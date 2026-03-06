import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';
import 'func.dart';
import '../../edit/edit_create_view.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:todo_and_lock/my_flutter_app_icons.dart';
import 'dart:developer';



class TodoListView extends StatefulWidget {
  final DateTime selectedDate;
  const TodoListView({super.key, required this.selectedDate});


  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  late Box<Todo> _todoBox;
  Timer? _timer;
  String? _activeOverlayId;

  @override
  void initState() {
    super.initState();
    _todoBox = Hive.box<Todo>('todos');


    // 1초마다 업데이트 로직 실행
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) async {
      // 1. 상태 업데이트 (Hive DB 등)
      bool hasChanged = updateTodoStatus(_todoBox);
      if (hasChanged && mounted) setState(() {});

    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// Reorder 로직: 손으로 순서 바꿀 때 호출 및 no 재할당
  void _onReorder(List<Todo> todos, int oldIndex, int newIndex) {
    if (oldIndex < newIndex) newIndex -= 1;

    final Todo item = todos.removeAt(oldIndex);
    todos.insert(newIndex, item);

    for (int i = 0; i < todos.length; i++) {
      todos[i].no = i + 1;
      todos[i].save();
    }
    setState(() {});
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
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: _todoBox.listenable(),
      builder: (context, Box<Todo> box, _) {
        // 2. widget.selectedDate를 사용하여 필터링합니다.
        final todos = box.values
            .where((t) =>
        t.date.year == widget.selectedDate.year &&
            t.date.month == widget.selectedDate.month &&
            t.date.day == widget.selectedDate.day)
            .toList()
          ..sort((a, b) => a.no.compareTo(b.no));

        if (todos.isEmpty) {
          return const Center(child: Text("일정이 없습니다."));
        }

        return ReorderableListView.builder(
          itemCount: todos.length,
          onReorder: (old, next) => _onReorder(todos, old, next),
          itemBuilder: (context, index) => _buildTodoCard(context, todos[index], todos, index),
        );
      },
    );
  }

  /// 개별 Todo 카드 위젯 (Material 컨테이너)
  Widget _buildTodoCard(BuildContext context, Todo todo, List<Todo> currentList, int index) {
    return Slidable(
      key: ValueKey(todo.id),
      /// 오른쪽에서 왼쪽으로 슬라이드 (삭제)
      endActionPane: ActionPane(
        motion: const ScrollMotion(),
        extentRatio: 0.25,
        dismissible: DismissiblePane(onDismissed: () => _onDelete(currentList, index)),
        children: [
          SlidableAction(
            onPressed: (_) => _onDelete(currentList, index),
            backgroundColor: Colors.red,
            foregroundColor: Colors.white,
            icon: Icons.delete,
            label: '삭제',
            borderRadius: const BorderRadius.horizontal(right: Radius.circular(16)),
          ),
        ],
      ),

      child: Container(
        // key: ValueKey(todo.id), // Slidable로 이동했으므로 제거
        margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
        decoration: BoxDecoration(
          color: getTodoColor(todo).background,
          borderRadius: BorderRadius.circular(16),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ],
        ),


        /// check box: check lock
        child: ListTile(
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          leading: Transform.scale(
            scale: 1.2,
            child: Checkbox(
              value: getCheckboxState(todo),
              activeColor: getTodoColor(todo).background,
              checkColor: getTodoColor(todo).text,
              side: WidgetStateBorderSide.resolveWith(
                    (states) => BorderSide(
                  color: getTodoColor(todo).text,  // 체크 전/후 동일한 색
                  width: 1.6,
                ),
              ),

              /// 오버레이 생성
              onChanged: (_) async{
                onCheckedTap(todo);
                setState(() {});
                if(todo.lock == false || todo.done == true) return;

                // 권한 확인
                final status = await FlutterOverlayWindow.isPermissionGranted();
                if(status == false) {
                  await FlutterOverlayWindow.requestPermission();
                  return;
                }

                if (await FlutterOverlayWindow.isActive()) return;

                await FlutterOverlayWindow.showOverlay(
                  enableDrag: false,
                  overlayTitle: "overlay test",
                  overlayContent: 'Overlay Enabled',
                  flag: OverlayFlag.defaultFlag,
                  visibility: NotificationVisibility.visibilityPublic,
                  positionGravity: PositionGravity.auto,
                  height: WindowSize.matchParent,
                  width: WindowSize.matchParent,
                  startPosition: const OverlayPosition(0, 0),
                );


                await FlutterOverlayWindow.shareData({
                  'id': todo.id,
                  'contents': todo.content,
                  'duration': todo.duration.inSeconds,
                  'checkTime': todo.checkTime?.toIso8601String() ?? '',
                });
              },

            ),
          ),
          title: Row(
            children: [
              Text(
                formatTimeText(todo),
                style: TextStyle(
                  fontSize: 20,
                  color: getTodoColor(todo).text,
                ),
              ),
              SizedBox(width: 8,),
              Text(
                todo.content,
                style: TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.w400,
                  color: getTodoColor(todo).text,
                ),
              ),
            ],
          ),

          trailing:
              IconButton(
                icon: Icon(MyFlutterApp.edit1, color: getTodoColor(todo).text),
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => TodoEditCreatePage(
                      todo: todo,
                      initialDate: widget.selectedDate,
                    ),
                  ),
                ),
              ),
        ),
      ),
    );
  }
}