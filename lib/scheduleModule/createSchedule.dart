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
  final _titleController = TextEditingController();
  final _descriptionController = TextEditingController();
  String _scheduleType = 'Activity';
  String _repeatType = 'None';

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;


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
        _titleController.text.isEmpty) {
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
        'scheduleType': _scheduleType,
        'title': _titleController.text.trim(),
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
    _titleController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Create Schedule'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: const InputDecoration(labelText: 'Select Pet'),
              items: widget.pets
                  .map<DropdownMenuItem<String>>((pet) => DropdownMenuItem<String>(
                value: pet['petID'].toString(),
                child: Text(pet['petName'] ?? 'No Name'),
              ))
                  .toList(),
              onChanged: (value) => setState(() => _selectedPetId = value),
            ),
            const SizedBox(height: 16),


            TextField(
              controller: _titleController,
              decoration: const InputDecoration(labelText: 'Title'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _descriptionController,
              decoration: const InputDecoration(labelText: 'Description'),
              maxLines: 3,
            ),
            const SizedBox(height: 16),


            DropdownButtonFormField<String>(
              value: _scheduleType,
              decoration: const InputDecoration(labelText: 'Schedule Type'),
              items: ['Activity', 'Medical', 'Other']
                  .map((type) => DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _scheduleType = val!),
            ),
            const SizedBox(height: 16),


            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: const InputDecoration(labelText: 'Repeat Type'),
              items: ['None', 'Daily', 'Weekly', 'Monthly']
                  .map((type) => DropdownMenuItem<String>(
                value: type,
                child: Text(type),
              ))
                  .toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 16),


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
