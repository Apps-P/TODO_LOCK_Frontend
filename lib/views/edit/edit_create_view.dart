import 'package:todo_and_lock/views/guide/guide_spotlight.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:todo_and_lock/theme/sliding_toggle.dart';

class TodoCreationResult {
  final Todo? todo;
  final bool guideSkipped;
  const TodoCreationResult({this.todo, this.guideSkipped = false});
}

class TodoEditCreatePage extends StatefulWidget {
  final Todo? todo; // null이면 Create, 아니면 Edit
  final DateTime initialDate;
  final bool guideMode;

  const TodoEditCreatePage({
    super.key,
    this.todo,
    required this.initialDate,
    this.guideMode = false,
  }) : assert(!guideMode || todo == null);

  @override
  State<TodoEditCreatePage> createState() => _TodoEditCreatePageState();
}

class _TodoEditCreatePageState extends State<TodoEditCreatePage> {
  final _contentController = TextEditingController();
  final _contentKey = GlobalKey();
  final _lockKey = GlobalKey();
  final _saveKey = GlobalKey();
  final _scrollController = ScrollController();
  late FixedExtentScrollController _hoursController;
  late FixedExtentScrollController _minutesController;
  int _guideStep = 0;
  bool _saving = false;
  bool _guideError = false;
  late DateTime _selectedDate;
  late int _selectedMinutes;
  late int _selectedHours;
  late Box<Todo> _todoBox;
  late bool _isLocked; // 1. Lock 상태 변수 추가

  @override
  void initState() {
    super.initState();
    _todoBox = Hive.box<Todo>('todos');
    _selectedDate = widget.todo?.date ?? widget.initialDate;
    _contentController.text = widget.todo?.content ?? "";
    _selectedMinutes =
        widget.todo?.duration.inMinutes.remainder(60) ?? 10; // 기본 10분
    _selectedHours = widget.todo?.duration.inHours ?? 0;
    _isLocked = widget.todo?.lock ?? false;
    _hoursController = FixedExtentScrollController(initialItem: _selectedHours);
    _minutesController = FixedExtentScrollController(
      initialItem: _selectedMinutes,
    );
    if (widget.guideMode) _showGuideTarget();
  }

  GlobalKey get _guideTarget => switch (_guideStep) {
    0 => _contentKey,
    1 => _lockKey,
    _ => _saveKey,
  };

  void _showGuideTarget() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final target = _guideTarget.currentContext;
      if (target != null) Scrollable.ensureVisible(target, alignment: 0.45);
    });
  }

  void _setGuideStep(int step) {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() {
      _guideStep = step;
      _guideError = false;
    });
    _showGuideTarget();
  }

  void _nextGuideStep() {
    if (_guideStep == 0 && _contentController.text.trim().isEmpty) {
      setState(() => _guideError = true);
      return;
    }
    if (_guideStep < 2) {
      _setGuideStep(_guideStep + 1);
    } else {
      _onSave();
    }
  }

  /// 날짜가 변경되었을 때 이전 날짜의 no를 재정렬하는 함수
  void _reorderOldDate(DateTime oldDate) {
    final oldTodos =
        _todoBox.values.where((t) => isSameDay(t.date, oldDate)).toList()
          ..sort((a, b) => a.no.compareTo(b.no));

    for (int i = 0; i < oldTodos.length; i++) {
      oldTodos[i].no = i + 1;
      oldTodos[i].save();
    }
  }

  /// 특정 날짜의 마지막 no + 1을 반환
  int _getNextNo(DateTime date) {
    final sameDayTodos = _todoBox.values.where((t) => isSameDay(t.date, date));
    if (sameDayTodos.isEmpty) return 1;
    return sameDayTodos.map((t) => t.no).reduce((a, b) => a > b ? a : b) + 1;
  }

  // 같은 날짜?
  bool isSameDay(DateTime a, DateTime b) =>
      a.year == b.year && a.month == b.month && a.day == b.day;

  // 저장
  void _onSave() async {
    if (_saving) return;
    if (_contentController.text.trim().isEmpty ||
        (_selectedHours == 0 && _selectedMinutes == 0)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('할 일 내용과 1분 이상의 시간을 입력해주세요.')),
      );
      return;
    }

    setState(() => _saving = true);
    Todo? savedTodo;
    try {
      if (widget.todo == null) {
        // [CREATE]
        final newTodo =
            Todo(
                content: _contentController.text.trim(),
                lock: widget.guideMode ? false : _isLocked,
                duration: Duration(
                  minutes: _selectedMinutes,
                  hours: _selectedHours,
                ),
              )
              ..date = _selectedDate
              ..userId = "local"
              ..no = _getNextNo(_selectedDate);

        await _todoBox.add(newTodo);
        savedTodo = newTodo;
      } else {
        // [EDIT]
        final todo = widget.todo!;
        savedTodo = todo;
        final oldDate = todo.date;

        todo.content = _contentController.text.trim();
        todo.duration = Duration(
          minutes: _selectedMinutes,
          hours: _selectedHours,
        );
        todo.lock = _isLocked; // 4. 수정된 Lock 값 반영

        if (!isSameDay(oldDate, _selectedDate)) {
          todo.date = _selectedDate;
          todo.no = _getNextNo(_selectedDate);
          await todo.save();
          _reorderOldDate(oldDate);
        } else {
          await todo.save();
        }
      }

      if (mounted) Navigator.pop(context, TodoCreationResult(todo: savedTodo));
    } catch (_) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('저장하지 못했습니다. 다시 시도해주세요.')));
      }
    }
  }

  @override
  void dispose() {
    _contentController.dispose();
    _scrollController.dispose();
    _hoursController.dispose();
    _minutesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screen = Scaffold(
      appBar: AppBar(title: Text(widget.todo == null ? "Todo 생성" : "Todo 수정")),
      body: Padding(
        padding: const EdgeInsets.all(10.0),
        child: SingleChildScrollView(
          controller: _scrollController,
          child: Container(
            padding: EdgeInsets.fromLTRB(0, 40, 0, 0),
            child: Column(
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(
                      width: 80,
                      child: Center(
                        child: Text(
                          "HH",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 24), // " : " 텍스트 너비만큼 간격
                    SizedBox(
                      width: 80,
                      child: Center(
                        child: Text(
                          "MM",
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.black45,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 시간
                    SizedBox(
                      width: 80,
                      height: 150,
                      child: // 시간 picker
                      ListWheelScrollView(
                        controller: _hoursController,
                        itemExtent: 52,
                        perspective: 0.0001,
                        diameterRatio: 100,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedHours = index);
                        },
                        children: List.generate(
                          24,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 44,
                                color: i == _selectedHours
                                    ? Colors.black
                                    : Colors.black26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Text(
                      " : ",
                      style: TextStyle(
                        fontSize: 40,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    // 분
                    SizedBox(
                      width: 80,
                      height: 150,
                      child: ListWheelScrollView(
                        controller: _minutesController,
                        itemExtent: 52,
                        perspective: 0.0001,
                        diameterRatio: 100,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (index) {
                          setState(() => _selectedMinutes = index % 60);
                        },
                        children: List.generate(
                          60,
                          (i) => Center(
                            child: Text(
                              i.toString().padLeft(2, '0'),
                              style: TextStyle(
                                fontSize: 44,
                                color: i == _selectedMinutes
                                    ? Colors.black
                                    : Colors.black26,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 50),

                // Todo typo
                ListTile(
                  title: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        "Todo",
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w400,
                        ),
                      ),

                      TextField(
                        key: _contentKey,
                        onSubmitted: widget.guideMode
                            ? (_) => _nextGuideStep()
                            : null,
                        // 👈 Expanded 제거
                        controller: _contentController,
                        decoration: const InputDecoration(
                          border: InputBorder.none,
                          hintText: "할 일 내용",
                          hintStyle: TextStyle(color: Colors.grey),
                        ),
                      ),
                    ],
                  ),
                ),

                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.carrot.withAlpha(128),
                        width: 0.5,
                        style: BorderStyle.solid, // solid, none
                      ),
                    ),
                  ),
                ),

                // Date selector
                ListTile(
                  title: const Text("날짜 선택"),
                  subtitle: Text("${_selectedDate.toLocal()}".split(' ')[0]),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2000),
                      lastDate: DateTime(2100),
                    );
                    if (picked != null) setState(() => _selectedDate = picked);
                  },
                ),

                Container(
                  height: 1,
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    border: Border(
                      bottom: BorderSide(
                        color: AppColors.carrot.withAlpha(128),
                        width: 0.5,
                        style: BorderStyle.solid, // solid, none
                      ),
                    ),
                  ),
                ),

                // 5. Lock 상태 체크박스 추가
                ListTile(
                  key: _lockKey,
                  title: const Text("항목 잠금 (Lock)"),
                  subtitle: Text(
                    widget.guideMode ? '가이드에서는 잠금 없이 추가해요' : '잠구기',
                  ),
                  trailing: SlidingToggle(
                    value: _isLocked,
                    onChanged: (bool value) {
                      if (!widget.guideMode) setState(() => _isLocked = value);
                    },
                    beginColor: AppColors.white,
                    endColor: AppColors.carrot,
                  ),
                ),
                SizedBox(height: 10),
                ElevatedButton(
                  key: _saveKey,
                  onPressed: _saving ? null : _onSave,
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                    backgroundColor: AppColors.carrot,
                  ),
                  child: const Text(
                    "저장하기",
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
    if (!widget.guideMode) return screen;
    return GuideSpotlight(
      targetKey: _guideTarget,
      step: 3,
      title: switch (_guideStep) {
        0 => '첫 할 일을 적어보세요',
        1 => '잠금은 꺼둔 채로',
        _ => '이제 저장해볼까요?',
      },
      description: switch (_guideStep) {
        0 =>
          _guideError
              ? '아래 칸에 할 일을 입력한 뒤 다음을 눌러주세요.'
              : '예: 책 10분 읽기\n직접 입력한 할 일이 목록에 저장돼요. 시간은 기본 10분으로 시작해요.',
        1 =>
          '항목 잠금이 꺼져 있어요. 이번 할 일은 화면을 잠그지 않아요.\n나중에 할 일을 수정하면서 시간과 잠금을 바꿀 수 있어요.',
        _ => '저장하기를 눌러 할 일을 추가하세요.\n저장 후에는 잠금 화면의 디자인과 버튼을 미리 살펴볼게요.',
      },
      nextLabel: _guideStep == 2 ? '저장하고 계속' : '다음',
      onNext: _nextGuideStep,
      onBack: _guideStep > 0
          ? () => _setGuideStep(_guideStep - 1)
          : () => Navigator.pop(context),
      onSkip: () {
        if (!_saving) {
          Navigator.pop(context, const TodoCreationResult(guideSkipped: true));
        }
      },
      interactive: _guideStep != 1,
      child: screen,
    );
  }
}
