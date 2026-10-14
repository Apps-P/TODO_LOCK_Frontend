import 'dart:async';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/services/lock_bridge.dart';
import 'package:todo_and_lock/services/local_todo_controller.dart';
import 'package:todo_and_lock/views/lock/lock_overlay_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<Todo> box;
  setUp(() async {
    directory = await Directory.systemTemp.createTemp('todolock-test-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoAdapter());
    if (!Hive.isAdapterRegistered(100)) Hive.registerAdapter(DurationAdapter());
    box = await Hive.openBox<Todo>('todos');
  });
  tearDown(() async {
    debugDefaultTargetPlatformOverride = null;
    await Hive.close();
    await directory.delete(recursive: true);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(LockBridge.channel, null);
  });
  Todo todo() =>
      Todo(content: '로컬 할 일', lock: true, duration: const Duration(minutes: 30))
        ..date = DateTime(2026, 9, 16)
        ..no = 1
        ..userId = 'local'
        ..checkTime = DateTime.now();

  test('local Todo survives reopening without authentication', () async {
    final item = todo();
    await box.add(item);
    await box.close();
    box = await Hive.openBox<Todo>('todos');
    expect(box.values.single.content, '로컬 할 일');
    expect(box.values.single.duration, const Duration(minutes: 30));
  });
  test('paid unlock resets start time and survives reopening', () async {
    final item = todo();
    await box.add(item);
    await LocalTodoController(
      box,
    ).applyOutcome(LockBridge.sessionId(item), 'paid');
    await box.close();
    box = await Hive.openBox<Todo>('todos');
    expect(box.values.single.checkTime, isNull);
    expect(box.values.single.done, isFalse);
  });
  test(
    'late outcome from previous start cannot unlock a new session',
    () async {
      final item = todo();
      await box.add(item);
      final previous = LockBridge.sessionId(item);
      item.checkTime = item.checkTime!.add(const Duration(minutes: 1));
      await item.save();
      await LocalTodoController(box).applyOutcome(previous, 'paid');
      expect(item.checkTime, isNotNull);
    },
  );
  test('cancel, error and pending outcomes do not unlock a Todo', () async {
    final item = todo();
    await box.add(item);
    for (final outcome in ['canceled', 'error', 'pending']) {
      await LocalTodoController(
        box,
      ).applyOutcome(LockBridge.sessionId(item), outcome);
      expect(item.checkTime, isNotNull);
      expect(item.done, isFalse);
    }
  });
  test(
    'normal completion marks done, repeated paid event is idempotent',
    () async {
      final item = todo();
      await box.add(item);
      final session = LockBridge.sessionId(item);
      final controller = LocalTodoController(box);
      await controller.applyOutcome(session, 'completed');
      expect(item.done, isTrue);
      await controller.applyOutcome(session, 'paid');
      await controller.applyOutcome(session, 'paid');
      expect(item.done, isFalse);
      expect(item.checkTime, isNull);
    },
  );
  test(
    'resume does not recreate a paid session before the journal is applied',
    () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final item = todo();
      await box.add(item);
      final methods = <String>[];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LockBridge.channel, (call) async {
            methods.add(call.method);
            return null;
          });
      await LocalTodoController(box).recoverOverlay();
      expect(methods, ['getSession']);
      expect(methods, isNot(contains('setSession')));
    },
  );
  testWidgets(
    'canceling payment keeps lock visible and duplicate taps launch only once',
    (tester) async {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      final purchase = Completer<String>();
      int requests = 0;
      int finishCalls = 0;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(LockBridge.channel, (call) async {
            if (call.method == 'getSession') return {'session': 'session'};
            if (call.method == 'purchaseUnlock') {
              requests++;
              return purchase.future;
            }
            if (call.method == 'finishSession') finishCalls++;
            return null;
          });
      await tester.pumpWidget(
        MaterialApp(
          home: LockOverlayView(
            id: 'todo',
            session: 'session',
            contents: '집중 테스트',
            checkTime: DateTime.now(),
            duration: const Duration(hours: 1),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text('포기하기 (결제)'));
      await tester.pump();
      await tester.tap(find.text('결제 확인 중…'));
      await tester.pump();
      expect(requests, 1);
      expect(finishCalls, 0);
      purchase.complete('canceled');
      await tester.pumpAndSettle();
      expect(find.textContaining('잠금을 유지합니다.'), findsOneWidget);
      expect(find.text('포기하기 (결제)'), findsOneWidget);
      expect(finishCalls, 0);
      await tester.pumpWidget(const SizedBox.shrink());
      debugDefaultTargetPlatformOverride = null;
    },
  );
}
