import 'package:flutter/material.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/views/lock/lock_ui.dart';
import 'guide_spotlight.dart';

/// Uses only the presentation widget. No lock session, timer, permission
/// request, temporary unlock, or purchase can be started by this preview.
class LockGuidePage extends StatefulWidget {
  final Todo todo;
  const LockGuidePage({super.key, required this.todo});

  @override
  State<LockGuidePage> createState() => _LockGuidePageState();
}

class _LockGuidePageState extends State<LockGuidePage> {
  final _timerKey = GlobalKey();
  final _temporaryKey = GlobalKey();
  final _giveUpKey = GlobalKey();
  int _step = 0;

  void _changeStep(int step) {
    setState(() => _step = step);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _target.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.8);
    });
  }

  GlobalKey get _target => switch (_step) {
    0 => _timerKey,
    1 => _temporaryKey,
    _ => _giveUpKey,
  };

  String _format(Duration duration) {
    String two(int value) => value.toString().padLeft(2, '0');
    return '${two(duration.inMinutes)}:${two(duration.inSeconds.remainder(60))}';
  }

  @override
  Widget build(BuildContext context) => GuideSpotlight(
    targetKey: _target,
    step: 4,
    title: switch (_step) {
      0 => '잠금 화면 미리보기',
      1 => '급할 때는 잠시해제',
      _ => '결제 후 잠금 해제',
    },
    description: switch (_step) {
      0 =>
        '할 일을 저장했어요!\n잠금을 켠 할 일을 시작하면 이런 화면이 나타나요. 남은 시간이 끝날 때까지 집중해요.\n지금은 미리보기라 실제로 잠기지 않아요.',
      1 =>
        '한 번에 2분씩, 최대 3회 잠시 사용할 수 있어요. 2분이 지나면 다시 잠기고, 집중 시간은 계속 흘러가요.\n가이드에서는 버튼이 실행되지 않아요.',
      _ =>
        '집중을 중단하려면 포기하기를 눌러요. Google Play 결제 성공이 확인되어야 잠금이 풀려요. 취소하거나 결제가 완료되지 않으면 잠금이 유지돼요.\n가이드에서는 결제가 발생하지 않아요.',
    },
    nextLabel: _step == 2 ? '마치기' : '다음',
    onNext: () {
      if (_step == 2) {
        Navigator.pop(context);
      } else {
        _changeStep(_step + 1);
      }
    },
    onBack: _step > 0 ? () => _changeStep(_step - 1) : null,
    onSkip: () => Navigator.pop(context),
    child: Scaffold(
      body: Stack(
        children: [
          LockUI(
            remainingTime: widget.todo.duration,
            contents: widget.todo.content,
            duration: widget.todo.duration,
            formatDuration: _format,
            onTempMode: () {},
            onGiveUp: () {},
            tempPressCount: 0,
            timerKey: _timerKey,
            temporaryButtonKey: _temporaryKey,
            giveUpButtonKey: _giveUpKey,
          ),
          const SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  '미리보기 · 실제 잠금과 결제 없음',
                  style: TextStyle(fontSize: 12),
                ),
              ),
            ),
          ),
        ],
      ),
    ),
  );
}
