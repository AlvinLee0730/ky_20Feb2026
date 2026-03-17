import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

final supabase = Supabase.instance.client;

class AddFoodPage extends StatefulWidget {
  final List<Map<String, dynamic>> pets;
  const AddFoodPage({super.key, required this.pets});

  @override
  State<AddFoodPage> createState() => _AddFoodPageState();
}

class _AddFoodPageState extends State<AddFoodPage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  String _selectedMode = 'record';

  // Record Feeding
  List<Map<String, dynamic>> _libraryItems = [];
  Map<String, dynamic>? _selectedLibraryItem;
  String? _selectedPetID;
  String _selectedUnit = 'g';

  final _amountController = TextEditingController();
  final _dateController = TextEditingController(text: DateFormat('yyyy-MM-dd').format(DateTime.now()));
  final _timeController = TextEditingController(text: DateFormat('HH:mm').format(DateTime.now()));

  // Add New Food
  final _brandController = TextEditingController();
  final _nameController = TextEditingController();
  final _calController = TextEditingController();
  final _proController = TextEditingController();
  final _fatController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fiberController = TextEditingController();

  bool _isLoadingLibrary = true;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    if (widget.pets.isNotEmpty) {
      _selectedPetID = widget.pets[0]['petID'].toString();
    }
    _fetchFoodLibrary();
  }

  @override
  void dispose() {
    _amountController.dispose();
    _dateController.dispose();
    _timeController.dispose();
    _brandController.dispose();
    _nameController.dispose();
    _calController.dispose();
    _proController.dispose();
    _fatController.dispose();
    _carbsController.dispose();
    _fiberController.dispose();
    super.dispose();
  }

  Future<void> _fetchFoodLibrary() async {
    setState(() => _isLoadingLibrary = true);
    try {
      final userID = supabase.auth.currentUser!.id;

      final res = await supabase
          .from('food_library')
          .select()
          .or('userID.eq.$userID,userID.is.null')
          .order('itemName', ascending: true);

      setState(() => _libraryItems = List.from(res));
      debugPrint("Loaded ${_libraryItems.length} foods");
    } catch (e) {
      debugPrint("Fetch library error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Failed to load food library")),
        );
      }
    } finally {
      setState(() => _isLoadingLibrary = false);
    }
  }

  // ====================== 保存喂食记录 ======================
  Future<void> _saveFoodRecord() async {
    if (_selectedPetID == null || _selectedLibraryItem == null || _amountController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select pet, food and amount")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
      final ratio = amount / 100;
      final item = _selectedLibraryItem!;

      await Future.wait([
        supabase.from('food').insert({
          'petID': _selectedPetID,
          'foodName': item['itemName'],
          'brand': item['brand'] ?? '',
          'amount': amount,
          'unit': _selectedUnit,
          'feedingDate': _dateController.text,
          'feedingTime': _timeController.text,
        }),
        supabase.from('nutrition').insert({
          'petID': _selectedPetID,
          'foodName': item['itemName'],
          'calory': (item['baseCalory'] ?? 0) * ratio,
          'protein': (item['baseProtein'] ?? 0) * ratio,
          'fat': (item['baseFat'] ?? 0) * ratio,
          'carbs': (item['baseCarbs'] ?? 0) * ratio,
          'fiber': (item['baseFiber'] ?? 0) * ratio,
          'date': _dateController.text,
          'nutritionTip': (item['baseCalory'] ?? 0) * ratio > 250 ? "High calorie portion" : "Normal portion",
        }),
      ]);

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("Feeding record saved successfully!"), backgroundColor: Colors.teal),
        );
        Navigator.pop(context, true);
      }
    } catch (e) {
      debugPrint("Save error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  Future<void> _saveToLibrary() async {
    if (_nameController.text.trim().isEmpty || _calController.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Food name and calories required")),
      );
      return;
    }

    setState(() => _isSaving = true);
    try {
      await supabase.from('food_library').insert({
        'brand': _brandController.text.trim(),
        'itemName': _nameController.text.trim(),
        'baseCalory': double.tryParse(_calController.text.trim()) ?? 0,
        'baseProtein': double.tryParse(_proController.text.trim()) ?? 0,
        'baseFat': double.tryParse(_fatController.text.trim()) ?? 0,
        'baseCarbs': double.tryParse(_carbsController.text.trim()) ?? 0,
        'baseFiber': double.tryParse(_fiberController.text.trim()) ?? 0,
        'userID': supabase.auth.currentUser!.id,
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text("New food added to library!"), backgroundColor: Colors.teal),
        );
        _clearLibraryForm();
        setState(() => _selectedMode = 'record');
        _fetchFoodLibrary();
      }
    } catch (e) {
      debugPrint("Library save error: $e");
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Failed to save: $e")));
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _clearLibraryForm() {
    _brandController.clear();
    _nameController.clear();
    _calController.clear();
    _proController.clear();
    _fatController.clear();
    _carbsController.clear();
    _fiberController.clear();
  }

  InputDecoration _inputStyle(String label, {IconData? icon}) {
    return InputDecoration(
      labelText: label,
      prefixIcon: icon != null ? Icon(icon, color: themeColor, size: 22) : null,
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
      contentPadding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add Food'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              DropdownButtonFormField<String>(
                value: _selectedMode,
                decoration: _inputStyle('What do you want to do?', icon: Icons.task_alt),
                items: const [
                  DropdownMenuItem(value: 'record', child: Text("Record Feeding")),
                  DropdownMenuItem(value: 'library', child: Text("Add New Food to Library")),
                ],
                onChanged: (val) => setState(() => _selectedMode = val!),
              ),
              const SizedBox(height: 20),

              if (_selectedMode == 'record') ...[
                DropdownButtonFormField<String>(
                  value: _selectedPetID,
                  decoration: _inputStyle('Select Pet', icon: Icons.pets),
                  items: widget.pets
                      .map((pet) => DropdownMenuItem(
                    value: pet['petID'].toString(),
                    child: Text(pet['petName']),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedPetID = val),
                ),
                const SizedBox(height: 12),

                DropdownButtonFormField<Map<String, dynamic>>(
                  value: _selectedLibraryItem,
                  isExpanded: true,
                  hint: const Text("Choose a food from library"),
                  decoration: _inputStyle('Select Food', icon: Icons.restaurant),
                  items: _libraryItems
                      .map((item) => DropdownMenuItem(
                    value: item,
                    child: Text("[${item['brand'] ?? 'General'}] ${item['itemName']}"),
                  ))
                      .toList(),
                  onChanged: (val) => setState(() => _selectedLibraryItem = val),
                ),
                const SizedBox(height: 16),

                Row(
                  children: [
                    Expanded(
                      flex: 2,
                      child: TextFormField(
                        controller: _amountController,
                        keyboardType: const TextInputType.numberWithOptions(decimal: true),
                        decoration: _inputStyle('Amount', icon: Icons.scale),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: DropdownButtonFormField<String>(
                        value: _selectedUnit,
                        decoration: _inputStyle('Unit'),
                        items: ['g', 'ml', 'cup']
                            .map((u) => DropdownMenuItem(value: u, child: Text(u)))
                            .toList(),
                        onChanged: (val) => setState(() => _selectedUnit = val!),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // 日期和时间横排（已加上日期验证）
                Row(
                  children: [
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showDatePicker(
                            context: context,
                            initialDate: DateTime.now(),
                            firstDate: DateTime(2000),           // 最早可选择2000年
                            lastDate: DateTime.now(),            // 只能选今天或以前
                          );
                          if (picked != null) {
                            _dateController.text = DateFormat('yyyy-MM-dd').format(picked);
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.calendar_today, color: themeColor, size: 22),
                              const SizedBox(width: 12),
                              Text(_dateController.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final picked = await showTimePicker(context: context, initialTime: TimeOfDay.now());
                          if (picked != null) {
                            _timeController.text =
                            "${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}";
                            setState(() {});
                          }
                        },
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey[100],
                            borderRadius: BorderRadius.circular(borderRadius),
                          ),
                          child: Row(
                            children: [
                              Icon(Icons.access_time, color: themeColor, size: 22),
                              const SizedBox(width: 12),
                              Text(_timeController.text),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),

                const SizedBox(height: 32),

                _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : ElevatedButton(
                  onPressed: _saveFoodRecord,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                  ),
                  child: const Text('SAVE FEEDING RECORD', style: TextStyle(fontWeight: FontWeight.bold)),
                ),
              ]

              else ...[
                TextFormField(controller: _brandController, decoration: _inputStyle("Brand", icon: Icons.branding_watermark)),
                const SizedBox(height: 12),
                TextFormField(controller: _nameController, decoration: _inputStyle("Food Name *", icon: Icons.restaurant)),
                const SizedBox(height: 20),

                const Text("Nutrition per 100g", style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextFormField(controller: _calController, keyboardType: TextInputType.number, decoration: _inputStyle("Calories", icon: Icons.local_fire_department)),
                const SizedBox(height: 12),
                TextFormField(controller: _proController, keyboardType: TextInputType.number, decoration: _inputStyle("Protein (g)", icon: Icons.fitness_center)),
                const SizedBox(height: 12),
                TextFormField(controller: _fatController, keyboardType: TextInputType.number, decoration: _inputStyle("Fat (g)", icon: Icons.opacity)),
                const SizedBox(height: 12),
                TextFormField(controller: _carbsController, keyboardType: TextInputType.number, decoration: _inputStyle("Carbs (g)", icon: Icons.grain)),
                const SizedBox(height: 12),
                TextFormField(controller: _fiberController, keyboardType: TextInputType.number, decoration: _inputStyle("Fiber (g)", icon: Icons.eco)),

                const SizedBox(height: 32),

                _isSaving
                    ? const Center(child: CircularProgressIndicator(color: Colors.teal))
                    : ElevatedButton(
                  onPressed: _saveToLibrary,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: themeColor,
                    foregroundColor: Colors.white,
                    minimumSize: const Size(double.infinity, 54),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                  ),
                  child: const Text('ADD TO FOOD LIBRARY', style: TextStyle(fontWeight: FontWeight.bold)),
                ),

                const SizedBox(height: 12),
                TextButton(
                  onPressed: () => setState(() => _selectedMode = 'record'),
                  child: const Text("← Back to Record Feeding"),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}