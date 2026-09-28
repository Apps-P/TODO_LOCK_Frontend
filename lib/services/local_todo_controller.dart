import 'dart:async';
import 'package:flutter/widgets.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/views/main/todo/func.dart';
import 'lock_bridge.dart';

/// The main engine is the sole writer of the todos box.
class LocalTodoController with WidgetsBindingObserver {
  final Box<Todo> box;
  Timer? _timer;
  bool _busy = false;
  int _ticks = 0;
  LocalTodoController(this.box);

  Future<void> start() async {
    WidgetsBinding.instance.addObserver(this);
    await tick();
    _timer = Timer.periodic(
      const Duration(seconds: 1),
      (_) => unawaited(tick()),
    );
    await recoverOverlay(migrateLegacy: true);
  }

  Future<void> tick() async {
    if (_busy) return;
    _busy = true;
    try {
      if (LockBridge.supported && _ticks++ % 30 == 0) {
        await LockBridge.channel.invokeMethod<void>('recoverPurchases');
      }
      for (final entry in (await LockBridge.outcomes()).entries) {
        await applyOutcome(entry.key, entry.value as String);
        await LockBridge.acknowledge(entry.key);
      }
      await updateTodoStatus(box);
    } catch (error, stack) {
      // Keep the journal entry for retry if local persistence fails.
      debugPrint('Local state update failed: $error\n$stack');
    } finally {
      _busy = false;
    }
  }

  Future<void> applyOutcome(String session, String outcome) async {
    for (final todo in box.values) {
      if (todo.checkTime == null || LockBridge.sessionId(todo) != session) {
        continue;
      }
      if (outcome == 'paid') {
        todo.done = false;
        todo.checkTime = null;
      } else if (outcome == 'completed') {
        todo.done = true;
      } else {
        continue;
      }
      await todo.save();
      await box.flush();
      break;
    }
  }

  Future<void> recoverOverlay({bool migrateLegacy = false}) async {
    if (!LockBridge.supported) return;
    if (await LockBridge.current() == null) {
      if (!migrateLegacy) return;
      // Existing Hive data from before the native session journal was added.
      final running = box.values.where(
        (t) => t.lock && !t.done && t.checkTime != null,
      );
      if (running.isEmpty) return;
      await LockBridge.begin(running.first);
    }
    if (!await FlutterOverlayWindow.isPermissionGranted()) return;
    if (!await FlutterOverlayWindow.isActive()) await showLockOverlay();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(tick().then((_) => recoverOverlay()));
    }
  }

  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
  }
}

Future<void> showLockOverlay() => FlutterOverlayWindow.showOverlay(
  enableDrag: false,
  overlayTitle: 'TODOnLOCK 집중 중',
  overlayContent: '설정한 시간이 끝날 때까지 잠금이 유지됩니다.',
  flag: OverlayFlag.defaultFlag,
  visibility: NotificationVisibility.visibilityPublic,
  positionGravity: PositionGravity.auto,
  height: WindowSize.matchParent,
  width: WindowSize.matchParent,
  startPosition: const OverlayPosition(0, 0),
);
