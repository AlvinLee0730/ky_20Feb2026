import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'editSchedule.dart';

final supabase = Supabase.instance.client;

class ScheduleDetailPage extends StatelessWidget {
  final Map<String, dynamic> schedule;
  const ScheduleDetailPage({super.key, required this.schedule});

  void _goToEdit(BuildContext context) async {

    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSchedulePage(schedule: schedule),
      ),
    );


    if (result == true) {
      Navigator.pop(context, true);
    }
  }

  Future<void> _deleteSchedule(BuildContext context) async {
    try {
      await supabase.from('schedule').delete().eq('scheduleID', schedule['scheduleID']);
      Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Delete failed: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Detail'),
        centerTitle: true,
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Title: ${schedule['title'] ?? '-'}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              Text('Type: ${schedule['scheduleType'] ?? '-'}'),
              Text('Date: ${schedule['date'] ?? '-'}'),
              Text('Time: ${schedule['startTime'] ?? '-'} - ${schedule['endTime'] ?? '-'}'),
              Text('Repeat: ${schedule['repeatType'] ?? '-'}'),
              const SizedBox(height: 32),
              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () => _goToEdit(context),
                      child: const Text('Edit'),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                      onPressed: () => _deleteSchedule(context),
                      child: const Text('Delete'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
