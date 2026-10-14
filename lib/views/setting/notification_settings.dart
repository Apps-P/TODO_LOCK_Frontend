import 'package:flutter/material.dart';
import 'package:hive_flutter/hive_flutter.dart';
import '../../services/todo_notifications.dart';

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
    if (!TodoNotifications.supported) return;
    try {
      final status = await TodoNotifications.status();
      if (mounted) setState(() => _status = status);
    } catch (error) {
      debugPrint('알림 권한 확인 실패: $error');
    }
  }

  Future<void> _perform(Future<void> Function() action) async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      await action();
      await _refresh();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('알림 설정을 변경하지 못했어요. 다시 시도해 주세요.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<void> _toggle(bool value, Future<void> Function(bool) save) =>
      _perform(() async {
        await save(value);
        if (value && TodoNotifications.supported) {
          await TodoNotifications.requestPermission();
        }
      });

  @override
  Widget build(BuildContext context) => ValueListenableBuilder(
    valueListenable: NotificationPreferences.box.listenable(
      keys: [
        NotificationPreferences.dailyKey,
        NotificationPreferences.runningKey,
      ],
    ),
    builder: (context, _, _) {
      final daily = NotificationPreferences.dailyEnabled;
      final running = NotificationPreferences.runningEnabled;
      final status = _status;
      final blocked =
          status != null &&
          ((daily && (!status.allowed || !status.dailyAllowed)) ||
              (running && (!status.allowed || !status.runningAllowed)));
      return Card(
        color: Colors.white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          children: [
            SwitchListTile.adaptive(
              key: const ValueKey('daily-jobs-switch'),
              title: const Text('오늘의 할 일 표시'),
              subtitle: const Text(
                '상태표시줄에 오늘의 목록을 순서대로 표시해요. 날짜가 바뀌면 목록도 바뀌어요.',
              ),
              value: daily,
              onChanged: _saving
                  ? null
                  : (value) =>
                        _toggle(value, NotificationPreferences.setDailyEnabled),
            ),
            SwitchListTile.adaptive(
              key: const ValueKey('running-timer-switch'),
              title: const Text('진행 중인 타이머 표시'),
              subtitle: const Text('실행 중인 할 일의 남은 시간을 별도 알림으로 표시해요.'),
              value: running,
              onChanged: _saving
                  ? null
                  : (value) => _toggle(
                      value,
                      NotificationPreferences.setRunningEnabled,
                    ),
            ),
            const Padding(
              padding: EdgeInsets.fromLTRB(16, 0, 16, 12),
              child: Text('화면 잠금 중에는 타이머를 꺼도 잠금 실행 안내가 표시됩니다.'),
            ),
            if (blocked)
              ListTile(
                leading: const Icon(Icons.notifications_off_outlined),
                title: const Text('알림이 차단되어 있어요'),
                subtitle: const Text('휴대폰 설정에서 알림을 허용해 주세요.'),
                trailing: TextButton(
                  onPressed: _saving
                      ? null
                      : () => _perform(() async {
                          await TodoNotifications.requestPermission();
                          final updated = await TodoNotifications.status();
                          if (!updated.allowed ||
                              (daily && !updated.dailyAllowed) ||
                              (running && !updated.runningAllowed)) {
                            await TodoNotifications.openSystemSettings();
                          }
                        }),
                  child: const Text('허용하기'),
                ),
              ),
            if (status != null && daily && !status.exactAllowed)
              ListTile(
                title: const Text('날짜 변경 시 바로 갱신'),
                subtitle: const Text('알람 및 리마인더 권한을 허용하면 앱을 닫아도 자정에 목록을 갱신해요.'),
                trailing: const Icon(Icons.chevron_right),
                onTap: _saving
                    ? null
                    : () => _perform(TodoNotifications.openExactAlarmSettings),
              ),
            if (TodoNotifications.supported)
              ListTile(
                title: const Text('휴대폰 알림 설정'),
                trailing: const Icon(Icons.open_in_new),
                onTap: _saving
                    ? null
                    : () => _perform(TodoNotifications.openSystemSettings),
              ),
          ],
        ),
      );
    },
  );
}
