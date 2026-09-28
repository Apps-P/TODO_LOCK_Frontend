import 'package:flutter/material.dart';
import 'package:todo_and_lock/services/guide_preferences.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:todo_and_lock/views/calendar/calender.dart';
import 'package:todo_and_lock/views/edit/edit_create_view.dart';
import 'package:todo_and_lock/views/guide/guide_spotlight.dart';
import 'package:todo_and_lock/views/guide/lock_guide_page.dart';
import 'package:todo_and_lock/views/main/todo/view.dart';
import 'app_bar.dart';
import 'banner.dart';

class MainView extends StatefulWidget {
  final DateTime selectedDate;
  final bool replayGuide;
  const MainView({
    super.key,
    required this.selectedDate,
    this.replayGuide = false,
  });

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  final _homeKey = GlobalKey();
  final _addKey = GlobalKey();
  int? _guideStep;
  bool _opening = false;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    if (widget.replayGuide || !GuidePreferences.hasSeenGuide) _guideStep = 0;
  }

  Future<void> _finishGuide() async {
    if (_finishing) return;
    _finishing = true;
    try {
      await GuidePreferences.markSeen();
      if (!mounted) return;
      setState(() => _guideStep = null);
      if (widget.replayGuide) {
        // Wait until PopScope has rebuilt before closing the replay route.
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) Navigator.pop(context);
        });
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('가이드 상태를 저장하지 못했습니다. 다시 시도해주세요.')),
        );
      }
    } finally {
      _finishing = false;
    }
  }

  Future<void> _openCreate() async {
    if (_opening) return;
    _opening = true;
    try {
      final guiding = _guideStep != null;
      final result = await Navigator.push<TodoCreationResult>(
        context,
        MaterialPageRoute(
          builder: (_) => TodoEditCreatePage(
            initialDate: widget.selectedDate,
            guideMode: guiding,
          ),
        ),
      );
      if (!mounted || !guiding) return;
      if (result?.guideSkipped == true) {
        await _finishGuide();
      } else if (result?.todo != null) {
        await Navigator.push<void>(
          context,
          MaterialPageRoute(builder: (_) => LockGuidePage(todo: result!.todo!)),
        );
        if (mounted) await _finishGuide();
      }
    } finally {
      _opening = false;
    }
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      appBar: CustomAppBar(
        selectedDate: widget.selectedDate,
        titleKey: _homeKey,
      ),
      body: TodoListView(selectedDate: widget.selectedDate),
      bottomNavigationBar: const BannerAdWidget(),
      floatingActionButton: FloatingActionButton(
        key: _addKey,
        tooltip: '할 일 추가',
        onPressed: _openCreate,
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
                    builder: (_) =>
                        CalendarView(selectedDate: widget.selectedDate),
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
    if (_guideStep == null) return screen;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) {
          if (_guideStep == 1) {
            setState(() => _guideStep = 0);
          } else {
            _finishGuide();
          }
        }
      },
      child: GuideSpotlight(
        targetKey: _guideStep == 0 ? _homeKey : _addKey,
        step: _guideStep! + 1,
        title: _guideStep == 0 ? '하루의 할 일을 한눈에' : '+ 버튼으로 할 일 추가',
        description: _guideStep == 0
            ? '이곳은 첫 화면이에요. 선택한 날짜의 할 일을 확인할 수 있어요.\n함께 첫 할 일을 추가해볼까요?'
            : '아래 + 버튼을 누르면 새로운 할 일을 만들 수 있어요.\n이번에는 잠금 없이 직접 추가해볼게요.',
        nextLabel: _guideStep == 0 ? '다음' : '할 일 추가하기',
        onNext: _guideStep == 0
            ? () => setState(() => _guideStep = 1)
            : _openCreate,
        onBack: _guideStep == 1 ? () => setState(() => _guideStep = 0) : null,
        onSkip: _finishGuide,
        interactive: _guideStep == 1,
        child: screen,
      ),
    );
  }
}
