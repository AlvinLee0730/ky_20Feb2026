import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _name = TextEditingController();
  final _species = TextEditingController();
  final _breed = TextEditingController();
  final _remarks = TextEditingController();

  DateTime? _birthDate;
  File? _imageFile;
  bool _loading = false;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage(String petID) async {
    if (_imageFile == null) return null;

    final fileName = '${petID}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('pet_photos')  // <- 改成你的 bucket 名
        .upload(fileName, _imageFile!);

    return supabase.storage
        .from('pet_photos')
        .getPublicUrl(fileName);
  }

  Future<void> _addPet() async {
    if (_name.text.isEmpty ||
        _species.text.isEmpty ||
        _breed.text.isEmpty ||
        _birthDate == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    setState(() => _loading = true);

    try {
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }

      // 生成 petID
      final petID = 'P${DateTime.now().millisecondsSinceEpoch}';

      final imageUrl = await _uploadImage(petID);

      await supabase.from('pet').insert({
        'userID': user.id,   // userID 也是 UUID
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'birthDate': _birthDate!.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
      });


      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(e.toString())));
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Add Pet')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundImage: _imageFile != null
                    ? FileImage(_imageFile!)
                    : const AssetImage('assets/default_pet.png')
                as ImageProvider,
              ),
            ),
            TextField(controller: _name, decoration: const InputDecoration(labelText: 'Pet Name')),
            TextField(controller: _species, decoration: const InputDecoration(labelText: 'Species')),
            TextField(controller: _breed, decoration: const InputDecoration(labelText: 'Breed')),
            TextField(controller: _remarks, decoration: const InputDecoration(labelText: 'Remarks')),
            const SizedBox(height: 12),
            Row(
              children: [
                Text(_birthDate == null
                    ? 'Select birth date'
                    : _birthDate!.toLocal().toString().split(' ')[0]),
                IconButton(
                  icon: const Icon(Icons.calendar_today),
                  onPressed: () async {
                    final picked = await showDatePicker(
                      context: context,
                      firstDate: DateTime(2000),
                      lastDate: DateTime.now(),
                      initialDate: _birthDate ?? DateTime.now(),
                    );
                    if (picked != null) setState(() => _birthDate = picked);
                  },
                )
              ],
            ),
            const SizedBox(height: 24),
            _loading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _addPet,
              child: const Text('Add Pet'),
            )
          ],
        ),
      ),
    );
  }
}
