import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class AddFoodPage extends StatefulWidget {
  final List<Map<String, dynamic>> pets; // 从 Dashboard 传过来的宠物列表
  const AddFoodPage({super.key, required this.pets});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final _formKey = GlobalKey<FormState>();
  final supabase = Supabase.instance.client;

  // Controllers
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _brandController = TextEditingController();
  final TextEditingController _amountController = TextEditingController();
  final TextEditingController _remarksController = TextEditingController();
  final TextEditingController _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final TextEditingController _timeController = TextEditingController(text: DateFormat('HH:mm').format(DateTime.now()));

  String? _selectedPetID;
  String _selectedUnit = 'g';
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) {
      _selectedPetID = widget.pets[0]['petID'].toString();
    }
  }

  Future<void> _saveFood() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSaving = true);
    try {
      await supabase.from('food').insert({
        'petID': _selectedPetID,
        'foodName': _nameController.text,
        'brand': _brandController.text,
        'amount': double.tryParse(_amountController.text) ?? 0.0,
        'unit': _selectedUnit,
        'feedingDate': _dateController.text,
        'feedingTime': _timeController.text,
        'remarks': _remarksController.text,
      });
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      setState(() => _isSaving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Add Food Record"), backgroundColor: Colors.teal),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Form(
          key: _formKey,
          child: Column(
            children: [
              // 1. 选择宠物
              DropdownButtonFormField<String>(
                value: _selectedPetID,
                decoration: const InputDecoration(labelText: "Select Pet", border: OutlineInputBorder()),
                items: widget.pets.map((pet) {
                  return DropdownMenuItem(value: pet['petID'].toString(), child: Text(pet['petName']));
                }).toList(),
                onChanged: (val) => setState(() => _selectedPetID = val),
              ),
              const SizedBox(height: 15),

              // 2. 食物名称
              TextFormField(
                controller: _nameController,
                decoration: const InputDecoration(labelText: "Food Name (e.g. Kibbles)", border: OutlineInputBorder()),
                validator: (val) => val!.isEmpty ? "Enter food name" : null,
              ),
              const SizedBox(height: 15),

              // 3. 分量与单位
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
                      items: ['g', 'ml', 'cup', 'can'].map((u) => DropdownMenuItem(value: u, child: Text(u))).toList(),
                      onChanged: (val) => setState(() => _selectedUnit = val!),
                      decoration: const InputDecoration(border: OutlineInputBorder()),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 15),

              // 4. 日期选择
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
                onPressed: _isSaving ? null : _saveFood,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
                child: _isSaving ? const CircularProgressIndicator(color: Colors.white) : const Text("Save Record", style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}