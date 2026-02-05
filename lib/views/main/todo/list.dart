
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'func.dart';

class TodoListView extends StatelessWidget {
  final Box<Todo> todoBox;
  final DateTime selectedDate;

  const TodoListView({
    super.key,
    required this.todoBox,
    required this.selectedDate,
  });

  @override
  Widget build(BuildContext context) {
    // 1. 해당 날짜의 데이터만 필터링하고 'no' 순으로 정렬
    return ValueListenableBuilder(
      valueListenable: todoBox.listenable(),
      builder: (context, Box<Todo> box, _) {
        final todos = box.values
            .where((todo) =>
        todo.date.year == selectedDate.year &&
            todo.date.month == selectedDate.month &&
            todo.date.day == selectedDate.day)
            .toList();

        // no 순서대로 정렬 (중요: ReorderableListView의 기준)
        todos.sort((a, b) => a.no.compareTo(b.no));

        if (todos.isEmpty) {
          return const Center(child: Text("일정이 없습니다."));
        }

        return ReorderableListView.builder(
          itemCount: todos.length,
          itemBuilder: (context, index) {
            final todo = todos[index];
            return TodoItemTile(
              key: ValueKey(todo.id), // Reorderable에는 고유 키가 필수
              todo: todo,
              onDelete: () => _deleteTodo(todos, index),
            );
          },
          onReorder: (oldIndex, newIndex) => _reorderTodo(todos, oldIndex, newIndex),
        );
      },
    );
  }

  /// 2. Reorder 로직: 손으로 순서 바꿀 때 호출
  void _reorderTodo(List<Todo> todos, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) {
      newIndex -= 1;
    }

    // 리스트 내 순서 변경
    final Todo item = todos.removeAt(oldIndex);
    todos.insert(newIndex, item);

    // 3. 변경된 리스트를 바탕으로 Hive의 'no' 재할당 (1부터 순차적)
    for (int i = 0; i < todos.length; i++) {
      todos[i].no = i + 1;
      todos[i].save();
    }
  }

  /// 4. Delete 로직: 삭제 시 'no' 재정렬
  void _deleteTodo(List<Todo> todos, int index) async {
    final todoToDelete = todos[index];
    await todoToDelete.delete(); // Hive에서 삭제

    // 리스트에서 제거 후 남은 아이템들 no 재할당
    todos.removeAt(index);
    for (int i = 0; i < todos.length; i++) {
      todos[i].no = i + 1;
      await todos[i].save();
    }
  }
}

/// 리스트의 각 항목을 구성하는 위젯 (Material 컨테이너 형태 준비)
class TodoItemTile extends StatelessWidget {
  final Todo todo;
  final VoidCallback onDelete;

  const TodoItemTile({
    super.key,
    required this.todo,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      decoration: BoxDecoration(
        color: getTodoColor(todo), // func.dart의 함수 사용
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(color: Colors.black12, blurRadius: 4, offset: Offset(0, 2)),
        ],
      ),
      child: ListTile(
        leading: Checkbox(
          value: getCheckboxState(todo),
          onChanged: (val) => onCheckedTap(todo),
        ),
        title: Text(
          todo.content,
          style: TextStyle(
            decoration: todo.done ? TextDecoration.lineThrough : null,
          ),
        ),
        subtitle: Text("순서: ${todo.no}"),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              formatTimeText(todo),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}