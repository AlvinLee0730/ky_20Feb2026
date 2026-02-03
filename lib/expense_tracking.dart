import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:fl_chart/fl_chart.dart';
import 'dart:math';

class ExpenseTrackingPage extends StatefulWidget {
  const ExpenseTrackingPage({super.key});

  @override
  State<ExpenseTrackingPage> createState() => _ExpenseTrackingPageState();
}

class _ExpenseTrackingPageState extends State<ExpenseTrackingPage> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  // State
  String _selectedCategory = 'Pet Food';
  DateTime _selectedDate = DateTime.now();
  // This controls which month the analytics and list display
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  bool _isSaving = false;

  final Map<String, double> _monthlyBudgets = {};
  final double _defaultBudget = 1000.0;

  // --- DATA ACCESS ---
  String get _currentUID => _supabase.auth.currentUser!.id;

  // We fetch a broader stream so we can calculate MoM variance by looking at previous months
  Stream<List<Map<String, dynamic>>> get _expenseStream => _supabase
      .from('pet_expenses')
      .stream(primaryKey: ['expenseID'])
      .eq('userID', _currentUID)
      .order('date', ascending: false);

  double get _currentMonthBudget {
    String key = DateFormat('yyyy-MM').format(_focusedMonth);
    return _monthlyBudgets[key] ?? _defaultBudget;
  }

  // --- ANALYTICS CALCULATIONS ---

  Map<String, dynamic> _calculateAdvancedAnalytics(List<Map<String, dynamic>> allData) {
    final now = DateTime.now();

    // 1. Filter data for the CURRENTLY SELECTED month
    final focusedMonthData = allData.where((e) {
      DateTime d = DateTime.parse(e['date']);
      return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
    }).toList();
    double focusedTotal = focusedMonthData.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    // 2. Filter data for the month BEFORE the selected month (for MoM Variance)
    DateTime prevMonth = DateTime(_focusedMonth.year, _focusedMonth.month - 1);
    final prevMonthData = allData.where((e) {
      DateTime d = DateTime.parse(e['date']);
      return d.year == prevMonth.year && d.month == prevMonth.month;
    }).toList();
    double prevTotal = prevMonthData.fold(0, (sum, e) => sum + (e['amount'] ?? 0));

    // Calculate Variance %
    double variance = 0;
    if (prevTotal > 0) {
      variance = ((focusedTotal - prevTotal) / prevTotal) * 100;
    }

    // 3. Daily Burn Rate
    // If viewing the actual current calendar month, divide by today's date.
    // Otherwise, divide by total days in that historical month.
    int daysInMonth = DateTime(_focusedMonth.year, _focusedMonth.month + 1, 0).day;
    int divisor = (_focusedMonth.year == now.year && _focusedMonth.month == now.month)
        ? now.day
        : daysInMonth;
    double burnRate = focusedTotal / (divisor > 0 ? divisor : 1);

    return {
      'focusedTotal': focusedTotal,
      'variance': variance,
      'burnRate': burnRate,
      'displayData': focusedMonthData,
    };
  }

  // --- MONTH PICKER UI ---
  void _changeMonth(int offset) {
    setState(() {
      _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset);
    });
  }

  // --- DATABASE OPERATIONS ---

  String _generateExpenseID() {
    return 'EP${(Random().nextInt(90000) + 10000)}';
  }

  Future<void> _saveExpense({Map<String, dynamic>? existingData}) async {
    if (_amountController.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      final data = {
        'userID': _currentUID,
        'category': _selectedCategory,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'note': _noteController.text.trim(),
      };
      if (existingData == null) {
        data['expenseID'] = _generateExpenseID();
        await _supabase.from('pet_expenses').insert(data);
      } else {
        await _supabase.from('pet_expenses').update(data).eq('expenseID', existingData['expenseID']);
      }
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        // --- MONTH FILTER IN APPBAR ---
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () => _changeMonth(-1),
            ),
            Text(
              DateFormat('MMM yyyy').format(_focusedMonth),
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () => _changeMonth(1),
            ),
          ],
        ),
        centerTitle: true,
        actions: [
          IconButton(
              icon: const Icon(Icons.settings_outlined),
              onPressed: _showBudgetSettings
          )
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _expenseStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final stats = _calculateAdvancedAnalytics(snapshot.data!);
          final List<Map<String, dynamic>> displayData = stats['displayData'];

          return SingleChildScrollView(
            child: Column(
              children: [
                _buildAnalyticsRow(stats['variance'], stats['burnRate']),
                _buildBudgetTracker(stats['focusedTotal']),
                if (displayData.isNotEmpty) ...[
                  _buildCategoryPieChart(displayData),
                  const Padding(
                    padding: EdgeInsets.fromLTRB(20, 10, 20, 5),
                    child: Align(
                        alignment: Alignment.centerLeft,
                        child: Text("History", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold))
                    ),
                  ),
                  ListView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    itemCount: displayData.length,
                    itemBuilder: (context, index) => _buildExpenseItem(displayData[index]),
                  ),
                ] else
                  Padding(
                    padding: const EdgeInsets.all(60),
                    child: Column(
                      children: [
                        Icon(Icons.receipt_long, size: 50, color: Colors.grey[300]),
                        const SizedBox(height: 10),
                        const Text("No expenses for this period", style: TextStyle(color: Colors.grey)),
                      ],
                    ),
                  ),
                const SizedBox(height: 100),
              ],
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _showExpenseForm(),
        backgroundColor: Colors.teal[800],
        icon: const Icon(Icons.add, color: Colors.white),
        label: const Text("Add Expense", style: TextStyle(color: Colors.white)),
      ),
    );
  }

  Widget _buildAnalyticsRow(double variance, double burnRate) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Row(
        children: [
          _analyticCard("Daily Burn", "RM ${burnRate.toStringAsFixed(2)}", Icons.speed, Colors.blue),
          const SizedBox(width: 12),
          _analyticCard(
              "MoM Variance",
              "${variance > 0 ? '+' : ''}${variance.toStringAsFixed(1)}%",
              Icons.trending_up,
              variance > 0 ? Colors.red : Colors.green
          ),
        ],
      ),
    );
  }

  Widget _analyticCard(String title, String value, IconData icon, Color color) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(15),
        decoration: BoxDecoration(
          color: color.withOpacity(0.05),
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: color.withOpacity(0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color, size: 20),
            const SizedBox(height: 8),
            Text(title, style: TextStyle(color: Colors.grey[600], fontSize: 12)),
            Text(value, style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: color)),
          ],
        ),
      ),
    );
  }

  Widget _buildBudgetTracker(double spent) {
    double budget = _currentMonthBudget;
    double progress = (spent / budget).clamp(0, 1);
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.grey[100],
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Budget Usage", style: TextStyle(fontWeight: FontWeight.w500)),
              Text("RM ${spent.toStringAsFixed(0)} / RM ${budget.toInt()}"),
            ],
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: progress,
            minHeight: 8,
            borderRadius: BorderRadius.circular(10),
            color: spent > budget ? Colors.red : Colors.teal,
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryPieChart(List<Map<String, dynamic>> data) {
    Map<String, double> categories = {};
    for (var e in data) {
      categories[e['category']] = (categories[e['category']] ?? 0) + (e['amount'] ?? 0);
    }
    return Container(
      height: 180,
      margin: const EdgeInsets.symmetric(vertical: 20),
      child: PieChart(
        PieChartData(
          sections: categories.entries.map((e) => PieChartSectionData(
            color: _getCategoryColor(e.key),
            value: e.value,
            radius: 40,
            title: '',
          )).toList(),
          centerSpaceRadius: 40,
        ),
      ),
    );
  }

  Widget _buildExpenseItem(Map<String, dynamic> item) {
    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Colors.grey[200]!),
      ),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(item['category']).withOpacity(0.1),
          child: Icon(_getCategoryIcon(item['category']), color: _getCategoryColor(item['category']), size: 20),
        ),
        title: Text(item['note']?.isEmpty ?? true ? item['category'] : item['note'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(item['date']),
        trailing: Text("RM ${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.black)),
        onTap: () => _showExpenseForm(existingData: item),
      ),
    );
  }

  void _showExpenseForm({Map<String, dynamic>? existingData}) {
    if (existingData != null) {
      _amountController.text = existingData['amount'].toString();
      _noteController.text = existingData['note'] ?? "";
      _selectedCategory = existingData['category'];
      _selectedDate = DateTime.parse(existingData['date']);
    } else {
      _amountController.clear();
      _noteController.clear();
      _selectedCategory = 'Pet Food';
      _selectedDate = DateTime.now();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Expense Record", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              // DATE PICKER
              ListTile(
                title: Text("Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}"),
                trailing: const Icon(Icons.edit_calendar, color: Colors.teal),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8), side: BorderSide(color: Colors.grey[300]!)),
                onTap: () async {
                  final picked = await showDatePicker(
                      context: context,
                      initialDate: _selectedDate,
                      firstDate: DateTime(2020),
                      lastDate: DateTime(2100)
                  );
                  if (picked != null) setModalState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 10),
              TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Amount (RM)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 10),
              DropdownButtonFormField(
                value: _selectedCategory,
                items: ['Pet Food', 'Pet Toy', 'Medical', 'Grooming', 'Others'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) => setModalState(() => _selectedCategory = v.toString()),
                decoration: const InputDecoration(border: OutlineInputBorder(), labelText: "Category"),
              ),
              const SizedBox(height: 10),
              TextField(controller: _noteController, decoration: const InputDecoration(labelText: "Notes", border: OutlineInputBorder())),
              const SizedBox(height: 20),
              _isSaving ? const CircularProgressIndicator() : ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.teal[800]),
                onPressed: () => _saveExpense(existingData: existingData),
                child: const Text("Save", style: TextStyle(color: Colors.white)),
              ),
              const SizedBox(height: 20),
            ],
          ),
        ),
      ),
    );
  }

  void _showBudgetSettings() {
    final controller = TextEditingController(text: _currentMonthBudget.toString());
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Set Budget"),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "RM")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          setState(() => _monthlyBudgets[DateFormat('yyyy-MM').format(_focusedMonth)] = double.tryParse(controller.text) ?? 1000.0);
          Navigator.pop(context);
        }, child: const Text("Set")),
      ],
    ));
  }

  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Pet Food': return Colors.blue;
      case 'Pet Toy': return Colors.orange;
      case 'Medical': return Colors.red;
      case 'Grooming': return Colors.purple;
      default: return Colors.blueGrey;
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Pet Food': return Icons.restaurant;
      case 'Pet Toy': return Icons.toys;
      case 'Medical': return Icons.medical_services;
      case 'Grooming': return Icons.content_cut;
      default: return Icons.payments;
    }
  }
}