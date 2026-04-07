import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'firebase_options.dart';
import 'login_page.dart';
import 'register_page.dart';
import 'start_page.dart';
import 'home_page.dart';
import 'admin_login.dart';
import 'pin_login_page.dart';
import 'create_pin_page.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  final prefs = await SharedPreferences.getInstance();
  String? pin = prefs.getString("user_pin");

  runApp(MyApp(pinExists: pin != null));
}

class MyApp extends StatelessWidget {
  final bool pinExists;

  const MyApp({super.key, required this.pinExists});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'Parking_management_system',
      home: pinExists ? const PinLoginPage() : const StartPage(),

      routes: {
        '/start': (context) => const StartPage(),
        '/login': (context) => const LoginPage(),
        '/pin': (context) => const PinLoginPage(),
        '/createPin': (context) => const CreatePinPage(),
        '/home': (context) => const HomePage(),
        '/register': (context) => const RegisterPage(),
        '/admin': (context) => const AdminLoginPage(),
      },
    );
  }
}
