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
  DateTime? _endDate; // Added end date variable

  @override
  void initState() {
    super.initState();
    _loadSchedules();
  }

  String getPetName(dynamic petID) {
    if (petID == null) return '-';
    final pet = widget.pets.firstWhere(
          (p) => p['petID']?.toString() == petID.toString(),
      orElse: () => {'petName': '-'},
    );
    return pet['petName'] as String? ?? '-';
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
      _applyFilter();
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
    final title = s['title'] as String? ?? 'Untitled';
    final dateStr = s['date'] as String? ?? '-';
    final startTime = (s['startTime'] as String?)?.substring(0, 5) ?? '--:--';
    final endTime = (s['endTime'] as String?)?.substring(0, 5) ?? '--:--';

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
          title,
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
                    child: Text('$dateStr | $startTime - $endTime'),
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
    DateTime? tempEnd = _endDate; // Temporary end date for the dialog

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Filter Schedules'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Pet Selection
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

                // Start Date Selection (From)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'From: ${tempStart?.toLocal().toString().split(' ')[0] ?? 'Select Start Date'}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempStart ?? DateTime.now(),
                      firstDate: DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) {
                      setDialogState(() {
                        tempStart = picked;
                        // If start date is after end date, reset end date
                        if (tempEnd != null && tempStart!.isAfter(tempEnd!)) {
                          tempEnd = null;
                        }
                      });
                    }
                  },
                ),

                // End Date Selection (To)
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(
                    'To: ${tempEnd?.toLocal().toString().split(' ')[0] ?? 'Select End Date'}',
                  ),
                  trailing: const Icon(Icons.calendar_today),
                  onTap: () async {
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: tempEnd ?? tempStart ?? DateTime.now(),
                      // Restrict end date to not be before start date
                      firstDate: tempStart ?? DateTime.now().subtract(const Duration(days: 365)),
                      lastDate: DateTime.now().add(const Duration(days: 365)),
                    );
                    if (picked != null) setDialogState(() => tempEnd = picked);
                  },
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () {
                setState(() {
                  _selectedPetId = null;
                  _startDate = null;
                  _endDate = null; // Clear on reset
                  _applyFilter();
                });
                Navigator.pop(ctx);
              },
              child: const Text('Reset'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cancel'),
            ),
            ElevatedButton(
              onPressed: () {
                setState(() {
                  _selectedPetId = tempPetId;
                  _startDate = tempStart;
                  _endDate = tempEnd; // Save changes on apply
                  _applyFilter();
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
        // Parse the date from the database
        final parsedDate = DateTime.tryParse(s['date'] ?? '') ?? DateTime(2000);

        // Format to pure date (remove time part to prevent comparison bugs between 23:59 and 00:00)
        final scheduleDate = DateTime(parsedDate.year, parsedDate.month, parsedDate.day);

        // 1. Match pet
        bool petMatch = _selectedPetId == null ||
            s['petID'].toString() == _selectedPetId.toString();

        // 2. Match start date (scheduleDate cannot be before _startDate)
        bool startMatch = _startDate == null ||
            !scheduleDate.isBefore(DateTime(_startDate!.year, _startDate!.month, _startDate!.day));

        // 3. Match end date (scheduleDate cannot be after _endDate)
        bool endMatch = _endDate == null ||
            !scheduleDate.isAfter(DateTime(_endDate!.year, _endDate!.month, _endDate!.day));

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
            const Text(
              'No schedules found. Plan some activities!',
              style: TextStyle(color: Colors.grey),
            ),
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