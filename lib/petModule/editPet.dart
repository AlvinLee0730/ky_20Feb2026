import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EditPetPage extends StatefulWidget {
  final Map petData;
  const EditPetPage({super.key, required this.petData});

  @override
  State<EditPetPage> createState() => _EditPetPageState();
}

class _EditPetPageState extends State<EditPetPage> {
  late TextEditingController _name;
  late TextEditingController _species;
  late TextEditingController _breed;
  late TextEditingController _remarks;

  DateTime? _birthDate;
  File? _imageFile;
  bool _loading = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.petData['petName']);
    _species = TextEditingController(text: widget.petData['species']);
    _breed = TextEditingController(text: widget.petData['breed']);
    _remarks = TextEditingController(text: widget.petData['remarks']);
    _birthDate = DateTime.tryParse(widget.petData['birthDate'] ?? '');
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) {
      setState(() => _imageFile = File(picked.path));
    }
  }

  Future<String?> _uploadImage() async {
    if (_imageFile == null) return widget.petData['petPhoto'];

    final fileName =
        '${widget.petData['petID']}_${DateTime.now().millisecondsSinceEpoch}.jpg';

    await supabase.storage
        .from('pet_photos')   // <- 改成你的 bucket 名
        .upload(fileName, _imageFile!);

    return supabase.storage
        .from('pet_photos')
        .getPublicUrl(fileName);
  }

  Future<void> _updatePet() async {
    if (_birthDate == null) return;

    setState(() => _loading = true);
    try {
      final imageUrl = await _uploadImage();

      await supabase.from('pet').update({
        'petName': _name.text.trim(),
        'species': _species.text.trim(),
        'breed': _breed.text.trim(),
        'birthDate': _birthDate!.toIso8601String(),
        'petPhoto': imageUrl,
        'remarks': _remarks.text.trim(),
      }).eq('petID', widget.petData['petID']);

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
      appBar: AppBar(title: const Text('Edit Pet')),
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
                    : widget.petData['petPhoto'] != null
                    ? NetworkImage(widget.petData['petPhoto'])
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
              onPressed: _updatePet,
              child: const Text('Save'),
            )
          ],
        ),
      ),
    );
  }
}
