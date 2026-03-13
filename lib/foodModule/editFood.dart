import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditFoodPage extends StatefulWidget {
  final Map<String, dynamic> foodData; // 包含 petID, foodName, amount, feedingDate 等
  const EditFoodPage({super.key, required this.foodData});

  @override
  State<EditFoodPage> createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final supabase = Supabase.instance.client;
  final _formKey = GlobalKey<FormState>(); // 新增 FormKey

  // Controllers
  late TextEditingController _nameController;
  late TextEditingController _amountController;
  late TextEditingController _remarksController;

  bool _isUpdating = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.foodData['foodName']);
    _amountController = TextEditingController(text: widget.foodData['amount'].toString());
    _remarksController = TextEditingController(text: widget.foodData['remarks'] ?? '');
  }

  // ================= 核心：同步更新 Food 和 Nutrition =================
  Future<void> _updateFoodAndNutrition() async {
    setState(() => _isUpdating = true);

    double oldAmount = double.tryParse(widget.foodData['amount'].toString()) ?? 1.0;
    double newAmount = double.tryParse(_amountController.text) ?? 0.0;

    // 计算比例变化，用于更新 Nutrition 数据
    // 逻辑：新营养 = 旧营养 * (新分量 / 旧分量)
    double changeRatio = newAmount / oldAmount;

    try {
      // 1. 更新 Food 表记录
      await supabase.from('food').update({
        'amount': newAmount,
        'remarks': _remarksController.text,
      }).eq('foodID', widget.foodData['foodID']);

      // 2. 更新 Nutrition 表记录
      // 我们需要先找出对应的营养记录。由于你没有存 nutritionID，
      // 我们用 petID + foodName + date (精确到天) 来匹配。
      final nutritionRecords = await supabase
          .from('nutrition')
          .select()
          .eq('petID', widget.foodData['petID'])
          .eq('foodName', widget.foodData['foodName'])
          .eq('date', widget.foodData['feedingDate']);

      if (nutritionRecords.isNotEmpty) {
        // 假设每次喂食对应一条营养记录，取第一条
        final String nID = nutritionRecords[0]['nutritionID'];

        await supabase.from('nutrition').update({
          'calory': (nutritionRecords[0]['calory'] as num) * changeRatio,
          'protein': (nutritionRecords[0]['protein'] as num) * changeRatio,
          'fat': (nutritionRecords[0]['fat'] as num) * changeRatio,
          'carbs': (nutritionRecords[0]['carbs'] as num) * changeRatio,
          'fiber': (nutritionRecords[0]['fiber'] as num) * changeRatio,
          'nutritionTip': "Updated based on new amount",
        }).eq('nutritionID', nID);
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Update error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      if (mounted) setState(() => _isUpdating = false);
    }
  }



  Future<void> _deleteFoodAndNutrition() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("This will also remove the nutritional data for this meal."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text("Delete", style: TextStyle(color: Colors.red))
          ),
        ],
      ),
    );

    if (confirm == true) {
      try {
        await supabase.from('food').delete().eq('foodID', widget.foodData['foodID']);
        await supabase.from('nutrition').delete()
            .eq('petID', widget.foodData['petID'])
            .eq('foodName', widget.foodData['foodName'])
            .eq('date', widget.foodData['feedingDate']);

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint("Delete error: $e");
      }
    }
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
            onPressed: _deleteFoodAndNutrition,
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // Food Name - read only
              TextFormField(
                controller: _nameController,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: "Food Name (Fixed)",
                  filled: true,
                  fillColor: Color(0xFFF5F5F5),
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 15),

              // Amount - with validation
              TextFormField(
                controller: _amountController,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: "Amount (g/ml)",
                  border: OutlineInputBorder(),
                  hintText: "e.g. 85 or 120.5",
                ),
                validator: (value) {
                  if (value == null || value.trim().isEmpty) {
                    return 'Please enter amount';
                  }
                  final num? numValue = num.tryParse(value);
                  if (numValue == null) {
                    return 'Please enter a valid number';
                  }
                  if (numValue <= 0) {
                    return 'Amount must be greater than 0';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 15),

              // Remarks - no validation, optional
              TextFormField(
                controller: _remarksController,
                decoration: const InputDecoration(
                  labelText: "Remarks (optional)",
                  border: OutlineInputBorder(),
                ),
                maxLines: 3,
              ),

              const Spacer(),

              ElevatedButton(
                onPressed: _isUpdating
                    ? null
                    : () {
                  if (_formKey.currentState!.validate()) {
                    _updateFoodAndNutrition();
                  } else {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text("Please fix the errors in the form"),
                      ),
                    );
                  }
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.teal,
                  minimumSize: const Size(double.infinity, 55),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                child: _isUpdating
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text(
                  "Update Record",
                  style: TextStyle(color: Colors.white, fontSize: 16),
                ),
              ),
            ],
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
    super.dispose();
  }
}