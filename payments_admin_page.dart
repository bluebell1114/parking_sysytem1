import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_service.dart';

class PaymentsAdminPage extends StatelessWidget {
  const PaymentsAdminPage({super.key});

  @override
  Widget build(BuildContext context) {
    final admin = AdminService();

    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: admin.pendingPaymentsStream(),
      builder: (context, snap) {
        if (snap.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (snap.hasError) {
          return Center(child: Text("Алдаа: ${snap.error}"));
        }

        final docs = snap.data?.docs ?? [];
        if (docs.isEmpty) {
          return const Center(child: Text("Pending төлбөр алга"));
        }

        return ListView.separated(
          itemCount: docs.length,
          separatorBuilder: (_, __) => const Divider(height: 1),
          itemBuilder: (_, i) {
            final d = docs[i];
            final data = d.data();

            final amount = (data['amount'] ?? 0) as int;
            final hours = (data['hours'] ?? 0) as int;
            final userId = (data['userId'] ?? '-') as String;
            final spotId = (data['spotId'] ?? '-') as String;

            return ListTile(
              title: Text('₮$amount • ${hours}цаг'),
              subtitle: Text('user: $userId\nspot: $spotId'),
              isThreeLine: true,
              trailing: Wrap(
                spacing: 8,
                children: [
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      await admin.rejectPayment(paymentId: d.id, adminUid: uid);
                    },
                  ),
                  IconButton(
                    icon: const Icon(Icons.check),
                    onPressed: () async {
                      final uid = FirebaseAuth.instance.currentUser?.uid;
                      if (uid == null) return;
                      await admin.approvePayment(
                        paymentId: d.id,
                        adminUid: uid,
                      );
                    },
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }
}
