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
  List<Map<String, dynamic>> _schedules = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  // 获取 pet 名字
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
          .filter('petID','in', widget.petIds)
          .order('date', ascending: true);

      setState(() {
        _schedules = List<Map<String, dynamic>>.from(scheduleResponse);
      });
    } catch (e) {
      print('Error loading schedules: $e');
      setState(() => _schedules = []);
    } finally {
      setState(() => _isLoading = false);
    }
  }

  void _goToDetail(Map<String, dynamic> schedule) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ScheduleDetailPage(schedule: schedule),
      ),
    ).then((_) => _loadSchedules());
  }

  void _goToCreate() async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => CreateSchedulePage(
          pets: widget.pets,
          petIds: widget.petIds,
        ),
      ),
    );
    _loadSchedules();
  }

  Widget _buildScheduleCard(Map<String, dynamic> s) {
    final petName = getPetName(s['petID']);
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: ListTile(
        leading: const Icon(Icons.event),
        title: Text(s['title'] ?? '-'),
        subtitle: Text(
          'Pet: $petName\n'
              'Date: ${s['date']} | ${s['startTime'] ?? '-'} - ${s['endTime'] ?? '-'}\n'
              'Type: ${s['scheduleType'] ?? '-'}',
        ),
        isThreeLine: true,
        trailing: const Icon(Icons.arrow_forward_ios),
        onTap: () => _goToDetail(s),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Schedules'), centerTitle: true),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _schedules.isEmpty
          ? const Center(child: Text('No schedules found.'))
          : ListView.builder(
        itemCount: _schedules.length,
        itemBuilder: (context, index) {
          return _buildScheduleCard(_schedules[index]);
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _goToCreate,
        child: const Icon(Icons.add),
      ),
    );
  }
}
