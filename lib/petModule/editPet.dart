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

  bool get _nameHasError =>
      _name.text
          .trim()
          .isEmpty;

  bool get _genderHasError => _gender == null;

  bool get _birthDateHasError => _birthDate == null;

  bool get _birthDateInFuture =>
      _birthDate != null && _birthDate!.isAfter(DateTime.now());

  bool get _weightIsInvalid {
    if (_weight.text
        .trim()
        .isEmpty) return false; // optional field
    final value = double.tryParse(_weight.text.trim());
    return value == null || value < 0;
  }

  String? get _weightErrorText {
    if (_weight.text
        .trim()
        .isEmpty) return null;
    final value = double.tryParse(_weight.text.trim());
    if (value == null) return 'Please enter a valid number';
    if (value < 0) return 'Weight cannot be negative';
    return null;
  }

  String? get _birthDateErrorText {
    if (_birthDate == null) return 'Birth date is required';
    if (_birthDateInFuture) return 'Birth date cannot be in the future';
    return null;
  }

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.petData['petName'] ?? '');
    _species = TextEditingController(text: widget.petData['species'] ?? '');
    _breed = TextEditingController(text: widget.petData['breed'] ?? '');
    _remarks = TextEditingController(text: widget.petData['remarks'] ?? '');
    _weight =
        TextEditingController(text: widget.petData['weight']?.toString() ?? '');
    _birthDate = DateTime.tryParse(widget.petData['birthDate'] ?? '');
    _vaccinationExpiry =
        DateTime.tryParse(widget.petData['vaccinationExpiry'] ?? '');
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
    final picked = await ImagePicker().pickImage(
        source: ImageSource.gallery, imageQuality: 70);
    if (picked != null) setState(() => _imageFile = File(picked.path));
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return widget.petData['petPhoto'];
    try {
      final fileName = 'pet_${DateTime
          .now()
          .millisecondsSinceEpoch}.jpg';
      await supabase.storage.from('pet_photos').upload(fileName, _imageFile!);
      return supabase.storage.from('pet_photos').getPublicUrl(fileName);
    } catch (e) {
      debugPrint("Upload error: $e");
      return widget.petData['petPhoto'];
    }
  }

  Future<void> _updatePet() async {
    // Required fields validation
    if (_nameHasError || _genderHasError || _birthDateHasError ||
        _birthDateInFuture) {
      String message = 'Please fix the following:\n';
      if (_nameHasError) message += '• Pet name is required\n';
      if (_genderHasError) message += '• Gender is required\n';
      if (_birthDateHasError) message += '• Birth date is required\n';
      if (_birthDateInFuture)
        message += '• Birth date cannot be in the future\n';

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(message.trim()),
          backgroundColor: Colors.redAccent,
          duration: const Duration(seconds: 4),
        ),
      );
      return;
    }

    // Optional field validation
    if (_weightIsInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Weight must be a valid non-negative number'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final imageUrl = await _uploadImage();
      final userId = supabase.auth.currentUser!.id;
      final petID = widget.petData['petID'] as String;

      // Cancel old notification
      final int oldNotificationId = petID.hashCode.abs();
      await NotificationService.cancel(oldNotificationId);

      await supabase.from('pet').update({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'gender': _gender,
        'birthDate': _birthDate!.toIso8601String(),
        // now safe because we checked
        'weight': double.tryParse(_weight.text.trim()) ?? 0.0,
        'vaccinationExpiry': _vaccinationExpiry?.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
      }).eq('petID', petID).eq('userID', userId);

      // Reschedule if expiry date exists
      if (_vaccinationExpiry != null) {
        await NotificationService.scheduleVaccineReminder(
          petId: petID,
          petName: _name.text.trim(),
          expiryDate: _vaccinationExpiry!,
        );
      }

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      print('Error updating pet: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Update failed: ${e
                .toString()
                .split('\n')
                .first}"),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) =>
          AlertDialog(
            title: const Text("Delete Pet?"),
            content: const Text(
                "This will permanently remove this pet profile."),
            actions: [
              TextButton(onPressed: () => Navigator.pop(ctx, false),
                  child: const Text("Cancel")),
              TextButton(onPressed: () => Navigator.pop(ctx, true),
                  child: const Text(
                      "Delete", style: TextStyle(color: Colors.red))),
            ],
          ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        final petID = widget.petData['petID'] as String;
        final int notificationId = petID.hashCode.abs();
        await NotificationService.cancel(notificationId);

        await supabase.from('pet').delete().eq('petID', petID);

        if (mounted) Navigator.pop(context, true);
      } catch (e) {
        debugPrint("Delete error: $e");
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Delete failed: $e")),
          );
        }
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
          IconButton(
              icon: const Icon(Icons.delete_outline), onPressed: _deletePet),
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
                    : (widget.petData['petPhoto'] != null ? NetworkImage(
                    widget.petData['petPhoto']) : null) as ImageProvider?,
                child: (_imageFile == null &&
                    widget.petData['petPhoto'] == null)
                    ? Icon(Icons.add_a_photo, size: 40, color: themeColor)
                    : null,
              ),
            ),
            const SizedBox(height: 30),
            TextField(
              controller: _name,
              decoration: _inputStyle('Pet Name', Icons.badge).copyWith(
                errorText: _name.text.isNotEmpty && _nameHasError
                    ? 'Pet name is required'
                    : null,
              ),
            ),

// Weight
            TextField(
              controller: _weight,
              keyboardType: TextInputType.numberWithOptions(decimal: true),
              decoration: _inputStyle('Weight (kg)', Icons.monitor_weight)
                  .copyWith(
                errorText: _weightErrorText,
              ),
            ),
            TextField(controller: _species,
                decoration: _inputStyle('Species', Icons.category)),
            const SizedBox(height: 15),
            TextField(controller: _breed,
                decoration: _inputStyle('Breed', Icons.pets)),
            const SizedBox(height: 15),
            DropdownButtonFormField<String>(
              value: _gender,
              decoration: _inputStyle('Gender', Icons.wc).copyWith(
                errorText: _gender == null ? 'Please select gender' : null,
              ),
              items: const [
                DropdownMenuItem(value: 'Male', child: Text('Male')),
                DropdownMenuItem(value: 'Female', child: Text('Female')),
              ],
              onChanged: (value) => setState(() => _gender = value),
            ),
            const SizedBox(height: 15),
            _buildDatePicker("Birth Date", _birthDate, (date) =>
                setState(() => _birthDate = date)),
            const SizedBox(height: 15),
            _buildDatePicker("Vaccination Expiry", _vaccinationExpiry, (date) =>
                setState(() => _vaccinationExpiry = date),
                icon: Icons.vaccines),
            const SizedBox(height: 15),
            TextField(controller: _remarks,
                maxLines: 3,
                decoration: _inputStyle('Remarks', Icons.description)),
            const SizedBox(height: 30),
            ElevatedButton(
              onPressed: _updatePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: const Text('UPDATE CHANGES',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDatePicker(String label, DateTime? date,
      Function(DateTime) onPicked, {IconData icon = Icons.calendar_today}) {
    final hasError = (label == "Birth Date") ? (_birthDateHasError ||
        _birthDateInFuture) : false;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        InkWell(
          onTap: () async {
            final picked = await showDatePicker(
              context: context,
              initialDate: date ?? DateTime.now(),
              firstDate: DateTime(2000),
              lastDate: DateTime.now().add(const Duration(days: 365 * 10)),
            );
            if (picked != null) onPicked(picked);
          },
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
            decoration: BoxDecoration(
              color: Colors.grey[100],
              borderRadius: BorderRadius.circular(borderRadius),
              border: hasError ? Border.all(color: Colors.redAccent) : null,
            ),
            child: Row(
              children: [
                Icon(icon, color: themeColor),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    date == null
                        ? 'Select $label'
                        : DateFormat('yyyy-MM-dd').format(date),
                    style: TextStyle(
                      color: date == null
                          ? Colors.grey[600]
                          : (hasError ? Colors.redAccent : Colors.black),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        if (hasError && label == "Birth Date")
          Padding(
            padding: const EdgeInsets.only(left: 16, top: 4),
            child: Text(
              _birthDateErrorText ?? '',
              style: const TextStyle(color: Colors.redAccent, fontSize: 12),
            ),
          ),
      ],
    );
  }
}