import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

final supabase = Supabase.instance.client;

class EditProfilePage extends StatefulWidget {
  const EditProfilePage({super.key});

  @override
  State<EditProfilePage> createState() => _EditProfilePageState();
}

class _EditProfilePageState extends State<EditProfilePage> {
  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  String userPhoto =
      'https://example.com/default_avatar.png';
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    try {
      final response = await supabase
          .from('users')
          .select()
          .eq('userID', user.id)
          .single();

      setState(() {
        _nameController.text = response['userName'] ?? '';
        _phoneController.text = response['phoneNumber'] ?? '';
        userPhoto = response['userPhoto'] ??
            'https://example.com/default_avatar.png';
        _isLoading = false;
      });
    } catch (e) {
      print('Error loading profile: $e');
      setState(() {
        _isLoading = false;
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to load profile')),
      );
    }
  }

  Future<void> _saveProfile() async {
    final user = supabase.auth.currentUser;
    if (user == null) return;

    setState(() => _isLoading = true);

    try {
      await supabase.from('users').update({
        'userName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),

      }).eq('userID', user.id);

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated successfully!')),
      );
      Navigator.pop(context);
    } catch (e) {
      print('Error updating profile: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Failed to update profile: $e')),
      );
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Edit Profile')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [

            GestureDetector(
              onTap: () {

              },
              child: CircleAvatar(
                radius: 60,
                backgroundImage: NetworkImage(userPhoto),
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tap to change photo (disabled now)'),

            const SizedBox(height: 32),

            TextField(
              controller: _nameController,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _phoneController,
              decoration: const InputDecoration(labelText: 'Phone Number'),
            ),
            const SizedBox(height: 32),

            _isLoading
                ? const CircularProgressIndicator()
                : ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
              style: ElevatedButton.styleFrom(
                  minimumSize: const Size(double.infinity, 50)),
            ),
          ],
        ),
      ),
    );
  }
}
