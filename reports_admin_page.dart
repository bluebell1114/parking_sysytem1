import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'admin_service.dart';

class ReportsAdminPage extends StatefulWidget {
  const ReportsAdminPage({super.key});

  @override
  State<ReportsAdminPage> createState() => _ReportsAdminPageState();
}

class _ReportsAdminPageState extends State<ReportsAdminPage> {
  final admin = AdminService();

  DateTimeRange range = DateTimeRange(
    start: DateTime.now().subtract(const Duration(days: 7)),
    end: DateTime.now(),
  );

  bool loading = false;
  Map<String, dynamic>? report;
  String? errorText;

  Future<void> _load() async {
    setState(() {
      loading = true;
      errorText = null;
    });

    try {
      final r = await admin.salesReport(from: range.start, to: range.end);
      if (!mounted) return;
      setState(() => report = r);
    } on FirebaseException catch (e) {
      // 🔥 яг ямар алдаа вэ гэдгийг эндээс харах боломжтой болно
      if (!mounted) return;

      if (e.code == 'failed-precondition') {
        setState(
          () => errorText =
              "Firestore index хэрэгтэй байна. (failed-precondition)\nFirebase Console → Firestore → Indexes дээр үүсгэнэ.",
        );
      } else if (e.code == 'permission-denied') {
        setState(
          () => errorText = "Firestore permission-denied. Rules-ээ шалгаарай.",
        );
      } else {
        setState(
          () => errorText = "Firestore алдаа: ${e.code}\n${e.message ?? ''}",
        );
      }
    } catch (e) {
      if (!mounted) return;
      setState(() => errorText = "Алдаа: $e");
    } finally {
      if (!mounted) return;
      setState(() => loading = false);
    }
  }

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Хугацаа: ${range.start.toLocal().toString().split(" ").first} → ${range.end.toLocal().toString().split(" ").first}',
                ),
              ),
              TextButton(
                onPressed: () async {
                  final picked = await showDateRangePicker(
                    context: context,
                    firstDate: DateTime(2020),
                    lastDate: DateTime.now(),
                    initialDateRange: range,
                  );
                  if (picked != null) {
                    setState(() => range = picked);
                    await _load();
                  }
                },
                child: const Text('Сонгох'),
              ),
            ],
          ),
          const SizedBox(height: 16),

          if (loading) const CircularProgressIndicator(),

          if (!loading && errorText != null) ...[
            Text(errorText!, style: const TextStyle(color: Colors.red)),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _load,
              child: const Text("Дахин ачаалах"),
            ),
          ],

          if (!loading && errorText == null && report != null)
            Card(
              child: ListTile(
                title: Text('Approved төлбөр: ${report!['count']} ширхэг'),
                subtitle: Text('Нийт орлого: ₮${report!['totalAmount']}'),
              ),
            ),
        ],
      ),
    );
  }
}
