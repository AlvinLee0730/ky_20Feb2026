import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:location/location.dart' as loc;
import 'package:geocoding/geocoding.dart';
import 'package:newfypken/notification_service.dart'; // 导入通知服务

final supabase = Supabase.instance.client;

class EditSchedulePage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  const EditSchedulePage({super.key, required this.schedule});

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  // --- 样式规范 ---
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedType;
  String? _selectedTitle;
  final _descController = TextEditingController();
  String _selectedRepeat = 'None';

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;
  bool _isLocating = false;
  LatLng? _pickedLocation;

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    // 初始化已有数据
    _selectedType = widget.schedule['scheduleType'];
    _selectedTitle = widget.schedule['title'];
    _descController.text = widget.schedule['description'] ?? '';
    _selectedRepeat = widget.schedule['repeatType'] ?? 'None';

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

  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  // --- 地图选址逻辑 ---
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
            title: const Text("Update Medical Location"),
            content: SizedBox(
              width: double.maxFinite,
              height: 400,
              child: FlutterMap(
                options: MapOptions(
                  initialCenter: currentLatLng,
                  initialZoom: 15,
                  onTap: (tapPosition, point) async {
                    setDialogState(() => _pickedLocation = point);
                    try {
                      List<Placemark> placemarks = await placemarkFromCoordinates(
                          point.latitude, point.longitude);
                      if (placemarks.isNotEmpty) {
                        Placemark place = placemarks.first;
                        _descController.text = "Hospital: ${place.name}, ${place.street}, ${place.locality}";
                      }
                    } catch (e) {
                      _descController.text = "Lat: ${point.latitude}, Lng: ${point.longitude}";
                    }
                    Future.delayed(const Duration(milliseconds: 500), () => Navigator.pop(context));
                  },
                ),
                children: [
                  TileLayer(urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png'),
                  if (_pickedLocation != null)
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: _pickedLocation!,
                          child: const Icon(Icons.location_on, color: Colors.red, size: 40),
                        ),
                      ],
                    ),
                ],
              ),
            ),
          ),
        ),
      );
    } catch (e) {
      debugPrint("Location Error: $e");
    } finally {
      setState(() => _isLocating = false);
    }
  }

  Future<void> _pickDate() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? DateTime.now(),
      firstDate: DateTime.now().subtract(const Duration(days: 365)),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  // ⭐ 修改核心：更新数据库并重设通知
  Future<void> _editSchedule() async {
    if (_selectedType == null || _selectedTitle == null || _selectedDate == null || _startTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Missing fields')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";

      // 1. 更新数据库
      await supabase.from('schedule').update({
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descController.text.trim(),
        'date': dateString,
        'startTime': startTimeString,
        'repeatType': _selectedRepeat,
      }).eq('scheduleID', widget.schedule['scheduleID']);

      // 2. ⭐ 通知逻辑：先取消旧的，再设新的
      // 我们使用 scheduleID 作为通知 ID（确保它是 int 类型），这样就能精准找到并覆盖
      int notifId = int.tryParse(widget.schedule['scheduleID'].toString()) ?? DateTime.now().millisecondsSinceEpoch ~/ 1000;

      // 先取消旧的提醒
      await NotificationService.cancelNotification(notifId);

      // 设定新的提醒时间
      final newScheduleTime = DateTime(
        _selectedDate!.year, _selectedDate!.month, _selectedDate!.day,
        _startTime!.hour, _startTime!.minute,
      );

      // 重新安排通知
      await NotificationService.scheduleNotification(
        id: notifId,
        title: "Updated Task: $_selectedTitle",
        body: "$_selectedTitle for your pet",
        scheduledTime: newScheduleTime,
        repeatType: _selectedRepeat,
      );

      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schedule'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
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
                InkWell(
                  onTap: _isLocating ? null : _showOSMPicker,
                  child: Container(
                    padding: const EdgeInsets.all(15),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      borderRadius: BorderRadius.circular(borderRadius),
                      border: Border.all(color: Colors.red[200]!),
                    ),
                    child: Row(
                      children: [
                        _isLocating
                            ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                            : Icon(Icons.local_hospital, color: Colors.red[700]),
                        const SizedBox(width: 12),
                        const Expanded(child: Text("Update Hospital Location", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent))),
                        const Icon(Icons.gps_fixed, size: 18, color: Colors.redAccent),
                      ],
                    ),
                  ),
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
              value: _selectedRepeat,
              decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedRepeat = val!),
            ),
            const SizedBox(height: 24),

            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(borderRadius)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.calendar_month, color: themeColor),
                    title: Text(_selectedDate == null ? 'Select Date' : "${_selectedDate!.toLocal()}".split(' ')[0]),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.access_time, color: themeColor),
                    title: Text(_startTime == null ? 'Set Start' : "Starts at ${_startTime!.format(context)}"),
                    onTap: () => _pickTime(true),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _editSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: const Text('SAVE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}