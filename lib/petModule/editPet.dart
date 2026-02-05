import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EditPetPage extends StatefulWidget {
  final Map<String, dynamic> petData;

  const EditPetPage({super.key, required this.petData});

  @override
  State<EditPetPage> createState() => _EditPetPageState();
}

class _EditPetPageState extends State<EditPetPage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  late TextEditingController _name;
  late TextEditingController _species;
  late TextEditingController _breed;
  late TextEditingController _remarks;

  DateTime? _birthDate;
  File? _imageFile;
  String? _gender;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.petData['petName'] ?? '');
    _species = TextEditingController(text: widget.petData['species'] ?? '');
    _breed = TextEditingController(text: widget.petData['breed'] ?? '');
    _remarks = TextEditingController(text: widget.petData['remarks'] ?? '');
    _birthDate = DateTime.tryParse(widget.petData['birthDate'] ?? '');
    _gender = widget.petData['gender'] ?? null;
  }

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _remarks.dispose();
    super.dispose();
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

  // ================= PICK IMAGE =================
  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 70,
    );
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  // ================= UPLOAD IMAGE =================
  Future<String?> _uploadImage() async {
    if (_imageFile == null) return widget.petData['petPhoto'];

    try {
      final userId = supabase.auth.currentUser!.id;
      final fileName = '$userId/pet_${DateTime.now().millisecondsSinceEpoch}.jpg';

      await supabase.storage.from('pet_photos').upload(
        fileName,
        _imageFile!,
        fileOptions: const FileOptions(upsert: true),
      );

      return supabase.storage.from('pet_photos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload error: $e");
      return widget.petData['petPhoto'];
    }
  }

  // ================= UPDATE PET =================
  Future<void> _updatePet() async {
    if (_gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Please select a gender")),
      );
      return;
    }

    setState(() => _loading = true);
    try {
      final imageUrl = await _uploadImage();
      final userId = supabase.auth.currentUser!.id;

      await supabase
          .from('pet')
          .update({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
      })
          .eq('petID', widget.petData['petID'])
          .eq('userID', userId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Update failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= DELETE PET =================
  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Confirm Delete"),
        content: const Text("Are you sure you want to delete this pet? This action cannot be undone."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text("Cancel")),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text("Delete", style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;

      await supabase
          .from('pet')
          .delete()
          .eq('petID', widget.petData['petID'])
          .eq('userID', userId);

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text("Delete failed: $e")),
      );
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= UI =================
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet Profile'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            _buildAvatar(),
            const SizedBox(height: 30),

            TextField(controller: _name, decoration: _inputStyle('Pet Name', Icons.badge)),
            const SizedBox(height: 15),
            TextField(controller: _species, decoration: _inputStyle('Species', Icons.category)),
            const SizedBox(height: 15),
            TextField(controller: _breed, decoration: _inputStyle('Breed', Icons.pets)),
            const SizedBox(height: 15),

            // Gender Dropdown
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputStyle('Gender', Icons.wc),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
                DropdownMenuItem(value: 'Unknown', child: Text('Unknown')),
              ],
              onChanged: (value) {
                setState(() => _gender = value);
              },
            ),
            const SizedBox(height: 15),

            _buildDatePicker(),
            const SizedBox(height: 15),

            TextField(
              controller: _remarks,
              maxLines: 3,
              decoration: _inputStyle('Remarks', Icons.description),
            ),

            const SizedBox(height: 20),

            // Update button
            _loading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _updatePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                minimumSize: const Size(double.infinity, 55),
              ),
              child: const Text('UPDATE CHANGES'),
            ),

            const SizedBox(height: 15),

            // Delete button
            ElevatedButton(
              onPressed: _deletePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: Colors.red,
                minimumSize: const Size(double.infinity, 50),
              ),
              child: const Text('DELETE PET', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }

  // ================= WIDGETS =================
  Widget _buildAvatar() {
    return Stack(
      children: [
        ClipOval(
          child: SizedBox(
            width: 120,
            height: 120,
            child: _buildImageDisplay(),
          ),
        ),
        Positioned(
          bottom: 0,
          right: 0,
          child: GestureDetector(
            onTap: _pickImage,
            child: CircleAvatar(
              backgroundColor: themeColor,
              radius: 18,
              child: const Icon(Icons.camera_alt, color: Colors.white, size: 18),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildDatePicker() {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: _birthDate ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime.now(),
        );
        if (picked != null) setState(() => _birthDate = picked);
      },
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.grey[100],
          borderRadius: BorderRadius.circular(borderRadius),
        ),
        child: Row(
          children: [
            Icon(Icons.calendar_today, color: themeColor),
            const SizedBox(width: 12),
            Text(
              _birthDate == null
                  ? 'Select Birth Date'
                  : _birthDate!.toString().split(' ')[0],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildImageDisplay() {
    if (_imageFile != null) return Image.file(_imageFile!, fit: BoxFit.cover);

    if (widget.petData['petPhoto'] != null &&
        widget.petData['petPhoto'].toString().isNotEmpty) {
      return Image.network(widget.petData['petPhoto'], fit: BoxFit.cover);
    }

    return const Icon(Icons.pets, size: 60);
  }
}
