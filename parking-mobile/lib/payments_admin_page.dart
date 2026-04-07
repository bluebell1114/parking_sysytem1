import 'dart:async';

import 'package:flutter/material.dart';

import 'auth_prefs.dart';
import 'backend_api.dart';

class PaymentsAdminPage extends StatefulWidget {
  const PaymentsAdminPage({super.key});

  @override
  State<PaymentsAdminPage> createState() => _PaymentsAdminPageState();
}

class _PaymentsAdminPageState extends State<PaymentsAdminPage> {
  List<Map<String, dynamic>> _items = [];
  String? _error;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final token = await AuthPrefs.getToken();
      if (token == null || token.isEmpty) {
        if (mounted) setState(() => _error = 'Нэвтрэх шаардлагатай');
        return;
      }
      final list = await BackendApi.adminPendingPayments(token: token);
      if (!mounted) return;
      setState(() {
        _items = list;
        _error = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _error = '$e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(_error!, textAlign: TextAlign.center),
              TextButton(onPressed: _load, child: const Text('Дахин')),
            ],
          ),
        ),
      );
    }

    if (_items.isEmpty) {
      return const Center(child: Text('Pending төлбөр алга'));
    }

    return ListView.separated(
      itemCount: _items.length,
      separatorBuilder: (_, __) => const Divider(height: 1),
      itemBuilder: (_, i) {
        final data = _items[i];
        final id = data['id']?.toString() ?? '';
        final amount = data['amount'] is int
            ? data['amount'] as int
            : int.tryParse('${data['amount']}') ?? 0;
        final hours = data['hours'] is int
            ? data['hours'] as int
            : int.tryParse('${data['hours']}') ?? 0;
        final userId = (data['user_ref'] ?? data['userId'] ?? '-') as Object;
        final userEmail = data['user_email'] as String? ?? data['userEmail'] as String?;
        final method = (data['method'] ?? '-') as String;
        final spotId = (data['spot_id'] ?? data['spotId'] ?? '-') as Object;

        return ListTile(
          title: Text('₮$amount • $hours цаг • $method'),
          subtitle: Text(
            '${userEmail != null && userEmail.isNotEmpty ? '$userEmail\n' : ''}ref: $userId\nspot: $spotId',
          ),
          isThreeLine: true,
          trailing: Wrap(
            spacing: 8,
            children: [
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () async {
                  final token = await AuthPrefs.getToken();
                  if (token == null || id.isEmpty) return;
                  try {
                    await BackendApi.adminRejectPayment(token: token, paymentId: id);
                    await _load();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.check),
                onPressed: () async {
                  final token = await AuthPrefs.getToken();
                  if (token == null || id.isEmpty) return;
                  try {
                    await BackendApi.adminApprovePayment(token: token, paymentId: id);
                    await _load();
                  } catch (e) {
                    if (!context.mounted) return;
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('$e')),
                    );
                  }
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
