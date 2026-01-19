import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class AddPetPage extends StatefulWidget {
  const AddPetPage({super.key});

  @override
  State<AddPetPage> createState() => _AddPetPageState();
}

class _AddPetPageState extends State<AddPetPage> {
  final _nameController = TextEditingController();
  final _speciesController = TextEditingController();
  final _breedController = TextEditingController();
  final _ageController = TextEditingController();

  bool _isLoading = false;

  Future<void> _addPet() async {
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
      final user = supabase.auth.currentUser;
      if (user == null) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('User not logged in')),
        );
        return;
      }


      await supabase.from('pet').insert({
        'userID': user.id,
        'petName': name,
        'species': species,
        'breed': breed,
        'age': age,
        'petPhoto': 'https://example.com/default_pet.png', // 默认头像
      });

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Pet added successfully!')),
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
        title: const Text('Add Pet'),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [

            CircleAvatar(
              radius: 50,
              backgroundImage:
              const NetworkImage('https://example.com/default_pet.png'),
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
                : ElevatedButton(
              onPressed: _addPet,
              child: const Text('Add Pet'),
            ),
          ],
        ),
      ),
    );
  }
}
