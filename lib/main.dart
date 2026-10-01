import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'services/guide_preferences.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/theme/app_theme.dart';
import 'package:todo_and_lock/views/lock/lock_overlay_view.dart';
import 'package:todo_and_lock/views/edit/edit_create_view.dart';
import 'package:todo_and_lock/views/main/main_view.dart';
import 'package:todo_and_lock/views/calendar/calender.dart';
import 'package:todo_and_lock/views/setting/setting.dart';
import 'package:todo_and_lock/views/main/achievement.dart';
import 'services/lock_bridge.dart';
import 'services/local_todo_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('ko', null);
  await Hive.initFlutter();
  Hive.registerAdapter(TodoAdapter());
  Hive.registerAdapter(DurationAdapter());
  final box = await Hive.openBox<Todo>('todos');
  await Hive.openBox<dynamic>(GuidePreferences.boxName);
  final controller = LocalTodoController(box);
  runApp(const MyApp());
  await controller.start();
}

@pragma('vm:entry-point')
void overlayMain() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(
    MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const OverlayDataHandler(),
    ),
  );
}

class OverlayDataHandler extends StatefulWidget {
  const OverlayDataHandler({super.key});
  @override
  State<OverlayDataHandler> createState() => _OverlayDataHandlerState();
}

class _OverlayDataHandlerState extends State<OverlayDataHandler> {
  Map<String, dynamic>? _data;
  StreamSubscription<dynamic>? _subscription;
  Timer? _poll;
  bool _reading = false;

  @override
  void initState() {
    super.initState();
    _subscription = FlutterOverlayWindow.overlayListener.listen(
      (_) => _reload(),
    );
    _poll = Timer.periodic(const Duration(seconds: 1), (_) => _reload());
    _reload();
  }

  Future<void> _reload() async {
    if (_reading) return;
    _reading = true;
    try {
      final data = await LockBridge.current();
      if (mounted && data?['session'] != _data?['session']) {
        setState(() => _data = data);
      }
    } catch (error) {
      debugPrint('잠금 상태 확인 실패: $error');
    } finally {
      _reading = false;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _subscription?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data == null) {
      return const Scaffold(body: Center(child: Text('잠금 상태 확인 중…')));
    }
    return LockOverlayView(
      key: ValueKey(data['session']),
      session: data['session'] as String,
      id: data['id'] as String,
      contents: data['contents'] as String,
      checkTime: DateTime.parse(data['checkTime'] as String),
      duration: Duration(seconds: data['duration'] as int),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'TODOnLOCK',
      theme: AppTheme.lightTheme,
      home: MainView(selectedDate: DateTime.now()),
      onGenerateRoute: (settings) {
        if (settings.name != null && settings.name!.startsWith('/')) {
          final dateString = settings.name!.substring(1);

          try {
            final selectedDate = DateTime.parse(dateString);

            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, _, _) => MainView(selectedDate: selectedDate),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, _, _, child) => child,
            );
          } catch (e) {
            return PageRouteBuilder(
              settings: settings,
              pageBuilder: (_, _, _) =>
                  MainView(selectedDate: DateTime.now()),
              transitionDuration: Duration.zero,
              reverseTransitionDuration: Duration.zero,
              transitionsBuilder: (_, _, _, child) => child,
            );
          }
        }
        return null;
      },
      routes: {
        '/create': (_) =>
            TodoEditCreatePage(todo: null, initialDate: DateTime.now()),
        '/calendar': (_) => CalendarView(selectedDate: DateTime.now()),
        '/setting': (_) => SettingsPage(),
        '/achievement': (_) => Achievement(),
      },
    );
  }
}
