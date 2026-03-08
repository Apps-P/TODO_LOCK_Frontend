import 'app_bar.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:todo_and_lock/views/main/todo/view.dart';

class MainView extends StatelessWidget {
  final DateTime selectedDate;
  const MainView({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: CustomAppBar(selectedDate: selectedDate),
      body: TodoListView(selectedDate: selectedDate),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create');
        },
        backgroundColor: AppColors.carrot,
        child: const Icon(Icons.add_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.all(0),
          children: [
            UserAccountsDrawerHeader(
              currentAccountPicture: const CircleAvatar(
                backgroundColor: Colors.white,
                child: Icon(Icons.person, color: Colors.blue),
              ),
              accountName: const Text("홍길동", style: TextStyle(color: AppColors.black100)),
              accountEmail: const Text("gmail.com", style: TextStyle(color: AppColors.black80)),
              decoration: const BoxDecoration(color: AppColors.listbg),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/setting');
              },
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.settings),
                title: Text("설정"),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/calendar');
              },
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.calendar_month_outlined),
                title: Text("캘린더"),
              ),
            ),
            InkWell(
              onTap: () => Navigator.pop(context),
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.emoji_events),
                title: Text("업적"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}