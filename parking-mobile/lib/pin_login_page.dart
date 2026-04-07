import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';
import 'package:shared_preferences/shared_preferences.dart';

class PinLoginPage extends StatefulWidget {
  const PinLoginPage({super.key});

  @override
  State<PinLoginPage> createState() => _PinLoginPageState();
}

class _PinLoginPageState extends State<PinLoginPage> {
  String enteredPin = "";

  Future<void> checkPin() async {
    final prefs = await SharedPreferences.getInstance();
    String? savedPin = prefs.getString("user_pin");

    if (enteredPin == savedPin) {
      Navigator.pushReplacementNamed(context, "/home");
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("PIN буруу байна")));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(30),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                "PIN оруулна уу",
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),

              const SizedBox(height: 40),

              PinCodeTextField(
                appContext: context,
                length: 4,
                keyboardType: TextInputType.number,
                obscureText: true,

                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.circle,
                  fieldHeight: 60,
                  fieldWidth: 60,
                  activeColor: Colors.blue,
                  selectedColor: Colors.blue,
                  inactiveColor: Colors.grey,
                ),

                onChanged: (value) {
                  enteredPin = value;
                },

                onCompleted: (value) {
                  checkPin();
                },
              ),

              const SizedBox(height: 20),

              const Text(
                "4 оронтой PIN оруулна уу",
                style: TextStyle(color: Colors.grey),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
