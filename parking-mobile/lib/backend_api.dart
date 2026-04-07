import 'dart:convert';

import 'package:http/http.dart' as http;

import 'api_config.dart';
import 'auth_prefs.dart';

class BackendApiException implements Exception {
  BackendApiException(this.message, this.statusCode);
  final String message;
  final int statusCode;

  @override
  String toString() => message;
}

class BackendApi {
  static Map<String, String> _jsonHeaders({String? token}) {
    return {
      'Content-Type': 'application/json',
      if (token != null && token.isNotEmpty) 'Authorization': 'Bearer $token',
    };
  }

  static Map<String, dynamic> _decodeObj(http.Response r) {
    if (r.body.isEmpty) return {};
    final v = jsonDecode(r.body);
    if (v is Map<String, dynamic>) return v;
    return {};
  }

  static void _throwIfBad(http.Response r) {
    if (r.statusCode < 400) return;
    final m = _decodeObj(r);
    final err = m['error']?.toString() ?? r.body;
    throw BackendApiException(err.isEmpty ? 'Алдаа ${r.statusCode}' : err, r.statusCode);
  }

  static Future<Map<String, dynamic>> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/auth/register'),
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email, 'password': password, 'name': name}),
    );
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<Map<String, dynamic>> login({
    required String email,
    required String password,
  }) async {
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/auth/login'),
      headers: _jsonHeaders(),
      body: jsonEncode({'email': email, 'password': password}),
    );
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<void> postLocation({
    required double lat,
    required double lng,
    double? accuracyM,
    String? label,
  }) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) return;
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/locations'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({
        'lat': lat,
        'lng': lng,
        if (accuracyM != null) 'accuracy_m': accuracyM,
        if (label != null) 'label': label,
      }),
    );
    _throwIfBad(r);
  }

  static Future<List<Map<String, dynamic>>> fetchSpots() async {
    final r = await http.get(Uri.parse('${apiBaseUrl()}/spots'));
    _throwIfBad(r);
    final m = _decodeObj(r);
    final items = m['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> submitPayment({
    required int amount,
    required int hours,
    required String method,
    String spotId = '',
    String? note,
    String? userEmail,
  }) async {
    final token = await AuthPrefs.getToken();
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/payments'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({
        'amount': amount,
        'hours': hours,
        'method': method,
        'spot_id': spotId,
        if (note != null) 'note': note,
        if (userEmail != null) 'user_email': userEmail,
      }),
    );
    _throwIfBad(r);
  }

  static Future<Map<String, dynamic>?> activeBooking() async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw BackendApiException('token_required', 401);
    }
    final r = await http.get(
      Uri.parse('${apiBaseUrl()}/bookings/active'),
      headers: _jsonHeaders(token: token),
    );
    _throwIfBad(r);
    final m = _decodeObj(r);
    final a = m['active'];
    if (a == null) return null;
    if (a is! Map) return null;
    return Map<String, dynamic>.from(a);
  }

  static Future<Map<String, dynamic>> startBooking({
    required String spotId,
  }) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw BackendApiException('token_required', 401);
    }
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/bookings/start'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'spot_id': spotId}),
    );
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<Map<String, dynamic>> payBooking({
    required String bookingId,
    required String method,
  }) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw BackendApiException('token_required', 401);
    }
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/bookings/pay'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'booking_id': bookingId, 'method': method}),
    );
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<Map<String, dynamic>> walletMe() async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw BackendApiException('token_required', 401);
    }
    final r = await http.get(
      Uri.parse('${apiBaseUrl()}/wallet/me'),
      headers: _jsonHeaders(token: token),
    );
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<int> walletTopup({
    required int amount,
    required String method,
    String? note,
  }) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) {
      throw BackendApiException('token_required', 401);
    }
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/wallet/topup'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({
        'amount': amount,
        'method': method,
        if (note != null) 'note': note,
      }),
    );
    _throwIfBad(r);
    final m = _decodeObj(r);
    final b = m['balance'];
    if (b is int) return b;
    return int.tryParse(b?.toString() ?? '') ?? 0;
  }

  static Future<List<Map<String, dynamic>>> adminPendingPayments({
    required String token,
  }) async {
    final r = await http.get(
      Uri.parse('${apiBaseUrl()}/admin/payments/pending'),
      headers: _jsonHeaders(token: token),
    );
    _throwIfBad(r);
    final m = _decodeObj(r);
    final items = m['items'];
    if (items is! List) return [];
    return items.map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  static Future<void> adminApprovePayment({
    required String token,
    required String paymentId,
  }) async {
    final r = await http.patch(
      Uri.parse('${apiBaseUrl()}/admin/payments/$paymentId'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'action': 'approve'}),
    );
    _throwIfBad(r);
  }

  static Future<void> adminRejectPayment({
    required String token,
    required String paymentId,
  }) async {
    final r = await http.patch(
      Uri.parse('${apiBaseUrl()}/admin/payments/$paymentId'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'action': 'reject'}),
    );
    _throwIfBad(r);
  }

  static Future<Map<String, dynamic>> adminSalesReport({
    required String token,
    required DateTime from,
    required DateTime to,
  }) async {
    final u = Uri.parse('${apiBaseUrl()}/admin/reports').replace(
      queryParameters: {
        'from': from.toUtc().toIso8601String(),
        'to': to.toUtc().toIso8601String(),
      },
    );
    final r = await http.get(u, headers: _jsonHeaders(token: token));
    _throwIfBad(r);
    return _decodeObj(r);
  }

  static Future<void> adminCreateSpot({
    required String token,
    required double lat,
    required double lng,
    String name = 'Зогсоол',
  }) async {
    final r = await http.post(
      Uri.parse('${apiBaseUrl()}/admin/spots'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'name': name, 'lat': lat, 'lng': lng}),
    );
    _throwIfBad(r);
  }

  static Future<void> adminPatchSpot({
    required String token,
    required String id,
    required String status,
  }) async {
    final r = await http.patch(
      Uri.parse('${apiBaseUrl()}/admin/spots/$id'),
      headers: _jsonHeaders(token: token),
      body: jsonEncode({'status': status}),
    );
    _throwIfBad(r);
  }

  static Future<void> adminDeleteSpot({
    required String token,
    required String id,
  }) async {
    final r = await http.delete(
      Uri.parse('${apiBaseUrl()}/admin/spots/$id'),
      headers: _jsonHeaders(token: token),
    );
    _throwIfBad(r);
  }
}
