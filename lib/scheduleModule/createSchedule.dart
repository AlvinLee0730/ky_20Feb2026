import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
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

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  // 日期选择
  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: DateTime.now(),
      firstDate: DateTime.now(),
      lastDate: DateTime.now().add(const Duration(days: 365)),
    );
    if (d != null) setState(() => _selectedDate = d);
  }

  // 时间选择
  Future<void> _pickTime(bool isStart) async {
    final t = await showTimePicker(context: context, initialTime: TimeOfDay.now());
    if (t != null) setState(() => isStart ? _startTime = t : _endTime = t);
  }

  // 创建 Schedule
  Future<void> _createSchedule() async {
    if (_selectedPetId == null ||
        _selectedType == null ||
        _selectedTitle == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('請填寫所有欄位')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateString =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2, '0')}-${_selectedDate!.day.toString().padLeft(2, '0')}";
      final startTimeString =
          "${_startTime!.hour.toString().padLeft(2, '0')}:${_startTime!.minute.toString().padLeft(2, '0')}:00";
      final endTimeString =
          "${_endTime!.hour.toString().padLeft(2, '0')}:${_endTime!.minute.toString().padLeft(2, '0')}:00";

      final startDateTime = DateTime(
        _selectedDate!.year,
        _selectedDate!.month,
        _selectedDate!.day,
        _startTime!.hour,
        _startTime!.minute,
      );

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

      final scheduleID =
      insertResponse.isNotEmpty ? insertResponse.first['scheduleID'] as String? : null;

      if (scheduleID != null) {
        await NotificationService.scheduleEventReminder(
          scheduleId: scheduleID,
          title: _selectedTitle!,
          description:
          _descriptionController.text.trim().isNotEmpty ? _descriptionController.text.trim() : null,
          startDateTime: startDateTime,
          repeatType: _repeatType,
        );
      }

      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Schedule Created Successfully!')));
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Error creating schedule: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Schedule creation failed: $e')),
        );
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
        borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
  );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
          title: const Text('New Schedule'),
          backgroundColor: themeColor,
          foregroundColor: Colors.white),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // 選擇寵物
            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: _inputDecoration('Select Pet', Icons.pets),
              items: widget.pets
                  .map((pet) => DropdownMenuItem(
                  value: pet['petID'].toString(), child: Text(pet['petName'] ?? 'No Name')))
                  .toList(),
              onChanged: (val) => setState(() => _selectedPetId = val),
            ),
            const SizedBox(height: 16),

            // Schedule Type
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys
                  .map((type) => DropdownMenuItem(value: type, child: Text(type)))
                  .toList(),
              onChanged: (val) => setState(() {
                _selectedType = val;
                _selectedTitle = null;
              }),
            ),
            const SizedBox(height: 16),

            // Title
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
            ],

            // Description
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 16),

            // Repeat
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly']
                  .map((t) => DropdownMenuItem(value: t, child: Text(t)))
                  .toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 20),

            // Date Picker
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

            // Start Time
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time),
              title: Text(_startTime == null ? "Pick Start Time" : _startTime!.format(context)),
              onTap: () => _pickTime(true),
            ),
            const SizedBox(height: 10),

            // End Time
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              leading: const Icon(Icons.access_time_filled),
              title: Text(_endTime == null ? "Pick End Time" : _endTime!.format(context)),
              onTap: () => _pickTime(false),
            ),
            const SizedBox(height: 30),

            // Create Schedule
            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _createSchedule,
              style: ElevatedButton.styleFrom(
                  backgroundColor: themeColor, minimumSize: const Size(double.infinity, 55)),
              child: const Text("Create Schedule",
                  style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}