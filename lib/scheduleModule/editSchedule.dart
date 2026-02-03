import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EditSchedulePage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  const EditSchedulePage({super.key, required this.schedule});

  @override
  State<EditSchedulePage> createState() => _EditSchedulePageState();
}

class _EditSchedulePageState extends State<EditSchedulePage> {
  String? _selectedType;
  String? _selectedTitle;
  final _descController = TextEditingController();
  final _repeatController = TextEditingController();
  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  // Type → Titles 映射
  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.schedule['scheduleType'];
    _selectedTitle = widget.schedule['title'];
    _descController.text = widget.schedule['description'] ?? '';
    _repeatController.text = widget.schedule['repeatType'] ?? 'None';

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
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
    );
    if (picked != null) {
      setState(() {
        if (isStart) _startTime = picked;
        else _endTime = picked;
      });
    }
  }

  Future<void> _editSchedule() async {
    if (_selectedType == null || _selectedTitle == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Type, Title and Date are required')));
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateString =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = _startTime != null
          ? "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00"
          : null;
      final endTimeString = _endTime != null
          ? "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00"
          : null;

      await supabase.from('schedule').update({
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descController.text,
        'date': dateString,
        'startTime': startTimeString,
        'endTime': endTimeString,
        'repeatType': _repeatController.text,
      }).eq('scheduleID', widget.schedule['scheduleID']);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Update failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule() async {
    setState(() => _isLoading = true);
    try {
      await supabase.from('schedule').delete().eq('scheduleID', widget.schedule['scheduleID']);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descController.dispose();
    _repeatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Schedule'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Type 下拉
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: const InputDecoration(labelText: 'Schedule Type'),
              items: scheduleTypeToTitle.keys
                  .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              ))
                  .toList(),
              onChanged: (val) {
                setState(() {
                  _selectedType = val;
                  _selectedTitle = null;
                });
              },
            ),
            const SizedBox(height: 16),

            // Title 下拉
            if (_selectedType != null)
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: const InputDecoration(labelText: 'Title'),
                items: scheduleTypeToTitle[_selectedType]!
                    .map((title) => DropdownMenuItem(
                  value: title,
                  child: Text(title),
                ))
                    .toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
            const SizedBox(height: 16),

            // Description
            TextField(
              controller: _descController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Repeat Type
            TextField(
              controller: _repeatController,
              decoration: const InputDecoration(labelText: 'Repeat Type'),
            ),
            const SizedBox(height: 16),

            // Date & Time pickers
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                ElevatedButton(
                  onPressed: _pickDate,
                  child: Text(_selectedDate == null
                      ? 'Select Date'
                      : 'Date: ${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}'),
                ),
                ElevatedButton(
                  onPressed: () => _pickTime(true),
                  child: Text(_startTime == null
                      ? 'Start Time'
                      : 'Start: ${_startTime!.format(context)}'),
                ),
                ElevatedButton(
                  onPressed: () => _pickTime(false),
                  child: Text(_endTime == null
                      ? 'End Time'
                      : 'End: ${_endTime!.format(context)}'),
                ),
              ],
            ),
            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator()
                : Row(
              children: [
                Expanded(
                    child: ElevatedButton(
                        onPressed: _editSchedule,
                        child: const Text('Confirm Edit'))),
                const SizedBox(width: 16),
                Expanded(
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                    onPressed: _deleteSchedule,
                    child: const Text('Delete'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
