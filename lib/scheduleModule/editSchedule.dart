import 'dart:io';
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
  // --- 样式规范：同步队友基因 ---
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedType;
  String? _selectedTitle;
  final _descController = TextEditingController();
  final _repeatTypeController = TextEditingController(); // 建议改为控制器或下拉

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  @override
  void initState() {
    super.initState();
    _selectedType = widget.schedule['scheduleType'];
    _selectedTitle = widget.schedule['title'];
    _descController.text = widget.schedule['description'] ?? '';
    // 假设数据里叫 repeatType
    _selectedRepeat = widget.schedule['repeatType'] ?? 'None';

    _selectedDate = DateTime.tryParse(widget.schedule['date'] ?? '');
    _startTime = _parseTime(widget.schedule['startTime']);
    _endTime = _parseTime(widget.schedule['endTime']);
  }

  String _selectedRepeat = 'None'; // 为了 UI 一致性，建议用下拉

  TimeOfDay? _parseTime(String? timeStr) {
    if (timeStr == null || timeStr.isEmpty) return null;
    final parts = timeStr.split(':');
    if (parts.length < 2) return null;
    return TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
  }

  // 统一的输入框样式
  InputDecoration _inputDecoration(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    );
  }

  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate ?? today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: themeColor)), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? (_startTime ?? TimeOfDay.now()) : (_endTime ?? TimeOfDay.now()),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: themeColor)), child: child!),
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  // ... (保留原有的 _editSchedule 和 _deleteSchedule 逻辑) ...
  Future<void> _editSchedule() async {
    if (_selectedType == null || _selectedTitle == null || _selectedDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Type, Title and Date are required')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = _startTime != null ? "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00" : null;
      final endTimeString = _endTime != null ? "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00" : null;

      await supabase.from('schedule').update({
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descController.text,
        'date': dateString,
        'startTime': startTimeString,
        'endTime': endTimeString,
        'repeatType': _selectedRepeat,
      }).eq('scheduleID', widget.schedule['scheduleID']);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Update Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _deleteSchedule() async {
    // 添加删除确认弹窗（符合队友的交互习惯）
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Schedule?"),
        content: const Text("Are you sure you want to remove this activity?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);
    try {
      await supabase.from('schedule').delete().eq('scheduleID', widget.schedule['scheduleID']);
      Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Delete Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Schedule'),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 类型选择
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() { _selectedType = val; _selectedTitle = null; }),
            ),
            const SizedBox(height: 16),

            // 标题选择
            if (_selectedType != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: _inputDecoration('Activity Title', Icons.title),
                items: scheduleTypeToTitle[_selectedType]!.map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
            ],

            // 描述
            TextField(
              controller: _descController,
              maxLines: 2,
              decoration: _inputDecoration('Description', Icons.description),
            ),
            const SizedBox(height: 16),

            // 重复类型下拉
            DropdownButtonFormField<String>(
              value: _selectedRepeat,
              decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _selectedRepeat = val!),
            ),
            const SizedBox(height: 24),

            // 日期时间选择（卡片式）
            const Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(borderRadius)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.calendar_month, color: themeColor),
                    title: Text(_selectedDate == null ? 'Select Date' : "${_selectedDate!.toLocal()}".split(' ')[0]),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.access_time, color: themeColor),
                    title: Text(_startTime == null ? 'Set Start' : "Starts at ${_startTime!.format(context)}"),
                    onTap: () => _pickTime(true),
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.update, color: themeColor),
                    title: Text(_endTime == null ? 'Set End' : "Ends at ${_endTime!.format(context)}"),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 操作按钮：对齐队友 Chat 模块的双按钮风格
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : Row(
              children: [
                Expanded(
                  child: ElevatedButton(
                    onPressed: _editSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                      elevation: 0,
                    ),
                    child: const Text('SAVE', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton(
                    onPressed: _deleteSchedule,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.red[400],
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                      elevation: 0,
                    ),
                    child: const Text('DELETE', style: TextStyle(fontWeight: FontWeight.bold)),
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