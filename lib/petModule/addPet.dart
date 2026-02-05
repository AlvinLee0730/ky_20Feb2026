import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
  final _remarks = TextEditingController();

  DateTime? _birthDate;
  File? _imageFile;
  bool _loading = false;

  // ⭐ 新增 gender
  String? _gender;

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

  // ================= IMAGE =================
  Future<void> _pickImage() async {
    final picked =
    await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 70);

    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  // ================= SAVE PET =================
  Future<void> _savePet() async {
    if (_name.text.isEmpty || _birthDate == null || _gender == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Name, Gender and Birth Date are required")),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final userId = supabase.auth.currentUser!.id; // ⭐ non-null fix

      String? imageUrl;

      // upload image
      if (_imageFile != null) {
        final fileName =
            'pet_${DateTime.now().millisecondsSinceEpoch}.jpg';

        await supabase.storage
            .from('pet_photos')
            .upload(fileName, _imageFile!);

        imageUrl =
            supabase.storage.from('pet_photos').getPublicUrl(fileName);
      }

      // ⭐ INSERT
      await supabase.from('pet').insert({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'gender': _gender, // ⭐ 新增
        'birthDate': _birthDate!.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
        'userID': userId, // ⭐ 修正 ownerID → userID
      });

      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text("Error: $e")));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  // ================= UI =================
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
            // IMAGE
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                _imageFile != null ? FileImage(_imageFile!) : null,
                child: _imageFile == null
                    ? Icon(Icons.add_a_photo, size: 40, color: themeColor)
                    : null,
              ),
            ),

            const SizedBox(height: 30),

            // NAME
            TextField(
              controller: _name,
              decoration: _inputStyle('Pet Name', Icons.badge),
            ),

            const SizedBox(height: 15),

            // SPECIES
            TextField(
              controller: _species,
              decoration: _inputStyle('Species', Icons.category),
            ),

            const SizedBox(height: 15),

            // BREED
            TextField(
              controller: _breed,
              decoration: _inputStyle('Breed', Icons.pets),
            ),

            const SizedBox(height: 15),

            // ⭐⭐⭐ GENDER DROPDOWN ⭐⭐⭐
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

            // BIRTH DATE
            ListTile(
              tileColor: Colors.grey[100],
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(borderRadius),
              ),
              leading: Icon(Icons.calendar_today, color: themeColor),
              title: Text(
                _birthDate == null
                    ? 'Select Birth Date'
                    : _birthDate!.toLocal().toString().split(' ')[0],
              ),
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

            // REMARKS
            TextField(
              controller: _remarks,
              maxLines: 3,
              decoration: _inputStyle('Remarks', Icons.description),
            ),

            const SizedBox(height: 40),

            // BUTTON
            _loading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _savePet,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius:
                  BorderRadius.circular(borderRadius),
                ),
              ),
              child: const Text(
                'SAVE PET',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
