import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:intl/intl.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/theme/app_theme.dart';
import 'package:todo_and_lock/views/lock/lock_overlay_view.dart';
import 'package:todo_and_lock/views/edit/edit_create_view.dart';
import 'package:todo_and_lock/views/main/main_view.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'dart:developer';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Hive.initFlutter();

  // 모델 어댑터 등록
  Hive.registerAdapter(TodoAdapter());

  // Duration 어댑터 등록
  Hive.registerAdapter(DurationAdapter());

  // Hive.box('todos') 로 접근.
  await Hive.openBox<Todo>('todos');

  runApp(const MyApp());
}


// ------------------------------------------------------------------
// overlay entry (main.dart 하단 혹은 별도 파일)
// ------------------------------------------------------------------
@pragma("vm:entry-point")
void overlayMain() async{
  WidgetsFlutterBinding.ensureInitialized();

  // Hive 초기화 및 어댑터 등록
  await Hive.initFlutter();

  // TodoAdapter 등록
  if (!Hive.isAdapterRegistered(0)) {  // typeId 확인
    Hive.registerAdapter(TodoAdapter());
    Hive.registerAdapter(DurationAdapter());
  }
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayDataHandler(), // 바로 View를 띄우지 않고 Handler를 거침
    ),
  );
}

class OverlayDataHandler extends StatefulWidget {
  const OverlayDataHandler({super.key});

  @override
  State<OverlayDataHandler> createState() => _OverlayDataHandlerState();
}

class _OverlayDataHandlerState extends State<OverlayDataHandler> {
  String id = "";
  String contents = "할 일 없음";
  Duration duration = Duration.zero;
  DateTime? checkTime;

  // OverlayDataHandler의 initState
  @override
  void initState() {
    super.initState();


    FlutterOverlayWindow.overlayListener.listen((data) {


      if (data != null && data is Map) {
        log("Data is Map, extracting values...");
        setState(() {
          id = data['id'] ?? "";
          log("Extracted id: $id");

          contents = data['contents'] ?? contents;
          log("Extracted contents: $contents");

          duration = Duration(seconds: data['duration'] ?? 0);
          log("Extracted duration: $duration");

          // ISO8601 문자열을 DateTime 객체로 변환
          if (data['checkTime'] != null && data['checkTime'] != '') {
            checkTime = DateTime.parse(data['checkTime']);
            log("Extracted checkTime: $checkTime");
          } else {
            checkTime = null;
            log("checkTime is null or empty");
          }
        });
      } else {
        log("Data is null or not a Map");
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    log("=== OverlayDataHandler build ===");
    log("Building with - id: $id, contents: $contents, duration: $duration, checkTime: $checkTime");

    // 데이터가 아직 안 왔으면 로딩 화면 표시
    if (id.isEmpty) {
      return Scaffold(
        body: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    return LockOverlayView(
      id: id,
      contents: contents,
      checkTime: checkTime,
      duration: duration,
    );
  }
}



class MyApp extends StatelessWidget {
  const MyApp({super.key});

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Lock',
      theme: AppTheme.lightTheme,
      initialRoute: '/${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      onGenerateRoute: (settings) {
        // 1. 경로가 '/'로 시작하는지 확인
        if (settings.name != null && settings.name!.startsWith('/')) {
          final dateString = settings.name!.substring(1); // '/' 제외한 부분 추출

          try {
            // 2. 문자열을 DateTime으로 파싱 (예: 2024-05-20)
            final selectedDate = DateTime.parse(dateString);

            return MaterialPageRoute(
              builder: (context) => MainView(selectedDate: selectedDate),
              settings: settings,
            );
          } catch (e) {
            // 날짜 형식이 아니거나 잘못된 경로일 경우 오늘 날짜로 리다이렉트
            return MaterialPageRoute(
              builder: (context) => MainView(selectedDate: DateTime.now()),
            );
          }
        }
        return null;
      },
      // 라우트 테이블
      routes: {
        '/create': (_) => TodoEditCreatePage(todo: null, initialDate: DateTime.now()),
      },
    );
  }
}
