import 'package:flutter/material.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:todo_and_lock/views/calendar/calender.dart';
import 'package:todo_and_lock/views/edit/edit_create_view.dart';
import 'package:todo_and_lock/views/main/todo/view.dart';
import 'app_bar.dart';
import 'banner.dart';

class MainView extends StatelessWidget {
  final DateTime selectedDate;
  const MainView({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: CustomAppBar(selectedDate: selectedDate),
    body: TodoListView(selectedDate: selectedDate),
    bottomNavigationBar: const BannerAdWidget(),
    floatingActionButton: FloatingActionButton(
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(
          builder: (_) => TodoEditCreatePage(initialDate: selectedDate),
        ),
      ),
      backgroundColor: AppColors.carrot,
      child: const Icon(Icons.add_outlined),
    ),
    floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    drawer: Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: AppColors.listbg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.checklist, size: 40),
                SizedBox(height: 16),
                Text('TODOnLOCK', style: TextStyle(fontSize: 24)),
                Text('할 일은 이 기기에 저장됩니다.'),
              ],
            ),
          ),
          ListTile(
            leading: const Icon(Icons.settings),
            title: const Text('설정'),
            onTap: () {
              Navigator.pop(context);
              Navigator.pushNamed(context, '/setting');
            },
          ),
          ListTile(
            leading: const Icon(Icons.calendar_month_outlined),
            title: const Text('캘린더'),
            onTap: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                MaterialPageRoute<void>(
                  builder: (_) => CalendarView(selectedDate: selectedDate),
                ),
              );
            },
          ),
          ListTile(
            leading: const Icon(Icons.emoji_events),
            title: const Text('업적'),
            onTap: () {
              Navigator.pop(context);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text('업적 페이지는 업데이트 예정입니다.')),
              );
            },
          ),
        ],
      ),
    ),
  );
}
