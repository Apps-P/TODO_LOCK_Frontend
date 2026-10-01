import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'func.dart';
import '../../edit/edit_create_view.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:todo_and_lock/my_flutter_app_icons.dart';
import 'package:todo_and_lock/services/lock_bridge.dart';
import 'package:todo_and_lock/services/local_todo_controller.dart';

class TodoListView extends StatefulWidget {
  final DateTime selectedDate;
  const TodoListView({super.key, required this.selectedDate});

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  late Box<Todo> _todoBox;
  Timer? _timer;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    _todoBox = Hive.box<Todo>('todos');

    // 1초마다 업데이트 로직 실행
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // 1. 상태 업데이트 (Hive DB 등)
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Reorder 로직: 손으로 순서 바꿀 때 호출 및 no 재할당
  void _onReorder(List<Todo> todos, int oldIndex, int newIndex) {
    final Todo item = todos.removeAt(oldIndex);
    todos.insert(newIndex, item);

    for (int i = 0; i < todos.length; i++) {
      todos[i].no = i + 1;
      todos[i].save();
    }
    if (mounted) setState(() {});
  }

  /// Delete 로직: 삭제 후 나머지 no 재정렬
  void _onDelete(List<Todo> todos, int index) async {
    final todo = todos[index];
    await todo.delete();

    todos.removeAt(index);
    for (int i = 0; i < todos.length; i++) {
      todos[i].no = i + 1;
      await todos[i].save();
    }
    if (mounted) setState(() {});
  }

  Future<void> _toggleTodo(Todo todo) async {
    if (_starting) return;
    _starting = true;
    try {
      if (!todo.lock && todo.checkTime != null) {
        todo.done = false;
        todo.checkTime = null;
        await todo.save();
        return;
      }
      if (todo.checkTime != null) return;
      if (todo.lock) {
        if (!LockBridge.supported) {
          throw StateError('화면 잠금은 Android에서 사용할 수 있습니다.');
        }
        if (await LockBridge.current() != null ||
            await FlutterOverlayWindow.isActive()) {
          throw StateError('이미 진행 중인 잠금이 있습니다.');
        }
        if (!await FlutterOverlayWindow.isPermissionGranted()) {
          if (!mounted) return;
          final allow = await showDialog<bool>(
            context: context,
            builder: (context) => AlertDialog(
              title: const Text('화면 잠금 권한'),
              content: const Text('다른 앱 위에 그리기 권한이 필요합니다.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('취소'),
                ),
                TextButton(
                  onPressed: () => Navigator.pop(context, true),
                  child: const Text('설정 열기'),
                ),
              ],
            ),
          );
          if (allow == true) await FlutterOverlayWindow.requestPermission();
          return;
        }
        if (!mounted) return;
        final start = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('집중을 시작할까요?'),
            content: const Text(
              '시간이 끝날 때까지 화면이 잠깁니다. 잠시 해제는 3회 가능하며, 포기하기는 Google Play 결제 완료 후 해제됩니다.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: const Text('취소'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(context, true),
                child: const Text('시작'),
              ),
            ],
          ),
        );
        if (start != true) return;
      }
      await onCheckedTap(todo);
      if (todo.lock) {
        final session = LockBridge.sessionId(todo);
        try {
          await LockBridge.begin(todo);
          await showLockOverlay();
          await FlutterOverlayWindow.shareData({'refresh': true});
        } catch (_) {
          await LockBridge.rollback(session);
          todo.checkTime = null;
          todo.done = false;
          await todo.save();
          rethrow;
        }
      }
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('$error')));
      }
    } finally {
      _starting = false;
      if (mounted) setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _todoBox.listenable(),
      builder: (context, Box<Todo> box, _) {
        // 2. widget.selectedDate를 사용하여 필터링합니다.
        final todos =
            box.values
                .where(
                  (t) =>
                      t.date.year == widget.selectedDate.year &&
                      t.date.month == widget.selectedDate.month &&
                      t.date.day == widget.selectedDate.day,
                )
                .toList()
              ..sort((a, b) => a.no.compareTo(b.no));

        if (todos.isEmpty) {
          return const Center(child: Text("일정이 없습니다."));
        }

        return ReorderableListView.builder(
          itemCount: todos.length,
          // Keep the card margins transparent in the drag overlay.
          proxyDecorator: (child, index, animation) =>
              Material(type: MaterialType.transparency, child: child),
          onReorderItem: (old, next) => _onReorder(todos, old, next),
          itemBuilder: (context, index) =>
              _buildTodoCard(context, todos[index], todos, index),
        );
      },
    );
  }

  /// 개별 Todo 카드 위젯 (Material 컨테이너)
  Widget _buildTodoCard(
    BuildContext context,
    Todo todo,
    List<Todo> currentList,
    int index,
  ) {
    final bool isDeletable =
        todo.checkTime == null || todo.done == true || todo.lock == false;

    /// 오른쪽에서 왼쪽으로 슬라이드 (삭제)
    return Slidable(
      key: ValueKey(todo.id),
      // delete 가능하면 삭제
      endActionPane: isDeletable
          ? ActionPane(
              motion: const ScrollMotion(),
              extentRatio: 0.25,
              dismissible: DismissiblePane(
                onDismissed: () => _onDelete(currentList, index),
              ),
              children: [
                SlidableAction(
                  onPressed: (_) => _onDelete(currentList, index),
                  backgroundColor: Colors.red,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: '삭제',
                  borderRadius: const BorderRadius.horizontal(
                    right: Radius.circular(16),
                  ),
                ),
              ],
            )
          : null, // 아니면 아무것도 안함.

      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: getTodoColor(todo).background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),

        /// check box: check lock
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 8,
          ),
          leading: Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: getCheckboxState(todo),
              activeColor: getTodoColor(todo).background,
              checkColor: getTodoColor(todo).text,
              side: WidgetStateBorderSide.resolveWith(
                (states) => BorderSide(
                  color: getTodoColor(todo).text, // 체크 전/후 동일한 색
                  width: 1.6,
                ),
              ),

              /// 오버레이 생성
              onChanged: (_) => _toggleTodo(todo),
            ),
          ),
          title: Row(
            children: [
              Text(
                formatTimeText(todo),
                style: TextStyle(fontSize: 20, color: getTodoColor(todo).text),
              ),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  todo.content,
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w400,
                    color: getTodoColor(todo).text,
                  ),
                  softWrap: true,
                  overflow: TextOverflow.visible,
                ),
              ),
            ],
          ),

          trailing: IconButton(
            icon: Icon(MyFlutterApp.edit1, color: getTodoColor(todo).text),
            onPressed: () {
              if (todo.done == true || todo.checkTime != null) return;
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => TodoEditCreatePage(
                    todo: todo,
                    initialDate: widget.selectedDate,
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}
