import 'app_bar.dart';
import 'package:todo_and_lock/theme/app_colors.dart';
import 'package:flutter/material.dart';
import 'package:todo_and_lock/views/main/todo/view.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:todo_and_lock/views/setting/auth_page.dart';

final _supabase = Supabase.instance.client;

class MainView extends StatefulWidget {
  final DateTime selectedDate;
  const MainView({super.key, required this.selectedDate});

  @override
  State<MainView> createState() => _MainViewState();
}

class _MainViewState extends State<MainView> {
  User? _user;

  @override
  void initState() {
    super.initState();
    _user = _supabase.auth.currentUser;
    _supabase.auth.onAuthStateChange.listen((data) {
      if (mounted) setState(() => _user = data.session?.user);
    });
  }

  Future<void> _signOut() async {
    await _supabase.auth.signOut();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = _user != null;
    final displayName =
        _user?.userMetadata?['display_name'] as String? ?? '홍길동';
    final email = _user?.email ?? '';

    return Scaffold(
      appBar: CustomAppBar(selectedDate: widget.selectedDate),
      body: TodoListView(selectedDate: widget.selectedDate),
      floatingActionButton: FloatingActionButton(
        onPressed: () {
          Navigator.pushNamed(context, '/create');
        },
        backgroundColor: AppColors.carrot,
        child: const Icon(Icons.add_outlined),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
      drawer: Drawer(
        child: ListView(
          padding: EdgeInsets.zero,
          children: [
            // ── 헤더: 로그인 상태에 따라 다르게 표시 ──────────
            GestureDetector(
              onTap: isLoggedIn
                  ? null
                  : () {
                Navigator.pop(context);
                Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AuthPage()),
                );
              },
              child: UserAccountsDrawerHeader(
                currentAccountPicture: CircleAvatar(
                  backgroundColor: Colors.white,
                  child: isLoggedIn
                      ? Text(
                    displayName.isNotEmpty
                        ? displayName[0].toUpperCase()
                        : '?',
                    style: const TextStyle(
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                      color: Colors.blue,
                    ),
                  )
                      : const Icon(Icons.person, color: Colors.blue),
                ),
                accountName: Text(
                  isLoggedIn ? displayName : '로그인 하세요',
                  style: const TextStyle(color: AppColors.black100),
                ),
                accountEmail: isLoggedIn
                    ? Text(email,
                    style: const TextStyle(color: AppColors.black80))
                    : const Text(
                  '탭하여 로그인 또는 회원가입',
                  style: TextStyle(color: AppColors.black80, fontSize: 12),
                ),
                decoration: const BoxDecoration(color: AppColors.listbg),
              ),
            ),

            // ── 기존 메뉴 ──────────────────────────────────────
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/setting');
              },
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.settings),
                title: Text("설정"),
              ),
            ),
            InkWell(
              onTap: () {
                Navigator.pop(context);
                Navigator.pushNamed(context, '/calendar');
              },
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.calendar_month_outlined),
                title: Text("캘린더"),
              ),
            ),
            InkWell(
              onTap: () {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('업적 페이지는 업데이트 예정입니다. 기다려주세요!')),
                );
                Navigator.pop(context);
              },
              splashColor: AppColors.black40,
              child: const ListTile(
                leading: Icon(Icons.emoji_events),
                title: Text("업적"),
              ),
            ),

            // ── 로그아웃 (로그인 상태일 때만 표시) ────────────
            if (isLoggedIn) ...[
              const Divider(thickness: 0.5,),
              InkWell(
                onTap: () {
                  Navigator.pop(context);
                  _signOut();
                },
                splashColor: AppColors.black40,
                child: const ListTile(
                  leading: Icon(Icons.logout, color: Colors.red),
                  title: Text("로그아웃", style: TextStyle(color: Colors.red)),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}