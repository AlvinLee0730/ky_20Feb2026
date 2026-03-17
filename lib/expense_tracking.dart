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
  final _amountController = TextEditingController();
  final _noteController = TextEditingController();

  // 新增：用于自定义分类的控制器和状态
  final _customCategoryController = TextEditingController();
  bool _isCustomCategory = false;

  String _selectedCategory = 'Pet Food';
  DateTime _selectedDate = DateTime.now();
  DateTime _focusedMonth = DateTime(DateTime.now().year, DateTime.now().month);
  DateTime? _selectedDay;
  bool _isSaving = false;

  // 用于列表过滤的当前选中分类
  String _filterCategory = 'All';

  final Map<String, double> _monthlyBudgets = {};
  final double _defaultBudget = 1000.0;

  String get _currentUID => _supabase.auth.currentUser!.id;

  Stream<List<Map<String, dynamic>>> get _expenseStream => _supabase
      .from('pet_expenses')
      .stream(primaryKey: ['expenseID'])
      .eq('userID', _currentUID)
      .order('date', ascending: false);

  double get _currentMonthBudget {
    String key = DateFormat('yyyy-MM').format(_focusedMonth);
    return _monthlyBudgets[key] ?? _defaultBudget;
  }

  // 专属的错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.teal)),
          )
        ],
      ),
    );
  }

  // 为每个分类固定一个颜色，用于饼图和图标
  Color _getCategoryColor(String cat) {
    switch (cat) {
      case 'Pet Food': return Colors.teal;
      case 'Medical': return Colors.redAccent;
      case 'Pet Toy': return Colors.orange;
      case 'Grooming': return Colors.purpleAccent;
      case 'Others': return Colors.blueGrey;
      default: return Colors.grey; // 自定义分类默认使用灰色
    }
  }

  IconData _getCategoryIcon(String cat) {
    switch (cat) {
      case 'Pet Food': return Icons.restaurant;
      case 'Pet Toy': return Icons.toys;
      case 'Medical': return Icons.medical_services;
      case 'Grooming': return Icons.content_cut;
      default: return Icons.payments; // 自定义分类默认使用支付图标
    }
  }

  // --- 高级数据分析逻辑 ---
  Map<String, dynamic> _calculateAdvancedAnalytics(List<Map<String, dynamic>> allData) {
    // 1. 日期过滤：判断是看全月还是看某一天
    final dateFilteredData = allData.where((e) {
      DateTime d = DateTime.parse(e['date']);
      if (_selectedDay != null) {
        return d.year == _selectedDay!.year && d.month == _selectedDay!.month && d.day == _selectedDay!.day;
      }
      return d.year == _focusedMonth.year && d.month == _focusedMonth.month;
    }).toList();

    double focusedTotal = 0;
    double essentialTotal = 0; // 刚需：食物、医疗
    double lifestyleTotal = 0; // 弹性：玩具、美容、其他
    Map<String, double> categoryTotals = {}; // 记录每个分类的总花费

    // 提取所有出现过的分类，加上默认的几个选项，确保新创建的分类也会出现在筛选栏里
    Set<String> dynamicFilters = {'All', 'Pet Food', 'Pet Toy', 'Medical', 'Grooming', 'Others'};

    for (var e in dateFilteredData) {
      String cat = e['category'] ?? 'Others';
      double amt = (e['amount'] ?? 0).toDouble();

      dynamicFilters.add(cat);

      focusedTotal += amt;
      categoryTotals[cat] = (categoryTotals[cat] ?? 0) + amt;

      if (cat == 'Pet Food' || cat == 'Medical') {
        essentialTotal += amt;
      } else {
        lifestyleTotal += amt;
      }
    }

    // 2. 分类过滤（仅针对下方的列表显示起效，不影响饼图）
    final displayData = dateFilteredData.where((e) {
      if (_filterCategory == 'All') return true;
      return e['category'] == _filterCategory;
    }).toList();

    return {
      'focusedTotal': focusedTotal,
      'essentialTotal': essentialTotal,
      'lifestyleTotal': lifestyleTotal,
      'categoryTotals': categoryTotals,
      'displayData': displayData,
      'filterOptions': dynamicFilters.toList(), // 传出动态分类列表
    };
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
        title: InkWell(
          onTap: _pickViewDate,
          child: Column(
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(_selectedDay == null
                      ? DateFormat('MMM yyyy').format(_focusedMonth)
                      : DateFormat('yyyy-MM-dd').format(_selectedDay!),
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                  const Icon(Icons.arrow_drop_down),
                ],
              ),
              Text(_selectedDay == null ? "Monthly View" : "Daily View",
                  style: TextStyle(fontSize: 10, color: Colors.teal[700], fontWeight: FontWeight.bold)),
            ],
          ),
        ),
        centerTitle: true,
        leading: IconButton(icon: const Icon(Icons.chevron_left), onPressed: () => _changeMonth(-1)),
        actions: [
          IconButton(icon: const Icon(Icons.chevron_right), onPressed: () => _changeMonth(1)),
          IconButton(icon: const Icon(Icons.settings_outlined), onPressed: _showBudgetSettings),
        ],
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _expenseStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final stats = _calculateAdvancedAnalytics(snapshot.data!);

          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_selectedDay != null)
                  Center(
                    child: Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: InputChip(
                        label: const Text("Return to Month View"),
                        onPressed: () => setState(() => _selectedDay = null),
                        onDeleted: () => setState(() => _selectedDay = null),
                      ),
                    ),
                  ),

                // 1. Needs vs Wants 分析卡片
                _buildAnalysisCard(stats['essentialTotal'], stats['lifestyleTotal']),

                // 2. 消费占比饼图与具体分类金额
                _buildPieChartAndLegend(stats['categoryTotals'], stats['focusedTotal']),

                // 3. 预算进度条
                _buildBudgetTracker(stats['focusedTotal']),

                // 4. 分类过滤器与消费历史
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 25, 20, 10),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(_selectedDay == null ? "Monthly Records" : "Daily Records",
                          style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                      Text("${stats['displayData'].length} items", style: TextStyle(color: Colors.grey[500], fontSize: 12)),
                    ],
                  ),
                ),

                // 横向滚动的 Category Filter (传入动态分类)
                _buildCategoryFilter(stats['filterOptions']),

                stats['displayData'].isEmpty
                    ? const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: Text("No expenses found for this category.", style: TextStyle(color: Colors.grey))),
                )
                    : ListView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: stats['displayData'].length,
                  itemBuilder: (context, index) => _buildExpenseItem(stats['displayData'][index]),
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
        label: const Text("Add Record", style: TextStyle(color: Colors.white)),
        icon: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  // --- UI 组件: 分析卡片 ---
  Widget _buildAnalysisCard(double essential, double lifestyle) {
    return Container(
      margin: const EdgeInsets.all(16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
          color: Colors.teal[900],
          borderRadius: BorderRadius.circular(24),
          boxShadow: [BoxShadow(color: Colors.teal.withOpacity(0.3), blurRadius: 10, offset: const Offset(0, 5))]
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              _statItem("Essential", "RM ${essential.toStringAsFixed(2)}", Colors.tealAccent),
              Container(width: 1, height: 40, color: Colors.white24),
              _statItem("Lifestyle", "RM ${lifestyle.toStringAsFixed(2)}", Colors.orangeAccent),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: Colors.white.withOpacity(0.1), borderRadius: BorderRadius.circular(12)),
            child: Row(
              children: [
                const Icon(Icons.auto_awesome, color: Colors.orangeAccent, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    lifestyle > 0
                        ? "Saving Hint: Reducing lifestyle costs could save you RM ${lifestyle.toStringAsFixed(0)} this month."
                        : "Awesome! You've only spent on essential needs.",
                    style: const TextStyle(color: Colors.white, fontSize: 12),
                  ),
                ),
              ],
            ),
          )
        ],
      ),
    );
  }

  Widget _statItem(String label, String value, Color color) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: Colors.white70, fontSize: 12)),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(color: color, fontSize: 18, fontWeight: FontWeight.bold)),
      ],
    );
  }

  // --- UI 组件: 饼图及分类详情图例 (Category Breakdown) ---
  Widget _buildPieChartAndLegend(Map<String, double> categoryTotals, double totalSpent) {
    if (totalSpent == 0) {
      return const Padding(
        padding: EdgeInsets.symmetric(vertical: 20),
        child: Center(child: Text("No expenses recorded yet.", style: TextStyle(color: Colors.grey))),
      );
    }

    List<PieChartSectionData> pieSections = [];
    categoryTotals.forEach((cat, amount) {
      if (amount > 0) {
        final double percentage = (amount / totalSpent) * 100;
        pieSections.add(PieChartSectionData(
          color: _getCategoryColor(cat),
          value: amount,
          title: '${percentage.toStringAsFixed(1)}%',
          radius: 60,
          titleStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white),
        ));
      }
    });

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 5),
          child: Text("Expense Breakdown", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        ),
        const SizedBox(height: 15),
        SizedBox(
          height: 200,
          child: PieChart(
            PieChartData(
              sections: pieSections,
              centerSpaceRadius: 40,
              sectionsSpace: 2,
            ),
          ),
        ),
        const SizedBox(height: 20),
        // 分类详情 (展示每个Category花了多少钱)
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: categoryTotals.entries.map((e) {
              final cat = e.key;
              final amount = e.value;
              final pct = (amount / totalSpent) * 100;
              return Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.grey.shade300),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircleAvatar(backgroundColor: _getCategoryColor(cat), radius: 6),
                    const SizedBox(width: 8),
                    Text('$cat: RM ${amount.toStringAsFixed(2)} ', style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold)),
                    Text('(${pct.toStringAsFixed(1)}%)', style: TextStyle(fontSize: 12, color: Colors.grey.shade600)),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
        const SizedBox(height: 10),
      ],
    );
  }

  // --- UI 组件: 预算 ---
  Widget _buildBudgetTracker(double spent) {
    double budget = _currentMonthBudget;
    double progress = (spent / budget).clamp(0, 1);
    return Container(
      margin: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(color: Colors.grey[50], borderRadius: BorderRadius.circular(20), border: Border.all(color: Colors.grey[200]!)),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text("Monthly Budget Usage", style: TextStyle(fontWeight: FontWeight.w600)),
              Text("RM ${spent.toStringAsFixed(0)} / ${budget.toInt()}"),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progress,
              minHeight: 8,
              backgroundColor: Colors.grey[200],
              color: spent > budget ? Colors.redAccent : Colors.teal,
            ),
          ),
        ],
      ),
    );
  }

  // --- UI 组件: 分类过滤条 ---
  Widget _buildCategoryFilter(List<String> filterOptions) {
    return Container(
      height: 50,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: filterOptions.length,
        itemBuilder: (context, index) {
          final cat = filterOptions[index];
          final isSelected = _filterCategory == cat;
          return Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(cat),
              selected: isSelected,
              selectedColor: Colors.teal,
              labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
              onSelected: (selected) {
                if (selected) setState(() => _filterCategory = cat);
              },
            ),
          );
        },
      ),
    );
  }

  // --- 列表项 ---
  Widget _buildExpenseItem(Map<String, dynamic> item) {
    bool isEssential = item['category'] == 'Pet Food' || item['category'] == 'Medical';
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 5),
      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey[100]!)),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: _getCategoryColor(item['category']).withOpacity(0.15),
          child: Icon(_getCategoryIcon(item['category']), color: _getCategoryColor(item['category']), size: 20),
        ),
        title: Text(item['note']?.isEmpty ?? true ? item['category'] : item['note'], style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text("${item['date']} • ${isEssential ? 'Essential' : 'Lifestyle'}"),
        trailing: Text("RM ${item['amount']}", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
        onTap: () => _showExpenseForm(existingData: item),
      ),
    );
  }

  // --- 功能方法 ---
  Future<void> _pickViewDate() async {
    final picked = await showDatePicker(context: context, initialDate: _selectedDay ?? _focusedMonth, firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (picked != null) setState(() { _selectedDay = picked; _focusedMonth = DateTime(picked.year, picked.month); });
  }

  void _changeMonth(int offset) {
    setState(() { _selectedDay = null; _focusedMonth = DateTime(_focusedMonth.year, _focusedMonth.month + offset); });
  }

  void _showBudgetSettings() {
    final controller = TextEditingController(text: _currentMonthBudget.toString());
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Set Monthly Budget"),
      content: TextField(controller: controller, keyboardType: TextInputType.number, decoration: const InputDecoration(suffixText: "RM")),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(onPressed: () {
          setState(() => _monthlyBudgets[DateFormat('yyyy-MM').format(_focusedMonth)] = double.tryParse(controller.text) ?? 1000.0);
          Navigator.pop(context);
        }, child: const Text("Save")),
      ],
    ));
  }

  void _showExpenseForm({Map<String, dynamic>? existingData}) {
    List<String> dropdownItems = ['Pet Food', 'Pet Toy', 'Medical', 'Grooming', 'Others', 'Add Custom...'];

    if (existingData != null) {
      _amountController.text = existingData['amount'].toString();
      _noteController.text = existingData['note'] ?? "";
      _selectedDate = DateTime.parse(existingData['date']);

      String cat = existingData['category'];
      // 如果已存在的数据是一个自定义分类，把它加到下拉菜单选项里，防止报错
      if (!dropdownItems.contains(cat)) {
        dropdownItems.insert(0, cat);
      }
      _selectedCategory = cat;
      _isCustomCategory = false;
      _customCategoryController.clear();
    } else {
      _amountController.clear();
      _noteController.clear();
      _selectedCategory = 'Pet Food';
      _selectedDate = _selectedDay ?? DateTime.now();
      _isCustomCategory = false;
      _customCategoryController.clear();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("Record Expense", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 20),
              ListTile(
                tileColor: Colors.grey[100],
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                title: Text("Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}"),
                trailing: const Icon(Icons.calendar_month),
                onTap: () async {
                  final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2020), lastDate: DateTime(2100));
                  if (picked != null) setModalState(() => _selectedDate = picked);
                },
              ),
              const SizedBox(height: 15),
              TextField(controller: _amountController, decoration: const InputDecoration(labelText: "Amount (RM)", border: OutlineInputBorder()), keyboardType: TextInputType.number),
              const SizedBox(height: 15),

              DropdownButtonFormField<String>(
                value: _selectedCategory,
                items: dropdownItems.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                onChanged: (v) {
                  setModalState(() {
                    _selectedCategory = v.toString();
                    _isCustomCategory = _selectedCategory == 'Add Custom...';
                  });
                },
                decoration: const InputDecoration(labelText: "Category", border: OutlineInputBorder()),
              ),

              // 当选择了 'Add Custom...' 时显示自定义输入框
              if (_isCustomCategory) ...[
                const SizedBox(height: 15),
                TextField(
                  controller: _customCategoryController,
                  decoration: const InputDecoration(labelText: "Custom Category Name", border: OutlineInputBorder()),
                  textCapitalization: TextCapitalization.words,
                ),
              ],

              const SizedBox(height: 15),
              TextField(controller: _noteController, decoration: const InputDecoration(labelText: "Note (Optional)", border: OutlineInputBorder())),
              const SizedBox(height: 25),
              _isSaving ? const CircularProgressIndicator() : ElevatedButton(
                style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 55), backgroundColor: Colors.teal[800], shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15))),
                onPressed: () => _saveExpense(existingData: existingData),
                child: const Text("Save Record", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
              const SizedBox(height: 30),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _saveExpense({Map<String, dynamic>? existingData}) async {
    // 1. 验证：金额是否为空
    if (_amountController.text.trim().isEmpty) {
      _showErrorDialog('Please enter the expense amount!');
      return;
    }

    // 2. 验证：金额是否为有效数字
    final parsedAmount = double.tryParse(_amountController.text.trim());
    if (parsedAmount == null || parsedAmount <= 0) {
      _showErrorDialog('Please enter a valid amount greater than 0!');
      return;
    }

    // 3. 处理最终要保存的 Category
    String finalCategory = _selectedCategory;
    if (_isCustomCategory) {
      if (_customCategoryController.text.trim().isEmpty) {
        _showErrorDialog('Please enter a custom category name!');
        return;
      }
      finalCategory = _customCategoryController.text.trim();
    }

    setState(() => _isSaving = true);
    try {
      final data = {
        'userID': _currentUID,
        'category': finalCategory, // 使用最终决定的分类
        'amount': parsedAmount,
        'date': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'note': _noteController.text.trim(),
      };

      if (existingData == null) {
        data['expenseID'] = 'EP${Random().nextInt(90000) + 10000}';
        await _supabase.from('pet_expenses').insert(data);
      } else {
        await _supabase.from('pet_expenses').update(data).eq('expenseID', existingData['expenseID']);
      }

      if (mounted) Navigator.pop(context); // 成功后关闭弹窗
    } catch (e) {
      // 捕捉错误并弹出提示框
      _showErrorDialog('Error saving record: $e');
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }
}