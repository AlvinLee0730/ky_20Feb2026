import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
// 💡 保持和 Create 页面一致的别名
import 'package:google_place/google_place.dart' as gp;
import 'package:newfypken/notification_service.dart';

final supabase = Supabase.instance.client;

class EditSchedulePage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  const EditSchedulePage({super.key, required this.schedule});

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedType;
  String? _selectedTitle;
  String _repeatType = 'None';
  final _descController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;
  bool _isLocating = false;
  LatLng? _pickedLocation;

  // 💡 引入 Google Place
  final String googleApiKey = "AIzaSyCl8hgw0K7-gpdCFdEJQfBKR22CfDverA0"; // <-- 记得放你的 Key
  late gp.GooglePlace googlePlace;

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    // 初始化 Google Place
    googlePlace = gp.GooglePlace(googleApiKey);

    // 填充旧数据
    _selectedType = widget.schedule['scheduleType'];
    _selectedTitle = widget.schedule['title'];
    _descController.text = widget.schedule['description'] ?? '';
    _repeatType = widget.schedule['repeatType'] ?? 'None';
    _selectedDate = DateTime.tryParse(widget.schedule['date'] ?? '');
    _startTime = _parseTime(widget.schedule['startTime']);
    _endTime = _parseTime(widget.schedule['endTime']);
  }

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // 💡 升级后的医院选择逻辑 (同步 Create 页面)
  Future<void> _showHospitalPicker() async {
    setState(() => _isLocating = true);
    try {
      loc.Location location = loc.Location();
      loc.LocationData locData = await location.getLocation();
      LatLng currentLocation = LatLng(locData.latitude!, locData.longitude!);

      // 搜索附近宠物医院
      var result = await googlePlace.search.getNearBySearch(
        gp.Location(lat: currentLocation.latitude, lng: currentLocation.longitude),
        5000,
        type: 'veterinary_care',
      );

      if (result != null && result.results != null && result.results!.isNotEmpty) {
        String? selectedHospital;
        await showDialog(
          context: context,
          builder: (ctx) => AlertDialog(
            title: const Text("Select Hospital"),
            content: SizedBox(
              width: double.maxFinite,
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: result.results!.length,
                itemBuilder: (context, index) {
                  final r = result.results![index];
                  final name = r.name ?? "Unknown";
                  final address = r.vicinity ?? "-";
                  return ListTile(
                    title: Text(name),
                    subtitle: Text(address),
                    onTap: () {
                      selectedHospital = "$name, $address";
                      Navigator.pop(ctx);
                    },
                  );
                },
              ),
            ),
          ),
        );
        if (selectedHospital != null) {
          _descController.text = "Hospital: $selectedHospital";
        }
      } else {
        await _showMapPicker(currentLocation);
      }
    } catch (e) {
      debugPrint("Location Error: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  // 💡 手动地图选择
  Future<void> _showMapPicker(LatLng initialLocation) async {
    LatLng? picked;
    await showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Pick Location on Map"),
        content: SizedBox(
          width: double.maxFinite,
          height: 400,
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: initialLocation, zoom: 15),
            onTap: (LatLng pos) {
              picked = pos;
            },
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () {
              if (picked != null) {
                _pickedLocation = picked;
                _descController.text = "Lat: ${picked!.latitude}, Lng: ${picked!.longitude}";
              }
              Navigator.pop(ctx);
            },
            child: const Text("Select"),
          )
        ],
      ),
    );
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
        context: context,
        initialDate: _selectedDate ?? DateTime.now(),
        firstDate: DateTime.now(),
        lastDate: DateTime.now().add(const Duration(days: 365)));
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
        context: context,
        initialTime: isStart
            ? (_startTime ?? TimeOfDay.now())
            : (_endTime ?? (_startTime ?? TimeOfDay.now())));
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  Future<void> _editSchedule() async {
    if (_selectedType == null || _selectedTitle == null || _selectedDate == null || _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing fields')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      final dateStr = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startStr = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";
      final endStr = "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00";

      await supabase.from('schedule').update({
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descController.text.trim(),
        'date': dateStr,
        'startTime': startStr,
        'endTime': endStr,
        'repeatType': _repeatType,
      }).eq('scheduleID', widget.schedule['scheduleID']);

      // 处理通知
      int notifId = int.tryParse(widget.schedule['scheduleID'].toString()) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;
      await NotificationService.cancelNotification(notifId);

      final scheduleTime = DateTime(_selectedDate!.year, _selectedDate!.month, _selectedDate!.day, _startTime!.hour, _startTime!.minute);
      final reminderTime = scheduleTime.subtract(const Duration(minutes: 1));

      await NotificationService.scheduleNotification(
        id: notifId,
        title: "Reminder: $_selectedTitle",
        body: "Starts in 1 minute! Time for your pet's task.",
        scheduledTime: reminderTime,
        repeatType: _repeatType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Changes saved!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  InputDecoration _inputDecoration(String label, IconData icon) => InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Schedule'), backgroundColor: themeColor, foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
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
                items: scheduleTypeToTitle[_selectedType]!.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
              if (_selectedType == 'Medical') ...[
                ElevatedButton.icon(
                  onPressed: _isLocating ? null : _showHospitalPicker, // 💡 调用升级后的函数
                  icon: const Icon(Icons.map),
                  label: Text(_isLocating ? "Locating..." : "Pick Hospital Location"),
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                ),
                const SizedBox(height: 16),
              ],
            ],
            TextField(
              controller: _descController,
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
            // 日期和时间选择列表保持一致样式
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
              onPressed: _editSchedule,
              style: ElevatedButton.styleFrom(backgroundColor: themeColor, minimumSize: const Size(double.infinity, 55)),
              child: const Text("SAVE CHANGES", style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}