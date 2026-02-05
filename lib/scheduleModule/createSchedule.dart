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
  // --- 样式定义：对齐队友基因 ---
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String? _selectedPetId;
  String? _selectedTitle;
  String? _selectedType;
  String _repeatType = 'None';
  final _descriptionController = TextEditingController();

  DateTime? _selectedDate;
  TimeOfDay? _startTime;
  TimeOfDay? _endTime;

  bool _isLoading = false;

  final Map<String, List<String>> scheduleTypeToTitle = {
    'Activity': ['Feed', 'Walk', 'Play Ball', 'Training'],
    'Medical': ['Vaccination', 'Checkup', 'Medication'],
    'Grooming': ['Bath', 'Haircut', 'Nail Trim'],
  };

  // 统一的装饰器
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

  // --- 选择逻辑保持不变，UI 交互优化 ---
  Future<void> _pickDate() async {
    final today = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: today,
      firstDate: today.subtract(const Duration(days: 365)),
      lastDate: today.add(const Duration(days: 365)),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: themeColor)), child: child!),
    );
    if (picked != null) setState(() => _selectedDate = picked);
  }

  Future<void> _pickTime(bool isStart) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.now(),
      builder: (context, child) => Theme(data: Theme.of(context).copyWith(colorScheme: ColorScheme.light(primary: themeColor)), child: child!),
    );
    if (picked != null) setState(() => isStart ? _startTime = picked : _endTime = picked);
  }

  // ... _createSchedule 逻辑保持不变 ...
  Future<void> _createSchedule() async {
    if (_selectedPetId == null || _selectedDate == null || _startTime == null || _endTime == null || _selectedType == null || _selectedTitle == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Please fill all required fields')));
      return;
    }
    setState(() => _isLoading = true);
    try {
      final dateString = "${_selectedDate!.year}-${_selectedDate!.month.toString().padLeft(2,'0')}-${_selectedDate!.day.toString().padLeft(2,'0')}";
      final startTimeString = "${_startTime!.hour.toString().padLeft(2,'0')}:${_startTime!.minute.toString().padLeft(2,'0')}:00";
      final endTimeString = "${_endTime!.hour.toString().padLeft(2,'0')}:${_endTime!.minute.toString().padLeft(2,'0')}:00";

      await supabase.from('schedule').insert({
        'petID': _selectedPetId,
        'scheduleType': _selectedType,
        'title': _selectedTitle,
        'description': _descriptionController.text.trim(),
        'date': dateString,
        'startTime': startTimeString,
        'endTime': endTimeString,
        'repeatType': _repeatType,
      });
      Navigator.pop(context);
    } catch (e) {
      debugPrint("Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('New Schedule'),
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
            // 宠物选择
            DropdownButtonFormField<String>(
              value: _selectedPetId,
              decoration: _inputDecoration('Select Pet', Icons.pets),
              items: widget.pets.map((pet) => DropdownMenuItem(value: pet['petID'].toString(), child: Text(pet['petName'] ?? 'No Name'))).toList(),
              onChanged: (val) => setState(() => _selectedPetId = val),
            ),
            const SizedBox(height: 16),

            // 类型选择
            DropdownButtonFormField<String>(
              value: _selectedType,
              decoration: _inputDecoration('Schedule Type', Icons.category),
              items: scheduleTypeToTitle.keys.map((type) => DropdownMenuItem(value: type, child: Text(type))).toList(),
              onChanged: (val) => setState(() { _selectedType = val; _selectedTitle = null; }),
            ),
            const SizedBox(height: 16),

            // 标题选择
            if (_selectedType != null) ...[
              DropdownButtonFormField<String>(
                value: _selectedTitle,
                decoration: _inputDecoration('Activity Title', Icons.title),
                items: scheduleTypeToTitle[_selectedType]!.map((title) => DropdownMenuItem(value: title, child: Text(title))).toList(),
                onChanged: (val) => setState(() => _selectedTitle = val),
              ),
              const SizedBox(height: 16),
            ],

            // 描述
            TextField(
              controller: _descriptionController,
              maxLines: 2,
              decoration: _inputDecoration('Description (Optional)', Icons.description),
            ),
            const SizedBox(height: 16),

            // 重复类型
            DropdownButtonFormField<String>(
              value: _repeatType,
              decoration: _inputDecoration('Repeat', Icons.repeat),
              items: ['None', 'Daily', 'Weekly', 'Monthly'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
              onChanged: (val) => setState(() => _repeatType = val!),
            ),
            const SizedBox(height: 24),

            // 时间日期选择区域（重点优化：不再是碎按钮，而是卡片感）
            const Text("Date & Time", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            const SizedBox(height: 10),
            Container(
              decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(borderRadius)),
              child: Column(
                children: [
                  ListTile(
                    leading: Icon(Icons.calendar_month, color: themeColor),
                    title: Text(_selectedDate == null ? 'Choose Date' : "${_selectedDate!.toLocal()}".split(' ')[0]),
                    onTap: _pickDate,
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.access_time, color: themeColor),
                    title: Text(_startTime == null ? 'Start Time' : "Starts at ${_startTime!.format(context)}"),
                    onTap: () => _pickTime(true),
                  ),
                  const Divider(height: 1, indent: 50),
                  ListTile(
                    leading: Icon(Icons.update, color: themeColor),
                    title: Text(_endTime == null ? 'End Time' : "Ends at ${_endTime!.format(context)}"),
                    onTap: () => _pickTime(false),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 40),

            // 创建按钮
            _isLoading
                ? const Center(child: CircularProgressIndicator())
                : ElevatedButton(
              onPressed: _createSchedule,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                elevation: 0,
              ),
              child: const Text('CREATE SCHEDULE', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}