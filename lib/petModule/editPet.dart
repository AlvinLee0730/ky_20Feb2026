import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:newfypken/notification_service.dart';

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
  late TextEditingController _weight;

  DateTime? _birthDate;
  DateTime? _vaccinationExpiry;
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
    _weight = TextEditingController(text: widget.petData['weight']?.toString() ?? '');
    _birthDate = DateTime.tryParse(widget.petData['birthDate'] ?? '');
    _vaccinationExpiry = DateTime.tryParse(widget.petData['vaccinationExpiry'] ?? '');
    _gender = widget.petData['gender'];
  }

  @override
  void dispose() {
    _name.dispose();
    _species.dispose();
    _breed.dispose();
    _remarks.dispose();
    _weight.dispose();
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

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return widget.petData['petPhoto'];
    try {
      final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('pet_photos').upload(fileName, _imageFile!);
      return supabase.storage.from('pet_photos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload error: $e");
      return widget.petData['petPhoto'];
    }
  }

  Future<void> _updatePet() async {
    setState(() => _loading = true);
    try {
      final imageUrl = await _uploadImage();
      final userId = supabase.auth.currentUser!.id;
      final petID = widget.petData['petID'];

      await supabase.from('pet').update({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate?.toIso8601String(),
        'weight': double.tryParse(_weight.text) ?? 0.0,
        'vaccinationExpiry': _vaccinationExpiry?.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
      }).eq('petID', petID).eq('userID', userId);

      await NotificationService.cancelNotification(NotificationService.petVaccineNotificationId(petID));
      if (_vaccinationExpiry != null) {
        final reminderTime = DateTime(_vaccinationExpiry!.year, _vaccinationExpiry!.month, _vaccinationExpiry!.day, 9, 0);
        if (reminderTime.isAfter(DateTime.now())) {
          await NotificationService.scheduleNotification(
            id: NotificationService.petVaccineNotificationId(petID),
            title: 'Vaccination reminder: ${_name.text.trim()}',
            body: 'Vaccination due today. Remember to schedule the next dose.',
            scheduledTime: reminderTime,
          );
        }
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Update failed: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Pet?"),
        content: const Text("This will permanently remove this pet profile."),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        final petID = widget.petData['petID'];
        await NotificationService.cancelNotification(NotificationService.petVaccineNotificationId(petID));
        await supabase.from('pet').delete().eq('petID', petID);
        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint("Delete error: $e");
      } finally {
        if (mounted) setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet Profile'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        actions: [
          IconButton(icon: const Icon(Icons.delete_outline), onPressed: _deletePet),
        ],
      ),
      body: _loading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : (widget.petData['petPhoto'] != null ? NetworkImage(widget.petData['petPhoto']) : null) as ImageProvider?,
                child: (_imageFile == null && widget.petData['petPhoto'] == null)
                    ? Icon(Icons.add_a_photo, size: 40, color: themeColor)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: _name, decoration: _inputStyle('Pet Name', Icons.badge)),
            const SizedBox(height: 15),
            TextField(controller: _weight, keyboardType: TextInputType.number, decoration: _inputStyle('Weight (kg)', Icons.monitor_weight)),
            const SizedBox(height: 15),
            TextField(controller: _species, decoration: _inputStyle('Species', Icons.category)),
            const SizedBox(height: 15),
            TextField(controller: _breed, decoration: _inputStyle('Breed', Icons.pets)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputStyle('Gender', Icons.wc),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 15),
            _buildDatePicker("Birth Date", _birthDate, (date) => setState(() => _birthDate = date)),
            const SizedBox(height: 15),
            _buildDatePicker("Vaccination Expiry", _vaccinationExpiry, (date) => setState(() => _vaccinationExpiry = date), icon: Icons.vaccines),
            const SizedBox(height: 15),
            TextField(controller: _remarks, maxLines: 3, decoration: _inputStyle('Remarks', Icons.description)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updatePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: const Text('UPDATE CHANGES', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date, Function(DateTime) onPicked, {IconData icon = Icons.calendar_today}) {
    return InkWell(
      onTap: () async {
        final picked = await showDatePicker(
          context: context,
          initialDate: date ?? DateTime.now(),
          firstDate: DateTime(2000),
          lastDate: DateTime(2100),
        );
        if (picked != null) onPicked(picked);
      },
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
        decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(borderRadius)),
        child: Row(
          children: [
            Icon(icon, color: themeColor),
            const SizedBox(width: 12),
            Text(
              date == null ? 'Select $label' : DateFormat('yyyy-MM-dd').format(date),
              style: TextStyle(color: date == null ? Colors.grey[600] : Colors.black),
            ),
          ],
        ),
      ),
    );
  }
}