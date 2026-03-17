import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class FoodLibraryPage extends StatefulWidget {
  const FoodLibraryPage({super.key});

  @override
  State<FoodLibraryPage> createState() => _FoodLibraryPageState();
}

class _FoodLibraryPageState extends State<FoodLibraryPage> with SingleTickerProviderStateMixin {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  final supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _libraryItems = [];
  bool _isLoading = true;

  late TabController _tabController;

  // 编辑模式
  Map<String, dynamic>? _editingFood;

  // 表单控制器
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _calController = TextEditingController();
  final _proController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fiberController = TextEditingController();

  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchLibraryItems();

    _tabController.addListener(() {
      if (_tabController.index == 0 && _editingFood != null) {
        _cancelEdit(); // 切换到列表页时自动取消编辑
      }
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    _brandController.dispose();
    _nameController.dispose();
    _calController.dispose();
    _proController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _fiberController.dispose();
    super.dispose();
  }

  Future<void> _fetchLibraryItems() async {
    setState(() => _isLoading = true);
    try {
      final userID = supabase.auth.currentUser!.id;
      final res = await supabase
          .from('food_library')
          .select()
          .or('userID.eq.$userID,userID.is.null')
          .order('itemName', ascending: true);

      setState(() => _libraryItems = List<Map<String, dynamic>>.from(res));
    } catch (e) {
      debugPrint("Fetch error: $e");
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  void _startEdit(Map<String, dynamic> food) {
    setState(() {
      _editingFood = food;
      _brandController.text = food['brand'] ?? '';
      _nameController.text = food['itemName'] ?? '';
      _calController.text = (food['baseCalory'] ?? 0).toString();
      _proController.text = (food['baseProtein'] ?? 0).toString();
      _fatController.text = (food['baseFat'] ?? 0).toString();
      _carbsController.text = (food['baseCarbs'] ?? 0).toString();
      _fiberController.text = (food['baseFiber'] ?? 0).toString();
      _tabController.animateTo(1); // 自动切换到编辑页
    });
  }

  void _cancelEdit() {
    setState(() {
      _editingFood = null;
      _clearForm();
    });
  }

  void _clearForm() {
    _brandController.clear();
    _nameController.clear();
    _calController.clear();
    _proController.clear();
    _fatController.clear();
    _carbsController.clear();
    _fiberController.clear();
  }

  Future<void> _saveFood() async {
    if (_nameController.text.trim().isEmpty || _calController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food name and calories are required")),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final data = {
        'brand': _brandController.text.trim(),
        'itemName': _nameController.text.trim(),
        'baseCalory': double.tryParse(_calController.text.trim()) ?? 0,
        'baseProtein': double.tryParse(_proController.text.trim()) ?? 0,
        'baseFat': double.tryParse(_fatController.text.trim()) ?? 0,
        'baseCarbs': double.tryParse(_carbsController.text.trim()) ?? 0,
        'baseFiber': double.tryParse(_fiberController.text.trim()) ?? 0,
      };

      if (_editingFood != null) {
        await supabase
            .from('food_library')
            .update(data)
            .eq('libraryID', _editingFood!['libraryID'])
            .eq('userID', supabase.auth.currentUser!.id);
      } else {
        await supabase.from('food_library').insert({
          ...data,
          'userID': supabase.auth.currentUser!.id,
        });
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_editingFood != null ? "Updated successfully!" : "Added successfully!"),
          backgroundColor: Colors.teal,
        ),
      );

      _cancelEdit();
      _tabController.animateTo(0);
      _fetchLibraryItems();
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Failed: $e"), backgroundColor: Colors.redAccent),
      );
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  InputDecoration _inputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = supabase.auth.currentUser!.id;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Food Library"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: "All Foods"),
            Tab(text: "Add / Edit"),
          ],
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white70,
          indicatorColor: Colors.white,
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          // ==================== Tab 1: 食物列表 ====================
          _isLoading
              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
              : RefreshIndicator(
            onRefresh: _fetchLibraryItems,
            child: _libraryItems.isEmpty
                ? const Center(child: Text("No food yet"))
                : ListView.builder(
              padding: const EdgeInsets.all(12),
              itemCount: _libraryItems.length,
              itemBuilder: (context, index) {
                final food = _libraryItems[index];
                final isOwnFood = food['userID'] == currentUserId;

                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 6),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  child: ListTile(
                    leading: const Icon(Icons.restaurant, color: Colors.orange),
                    title: Text("[${food['brand'] ?? 'General'}] ${food['itemName']}"),
                    subtitle: food['userID'] == null
                        ? const Text("Admin Food", style: TextStyle(color: Colors.grey, fontSize: 12))
                        : null,
                    trailing: isOwnFood
                        ? IconButton(
                      icon: const Icon(Icons.edit, color: Colors.teal),
                      onPressed: () => _startEdit(food),
                    )
                        : null,
                  ),
                );
              },
            ),
          ),

          // ==================== Tab 2: 新增 / 编辑表单 ====================
          SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Card(
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _editingFood == null ? "Add New Food" : "Edit Food",
                      style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 24),

                    TextFormField(controller: _brandController, decoration: _inputStyle("Brand", Icons.branding_watermark)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _nameController, decoration: _inputStyle("Food Name *", Icons.restaurant)),
                    const SizedBox(height: 20),

                    const Text("Nutrition Information (per 100g)", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _calController, keyboardType: TextInputType.number, decoration: _inputStyle("Calories", Icons.local_fire_department)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _proController, keyboardType: TextInputType.number, decoration: _inputStyle("Protein (g)", Icons.fitness_center)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _fatController, keyboardType: TextInputType.number, decoration: _inputStyle("Fat (g)", Icons.opacity)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _carbsController, keyboardType: TextInputType.number, decoration: _inputStyle("Carbs (g)", Icons.grain)),
                    const SizedBox(height: 12),
                    TextFormField(controller: _fiberController, keyboardType: TextInputType.number, decoration: _inputStyle("Fiber (g)", Icons.eco)),

                    const SizedBox(height: 40),
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton(
                            onPressed: _cancelEdit,
                            child: const Text("Cancel"),
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: _isSaving
                              ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                              : ElevatedButton(
                            onPressed: _saveFood,
                            style: ElevatedButton.styleFrom(
                              backgroundColor: themeColor,
                              foregroundColor: Colors.white,
                              minimumSize: const Size(double.infinity, 50),
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                            ),
                            child: Text(_editingFood == null ? "ADD TO LIBRARY" : "UPDATE FOOD"),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}