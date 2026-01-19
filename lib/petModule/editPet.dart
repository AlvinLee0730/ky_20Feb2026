import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EditPetPage extends StatefulWidget {
  final Map petData;

  const EditPetPage({super.key, required this.petData});

  @override
  State<EditPetPage> createState() => _EditPetPageState();
}

class _EditPetPageState extends State<EditPetPage> {
  late TextEditingController _nameController;
  late TextEditingController _speciesController;
  late TextEditingController _breedController;
  late TextEditingController _ageController;

  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.petData['petName']);
    _speciesController = TextEditingController(text: widget.petData['species']);
    _breedController = TextEditingController(text: widget.petData['breed']);
    _ageController = TextEditingController(text: widget.petData['age'].toString());
  }


  Future<void> _updatePet() async {
    final name = _nameController.text.trim();
    final species = _speciesController.text.trim();
    final breed = _breedController.text.trim();
    final ageText = _ageController.text.trim();

    if (name.isEmpty || species.isEmpty || breed.isEmpty || ageText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please fill all fields')),
      );
      return;
    }

    final age = int.tryParse(ageText);
    if (age == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Age must be a number')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('pet')
          .update({
        'petName': name,
        'species': species,
        'breed': breed,
        'age': age,
      })
          .eq('petID', widget.petData['petID']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet updated successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Future<void> _deletePet() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Pet'),
        content: const Text('Are you sure you want to delete this pet?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete', style: TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirm != true) return;

    setState(() => _isLoading = true);

    try {
      await supabase
          .from('pet')
          .delete()
          .eq('petID', widget.petData['petID']);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet deleted successfully!')),
      );

      Navigator.pop(context);
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _speciesController.dispose();
    _breedController.dispose();
    _ageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Edit Pet'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            CircleAvatar(
              radius: 50,
              backgroundImage: NetworkImage(
                widget.petData['petPhoto'] ??
                    'https://example.com/default_pet.png',
              ),
            ),
            const SizedBox(height: 16),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Pet Name'),
            ),
            TextField(
              controller: _speciesController,
              decoration: const InputDecoration(labelText: 'Species'),
            ),
            TextField(
              controller: _breedController,
              decoration: const InputDecoration(labelText: 'Breed'),
            ),
            TextField(
              controller: _ageController,
              decoration: const InputDecoration(labelText: 'Age'),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator()
                : Column(
              children: [
                ElevatedButton(
                  onPressed: _updatePet,
                  child: const Text('Confirm Edit'),
                ),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _deletePet,
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                  child: const Text('Delete Pet'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
