import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/foodModule/addFood.dart';
import 'package:newfypken/foodModule/editFood.dart';
import 'package:newfypken/foodModule/nutritionPage.dart'; // 假設你有這個

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
        setState(() {
          _foodRecords = [];
          _isLoading = false;
        });
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Error fetching records: $e")),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _formatDate(String? dateStr) {
    if (dateStr == null || dateStr.isEmpty) return 'Unknown date';
    try {
      final date = DateTime.parse(dateStr);
      final months = [
        'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
        'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
      ];
      return "${date.day} ${months[date.month - 1]} ${date.year}";
    } catch (e) {
      return dateStr;
    }
  }

  void _showPetSelector() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Container(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                "View Nutrition Analysis for:",
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 15),
              ...widget.pets.map((pet) => ListTile(
                leading: const Icon(Icons.pets, color: Colors.teal),
                title: Text(pet['petName']),
                onTap: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NutritionPage(petData: pet),
                    ),
                  );
                },
              )),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Records"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.analytics_outlined),
            onPressed: widget.pets.isEmpty ? null : _showPetSelector,
            tooltip: widget.pets.isEmpty ? "No pets available" : "Nutrition Analysis",
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : widget.pets.isEmpty
          ? _buildNoPetsState()
          : _foodRecords.isEmpty
          ? _buildEmptyState()
          : RefreshIndicator(
        onRefresh: _fetchFoodRecords,
        child: ListView.builder(
          itemCount: _foodRecords.length,
          itemBuilder: (context, index) {
            final record = _foodRecords[index];
            final pet = widget.pets.firstWhere(
                  (p) => p['petID'] == record['petID'],
              orElse: () => {'petName': 'Unknown Pet'},
            );

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
              child: ListTile(
                leading: const Icon(Icons.fastfood, color: Colors.orange),
                title: Text("${record['foodName']} (${record['amount']}${record['unit']})"),
                subtitle: Text("${pet['petName']} • ${_formatDate(record['feedingDate'])}"),
                trailing: IconButton(
                  icon: const Icon(Icons.edit, size: 20),
                  onPressed: () async {
                    final result = await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => EditFoodPage(foodData: record),
                      ),
                    );
                    if (result == true && mounted) {
                      _fetchFoodRecords();
                    }
                  },
                ),
                onTap: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => NutritionPage(petData: pet),
                    ),
                  );
                },
              ),
            );
          },
        ),
      ),
      floatingActionButton: widget.pets.isEmpty
          ? null
          : FloatingActionButton(
        backgroundColor: Colors.teal,
        child: const Icon(Icons.add, color: Colors.white),
        onPressed: () async {
          final result = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => AddFoodPage(pets: widget.pets)),
          );
          if (result == true && mounted) {
            _fetchFoodRecords();
          }
        },
      ),
    );
  }

  Widget _buildNoPetsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.pets_outlined, size: 80, color: Colors.grey),
          const SizedBox(height: 16),
          const Text(
            "No pets added yet",
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          const Text(
            "Add a pet first to start recording meals",
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey),
          ),
          const SizedBox(height: 24),

          ElevatedButton.icon(
            icon: const Icon(Icons.add),
             label: const Text("Add Pet"),
             onPressed: () {
             // Navigator.push(... AddPetPage ...)
             },
           ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Text(
        "No feeding records found.\nTap + to add one.",
        textAlign: TextAlign.center,
        style: TextStyle(fontSize: 16, color: Colors.grey),
      ),
    );
  }
}