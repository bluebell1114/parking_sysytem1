import 'package:flutter/material.dart';

import 'api_config.dart';
import 'auth_prefs.dart';
import 'backend_api.dart';
import 'payments_admin_page.dart';
import 'reports_admin_page.dart';
import 'spots_admin_page.dart';

class AdminLoginPage extends StatefulWidget {
  const AdminLoginPage({super.key});

  @override
  State<AdminLoginPage> createState() => _AdminLoginPageState();
}

class _AdminLoginPageState extends State<AdminLoginPage> {
  final _formKey = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _adminLogin() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();
      final pass = _password.text.trim();

      final res = await BackendApi.login(email: email, password: pass);
      final user = res['user'];
      if (user is! Map) {
        setState(() => _error = "Серверийн хариу буруу байна.");
        return;
      }
      final u = Map<String, dynamic>.from(user);
      if (u['isAdmin'] != true) {
        if (!mounted) return;
        setState(() => _error = "Та админ биш байна! (admin@greenpark.com / admin123)");
        return;
      }

      final token = res['token'] as String? ?? '';
      await AuthPrefs.saveSession(
        token: token,
        userId: u['id'].toString(),
        email: u['email'].toString(),
        name: u['name']?.toString() ?? '',
        isAdmin: true,
      );

      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(builder: (_) => const AdminHome()),
      );
    } on BackendApiException catch (e) {
      if (!mounted) return;
      if (e.message == 'invalid_credentials') {
        setState(() => _error = _authMessageMn('invalid-credential'));
      } else if (e.message.contains('Failed host lookup') ||
          e.message.contains('Connection refused')) {
        setState(
          () => _error = 'API холбогдохгүй байна: ${apiBaseUrl()}',
        );
      } else {
        setState(() => _error = e.message);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = "Алдаа: $e");
    } finally {
      if (!mounted) return;
      setState(() => _loading = false);
    }
  }

  String _authMessageMn(String code) {
    switch (code) {
      case 'invalid-email':
        return "Имэйл буруу байна.";
      case 'user-not-found':
        return "Хэрэглэгч олдсонгүй.";
      case 'wrong-password':
        return "Нууц үг буруу байна.";
      case 'invalid-credential':
        return "Имэйл эсвэл нууц үг буруу (эсвэл бүртгэлгүй) байна.";
      case 'too-many-requests':
        return "Хэт олон оролдлого хийлээ. Түр хүлээгээд дахин алдана.";
      case 'network-request-failed':
        return "Интернет холболтоо шалгана уу.";
      default:
        return "Нэвтрэхэд алдаа гарлаа. ($code)";
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Админ нэвтрэх")),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Form(
              key: _formKey,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextFormField(
                    controller: _email,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: "Имэйл",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      final t = (v ?? '').trim();
                      if (t.isEmpty) return "Имэйлээ оруулна уу";
                      if (!t.contains('@')) return "Имэйл буруу байна";
                      return null;
                    },
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: "Нууц үг",
                      border: OutlineInputBorder(),
                    ),
                    validator: (v) {
                      if ((v ?? '').isEmpty) return "Нууц үгээ оруулна уу";
                      if ((v ?? '').length < 6) {
                        return "Хамгийн багадаа 6 тэмдэгт";
                      }
                      return null;
                    },
                  ),
                  const SizedBox(height: 14),
                  if (_error != null)
                    Text(_error!, style: const TextStyle(color: Colors.red)),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _loading ? null : _adminLogin,
                      child: _loading
                          ? const SizedBox(
                              height: 18,
                              width: 18,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text("Нэвтрэх"),
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'Docker `mobile_bas2` — анхны админ: admin@greenpark.com / admin123',
                    style: TextStyle(fontSize: 12, color: Colors.grey.shade700),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class AdminHome extends StatelessWidget {
  const AdminHome({super.key});

  Future<void> _logout(BuildContext context) async {
    await AuthPrefs.clear();
    if (!context.mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => const AdminLoginPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 3,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Админ самбар"),
          bottom: const TabBar(
            tabs: [
              Tab(text: "Нөөц"),
              Tab(text: "Төлбөр"),
              Tab(text: "Тайлан"),
            ],
          ),
          actions: [
            IconButton(
              onPressed: () => _logout(context),
              icon: const Icon(Icons.logout),
            ),
          ],
        ),
        body: const TabBarView(
          children: [SpotsAdminPage(), PaymentsAdminPage(), ReportsAdminPage()],
        ),
      ),
    );
  }
}
