import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();

    // Fill previous schedule data
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
    if (_selectedType == null || _selectedTitle == null || _selectedDate == null ||
        _startTime == null || _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please fill all required fields')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateStr =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final startStr =
          "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00";
      final endStr =
          "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00";

      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

      // Update Supabase
      await supabase.from('schedule').update({
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descController.text.trim(),
        'date': dateStr,
        'startTime': startStr,
        'endTime': endStr,
        'repeatType': _repeatType,
      }).eq('scheduleID', widget.schedule['scheduleID']);

      // Cancel old notification
      final String scheduleID = widget.schedule['scheduleID'] as String;
      final int oldNotifId = scheduleID.hashCode.abs();
      await NotificationService.cancel(oldNotifId);

      // Schedule new notification
      await NotificationService.scheduleEventReminder(
        scheduleId: scheduleID,
        title: _selectedTitle!,
        description: _descController.text.trim().isNotEmpty
            ? _descController.text.trim()
            : null,
        startDateTime: startDateTime,
        repeatType: _repeatType,
      );

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Schedule updated successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Update failed: $e')));
      }
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
          borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none));

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('Edit Schedule'),
          backgroundColor: themeColor,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val;
                  _selectedTitle = null;
                });
              },
            ),
            const SizedBox(height: 16),
            if (_selectedType != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: _inputDecoration('Activity Title', Icons.title),
                items: scheduleTypeToTitle[_selectedType]!
                    .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                    .toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
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
              items: ['None', 'Daily', 'Weekly', 'Monthly']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 20),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.calendar_today),
              title: Text(_selectedDate == null
                  ? "Pick Date"
                  : _selectedDate.toString().split(' ')[0]),
              onTap: _pickDate,
            ),
            const SizedBox(height: 10),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time),
              title:
              Text(_startTime == null ? "Pick Start Time" : _startTime!.format(context)),
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
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor, minimumSize: const Size(double.infinity, 55)),
              child: const Text("SAVE CHANGES",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}