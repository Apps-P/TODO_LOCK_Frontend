import 'dart:developer';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:todo_and_lock/theme/sliding_toggle.dart';
import 'package:flutter/cupertino.dart';

class TodoEditCreatePage extends StatefulWidget {
  final Todo? todo; // null이면 Create, 아니면 Edit
  final DateTime initialDate;

  const TodoEditCreatePage({super.key, this.todo, required this.initialDate});

  @override
  State<TodoEditCreatePage> createState() => _TodoEditCreatePageState();
}

class _TodoEditCreatePageState extends State<TodoEditCreatePage> {
  final _contentController = TextEditingController();
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
    _selectedMinutes = widget.todo?.duration.inMinutes.remainder(60) ?? 10; // 기본 10분
    _selectedHours = widget.todo?.duration.inHours ?? 0;
    _isLocked = widget.todo?.lock ?? false;
  }

  /// 날짜가 변경되었을 때 이전 날짜의 no를 재정렬하는 함수
  void _reorderOldDate(DateTime oldDate) {
    final oldTodos = _todoBox.values
        .where((t) => isSameDay(t.date, oldDate))
        .toList()
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
    if (_contentController.text.isEmpty) return;

    if (widget.todo == null) {
      // [CREATE]
      final newTodo = Todo(
        content: _contentController.text,
        lock: _isLocked, // 3. 설정된 Lock 값 반영
        duration: Duration(minutes: _selectedMinutes, hours: _selectedHours),
      )
        ..date = _selectedDate
        ..user_id = "user_1"
        ..no = _getNextNo(_selectedDate);

      await _todoBox.add(newTodo);
    } else {
      // [EDIT]
      final todo = widget.todo!;
      final oldDate = todo.date;

      todo.content = _contentController.text;
      todo.duration = Duration(minutes: _selectedMinutes, hours: _selectedHours);
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


    log("========= Hive Todo List Check =========");
    log("Total count: ${_todoBox.length}");

    for (int i = 0; i < _todoBox.length; i++) {
      final todo = _todoBox.getAt(i);
      if (todo != null) {
        // todo.id가 UUID 등으로 정의되어 있다면 출력됩니다.
        log("Index[$i] | Hive Key: ${_todoBox.keyAt(i)} | Todo ID: ${todo.id} | Content: ${todo.content}");
      }
    }
    log("========================================");
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.todo == null ? "Todo 생성" : "Todo 수정")),
      body: Padding(
        padding: const EdgeInsets.all(10.0),

        child: Container(
          padding: EdgeInsets.symmetric(vertical: 40),
          child: Column(
            children: [

              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // 시간
                  SizedBox(
                    width: 80,
                    height: 150,
                    child: // 시간 picker
                    ListWheelScrollView(
                      controller: FixedExtentScrollController(initialItem: _selectedHours),
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
                  const Text(" : ", style: TextStyle(fontSize: 40, fontWeight: FontWeight.bold)),
                  // 분
                  SizedBox(
                    width: 80,
                    height: 150,
                    child: ListWheelScrollView(
                      controller: FixedExtentScrollController(initialItem: _selectedMinutes),
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
              const SizedBox(height: 50,),


              // Todo typo
              ListTile(
                title: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      "Todo",
                      style: TextStyle(fontSize: 16, fontWeight: FontWeight.w400),
                    ),

                    TextField(  // 👈 Expanded 제거
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                decoration: BoxDecoration(
                  border: Border(
                    bottom: BorderSide(
                      color: AppColors.carrot.withAlpha(50),
                      width: 0.5,
                      style: BorderStyle.solid, // solid, none
                    ),
                  ),
                ),
              ),

              // 5. Lock 상태 체크박스 추가

              ListTile(
                title: const Text("항목 잠금 (Lock)"),
                subtitle: const Text("잠구기"),
                trailing: SlidingToggle(
                  value: _isLocked,
                  onChanged: (bool value) {
                    setState(() => _isLocked = value);
                  },
                  beginColor: AppColors.white,
                  endColor: AppColors.carrot,
                ),
              ),
              SizedBox(height: 10,),
              ElevatedButton(
                onPressed: _onSave,
                style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50),
                  backgroundColor: AppColors.carrot,
                ),
                child: const Text("저장하기",
                    style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500)),
              )
            ],
          ),
        ),
      ),
    );
  }
}