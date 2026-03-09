import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_sign_in/google_sign_in.dart';

final supabase = Supabase.instance.client;

class AuthPage extends StatefulWidget {
  const AuthPage({super.key});

  @override
  State<AuthPage> createState() => _AuthPageState();
}

class _AuthPageState extends State<AuthPage>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  // 로그인
  final _loginEmailController = TextEditingController();
  final _loginPasswordController = TextEditingController();

  // 회원가입
  final _signupEmailController = TextEditingController();
  final _signupPasswordController = TextEditingController();
  final _signupPasswordConfirmController = TextEditingController();
  final _signupNameController = TextEditingController();

  bool _loginObscure = true;
  bool _signupObscure = true;
  bool _signupConfirmObscure = true;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _loginEmailController.dispose();
    _loginPasswordController.dispose();
    _signupEmailController.dispose();
    _signupPasswordController.dispose();
    _signupPasswordConfirmController.dispose();
    _signupNameController.dispose();
    super.dispose();
  }

  // ───────────────────────────── 이메일 로그인
  Future<void> _signInWithEmail() async {
    final email = _loginEmailController.text.trim();
    final password = _loginPasswordController.text.trim();

    if (email.isEmpty || password.isEmpty) {
      _showSnackBar('이메일과 비밀번호를 입력해주세요.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signInWithPassword(
        email: email,
        password: password,
      );
      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────────── 이메일 회원가입
  Future<void> _signUpWithEmail() async {
    final email = _signupEmailController.text.trim();
    final password = _signupPasswordController.text.trim();
    final confirm = _signupPasswordConfirmController.text.trim();
    final name = _signupNameController.text.trim();

    if (email.isEmpty || password.isEmpty || name.isEmpty) {
      _showSnackBar('모든 항목을 입력해주세요.');
      return;
    }
    if (password != confirm) {
      _showSnackBar('비밀번호가 일치하지 않습니다.');
      return;
    }
    if (password.length < 6) {
      _showSnackBar('비밀번호는 6자 이상이어야 합니다.');
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.auth.signUp(
        email: email,
        password: password,
        data: {'display_name': name},
      );
      if (mounted) {
        _showSnackBar('가입 확인 이메일을 보냈습니다. 이메일을 확인해주세요.');
        _tabController.animateTo(0); // 로그인 탭으로 이동
      }
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('회원가입 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  // ───────────────────────────── 구글 네이티브 로그인
  Future<void> _signInWithGoogle() async {
    /// TODO: 본인의 웹 클라이언트 ID와 iOS 클라이언트 ID로 교체하세요.
    const webClientId = 'YOUR_WEB_CLIENT_ID.apps.googleusercontent.com';
    const iosClientId = 'YOUR_IOS_CLIENT_ID.apps.googleusercontent.com';

    setState(() => _isLoading = true);
    try {
      final GoogleSignIn signIn = GoogleSignIn.instance;

      await signIn.initialize(
        clientId: iosClientId,
        serverClientId: webClientId,
      );

      final googleAccount = await signIn.authenticate();
      final googleAuthorization =
      await googleAccount.authorizationClient.authorizationForScopes([]);
      final idToken = googleAccount.authentication.idToken;
      final accessToken = googleAuthorization?.accessToken;

      if (idToken == null) throw '구글 ID 토큰을 가져오지 못했습니다.';

      await supabase.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      if (mounted) Navigator.of(context).pop();
    } on AuthException catch (e) {
      _showSnackBar(e.message);
    } catch (e) {
      _showSnackBar('구글 로그인 중 오류가 발생했습니다.');
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _showSnackBar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  // ───────────────────────────── UI

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('계정'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '로그인'),
            Tab(text: '회원가입'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildLoginTab(),
          _buildSignUpTab(),
        ],
      ),
    );
  }

  // ─── 로그인 탭
  Widget _buildLoginTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _buildEmailField(
            controller: _loginEmailController,
            label: '이메일',
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _loginPasswordController,
            label: '비밀번호',
            obscure: _loginObscure,
            onToggle: () => setState(() => _loginObscure = !_loginObscure),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: '로그인',
            onPressed: _isLoading ? null : _signInWithEmail,
          ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildGoogleButton(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _tabController.animateTo(1),
            child: const Text('계정이 없으신가요? 회원가입'),
          ),
        ],
      ),
    );
  }

  // ─── 회원가입 탭
  Widget _buildSignUpTab() {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SizedBox(height: 16),
          _buildEmailField(
            controller: _signupNameController,
            label: '이름',
            keyboardType: TextInputType.name,
          ),
          const SizedBox(height: 12),
          _buildEmailField(
            controller: _signupEmailController,
            label: '이메일',
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _signupPasswordController,
            label: '비밀번호',
            obscure: _signupObscure,
            onToggle: () => setState(() => _signupObscure = !_signupObscure),
          ),
          const SizedBox(height: 12),
          _buildPasswordField(
            controller: _signupPasswordConfirmController,
            label: '비밀번호 확인',
            obscure: _signupConfirmObscure,
            onToggle: () =>
                setState(() => _signupConfirmObscure = !_signupConfirmObscure),
          ),
          const SizedBox(height: 24),
          _buildPrimaryButton(
            label: '회원가입',
            onPressed: _isLoading ? null : _signUpWithEmail,
          ),
          const SizedBox(height: 16),
          _buildDivider(),
          const SizedBox(height: 16),
          _buildGoogleButton(),
          const SizedBox(height: 16),
          TextButton(
            onPressed: () => _tabController.animateTo(0),
            child: const Text('이미 계정이 있으신가요? 로그인'),
          ),
        ],
      ),
    );
  }

  // ─── 공통 위젯

  Widget _buildEmailField({
    required TextEditingController controller,
    required String label,
    TextInputType keyboardType = TextInputType.emailAddress,
  }) {
    return TextField(
      controller: controller,
      keyboardType: keyboardType,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
    );
  }

  Widget _buildPasswordField({
    required TextEditingController controller,
    required String label,
    required bool obscure,
    required VoidCallback onToggle,
  }) {
    return TextField(
      controller: controller,
      obscureText: obscure,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
        contentPadding:
        const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        suffixIcon: IconButton(
          icon: Icon(obscure ? Icons.visibility_off : Icons.visibility),
          onPressed: onToggle,
        ),
      ),
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback? onPressed,
  }) {
    return SizedBox(
      height: 48,
      child: ElevatedButton(
        onPressed: onPressed,
        child: _isLoading
            ? const SizedBox(
          width: 20,
          height: 20,
          child: CircularProgressIndicator(strokeWidth: 2),
        )
            : Text(label, style: const TextStyle(fontSize: 16)),
      ),
    );
  }

  Widget _buildGoogleButton() {
    return SizedBox(
      height: 48,
      child: OutlinedButton.icon(
        onPressed: _isLoading ? null : _signInWithGoogle,
        icon: Image.network(
          'https://www.svgrepo.com/show/475656/google-color.svg',
          height: 20,
          width: 20,
          errorBuilder: (_, __, ___) => const Icon(Icons.login, size: 20),
        ),
        label: const Text('Google로 로그인'),
      ),
    );
  }

  Widget _buildDivider() {
    return const Row(
      children: [
        Expanded(child: Divider(thickness: 0.5,)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text('또는', style: TextStyle(color: Colors.grey)),
        ),
        Expanded(child: Divider(thickness: 0.5,)),
      ],
    );
  }
}