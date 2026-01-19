import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'addPet.dart';
import 'editPet.dart';
import 'package:newfypken/scheduleModule/schedule.dart';

final supabase = Supabase.instance.client;

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  List<Map<String, dynamic>> pets = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadPets();
  }


  Future<void> _loadPets() async {
    setState(() => _isLoading = true);
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('pet')
            .select()
            .eq('userID', user.id);

        setState(() {
          pets = List<Map<String, dynamic>>.from(response);
        });
      }
    } catch (e) {
      print('Error loading pets: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to load pets: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }


  Widget _buildTopButtons() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          ElevatedButton(
            onPressed: () async {

              await Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const AddPetPage()),
              );
              _loadPets();
            },
            child: const Text('Add Pet'),
          ),
          ElevatedButton(
            onPressed: () {

              final petIds = pets.map((pet) => pet['petID'].toString()).toList();


              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => SchedulePage(
                    pets: pets,
                    petIds: petIds,
                  ),
                ),
              );
            },
            child: const Text('Schedule'),
          ),
          ElevatedButton(
            onPressed: () {

            },
            child: const Text('Food & Nutrition'),
          ),
        ],
      ),
    );
  }


  Widget _buildPetCard(Map<String, dynamic> pet) {
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
      child: ListTile(
        leading: CircleAvatar(
          radius: 30,
          backgroundImage: NetworkImage(
            pet['petPhoto'] ?? 'https://example.com/default_pet.png',
          ),
        ),
        title: Text(pet['petName'] ?? 'No Name'),
        subtitle: Text(
          'Species: ${pet['species'] ?? '-'}\n'
              'Breed: ${pet['breed'] ?? '-'}\n'
              'Age: ${pet['age'] ?? '-'}',
        ),
        isThreeLine: true,
        trailing: IconButton(
          icon: const Icon(Icons.edit, color: Colors.blue),
          onPressed: () async {
            await Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => EditPetPage(petData: pet)),
            );
            _loadPets();
          },
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Pets'),
        centerTitle: true,
      ),
      body: Column(
        children: [
          _buildTopButtons(),
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : pets.isEmpty
                ? const Center(child: Text('No pets found. Add one!'))
                : ListView.builder(
              itemCount: pets.length,
              itemBuilder: (context, index) {
                final pet = pets[index];
                return _buildPetCard(pet);
              },
            ),
          ),
        ],
      ),
    );
  }
}
