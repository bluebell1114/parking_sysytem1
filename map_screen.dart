import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:flutter_google_places/flutter_google_places.dart';
import 'package:google_maps_webservice/places.dart';

const String googleApiKey = "AIzaSyDdMFjSucfVXID2IBGxI0UBZp_HRtqnFO8c";

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

  final places = GoogleMapsPlaces(apiKey: googleApiKey);

  Set<Marker> markers = {
    const Marker(
      markerId: MarkerId("parking1"),
      position: LatLng(47.918873, 106.917701),
      infoWindow: InfoWindow(title: "Car Parking", snippet: "Ulaanbaatar"),
    ),
  };

  /// SEARCH FUNCTION
  Future<void> searchPlaces() async {
    Prediction? prediction = await PlacesAutocomplete.show(
      context: context,
      apiKey: googleApiKey,
      mode: Mode.overlay,
      language: "en",
    );

    if (prediction != null) {
      PlacesDetailsResponse detail = await places.getDetailsByPlaceId(
        prediction.placeId!,
      );

      final lat = detail.result.geometry!.location.lat;
      final lng = detail.result.geometry!.location.lng;

      setState(() {
        locationName = detail.result.name;
        showCard = true;

        markers.add(
          Marker(
            markerId: const MarkerId("searchedLocation"),
            position: LatLng(lat, lng),
            infoWindow: InfoWindow(title: detail.result.name),
          ),
        );
      });

      mapController?.animateCamera(
        CameraUpdate.newLatLngZoom(LatLng(lat, lng), 16),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parking Map")),

      body: Stack(
        children: [
          /// GOOGLE MAP
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

          /// SEARCH BAR
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: GestureDetector(
              onTap: searchPlaces,

              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 255, 255, 255),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 5),
                  ],
                ),
                child: const TextField(
                  enabled: false,
                  decoration: InputDecoration(
                    hintText: "Search location",
                    border: InputBorder.none,
                    icon: Icon(Icons.search),
                  ),
                ),
              ),
            ),
          ),

          /// LOCATION CARD
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
                        ),
                      ),
                    ),

                    IconButton(
                      icon: const Icon(Icons.close),
                      onPressed: () {
                        setState(() {
                          showCard = false;
                        });
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
