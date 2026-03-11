import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:google_place/google_place.dart' as gp;
import 'package:newfypken/notification_service.dart';

final supabase = Supabase.instance.client;

class CreateSchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final List<String> petIds;
  const CreateSchedulePage({super.key, required this.pets, required this.petIds});

  @override
  State<CreateSchedulePage> createState() => _CreateSchedulePageState();
}

class _CreateSchedulePageState extends State<CreateSchedulePage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedPetId;
  String? _selectedType;
  String? _selectedTitle;
  final _descriptionController = TextEditingController();
  String _repeatType = 'None';

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;
  bool _isLocating = false;
  LatLng? _pickedLocation;
  Set<Marker> _markers = {};

  // Google Place API Key
  final String googleApiKey = "AIzaSyCl8hgw0K7-gpdCFdEJQfBKR22CfDverA0"; // <-- 记得放回你的 Key
  late gp.GooglePlace googlePlace; // 💡 使用别名 gp

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    googlePlace = gp.GooglePlace(googleApiKey); // 💡 使用别名 gp
  }

  Future<void> _showHospitalPicker() async {
    setState(() => _isLocating = true);
    try {
      loc.Location location = loc.Location();

      // 1. 检查服务
      bool serviceEnabled = await location.serviceEnabled();
      if (!serviceEnabled) {
        serviceEnabled = await location.requestService();
        if (!serviceEnabled) {
          setState(() => _isLocating = false);
          return;
        }
      }

      // 2. 检查权限
      loc.PermissionStatus permissionGranted = await location.hasPermission();
      if (permissionGranted == loc.PermissionStatus.denied) {
        permissionGranted = await location.requestPermission();
        if (permissionGranted != loc.PermissionStatus.granted) {
          setState(() => _isLocating = false);
          return;
        }
      }

      // 3. 关键：加一个超时的获取位置，防止无限等待
      print("正在获取位置...");
      loc.LocationData? locData;
      try {
        locData = await location.getLocation().timeout(const Duration(seconds: 8));
      } catch (e) {
        print("获取位置超时，使用默认坐标");
      }

      // 4. 如果拿不到位置，给一个默认坐标（比如 KL），防止地图因为 target 为 null 闪退
      LatLng initialPos = (locData != null && locData.latitude != null)
          ? LatLng(locData.latitude!, locData.longitude!)
          : const LatLng(3.1412, 101.6865); // 默认吉隆坡坐标

      print("准备弹出地图，坐标: $initialPos");

      // 5. 确保 context 还在才弹出 Dialog
      if (!mounted) return;
      await _showMapPicker(initialPos);

    } catch (e) {
      debugPrint("闪退防护报错: $e");
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

// 在 _showMapPicker 内加反向编码
  String? _pickedLocationName;

  Future<void> _showMapPicker(LatLng initialLocation) async {
    LatLng? picked = initialLocation;
    GoogleMapController? mapController;
    List<gp.AutocompletePrediction> predictions = [];

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text("Search & Pick Location"),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // 🔍 搜索框
                TextField(
                  decoration: InputDecoration(
                    hintText: "Search place (e.g. PV16)",
                    prefixIcon: const Icon(Icons.search),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  onChanged: (value) async {
                    if (value.isNotEmpty) {
                      // 调用 Google Autocomplete API
                      var result = await googlePlace.autocomplete.get(value);
                      if (result != null && result.predictions != null) {
                        setStateDialog(() => predictions = result.predictions!);
                      }
                    } else {
                      setStateDialog(() => predictions = []);
                    }
                  },
                ),

                // 📍 搜索建议列表 (如果有结果就显示)
                if (predictions.isNotEmpty)
                  SizedBox(
                    height: 200,
                    child: ListView.builder(
                      itemCount: predictions.length,
                      itemBuilder: (context, index) => ListTile(
                        title: Text(predictions[index].description ?? ""),
                        onTap: () async {
                          // 获取选中地点的详情（经纬度）
                          final details = await googlePlace.details.get(predictions[index].placeId!);
                          if (details != null && details.result != null) {
                            double lat = details.result!.geometry!.location!.lat!;
                            double lng = details.result!.geometry!.location!.lng!;
                            LatLng newPos = LatLng(lat, lng);

                            // 移动地图相机
                            mapController?.animateCamera(CameraUpdate.newLatLngZoom(newPos, 16));

                            setStateDialog(() {
                              picked = newPos;
                              _markers = {Marker(markerId: const MarkerId("picked"), position: newPos)};
                              predictions = []; // 选完后关掉列表
                            });
                          }
                        },
                      ),
                    ),
                  ),

                const SizedBox(height: 10),

                // 🗺️ 地图显示
                SizedBox(
                  width: double.maxFinite,
                  height: 300,
                  child: GoogleMap(
                    initialCameraPosition: CameraPosition(target: initialLocation, zoom: 15),
                    onMapCreated: (ctrl) => mapController = ctrl,
                    markers: _markers,
                    onTap: (LatLng pos) {
                      setStateDialog(() {
                        picked = pos;
                        _markers = {Marker(markerId: const MarkerId("picked"), position: pos)};
                      });
                    },
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
              ElevatedButton(
                onPressed: () async {
                  if (picked != null) {
                    _pickedLocation = picked;
                    // 反向编码获取地址名字
                    List<Placemark> p = await placemarkFromCoordinates(picked!.latitude, picked!.longitude);
                    if (p.isNotEmpty) {
                      _descriptionController.text = "${p.first.name}, ${p.first.street}";
                    }
                  }
                  Navigator.pop(ctx);
                },
                child: const Text("Select"),
              )
            ],
          );
        },
      ),
    );
  }
  // ... 保持你之前的 _pickDate, _pickTime 和 _createSchedule 不变 ...
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  Future<void> _createSchedule() async {
    if (_selectedPetId == null || _selectedType == null || _selectedTitle == null || _selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";
      final endTimeString = "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00";

      final insertResponse = await supabase.from('schedule').insert({
        'petID': _selectedPetId,
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'date': dateString,
        'startTime': startTimeString,
        'endTime': endTimeString,
        'repeatType': _repeatType,
      }).select('scheduleID');

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule created!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("❌ Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon, color: themeColor),
    filled: true,
    fillColor: Colors.grey[100],
    border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('New Schedule'), backgroundColor: themeColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: _inputDecoration('Select Pet', Icons.pets),
              items: widget.pets.map((pet) => DropdownMenuItem(value: pet['petID'].toString(), child: Text(pet['petName'] ?? 'No Name'))).toList(),
              onChanged: (val) => setState(() => _selectedPetId = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() { _selectedType = val; _selectedTitle = null; }),
            ),
            const SizedBox(height: 16),
            if (_selectedType != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: _inputDecoration('Activity Title', Icons.title),
                items: scheduleTypeToTitle[_selectedType]!.map((title) => DropdownMenuItem(value: title, child: Text(title))).toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'Medical') ...[
                ElevatedButton.icon(
                  onPressed: _isLocating ? null : _showHospitalPicker,
                  icon: const Icon(Icons.map),
                  label: Text(_isLocating ? "Locating..." : "Pick Hospital Location"),
                  style: ElevatedButton.styleFrom(
                    minimumSize: const Size(double.infinity, 50),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ],
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.calendar_today),
              title: Text(_selectedDate == null ? "Pick Date" : _selectedDate.toString().split(' ')[0]),
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time),
              title: Text(_startTime == null ? "Pick Start Time" : _startTime!.format(context)),
              onTap: () => _pickTime(true),
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time_filled),
              title: Text(_endTime == null ? "Pick End Time" : _endTime!.format(context)),
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _createSchedule,
              style: ElevatedButton.styleFrom(backgroundColor: themeColor, minimumSize: const Size(double.infinity, 55)),
              child: const Text("Create Schedule", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}