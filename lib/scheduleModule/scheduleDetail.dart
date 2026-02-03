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
      Navigator.pop(context, true); // 返回上一页刷新
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

  String _formatTime(String? t) {
    if (t == null) return '-';
    final parts = t.split(':');
    return '${parts[0]}:${parts[1]}';
  }

  String _formatDate(String? d) {
    if (d == null) return '-';
    final parts = d.split('-');
    return '${parts[2]}/${parts[1]}/${parts[0]}'; // DD/MM/YYYY
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
              // 显示 Pet Name，如果没有则显示 petID
              Text(
                'Pet: ${schedule['petName'] ?? schedule['petID'] ?? '-'}',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w500),
              ),
              const SizedBox(height: 8),

              Text(
                'Title: ${schedule['title'] ?? '-'}',
                style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),

              Text('Type: ${schedule['scheduleType'] ?? '-'}'),
              Text('Date: ${_formatDate(schedule['date'])}'),
              Text(
                'Time: ${_formatTime(schedule['startTime'])} - ${_formatTime(schedule['endTime'])}',
              ),
              Text('Repeat: ${schedule['repeatType'] ?? '-'}'),
              Text('Description: ${schedule['description'] ?? '-'}'),
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
