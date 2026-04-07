import 'backend_api.dart';

/// Хэрэглэгчийн төлбөрийн хүсэлт → Docker `mobile_bas2` API `/payments`.
class AdminService {
  Future<void> submitPendingPayment({
    required String userId,
    required String userEmail,
    required int amount,
    required String method,
    int hours = 1,
    String spotId = '',
    String? note,
  }) {
    return BackendApi.submitPayment(
      amount: amount,
      hours: hours,
      method: method,
      spotId: spotId,
      note: note,
      userEmail: userEmail.isNotEmpty ? userEmail : null,
    );
  }
}
