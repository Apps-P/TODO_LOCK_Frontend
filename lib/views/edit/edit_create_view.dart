import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:todo_and_lock/models/todo_model.dart';

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
  late Box<Todo> _todoBox;
  late bool _isLocked; // 1. Lock 상태 변수 추가

  @override
  void initState() {
    super.initState();
    _todoBox = Hive.box<Todo>('todos');
    _selectedDate = widget.todo?.date ?? widget.initialDate;
    _contentController.text = widget.todo?.content ?? "";
    _selectedMinutes = widget.todo?.duration.inMinutes ?? 10; // 기본 10분
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
        duration: Duration(minutes: _selectedMinutes),
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
      todo.duration = Duration(minutes: _selectedMinutes);
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
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.todo == null ? "Todo 생성" : "Todo 수정")),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          children: [
            TextField(
              controller: _contentController,
              decoration: const InputDecoration(labelText: "할 일 내용"),
            ),
            const SizedBox(height: 20),
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
            const SizedBox(height: 20),
            Row(
              children: [
                const Text("목표 시간(분): "),
                Expanded(
                  child: Slider(
                    value: _selectedMinutes.toDouble(),
                    min: 1,
                    max: 120,
                    divisions: 120,
                    label: "$_selectedMinutes분",
                    onChanged: (v) => setState(() => _selectedMinutes = v.toInt()),
                  ),
                ),
                Text("$_selectedMinutes분"),


              ],
            ),
            // 5. Lock 상태 체크박스 추가

            CheckboxListTile(
              title: const Text("항목 잠금 (Lock)"),
              subtitle: const Text("잠구기"),
              value: _isLocked,
              controlAffinity: ListTileControlAffinity.leading, // 체크박스를 왼쪽으로
              onChanged: (bool? value) {
                setState(() {
                  _isLocked = value ?? false;
                });
              },
            ),

            const Spacer(),
            ElevatedButton(
              onPressed: _onSave,
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
              child: const Text("저장하기"),
            )
          ],
        ),
      ),
    );
  }
}