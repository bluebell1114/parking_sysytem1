import 'package:flutter/material.dart';

import 'api_config.dart';
import 'backend_api.dart';

class RegisterPage extends StatefulWidget {
  const RegisterPage({Key? key}) : super(key: key);

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final _registerFormKey = GlobalKey<FormState>();
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();
  final TextEditingController _confirmPasswordController =
      TextEditingController();

  bool _isLoading = false;

  static const int _minPasswordLength = 6;

  String _apiErrorMn(Object e) {
    if (e is BackendApiException) {
      switch (e.message) {
        case 'email_in_use':
          return 'Энэ имэйлээр аль хэдийн бүртгэл бий.';
        case 'invalid_input':
          return 'Имэйл/нууц үг буруу (нууц дор хаяж $_minPasswordLength тэмдэгт).';
        case 'server_error':
          return 'Серверийн алдаа. Docker `mobile_bas2` API асаалттай эсэхийг шалгана уу.';
        default:
          if (e.message.contains('Failed host lookup') ||
              e.message.contains('Connection refused')) {
            return 'Сүлжээний алдаа. API: ${apiBaseUrl()} — docker compose асаасан уу?';
          }
          return e.message;
      }
    }
    return 'Алдаа: $e';
  }

  Future<void> _registerUser() async {
    if (!_registerFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await BackendApi.register(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
        name: _nameController.text.trim(),
      );

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Бүртгэл амжилттай — Docker (mobile_bas2) серверт хадгалагдлаа'),
        ),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_apiErrorMn(e))),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String hint) {
    return InputDecoration(
      hintText: hint,
      filled: true,
      fillColor: Colors.white.withOpacity(0.9),
      contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide.none,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          Positioned.fill(
            child: Image.network(
              "https://scontent.fuln8-1.fna.fbcdn.net/v/t1.15752-9/647437011_1361207769068874_279893139304913146_n.jpg?stp=dst-jpg_s2048x2048_tt6&_nc_cat=100&ccb=1-7&_nc_sid=9f807c&_nc_ohc=Jmuj97ICYbsQ7kNvwF7vkf8&_nc_oc=Adk8I-G25mq4f6o4s9dRj9_8ie3-z_2pH-FStuhEh-m65pIH87v9KO0i2YsgY2BrbE0&_nc_zt=23&_nc_ht=scontent.fuln8-1.fna&_nc_ss=8&oh=03_Q7cD4wH5_waMmdCxWU3esmEYCCm_ibjy6FxbTJJqw6K3gYkP6w&oe=69D738F2",
              fit: BoxFit.cover,
            ),
          ),
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.3)),
          ),
          SafeArea(
            child: SingleChildScrollView(
              child: Container(
                height: MediaQuery.of(context).size.height,
                padding: const EdgeInsets.all(20),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Та бүртгэлээ үүсгэнэ үү?',
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    Form(
                      key: _registerFormKey,
                      child: Column(
                        children: [
                          TextFormField(
                            controller: _nameController,
                            decoration: _inputDecoration('Нэр'),
                            validator: (v) {
                              if (v == null || v.trim().isEmpty) {
                                return 'Нэрээ оруулна уу';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _emailController,
                            keyboardType: TextInputType.emailAddress,
                            autocorrect: false,
                            decoration: _inputDecoration('Email'),
                            validator: (v) {
                              final s = v?.trim() ?? '';
                              if (s.isEmpty) return 'Имэйл оруулна уу';
                              if (!s.contains('@')) {
                                return 'Зөв имэйл хаяг оруулна уу';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _passwordController,
                            obscureText: true,
                            decoration: _inputDecoration(
                              'Нууц үг (дор хаяж $_minPasswordLength тэмдэгт)',
                            ),
                            validator: (v) {
                              final s = v ?? '';
                              if (s.length < _minPasswordLength) {
                                return 'Нууц үг дор хаяж $_minPasswordLength тэмдэгт байх ёстой';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 15),

                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: true,
                            decoration: _inputDecoration(
                              'Нууц үгээ баталгаажуулна уу',
                            ),
                            validator: (v) {
                              if (v != _passwordController.text) {
                                return 'Нууц үг таарахгүй байна';
                              }
                              return null;
                            },
                          ),

                          const SizedBox(height: 25),

                          SizedBox(
                            width: double.infinity,
                            height: 50,
                            child: ElevatedButton(
                              onPressed: _isLoading ? null : _registerUser,
                              child: const Text(
                                'Бүртгүүлэх',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 58, 103, 81),
                                ),
                              ),
                            ),
                          ),

                          const SizedBox(height: 15),

                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Text(
                                'Бүртгэлтэй юу?',
                                style: TextStyle(color: Colors.white),
                              ),
                              TextButton(
                                onPressed: () {
                                  Navigator.pop(context);
                                },
                                child: const Text(
                                  'Нэвтрэх',
                                  style: TextStyle(color: Colors.greenAccent),
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
