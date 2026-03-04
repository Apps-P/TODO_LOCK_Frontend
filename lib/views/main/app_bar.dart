import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final DateTime selectedDate;

  const CustomAppBar({super.key, required this.selectedDate});

  String _resolveTitle() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final current = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    if (current == today) return '오늘은...';
    if (current == tomorrow) return '내일은...';
    return DateFormat('yyyy.MM.dd').format(selectedDate);
  }

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final current = DateTime(selectedDate.year, selectedDate.month, selectedDate.day); // 추가

    return AppBar(
      title: Text(_resolveTitle()),
      centerTitle: true,
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () => Scaffold.of(context).openDrawer(),
      ),
      actions: [
        IconButton(
          icon: Icon(current == today          // 아이콘 분기
              ? Icons.toggle_on_outlined
              : Icons.toggle_off_outlined),
          onPressed: () {
            final target = current == today
                ? today.add(const Duration(days: 1))
                : today;

            final dateString = DateFormat('yyyy-MM-dd').format(target);
            Navigator.pushReplacementNamed(context, '/$dateString');
          },
        ),
      ],
    );
  }

  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}