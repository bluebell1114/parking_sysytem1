import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

class SpotsAdminPage extends StatefulWidget {
  const SpotsAdminPage({super.key});

  @override
  State<SpotsAdminPage> createState() => _SpotsAdminPageState();
}

class _SpotsAdminPageState extends State<SpotsAdminPage> {
  static const LatLng ub = LatLng(47.918873, 106.917701);

  GoogleMapController? mapController;

  Set<Marker> markers = {};

  @override
  void initState() {
    super.initState();
    loadParking();
  }

  /// FIRESTORE-ООС PARKING УНШИХ
  void loadParking() {
    FirebaseFirestore.instance.collection("parking_spots").snapshots().listen((
      snapshot,
    ) {
      Set<Marker> newMarkers = {};

      for (var doc in snapshot.docs) {
        final data = doc.data();

        if (data["lat"] != null && data["lng"] != null) {
          final lat = data["lat"];
          final lng = data["lng"];
          final status = data["status"];

          BitmapDescriptor markerColor;

          if (status == "free") {
            markerColor = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueGreen,
            );
          } else {
            markerColor = BitmapDescriptor.defaultMarkerWithHue(
              BitmapDescriptor.hueRed,
            );
          }

          newMarkers.add(
            Marker(
              markerId: MarkerId(doc.id),
              position: LatLng(lat, lng),
              icon: markerColor,

              infoWindow: InfoWindow(title: "Parking", snippet: status),

              onTap: () {
                changeStatus(doc.id, status);
              },
            ),
          );
        }
      }

      setState(() {
        markers = newMarkers;
      });
    });
  }

  /// MAP ДЭЭР ДАРАХАД PARKING НЭМЭХ
  void addParking(LatLng position) {
    FirebaseFirestore.instance.collection("parking_spots").add({
      "lat": position.latitude,
      "lng": position.longitude,
      "status": "free",
    });
  }

  /// PARKING STATUS ӨӨРЧЛӨХ
  void changeStatus(String id, String status) {
    String newStatus = status == "free" ? "occupied" : "free";

    FirebaseFirestore.instance.collection("parking_spots").doc(id).update({
      "status": newStatus,
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Admin Parking Dashboard")),

      body: GoogleMap(
        initialCameraPosition: const CameraPosition(target: ub, zoom: 14),

        markers: markers,

        /// MAP ДЭЭР TAP
        onTap: (LatLng position) {
          addParking(position);
        },

        myLocationEnabled: true,

        trafficEnabled: true,

        onMapCreated: (controller) {
          mapController = controller;
        },
      ),
    );
  }
}
