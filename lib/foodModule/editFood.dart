import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class EditFoodPage extends StatefulWidget {
  final Map<String, dynamic> foodData; // 点击的那条记录数据
  const EditFoodPage({super.key, required this.foodData});

  @override
  State<EditFoodPage> createState() => _EditFoodPageState();
}

class _EditFoodPageState extends State<EditFoodPage> {
  final supabase = Supabase.instance.client;
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

  Future<void> _updateFood() async {
    setState(() => _isUpdating = true);
    await supabase.from('food').update({
      'foodName': _nameController.text,
      'amount': double.tryParse(_amountController.text) ?? 0.0,
      'remarks': _remarksController.text,
    }).eq('foodID', widget.foodData['foodID']);

    if (mounted) Navigator.pop(context, true);
  }

  Future<void> _deleteFood() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Record?"),
        content: const Text("Are you sure you want to delete this food record?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await supabase.from('food').delete().eq('foodID', widget.foodData['foodID']);
      if (mounted) Navigator.pop(context, true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Edit Food Record"),
        backgroundColor: Colors.teal,
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deleteFood),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Food Name")),
            const SizedBox(height: 15),
            TextField(controller: _amountController, keyboardType: TextInputType.number, decoration: const InputDecoration(labelText: "Amount")),
            const SizedBox(height: 15),
            TextField(controller: _remarksController, decoration: const InputDecoration(labelText: "Remarks"), maxLines: 3),
            const Spacer(),
            ElevatedButton(
              onPressed: _isUpdating ? null : _updateFood,
              style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, minimumSize: const Size(double.infinity, 50)),
              child: const Text("Update Record", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}