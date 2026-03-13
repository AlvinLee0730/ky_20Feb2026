import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'package:newfypken/notification_service.dart';

final supabase = Supabase.instance.client;

class CreatePetPage extends StatefulWidget {
  const CreatePetPage({super.key});

  @override
  State<CreatePetPage> createState() => _CreatePetPageState();
}

class _CreatePetPageState extends State<CreatePetPage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  final _name = TextEditingController();
  final _species = TextEditingController();
  final _breed = TextEditingController();
  final _weight = TextEditingController();
  final _remarks = TextEditingController();

  DateTime? _birthDate;
  DateTime? _vaccinationExpiry;

  File? _imageFile;
  bool _loading = false;
  String? _gender;

  bool get _nameHasError       => _name.text.trim().isEmpty;
  bool get _birthDateHasError  => _birthDate == null;
  bool get _genderHasError     => _gender == null;

  bool get _weightIsInvalid {
    if (_weight.text.trim().isEmpty) return false; // optional
    final value = double.tryParse(_weight.text.trim());
    return value == null || value < 0;
  }

  String? get _weightErrorText {
    if (_weight.text.trim().isEmpty) return null;
    final value = double.tryParse(_weight.text.trim());
    if (value == null) return 'please Enter Valid Number';
    if (value < 0)     return 'Cannot be negative';
    return null;
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
    );
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<void> _savePet() async {
    // Required fields
    if (_nameHasError || _birthDateHasError || _genderHasError) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Pet name, gender, and birth date are required."),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // Optional but format-sensitive fields
    if (_weightIsInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text("Weight must be a valid non-negative number."),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = supabase.auth.currentUser!.id;
      String? imageUrl;

      if (_imageFile != null) {
        final fileName = 'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';
        await supabase.storage.from('pet_photos').upload(fileName, _imageFile!);
        imageUrl = supabase.storage.from('pet_photos').getPublicUrl(fileName);
      }

      final insertResponse = await supabase.from('pet').insert({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate!.toIso8601String(),
        'weight': double.tryParse(_weight.text.trim()) ?? 0.0,
        'vaccinationExpiry': _vaccinationExpiry?.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
        'userID': userId,
      }).select('petID');

      final petID = insertResponse.isNotEmpty
          ? insertResponse.first['petID'] as String?
          : null;

      if (petID != null && _vaccinationExpiry != null) {
        await NotificationService.scheduleVaccineReminder(
          petId: petID,
          petName: _name.text.trim(),
          expiryDate: _vaccinationExpiry!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error saving pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to save: ${e.toString().split('\n').first}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Add New Pet'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage: _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null ? Icon(Icons.add_a_photo, size: 40, color: themeColor) : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _name,
              decoration: _inputStyle('Pet Name', Icons.badge).copyWith(
                errorText: _nameHasError ? 'Please enter pet name' : null,
              ),
            ),

            TextField(
              controller: _weight,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              decoration: _inputStyle('Weight (kg)', Icons.monitor_weight_outlined).copyWith(
                errorText: _weightErrorText,
              ),
            ),
            const SizedBox(height: 15),
            TextField(controller: _species, decoration: _inputStyle('Species', Icons.category)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputStyle('Gender', Icons.wc).copyWith(
                errorText: _genderHasError ? 'Please select gender' : null,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 15),
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
              leading: Icon(Icons.calendar_today, color: themeColor),
              title: Text(_birthDate == null ? 'Select Birth Date' : DateFormat('yyyy-MM-dd').format(_birthDate!)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now(),
                  firstDate: DateTime(2000),
                  lastDate: DateTime.now(),
                );
                if (picked != null) setState(() => _birthDate = picked);
              },
            ),
            const SizedBox(height: 15),
            ListTile(
              tileColor: Colors.teal[50],
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
              leading: Icon(Icons.vaccines, color: themeColor),
              title: Text(
                  _vaccinationExpiry == null
                      ? 'Last Vaccination Expiry Date'
                      : 'Expiry: ${DateFormat('yyyy-MM-dd').format(_vaccinationExpiry!)}'
              ),
              subtitle: const Text("Optional: For reminder purposes", style: TextStyle(fontSize: 11)),
              onTap: () async {
                final picked = await showDatePicker(
                  context: context,
                  initialDate: DateTime.now().add(const Duration(days: 365)),
                  firstDate: DateTime.now().subtract(const Duration(days: 365)),
                  lastDate: DateTime(2100),
                );
                if (picked != null) setState(() => _vaccinationExpiry = picked);
              },
            ),
            const SizedBox(height: 15),
            TextField(controller: _remarks, maxLines: 2, decoration: _inputStyle('Remarks', Icons.description)),
            const SizedBox(height: 40),
            _loading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _savePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: const Text('SAVE PET', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}