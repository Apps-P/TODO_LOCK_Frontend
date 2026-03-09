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

  double _tmpWidth = 0;
  double _tmpHeight = 0;
  int _tempPressCount = 0;

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
      _startCountdown();

      setState(() {
        _tempPressCount = 0;
      });
    }
  }



  /// start Timer and finished overlay when remain time smaller than zero.
  void _startCountdown() {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemaining();


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
    });

    double device_h = MediaQuery.of(context).size.height;
    double device_w = MediaQuery.of(context).size.width;

    _tmpWidth = device_w / 4;
    _tmpHeight = device_h / 8;

    await FlutterOverlayWindow.resizeOverlay(_tmpWidth.round(), _tmpHeight.round(), false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
    await FlutterOverlayWindow.moveOverlay(
        OverlayPosition((device_w - _tmpWidth) / 2, (device_h - _tmpHeight) / 2));

    if (mounted) {
      setState(() {
        _mode = OverlayMode.temp;
      });
    }

    Future.delayed(const Duration(seconds: 10), () async {
      if (!mounted) return;

      // 1. 먼저 크기/플래그 복구
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(0, 0));
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, WindowSize.matchParent, false);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);

      // 2. 크기 복구 후 UI 전환
      if (!mounted) return;
      setState(() {
        _mode = OverlayMode.lock;
      });
    });
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
        width: _tmpWidth,
        height: _tmpHeight,
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