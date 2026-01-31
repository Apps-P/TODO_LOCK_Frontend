import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/theme/app_theme.dart';
import 'package:todo_and_lock/views/edit/todo_edit_view.dart';
import 'package:todo_and_lock/views/lock/lock_overlay_view.dart';
import 'package:todo_and_lock/views/main/todo_list_view.dart';
import 'package:todo_and_lock/views/main/main_view.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 모델 어댑터 등록
  Hive.registerAdapter(TodoAdapter());

  // Duration 어댑터 등록
  Hive.registerAdapter(DurationAdapter());

  runApp(const MyApp());
}


@pragma("vm:entry-point")
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: LockOverlayView(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Lock',
      theme: AppTheme.lightTheme,
      initialRoute: '/',
      // 라우트 테이블
      routes: {
        '/': (_) => const MainView(),
        '/edit': (_) => const TodoEditView(),
        '/read': (_) => const TodoListView(),
      },
    );
  }
}
