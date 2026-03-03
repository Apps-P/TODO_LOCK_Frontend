
import 'app_bar.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:todo_and_lock/views/main/todo/view.dart';
import 'package:intl/intl.dart';




class MainView extends StatelessWidget {

  final DateTime selectedDate; // 라우트에서 넘겨받은 날짜
  const MainView({super.key, required this.selectedDate});

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final tomorrow = today.add(const Duration(days: 1));
    final compareDate = DateTime(selectedDate.year, selectedDate.month, selectedDate.day);

    String titleWidget;

    if (compareDate == today) {
      titleWidget = "오늘은...";
    } else if (compareDate == tomorrow) {
      titleWidget = "내일은...";
    } else {
      titleWidget = DateFormat('yyyy.MM.dd').format(selectedDate);
    }
    return Scaffold(
      appBar: CustomAppBar(
        title:titleWidget,
      ),

      body: TodoListView(selectedDate: selectedDate),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 새 할 일 추가 페이지로 이동
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
                  child: Icon(Icons.person, color: Colors.blue,),

                ),
                accountName: const Text("홍길동", style: TextStyle(color: AppColors.black100),) ,
                accountEmail: const Text("gmail.com", style: TextStyle(color: AppColors.black80)),
                decoration: BoxDecoration(
                  color: AppColors.listbg
                ),
            ),

            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              splashColor: AppColors.black40, // 커스텀 물결 색상
              child: const ListTile(
                leading: Icon(Icons.settings),
                title: Text("설정"),
              ),
            ),

            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              splashColor: AppColors.black40, // 커스텀 물결 색상
              child: const ListTile(
                leading:  Icon(Icons.calendar_month_outlined),
                title: Text("캘린더"),
              ),
            ),


            InkWell(
              onTap: () {
                Navigator.pop(context);
              },
              splashColor: AppColors.black40, // 커스텀 물결 색상
              child: const ListTile(
                leading:  Icon(Icons.emoji_events),
                title: Text("업적"),
              ),
            ),

          ],
        ),
      ),
    );
  }
}
