import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/notification_service.dart';
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
  List<Map<String, dynamic>> _filteredSchedules = [];
  bool _isLoading = true;

  // Filter fields
  String? _selectedPetId;
  DateTime? _startDate;
  DateTime? _endDate;

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  String getPetName(String petID) {
    final pet = widget.pets.firstWhere(
          (p) => p['petID'].toString() == petID.toString(),
      orElse: () => {'petName': '-'},
    );
    return pet['petName'] ?? '-';
  }

  Future<void> _loadSchedules() async {
    if (widget.petIds.isEmpty) {
      setState(() {
        _schedules = [];
        _filteredSchedules = [];
      });
      return;
    }
    setState(() => _isLoading = true);
    try {
      final scheduleResponse = await supabase
          .from('schedule')
          .select()
          .filter('petID', 'in', widget.petIds)
          .order('date', ascending: true);
      _schedules = List<Map<String, dynamic>>.from(scheduleResponse);
      _applyFilter(); // 初始显示全部
    } catch (e) {
      debugPrint('Error loading schedules: $e');
      setState(() {
        _schedules = [];
        _filteredSchedules = [];
      });
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

  void _openFilterDialog() async {
    String? tempPetId = _selectedPetId;
    DateTime? tempStart = _startDate;
    DateTime? tempEnd = _endDate;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Schedules'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<String>(
                  value: tempPetId,
                  decoration: const InputDecoration(labelText: 'Pet'),
                  items: [
                    const DropdownMenuItem(value: null, child: Text('All Pets')),
                    ...widget.pets.map(
                          (p) => DropdownMenuItem(value: p['petID'], child: Text(p['petName'] ?? '-')),
                    )
                  ],
                  onChanged: (val) => setDialogState(() => tempPetId = val),
                ),
                const SizedBox(height: 12),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'From: ${tempStart?.toLocal().toString().split(' ')[0] ?? 'Start Date'}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempStart ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => tempStart = picked);
                  },
                ),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'To: ${tempEnd?.toLocal().toString().split(' ')[0] ?? 'End Date'}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempEnd ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => tempEnd = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            // Reset 按钮
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPetId = null;
                  _startDate = null;
                  _endDate = null;
                  _applyFilter(); // 清空筛选显示所有
                });
                Navigator.pop(ctx); // 关闭 dialog
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(ctx); // 取消
              },
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedPetId = tempPetId;
                  _startDate = tempStart;
                  _endDate = tempEnd;
                  _applyFilter(); // 应用筛选
                });
                Navigator.pop(ctx);
              },
              child: const Text('Apply'),
            ),
          ],
        ),
      ),
    );
  }

  void _applyFilter() {
    setState(() {
      _filteredSchedules = _schedules.where((s) {
        bool petMatch = _selectedPetId == null || s['petID'].toString() == _selectedPetId.toString();
        bool startMatch = _startDate == null || DateTime.parse(s['date']).isAfter(_startDate!.subtract(const Duration(days: 1)));
        bool endMatch = _endDate == null || DateTime.parse(s['date']).isBefore(_endDate!.add(const Duration(days: 1)));
        return petMatch && startMatch && endMatch;
      }).toList();
    });
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
        actions: [
          IconButton(
            icon: const Icon(Icons.filter_alt),
            tooltip: 'Filter schedules',
            onPressed: _openFilterDialog,
          ),
        ],
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : _filteredSchedules.isEmpty
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
        itemCount: _filteredSchedules.length,
        itemBuilder: (context, index) {
          return _buildScheduleCard(_filteredSchedules[index]);
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