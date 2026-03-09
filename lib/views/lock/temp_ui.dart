import 'package:flutter/material.dart';

class TempUI extends StatelessWidget {
  final Duration remainingTime;
  final String Function(Duration) formatDuration;
  final double width;
  final double height;

  const TempUI({
    super.key,
    required this.remainingTime,
    required this.formatDuration,
    required this.width,
    required this.height,
  });

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topRight,
      child: Container(
        width: width,
        height: height,

        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(12),
        ),
        alignment: Alignment.center,
        child: Text(
          formatDuration(remainingTime),
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