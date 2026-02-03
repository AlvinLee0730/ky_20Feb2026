import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class CreateSchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final List<String> petIds;

  const CreateSchedulePage({super.key, required this.pets, required this.petIds});

  @override
  State<CreateSchedulePage> createState() => _CreateSchedulePageState();
}

class _CreateSchedulePageState extends State<CreateSchedulePage> {
  String? _selectedPetId;
  String? _selectedTitle;
  String? _selectedType;
  String _repeatType = 'None';
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  // Map of ScheduleType → Titles
  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
    );
    if (picked != null) {
      setState(() {
        if (isStart) {
          _startTime = picked;
        } else {
          _endTime = picked;
        }
      });
    }
  }

  Future<void> _createSchedule() async {
    if (_selectedPetId == null ||
        _selectedDate == null ||
        _startTime == null ||
        _endTime == null ||
        _selectedType == null ||
        _selectedTitle == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all required fields')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final dateString =
          "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString =
          "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";
      final endTimeString =
          "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00";

      await supabase.from('schedule').insert({
        'petID': _selectedPetId,
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'date': dateString,
        'startTime': startTimeString,
        'endTime': endTimeString,
        'repeatType': _repeatType,
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Schedule created!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Create Schedule'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            // Pet selection
            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: const InputDecoration(labelText: 'Select Pet'),
              items: widget.pets
                  .map<DropdownMenuItem<String>>((pet) => DropdownMenuItem(
                value: pet['petID'].toString(),
                child: Text(pet['petName'] ?? 'No Name'),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _selectedPetId = val),
            ),
            const SizedBox(height: 16),

            // Schedule Type selection
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
                  _selectedTitle = null; // 重置 title
                });
              },
            ),
            const SizedBox(height: 16),

            // Title selection (depends on selected type)
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
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),

            // Repeat Type
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: const InputDecoration(labelText: 'Repeat Type'),
              items: ['None', 'Daily', 'Weekly', 'Monthly']
                  .map((type) => DropdownMenuItem(
                value: type,
                child: Text(type),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
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
                : ElevatedButton(
              onPressed: _createSchedule,
              child: const Text('Create Schedule'),
            ),
          ],
        ),
      ),
    );
  }
}
