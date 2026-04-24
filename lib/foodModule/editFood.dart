import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class EditFoodPage extends StatefulWidget {
  final Map<String, dynamic> foodData;
  // 预期 foodData 包含: foodID, petID, foodName, amount, unit, feedingDate, feedingTime, remarks 等
  const EditFoodPage({super.key, required this.foodData});

  @override
  State<EditFoodPage> createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>();

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _remarksController;
  late TextEditingController _dateController;
  late TextEditingController _timeController;

  String _selectedUnit = 'g';
  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    // 初始化所有字段
    _nameController = TextEditingController(text: widget.foodData['foodName'] ?? '');
    _amountController = TextEditingController(text: widget.foodData['amount']?.toString() ?? '');
    _remarksController = TextEditingController(text: widget.foodData['remarks'] ?? '');

    // 初始化日期和时间
    _dateController = TextEditingController(
        text: widget.foodData['feedingDate'] ?? DateFormat('yyyy-MM-dd').format(DateTime.now())
    );
    _timeController = TextEditingController(
        text: widget.foodData['feedingTime'] ?? DateFormat('HH:mm').format(DateTime.now())
    );

    // 初始化单位，如果没有默认为 'g'
    _selectedUnit = widget.foodData['unit'] ?? 'g';
    if (!['g', 'ml', 'cup'].contains(_selectedUnit)) {
      _selectedUnit = 'g';
    }
  }

  Future<void> _updateFoodAndNutrition() async {
    setState(() => _isUpdating = true);

    // 1. 安全计算比例，防止除以 0
    double oldAmount = double.tryParse(widget.foodData['amount']?.toString() ?? '1.0') ?? 1.0;
    if (oldAmount == 0) oldAmount = 1.0; // 边缘情况防护

    double newAmount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    double changeRatio = newAmount / oldAmount;

    try {
      // 2. 更新 food 表 (包含所有的修改项)
      await supabase.from('food').update({
        'amount': newAmount,
        'unit': _selectedUnit,
        'feedingDate': _dateController.text,
        'feedingTime': _timeController.text,
        'remarks': _remarksController.text.trim(),
      }).eq('foodID', widget.foodData['foodID']);

      // 3. 通过 foodID 精确查找并更新 nutrition 表 (避免同日同宠物同食物的干扰)
      final nutritionRecords = await supabase
          .from('nutrition')
          .select()
          .eq('foodID', widget.foodData['foodID']); // ⚠️ 依赖你的 nutrition 表有 foodID 字段

      if (nutritionRecords.isNotEmpty) {
        final String nID = nutritionRecords[0]['nutritionID'].toString();

        // 重新计算新的营养值
        await supabase.from('nutrition').update({
          'calory': (nutritionRecords[0]['calory'] as num) * changeRatio,
          'protein': (nutritionRecords[0]['protein'] as num) * changeRatio,
          'fat': (nutritionRecords[0]['fat'] as num) * changeRatio,
          'carbs': (nutritionRecords[0]['carbs'] as num) * changeRatio,
          'fiber': (nutritionRecords[0]['fiber'] as num) * changeRatio,
          'date': _dateController.text, // 同步更新营养表的日期
          'nutritionTip': "Updated based on new amount",
        }).eq('nutritionID', nID);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Record updated successfully!"), backgroundColor: Colors.teal),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Update error: $e");
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }

  Future<void> _deleteFoodAndNutrition() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("This will permanently remove this meal and its nutritional data."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold))
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isUpdating = true); // 借用 loading 状态防止重复点击
      try {
        // ⚠️ 通过唯一的 foodID 进行精准删除
        await supabase.from('food').delete().eq('foodID', widget.foodData['foodID']);
        await supabase.from('nutrition').delete().eq('foodID', widget.foodData['foodID']);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Record deleted."), backgroundColor: Colors.redAccent),
          );
          Navigator.pop(context, true);
        }
      } catch (e) {
        debugPrint("Delete error: $e");
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Delete failed: $e")));
      } finally {
        if (mounted) setState(() => _isUpdating = false);
      }
    }
  }

  // 辅助方法：提取通用输入框样式
  InputDecoration _inputStyle(String label) {
    return InputDecoration(
      labelText: label,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
      filled: true,
      fillColor: Colors.white,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Food Record"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            tooltip: 'Delete Record',
            onPressed: _isUpdating ? null : _deleteFoodAndNutrition,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. Food Name (只读)
                TextFormField(
                  controller: _nameController,
                  readOnly: true,
                  decoration: const InputDecoration(
                    labelText: "Food Name (Fixed)",
                    filled: true,
                    fillColor: Color(0xFFF5F5F5),
                    border: OutlineInputBorder(borderSide: BorderSide.none),
                    prefixIcon: Icon(Icons.restaurant, color: Colors.grey),
                  ),
                ),
                const SizedBox(height: 16),

                // 2. Amount 和 Unit (水平排列)
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        // 强制只能输入数字和小数点
                        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'(^\d*\.?\d*)'))],
                        decoration: _inputStyle("Amount").copyWith(hintText: "e.g. 85.5"),
                        validator: (value) {
                          if (value == null || value.trim().isEmpty) return 'Required';
                          final num? numValue = num.tryParse(value);
                          if (numValue == null || numValue <= 0) return 'Must be > 0';
                          return null;
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: _inputStyle("Unit"),
                        items: ['g', 'ml', 'cup']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedUnit = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 3. Date 和 Time (加回编辑页面)
                Row(
                  children: [
                    Expanded(
                      child: TextFormField(
                        controller: _dateController,
                        readOnly: true,
                        decoration: _inputStyle("Date").copyWith(
                          prefixIcon: const Icon(Icons.calendar_today, color: Colors.teal, size: 20),
                        ),
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.tryParse(_dateController.text) ?? DateTime.now(),
                            firstDate: DateTime(2000),
                            lastDate: DateTime.now(),
                          );
                          if (picked != null) {
                            setState(() {
                              _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                            });
                          }
                        },
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: TextFormField(
                        controller: _timeController,
                        readOnly: true,
                        decoration: _inputStyle("Time").copyWith(
                          prefixIcon: const Icon(Icons.access_time, color: Colors.teal, size: 20),
                        ),
                        onTap: () async {
                          // 解析现有的时间
                          final parts = _timeController.text.split(':');
                          TimeOfDay initialTime = TimeOfDay.now();
                          if (parts.length == 2) {
                            initialTime = TimeOfDay(hour: int.parse(parts[0]), minute: int.parse(parts[1]));
                          }

                          final picked = await showTimePicker(context: context, initialTime: initialTime);
                          if (picked != null) {
                            setState(() {
                              _timeController.text = "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                            });
                          }
                        },
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 4. Remarks
                TextFormField(
                  controller: _remarksController,
                  decoration: _inputStyle("Remarks (optional)"),
                  maxLines: 3,
                ),

                const SizedBox(height: 32),

                // 5. Submit Button
                ElevatedButton(
                  onPressed: _isUpdating
                      ? null
                      : () {
                    if (_formKey.currentState!.validate()) {
                      _updateFoodAndNutrition();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text("Please fix the errors above.")),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                  ),
                  child: _isUpdating
                      ? const SizedBox(
                    height: 24,
                    width: 24,
                    child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2.5),
                  )
                      : const Text("UPDATE RECORD", style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _nameController.dispose();
    _amountController.dispose();
    _remarksController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    super.dispose();
  }
}