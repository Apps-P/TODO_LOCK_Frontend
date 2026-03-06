import 'package:flutter/material.dart';
import 'dart:developer';

class LockUI extends StatelessWidget {
  final Duration remainingTime;
  final String contents;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onTempMode;
  final void Function() onGiveUp;

  const LockUI({
    super.key,
    required this.remainingTime,
    required this.contents,
    required this.duration,
    required this.formatDuration,
    required this.onTempMode,
    required this.onGiveUp,
  });

  @override
  Widget build(BuildContext context) {
    var par_h = MediaQuery.of(context).size.height;
    var par_w = MediaQuery.of(context).size.width;

    return Center(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 12.0),
        height: par_h,
        width: double.infinity,
        decoration: BoxDecoration(
          color: Color(0xFFF2F0EF),
        ),
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
                      color: Colors.black,
                    ),
                  ),

                  SizedBox(height: par_h * 0.04),

                  // 타이머 디스플레이
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
                    child: Text(
                      formatDuration(remainingTime),
                      style: TextStyle(
                        color: Colors.white,
                        fontSize: 50,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  SizedBox(height: par_h * 0.05),

                  // Todo 내용
                  Container(
                    width: double.infinity,
                    height: par_h * 0.14,
                    padding: EdgeInsets.symmetric(vertical: 20, horizontal: 20),
                    margin: EdgeInsets.symmetric(
                      horizontal: par_w * 0.125,
                      vertical: 10,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      scrollDirection: Axis.vertical,
                      child: Text(
                        "+${formatDuration(duration)}  $contents",
                        style: TextStyle(fontSize: 20, color: Colors.black87),
                      ),
                    ),
                  ),

                  // Tip 컨테이너
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
                          "정말 급한 일이 있을 때는 \n 잠시 해제 버튼을 눌러보세요",
                          textAlign: TextAlign.center,
                          style: TextStyle(
                            fontSize: 16,
                            color: Colors.black87,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 버튼들
                  Container(
                    margin: EdgeInsets.symmetric(
                      horizontal: par_w * 0.125,
                      vertical: 10,
                    ),
                    height: par_h * 0.08,
                    child: Row(
                      children: [
                        // 잠시해제 버튼
                        Expanded(
                          child: GestureDetector(
                            onTap: onTempMode,
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

                        // 포기하기 버튼
                        Expanded(
                          child: GestureDetector(
                            onTap: () async {
                              log("pressed give up");
                              onGiveUp();
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
    );
  }
}