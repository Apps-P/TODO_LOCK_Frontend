import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:hive/hive.dart';
import '../models/todo_model.dart';
import 'guide_preferences.dart';

class NotificationPreferences {
  static const dailyKey = 'dailyTodoNotificationEnabled';
  static const runningKey = 'runningTodoNotificationEnabled';
  static Box<dynamic> get box => Hive.box<dynamic>(GuidePreferences.boxName);
  static bool get dailyEnabled => box.get(dailyKey, defaultValue: true) == true;
  static bool get runningEnabled =>
      box.get(runningKey, defaultValue: true) == true;
  static Future<void> setDailyEnabled(bool value) => box.put(dailyKey, value);
  static Future<void> setRunningEnabled(bool value) =>
      box.put(runningKey, value);
  static Future<void> migrate() async {
    if (!box.containsKey(dailyKey)) {
      await setDailyEnabled(
        box.get('futureTodoRemindersEnabled', defaultValue: true) == true,
      );
    }
    await box.deleteAll([
      'futureTodoRemindersEnabled',
      'futureTodoReminderMinute',
    ]);
  }
}

class NotificationStatus {
  final bool allowed, dailyAllowed, runningAllowed, exactAllowed;
  NotificationStatus.fromMap(Map<dynamic, dynamic> map)
    : allowed = map['allowed'] == true,
      dailyAllowed = map['dailyAllowed'] == true,
      runningAllowed = map['runningAllowed'] == true,
      exactAllowed = map['exactAllowed'] == true;
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
    'order': todo.no,
    'done': todo.done,
    'lock': todo.lock,
    'endTime': todo.checkTime?.add(todo.duration).millisecondsSinceEpoch ?? 0,
  };
  static Future<NotificationStatus> status() async {
    if (!supported) return NotificationStatus.fromMap({});
    return NotificationStatus.fromMap(
      await channel.invokeMapMethod<String, dynamic>('status') ?? {},
    );
  }

  static Future<void> requestPermission() async {
    if (supported) await channel.invokeMethod<void>('requestPermission');
  }

  static Future<void> openSystemSettings() async {
    if (supported) await channel.invokeMethod<void>('openNotificationSettings');
  }

  static Future<void> openExactAlarmSettings() async {
    if (supported) await channel.invokeMethod<void>('openExactAlarmSettings');
  }
}

/// Only the main engine mirrors Hive. Android owns alarms across app restarts.
class TodoNotificationController with WidgetsBindingObserver {
  TodoNotificationController(this.todos, this.preferences);
  final Box<Todo> todos;
  final Box<dynamic> preferences;
  StreamSubscription<BoxEvent>? _todosSubscription, _preferencesSubscription;
  Future<void>? _syncing;
  Timer? _retry;
  Timer? _midnight;
  bool _dirty = false, _disposed = false;

  Future<void> start() async {
    if (!TodoNotifications.supported) return;
    await NotificationPreferences.migrate();
    WidgetsBinding.instance.addObserver(this);
    _todosSubscription = todos.watch().listen((_) => sync());
    _preferencesSubscription = preferences.watch().listen((event) {
      if (event.key == NotificationPreferences.dailyKey ||
          event.key == NotificationPreferences.runningKey) {
        sync();
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
    while (_dirty && !_disposed) {
      _dirty = false;
      try {
        await TodoNotifications.channel.invokeMethod<void>('sync', {
          'todos': todos.values.map(TodoNotifications.serialize).toList(),
          'dailyEnabled':
              preferences.get(
                NotificationPreferences.dailyKey,
                defaultValue: true,
              ) ==
              true,
          'runningEnabled':
              preferences.get(
                NotificationPreferences.runningKey,
                defaultValue: true,
              ) ==
              true,
        });
        _retry?.cancel();
        _midnight?.cancel();
        final now = DateTime.now();
        _midnight = Timer(
          DateTime(now.year, now.month, now.day + 1).difference(now),
          sync,
        );
      } catch (error) {
        debugPrint('알림 동기화 실패: $error');
        _retry?.cancel();
        if (!_disposed) _retry = Timer(const Duration(seconds: 5), sync);
        break;
      }
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) sync();
  }

  Future<void> dispose() async {
    _disposed = true;
    _retry?.cancel();
    _midnight?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    await _todosSubscription?.cancel();
    await _preferencesSubscription?.cancel();
    await _syncing;
  }
}
