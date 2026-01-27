import 'dart:async';
import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/models/job_model.dart';

class TodoListView extends StatefulWidget {
  const TodoListView({super.key});

  @override
  State<TodoListView> createState() => _TodoListViewState();
}

class _TodoListViewState extends State<TodoListView> {
  Timer? _timer;
  final Box<Job> _box = Hive.box<Job>('userBox');

  @override
  void initState() {
    super.initState();
    // 1초마다 _updateJobStatus 함수를 실행하는 타이머 설정
    _timer = Timer.periodic(const Duration(seconds: 1), _updateJobStatus);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  /// 1초마다 실행되며 진행중인 Job의 상태를 업데이트하는 함수
  void _updateJobStatus(Timer timer) {
    final now = DateTime.now();
    bool needsUiUpdate = false;

    for (final key in _box.keys) {
      final job = _box.get(key);
      if (job == null) continue;

      // '진행 중' 상태인 항목을 찾음
      if (job.checkTime != null && !job.done) {
        final elapsed = now.difference(job.checkTime!);

        if (elapsed >= job.duration) {
          // 시간이 경과하면 'done = true'로 설정
          job.done = true;
          _box.put(key, job);
        } else {
          // 아직 진행중인 항목이 있음
          needsUiUpdate = true;
        }
      }
    }

    // 진행중인 항목이 하나라도 있다면
    // setState를 호출하여 UI를 강제로 갱신
    if (needsUiUpdate && mounted) {
      setState(() {
      });
    }
  }

  /// 체크박스 탭 처리
  void _onCheckboxTapped(int key, Job job, bool? newValue) {
    final now = DateTime.now();

    if (newValue == true) {
      // check box를 누를 때 check_time을 현재 시각으로 채움
      job.checkTime = now;
      job.done = false;
    } else {
      // check box를 다시 누르면 check_time을 null로 채움
      job.checkTime = null;
      job.done = false;
    }
    // 변경 사항을 Hive DB에 저장
    _box.put(key, job);
  }

  Color _getJobColor(Job job) {
    // done이 1이면 회색 박스
    if (job.done) {
      return Colors.grey[200]!;
    }

    // 시작 전 - check time이 null이라면 흰색 박스
    if (job.checkTime == null) {
      return Colors.white;
    }

    //진행중이면  오랜지 박스
    //checkTime이 null이 아니고, done=false도 아니면 진행중
    return Colors.orange[100]!;
  }

  /// 체크박스 상태 결정 (시작 전=false, 진행중/완료=true)
  bool _getCheckboxState(Job job) {
    return job.checkTime != null; // checkTime이 있으면(진행중/완료) 체크됨
  }

  /// 시간 표시 텍스트 포맷
  String _formatTimeText(Job job) {
    final now = DateTime.now();

    // 진행 중
    if (job.checkTime != null && !job.done) {
      final remaining = job.duration - now.difference(job.checkTime!);
      if (remaining.isNegative) return "00:00"; // 시간 초과

      String twoDigits(int n) => n.toString().padLeft(2, "0");
      String minutes = twoDigits(remaining.inMinutes.remainder(60));
      String seconds = twoDigits(remaining.inSeconds.remainder(60));
      return "+$minutes:$seconds"; // 이미지의 "+3:00" 대신 남은 시간 표시
    }

    // 시작 전 또는 완료
    String twoDigits(int n) => n.toString().padLeft(2, "0");
    String minutes = twoDigits(job.duration.inMinutes.remainder(60));
    String seconds = twoDigits(job.duration.inSeconds.remainder(60));
    return "$minutes:$seconds";
  }

  @override
  Widget build(BuildContext context) {
    ThemeData theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('오늘은'),
        leading: IconButton(icon: const Icon(Icons.menu), onPressed: () {}),
        actions: [
          IconButton(icon: const Icon(Icons.calendar_today), onPressed: () {})
        ],
        elevation: 0,
        backgroundColor: theme.scaffoldBackgroundColor,
        foregroundColor: theme.textTheme.titleLarge?.color,
      ),

      body: ValueListenableBuilder<Box<Job>>(
        valueListenable: _box.listenable(),
        builder: (context, box, _) {
          final jobs = box.values.toList();
          final keys = box.keys.toList();

          if (jobs.isEmpty) {
            return const Center(child: Text("할 일을 추가하세요."));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            itemCount: jobs.length,
            itemBuilder: (context, index) {
              final job = jobs[index];
              final key = keys[index];

              final color = _getJobColor(job);
              final isChecked = _getCheckboxState(job);
              final timeText = _formatTimeText(job);

              // 왼쪽으로 슬라이딩 시 해당 TODO 삭제
              return Dismissible(
                key: Key(job.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  color: Colors.red,
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  margin: const EdgeInsets.only(bottom: 12),
                  child: const Icon(Icons.delete, color: Colors.white),
                ),
                onDismissed: (_) {
                  box.delete(key);
                  ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('삭제되었습니다')));
                },
                child: Card(
                  elevation: 0,
                  margin: const EdgeInsets.only(bottom: 12),
                  color: color,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    // 회색 테두리
                    side: BorderSide(color: Colors.grey[300]!, width: 1),
                  ),
                  child: InkWell(
                    //"Job클릭하면 CU 페이지로 네비게이션"
                    onTap: () =>
                        Navigator.pushNamed(context, '/edit', arguments: key),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8.0, vertical: 12.0),
                      child: Row(
                        children: [
                          // 체크박스
                          Checkbox(
                            value: isChecked,
                            onChanged: (newValue) {
                              _onCheckboxTapped(key, job, newValue);
                            },
                          ),

                          // 시간
                          Text(
                            timeText,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              color: Colors.black54,
                              fontWeight: (job.checkTime != null && !job.done)
                                  ? FontWeight.bold
                                  : FontWeight.normal,
                            ),
                          ),
                          const SizedBox(width: 12),

                          // 내용
                          Expanded(
                            child: Text(
                              job.content,
                              style: theme.textTheme.bodyLarge?.copyWith(
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),

                          // 수정 아이콘
                          /*
                          IconButton(
                            icon: Icon(Icons.edit_outlined,
                                color: Colors.grey[600]),
                            onPressed: () => Navigator.pushNamed(
                                context, '/edit',
                                arguments: key),
                          ),
                          */

                          if (!job.done)
                            IconButton(
                              icon: Icon(
                                Icons.edit_outlined,
                                color: job.checkTime != null && !job.done
                                    ? Colors.orange[800]
                                    : Colors.grey[600],
                              ),
                              onPressed: () => Navigator.pushNamed(
                                  context, '/edit',
                                  arguments: key),
                            )
                          else
                            const SizedBox(width: 48),
                        ],
                      ),
                    ),
                  ),
                ),
              );
            },
          );
        },
      ),

      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.pushNamed(context, '/edit'),
        child: const Icon(Icons.add),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }
}