import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/services/guide_preferences.dart';
import 'package:todo_and_lock/services/todo_notifications.dart';
import 'package:todo_and_lock/views/setting/notification_settings.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<Todo> todos;
  late Box<dynamic> preferences;
  TodoNotificationController? controller;
  final calls = <MethodCall>[];
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  const granted = {
    'allowed': true,
    'dailyAllowed': true,
    'runningAllowed': true,
    'exactAllowed': true,
  };

  setUp(() async {
    directory = await Directory.systemTemp.createTemp(
      'todolock-notifications-',
    );
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoAdapter());
    if (!Hive.isAdapterRegistered(100)) Hive.registerAdapter(DurationAdapter());
    todos = await Hive.openBox<Todo>('todos');
    preferences = await Hive.openBox<dynamic>(GuidePreferences.boxName);
    calls.clear();
    messenger.setMockMethodCallHandler(TodoNotifications.channel, (call) async {
      calls.add(call);
      return call.method == 'status' || call.method == 'requestPermission'
          ? granted
          : null;
    });
  });

  tearDown(() async {
    await controller?.dispose();
    controller = null;
    await Hive.close();
    await directory.delete(recursive: true);
    messenger.setMockMethodCallHandler(TodoNotifications.channel, null);
  });

  Todo makeTodo() =>
      Todo(content: '책 읽기', lock: false, duration: const Duration(minutes: 10))
        ..date = DateTime(2026, 10, 6)
        ..no = 0
        ..userId = 'local';
  Map<dynamic, dynamic> latest() =>
      calls.lastWhere((call) => call.method == 'sync').arguments as Map;

  test('list and timer preferences persist independently', () async {
    expect(NotificationPreferences.dailyEnabled, isTrue);
    expect(NotificationPreferences.runningEnabled, isTrue);
    await NotificationPreferences.setDailyEnabled(false);
    await NotificationPreferences.setRunningEnabled(false);
    await preferences.close();
    preferences = await Hive.openBox<dynamic>(GuidePreferences.boxName);
    expect(NotificationPreferences.dailyEnabled, isFalse);
    expect(NotificationPreferences.runningEnabled, isFalse);
  });

  test(
    'add edit start stop complete delete mirror the latest job state',
    () async {
      controller = TodoNotificationController(todos, preferences);
      await controller!.start();
      final todo = makeTodo();
      await todos.put(todo.id, todo);
      await controller!.sync();
      expect((latest()['todos'] as List).single['date'], '2026-10-06');
      todo.content = '산책';
      todo.date = DateTime(2026, 10, 7);
      await todo.save();
      await controller!.sync();
      expect((latest()['todos'] as List).single['content'], '산책');
      expect((latest()['todos'] as List).single['date'], '2026-10-07');
      todo.checkTime = DateTime.now();
      await todo.save();
      await controller!.sync();
      expect(
        (latest()['todos'] as List).single['endTime'],
        todo.checkTime!.add(todo.duration).millisecondsSinceEpoch,
      );
      todo.checkTime = null;
      await todo.save();
      await controller!.sync();
      expect((latest()['todos'] as List).single['endTime'], 0);
      todo.done = true;
      await todo.save();
      await controller!.sync();
      expect((latest()['todos'] as List).single['done'], isTrue);
      await todo.delete();
      await controller!.sync();
      expect(latest()['todos'], isEmpty);
    },
  );

  test('settings update independently from running jobs', () async {
    final todo = makeTodo()..checkTime = DateTime.now();
    await todos.put(todo.id, todo);
    controller = TodoNotificationController(todos, preferences);
    await controller!.start();
    await NotificationPreferences.setRunningEnabled(true);
    await NotificationPreferences.setDailyEnabled(false);
    await controller!.sync();
    expect(latest()['runningEnabled'], true);
    expect(latest()['dailyEnabled'], false);
    expect((latest()['todos'] as List).single['endTime'], greaterThan(0));
  });

  test(
    'overlapping changes serialize and cannot overwrite the newest snapshot',
    () async {
      final entered = Completer<void>(), release = Completer<void>();
      var inFlight = 0, maxInFlight = 0;
      messenger.setMockMethodCallHandler(TodoNotifications.channel, (
        call,
      ) async {
        calls.add(call);
        inFlight++;
        if (inFlight > maxInFlight) maxInFlight = inFlight;
        if (!entered.isCompleted) {
          entered.complete();
          await release.future;
        }
        inFlight--;
        return null;
      });
      controller = TodoNotificationController(todos, preferences);
      final starting = controller!.start();
      await entered.future;
      final todo = makeTodo();
      await todos.put(todo.id, todo);
      todo.content = '최종 내용';
      await todo.save();
      await NotificationPreferences.setRunningEnabled(false);
      release.complete();
      await starting;
      await controller!.sync();
      expect(maxInFlight, 1);
      expect((latest()['todos'] as List).single['content'], '최종 내용');
      expect(latest()['runningEnabled'], false);
    },
  );

  testWidgets(
    'settings toggle list and timer separately without a reminder time',
    (tester) async {
      Future<void> flush() async {
        for (var i = 0; i < 5; i++) {
          await tester.runAsync(
            () => Future<void>.delayed(const Duration(milliseconds: 10)),
          );
          await tester.pumpAndSettle();
        }
      }

      addTearDown(() async {
        await tester.pumpWidget(const SizedBox.shrink());
        final closing = Hive.close();
        await flush();
        await closing;
      });
      await tester.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(child: NotificationSettingsCard()),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('알림 시간'), findsNothing);
      await tester.tap(find.byKey(const ValueKey('daily-jobs-switch')));
      await flush();
      expect(NotificationPreferences.dailyEnabled, isFalse);
      expect(NotificationPreferences.runningEnabled, isTrue);
      await tester.tap(find.byKey(const ValueKey('running-timer-switch')));
      await flush();
      expect(NotificationPreferences.runningEnabled, isFalse);
      expect(NotificationPreferences.dailyEnabled, isFalse);
      expect(tester.takeException(), isNull);
    },
  );
}
