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
  late TextEditingController _titleController;
  late TextEditingController _typeController;
  late TextEditingController _descController;
  late TextEditingController _dateController;
  late TextEditingController _startTimeController;
  late TextEditingController _endTimeController;
  late TextEditingController _repeatController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _titleController = TextEditingController(text: widget.schedule['title']);
    _typeController = TextEditingController(text: widget.schedule['scheduleType']);
    _descController = TextEditingController(text: widget.schedule['description']);
    _dateController = TextEditingController(text: widget.schedule['date']);
    _startTimeController = TextEditingController(text: widget.schedule['startTime']);
    _endTimeController = TextEditingController(text: widget.schedule['endTime']);
    _repeatController = TextEditingController(text: widget.schedule['repeatType']);
  }

  Future<void> _editSchedule() async {
    if (_titleController.text.isEmpty || _dateController.text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Title and Date required')));
      return;
    }

    setState(() => _isLoading = true);
    try {
      await supabase.from('schedule').update({
        'title': _titleController.text,
        'scheduleType': _typeController.text,
        'description': _descController.text,
        'date': _dateController.text,
        'startTime': _startTimeController.text,
        'endTime': _endTimeController.text,
        'repeatType': _repeatController.text,
      }).eq('scheduleID', widget.schedule['scheduleID']);

      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Update failed: $e')));
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Schedule'), centerTitle: true),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: 'Title')),
            TextField(controller: _typeController, decoration: const InputDecoration(labelText: 'Type')),
            TextField(controller: _descController, decoration: const InputDecoration(labelText: 'Description')),
            TextField(controller: _dateController, decoration: const InputDecoration(labelText: 'Date')),
            TextField(controller: _startTimeController, decoration: const InputDecoration(labelText: 'Start Time')),
            TextField(controller: _endTimeController, decoration: const InputDecoration(labelText: 'End Time')),
            TextField(controller: _repeatController, decoration: const InputDecoration(labelText: 'Repeat Type')),
            const SizedBox(height: 16),
            _isLoading
                ? const CircularProgressIndicator()
                : Row(
              children: [
                Expanded(
                  child: ElevatedButton(onPressed: _editSchedule, child: const Text('Confirm Edit')),
                ),
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
