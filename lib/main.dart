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
import 'package:todo_and_lock/views/calendar/calender.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'dart:developer';


void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
  await Hive.initFlutter();

  Hive.registerAdapter(TodoAdapter());
  Hive.registerAdapter(DurationAdapter());
  await Hive.openBox<Todo>('todos');

  runApp(const MyApp());
}


@pragma("vm:entry-point")
void overlayMain() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Hive.initFlutter();

  if (!Hive.isAdapterRegistered(0)) {
    Hive.registerAdapter(TodoAdapter());
    Hive.registerAdapter(DurationAdapter());
  }
  runApp(
    const MaterialApp(
      debugShowCheckedModeBanner: false,
      home: OverlayDataHandler(),
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

    if (id.isEmpty) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
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

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Todo Lock',
      theme: AppTheme.lightTheme,
      initialRoute: '/${DateFormat('yyyy-MM-dd').format(DateTime.now())}',
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/')) {
          final dateString = settings.name!.substring(1);

          try {
            final selectedDate = DateTime.parse(dateString);

            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => MainView(selectedDate: selectedDate),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, __, ___, child) => child,
            );
          } catch (e) {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, __, ___) => MainView(selectedDate: DateTime.now()),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, __, ___, child) => child,
            );
          }
        }
        return null;
      },
      routes: {
        '/create': (_) => TodoEditCreatePage(todo: null, initialDate: DateTime.now()),
        '/calendar': (_) => CalendarView(selectedDate: DateTime.now()),
      },
    );
  }
}