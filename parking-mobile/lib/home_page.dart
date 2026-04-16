import 'dart:io';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:geolocator/geolocator.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:latlong2/latlong.dart' as ll;

import 'auth_prefs.dart';
import 'api_config.dart';
import 'backend_api.dart';

class AppColors {
  static const primary = Color.fromRGBO(244, 245, 246, 1);
  static const bg = Color.fromARGB(255, 255, 253, 253);
  static const card = Color.fromRGBO(33, 88, 144, 1);
  static const muted = Color.fromARGB(255, 191, 66, 66);
}

class AppRadii {
  static const r12 = BorderRadius.all(Radius.circular(12));
  static const r16 = BorderRadius.all(Radius.circular(16));
}

class AppShadows {
  static List<BoxShadow> soft = const [
    BoxShadow(
      color: Color.fromARGB(31, 84, 35, 35),
      blurRadius: 10,
      offset: Offset(0, 4),
    ),
  ];
}

class CarImage {
  final File? mobileFile;
  final Uint8List? webBytes;

  const CarImage({this.mobileFile, this.webBytes});

  bool get isEmpty => mobileFile == null && webBytes == null;

  ImageProvider? toImageProvider() {
    if (mobileFile != null) return FileImage(mobileFile!);
    if (webBytes != null) return MemoryImage(webBytes!);
    return null;
  }
}

class CarModel {
  final String? id;
  final String name;
  final String plate;
  final CarImage image;

  const CarModel({
    this.id,
    required this.name,
    required this.plate,
    required this.image,
  });

  CarModel copyWith({String? id, String? name, String? plate, CarImage? image}) =>
      CarModel(
        id: id ?? this.id,
        name: name ?? this.name,
        plate: plate ?? this.plate,
        image: image ?? this.image,
      );
}

class CarFormResult {
  final String name;
  final String plate;
  final CarImage image;

  const CarFormResult({
    required this.name,
    required this.plate,
    required this.image,
  });

  CarModel toModel() => CarModel(name: name, plate: plate, image: image);
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  /// Апп нээгдэхэд шууд Map таб дээр бууна.
  int _index = 1;

  late final List<Widget> _pages = const [
    CarListPage(),
    MapScreen(),
    PaymentScreen(),
    NotificationScreen(),
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _syncLocationOnce());
  }

  /// Docker `mobile_bas2`: хэрэглэгчийн байршлыг `user_locations` хүснэгтэд бичнэ.
  Future<void> _syncLocationOnce() async {
    try {
      final t = await AuthPrefs.getToken();
      if (t == null || t.isEmpty) return;
      var p = await Geolocator.checkPermission();
      if (p == LocationPermission.denied) {
        p = await Geolocator.requestPermission();
        if (p == LocationPermission.denied ||
            p == LocationPermission.deniedForever) {
          return;
        }
      }
      final pos = await Geolocator.getCurrentPosition();
      await BackendApi.postLocation(
        lat: pos.latitude,
        lng: pos.longitude,
        accuracyM: pos.accuracy,
      );
    } catch (_) {}
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_index],
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withOpacity(.12),
        onDestinationSelected: (i) => setState(() => _index = i),
        destinations: const [
          NavigationDestination(icon: Icon(Icons.directions_car), label: 'Car'),
          NavigationDestination(icon: Icon(Icons.location_on), label: 'Map'),
          NavigationDestination(icon: Icon(Icons.payment), label: 'Payment'),
          NavigationDestination(
            icon: Icon(Icons.notifications),
            label: 'Notification',
          ),
        ],
      ),
    );
  }
}

class CarListPage extends StatefulWidget {
  const CarListPage({super.key});

  @override
  State<CarListPage> createState() => _CarListPageState();
}

class _CarListPageState extends State<CarListPage> {
  final List<CarModel> _cars = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);
    try {
      final rows = await BackendApi.fetchCars();
      if (!mounted) return;
      setState(() {
        _cars
          ..clear()
          ..addAll(
            rows.map(
              (e) => CarModel(
                id: e['id']?.toString(),
                name: (e['name']?.toString() ?? '').trim().isEmpty
                    ? 'Машин'
                    : e['name']?.toString() ?? 'Машин',
                plate: e['plate']?.toString() ?? '',
                image: const CarImage(),
              ),
            ),
          );
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Машин ачаалж чадсангүй: $e')),
      );
    }
  }

  Future<void> _addCar() async {
    final CarFormResult? res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CarFormPage(title: "Add New Car"),
      ),
    );
    if (res == null) return;

    try {
      await BackendApi.createCar(name: res.name, plate: res.plate);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Нэмэхэд алдаа: $e')),
      );
    }
  }

  Future<void> _editCar(int index) async {
    final car = _cars[index];

    final CarFormResult? res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CarFormPage(
          title: "Edit Car",
          initialName: car.name,
          initialPlate: car.plate,
          initialImage: car.image,
        ),
      ),
    );

    if (res == null) return;

    final id = car.id;
    if (id == null || id.isEmpty) return;

    try {
      await BackendApi.patchCar(id: id, name: res.name, plate: res.plate);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Засахад алдаа: $e')),
      );
      return;
    }
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Editing Completed!")));
  }

  Future<void> _deleteCar(int index) async {
    final car = _cars[index];
    final id = car.id;
    if (id == null || id.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Устгах уу?'),
        content: Text('“${car.plate}” машиныг устгах уу?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Болих'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Устгах'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    try {
      await BackendApi.deleteCar(id: id);
      await _reload();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Устгахад алдаа: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Таны машин', style: TextStyle(color: Color.fromARGB(255, 17, 16, 16))),
        centerTitle: true,
        actions: [
          IconButton(
            tooltip: 'Дахин ачаалах',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _cars.isEmpty
              ? const _EmptyCars()
              : ListView.separated(
              padding: const EdgeInsets.all(16),
              itemCount: _cars.length,

              separatorBuilder: (_, __) => const SizedBox(height: 10),
              itemBuilder: (context, i) {
                final car = _cars[i];
                return _CarCard(
                  car: car,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => CarDetailsPage(car: car)),
                  ),
                  onEdit: () => _editCar(i),
                  onDelete: () => _deleteCar(i),
                );
              },
            ),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primary,
        onPressed: _addCar,
        icon: const Icon(Icons.add, color: Color.fromARGB(255, 15, 14, 14)),
        label: const Text("нэмэх", style: TextStyle(color: Color.fromARGB(255, 15, 14, 14))),
      ),
    );
  }
}

class _EmptyCars extends StatelessWidget {
  const _EmptyCars();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: const Color.fromARGB(255, 104, 93, 230),
            borderRadius: AppRadii.r16,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: const [
              Icon(Icons.directions_car, size: 56, color: Color.fromARGB(255, 7, 8, 8)),
              SizedBox(height: 12),
              Text(
                "Одоогоор машин нэмээгүй байна",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700), selectionColor: Colors.white,
              ),
              SizedBox(height: 6),
              Text(
                "",
                textAlign: TextAlign.center,
                style: TextStyle(color: Color.fromARGB(255, 231, 229, 229)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _CarCard extends StatelessWidget {
  final CarModel car;
  final VoidCallback onTap;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _CarCard({
    required this.car,
    required this.onTap,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: AppRadii.r16,
      child: InkWell(
        borderRadius: AppRadii.r16,
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: AppRadii.r16,
            boxShadow: AppShadows.soft,
          ),
          child: Row(
            children: [
              CarAvatar(image: car.image, radius: 26),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      car.name,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 16,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      car.plate,
                      style: const TextStyle(color: AppColors.muted),
                    ),
                  ],
                ),
              ),
              IconButton(
                onPressed: onEdit,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline, color: Colors.red),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class CarFormPage extends StatefulWidget {
  final String title;
  final String? initialName;
  final String? initialPlate;
  final CarImage? initialImage;

  const CarFormPage({
    super.key,
    required this.title,
    this.initialName,
    this.initialPlate,
    this.initialImage,
  });

  @override
  State<CarFormPage> createState() => _CarFormPageState();
}

class _CarFormPageState extends State<CarFormPage> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name = TextEditingController(
    text: widget.initialName ?? "",
  );
  late final TextEditingController _plate = TextEditingController(
    text: widget.initialPlate ?? "",
  );

  CarImage _image = const CarImage();

  @override
  void initState() {
    super.initState();
    _image = widget.initialImage ?? const CarImage();
  }

  @override
  void dispose() {
    _name.dispose();
    _plate.dispose();
    super.dispose();
  }

  Future<void> _pick(ImageSource source) async {
    try {
      final picker = ImagePicker();
      final XFile? img = await picker.pickImage(
        source: source,
        imageQuality: 80,
      );
      if (img == null) return;

      if (kIsWeb) {
        final bytes = await img.readAsBytes();
        setState(() => _image = CarImage(webBytes: bytes));
      } else {
        setState(() => _image = CarImage(mobileFile: File(img.path)));
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text("Зураг авахад алдаа гарлаа: $e")));
    }
  }

  void _showPicker() {
    showModalBottomSheet(
      context: context,
      showDragHandle: true,
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.photo_library),
              title: const Text("Gallery-с сонгох"),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.gallery);
              },
            ),
            ListTile(
              leading: const Icon(Icons.camera_alt),
              title: const Text("Камераар авах"),
              onTap: () {
                Navigator.pop(context);
                _pick(ImageSource.camera);
              },
            ),
            const SizedBox(height: 10),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    Navigator.pop(
      context,
      CarFormResult(
        name: _name.text.trim(),
        plate: _plate.text.trim(),
        image: _image,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color.fromARGB(255, 251, 251, 254),
      appBar: AppBar(
        title: Text(widget.title),
        backgroundColor: const Color.fromARGB(255, 36, 96, 155),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadii.r16,
            boxShadow: AppShadows.soft,
          ),
          child: Form(
            key: _formKey,
            child: Column(
              children: [
                GestureDetector(
                  onTap: _showPicker,
                  child: Column(
                    children: [
                      CarAvatar(image: _image, radius: 54),
                      const SizedBox(height: 10),
                      Text(
                        _image.isEmpty ? "Зураг нэмэх" : "Зураг солих",
                        style: const TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 18),
                _Input(
                  controller: _name,
                  label: "Машины нэр",
                  icon: Icons.directions_car,
                  validator: (v) =>
                      (v == null || v.trim().isEmpty) ? "Enter car name" : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  controller: _plate,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: TextInputType.text,
                  textCapitalization: TextCapitalization.characters,
                  inputFormatters: const [
                    _MnPlateFormatter(),
                  ],
                  validator: (v) {
                    final s = (v ?? '').trim();
                    if (s.isEmpty) return 'Улсын дугаараа оруулна уу';
                    final ok = RegExp(r'^[А-ЯӨҮ]{2}[0-9]{4}$').hasMatch(s);
                    if (!ok) return 'Жишээ: УБ1234 (2 үсэг + 4 тоо)';
                    return null;
                  },
                  decoration: InputDecoration(
                    labelText: 'Улсын дугаар',
                    hintText: 'УБ1234',
                    prefixIcon: const Icon(Icons.confirmation_number_outlined),
                    filled: true,
                    fillColor: const Color(0xFFF9FAFB),
                    border: OutlineInputBorder(borderRadius: AppRadii.r12),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: AppRadii.r12,
                      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: AppRadii.r12,
                      borderSide:
                          const BorderSide(color: AppColors.primary, width: 1.4),
                    ),
                    counterText: '',
                  ),
                  maxLength: 6,
                  onChanged: (_) => setState(() {}),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                    ),
                    onPressed: (_formKey.currentState?.validate() ?? false)
                        ? _submit
                        : null,
                    child: const Text(
                      "Save",
                      style: TextStyle(color: Colors.white, fontSize: 16),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Input extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final IconData icon;
  final String? Function(String?)? validator;

  const _Input({
    required this.controller,
    required this.label,
    required this.icon,
    this.validator,
  });

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      validator: validator,
      decoration: InputDecoration(
        labelText: label,
        prefixIcon: Icon(icon),
        filled: true,
        fillColor: const Color(0xFFF9FAFB),
        border: OutlineInputBorder(borderRadius: AppRadii.r12),
        enabledBorder: OutlineInputBorder(
          borderRadius: AppRadii.r12,
          borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: AppRadii.r12,
          borderSide: const BorderSide(color: AppColors.primary, width: 1.4),
        ),
      ),
    );
  }
}

class _MnPlateFormatter extends TextInputFormatter {
  const _MnPlateFormatter();

  @override
  TextEditingValue formatEditUpdate(
    TextEditingValue oldValue,
    TextEditingValue newValue,
  ) {
    // Keep only Cyrillic letters and digits, no spaces.
    final raw = newValue.text.replaceAll(RegExp(r'\s+'), '').toUpperCase();
    final buf = StringBuffer();
    final letters = <String>[];
    final digits = <String>[];

    for (final rune in raw.runes) {
      final ch = String.fromCharCode(rune);
      if (RegExp(r'^[0-9]$').hasMatch(ch)) {
        if (digits.length < 4) digits.add(ch);
        continue;
      }
      // Mongolian Cyrillic uppercase letters (А-Я plus Ө Ү)
      if (RegExp(r'^[А-ЯӨҮ]$').hasMatch(ch)) {
        if (letters.length < 2) letters.add(ch);
      }
    }

    buf.writeAll(letters);
    buf.writeAll(digits);
    final text = buf.toString();

    return TextEditingValue(
      text: text,
      selection: TextSelection.collapsed(offset: text.length),
      composing: TextRange.empty,
    );
  }
}

class CarAvatar extends StatelessWidget {
  final CarImage image;
  final double radius;

  const CarAvatar({super.key, required this.image, this.radius = 28});

  @override
  Widget build(BuildContext context) {
    final provider = image.toImageProvider();

    return CircleAvatar(
      radius: radius,
      backgroundColor: const Color(0xFFE5E7EB),
      backgroundImage: provider,
      child: provider == null
          ? Icon(Icons.directions_car, size: radius, color: Colors.black54)
          : null,
    );
  }
}

class CarDetailsPage extends StatelessWidget {
  final CarModel car;

  const CarDetailsPage({super.key, required this.car});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(car.name),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: AppRadii.r16,
            boxShadow: AppShadows.soft,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: CarAvatar(image: car.image, radius: 70)),
              const SizedBox(height: 16),
              const Text(
                "Машины нэр",
                style: TextStyle(color: AppColors.muted),
              ),
              Text(
                car.name,
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 12),
              const Text("Дугаар", style: TextStyle(color: AppColors.muted)),
              Text(car.plate, style: const TextStyle(fontSize: 20)),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.primary,
                    side: const BorderSide(color: AppColors.primary),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
                  ),
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Буцах"),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class MapScreen extends StatefulWidget {
  const MapScreen({super.key});

  @override
  State<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends State<MapScreen> {
  static const ll.LatLng ub = ll.LatLng(47.918873, 106.917701);

  bool showCard = false;
  String locationName = "";
  String cardSubtitle = "";
  String? _selectedSpotId;

  final TextEditingController searchController = TextEditingController();
  final MapController _mapController = MapController();
  bool _searching = false;
  String? _searchError;
  List<Map<String, dynamic>> _searchResults = [];
  static const String _googlePlacesKey = String.fromEnvironment('GOOGLE_PLACES_KEY');

  List<Marker> _markers = [];
  List<Map<String, dynamic>> _spotRows = [];
  Timer? _poll;
  bool _loadingSpots = true;
  String? _spotsError;

  List<Map<String, dynamic>> _cars = [];
  String? _selectedCarId;

  @override
  void initState() {
    super.initState();
    _refreshSpots();
    _poll = Timer.periodic(const Duration(seconds: 4), (_) => _refreshSpots());
  }

  Future<void> _runSearch(String query) async {
    final q = query.trim();
    if (q.isEmpty) {
      setState(() {
        _searchResults = [];
        _searchError = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _searchError = null;
    });
    try {
      final items = _googlePlacesKey.isNotEmpty
          ? await _googleAutocomplete(q)
          : await _nominatimSearch(q);
      if (!mounted) return;
      setState(() {
        _searchResults = items;
        _searching = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _searching = false;
        _searchError = e.toString();
      });
    }
  }

  Future<List<Map<String, dynamic>>> _nominatimSearch(String q) async {
    final uri = Uri.https('nominatim.openstreetmap.org', '/search', {
      'q': q,
      'format': 'json',
      'addressdetails': '1',
      'limit': '6',
    });
    final r = await http.get(
      uri,
      headers: const {
        'User-Agent': 'parking_sysytem1 (flutter)',
        'Accept': 'application/json',
      },
    );
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('OSM search failed (${r.statusCode})');
    }
    final raw = jsonDecode(r.body);
    if (raw is! List) throw Exception('Bad OSM search response');
    final items = <Map<String, dynamic>>[];
    for (final it in raw) {
      if (it is! Map) continue;
      final lat = double.tryParse(it['lat']?.toString() ?? '');
      final lon = double.tryParse(it['lon']?.toString() ?? '');
      if (lat == null || lon == null) continue;
      items.add({
        'provider': 'osm',
        'display_name': it['display_name']?.toString() ?? '',
        'lat': lat,
        'lon': lon,
      });
    }
    return items;
  }

  Future<List<Map<String, dynamic>>> _googleAutocomplete(String q) async {
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/autocomplete/json', {
      'input': q,
      'key': _googlePlacesKey,
      // bias around Ulaanbaatar
      'location': '47.918873,106.917701',
      'radius': '40000',
      'language': 'mn',
    });
    final r = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Google search failed (${r.statusCode})');
    }
    final m = jsonDecode(r.body);
    if (m is! Map) throw Exception('Bad Google response');
    final status = m['status']?.toString() ?? '';
    if (status != 'OK' && status != 'ZERO_RESULTS') {
      final msg = m['error_message']?.toString();
      throw Exception(msg != null && msg.isNotEmpty ? msg : 'Google status: $status');
    }
    final preds = m['predictions'];
    if (preds is! List) return [];
    final items = <Map<String, dynamic>>[];
    for (final p in preds) {
      if (p is! Map) continue;
      items.add({
        'provider': 'google',
        'display_name': p['description']?.toString() ?? '',
        'place_id': p['place_id']?.toString() ?? '',
      });
    }
    return items;
  }

  Future<ll.LatLng?> _googlePlaceToLatLng(String placeId) async {
    if (placeId.trim().isEmpty) return null;
    final uri = Uri.https('maps.googleapis.com', '/maps/api/place/details/json', {
      'place_id': placeId,
      'fields': 'geometry/location,name,formatted_address',
      'key': _googlePlacesKey,
      'language': 'mn',
    });
    final r = await http.get(uri, headers: const {'Accept': 'application/json'});
    if (r.statusCode < 200 || r.statusCode >= 300) {
      throw Exception('Google details failed (${r.statusCode})');
    }
    final m = jsonDecode(r.body);
    if (m is! Map) return null;
    final status = m['status']?.toString() ?? '';
    if (status != 'OK') return null;
    final result = m['result'];
    if (result is! Map) return null;
    final geom = result['geometry'];
    if (geom is! Map) return null;
    final loc = geom['location'];
    if (loc is! Map) return null;
    final lat = (loc['lat'] is num) ? (loc['lat'] as num).toDouble() : double.tryParse(loc['lat']?.toString() ?? '');
    final lng = (loc['lng'] is num) ? (loc['lng'] as num).toDouble() : double.tryParse(loc['lng']?.toString() ?? '');
    if (lat == null || lng == null) return null;
    return ll.LatLng(lat, lng);
  }

  void _goToSearchResult(Map<String, dynamic> r) {
    final provider = r['provider']?.toString() ?? 'osm';
    if (provider == 'google') {
      final placeId = r['place_id']?.toString() ?? '';
      setState(() => _searching = true);
      _googlePlaceToLatLng(placeId)
          .then((pos) {
            if (!mounted) return;
            if (pos != null) _mapController.move(pos, 15);
            setState(() {
              _searchResults = [];
              _searching = false;
            });
            FocusManager.instance.primaryFocus?.unfocus();
          })
          .catchError((e) {
            if (!mounted) return;
            setState(() {
              _searching = false;
              _searchError = e.toString();
            });
          });
      return;
    }

    final lat = r['lat'];
    final lon = r['lon'];
    if (lat is! double || lon is! double) return;
    _mapController.move(ll.LatLng(lat, lon), 15);
    setState(() => _searchResults = []);
    FocusManager.instance.primaryFocus?.unfocus();
  }

  Future<void> _refreshCars() async {
    try {
      final rows = await BackendApi.fetchCars();
      if (!mounted) return;
      setState(() {
        _cars = rows;
        if (_selectedCarId == null && rows.isNotEmpty) {
          _selectedCarId = rows.first['id']?.toString();
        } else if (_selectedCarId != null) {
          final stillExists = rows.any((e) => e['id']?.toString() == _selectedCarId);
          if (!stillExists && rows.isNotEmpty) {
            _selectedCarId = rows.first['id']?.toString();
          }
        }
      });
    } catch (_) {
      // ignore — we will show error on booking attempt
    }
  }

  /// Docker `mobile_bas2` API — `parking_spots`.
  Future<void> _refreshSpots() async {
    try {
      final rows = await BackendApi.fetchSpots();
      if (!mounted) return;
      final next = <Marker>[];
      for (final data in rows) {
        final id = data['id']?.toString() ?? '';
        if (id.isEmpty) continue;
        final pos = _spotLatLng(data);
        if (pos == null) continue;

        final name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : 'Зогсоол';
        final price = data['price_per_hour'] ?? data['pricePerHour'] ?? data['price'];
        final status = _spotStatus(data);
        final total = data['total'];
        final avail = data['available'] ?? data['avail'] ?? data['free'];
        final cap = (avail is num && total is num)
            ? 'Сул: ${avail.toInt()}/${total.toInt()}'
            : (total is num ? 'Нийт: ${total.toInt()}' : '');
        final snippetBase = price != null ? '₮$price/цаг · $status' : status;
        final snippet = cap.isNotEmpty ? '$snippetBase · $cap' : snippetBase;

        next.add(
          Marker(
            width: 40,
            height: 40,
            point: pos,
            child: GestureDetector(
              onTap: () {
                final addr = (data['address'] as String?)?.trim() ?? '';
                setState(() {
                  showCard = true;
                  _selectedSpotId = id;
                  locationName = name;
                  cardSubtitle =
                      addr.isNotEmpty ? '$addr · $snippet' : snippet.toString();
                });
              },
              child: Icon(
                Icons.location_pin,
                size: 40,
                color: status == 'free' ? Colors.green : Colors.red,
              ),
            ),
          ),
        );
      }
      setState(() {
        _spotRows = rows;
        _markers = next;
        _loadingSpots = false;
        _spotsError = null;
      });
    } catch (e) {
      debugPrint('fetch spots: $e');
      if (!mounted) return;
      setState(() {
        _loadingSpots = false;
        _spotsError = e.toString();
      });
    }
  }

  ll.LatLng? _spotLatLng(Map<String, dynamic> data) {
    final lat = data['lat'];
    final lng = data['lng'];
    if (lat is num && lng is num) {
      return ll.LatLng(lat.toDouble(), lng.toDouble());
    }
    final loc = data['location'];
    if (loc is Map) {
      final la = loc['lat'];
      final ln = loc['lng'];
      if (la is num && ln is num) {
        return ll.LatLng(la.toDouble(), ln.toDouble());
      }
    }
    return null;
  }

  String _spotStatus(Map<String, dynamic> data) {
    final s = data['status'];
    if (s is String) return s;
    if (data['is_available'] == true || data['isAvailable'] == true) {
      return 'free';
    }
    if (data['is_available'] == false || data['isAvailable'] == false) {
      return 'occupied';
    }
    return 'free';
  }

  @override
  void dispose() {
    _poll?.cancel();
    searchController.dispose();
    super.dispose();
  }

  Widget _windowsSpotList() {
    if (_spotRows.isEmpty) {
      return const Center(
        child: Text(
          'Зогсоол алга эсвэл API холбогдохгүй байна.\n'
          'Docker: mobile_bas2 хавтас дээр `docker compose up`',
          textAlign: TextAlign.center,
        ),
      );
    }
    return ListView.builder(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      itemCount: _spotRows.length,
      itemBuilder: (context, i) {
        final data = _spotRows[i];
        final pos = _spotLatLng(data);
        final name = (data['name'] as String?)?.trim().isNotEmpty == true
            ? data['name'] as String
            : 'Зогсоол';
        final price =
            data['price_per_hour'] ?? data['pricePerHour'] ?? data['price'];
        final sub = pos != null
            ? '${pos.latitude.toStringAsFixed(5)}, ${pos.longitude.toStringAsFixed(5)}'
            : '—';
        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            title: Text(name),
            subtitle: Text(
              '${price != null ? '₮$price/цаг · ' : ''}$sub',
            ),
            isThreeLine: true,
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    if (!kIsWeb && Platform.isWindows) {
      return Scaffold(
        appBar: AppBar(title: const Text('Parking Map')),
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Material(
              color: const Color(0xFFFFF8E1),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Text(
                  'Windows дээр Google Map дэмжигдэхгүй. Зогсоолын жагсаалт Docker API-аас. '
                  'Газрын зураг: Android эсвэл `flutter run -d chrome`.',
                  style: TextStyle(fontSize: 13, color: Colors.grey.shade900),
                ),
              ),
            ),
            Expanded(child: _windowsSpotList()),
          ],
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text("Parking Map")),

      body: Stack(
        children: [
          /// OpenStreetMap (Google API шаардлагагүй) — Docker `mobile_bas2` /parking_spots
          FlutterMap(
            mapController: _mapController,
            options: const MapOptions(
              initialCenter: ub,
              initialZoom: 14,
            ),
            children: [
              TileLayer(
                urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.parking_managment_system',
              ),
              MarkerLayer(markers: _markers),
            ],
          ),

          // Search (Google map шиг) — OpenStreetMap Nominatim
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Material(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                  elevation: 4,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    child: Row(
                      children: [
                        const Icon(Icons.search, size: 20),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            controller: searchController,
                            textInputAction: TextInputAction.search,
                            decoration: const InputDecoration(
                              hintText: 'Хаяг/газрын нэр хайх… (Google key байвал Google, байхгүй бол OSM)',
                              border: InputBorder.none,
                              isDense: true,
                            ),
                            onSubmitted: _runSearch,
                          ),
                        ),
                        if (_searching)
                          const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        else
                          IconButton(
                            tooltip: 'Хайх',
                            onPressed: () => _runSearch(searchController.text),
                            icon: const Icon(Icons.arrow_forward, size: 20),
                          ),
                      ],
                    ),
                  ),
                ),
                if (_searchError != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      color: const Color(0xFFFFF8E1),
                      borderRadius: BorderRadius.circular(10),
                      elevation: 2,
                      child: Padding(
                        padding: const EdgeInsets.all(10),
                        child: Text(
                          'Search алдаа: ${_searchError!}',
                          style: const TextStyle(fontSize: 12),
                        ),
                      ),
                    ),
                  ),
                if (_searchResults.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Material(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(10),
                      elevation: 4,
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxHeight: 220),
                        child: ListView.separated(
                          shrinkWrap: true,
                          padding: EdgeInsets.zero,
                          itemCount: _searchResults.length,
                          separatorBuilder: (_, __) => const Divider(height: 1),
                          itemBuilder: (_, i) {
                            final r = _searchResults[i];
                            final name = (r['display_name']?.toString() ?? '').trim();
                            return ListTile(
                              dense: true,
                              title: Text(
                                name.isEmpty ? '—' : name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              onTap: () => _goToSearchResult(r),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),

          if (_loadingSpots)
            Positioned(
              top: _searchResults.isNotEmpty || _searchError != null ? 280 : 60,
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
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    SizedBox(width: 10),
                    Expanded(child: Text('Зогсоолууд ачаалж байна…')),
                  ],
                ),
              ),
            ),

          if (!_loadingSpots && (_spotsError != null || _markers.isEmpty))
            Positioned(
              top: _searchResults.isNotEmpty || _searchError != null ? 280 : 60,
              left: 15,
              right: 15,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF8E1),
                  borderRadius: BorderRadius.circular(10),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 5),
                  ],
                ),
                child: Text(
                  _spotsError != null
                      ? 'Зогсоол татахад алдаа: $_spotsError\nAPI: ${apiBaseUrl()}'
                      : 'Одоогоор зогсоол алга (эсвэл API асаагүй байна).',
                  style: const TextStyle(fontSize: 13),
                ),
              ),
            ),

          /// 🔎 SEARCH BAR
          Positioned(
            top: 10,
            left: 15,
            right: 15,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                boxShadow: const [
                  BoxShadow(color: Colors.black26, blurRadius: 5),
                ],
              ),
              child: TextField(
                controller: searchController,
                decoration: const InputDecoration(
                  hintText: "Search location",
                  border: InputBorder.none,
                  icon: Icon(Icons.search),
                ),
              ),
            ),
          ),

          /// 📍 GOOGLE MAPS шиг доороос гардаг CARD
          if (showCard)
            Positioned(
              bottom: 20,
              left: 20,
              right: 20,
              child: Container(
                padding: const EdgeInsets.all(15),
                decoration: BoxDecoration(
                  color: const Color.fromARGB(255, 22, 31, 154),
                  borderRadius: BorderRadius.circular(15),
                  boxShadow: const [
                    BoxShadow(color: Colors.black26, blurRadius: 10),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.location_pin,
                          color: Color.fromARGB(255, 167, 154, 153),
                          size: 35,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                locationName,
                                style: const TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.white,
                                ),
                              ),
                              Text(
                                cardSubtitle.isNotEmpty
                                    ? cardSubtitle
                                    : "Ulaanbaatar - Mongolia",
                                style: const TextStyle(color: Colors.white70),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close, color: Colors.white),
                          onPressed: () => setState(() => showCard = false),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _selectedSpotId == null
                            ? null
                            : () => _bookSelectedSpot(),
                        child: const Text('ЗАХИАЛАХ'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _bookSelectedSpot() async {
    final spotId = _selectedSpotId;
    if (spotId == null) return;
    try {
      await _refreshCars();
      if (_cars.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Эхлээд Car хэсгээс машин нэмнэ үү.')),
        );
        return;
      }

      String selectedCarId = _selectedCarId ?? _cars.first['id']?.toString() ?? '';
      if (!_cars.any((e) => e['id']?.toString() == selectedCarId)) {
        selectedCarId = _cars.first['id']?.toString() ?? '';
      }

      final ok = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Захиалга эхлүүлэх'),
          content: StatefulBuilder(
            builder: (dctx, setInner) {
              final items = _cars
                  .map((e) => Map<String, dynamic>.from(e))
                  .where((e) => (e['id']?.toString() ?? '').isNotEmpty)
                  .toList();
              final current = items.firstWhere(
                (e) => e['id']?.toString() == selectedCarId,
                orElse: () => items.first,
              );
              final plate = current['plate']?.toString() ?? '—';
              return Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Та энэ зогсоолд зогсохыг эхлүүлэх үү?\n\nЗогсоол: $locationName'),
                  const SizedBox(height: 12),
                  const Text('Машин сонгох'),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<String>(
                    value: selectedCarId,
                    items: items
                        .map(
                          (e) => DropdownMenuItem<String>(
                            value: e['id']?.toString() ?? '',
                            child: Text(
                              '${(e['name']?.toString() ?? 'Машин').trim().isEmpty ? 'Машин' : e['name']} • ${e['plate'] ?? ''}',
                            ),
                          ),
                        )
                        .toList(),
                    onChanged: (v) {
                      if (v == null || v.isEmpty) return;
                      setInner(() => selectedCarId = v);
                      setState(() => _selectedCarId = v);
                    },
                  ),
                  const SizedBox(height: 8),
                  Text('Сонгосон: $plate'),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Цуцлах'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Эхлүүлэх'),
            ),
          ],
        ),
      );
      if (ok != true) return;

      await BackendApi.startBooking(spotId: spotId, carId: selectedCarId);

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Захиалга эхэллээ. Төлөх үед хугацаагаар бодож wallet-ээс хасна.')),
      );
      setState(() => showCard = false);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа: $e')),
      );
    }
  }
}

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'qpay';
  final TextEditingController _topupAmountController =
      TextEditingController(text: '5000');
  int? _walletBalance;
  bool _walletLoading = false;
  bool _submitting = false;
  Map<String, dynamic>? _activeBooking;

  int get _topupAmountTugrik {
    final v = int.tryParse(
      _topupAmountController.text.trim().replaceAll(RegExp(r'\s'), ''),
    );
    return v ?? 0;
  }

  @override
  void initState() {
    super.initState();
    _loadWallet();
    _loadActiveBooking();
  }

  Future<void> _loadWallet() async {
    setState(() => _walletLoading = true);
    try {
      final r = await BackendApi.walletMe();
      if (!mounted) return;
      setState(() => _walletBalance = (r['balance'] as int?) ?? 0);
    } catch (_) {
      if (!mounted) return;
      setState(() => _walletBalance = null);
    } finally {
      if (mounted) setState(() => _walletLoading = false);
    }
  }

  Future<void> _loadActiveBooking() async {
    try {
      final b = await BackendApi.activeBooking();
      if (!mounted) return;
      setState(() => _activeBooking = b);
    } catch (_) {
      if (!mounted) return;
      setState(() => _activeBooking = null);
    }
  }

  Future<void> _payActiveBooking() async {
    final b = _activeBooking;
    if (b == null) return;
    final id = b['id']?.toString() ?? '';
    if (id.isEmpty) return;
    setState(() => _submitting = true);
    try {
      final r = await BackendApi.payBooking(
        bookingId: id,
        method: selectedMethod,
      );
      if (!mounted) return;
      setState(() {
        _walletBalance = (r['balance'] as int?) ?? _walletBalance;
        _activeBooking = null;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Төлбөр амжилттай. ₮${r['amount']} · ${r['hours']} цаг\nҮлдэгдэл: ₮${r['balance']}',
          ),
        ),
      );
    } catch (e) {
      if (!mounted) return;
      final msg = e.toString().contains('insufficient_balance')
          ? 'Үлдэгдэл хүрэхгүй байна.'
          : 'Алдаа: $e';
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    } finally {
      if (mounted) setState(() => _submitting = false);
      await _loadWallet();
      await _loadActiveBooking();
    }
  }

  Future<void> _topupWallet() async {
    final amount = _topupAmountTugrik;
    if (amount < 1) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цэнэглэх дүн (₮) оруулна уу.')),
      );
      return;
    }
    setState(() => _submitting = true);
    try {
      final newBalance = await BackendApi.walletTopup(
        amount: amount,
        method: selectedMethod,
        note: 'mobile topup',
      );
      if (!mounted) return;
      setState(() => _walletBalance = newBalance);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Хэтэвч цэнэглэгдлээ. Үлдэгдэл: ₮$newBalance')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Алдаа: $e')),
      );
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  @override
  void dispose() {
    _topupAmountController.dispose();
    super.dispose();
  }

  Future<void> _showTopupDialog() async {
    String method = selectedMethod;
    String bank = 'khaan';
    _topupAmountController.text =
        (_topupAmountTugrik > 0 ? _topupAmountTugrik : 5000).toString();

    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          title: const Text('Хэтэвч цэнэглэх'),
          content: StatefulBuilder(
            builder: (ctx, setLocal) {
              return Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: _topupAmountController,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    decoration: const InputDecoration(
                      labelText: 'Цэнэглэх дүн (₮)',
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 14),
                  RadioListTile<String>(
                    value: 'qpay',
                    groupValue: method,
                    onChanged: (v) => setLocal(() => method = v ?? 'qpay'),
                    title: const Text('QPay (QR төлбөр)'),
                    subtitle: const Text('Банкны апп-аар QR уншуулж төлнө'),
                  ),
                  RadioListTile<String>(
                    value: 'bank',
                    groupValue: method,
                    onChanged: (v) => setLocal(() => method = v ?? 'bank'),
                    title: const Text('Дансанд шилжүүлэх'),
                    subtitle: const Text('Хаан, Голомт, Хас гэх мэт'),
                  ),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: bank,
                    decoration: const InputDecoration(
                      labelText: 'Банк сонгох',
                      border: OutlineInputBorder(),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'khaan', child: Text('Хаан банк')),
                      DropdownMenuItem(value: 'xac', child: Text('Хас банк')),
                      DropdownMenuItem(value: 'golomt', child: Text('Голомт банк')),
                      DropdownMenuItem(value: 'tdb', child: Text('Худалдаа хөгжлийн банк')),
                      DropdownMenuItem(value: 'state', child: Text('Төрийн банк')),
                    ],
                    onChanged: (v) => setLocal(() => bank = v ?? 'khaan'),
                  ),
                ],
              );
            },
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Цуцлах'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Цэнэглэх'),
            ),
          ],
        );
      },
    );

    if (ok != true) return;

    final amount = int.tryParse(
          _topupAmountController.text.trim().replaceAll(RegExp(r'\s'), ''),
        ) ??
        0;
    if (amount < 1) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Цэнэглэх дүн (₮) оруулна уу.')),
      );
      return;
    }

    setState(() {
      selectedMethod = '$method:$bank';
      _topupAmountController.text = amount.toString();
    });

    await _openBankForTopup(bank: bank, channel: method);
    if (!mounted) return;
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Төлбөр баталгаажуулах'),
        content: const Text(
          'Сонгосон банкны апп дээр төлбөрөө хийсэн бол “Баталгаажуулах”-ыг дарна уу.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Цуцлах'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Баталгаажуулах'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _topupWallet();
    }
  }

  Future<void> _openBankForTopup({
    required String bank,
    required String channel, // 'qpay' | 'bank'
  }) async {
    // Dev/demo: жинхэнэ QPay invoice/deeplink үүсгэхгүй.
    // Тиймээс банкны апп/сайт руу нээгээд, хэрэглэгч төлснөө баталгаажуулж цэнэглэнэ.
    Uri url;
    switch (bank) {
      case 'khaan':
        url = Uri.parse('https://khanbank.com/');
        break;
      case 'xac':
        url = Uri.parse('https://www.xacbank.mn/');
        break;
      case 'golomt':
        url = Uri.parse('https://golomtbank.com/');
        break;
      case 'tdb':
        url = Uri.parse('https://www.tdbm.mn/');
        break;
      case 'state':
        url = Uri.parse('https://www.statebank.mn/');
        break;
      default:
        url = Uri.parse('https://www.qpay.mn/');
        break;
    }

    final ok = await launchUrl(url, mode: LaunchMode.externalApplication);
    if (!ok && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Банкны апп нээгдсэнгүй. $channel:$bank')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("Төлбөрийн дэлгэц"),
        centerTitle: true,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _Card(
            child: Row(
              children: [
                const Icon(Icons.account_balance_wallet, color: Colors.white),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    _walletLoading
                        ? 'Хэтэвч ачаалж байна…'
                        : (_walletBalance == null
                            ? 'Хэтэвч: нэвтэрсний дараа харагдана'
                            : 'Хэтэвчний үлдэгдэл: ₮$_walletBalance'),
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed:
                      (_walletLoading || _submitting) ? null : _showTopupDialog,
                  child: const Text(
                    'Цэнэглэх',
                    style: TextStyle(color: Colors.white),
                  ),
                ),
                const SizedBox(width: 6),
                IconButton(
                  onPressed: _walletLoading ? null : _loadWallet,
                  icon: const Icon(Icons.refresh, color: Colors.white),
                  tooltip: 'Refresh',
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          if (_activeBooking != null) ...[
            _Card(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Идэвхтэй захиалга',
                    style: TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    _activeBooking!['spot_name']?.toString() ?? '—',
                    style: const TextStyle(color: Colors.white),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Эхэлсэн: ${_activeBooking!['started_at']?.toString() ?? '—'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Машин: ${_activeBooking!['car_plate']?.toString() ?? '—'}',
                    style: const TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _submitting ? null : _payActiveBooking,
                      child: const Text('ОДОО ТӨЛӨХ (WALLET)'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
          ],
          // Topup is available from the header "Цэнэглэх" button.
        ],
      ),
    );
  }
}

class NotificationScreen extends StatelessWidget {
  const NotificationScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text("Мэдэгдэл"),
        centerTitle: true,
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: _Card(
          child: const Text(
            "Таны зогсоолын захиалсан хугацаа дуусахад 10 минут үлдсэн тул та сунгалтаа хийнэ үү!",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: AppColors.primary,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final Widget child;

  const _Card({required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.r16,
        boxShadow: AppShadows.soft,
      ),
      child: child,
    );
  }
}
