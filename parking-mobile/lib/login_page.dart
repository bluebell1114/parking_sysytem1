import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _loginFormKey = GlobalKey<FormState>();
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
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

  String _authErrorMn(String code) {
    switch (code) {
      case 'invalid-email':
        return 'Имэйл буруу байна.';
      case 'user-not-found':
      case 'user-disabled':
        return 'Энэ имэйлээр бүртгэл байхгүй эсвэл идэвхгүй. Эхлээд «Бүртгүүлэх» хийнэ үү.';
      case 'wrong-password':
        return 'Нууц үг буруу байна.';
      case 'invalid-credential':
        return 'Имэйл эсвэл нууц үг таарахгүй. Вэбийн туршилтын нууц үг Firebase-тэй адил биш байж болно — апп дээр бүртгэсэн мэдээллээрээ орно уу.';
      case 'too-many-requests':
        return 'Хэт олон оролдлого. Түр хүлээгээд дахин оролдоорой.';
      case 'network-request-failed':
        return 'Сүлжээний алдаа. Интернэтээ шалгана уу.';
      case 'operation-not-allowed':
        return 'Имэйл/нууц үгээр нэвтрэх Firebase дээр идэвхгүй байна (Console → Authentication).';
      default:
        return 'Нэвтрэхэд алдаа: $code';
    }
  }

  Future<void> _loginUser() async {
    if (!_loginFormKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    try {
      await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      if (!mounted) return;
      Navigator.pushReplacementNamed(context, '/createPin');
    } on FirebaseAuthException catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_authErrorMn(e.code)),
          duration: const Duration(seconds: 5),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа: $e')),
      );
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          /// INTERNET BACKGROUND IMAGE
          Positioned.fill(
            child: Image.network(
              'https://scontent.fuln8-1.fna.fbcdn.net/v/t1.15752-9/647437011_1361207769068874_279893139304913146_n.jpg?stp=dst-jpg_s2048x2048_tt6&_nc_cat=100&ccb=1-7&_nc_sid=9f807c&_nc_ohc=Jmuj97ICYbsQ7kNvwF7vkf8&_nc_oc=Adk8I-G25mq4f6o4s9dRj9_8ie3-z_2pH-FStuhEh-m65pIH87v9KO0i2YsgY2BrbE0&_nc_zt=23&_nc_ht=scontent.fuln8-1.fna&_nc_ss=8&oh=03_Q7cD4wH5_waMmdCxWU3esmEYCCm_ibjy6FxbTJJqw6K3gYkP6w&oe=69D738F2',
              fit: BoxFit.cover,
            ),
          ),

          /// DARK OVERLAY
          Positioned.fill(
            child: Container(color: Colors.black.withOpacity(0.4)),
          ),

          /// LOGIN FORM
          Center(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Form(
                key: _loginFormKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text(
                      "Нэвтрэх",
                      style: TextStyle(
                        fontSize: 28,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),

                    const SizedBox(height: 30),

                    TextFormField(
                      controller: _emailController,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      decoration: _inputDecoration('Email'),
                      validator: (v) {
                        final s = v?.trim() ?? '';
                        if (s.isEmpty) return 'Имэйл оруулна уу';
                        if (!s.contains('@')) return 'Зөв имэйл оруулна уу';
                        return null;
                      },
                    ),

                    const SizedBox(height: 15),

                    TextFormField(
                      controller: _passwordController,
                      obscureText: true,
                      decoration: _inputDecoration('Нууц үг'),
                      validator: (v) {
                        if (v == null || v.isEmpty) return 'Нууц үг оруулна уу';
                        if (v.length < 6) {
                          return 'Нууц үг дор хаяж 6 тэмдэгт';
                        }
                        return null;
                      },
                    ),

                    const SizedBox(height: 8),

                    const Text(
                      'Эхлээд «Бүртгүүлэх»-ээр бүртгүүлсэн имэйл ашиглана уу.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.white70, fontSize: 12),
                    ),

                    const SizedBox(height: 25),

                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isLoading ? null : _loginUser,
                        child: _isLoading
                            ? const CircularProgressIndicator(
                                color: Colors.white,
                              )
                            : const Text(
                                'Нэвтрэх',
                                style: TextStyle(
                                  color: Color.fromARGB(255, 59, 132, 96),
                                ),
                              ),
                      ),
                    ),

                    const SizedBox(height: 15),

                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Бүртгэлгүй юу?',
                          style: TextStyle(color: Colors.white),
                        ),
                        TextButton(
                          onPressed: () {
                            Navigator.pushNamed(context, '/register');
                          },
                          child: const Text(
                            'Бүртгүүлэх',
                            style: TextStyle(color: Colors.greenAccent),
                          ),
                        ),
                      ],
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
