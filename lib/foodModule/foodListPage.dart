import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/foodModule/addFood.dart';
import 'package:newfypken/foodModule/editFood.dart';
// 1. 记得导入你的 nutritionPage
import 'package:newfypken/foodModule/nutritionPage.dart';

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
        foregroundColor: Colors.white,
        // 2. 在 AppBar 增加一个前往 Nutrition 的入口（全局视角）
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: () {
              // 如果有多只宠物，这里可以弹出一个对话框让用户选看哪一只的营养
              _showPetSelector();
            },
          )
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _foodRecords.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
        itemCount: _foodRecords.length,
        itemBuilder: (context, index) {
          final record = _foodRecords[index];
          final pet = widget.pets.firstWhere((p) => p['petID'] == record['petID']);

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
            child: ListTile(
              leading: const Icon(Icons.fastfood, color: Colors.orange),
              title: Text("${record['foodName']} (${record['amount']}${record['unit']})"),
              subtitle: Text("${pet['petName']} • ${record['feedingDate']}"),
              // 3. 修改点击逻辑：点击 ListTile 进入 Nutrition，点击图标进入 Edit
              trailing: IconButton(
                icon: const Icon(Icons.edit, size: 20),
                onPressed: () async {
                  final result = await Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => EditFoodPage(foodData: record))
                  );
                  if (result == true) _fetchFoodRecords();
                },
              ),
              onTap: () {
                // 点击整条记录直接去看这只宠物的营养分析
                Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => NutritionPage(petData: pet))
                );
              },
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
              context,
              MaterialPageRoute(builder: (_) => AddFoodPage(pets: widget.pets))
          );
          if (result == true) _fetchFoodRecords();
        },
      ),
    );
  }

  // 4. 一个简单的宠物选择器，用于从 AppBar 直接进入 Nutrition
  void _showPetSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text("View Nutrition Analysis for:", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 15),
              ...widget.pets.map((pet) => ListTile(
                leading: const Icon(Icons.pets, color: Colors.teal),
                title: Text(pet['petName']),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(context, MaterialPageRoute(builder: (_) => NutritionPage(petData: pet)));
                },
              )).toList(),
            ],
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return const Center(child: Text("No feeding records found. Tap + to add."));
  }
}