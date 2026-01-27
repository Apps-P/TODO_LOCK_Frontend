import 'package:flutter/material.dart';

class CustomAppBar extends StatelessWidget implements PreferredSizeWidget {
  final String title;

  const CustomAppBar({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return AppBar(
      title: Text(title),
      centerTitle: true,
      // 왼쪽 아이콘: Scaffold의 drawer를 엽니다.
      leading: IconButton(
        icon: const Icon(Icons.menu),
        onPressed: () {
          Scaffold.of(context).openDrawer();
        },
      ),
      // 오른쪽 아이콘: 스위치 모양 아이콘 (기능 없음)
      actions: [
        IconButton(
          icon: const Icon(Icons.toggle_on_outlined),
          onPressed: () {
            // switch today & tomorrow
          },
        ),
      ],
    );
  }

  // AppBar의 표준 높이를 지정합니다.
  @override
  Size get preferredSize => const Size.fromHeight(kToolbarHeight);
}