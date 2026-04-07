import 'package:cloud_firestore/cloud_firestore.dart';

class AdminService {
  final _db = FirebaseFirestore.instance;

  // ---------- Parking spots ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> spotsStream() {
    return _db
        .collection('parking_spots')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> createSpot({
    required String name,
    required double lat,
    required double lng,
    required int pricePerHour,
  }) async {
    await _db.collection('parking_spots').add({
      'name': name,
      'location': {'lat': lat, 'lng': lng},
      'pricePerHour': pricePerHour,
      'isAvailable': true,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> setSpotAvailability(String spotId, bool isAvailable) {
    return _db.collection('parking_spots').doc(spotId).update({
      'isAvailable': isAvailable,
    });
  }

  Future<void> deleteSpot(String spotId) {
    return _db.collection('parking_spots').doc(spotId).delete();
  }

  // ---------- Payments ----------
  Stream<QuerySnapshot<Map<String, dynamic>>> pendingPaymentsStream() {
    return _db
        .collection('payments')
        .where('status', isEqualTo: 'pending')
        .orderBy('createdAt', descending: true)
        .snapshots();
  }

  Future<void> approvePayment({
    required String paymentId,
    required String adminUid,
  }) {
    return _db.collection('payments').doc(paymentId).update({
      'status': 'approved',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> rejectPayment({
    required String paymentId,
    required String adminUid,
    String? reason,
  }) {
    return _db.collection('payments').doc(paymentId).update({
      'status': 'rejected',
      'approvedBy': adminUid,
      'approvedAt': FieldValue.serverTimestamp(),
      if (reason != null) 'rejectReason': reason,
    });
  }

  /// Хэрэглэгчийн төлбөрийн хүсэлт — админы `pending` жагсаалтад орно.
  Future<void> submitPendingPayment({
    required String userId,
    required String userEmail,
    required int amount,
    required String method,
    int hours = 1,
    String spotId = '',
    String? note,
  }) async {
    if (amount < 1) {
      throw ArgumentError('Дүн 1-ээс багагүй байх ёстой');
    }
    await _db.collection('payments').add({
      'userId': userId,
      'userEmail': userEmail,
      'amount': amount,
      'hours': hours,
      'spotId': spotId,
      'status': 'pending',
      'method': method,
      if (note != null && note.isNotEmpty) 'note': note,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  // ---------- Report ----------
  Future<Map<String, dynamic>> salesReport({
    required DateTime from,
    required DateTime to,
  }) async {
    final snap = await _db
        .collection('payments')
        .where('status', isEqualTo: 'approved')
        .where('approvedAt', isGreaterThanOrEqualTo: Timestamp.fromDate(from))
        .where('approvedAt', isLessThanOrEqualTo: Timestamp.fromDate(to))
        .get();

    int total = 0;
    for (final d in snap.docs) {
      total += (d.data()['amount'] ?? 0) as int;
    }

    return {'count': snap.docs.length, 'totalAmount': total};
  }
}
