import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:todo_and_lock/services/todo_notifications.dart';
import 'package:todo_and_lock/theme/app_colors.dart';

class NotificationSettingsCard extends StatefulWidget {
  const NotificationSettingsCard({super.key});

  @override
  State<NotificationSettingsCard> createState() =>
      _NotificationSettingsCardState();
}

class _NotificationSettingsCardState extends State<NotificationSettingsCard>
    with WidgetsBindingObserver {
  NotificationStatus? _status;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _refresh();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  Future<void> _refresh() async {
    try {
      final status = await TodoNotifications.status();
      if (mounted)
        setState(() {
          _status = status;
          _error = null;
        });
    } catch (_) {
      if (mounted) setState(() => _error = '알림 상태를 확인하지 못했습니다.');
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      await _refresh();
    } catch (_) {
      if (mounted)
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정을 변경하지 못했습니다. 다시 시도해주세요.')),
        );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _chooseTime() async {
    final minute = NotificationPreferences.minuteOfDay;
    final selected = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: minute ~/ 60, minute: minute % 60),
      helpText: '할 일 알림 시간',
      cancelText: '취소',
      confirmText: '확인',
      hourLabelText: '시',
      minuteLabelText: '분',
    );
    if (selected != null && mounted) {
      await _perform(
        () => NotificationPreferences.setTime(
          selected.hour * 60 + selected.minute,
        ),
      );
    }
  }

  String _timeLabel(int minutes) {
    final hour = minutes ~/ 60;
    return '${hour < 12 ? '오전' : '오후'} ${hour % 12 == 0 ? 12 : hour % 12}:${(minutes % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: NotificationPreferences.box.listenable(
      keys: [
        NotificationPreferences.enabledKey,
        NotificationPreferences.timeKey,
      ],
    ),
    builder: (context, _, child) {
      final enabled = NotificationPreferences.enabled;
      final status = _status;
      return Card(
        elevation: 0,
        color: Colors.white,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('future-reminders-switch'),
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 8,
              ),
              secondary: const Icon(
                Icons.notifications_outlined,
                color: AppColors.carrot,
              ),
              title: const Text('예정된 할 일 알림'),
              subtitle: const Text('미래 날짜에 미리 추가한 할 일을 해당일에 알려드려요.'),
              value: enabled,
              onChanged: _saving
                  ? null
                  : (value) => _perform(() async {
                      await NotificationPreferences.setEnabled(value);
                      if (value) await TodoNotifications.requestPermission();
                    }),
            ),
            const Divider(height: 1, indent: 20, endIndent: 20),
            ListTile(
              key: const ValueKey('reminder-time'),
              contentPadding: const EdgeInsets.symmetric(horizontal: 20),
              leading: const Icon(Icons.schedule),
              title: const Text('알림 시간'),
              subtitle: Text(_timeLabel(NotificationPreferences.minuteOfDay)),
              enabled: enabled && !_saving,
              trailing: const Icon(Icons.chevron_right),
              onTap: _chooseTime,
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Text(
                '진행 중인 할 일은 알림창에 이름과 남은 시간이 표시돼요. 완료하거나 중단하면 사라져요.',
                style: TextStyle(fontSize: 13, color: Colors.black54),
              ),
            ),
            if (_error != null)
              ListTile(
                title: Text(_error!),
                onTap: _refresh,
                trailing: const Icon(Icons.refresh),
              ),
            if (status != null && TodoNotifications.supported) ...[
              if (!status.allowed)
                ListTile(
                  title: const Text('기기 알림 권한이 꺼져 있어요'),
                  subtitle: const Text('예정된 할 일과 진행 상태를 표시하려면 알림을 허용해주세요.'),
                  trailing: TextButton(
                    onPressed: _saving
                        ? null
                        : () => _perform(() async {
                            await TodoNotifications.requestPermission();
                          }),
                    child: const Text('허용하기'),
                  ),
                )
              else if (!status.remindersAllowed || !status.runningAllowed)
                const ListTile(
                  title: Text('일부 알림이 기기 설정에서 꺼져 있어요'),
                  subtitle: Text('시스템 알림 설정에서 필요한 알림을 켜주세요.'),
                ),
              if (enabled && !status.exactAllowed)
                ListTile(
                  title: const Text('정확한 시간에 알림'),
                  subtitle: const Text(
                    '알람 및 리마인더 권한을 허용하면 지정한 시간에 알림을 받을 수 있어요. 허용 전에는 늦게 도착할 수 있어요.',
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      _perform(TodoNotifications.openExactAlarmSettings),
                ),
              ListTile(
                title: const Text('시스템 알림 설정'),
                trailing: const Icon(Icons.open_in_new, size: 20),
                onTap: () => _perform(TodoNotifications.openSystemSettings),
              ),
            ],
          ],
        ),
      );
    },
  );
}
