import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_model.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  AppUser? _user;
  bool _isLoading = true;
  XFile? _pickedImage;

  final _nameController = TextEditingController();
  final _phoneController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    final currentUser = supabase.auth.currentUser;
    if (currentUser == null) return;

    try {
      final response = await supabase.from('users').select().eq('userID', currentUser.id).single();
      setState(() {
        _user = AppUser.fromJson(response);
        _nameController.text = _user!.userName;
        _phoneController.text = _user!.phoneNumber ?? '';
      });
    } catch (e) {
      print('Error loading profile: $e');
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _saveProfile() async {
    if (_user == null) return;

    setState(() => _isLoading = true);
    try {
      String imageUrl = _user!.userPhoto ?? '';

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();
        final filePath = '${_user!.userID}/avatar.png';
        await supabase.storage.from('user_photos').uploadBinary(filePath, bytes);
        imageUrl = supabase.storage.from('user_photos').getPublicUrl(filePath);
      }

      await supabase.from('users').update({
        'userName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim(),
        'userPhoto': imageUrl,
      }).eq('userID', _user!.userID);

      setState(() {
        _user = AppUser(
          userID: _user!.userID,
          userName: _nameController.text.trim(),
          email: _user!.email,
          phoneNumber: _phoneController.text.trim(),
          userPhoto: imageUrl,
          accountStatus: _user!.accountStatus,
          role: _user!.role,
        );
        _pickedImage = null;
      });

      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated successfully!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    await supabase.auth.signOut();
    Navigator.pushReplacementNamed(context, '/login');
  }

  @override
  void dispose() {
    _nameController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return const Scaffold(body: Center(child: CircularProgressIndicator()));

    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 60,
                backgroundImage: _pickedImage != null
                    ? FileImage(File(_pickedImage!.path))
                    : NetworkImage(_user!.userPhoto ?? '') as ImageProvider,
              ),
            ),
            const SizedBox(height: 16),
            const Text('Tap to change photo'),
            const SizedBox(height: 24),
            TextField(controller: _nameController, decoration: const InputDecoration(labelText: 'Name')),
            const SizedBox(height: 16),
            TextField(controller: _phoneController, decoration: const InputDecoration(labelText: 'Phone Number')),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: _saveProfile,
              child: const Text('Save'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _signOut,
              child: const Text('Logout'),
              style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50), backgroundColor: Colors.red),
            ),
          ],
        ),
      ),
    );
  }
}
