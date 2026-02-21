import 'dart:developer';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum OverlayMode { lock, temp }

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

  @override
  void initState() {
    super.initState();
    log("widget.checkTime: ${widget.checkTime}");
    log("widget.duration: ${widget.duration}");
    _calculateRemaining();
    log("Initial _remainingTime: $_remainingTime");
    _startCountdown();
  }

  @override
  void didUpdateWidget(LockOverlayView oldWidget) {
    super.didUpdateWidget(oldWidget);
    log("=== LockOverlayView didUpdateWidget ===");
    log("Old id: ${oldWidget.id}, New id: ${widget.id}");
    log("Old checkTime: ${oldWidget.checkTime}, New checkTime: ${widget.checkTime}");
    log("Old duration: ${oldWidget.duration}, New duration: ${widget.duration}");

    // 새로운 Todo가 시작되면 (id가 변경되면) 타이머 재시작
    if (oldWidget.id != widget.id) {
      log("ID changed! Restarting timer...");
      _tickTimer?.cancel(); // 기존 타이머 취소
      _calculateRemaining();
      log("New _remainingTime: $_remainingTime");
      _startCountdown(); // 새 타이머 시작
    }
  }

  ///====================================================
  /// 타이머 함수 선언
  /// ====================================================

  // 남은 시간 계산
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

  // 1초마다 남은 시간 갱신
  void _startCountdown() {
    _tickTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _calculateRemaining();
      log("Current _remainingTime: $_remainingTime");

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

  // 시간이 다 되거나 사용자가 끌 때
  Future<void> _closeOverlayWithSync() async {
    _tickTimer?.cancel();
    await FlutterOverlayWindow.closeOverlay();
  }

  void _onFinished() async {
    await _closeOverlayWithSync();
  }

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

  ///====================================================
  /// 타이머 함수 끝
  /// ====================================================
  @override
  Widget build(BuildContext context) {
    var par_h = MediaQuery.of(context).size.height;
    var par_w = MediaQuery.of(context).size.width;
    return Material(
      color: Colors.transparent,
      child: _mode == OverlayMode.temp
          ? _buildTempUI()
          : _buildLockUI(par_h, par_w),
    );
  }

  Future<void> _handleTempMode() async {
    if (_mode == OverlayMode.temp) return; // 중복 호출 방지

    var device_h = MediaQuery.of(context).size.height;
    var device_w = MediaQuery.of(context).size.width;

    await FlutterOverlayWindow.resizeOverlay(150, 80, false);
    await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
    await FlutterOverlayWindow.moveOverlay(
        OverlayPosition(device_w / 2 - 75, device_h / 2 - 40));

    if (mounted) {
      setState(() {
        _mode = OverlayMode.temp;
      });
    }

    // 5초 후 lock UI로 복귀
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;

      setState(() {
        _mode = OverlayMode.lock;
      });

      await FlutterOverlayWindow.moveOverlay(OverlayPosition(0, 0));
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent, WindowSize.matchParent, false);
    });
  }

  Widget _buildLockUI(double par_h, double par_w) {
    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        height: par_h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFFF2F0EF),
        ),
        child: GestureDetector(
          child: Stack(
            children: [
              SizedBox(
                height: par_h,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SizedBox(height: par_h * 0.1),

                    Text(
                      "앞으로 남은 시간...",
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w700,
                      ),
                    ),

                    SizedBox(height: par_h * 0.04),

                    Container(
                      height: par_h * 0.15,
                      padding: EdgeInsets.symmetric(
                        vertical: 20,
                        horizontal: 24,
                      ),
                      margin: EdgeInsets.symmetric(horizontal: par_w * 0.125),
                      decoration: BoxDecoration(
                        color: Color(0xFFF25843),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,

                      /// Timer 표시 - checkTime과 duration 기반 실시간 계산
                      child: Text(
                        _formatDuration(_remainingTime),
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),

                    SizedBox(height: par_h * 0.05),

                    Container(
                      width: double.infinity,
                      height: par_h * 0.14,
                      padding: EdgeInsets.symmetric(vertical: 20),
                      margin: EdgeInsets.symmetric(
                        horizontal: par_w * 0.125,
                        vertical: 10,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,

                      child: Text(
                        "${_formatDuration(widget.duration)} ${widget.contents}",
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ),

                    /// Tip 컨테이너
                    Container(
                      width: double.infinity,
                      height: par_h * 0.22,
                      padding: EdgeInsets.symmetric(
                        vertical: 24,
                        horizontal: 12,
                      ),
                      margin: EdgeInsets.symmetric(
                        horizontal: par_w * 0.125,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      alignment: Alignment.center,
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            "Tip",
                            style: TextStyle(
                              fontSize: 18,
                              color: Color(0xFFF25843),
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          SizedBox(height: 8),
                          Text(
                            "정말 급한 일이 있을 때는 잠시 해제 버튼을 눌러보세요",
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 16,
                              color: Colors.black87,
                            ),
                          ),
                        ],
                      ),
                    ),

                    Container(
                      margin: EdgeInsets.symmetric(
                        horizontal: par_w * 0.125,
                        vertical: 10,
                      ),
                      height: par_h * 0.08,
                      child: Row(
                        children: [
                          /// 잠시해제 버튼
                          Expanded(
                            child: GestureDetector(
                              onTap: _handleTempMode,
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Colors.white,
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "잠시해제",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.black87,
                                  ),
                                ),
                              ),
                            ),
                          ),

                          SizedBox(width: 16),

                          /// 포기하기 버튼
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await _closeOverlayWithSync();
                              },
                              child: Container(
                                padding: EdgeInsets.symmetric(vertical: 14),
                                decoration: BoxDecoration(
                                  color: Color(0xFFF25843),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                alignment: Alignment.center,
                                child: Text(
                                  "포기하기",
                                  style: TextStyle(
                                    fontSize: 16,
                                    color: Colors.white,
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),

                    Spacer(),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTempUI() {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: 120,
        height: 60,
        margin: const EdgeInsets.only(top: 10, right: 10),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          _formatDuration(_remainingTime),
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }
}