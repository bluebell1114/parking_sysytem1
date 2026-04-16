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
        final name = data['name']?.toString() ?? 'Зогсоол';
        final hue = status == 'free'
            ? BitmapDescriptor.hueGreen
            : BitmapDescriptor.hueRed;
        next.add(
          Marker(
            markerId: MarkerId(id),
            position: LatLng(lat.toDouble(), lng.toDouble()),
            icon: BitmapDescriptor.defaultMarkerWithHue(hue),
            infoWindow: InfoWindow(title: name, snippet: status),
            onTap: () => _openSpotActions(id: id, status: status, name: name),
          ),
        );
      }
      setState(() => markers = next);
    } catch (e) {
      debugPrint('spots admin: $e');
    }
  }

  Future<void> _openSpotActions({
    required String id,
    required String status,
    required String name,
  }) async {
    final token = await AuthPrefs.getToken();
    if (!mounted) return;
    if (token == null || token.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Admin token байхгүй байна. Нэвтэрнэ үү.')),
      );
      return;
    }

    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (ctx) {
        final nextStatus = status == 'free' ? 'occupied' : 'free';
        final nextStatusLabel = status == 'free' ? 'Occupied болгох' : 'Free болгох';
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  name,
                  style: Theme.of(ctx).textTheme.titleMedium,
                ),
                const SizedBox(height: 6),
                Text('ID: $id', style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.swap_horiz),
                  title: Text(nextStatusLabel),
                  subtitle: Text('Одоогийн төлөв: $status → $nextStatus'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    try {
                      await BackendApi.adminPatchSpot(
                        token: token,
                        id: id,
                        status: nextStatus,
                      );
                      await _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Алдаа: $e')),
                      );
                    }
                  },
                ),
                const Divider(),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.delete, color: Colors.red),
                  title: const Text('Устгах', style: TextStyle(color: Colors.red)),
                  subtitle: const Text('Жагсаалтаас нууна (archive).'),
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final ok = await showDialog<bool>(
                      context: context,
                      builder: (dctx) => AlertDialog(
                        title: const Text('Устгах уу?'),
                        content: Text('“$name” зогсоолыг устгах уу?'),
                        actions: [
                          TextButton(
                            onPressed: () => Navigator.of(dctx).pop(false),
                            child: const Text('Болих'),
                          ),
                          FilledButton(
                            onPressed: () => Navigator.of(dctx).pop(true),
                            child: const Text('Устгах'),
                          ),
                        ],
                      ),
                    );
                    if (ok != true) return;
                    try {
                      await BackendApi.adminDeleteSpot(token: token, id: id);
                      await _load();
                    } catch (e) {
                      if (!mounted) return;
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text('Устгахад алдаа: $e')),
                      );
                    }
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
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
