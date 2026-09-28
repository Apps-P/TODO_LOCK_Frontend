import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:todo_and_lock/services/lock_bridge.dart';
import 'lock_ui.dart';
import 'temp_ui.dart';

class LockOverlayView extends StatefulWidget {
  final String id;
  final String session;
  final String contents;
  final DateTime checkTime;
  final Duration duration;
  const LockOverlayView({
    super.key,
    required this.id,
    required this.session,
    required this.contents,
    required this.checkTime,
    required this.duration,
  });
  @override
  State<LockOverlayView> createState() => _LockOverlayViewState();
}

class _LockOverlayViewState extends State<LockOverlayView> {
  Timer? _timer;
  DateTime? _breakUntil;
  int _breakCount = 0;
  bool _paying = false;
  bool _finishing = false;
  String? _message;
  Duration get remaining {
    final value = widget.checkTime
        .add(widget.duration)
        .difference(DateTime.now());
    return value.isNegative ? Duration.zero : value;
  }

  int get breakSeconds => _breakUntil == null
      ? 0
      : ((_breakUntil!.difference(DateTime.now()).inMilliseconds / 1000).ceil())
            .clamp(0, 120);

  @override
  void initState() {
    super.initState();
    _restoreBreak();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) => _tick());
  }

  Future<void> _restoreBreak() async {
    final data = await LockBridge.current();
    if (!mounted || data?['session'] != widget.session) return;
    _breakCount = (data?['breakCount'] as int?) ?? 0;
    final until = (data?['breakUntil'] as int?) ?? 0;
    if (until > DateTime.now().millisecondsSinceEpoch) {
      _breakUntil = DateTime.fromMillisecondsSinceEpoch(until);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
    }
    if (mounted) setState(() {});
  }

  Future<void> _tick() async {
    if (_finishing) return;
    if (remaining == Duration.zero) {
      _finishing = true;
      try {
        await LockBridge.finish(widget.session);
      } catch (_) {
        // A failed durable write must keep the lock; retry on the next tick.
        _finishing = false;
      }
      return;
    }
    if (_breakUntil != null && breakSeconds == 0) {
      try {
        await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
        _breakUntil = null;
      } catch (_) {
        return; // Retry restoring the touch-blocking flag on the next tick.
      }
    }
    if (mounted) setState(() {});
  }

  Future<void> _giveUp() async {
    if (_paying || _finishing) return;
    setState(() {
      _paying = true;
      _message = null;
    });
    try {
      // Native code is the only authority that records a paid unlock. Never
      // close the overlay or mutate a Todo merely because this Future resolves.
      final status = await LockBridge.purchase(widget.session);
      if (!mounted) return;
      setState(() {
        _message = switch (status) {
          'purchased' => '결제가 확인되었습니다.',
          'completed' => '집중 시간이 완료되었습니다.',
          'pending' => '결제 승인 대기 중입니다. 확인될 때까지 잠금이 유지됩니다.',
          'unavailable' => '결제 상품을 불러올 수 없습니다. 잠금이 유지됩니다.',
          'credit' => '이전 결제가 확인되었습니다. 포기하기를 다시 누르면 사용할 수 있습니다.',
          'canceled' => '결제가 취소되었거나 결제 화면을 벗어났습니다. 잠금을 유지합니다.',
          _ => '결제를 확인하지 못했습니다. 잠금이 유지됩니다.',
        };
      });
    } on PlatformException catch (error) {
      if (mounted) {
        setState(() => _message = error.message ?? '결제를 시작하지 못했습니다.');
      }
    } catch (_) {
      if (mounted) setState(() => _message = '결제를 시작하지 못했습니다. 잠금은 유지됩니다.');
    } finally {
      if (mounted) setState(() => _paying = false);
    }
  }

  Future<void> _temporaryUnlock() async {
    if (_paying || _finishing || _breakCount >= 3 || breakSeconds > 0) return;
    try {
      final until = await LockBridge.channel.invokeMethod<int>('startBreak', {
        'session': widget.session,
      });
      if (until == null || !mounted) return;
      _breakCount++;
      _breakUntil = DateTime.fromMillisecondsSinceEpoch(until);
      await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted) setState(() => _message = '잠시 해제를 시작하지 못했습니다.');
    }
  }

  String _format(Duration duration) {
    String two(int v) => v.toString().padLeft(2, '0');
    final text =
        '${two(duration.inMinutes.remainder(60))}:${two(duration.inSeconds.remainder(60))}';
    return duration.inHours > 0 ? '${two(duration.inHours)}:$text' : text;
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Material(
    color: Colors.transparent,
    child: breakSeconds > 0
        ? TempUI(
            remainingTime: remaining,
            formatDuration: _format,
            tempRemainingSeconds: breakSeconds,
          )
        : Stack(
            children: [
              LockUI(
                remainingTime: remaining,
                contents: widget.contents,
                duration: widget.duration,
                formatDuration: _format,
                onTempMode: _temporaryUnlock,
                onGiveUp: _giveUp,
                tempPressCount: _breakCount,
                isPaying: _paying,
              ),
              if (_message != null)
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 8,
                  child: SafeArea(
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.black87,
                      child: Text(
                        _message!,
                        style: const TextStyle(color: Colors.white),
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ),
                ),
            ],
          ),
  );
}
