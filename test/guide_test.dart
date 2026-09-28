import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/duration_adapter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/services/guide_preferences.dart';
import 'package:todo_and_lock/services/lock_bridge.dart';
import 'package:todo_and_lock/theme/app_theme.dart';
import 'package:todo_and_lock/theme/sliding_toggle.dart';
import 'package:todo_and_lock/views/guide/guide_spotlight.dart';
import 'package:todo_and_lock/views/main/main_view.dart';
import 'package:todo_and_lock/views/setting/setting.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Directory directory;
  late Box<Todo> todos;
  final nativeCalls = <String>[];
  final screenshotKey = GlobalKey();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  setUpAll(() async {
    final regular = FontLoader('Paperlogy')
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-4Regular.ttf'))
      ..addFont(rootBundle.load('assets/fonts/Paperlogy-5Medium.ttf'));
    await regular.load();
    await (FontLoader(
      'MaterialIcons',
    )..addFont(rootBundle.load('fonts/MaterialIcons-Regular.otf'))).load();
  });

  setUp(() async {
    directory = await Directory.systemTemp.createTemp('todolock-guide-');
    Hive.init(directory.path);
    if (!Hive.isAdapterRegistered(0)) Hive.registerAdapter(TodoAdapter());
    if (!Hive.isAdapterRegistered(100)) Hive.registerAdapter(DurationAdapter());
    todos = await Hive.openBox<Todo>('todos');
    await Hive.openBox<dynamic>(GuidePreferences.boxName);
    nativeCalls.clear();
    messenger.setMockMethodCallHandler(LockBridge.channel, (call) async {
      nativeCalls.add(call.method);
      return null;
    });
    messenger.setMockMethodCallHandler(
      const MethodChannel('x-slayer/overlay_channel'),
      (call) async {
        nativeCalls.add(call.method);
        return false;
      },
    );
    // Ads use a custom request codec; no native ad view is needed for the tour.
    messenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      (_) async => const StandardMethodCodec().encodeSuccessEnvelope(null),
    );
  });

  tearDown(() async {
    await Hive.close();
    await directory.delete(recursive: true);
    messenger.setMockMethodCallHandler(LockBridge.channel, null);
    messenger.setMockMethodCallHandler(
      const MethodChannel('x-slayer/overlay_channel'),
      null,
    );
    messenger.setMockMessageHandler(
      'plugins.flutter.io/google_mobile_ads',
      null,
    );
  });

  Future<void> flush(WidgetTester tester) async {
    // Disk writes complete outside FakeAsync; alternate real I/O and frames so
    // each awaited Hive write and the navigation it triggers can finish.
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pumpAndSettle();
    }
  }

  Future<void> launch(
    WidgetTester tester, {
    Size size = const Size(390, 844),
    double scale = 1,
  }) async {
    tester.view.devicePixelRatio = 1;
    tester.view.physicalSize = size;
    addTearDown(tester.view.reset);
    addTearDown(() async {
      await tester.pumpWidget(const SizedBox.shrink());
      final closing = Hive.close();
      await flush(tester);
      await closing;
    });
    await tester.pumpWidget(
      RepaintBoundary(
        key: screenshotKey,
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.linear(scale)),
            child: child!,
          ),
          home: MainView(selectedDate: DateTime.now()),
          routes: {'/setting': (_) => const SettingsPage()},
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> next(WidgetTester tester) async {
    final button = find.byKey(const ValueKey('guide-next'));
    await tester.ensureVisible(button);
    await tester.tap(button);
    await tester.pumpAndSettle();
  }

  Future<void> capture(WidgetTester tester, String name) async {
    if (!const bool.fromEnvironment('GUIDE_SCREENSHOTS')) return;
    await tester.runAsync(() async {
      final boundary =
          screenshotKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage(pixelRatio: 2);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      final output = File('build/guide-preview/$name.png');
      await output.parent.create(recursive: true);
      await output.writeAsBytes(bytes!.buffer.asUint8List());
      image.dispose();
    });
  }

  test('guide completion survives reopening local settings', () async {
    expect(GuidePreferences.hasSeenGuide, isFalse);
    await GuidePreferences.markSeen();
    await Hive.box<dynamic>(GuidePreferences.boxName).close();
    await Hive.openBox<dynamic>(GuidePreferences.boxName);
    expect(GuidePreferences.hasSeenGuide, isTrue);
  });

  testWidgets(
    'first run creates one unlocked todo and previews without native lock or billing calls',
    (tester) async {
      await launch(tester);
      expect(find.text('하루의 할 일을 한눈에'), findsOneWidget);
      await capture(tester, '01-home');
      await next(tester);
      await capture(tester, '02-add');
      await tester.tap(find.byType(FloatingActionButton));
      await tester.pumpAndSettle();
      await next(tester);
      expect(find.text('아래 칸에 할 일을 입력한 뒤 다음을 눌러주세요.'), findsOneWidget);
      expect(todos, isEmpty);
      await tester.enterText(find.byType(TextField), '책 10분 읽기');
      tester.view.viewInsets = const FakeViewPadding(bottom: 300);
      await tester.pumpAndSettle();
      await capture(tester, '03-input-keyboard');
      expect(tester.takeException(), isNull);
      tester.view.resetViewInsets();
      await next(tester);
      expect(
        tester.widget<SlidingToggle>(find.byType(SlidingToggle)).value,
        isFalse,
      );
      await capture(tester, '03-lock-off');
      await next(tester);
      await capture(tester, '03-save');
      await tester.tap(find.text('저장하기'));
      await tester.tap(find.text('저장하기'));
      await flush(tester);
      expect(todos.length, 1);
      final todo = todos.values.single;
      expect(todo.lock, isFalse);
      expect(todo.checkTime, isNull);
      expect(todo.done, isFalse);
      expect(find.text('잠금 화면 미리보기'), findsOneWidget);
      await capture(tester, '04-lock-preview');
      await next(tester);
      await capture(tester, '04-temporary');
      // Spotlight prevents tapping preview buttons, even when highlighted.
      await tester.tap(find.text('잠시해제\n0/3'), warnIfMissed: false);
      await next(tester);
      await capture(tester, '04-give-up');
      await tester.tap(find.text('포기하기 (결제)'), warnIfMissed: false);
      expect(nativeCalls, isEmpty);
      await next(tester);
      await flush(tester);
      expect(find.byType(GuideSpotlight), findsNothing);
      expect(find.text('책 10분 읽기'), findsOneWidget);
      expect(GuidePreferences.hasSeenGuide, isTrue);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());

      await launch(tester);
      expect(find.byType(GuideSpotlight), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'skipping persists and settings replays the guide then returns to settings',
    (tester) async {
      await launch(tester);
      await tester.tap(find.text('건너뛰기'));
      await flush(tester);
      expect(GuidePreferences.hasSeenGuide, isTrue);
      expect(todos, isEmpty);
      await tester.tap(find.byIcon(Icons.menu));
      await tester.pumpAndSettle();
      await tester.tap(find.text('설정'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('사용 가이드'));
      await tester.pumpAndSettle();
      expect(find.text('하루의 할 일을 한눈에'), findsOneWidget);
      await tester.tap(find.text('건너뛰기'));
      await flush(tester);
      expect(find.byType(SettingsPage), findsOneWidget);
      expect(find.text('사용 가이드'), findsOneWidget);
      expect(todos, isEmpty);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets(
    'back from creation resumes plus step; skipping creation saves no draft',
    (tester) async {
      await launch(tester);
      await next(tester);
      await next(tester);
      await tester.enterText(find.byType(TextField), '저장하지 않은 초안');
      await tester.binding.handlePopRoute();
      await tester.pumpAndSettle();
      expect(find.text('+ 버튼으로 할 일 추가'), findsOneWidget);
      await next(tester);
      await tester.tap(find.text('건너뛰기'));
      await flush(tester);
      expect(todos, isEmpty);
      expect(GuidePreferences.hasSeenGuide, isTrue);
      expect(find.byType(GuideSpotlight), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );

  testWidgets('small screen and enlarged text keep the tour navigable', (
    tester,
  ) async {
    await launch(tester, size: const Size(320, 568), scale: 1.3);
    await next(tester);
    await next(tester);
    await tester.enterText(find.byType(TextField), '작은 화면 테스트');
    await next(tester);
    await next(tester);
    await next(tester);
    await flush(tester);
    expect(find.text('잠금 화면 미리보기'), findsOneWidget);
    await next(tester);
    await next(tester);
    await capture(tester, 'small-screen');
    await next(tester);
    await flush(tester);
    expect(tester.takeException(), isNull);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}
