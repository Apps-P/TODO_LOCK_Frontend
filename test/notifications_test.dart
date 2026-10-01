import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
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

  setUp(() async {
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    directory = await Directory.systemTemp.createTemp('todo-notifications-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoAdapter());
    if (!Hive.isAdapterRegistered(100)) Hive.registerAdapter(DurationAdapter());
    todos = await Hive.openBox<Todo>('todos');
    preferences = await Hive.openBox<dynamic>(GuidePreferences.boxName);
    calls.clear();
    messenger.setMockMethodCallHandler(TodoNotifications.channel, (call) async {
      calls.add(call);
      if (call.method == 'status' || call.method == 'requestPermission') {
        return {
          'allowed': true,
          'remindersAllowed': true,
          'runningAllowed': true,
          'exactAllowed': true,
        };
      }
      return null;
    });
  });

  tearDown(() async {
    await controller?.dispose();
    controller = null;
    await Hive.close();
    await directory.delete(recursive: true);
    messenger.setMockMethodCallHandler(TodoNotifications.channel, null);
    debugDefaultTargetPlatformOverride = null;
  });

  Todo job() =>
      Todo(content: '책 읽기', lock: false, duration: const Duration(minutes: 10))
        ..date = DateTime(2026, 10, 1)
        ..no = 1
        ..user_id = 'local';

  Map<dynamic, dynamic> getLastSync() =>
      calls.lastWhere((call) => call.method == 'sync').arguments as Map;

  test(
    'default nine oclock and disabled preference survive reopening',
    () async {
      expect(NotificationPreferences.enabled, isTrue);
      expect(NotificationPreferences.minuteOfDay, 540);
      await NotificationPreferences.setTime(615);
      await NotificationPreferences.setEnabled(false);
      await preferences.close();
      preferences = await Hive.openBox<dynamic>(GuidePreferences.boxName);
      expect(NotificationPreferences.enabled, isFalse);
      expect(NotificationPreferences.minuteOfDay, 615);
      expect(() => NotificationPreferences.setTime(1440), throwsRangeError);
    },
  );

  test(
    'saved edits, starts, stops, completions and deletions update native mirror',
    () async {
      controller = TodoNotificationController(todos, preferences);
      await controller!.start();
      final todo = job();
      await todos.add(todo);
      await controller!.sync();
      expect((getLastSync()['todos'] as List).single['date'], '2026-10-01');
      todo.content = '수정된 할 일';
      todo.date = DateTime(2026, 10, 2);
      todo.checkTime = DateTime(2026, 10, 2, 10);
      await todo.save();
      await controller!.sync();
      final running = (getLastSync()['todos'] as List).single;
      expect(running['content'], '수정된 할 일');
      expect(running['date'], '2026-10-02');
      expect(
        running['endTime'],
        DateTime(2026, 10, 2, 10, 10).millisecondsSinceEpoch,
      );
      todo.checkTime = null;
      await todo.save();
      await controller!.sync();
      expect((getLastSync()['todos'] as List).single['endTime'], 0);
      todo.done = true;
      await todo.save();
      await controller!.sync();
      expect((getLastSync()['todos'] as List).single['done'], isTrue);
      await todo.delete();
      await controller!.sync();
      expect(getLastSync()['todos'], isEmpty);
    },
  );

  test(
    'settings changes update alarms without changing running jobs',
    () async {
      final todo = job()..checkTime = DateTime.now();
      await todos.add(todo);
      controller = TodoNotificationController(todos, preferences);
      await controller!.start();
      await NotificationPreferences.setTime(450);
      await NotificationPreferences.setEnabled(false);
      await Future<void>.delayed(Duration.zero);
      await controller!.sync();
      expect(getLastSync()['minuteOfDay'], 450);
      expect(getLastSync()['enabled'], isFalse);
      expect((getLastSync()['todos'] as List).single['endTime'], isPositive);
    },
  );

  test(
    'changes during an in-flight sync are sent in order with latest contents',
    () async {
      final gate = Completer<void>();
      var syncing = 0;
      var maxSyncing = 0;
      messenger.setMockMethodCallHandler(TodoNotifications.channel, (
        call,
      ) async {
        calls.add(call);
        syncing++;
        if (syncing > maxSyncing) maxSyncing = syncing;
        if (calls.length == 1) await gate.future;
        syncing--;
        return null;
      });
      controller = TodoNotificationController(todos, preferences);
      final first = controller!.start();
      await Future<void>.delayed(Duration.zero);
      await todos.add(job());
      await NotificationPreferences.setTime(600);
      gate.complete();
      await first;
      await controller!.sync();
      expect(maxSyncing, 1);
      expect(getLastSync()['minuteOfDay'], 600);
      expect(getLastSync()['todos'], hasLength(1));
    },
  );

  testWidgets('settings can pick a time and turn morning reminders off', (
    tester,
  ) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = const Size(430, 900);
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final closing = Hive.close();
      for (var i = 0; i < 10; i++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 10)),
        );
        await tester.pump();
      }
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
    expect(find.text('오전 9:00'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('reminder-time')));
    await tester.pumpAndSettle();
    await tester.tap(find.byIcon(Icons.keyboard_outlined));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextField).at(0), '08');
    await tester.enterText(find.byType(TextField).at(1), '30');
    await tester.tap(find.text('확인'));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
    expect(NotificationPreferences.minuteOfDay, 510);
    expect(find.text('오전 8:30'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('future-reminders-switch')));
    await tester.pumpAndSettle();
    expect(NotificationPreferences.enabled, isFalse);
    expect(
      tester
          .widget<ListTile>(find.byKey(const ValueKey('reminder-time')))
          .enabled,
      isFalse,
    );
    expect(tester.takeException(), isNull);
  });
}
