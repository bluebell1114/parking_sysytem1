import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

void main() {
  runApp(const ParkingApp());
}

class ParkingApp extends StatelessWidget {
  const ParkingApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primaryColor: const Color.fromARGB(255, 3, 43, 92),
        scaffoldBackgroundColor: Colors.grey[100],
        textTheme: GoogleFonts.notoSansTextTheme(),
      ),
      home: const ParkingScreen(),
    );
  }
}

class ParkingScreen extends StatefulWidget {
  const ParkingScreen({super.key});

  @override
  State<ParkingScreen> createState() => _ParkingScreenState();
}

class _ParkingScreenState extends State<ParkingScreen> {
  String selectedType = "Хувь хүн";

  @override
  Widget build(BuildContext context) {
    final size = MediaQuery.of(context).size;
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: theme.scaffoldBackgroundColor,
        elevation: 0,
        centerTitle: true,
        title: Text(
          "",
          style: TextStyle(
            color: theme.brightness == Brightness.dark
                ? Colors.white
                : Colors.black,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: SingleChildScrollView(
        padding: EdgeInsets.symmetric(
          horizontal: size.width * 0.06,
          vertical: size.height * 0.02,
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Text(
                "Parking",
                style: TextStyle(
                  color: const Color.fromARGB(255, 2, 47, 103),
                  fontSize: size.width * 0.08,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            SizedBox(height: size.height * 0.01),
            Center(
              child: Text(
                "Машины дугаараа оруулаад төлбөртэй\nзогсоолд шууд нэвтэрээрэй.",
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.grey[700],
                  fontSize: size.width * 0.04,
                ),
              ),
            ),
            SizedBox(height: size.height * 0.03),
            Container(
              padding: EdgeInsets.all(size.width * 0.04),
              decoration: BoxDecoration(
                color: theme.cardColor,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  if (theme.brightness == Brightness.light)
                    BoxShadow(
                      color: Colors.black12,
                      blurRadius: 6,
                      offset: const Offset(0, 2),
                    ),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Container(
                        height: size.width * 0.1,
                        width: size.width * 0.1,
                        decoration: BoxDecoration(
                          color: const Color.fromARGB(255, 10, 27, 83),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Icon(Icons.add, color: Colors.white),
                      ),
                      SizedBox(width: size.width * 0.03),
                      Expanded(
                        child: TextField(
                          decoration: InputDecoration(
                            suffixText: '',
                            labelText: 'Машины дугаар',
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.02),
                  const Divider(),
                  SizedBox(height: size.height * 0.01),

                  infoRow("Нийт төлбөр", "10000.0₮", bold: true),
                  infoRow("Зогссон хугацаа:", "00:50:17"),
                  infoRow("Зогсоол:", "Novel Parking"),
                  infoRow("Орсон огноо:", "2025.05.04 - 15:48"),

                  SizedBox(height: size.height * 0.02),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color.fromARGB(255, 11, 27, 81),
                          title: const Text("Хувь хүн"),
                          value: "Хувь хүн",
                          groupValue: selectedType,
                          onChanged: (value) =>
                              setState(() => selectedType = value!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile(
                          contentPadding: EdgeInsets.zero,
                          activeColor: const Color.fromARGB(255, 3, 46, 99),
                          title: const Text("Байгууллага"),
                          value: "Байгууллага",
                          groupValue: selectedType,
                          onChanged: (value) =>
                              setState(() => selectedType = value!),
                        ),
                      ),
                    ],
                  ),

                  SizedBox(height: size.height * 0.01),
                  TextField(
                    decoration: InputDecoration(
                      hintText: "Email хаягаа бичнэ үү",
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                  ),

                  SizedBox(height: size.height * 0.02),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color.fromARGB(255, 3, 38, 91),
                        padding: EdgeInsets.symmetric(
                          vertical: size.height * 0.018,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(10),
                        ),
                      ),
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const PaymentScreen(),
                          ),
                        );
                      },
                      child: const Text(
                        "Төлбөр төлөх",
                        style: TextStyle(color: Colors.white, fontSize: 16),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget infoRow(String label, String value, {bool bold = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: Colors.grey)),
          Text(
            value,
            style: TextStyle(
              fontWeight: bold ? FontWeight.bold : FontWeight.normal,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'qpay';
  final double totalAmount = 5000;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        backgroundColor: const Color(0xFF253C78),
        title: const Text(" Төлбөрийн дэлгэц"),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildAmount(),
            const SizedBox(height: 25),
            const Text(
              "Төлбөрийн арга сонгох",
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),

            _buildMethodCard(
              method: 'qpay',
              title: "QPay (QR төлбөр)",
              icon: Icons.qr_code_2,
              subtitle: "Банкны апп ашиглан QR уншуулна уу",
            ),
            _buildMethodCard(
              method: 'bank',
              title: "Дансанд шилжүүлэх",
              icon: Icons.account_balance,
              subtitle: "Хаан, Голомт, Хас гэх мэт",
            ),

            const SizedBox(height: 25),
            if (selectedMethod == 'qpay') _buildQpayWidget(),
            if (selectedMethod == 'bank') _buildBankInfo(),

            const SizedBox(height: 35),
            Center(
              child: ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFF253C78),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 80,
                    vertical: 16,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text("Төлбөр амжилттай хийгдлээ!")),
                  );
                },
                icon: const Icon(Icons.check_circle_outline),
                label: const Text(
                  "ТӨЛӨХ",
                  style: TextStyle(fontSize: 18, color: Colors.white),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAmount() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text("Төлөх дүн", style: TextStyle(color: Colors.grey)),
          const SizedBox(height: 5),
          Text(
            "₮ ${totalAmount.toStringAsFixed(0)}",
            style: const TextStyle(
              fontSize: 36,
              fontWeight: FontWeight.bold,
              color: Color(0xFF253C78),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildQpayWidget() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: Column(
        children: [
          const Text(
            "QPay QR код уншуулна уу",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 16),
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: Colors.grey[300],
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 160,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 12),
          const Text(
            "QR кодыг банкны апп-аар уншуулж төлнө үү.",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildBankInfo() {
    return Container(
      margin: const EdgeInsets.only(top: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 5)],
      ),
      child: const Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "🏦 Дансны мэдээлэл",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 10),
          Text("Банк: Хаан банк"),
          Text("Дансны дугаар: 5012345678"),
          Text("Дансны нэр: MyParking LLC"),
          SizedBox(height: 10),
          Text(
            "Гүйлгээний утга: Машины дугаар эсвэл нэрээ бичнэ үү.",
            style: TextStyle(color: Colors.grey),
          ),
        ],
      ),
    );
  }

  Widget _buildMethodCard({
    required String method,
    required String title,
    required String subtitle,
    required IconData icon,
  }) {
    final bool selected = selectedMethod == method;

    return GestureDetector(
      onTap: () => setState(() => selectedMethod = method),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected ? const Color(0xFF253C78) : Colors.transparent,
            width: 2,
          ),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? const Color(0xFF253C78) : Colors.grey,
              size: 30,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(subtitle, style: const TextStyle(color: Colors.grey)),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? const Color(0xFF253C78) : Colors.grey,
            ),
          ],
        ),
      ),
    );
  }
}
