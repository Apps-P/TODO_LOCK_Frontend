import 'package:flutter/material.dart';

class TempUI extends StatelessWidget {
  final Duration remainingTime;
  final String Function(Duration) formatDuration;
  final int tempRemainingSeconds;

  const TempUI({
    super.key,
    required this.remainingTime,
    required this.formatDuration,
    required this.tempRemainingSeconds,
  });

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final boxWidth = size.width / 4;
    final boxHeight = size.height / 8;

    // 오버레이 전체는 matchParent (투명) + clickThrough flag
    // 실제 표시 영역만 boxWidth x boxHeight 크기의 불투명 컨테이너
    return SizedBox.expand(
      child: Stack(
        children: [
          // 나머지 전체 영역: 완전 투명 (터치는 clickThrough flag가 처리)
          const SizedBox.expand(),

          // 실제 표시 영역
          Positioned(
            right: 0,
            top: 0,
            child: Container(
              width: boxWidth,
              height: boxHeight,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '$tempRemainingSeconds',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  Text(
                    formatDuration(remainingTime),
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}