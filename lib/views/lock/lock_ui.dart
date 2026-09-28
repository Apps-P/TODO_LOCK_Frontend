import 'dart:math' as math;
import 'package:flutter/material.dart';

class LockUI extends StatelessWidget {
  final Duration remainingTime;
  final String contents;
  final Duration duration;
  final String Function(Duration) formatDuration;
  final VoidCallback onTempMode;
  final VoidCallback onGiveUp;
  final int tempPressCount;
  final bool isPaying;
  final GlobalKey? timerKey;
  final GlobalKey? temporaryButtonKey;
  final GlobalKey? giveUpButtonKey;

  const LockUI({
    super.key,
    required this.remainingTime,
    required this.contents,
    required this.duration,
    required this.formatDuration,
    required this.onTempMode,
    required this.onGiveUp,
    required this.tempPressCount,
    this.isPaying = false,
    this.timerKey,
    this.temporaryButtonKey,
    this.giveUpButtonKey,
  });

  @override
  Widget build(BuildContext context) {
    final isTempDisabled = tempPressCount >= 3 || isPaying;
    return ColoredBox(
      color: const Color(0xFFF2F0EF),
      child: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            final height = constraints.maxHeight;
            final width = constraints.maxWidth;
            // Natural heights and scrolling keep the same design usable on
            // compact displays and with larger accessibility text settings.
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(
                width * 0.125,
                height * 0.07,
                width * 0.125,
                24,
              ),
              child: Column(
                children: [
                  const Text(
                    '앞으로 남은 시간...',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.w700,
                      color: Colors.black,
                    ),
                  ),
                  SizedBox(height: height * 0.03),
                  Container(
                    key: timerKey,
                    height: math.max(88, height * 0.15),
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(
                      vertical: 20,
                      horizontal: 24,
                    ),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF25843),
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        formatDuration(remainingTime),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 50,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  SizedBox(height: height * 0.03),
                  Container(
                    height: math.max(88, height * 0.14),
                    width: double.infinity,
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    alignment: Alignment.center,
                    child: SingleChildScrollView(
                      child: Text(
                        '+${formatDuration(duration)}  $contents',
                        style: const TextStyle(
                          fontSize: 20,
                          color: Colors.black87,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  Container(
                    width: double.infinity,
                    constraints: BoxConstraints(
                      minHeight: math.max(128, height * 0.18),
                    ),
                    padding: const EdgeInsets.symmetric(
                      vertical: 24,
                      horizontal: 12,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: const Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Tip',
                          style: TextStyle(
                            fontSize: 18,
                            color: Color(0xFFF25843),
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 8),
                        Text(
                          '정말 급한 일이 있을 때는\n잠시 해제 버튼을 눌러보세요',
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 16, color: Colors.black87),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  IntrinsicHeight(
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Expanded(
                          child: _button(
                            key: temporaryButtonKey,
                            label: '잠시해제\n$tempPressCount/3',
                            color: isTempDisabled
                                ? Colors.black26
                                : Colors.white,
                            textColor: isTempDisabled
                                ? Colors.white
                                : Colors.black87,
                            onTap: isTempDisabled ? null : onTempMode,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _button(
                            key: giveUpButtonKey,
                            label: isPaying ? '결제 확인 중…' : '포기하기 (결제)',
                            color: const Color(0xFFF25843),
                            textColor: Colors.white,
                            onTap: isPaying ? null : onGiveUp,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _button({
    required Key? key,
    required String label,
    required Color color,
    required Color textColor,
    required VoidCallback? onTap,
  }) => Semantics(
    button: true,
    enabled: onTap != null,
    child: GestureDetector(
      key: key,
      onTap: onTap,
      child: Container(
        constraints: const BoxConstraints(minHeight: 64),
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 8),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          label,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w400,
            color: textColor,
          ),
        ),
      ),
    ),
  );
}
