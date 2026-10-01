import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'guide_preferences.dart';

class NotificationPreferences {
  static const enabledKey = 'futureTodoRemindersEnabled';
  static const timeKey = 'futureTodoReminderMinute';
  static Box<dynamic> get box => Hive.box<dynamic>(GuidePreferences.boxName);
  static bool get enabled => box.get(enabledKey, defaultValue: true) == true;
  static int get minuteOfDay =>
      (box.get(timeKey, defaultValue: 540) as int).clamp(0, 1439);

  static Future<void> setEnabled(bool value) => box.put(enabledKey, value);
  static Future<void> setTime(int value) {
    if (value < 0 || value >= 1440) throw RangeError.range(value, 0, 1439);
    return box.put(timeKey, value);
  }
}

class NotificationStatus {
  final bool allowed;
  final bool remindersAllowed;
  final bool runningAllowed;
  final bool exactAllowed;
  const NotificationStatus({
    this.allowed = false,
    this.remindersAllowed = false,
    this.runningAllowed = false,
    this.exactAllowed = false,
  });

  factory NotificationStatus.fromMap(Map<Object?, Object?>? map) =>
      NotificationStatus(
        allowed: map?['allowed'] == true,
        remindersAllowed: map?['remindersAllowed'] == true,
        runningAllowed: map?['runningAllowed'] == true,
        exactAllowed: map?['exactAllowed'] == true,
      );
}

class TodoNotifications {
  static const channel = MethodChannel('todolock/notifications');
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static String dateKey(DateTime date) =>
      '${date.year.toString().padLeft(4, '0')}-${date.month.toString().padLeft(2, '0')}-${date.day.toString().padLeft(2, '0')}';

  static Map<String, Object> serialize(Todo todo) => {
    'id': todo.id,
    'content': todo.content,
    'date': dateKey(todo.date),
    'done': todo.done,
    'lock': todo.lock,
    'endTime': todo.checkTime?.add(todo.duration).millisecondsSinceEpoch ?? 0,
  };

  static Future<NotificationStatus> status() async {
    if (!supported) return const NotificationStatus();
    return NotificationStatus.fromMap(await channel.invokeMapMethod('status'));
  }

  static Future<NotificationStatus> requestPermission() async {
    if (!supported) return const NotificationStatus();
    return NotificationStatus.fromMap(
      await channel.invokeMapMethod('requestPermission'),
    );
  }

  static Future<void> openSystemSettings() async {
    if (supported) await channel.invokeMethod<void>('openNotificationSettings');
  }

  static Future<void> openExactAlarmSettings() async {
    if (supported) await channel.invokeMethod<void>('openExactAlarmSettings');
  }
}

/// Sync only after data/settings changes or resume, never every timer tick.
/// Native alarms and system chronometers continue while Flutter is suspended.
class TodoNotificationController with WidgetsBindingObserver {
  final Box<Todo> todos;
  final Box<dynamic> preferences;
  StreamSubscription<BoxEvent>? _todoChanges;
  StreamSubscription<BoxEvent>? _settingChanges;
  Future<void>? _syncing;
  bool _dirty = false;
  bool _disposed = false;

  TodoNotificationController(this.todos, this.preferences);

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    _todoChanges = todos.watch().listen((_) => unawaited(sync()));
    _settingChanges = preferences.watch().listen((event) {
      if (event.key == NotificationPreferences.enabledKey ||
          event.key == NotificationPreferences.timeKey) {
        unawaited(sync());
      }
    });
    await sync();
  }

  Future<void> sync() {
    if (_disposed || !TodoNotifications.supported) return Future.value();
    _dirty = true;
    return _syncing ??= _drain().whenComplete(() => _syncing = null);
  }

  Future<void> _drain() async {
    try {
      while (_dirty && !_disposed) {
        _dirty = false;
        await TodoNotifications.channel.invokeMethod<void>('sync', {
          'todos': todos.values.map(TodoNotifications.serialize).toList(),
          'enabled':
              preferences.get(
                NotificationPreferences.enabledKey,
                defaultValue: true,
              ) ==
              true,
          'minuteOfDay':
              (preferences.get(
                        NotificationPreferences.timeKey,
                        defaultValue: 540,
                      )
                      as int)
                  .clamp(0, 1439),
        });
      }
    } catch (error) {
      debugPrint('알림 동기화 실패: $error');
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) unawaited(sync());
  }

  Future<void> dispose() async {
    _disposed = true;
    WidgetsBinding.instance.removeObserver(this);
    await _todoChanges?.cancel();
    await _settingChanges?.cancel();
    await _syncing;
  }
}
