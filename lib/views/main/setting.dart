import 'package:flutter/material.dart';
import 'package:flutter_overlay_window/flutter_overlay_window.dart';
import 'package:todo_and_lock/theme/sliding_toggle.dart';

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});

  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> with WidgetsBindingObserver {
  bool _isOverlayGranted = false;

  @override
  void initState() {
    super.initState();
    // 앱이 포그라운드로 돌아올 때 권한 체크를 위해 옵저버 등록
    WidgetsBinding.instance.addObserver(this);
    _checkPermission();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // 앱의 상태 변화(설정창에서 돌아옴 등)를 감지
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _checkPermission();
    }
  }

  // 권한 확인 로직
  Future<void> _checkPermission() async {
    final status = await FlutterOverlayWindow.isPermissionGranted();
    if (mounted) {
      setState(() {
        _isOverlayGranted = status;
      });
    }
  }

  // 토글 조작 시 권한 요청
  Future<void> _handleToggle(bool value) async {
    if (value) {
      // 권한이 없는데 켜려고 할 때만 요청
      if (!_isOverlayGranted) {
        await FlutterOverlayWindow.requestPermission();
        // 참고: requestPermission은 시스템 설정창을 띄우므로
        // 사용자가 돌아온 후 didChangeAppLifecycleState에서 상태가 업데이트됩니다.
      }
    } else {
      // 오버레이 권한은 앱 내에서 직접 '끄기'가 불가능하고 시스템 설정에서만 가능하므로 안내 메시지 출력
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('권한 해제는 시스템 설정에서 직접 수행해야 합니다.')),
      );
      // 상태 원복 (시스템 권한이 살아있으므로)
      setState(() => _isOverlayGranted = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        title: const Text('설정', style: TextStyle(color: Colors.black)),
        backgroundColor: Colors.white,
        elevation: 0,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _buildSettingTile(
            title: '다른 앱 위에 그리기 권한',
            subtitle: '오버레이 기능을 사용하기 위해 필요합니다.',
            value: _isOverlayGranted,
            onChanged: _handleToggle,
          ),
        ],
      ),
    );
  }

  Widget _buildSettingTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: TextStyle(fontSize: 13, color: Colors.grey[600]),
                ),
              ],
            ),
          ),
          SlidingToggle(
            value: value,
            onChanged: onChanged,
          ),
        ],
      ),
    );
  }
}