import 'dart:developer';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';

enum OverlayMode { lock, temp }

class LockOverlayView extends StatefulWidget {
  final String contents;
  final Duration duration;
  const LockOverlayView({
    super.key,
    required this.contents,
    required this.duration,
  });

  @override
  State<LockOverlayView> createState() => _LockOverlayViewState();

}

class _LockOverlayViewState extends State<LockOverlayView> {
  OverlayMode _mode = OverlayMode.lock;

  // 실시간 타이머를 위한 변수들
  Timer? _tickTimer;
  late Duration _remainingTime;

  @override

  void initState() {
    super.initState();
  }

  @override
  void dispose() {
    _tickTimer?.cancel(); // 메모리 누수 방지
    super.dispose();
  }


  String _formatDuration(Duration duration) {
    String minutes = duration.inMinutes.toString().padLeft(2, '0');
    String seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return "$minutes:$seconds";
  }
  void _onTimerFinished() async {
    // 시간이 다 되면 자동으로 오버레이 닫기
    await FlutterOverlayWindow.closeOverlay();
  }

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
    if(_mode == OverlayMode.temp) return; // 중복 호출
    // 1) overlay를 우측 상단 작은 크기로 축소
    var device_h = MediaQuery.of(context).size.height;
    var device_w = MediaQuery.of(context).size.width;

    await FlutterOverlayWindow.resizeOverlay(
        150, 80, false
    );
    await FlutterOverlayWindow.updateFlag(OverlayFlag.clickThrough);
    await FlutterOverlayWindow.moveOverlay(OverlayPosition(device_w/2 - 75,device_h/2 - 40));



    // 2) temp mode UI 표시
    if (mounted) {
      setState(() {
        _mode = OverlayMode.temp;
      });
    }

    // 3) 5초 후 lock UI로 복귀
    Future.delayed(const Duration(seconds: 5), () async {
      if (!mounted) return;
      log("5 second");
      setState(() {
        _mode = OverlayMode.lock;
      });

      // 원래 전체 화면으로 복구
      await FlutterOverlayWindow.moveOverlay(OverlayPosition(0, 0));
      await FlutterOverlayWindow.updateFlag(OverlayFlag.defaultFlag);
      await FlutterOverlayWindow.resizeOverlay(
          WindowSize.matchParent,
          WindowSize.matchParent,
          false
      );

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

                      /// Timer 표시
                      child: Text(
                        _formatDuration(widget.duration),
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

                      // Show contents & duration.
                      child: Text(
                          "+3:00 ${widget.contents}",
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ),

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
                            "정말 급한 일이 있을 때는\n“잠시 해제” 버튼을 눌러보세요",
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
                          // ✔️ 잠시 해제 버튼 수정됨
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

                          /// "Give UP" button -> give me the money!
                          Expanded(
                            child: GestureDetector(
                              onTap: () async {
                                await FlutterOverlayWindow.closeOverlay();
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
        child: const Text(
          "temp",
          style: TextStyle(color: Colors.white, fontSize: 16),
        ),
      ),
    );
  }

}




