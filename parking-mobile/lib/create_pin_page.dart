import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

class CreatePinPage extends StatefulWidget {
  const CreatePinPage({super.key});

  @override
  State<CreatePinPage> createState() => _CreatePinPageState();
}

class _CreatePinPageState extends State<CreatePinPage> {
  String pin = "";

  Future<void> savePin() async {
    if (pin.length != 4) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("4 оронтой PIN оруулна уу")));
      return;
    }

    final prefs = await SharedPreferences.getInstance();
    await prefs.setString("user_pin", pin);

    if (!mounted) return;
    Navigator.pushReplacementNamed(context, "/home");
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("PIN үүсгэх")),

      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            const SizedBox(height: 40),

            const Text(
              "4 оронтой PIN үүсгэнэ үү",
              style: TextStyle(fontSize: 20),
            ),

            const SizedBox(height: 40),

            PinCodeTextField(
              appContext: context,
              length: 4,
              onChanged: (value) {
                pin = value;
              },
              keyboardType: TextInputType.number,
            ),

            const SizedBox(height: 30),

            ElevatedButton(onPressed: savePin, child: const Text("Хадгалах")),
          ],
        ),
      ),
    );
  }
}
