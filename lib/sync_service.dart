import 'dart:developer';
import 'package:hive/hive.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_and_lock/models/todo_model.dart';

/// ====================================================
/// SyncService
///
/// 동작 규칙:
///   1. 최초 로그인 → 로컬(Hive) 전체를 Supabase로 dump
///   2. 이후 앱 시작(로그인 상태) → merge
///      - 같은 id: Hive 우선 (로컬이 더 최신)
///      - Supabase에만 있는 id: Hive로 내려받기
///      - Hive에만 있는 id: Supabase에 올리기
/// ====================================================
class SyncService {
  static final _supabase = Supabase.instance.client;
  static const _table = 'todos';

  // ── Supabase에 저장되는 컬럼명과 Todo 필드 매핑 ──────────────

  static Map<String, dynamic> _toRow(Todo todo, String userId) => {
    'id': todo.id,                                      // uuid
    'user_id': userId,                                  // uuid
    'date': todo.date.toIso8601String().substring(0, 10), // date (yyyy-MM-dd)
    'no': todo.no,                                      // int4
    'content': todo.content,                            // text
    'lock': todo.lock,                                  // bool
    'check_time': todo.checkTime?.toUtc().toIso8601String(), // timestamptz?
    'duration': _durationToInterval(todo.duration),    // interval
    'done': todo.done,                                  // bool
  };

  static Todo _fromRow(Map<String, dynamic> row) {
    final todo = Todo(
      content: row['content'] as String,
      lock: row['lock'] as bool,
      duration: _intervalToDuration(row['duration'] as String),
      done: row['done'] as bool,
    );
    todo.id = row['id'] as String;
    todo.user_id = row['user_id'] as String;
    todo.date = DateTime.parse(row['date'] as String);
    todo.no = row['no'] as int;
    todo.checkTime = row['check_time'] != null
        ? DateTime.parse(row['check_time'] as String).toLocal()
        : null;
    return todo;
  }

  /// Duration → Postgres interval 문자열 (e.g. "01:30:00")
  static String _durationToInterval(Duration d) {
    final h = d.inHours.toString().padLeft(2, '0');
    final m = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final s = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  /// Postgres interval 문자열 → Duration
  /// Supabase는 interval을 "HH:MM:SS" 또는 "HH:MM:SS.ffffff" 형태로 반환
  static Duration _intervalToDuration(String interval) {
    // "01:30:00" 또는 "01:30:00.000000" 형태 파싱
    final parts = interval.split(':');
    final hours = int.parse(parts[0]);
    final minutes = int.parse(parts[1]);
    final seconds = double.parse(parts[2]).toInt();
    return Duration(hours: hours, minutes: minutes, seconds: seconds);
  }

  // ─────────────────────────────────────────────────────────────
  /// 앱 시작 시 호출. 로그인 여부 확인 후 적절한 동작 수행.
  // ─────────────────────────────────────────────────────────────
  static Future<void> syncOnStartup() async {
    final user = _supabase.auth.currentUser;
    if (user == null) {
      log('[Sync] 로그인 안 됨 → skip');
      return;
    }

    final box = await _openBox();
    final isFirstLogin = await _isFirstLogin(user.id);

    if (isFirstLogin) {
      log('[Sync] 최초 로그인 → dump local to Supabase');
      await _dumpLocalToSupabase(box, user.id);
      await _markFirstLoginDone(user.id);
    } else {
      log('[Sync] 기존 로그인 → merge');
      await _merge(box, user.id);
    }
  }

  // ─────────────────────────────────────────────────────────────
  /// 1. 최초 로그인: 로컬 전체 → Supabase upsert
  // ─────────────────────────────────────────────────────────────
  static Future<void> _dumpLocalToSupabase(
      Box<Todo> box, String userId) async {
    final todos = box.values.toList();
    if (todos.isEmpty) {
      log('[Sync] 로컬 데이터 없음 → dump skip');
      return;
    }

    final rows = todos.map((t) => _toRow(t, userId)).toList();

    try {
      await _supabase.from(_table).upsert(rows);
      log('[Sync] dump 완료: ${rows.length}개');
    } catch (e) {
      log('[Sync] dump 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  /// 2. Merge: Hive ↔ Supabase
  ///    - 같은 id → Hive 우선 (Supabase 덮어쓰기)
  ///    - Supabase에만 있음 → Hive에 추가
  ///    - Hive에만 있음 → Supabase에 upsert
  // ─────────────────────────────────────────────────────────────
  static Future<void> _merge(Box<Todo> box, String userId) async {
    // Supabase에서 해당 유저의 todos 전부 가져오기
    List<Map<String, dynamic>> remoteRows;
    try {
      final response = await _supabase
          .from(_table)
          .select()
          .eq('user_id', userId);
      remoteRows = List<Map<String, dynamic>>.from(response);
    } catch (e) {
      log('[Sync] Supabase fetch 실패: $e');
      return;
    }

    final localMap = {for (var t in box.values) t.id: t};
    final remoteMap = {for (var r in remoteRows) r['id'] as String: r};

    final List<Map<String, dynamic>> toUpsertRemote = [];
    final List<Todo> toAddLocal = [];

    // ── Hive 기준 순회 ──────────────────────────────────────
    for (final localTodo in localMap.values) {
      if (remoteMap.containsKey(localTodo.id)) {
        // 같은 id 존재 → Hive 우선으로 Supabase 덮어쓰기
        toUpsertRemote.add(_toRow(localTodo, userId));
      } else {
        // Hive에만 있음 → Supabase에 올리기
        toUpsertRemote.add(_toRow(localTodo, userId));
      }
    }

    // ── Supabase에만 있는 항목 → Hive에 추가 ────────────────
    for (final remoteRow in remoteRows) {
      final id = remoteRow['id'] as String;
      if (!localMap.containsKey(id)) {
        toAddLocal.add(_fromRow(remoteRow));
      }
    }

    // ── Supabase upsert ──────────────────────────────────────
    if (toUpsertRemote.isNotEmpty) {
      try {
        await _supabase.from(_table).upsert(toUpsertRemote);
        log('[Sync] Supabase upsert: ${toUpsertRemote.length}개');
      } catch (e) {
        log('[Sync] Supabase upsert 실패: $e');
      }
    }

    // ── Hive 추가 ────────────────────────────────────────────
    for (final todo in toAddLocal) {
      await box.put(todo.id, todo);
    }
    if (toAddLocal.isNotEmpty) {
      log('[Sync] Hive에 추가: ${toAddLocal.length}개');
    }

    log('[Sync] merge 완료');
  }

  // ─────────────────────────────────────────────────────────────
  /// 단건 dirty 저장 (Todo 변경 시마다 호출)
  // ─────────────────────────────────────────────────────────────
  static Future<void> pushTodo(Todo todo) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from(_table).upsert(_toRow(todo, user.id));
      log('[Sync] pushTodo: ${todo.id}');
    } catch (e) {
      log('[Sync] pushTodo 실패: $e');
    }
  }

  /// Todo 삭제 시 Supabase에서도 삭제
  static Future<void> deleteTodo(String todoId) async {
    final user = _supabase.auth.currentUser;
    if (user == null) return;

    try {
      await _supabase.from(_table).delete().eq('id', todoId);
      log('[Sync] deleteTodo: $todoId');
    } catch (e) {
      log('[Sync] deleteTodo 실패: $e');
    }
  }

  // ─────────────────────────────────────────────────────────────
  // 내부 유틸
  // ─────────────────────────────────────────────────────────────

  static Future<Box<Todo>> _openBox() async {
    if (Hive.isBoxOpen('todos')) return Hive.box<Todo>('todos');
    return await Hive.openBox<Todo>('todos');
  }

  /// 최초 로그인 여부: Supabase에 해당 유저 row가 하나도 없으면 최초
  static Future<bool> _isFirstLogin(String userId) async {
    try {
      final response = await _supabase
          .from(_table)
          .select('id')
          .eq('user_id', userId)
          .limit(1);
      return (response as List).isEmpty;
    } catch (e) {
      log('[Sync] _isFirstLogin 확인 실패: $e');
      return false;
    }
  }

  /// 최초 로그인 완료 마킹 (더미 - 실제로는 row가 생기므로 자동 처리)
  static Future<void> _markFirstLoginDone(String userId) async {
    log('[Sync] 최초 로그인 마킹 완료 (userId: $userId)');
  }
}