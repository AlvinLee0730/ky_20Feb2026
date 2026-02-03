import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class LostAndFoundPage extends StatefulWidget {
  const LostAndFoundPage({super.key});

  @override
  State<LostAndFoundPage> createState() => _LostAndFoundPageState();
}

class _LostAndFoundPageState extends State<LostAndFoundPage> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _nameController = TextEditingController();
  final _breedController = TextEditingController();
  final _locationController = TextEditingController();
  final _descriptionController = TextEditingController();
  final _contactInfoController = TextEditingController();
  final _searchController = TextEditingController();

  // Sorting and Filter States
  bool _isAscending = false;
  String _searchQuery = "";
  String _filterType = 'All';
  String _filterBreed = 'All';
  String _filterLocation = 'All';

  // Dynamic Filter Lists
  List<String> _availableBreeds = ['All'];
  List<String> _availableLocations = ['All'];

  // Form State
  String _selectedType = 'Lost';
  String _selectedGender = 'Male';
  String _contactMethod = 'Phone';
  DateTime _selectedDate = DateTime.now();
  File? _imageFile;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _loadFilters();
  }

  // --- LOGIC: LOAD DYNAMIC FILTER OPTIONS ---
  Future<void> _loadFilters() async {
    try {
      final response = await _supabase.from('lost_pets').select('breed, location');
      final Set<String> breeds = {'All'};
      final Set<String> locations = {'All'};

      for (var row in response) {
        if (row['breed'] != null && row['breed'].toString().isNotEmpty) {
          breeds.add(row['breed']);
        }
        if (row['location'] != null && row['location'].toString().isNotEmpty) {
          locations.add(row['location']);
        }
      }

      setState(() {
        _availableBreeds = breeds.toList();
        _availableLocations = locations.toList();
      });
    } catch (e) {
      debugPrint("Filter load error: $e");
    }
  }

  void _clearAllFilters() {
    setState(() {
      _filterType = 'All';
      _filterBreed = 'All';
      _filterLocation = 'All';
      _searchQuery = "";
      _searchController.clear();
    });
  }

  Stream<List<Map<String, dynamic>>> get _petStream => _supabase
      .from('lost_pets')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: _isAscending);

  // --- LOGIC: DELETE ---
  Future<void> _deletePost(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Post?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );
    if (confirm == true) {
      await _supabase.from('lost_pets').delete().eq('id', id);
      _loadFilters();
    }
  }

  // --- LOGIC: SAVE ---
  Future<void> _savePost({int? existingId, String? existingImageUrl}) async {
    if (_nameController.text.trim().isEmpty || _locationController.text.trim().isEmpty) return;

    setState(() => _isSaving = true);
    try {
      String? imageUrl = existingImageUrl;
      if (_imageFile != null) {
        final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await _supabase.storage.from('pet_images').upload(fileName, _imageFile!);
        imageUrl = _supabase.storage.from('pet_images').getPublicUrl(fileName);
      }

      final data = {
        'type': _selectedType,
        'name': _nameController.text.trim(),
        'location': _locationController.text.trim(),
        'description': _descriptionController.text.trim(),
        'gender': _selectedGender,
        'breed': _breedController.text.trim(),
        'date_lost': DateFormat('yyyy-MM-dd').format(_selectedDate),
        'contact_method': _contactMethod,
        'contact_info': _contactInfoController.text.trim(),
        'image_url': imageUrl,
      };

      if (existingId == null) {
        await _supabase.from('lost_pets').insert(data);
      } else {
        await _supabase.from('lost_pets').update(data).eq('id', existingId);
      }

      _loadFilters();
      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  // --- FORM UI ---
  void _showPostForm({Map<String, dynamic>? post}) {
    if (post != null) {
      _nameController.text = post['name'] ?? '';
      _locationController.text = post['location'] ?? '';
      _descriptionController.text = post['description'] ?? '';
      _breedController.text = post['breed'] ?? '';
      _contactInfoController.text = post['contact_info'] ?? '';
      _selectedType = post['type'] ?? 'Lost';
      _selectedGender = post['gender'] ?? 'Male';
      _contactMethod = post['contact_method'] ?? 'Phone';
      _selectedDate = DateTime.parse(post['date_lost'] ?? DateTime.now().toIso8601String());
    } else {
      _nameController.clear(); _locationController.clear(); _descriptionController.clear();
      _breedController.clear(); _contactInfoController.clear();
      _imageFile = null; _selectedDate = DateTime.now();
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(post == null ? "Report a Pet" : "Edit Report", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                InkWell(
                  onTap: () async {
                    final pickedFile = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 50);
                    if (pickedFile != null) setModalState(() => _imageFile = File(pickedFile.path));
                  },
                  child: Container(
                    height: 120, width: double.infinity,
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                    child: _imageFile != null
                        ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.file(_imageFile!, fit: BoxFit.cover))
                        : (post?['image_url'] != null ? ClipRRect(borderRadius: BorderRadius.circular(15), child: Image.network(post!['image_url'], fit: BoxFit.cover)) : const Icon(Icons.add_a_photo, color: Colors.orange)),
                  ),
                ),
                DropdownButtonFormField(
                  value: _selectedType,
                  decoration: const InputDecoration(labelText: "Report Type"),
                  items: ['Lost', 'Found'].map((t) => DropdownMenuItem(value: t, child: Text(t))).toList(),
                  onChanged: (val) => setModalState(() => _selectedType = val!),
                ),
                TextField(controller: _nameController, decoration: const InputDecoration(labelText: "Pet Name")),
                TextField(controller: _breedController, decoration: const InputDecoration(labelText: "Breed")),
                DropdownButtonFormField(
                  value: _selectedGender,
                  decoration: const InputDecoration(labelText: "Gender"),
                  items: ['Male', 'Female', 'Unknown'].map((g) => DropdownMenuItem(value: g, child: Text(g))).toList(),
                  onChanged: (val) => setModalState(() => _selectedGender = val!),
                ),
                TextField(controller: _locationController, decoration: const InputDecoration(labelText: "Location")),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text("Date: ${DateFormat('yyyy-MM-dd').format(_selectedDate)}"),
                  trailing: const Icon(Icons.calendar_month),
                  onTap: () async {
                    final picked = await showDatePicker(context: context, initialDate: _selectedDate, firstDate: DateTime(2022), lastDate: DateTime.now());
                    if (picked != null) setModalState(() => _selectedDate = picked);
                  },
                ),
                TextField(controller: _contactInfoController, decoration: const InputDecoration(labelText: "Contact Detail (Phone/Email)")),
                TextField(controller: _descriptionController, maxLines: 2, decoration: const InputDecoration(labelText: "Description")),
                const SizedBox(height: 20),
                _isSaving ? const CircularProgressIndicator() : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.orange, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                  onPressed: () => _savePost(existingId: post?['id'], existingImageUrl: post?['image_url']),
                  child: Text(post == null ? "POST REPORT" : "UPDATE REPORT"),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    bool hasFilters = _filterType != 'All' || _filterBreed != 'All' || _filterLocation != 'All' || _searchQuery.isNotEmpty;

    return Scaffold(
      appBar: AppBar(
        title: const Text("Lost & Found"),
        actions: [
          if (hasFilters) IconButton(icon: const Icon(Icons.refresh), onPressed: _clearAllFilters),
          IconButton(
            icon: Icon(_isAscending ? Icons.arrow_upward : Icons.arrow_downward),
            onPressed: () => setState(() => _isAscending = !_isAscending),
          ),
        ],
      ),
      body: Column(
        children: [
          // 1. SEARCH BAR
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search name...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),

          // 2. RESTORED FILTERS ROW
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                Expanded(child: _buildDropdownFilter("Type", _filterType, ['All', 'Lost', 'Found'], (val) => setState(() => _filterType = val!))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdownFilter("Breed", _filterBreed, _availableBreeds, (val) => setState(() => _filterBreed = val!))),
                const SizedBox(width: 8),
                Expanded(child: _buildDropdownFilter("Loc", _filterLocation, _availableLocations, (val) => setState(() => _filterLocation = val!))),
              ],
            ),
          ),
          const Divider(),

          // 3. GRID VIEW
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _petStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filtered = snapshot.data!.where((p) {
                  final name = (p['name'] ?? '').toString().toLowerCase();
                  bool matchesSearch = name.contains(_searchQuery);
                  bool matchesType = _filterType == 'All' || p['type'] == _filterType;
                  bool matchesBreed = _filterBreed == 'All' || p['breed'] == _filterBreed;
                  bool matchesLoc = _filterLocation == 'All' || p['location'] == _filterLocation;
                  return matchesSearch && matchesType && matchesBreed && matchesLoc;
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 0.75,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final post = filtered[index];
                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => LostPetDetail(post: post))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  post['image_url'] != null
                                      ? Image.network(post['image_url'], width: double.infinity, height: double.infinity, fit: BoxFit.cover)
                                      : Container(color: Colors.orange[50], width: double.infinity, child: const Icon(Icons.pets, size: 40)),
                                  Positioned(
                                    top: 5, right: 5,
                                    child: Row(
                                      children: [
                                        _smallActionBtn(Icons.edit, Colors.blue, () => _showPostForm(post: post)),
                                        const SizedBox(width: 4),
                                        _smallActionBtn(Icons.delete, Colors.red, () => _deletePost(post['id'])),
                                      ],
                                    ),
                                  ),
                                  Positioned(
                                    bottom: 5, left: 5,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(color: post['type'] == 'Lost' ? Colors.red : Colors.green, borderRadius: BorderRadius.circular(4)),
                                      child: Text(post['type'] ?? 'Lost', style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                                    ),
                                  )
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(post['name'] ?? 'Unknown', style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1),
                                  Text(post['location'] ?? 'Unknown location', style: const TextStyle(fontSize: 12, color: Colors.grey), maxLines: 1),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showPostForm(),
        backgroundColor: Colors.orange,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _smallActionBtn(IconData icon, Color color, VoidCallback onPressed) {
    return GestureDetector(
      onTap: onPressed,
      child: Container(
        height: 28, width: 28,
        decoration: BoxDecoration(color: Colors.white.withOpacity(0.9), shape: BoxShape.circle),
        child: Icon(icon, size: 16, color: color),
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.grey)),
        DropdownButton<String>(
          value: items.contains(value) ? value : 'All',
          isExpanded: true,
          underline: Container(height: 1, color: Colors.orange),
          onChanged: onChanged,
          items: items.map((i) => DropdownMenuItem(value: i, child: Text(i, style: const TextStyle(fontSize: 12)))).toList(),
        ),
      ],
    );
  }
}

// --- DETAIL PAGE ---
class LostPetDetail extends StatelessWidget {
  final Map<String, dynamic> post;
  const LostPetDetail({super.key, required this.post});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(post['name'] ?? "Details")),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (post['image_url'] != null) Image.network(post['image_url'], width: double.infinity, height: 300, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(post['name'] ?? "Unknown Pet", style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                      Chip(label: Text(post['type'] ?? 'Lost'), backgroundColor: post['type'] == 'Lost' ? Colors.red[100] : Colors.green[100]),
                    ],
                  ),
                  const Divider(),
                  _detailRow(Icons.pets, "Breed", post['breed']),
                  _detailRow(Icons.transgender, "Gender", post['gender']),
                  _detailRow(Icons.location_on, "Location", post['location']),
                  _detailRow(Icons.calendar_today, "Date", post['date_lost']),
                  _detailRow(Icons.contact_phone, "Contact", post['contact_info']),
                  const SizedBox(height: 20),
                  const Text("Description", style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(post['description'] ?? "No additional description."),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _detailRow(IconData icon, String label, String? value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(icon, size: 20, color: Colors.orange),
          const SizedBox(width: 10),
          Text("$label: ", style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value ?? "N/A"),
        ],
      ),
    );
  }
}