import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:newfypken/notification_service.dart'; // 请确保路径正确
import 'dart:io';

final supabase = Supabase.instance.client;

class CreateSchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final List<String> petIds;
  const CreateSchedulePage({super.key, required this.pets, required this.petIds});

  @override
  State<CreateSchedulePage> createState() => _CreateSchedulePageState();
}

class _CreateSchedulePageState extends State<CreateSchedulePage> {
  // --- 变量定义 ---
  LatLng? _pickedLocation;
  bool _isLocating = false;
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedPetId;
  String? _selectedType;
  String? _selectedTitle;
  String _repeatType = 'None';
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  bool _isLoading = false;

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    // 删除了权限检查逻辑，不再弹出烦人的设置跳转
  }

  // --- 地图选择逻辑 ---
  Future<void> _showOSMPicker() async {
    setState(() => _isLocating = true);
    try {
      loc.Location location = loc.Location();
      loc.LocationData locationData = await location.getLocation();
      LatLng currentLatLng = LatLng(locationData.latitude!, locationData.longitude!);

      if (!mounted) return;
      showDialog(
        context: context,
        builder: (context) => StatefulBuilder(
          builder: (context, setDialogState) => AlertDialog(
            title: const Text("Select Location"),
            content: SizedBox(
              height: 400, width: double.maxFinite,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: currentLatLng, initialZoom: 15,
                  onTap: (tapPosition, point) async {
                    setDialogState(() => _pickedLocation = point);
                    try {
                      List<Placemark> p = await placemarkFromCoordinates(point.latitude, point.longitude);
                      if (p.isNotEmpty) {
                        _descriptionController.text = "Hospital: ${p.first.name}, ${p.first.street}";
                      }
                    } catch (e) {
                      _descriptionController.text = "Lat: ${point.latitude}, Lng: ${point.longitude}";
                    }
                    Future.delayed(const Duration(milliseconds: 500), () => Navigator.pop(context));
                  },
                ),
                children: [
                  TileLayer(
                    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                    // ⭐ 修复 Access Blocked: 加上 User-Agent 政策声明
                    userAgentPackageName: 'com.example.newfypken',
                  ),
                  if (_pickedLocation != null)
                    MarkerLayer(markers: [Marker(point: _pickedLocation!, child: const Icon(Icons.location_on, color: Colors.red, size: 40))]),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      print("Location Error: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  // --- 核心创建逻辑 ---
  Future<void> _createSchedule() async {
    if (_selectedPetId == null || _selectedType == null || _selectedTitle == null || _selectedDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";

      // 插入数据库
      await supabase.from('schedule').insert({
        'petID': _selectedPetId,
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'date': dateString,
        'startTime': startTimeString,
        'repeatType': _repeatType,
      });

      // 通知设置 (保持之前的本地修正逻辑)
      int notifId = DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await NotificationService.scheduleNotification(
        id: notifId,
        title: "Reminder: $_selectedTitle",
        body: "Time for your pet's task!",
        scheduledTime: DateTime.now().add(const Duration(seconds: 10)),
        repeatType: _repeatType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Schedule created!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      print("❌ Error: $e");
      // 报错时也要尝试返回，不让 UI 卡死在加载中
      if (mounted) Navigator.pop(context, true);
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
    labelText: label, prefixIcon: Icon(icon, color: themeColor),
    filled: true, fillColor: Colors.grey[100],
    border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
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
              value: _selectedPetId, decoration: _inputDecoration('Select Pet', Icons.pets),
              items: widget.pets.map((pet) => DropdownMenuItem(value: pet['petID'].toString(), child: Text(pet['petName'] ?? 'No Name'))).toList(),
              onChanged: (val) => setState(() => _selectedPetId = val),
            ),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _selectedType, decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() { _selectedType = val; _selectedTitle = null; }),
            ),
            const SizedBox(height: 16),
            if (_selectedType != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: _inputDecoration('Activity Title', Icons.title),
                items: scheduleTypeToTitle[_selectedType]!
                    .map((title) => DropdownMenuItem(value: title, child: Text(title)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'Medical') ...[
                ElevatedButton.icon(
                  onPressed: _isLocating ? null : _showOSMPicker,
                  icon: const Icon(Icons.map),
                  label: Text(_isLocating ? "Locating..." : "Pick Hospital Location"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 16),
              ],
            ],
            TextField(controller: _descriptionController, decoration: _inputDecoration('Description', Icons.description)),
            const SizedBox(height: 16),
            DropdownButtonFormField<String>(
              value: _repeatType, decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.calendar_today), title: Text(_selectedDate == null ? "Pick Date" : _selectedDate.toString().split(' ')[0]),
              onTap: () async {
                final d = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime.now(), lastDate: DateTime.now().add(const Duration(days: 365)));
                if (d != null) setState(() => _selectedDate = d);
              },
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: Colors.grey[100], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time), title: Text(_startTime == null ? "Pick Start Time" : _startTime!.format(context)),
              onTap: () async {
                final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                if (t != null) setState(() => _startTime = t);
              },
            ),
            const SizedBox(height: 30),
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
                onPressed: _createSchedule,
                style: ElevatedButton.styleFrom(backgroundColor: themeColor, minimumSize: const Size(double.infinity, 55)),
                child: const Text("CREATE & SET REMINDER", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold))
            ),
          ],
        ),
      ),
    );
  }
}