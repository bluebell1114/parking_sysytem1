import 'dart:async';

import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

import 'auth_prefs.dart';
import 'backend_api.dart';

class SpotsAdminPage extends StatefulWidget {
  const SpotsAdminPage({super.key});

  @override
  State<SpotsAdminPage> createState() => _SpotsAdminPageState();
}

class _SpotsAdminPageState extends State<SpotsAdminPage> {
  static const LatLng ub = LatLng(47.918873, 106.917701);

  GoogleMapController? mapController;
  Set<Marker> markers = {};
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _load();
    _poll = Timer.periodic(const Duration(seconds: 3), (_) => _load());
  }

  Future<void> _load() async {
    try {
      final rows = await BackendApi.fetchSpots();
      if (!mounted) return;
      final next = <Marker>{};
      for (final data in rows) {
        final id = data['id']?.toString() ?? '';
        final lat = data['lat'];
        final lng = data['lng'];
        if (id.isEmpty || lat is! num || lng is! num) continue;
        final status = (data['status'] as String?) ?? 'free';
        final hue = status == 'free'
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed;
        next.add(
          Marker(
            markerId: MarkerId(id),
            position: LatLng(lat.toDouble(), lng.toDouble()),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(title: data['name']?.toString() ?? 'Зогсоол', snippet: status),
            onTap: () => _toggleStatus(id, status),
          ),
        );
      }
      setState(() => markers = next);
    } catch (e) {
      debugPrint('spots admin: $e');
    }
  }

  Future<void> _toggleStatus(String id, String status) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) return;
    final newStatus = status == 'free' ? 'occupied' : 'free';
    try {
      await BackendApi.adminPatchSpot(token: token, id: id, status: newStatus);
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  Future<void> _addParking(LatLng position) async {
    final token = await AuthPrefs.getToken();
    if (token == null || token.isEmpty) return;
    try {
      await BackendApi.adminCreateSpot(
        token: token,
        lat: position.latitude,
        lng: position.longitude,
        name: 'Зогсоол',
      );
      await _load();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$e')));
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Parking Dashboard")),
      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: ub, zoom: 14),
        markers: markers,
        onTap: _addParking,
        myLocationEnabled: true,
        trafficEnabled: true,
        onMapCreated: (controller) {
          mapController = controller;
        },
      ),
    );
  }
}
