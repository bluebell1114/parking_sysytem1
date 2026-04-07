import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';

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
  final String name;
  final String plate;
  final CarImage image;

  const CarModel({
    required this.name,
    required this.plate,
    required this.image,
  });

  CarModel copyWith({String? name, String? plate, CarImage? image}) => CarModel(
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
  int _index = 0;

  late final List<Widget> _pages = const [
    CarListPage(),
    MapScreen(),
    PaymentScreen(),
    NotificationScreen(),
  ];

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

  Future<void> _addCar() async {
    final CarFormResult? res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => const CarFormPage(title: "Add New Car"),
      ),
    );
    if (res == null) return;

    setState(() => _cars.add(res.toModel()));
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

    setState(() => _cars[index] = res.toModel());
    if (!mounted) return;

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text("Editing Completed!")));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: const Text('Таны машин', style: TextStyle(color: Color.fromARGB(255, 17, 16, 16))),
        centerTitle: true,
      ),
      body: _cars.isEmpty
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

  const _CarCard({
    required this.car,
    required this.onTap,
    required this.onEdit,
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
                _Input(
                  controller: _plate,
                  label: "Улсын дугаар",
                  icon: Icons.confirmation_number_outlined,
                  validator: (v) => (v == null || v.trim().isEmpty)
                      ? "Enter plate number"
                      : null,
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
                    onPressed: _submit,
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
  static const LatLng ub = LatLng(47.918873, 106.917701);

  GoogleMapController? mapController;

  bool showCard = false;
  String locationName = "";

  final TextEditingController searchController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Parking Map")),

      body: Stack(
        children: [
          /// GOOGLE MAP
          GoogleMap(
            initialCameraPosition: const CameraPosition(target: ub, zoom: 14),

            mapType: MapType.normal,

            /// 🚗 Замын түгжрэл
            trafficEnabled: true,

            /// 🏢 3D барилга
            buildingsEnabled: true,

            /// 📍 Миний байршил
            myLocationEnabled: true,
            myLocationButtonEnabled: true,

            markers: {
              Marker(
                markerId: const MarkerId("parking1"),
                position: const LatLng(47.918873, 106.917701),
                infoWindow: const InfoWindow(title: "Car parking"),

                onTap: () {
                  setState(() {
                    showCard = true;
                    locationName = "HUD - 15 khoroo";
                  });
                },
              ),
            },

            onMapCreated: (controller) {
              mapController = controller;
            },
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
                child: Row(
                  children: [
                    const Icon(Icons.location_pin, color: Color.fromARGB(255, 167, 154, 153), size: 35),

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
                            ),
                          ),
                          const Text(
                            "Ulaanbaatar - Mongolia",
                            style: TextStyle(color: Colors.grey),
                          ),
                        ],
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

class PaymentScreen extends StatefulWidget {
  const PaymentScreen({super.key});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  String selectedMethod = 'qpay';
  final double totalAmount = 5000;

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
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  "Төлөх дүн",
                  style: TextStyle(color: AppColors.muted),
                ),
                const SizedBox(height: 6),
                Text(
                  "₮ ${totalAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w900,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          const Text(
            "Төлбөрийн арга сонгох",
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800), 
          ),
          const SizedBox(height: 10),

          _MethodCard(
            
            selected: selectedMethod == 'qpay',
            title: "QPay (QR төлбөр)", 
            subtitle: "Банкны апп ашиглан QR уншуулна уу",
            icon: Icons.qr_code_2,
            onTap: () => setState(() => selectedMethod = 'qpay'),
            
          ),

          const SizedBox(height: 10),
          _MethodCard(
            selected: selectedMethod == 'bank',
            title: "Дансанд шилжүүлэх",
            subtitle: "Хаан, Голомт, Хас гэх мэт",
            icon: Icons.account_balance,
            onTap: () => setState(() => selectedMethod = 'bank'),
          ),

          const SizedBox(height: 20),
          if (selectedMethod == 'qpay') _qpayWidget(),
          if (selectedMethod == 'bank') _bankInfo(),

          const SizedBox(height: 16),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(vertical: 14),
              shape: RoundedRectangleBorder(borderRadius: AppRadii.r12),
            ),
            onPressed: () {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(content: Text("Төлбөр амжилттай хийгдлээ!")),
              );
            },
            icon: const Icon(Icons.check_circle_outline, color: Colors.white),
            label: const Text(
              "ТӨЛӨХ",
              style: TextStyle(color: Colors.white, fontSize: 16),
            ),
          ),
        ],
      ),
    );
  }

  Widget _qpayWidget() {
    return _Card(
      child: Column(
        children: [
          const Text(
            "QPay QR код уншуулна уу",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Container(
            height: 200,
            width: 200,
            decoration: BoxDecoration(
              color: const Color(0xFFF3F4F6),
              borderRadius: AppRadii.r16,
            ),
            child: const Icon(
              Icons.qr_code_2,
              size: 160,
              color: Colors.black54,
            ),
          ),
          const SizedBox(height: 10),
          const Text(
            "QR кодыг банкны апп-аар уншуулж төлнө үү.",
            textAlign: TextAlign.center,
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }

  Widget _bankInfo() {
    return const _Card(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            "Дансны мэдээлэл",
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
          ),
          SizedBox(height: 10),
          _InfoRow(label: "Банк", value: "Хаан банк"),
          _InfoRow(label: "Дансны дугаар", value: "5012345678"),
          _InfoRow(label: "Дансны нэр", value: "MyParking LLC"),
          SizedBox(height: 10),
          Text(
            "Гүйлгээний утга: Машины дугаар эсвэл нэрээ бичнэ үү.",
            style: TextStyle(color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}

class _MethodCard extends StatelessWidget {
  final bool selected;
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;

  const _MethodCard({
    required this.selected,
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: _Card(
        border: Border.all(
          color: selected ? AppColors.primary : Colors.transparent,
          width: 2,
        ),
        child: Row(
          children: [
            Icon(
              icon,
              color: selected ? AppColors.primary : Colors.grey,
              size: 30,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: const TextStyle(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            Icon(
              selected ? Icons.check_circle : Icons.circle_outlined,
              color: selected ? AppColors.primary : Colors.grey,
            ),
          ],
        ),
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
  final Border? border;

  const _Card({required this.child, this.border});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.card,
        borderRadius: AppRadii.r16,
        boxShadow: AppShadows.soft,
        border: border,
      ),
      child: child,
    );
  }
}

class _InfoRow extends StatelessWidget {
  final String label;
  final String value;

  const _InfoRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.muted)),
          Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }
}
