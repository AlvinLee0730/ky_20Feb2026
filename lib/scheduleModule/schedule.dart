import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'createSchedule.dart';
import 'scheduleDetail.dart';

final supabase = Supabase.instance.client;

class SchedulePage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  final List<String> petIds;

  const SchedulePage({super.key, required this.pets, required this.petIds});

  @override
  State<SchedulePage> createState() => _SchedulePageState();
}

class _SchedulePageState extends State<SchedulePage> {
  final Color themeColor = Colors.teal;

  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  // 根据 petID 找名字
  String getPetName(String petID) {
    final pet = widget.pets.firstWhere(
          (p) => p['petID'].toString() == petID.toString(),
      orElse: () => {'petName': '-'},
    );
    return pet['petName'] ?? '-';
  }

  Future<void> _loadSchedules() async {
    if (widget.petIds.isEmpty) {
      setState(() => _schedules = []);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final scheduleResponse = await supabase
          .from('schedule')
          .select()
          .filter('petID', 'in', widget.petIds)
          .order('date', ascending: true);

      setState(() {
        _schedules = List<Map<String, dynamic>>.from(scheduleResponse);
      });
    } catch (e) {
      debugPrint('Error loading schedules: $e');
      setState(() => _schedules = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToDetail(Map<String, dynamic> schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => ScheduleDetailPage(schedule: schedule)),
    ).then((_) => _loadSchedules());
  }

  void _goToCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSchedulePage(pets: widget.pets, petIds: widget.petIds),
      ),
    );
    _loadSchedules();
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    final petName = getPetName(s['petID']);

    return Card(
      elevation: 2,
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(12),
        leading: CircleAvatar(
          backgroundColor: themeColor.withOpacity(0.1),
          child: Icon(Icons.calendar_today, color: themeColor),
        ),
        title: Text(
          s['title'] ?? '-',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        subtitle: Padding(
          padding: const EdgeInsets.only(top: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(Icons.pets, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(child: Text('Pet: $petName')),
                ],
              ),
              const SizedBox(height: 4),
              Row(
                children: [
                  const Icon(Icons.access_time, size: 14, color: Colors.grey),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text('${s['date']} | ${s['startTime']?.substring(0,5)} - ${s['endTime']?.substring(0,5)}'),
                  ),
                ],
              ),
            ],
          ),
        ),
        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
        onTap: () => _goToDetail(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Pet Schedules'),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : _schedules.isEmpty
          ? Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.event_note, size: 80, color: Colors.grey[300]),
            const SizedBox(height: 16),
            const Text('No schedules found. Plan some activities!',
                style: TextStyle(color: Colors.grey)),
          ],
        ),
      )
          : ListView.builder(
        padding: const EdgeInsets.only(top: 10, bottom: 80),
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          return _buildScheduleCard(_schedules[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreate,
        backgroundColor: themeColor,
        child: const Icon(Icons.add, color: Colors.white, size: 30),
      ),
    );
  }
}
