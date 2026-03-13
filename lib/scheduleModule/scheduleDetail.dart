import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/notification_service.dart';
import 'editSchedule.dart';

final supabase = Supabase.instance.client;

class ScheduleDetailPage extends StatefulWidget {
  final Map<String, dynamic> schedule;
  const ScheduleDetailPage({super.key, required this.schedule});

  @override
  State<ScheduleDetailPage> createState() => _ScheduleDetailPageState();
}

class _ScheduleDetailPageState extends State<ScheduleDetailPage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  Map<String, dynamic> schedule = {};

  @override
  void initState() {
    super.initState();
    schedule = {...widget.schedule};
    _loadPetName();
  }

  // Fetch petName from petID if not already in map
  Future<void> _loadPetName() async {
    if (schedule['petName'] == null && schedule['petID'] != null) {
      final res = await supabase
          .from('pet')
          .select('petName')
          .eq('petID', schedule['petID'])
          .maybeSingle();
      if (res != null && mounted) {
        setState(() {
          schedule['petName'] = res['petName'];
        });
      }
    }
  }

  void _goToEdit() async {
    final result = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EditSchedulePage(schedule: schedule),
      ),
    );
    if (result == true) {
      Navigator.pop(context, true); // Return to refresh the list after editing
    }
  }

  Future<void> _deleteSchedule() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Schedule?"),
        content: const Text("This will permanently remove this schedule and its reminders."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        final String scheduleID = schedule['scheduleID'] as String;

        // Calculate notification ID consistent with create/edit
        final int notifId = scheduleID.hashCode.abs();

        // Cancel notifications
        await NotificationService.cancel(notifId);
        print('Cancelled schedule notification: scheduleID $scheduleID | notifId $notifId');

        // Delete from Supabase
        await supabase.from('schedule').delete().eq('scheduleID', scheduleID);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Schedule deleted successfully.')),
          );
          Navigator.pop(context, true); // Return and refresh list
        }
      } catch (e) {
        print('Error deleting schedule: $e');
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Failed to delete schedule: $e')),
          );
        }
      }
    }
  }

  String _formatTime(String? t) {
    if (t == null || t.isEmpty) return '-';
    final parts = t.split(':');
    return '${parts[0]}:${parts[1]}';
  }

  Widget _buildDetailTile(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(icon, size: 20, color: themeColor),
          const SizedBox(width: 12),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text(value, style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w500)),
            ],
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Schedule Details'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          IconButton(icon: const Icon(Icons.edit), onPressed: _goToEdit),
        ],
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // Top info section
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 40),
              decoration: BoxDecoration(
                color: themeColor,
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
              ),
              child: Column(
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: Colors.white.withOpacity(0.2),
                    child: const Icon(Icons.event_available, size: 40, color: Colors.white),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    schedule['title'] ?? '-',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'Category: ${schedule['scheduleType'] ?? '-'}',
                    style: TextStyle(color: Colors.white.withOpacity(0.8), fontSize: 16),
                  ),
                ],
              ),
            ),
            // Content section
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildDetailTile(Icons.pets, "Pet Name", schedule['petName'] ?? '-'),
                  _buildDetailTile(Icons.calendar_month, "Date", schedule['date'] ?? '-'),
                  _buildDetailTile(Icons.access_time, "Time Window",
                      '${_formatTime(schedule['startTime'])} - ${_formatTime(schedule['endTime'])}'),
                  _buildDetailTile(Icons.repeat, "Frequency", schedule['repeatType'] ?? 'None'),
                  const Divider(height: 40),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      schedule['description']?.isEmpty ?? true
                          ? "No additional description."
                          : schedule['description'],
                      style: const TextStyle(height: 1.5, color: Colors.black87),
                    ),
                  ),
                  const SizedBox(height: 40),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _deleteSchedule,
                          icon: const Icon(Icons.delete_outline),
                          label: const Text("Delete"),
                          style: OutlinedButton.styleFrom(
                            foregroundColor: Colors.red,
                            side: const BorderSide(color: Colors.red),
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: ElevatedButton.icon(
                          onPressed: _goToEdit,
                          icon: const Icon(Icons.edit),
                          label: const Text("Edit Schedule"),
                          style: ElevatedButton.styleFrom(
                            backgroundColor: themeColor,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 15),
                            elevation: 0,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}