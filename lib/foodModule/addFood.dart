import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddFoodPage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  const AddFoodPage({super.key, required this.pets});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // 1. 定义数据变量
  List<Map<String, dynamic>> _libraryItems = []; // 存储从 food_library 拿到的食物
  Map<String, dynamic>? _selectedLibraryItem;   // 当前选中的食物对象
  String? _selectedPetID;
  String _selectedUnit = 'g';
  bool _isSaving = false;
  bool _isLoadingLibrary = true;

  // Controllers
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final TextEditingController _timeController = TextEditingController(text: DateFormat('HH:mm').format(DateTime.now()));

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) {
      _selectedPetID = widget.pets[0]['petID'].toString();
    }
    _fetchFoodLibrary(); // 初始化时获取食物字典
  }

  // 2. 获取食物库数据
  Future<void> _fetchFoodLibrary() async {
    try {
      final response = await supabase.from('food_library').select();
      setState(() {
        _libraryItems = List<Map<String, dynamic>>.from(response);
        _isLoadingLibrary = false;
      });
    } catch (e) {
      debugPrint("Error fetching library: $e");
      setState(() => _isLoadingLibrary = false);
    }
  }

  // 3. 核心保存逻辑 (修复变量引用错误)
  Future<void> _saveFoodAndNutrition() async {
    if (!_formKey.currentState!.validate() || _selectedLibraryItem == null) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Please select a food and enter amount")));
      return;
    }

    setState(() => _isSaving = true);

    double amount = double.tryParse(_amountController.text) ?? 0.0;
    double ratio = amount / 100; // 因为库里是每 100g 的营养

    // 计算实际营养
    double cal = ((_selectedLibraryItem!['baseCalory'] ?? 0) as num).toDouble() * ratio;
    double pro = ((_selectedLibraryItem!['baseProtein'] ?? 0) as num).toDouble() * ratio;
    double fat = ((_selectedLibraryItem!['baseFat'] ?? 0) as num).toDouble() * ratio;
    double carbs = ((_selectedLibraryItem!['baseCarbs'] ?? 0) as num).toDouble() * ratio;
    double fiber = ((_selectedLibraryItem!['baseFiber'] ?? 0) as num).toDouble() * ratio;

    try {
      // 同时写入两个表
      await Future.wait([
        // 写入 Food 表
        supabase.from('food').insert({
          'petID': _selectedPetID,
          'foodName': _selectedLibraryItem!['itemName'],
          'brand': _selectedLibraryItem!['brand'],
          'amount': amount,
          'unit': _selectedUnit,
          'feedingDate': _dateController.text,
          'feedingTime': _timeController.text,
        }),
        // 写入 Nutrition 表
        supabase.from('nutrition').insert({
          'petID': _selectedPetID,
          'foodName': _selectedLibraryItem!['itemName'],
          'calory': cal,
          'protein': pro,
          'fat': fat,
          'carbs': carbs,
          'fiber': fiber,
          'date': _dateController.text,
          'nutritionTip': cal > 250 ? "High calorie portion" : "Normal portion",
        }),
      ]);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      debugPrint("Save error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Record Feeding"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: _isLoadingLibrary
          ? const Center(child: CircularProgressIndicator())
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 宠物选择
              DropdownButtonFormField<String>(
                value: _selectedPetID,
                decoration: const InputDecoration(labelText: "Select Pet", border: OutlineInputBorder()),
                items: widget.pets.map((pet) {
                  return DropdownMenuItem(value: pet['petID'].toString(), child: Text(pet['petName']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedPetID = val),
              ),
              const SizedBox(height: 15),

              // 食物库选择 (关键修复)
              DropdownButtonFormField<Map<String, dynamic>>(
                value: _selectedLibraryItem,
                decoration: const InputDecoration(labelText: "Select Food (from Library)", border: OutlineInputBorder()),
                items: _libraryItems.map((item) {
                  return DropdownMenuItem(
                    value: item,
                    child: Text("[${item['brand']}] ${item['itemName']}"),
                  );
                }).toList(),
                onChanged: (val) => setState(() => _selectedLibraryItem = val),
                validator: (val) => val == null ? "Please select food" : null,
              ),
              const SizedBox(height: 15),

              // 分量输入
              Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: TextFormField(
                      controller: _amountController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: "Amount", border: OutlineInputBorder()),
                      validator: (val) => val!.isEmpty ? "Enter amount" : null,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: DropdownButtonFormField<String>(
                      value: _selectedUnit,
                      items: ['g', 'ml', 'cup'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 日期
              TextFormField(
                controller: _dateController,
                readOnly: true,
                decoration: const InputDecoration(labelText: "Date", suffixIcon: Icon(Icons.calendar_today)),
                onTap: () async {
                  DateTime? picked = await showDatePicker(context: context, initialDate: DateTime.now(), firstDate: DateTime(2000), lastDate: DateTime(2100));
                  if (picked != null) _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                },
              ),
              const SizedBox(height: 25),

              ElevatedButton(
                onPressed: _isSaving ? null : _saveFoodAndNutrition,
                style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.teal,
                    minimumSize: const Size(double.infinity, 55),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))
                ),
                child: _isSaving
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text("Save Record & Calculate Nutrition", style: TextStyle(color: Colors.white, fontSize: 16)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}