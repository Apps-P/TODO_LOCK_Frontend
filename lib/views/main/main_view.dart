import 'dart:developer';
import 'dart:isolate';
import 'dart:ui';
import 'app_bar.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'todo_list_view.dart';




class MainView extends StatelessWidget {
  const MainView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const CustomAppBar(title: '오늘 할 일',),

      body: TodoListView(),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          // 새 할 일 추가 페이지로 이동
          Navigator.pushNamed(context, '/edit');
        },
        backgroundColor: AppColors.carrot, // 원하는 색상으로 변경 가능
        child: const Icon(Icons.add_outlined),
      ),

      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,

      // For overlay test. only in android vm. 차후에 삭제합시다.
      bottomNavigationBar: BottomAppBar(
        child: ElevatedButton(onPressed: ()async {
          final status = await FlutterOverlayWindow.isPermissionGranted();
          log("Is Permission Granted: $status");
          if(status == false) {
            await FlutterOverlayWindow.requestPermission();
            log("req permission");
            return;
          }

          if (await FlutterOverlayWindow.isActive()) return;
          await FlutterOverlayWindow.showOverlay(
            enableDrag: false,
            overlayTitle: "overlay test",
            overlayContent: 'Overlay Enabled',
            flag: OverlayFlag.defaultFlag,
            visibility: NotificationVisibility.visibilityPublic,
            positionGravity: PositionGravity.auto,
            height: WindowSize.matchParent,
            width: WindowSize.matchParent,
            startPosition: const OverlayPosition(0, 0),
          );
        }, child: const Text("Show Overlay")
        ),
      ),


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
