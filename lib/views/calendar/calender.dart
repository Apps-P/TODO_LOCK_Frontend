import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class CalendarView extends StatefulWidget {
  final DateTime selectedDate;

  const CalendarView({super.key, required this.selectedDate});

  @override
  State<CalendarView> createState() => _CalendarViewState();
}

class _CalendarViewState extends State<CalendarView> {
  late DateTime _focusedMonth; // 현재 보여주는 월
  late DateTime _selectedDate; // 선택된 날짜

  @override
  void initState() {
    super.initState();
    _focusedMonth = DateTime(widget.selectedDate.year, widget.selectedDate.month, 1);
    _selectedDate = widget.selectedDate;
  }

  // 이전 달로 이동
  void _prevMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1, 1);
    });
  }

  // 다음 달로 이동
  void _nextMonth() {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 1);
    });
  }

  // 날짜 선택 시 해당 날짜 URL로 네비게이션
  void _onDateTap(DateTime date) {
    final dateString = DateFormat('yyyy-MM-dd').format(date);
    Navigator.pushReplacementNamed(context, '/$dateString');
  }

  // 해당 월의 날짜 그리드 생성
  List<DateTime?> _buildCalendarDays() {
    final firstDay = DateTime(_focusedMonth.year, _focusedMonth.month, 1);
    final lastDay = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0);

    // 일요일 시작 기준 (0=Sun, 6=Sat)
    // weekday: 1=Mon ... 7=Sun → 일요일 앞 공백 = weekday % 7
    final leadingBlanks = firstDay.weekday % 7;

    final days = <DateTime?>[];

    // 앞 공백
    for (int i = 0; i < leadingBlanks; i++) {
      days.add(null);
    }

    // 실제 날짜
    for (int d = 1; d <= lastDay.day; d++) {
      days.add(DateTime(_focusedMonth.year, _focusedMonth.month, d));
    }

    // 뒤 공백 (6줄 맞추기용 — 없어도 됨)
    while (days.length % 7 != 0) {
      days.add(null);
    }

    return days;
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && date.month == now.month && date.day == now.day;
  }

  bool _isSelected(DateTime date) {
    return date.year == _selectedDate.year &&
        date.month == _selectedDate.month &&
        date.day == _selectedDate.day;
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final calendarDays = _buildCalendarDays();
    final monthLabel = DateFormat('yyyy년 MM월', 'ko').format(_focusedMonth);

    // fallback: 'ko' locale 없을 경우 영문
    // final monthLabel = DateFormat('yyyy년 MM월').format(_focusedMonth);

    // ── 요일 라벨 ──
    const weekLabels = ['일', '월', '화', '수', '목', '금', '토'];

    return Scaffold(
      appBar: AppBar(
        title: const Text('캘린더'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: Column(
        children: [
          // ── 월 네비게이션 헤더 ──
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                IconButton(
                  onPressed: _prevMonth,
                  icon: const Icon(Icons.chevron_left),
                ),
                Text(
                  monthLabel,
                  style: theme.textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                IconButton(
                  onPressed: _nextMonth,
                  icon: const Icon(Icons.chevron_right),
                ),
              ],
            ),
          ),

          // ── 요일 라벨 ──
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Row(
              children: weekLabels.map((label) {
                final isSun = label == '일';
                final isSat = label == '토';
                return Expanded(
                  child: Center(
                    child: Text(
                      label,
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 13,
                        color: isSun
                            ? Colors.red[400]
                            : isSat
                            ? Colors.blue[400]
                            : theme.colorScheme.onSurface.withOpacity(0.6),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 8),
          const Divider(height: 1,color: Colors.black26,indent: 10, endIndent: 10,),

          // ── 날짜 그리드 ──
          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(8),
              physics: const NeverScrollableScrollPhysics(),
              shrinkWrap: true,
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 7,
                mainAxisSpacing: 4,
                crossAxisSpacing: 4,
              ),
              itemCount: calendarDays.length,
              itemBuilder: (context, index) {
                final date = calendarDays[index];

                if (date == null) return const SizedBox.shrink();

                final isSelected = _isSelected(date);
                final isToday = _isToday(date);

                // 0=Sun(빨강), 6=Sat(파랑)
                final dayOfWeek = index % 7;
                Color? textColor;
                if (dayOfWeek == 0) textColor = Colors.red[400];   // 일요일
                if (dayOfWeek == 6) textColor = Colors.blue[400];  // 토요일

                return GestureDetector(
                  onTap: () => _onDateTap(date),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 150),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? theme.colorScheme.primary
                          : isToday
                          ? theme.colorScheme.primary.withOpacity(0.12)
                          : Colors.transparent,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Text(
                        '${date.day}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight:
                          isSelected || isToday ? FontWeight.bold : FontWeight.normal,
                          color: isSelected
                              ? theme.colorScheme.onPrimary
                              : textColor ?? theme.colorScheme.onSurface,
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
          ),

          // ── 오늘로 이동 버튼 ──
          Padding(
            padding: const EdgeInsets.only(bottom: 24, top: 8),
            child: TextButton.icon(
              onPressed: () {
                final today = DateTime.now();
                setState(() {
                  _focusedMonth = DateTime(today.year, today.month, 1);
                  _selectedDate = today;
                });
                _onDateTap(today);
              },
              icon: const Icon(Icons.today),
              label: const Text('오늘로 이동'),
            ),
          ),
        ],
      ),
    );
  }
}