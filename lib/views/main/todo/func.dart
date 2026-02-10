
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';

/// 1. 타이머 업데이트 로직 (UI 갱신 필요 여부 반환)
/// 매 초마다 Box를 순회하며 시간이 다 된 항목을 처리합니다.
bool updateTodoStatus(Box<Todo> box) {
  final now = DateTime.now();
  bool needsUiUpdate = false;

  for (var i = 0; i < box.length; i++) {
    final todo = box.getAt(i);
    if (todo == null) continue;

    // 진행 중인 항목(checkTime이 있고 아직 완료되지 않음) 체크
    if (todo.checkTime != null && !todo.done) {
      final elapsed = now.difference(todo.checkTime!);

      if (elapsed >= todo.duration) {
        // 시간이 다 되면 자동으로 완료 처리
        todo.done = true;
        todo.save();
      } else {
        // 아직 진행 중인 항목이 하나라도 있다면 UI를 갱신해야 함
        needsUiUpdate = true;
      }
    }
  }
  return needsUiUpdate;
}

/// 2. 체크박스 탭 로직
void onCheckedTap(Todo todo) {
  final now = DateTime.now();

  if (todo.checkTime == null) {
    // 시작 전 -> 진행 중으로 변경
    todo.checkTime = now;
    todo.done = false;
  }

  todo.save();
}

/// 3. 상태별 배경색 결정
Color getTodoColor(Todo todo) {
  if (todo.done) return Colors.grey[200]!; // 완료: 회색
  if (todo.checkTime != null) return Colors.orange[100]!; // 진행중: 오렌지
  return Colors.white; // 시작 전: 흰색
}

/// 4. 체크박스 UI 상태 (시작 전만 빈 체크박스)
bool getCheckboxState(Todo todo) {
  return todo.checkTime != null;
}

/// 5. 타이머 텍스트 포맷팅 (남은 시간 또는 전체 시간)
String formatTimeText(Todo todo) {
  final now = DateTime.now();
  Duration displayDuration = todo.duration;

  // 진행 중일 때만 '남은 시간' 계산
  if (todo.checkTime != null && !todo.done) {
    final remaining = todo.duration - now.difference(todo.checkTime!);
    displayDuration = remaining.isNegative ? Duration.zero : remaining;
  }

  String twoDigits(int n) => n.toString().padLeft(2, "0");
  String minutes = twoDigits(displayDuration.inMinutes.remainder(60));
  String seconds = twoDigits(displayDuration.inSeconds.remainder(60));

  // 진행 중일 때는 앞에 '+' 또는 '-' 표시를 붙여 구분 가능 (선택 사항)
  final prefix = (todo.checkTime != null && !todo.done) ? "+" : "";
  return "$prefix$minutes:$seconds";
}