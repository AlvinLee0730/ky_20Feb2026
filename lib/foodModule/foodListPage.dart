import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/foodModule/addFood.dart';
import 'package:newfypken/foodModule/editFood.dart';

class FoodListPage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  const FoodListPage({super.key, required this.pets});

  @override
  State<FoodListPage> createState() => _FoodListPageState();
}

class _FoodListPageState extends State<FoodListPage> {
  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _foodRecords = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _fetchFoodRecords();
  }

  Future<void> _fetchFoodRecords() async {
    setState(() => _isLoading = true);
    try {
      final List<String> petIds = widget.pets
          .map((p) => p['petID'].toString())
          .toList();

      if (petIds.isEmpty) {
        setState(() => _foodRecords = []);
        return;
      }
      final response = await supabase
          .from('food')
          .select()
          .inFilter('petID', petIds)
          .order('feedingDate', ascending: false);
      setState(() {
        _foodRecords = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Fetch error: $e");
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching food: $e"))
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Records"),
        backgroundColor: Colors.teal,
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
        itemCount: _foodRecords.length,
        itemBuilder: (context, index) {
          final record = _foodRecords[index];
          // 找回对应的宠物名字
          final pet = widget.pets.firstWhere((p) => p['petID'] == record['petID']);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.fastfood, color: Colors.orange),
              title: Text("${record['foodName']} (${record['amount']}${record['unit']})"),
              subtitle: Text("${pet['petName']} • ${record['feedingDate']} ${record['feedingTime']}"),
              trailing: const Icon(Icons.edit, size: 20),
              onTap: () async {
                // 跳转到 Edit 页面
                final result = await Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => EditFoodPage(foodData: record))
                );
                if (result == true) _fetchFoodRecords();
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add),
        onPressed: () async {
          // 跳转到 Add 页面
          final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddFoodPage(pets: widget.pets))
          );
          if (result == true) _fetchFoodRecords();
        },
      ),
    );
  }
}