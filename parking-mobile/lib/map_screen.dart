import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

/// Энгийн газрын зураг (Places API хамаарлыг Android build алдаанаас зайлсхийхийн тулд хассан).
/// Үндсэн аппын `home_page.dart` дахь MapScreen Firestore-той ажиллана.
class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const LatLng ub = LatLng(47.918873, 106.917701);

  GoogleMapController? mapController;

  bool showCard = false;
  String locationName = "";

  Set<Marker> markers = {
    const Marker(
      markerId: MarkerId("parking1"),
      position: LatLng(47.918873, 106.917701),
      infoWindow: InfoWindow(title: "Car Parking", snippet: "Ulaanbaatar"),
    ),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parking Map")),
      body: Stack(
        children: [
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: ub, zoom: 14),
            markers: markers,
            myLocationEnabled: true,
            trafficEnabled: true,
            buildingsEnabled: true,
            onMapCreated: (controller) {
              mapController = controller;
            },
          ),
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: const Row(
                children: [
                  Icon(Icons.info_outline, size: 20, color: Colors.black54),
                  SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      "Бүх зогсоолыг үндсэн апп → Map табаас харна уу.",
                      style: TextStyle(fontSize: 13, color: Colors.black87),
                    ),
                  ),
                ],
              ),
            ),
          ),
          if (showCard)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 22, 52, 144),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, color: Colors.red, size: 35),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        locationName,
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () {
                        setState(() => showCard = false);
                      },
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
