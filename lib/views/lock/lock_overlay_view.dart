import 'dart:developer';
import 'dart:async';

import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'lock_ui.dart';
import 'temp_ui.dart';

enum OverlayMode { lock, temp }

/// ====================================================
/// What: class for Lock overlay view
/// How: get id and sync "todo" object.
///      and make timer which work identically
///      with main app (todo/view.dart).
/// ====================================================
class LockOverlayView extends StatefulWidget {
  final String id;
  final String contents;
  final DateTime? checkTime;
  final Duration duration;

  const LockOverlayView({
    super.key,
    required this.id,
    required this.contents,
    required this.duration,
    required this.checkTime,
  });

  @override
  State<LockOverlayView> createState() => _LockOverlayViewState();
}

class _LockOverlayViewState extends State<LockOverlayView> {
  OverlayMode _mode = OverlayMode.lock;
  Timer? _tickTimer;
  late Duration _remainingTime;

  int _tempPressCount = 0;

  /// temp 모드 남은 초. -1이면 비활성 상태.
  int _tempRemainingSeconds = -1;

  static const int _tempDurationSeconds = 100;

  @override
  void initState() {
    super.initState();
    _calculateRemaining();
    _startCountdown();
  }

  @override
  void didUpdateWidget(LockOverlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    log("=== LockOverlayView didUpdateWidget ===");
    log("Old id: ${oldWidget.id}, New id: ${widget.id}");

    if (oldWidget.id != widget.id) {
      log("ID changed! Restarting timer...");
      _tickTimer?.cancel();
      _calculateRemaining();
      log("New _remainingTime: $_remainingTime");

      // temp 모드 상태 초기화: 이전 todo의 상태가 다음 todo에 이어지지 않도록
      _mode = OverlayMode.lock;
      _tempRemainingSeconds = -1;
      _tempPressCount = 0;

      _startCountdown();
    }
  }

  /// 메인 tick: todo 카운트다운 + temp 모드 카운트다운을 하나의 Timer로 처리.
  void _startCountdown() {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      // ── 1) todo 잔여 시간 갱신 ──
      _calculateRemaining();

      // ── 2) temp 모드 카운트다운 (todo 완료 판정과 독립적으로 실행) ──
      if (_mode == OverlayMode.temp && _tempRemainingSeconds > 0) {
        _tempRemainingSeconds--;

        if (_tempRemainingSeconds <= 0) {
          _exitTempMode(); // async fire-and-forget: overlay flag 원복
        }
      }

      // ── 3) todo 완료 판정 (temp 모드 중에도 항상 실행) ──
      if (_remainingTime.inSeconds <= 0) {
        _onFinished();
      } else {
        if (mounted) {
          setState(() {});
        } else {
          log("Widget not mounted!");
        }
      }
    });
  }

  /// temp 모드 종료 → lock 모드로 복귀 + overlay flag 원복.
  Future<void> _exitTempMode() async {
    if (!mounted) return;

    setState(() {
      _mode = OverlayMode.lock;
      _tempRemainingSeconds = -1;
    });

    await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
  }

  /// Get remaining time from checkTime and now().
  void _calculateRemaining() {
    if (widget.checkTime != null) {
      final now = DateTime.now();
      final elapsed = now.difference(widget.checkTime!);
      final remaining = widget.duration - elapsed;
      _remainingTime = remaining.isNegative ? Duration.zero : remaining;
    } else {
      _remainingTime = widget.duration;
    }
  }

  Future<void> _closeOverlayWithSync() async {
    _tickTimer?.cancel();
    await FlutterOverlayWindow.closeOverlay();
  }

  // Close overlay when Succeed.
  void _onFinished() async {
    await _saveTodoCompletion(isSuccess: true);
    await _closeOverlayWithSync();
  }

  // Close overlay when Give up.
  void onGiveUp() async {
    await _saveTodoCompletion(isSuccess: false);
    await _closeOverlayWithSync();
  }

  /// Sync Hive. Search todo object from id.
  Future<void> _saveTodoCompletion({required bool isSuccess}) async {
    try {
      Box<Todo> todoBox;

      // 🔥 핵심: Box를 닫고 다시 열어서 최신 상태 강제 로드
      if (Hive.isBoxOpen('todos')) {
        await Hive.box<Todo>('todos').close();
      }

      // 새로 열기 - 이때 디스크에서 최신 데이터 읽음
      todoBox = await Hive.openBox<Todo>('todos');

      // ID로 Todo 찾기
      Todo? targetTodo;
      for (var t in todoBox.values) {
        if (t.id == widget.id) {
          targetTodo = t;
          break;
        }
      }

      if (targetTodo != null) {
        // 값 변경
        targetTodo.done = isSuccess;

        // 저장 및 디스크 동기화
        await targetTodo.save();
        await todoBox.flush(); // Write on disk directly

        log("Todo Sync Success: ${isSuccess ? 'DONE' : 'GIVE UP'} (ID: ${widget.id})");
      } else {
        log("Error: Could not find Todo with ID ${widget.id}");
      }
    } catch (e) {
      log("Critical Error in Overlay Hive Sync: $e");
    }
  }

  /// Show duration with format (hh:)mm:ss.
  String _formatDuration(Duration duration) {
    int hours = duration.inHours;
    int minutes = duration.inMinutes.remainder(60);
    int seconds = duration.inSeconds.remainder(60);
    if (hours > 0) {
      return "${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    } else {
      return "${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}";
    }
  }

  @override
  void dispose() {
    _tickTimer?.cancel();
    super.dispose();
  }

  /// Handler for [temp] mode and [lock] mode switch.
  Future<void> _handleTempMode() async {
    if (_mode == OverlayMode.temp) return;

    // 3번 초과 시 버튼 비활성화 처리 (LockUI에서 색상/동작 제어)
    if (_tempPressCount >= 3) return;

    setState(() {
      _tempPressCount++;
      _mode = OverlayMode.temp;
      _tempRemainingSeconds = _tempDurationSeconds; // 카운트다운 시작
    });

    await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
  }

  /// Build overlay by mode type.
  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      textStyle: const TextStyle(fontFamily: 'Paperlogy'),
      child: _mode == OverlayMode.temp
          ? TempUI(
        remainingTime: _remainingTime,
        formatDuration: _formatDuration,
        tempRemainingSeconds: _tempRemainingSeconds,
      )
          : LockUI(
        remainingTime: _remainingTime,
        contents: widget.contents,
        duration: widget.duration,
        formatDuration: _formatDuration,
        onTempMode: _handleTempMode,
        onGiveUp: onGiveUp,
        tempPressCount: _tempPressCount,
      ),
    );
  }
}