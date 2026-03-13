import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'user_model.dart';
import 'user_management.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {


  bool get _nameIsEmpty => _nameController.text.trim().isEmpty;
  bool get _nameTooShort => _nameController.text.trim().length < 3;
  bool get _nameTooLong  => _nameController.text.trim().length > 30;
  bool get _nameHasNumber {
    final name = _nameController.text.trim();
    return RegExp(r'\d').hasMatch(name);
  }

  bool get _phoneInvalid {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return false;


    final cleanPhone = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final regExp = RegExp(r'^(?:\+60|0)1[0-9]{8,9}$');
    return !regExp.hasMatch(cleanPhone);
  }

  String? get _nameErrorText {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Name is required';
    if (name.length < 3) return 'Name must be at least 3 characters';
    if (name.length > 30) return 'Name is too long (max 30)';
    if (_nameHasNumber) return 'Name cannot contain numbers';
    return null;
  }

  String? get _phoneErrorText {
    if (_phoneController.text.trim().isEmpty) return null;
    if (_phoneInvalid) return 'Invalid Malaysian phone number (e.g. 0123456789 or +60123456789)';
    return null;
  }
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

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

  InputDecoration _profileInputStyle(String label, IconData icon) {
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

  // ... (_loadUserData, _pickImage, _saveProfile 逻辑保持不变) ...
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
      debugPrint('Error loading profile: $e');
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

    // 名字驗證
    if (_nameIsEmpty || _nameTooShort || _nameTooLong || _nameHasNumber) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_nameErrorText ?? 'Please enter a valid name'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    // 手機驗證（選填）
    if (_phoneInvalid) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Invalid Malaysian phone number format'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      String imageUrl = _user!.userPhoto ?? '';

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();

        // 1. 大小檢查 (< 5MB)
        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw Exception('Image size exceeds 5MB limit');
        }

        // 2. 類型檢查 (jpg/jpeg/png)
        final path = _pickedImage!.path.toLowerCase();
        final isValidType = path.endsWith('.jpg') ||
            path.endsWith('.jpeg') ||
            path.endsWith('.png');
        if (!isValidType) {
          throw Exception('Only JPG or PNG images are allowed');
        }

        final extension = path.endsWith('.png') ? 'png' : 'jpg';
        final filePath = '${_user!.userID}/avatar.$extension';
        await supabase.storage.from('user_photos').uploadBinary(filePath, bytes);
        imageUrl = supabase.storage.from('user_photos').getPublicUrl(filePath);
      }

      // 更新資料
      await supabase.from('users').update({
        'userName': _nameController.text.trim(),
        'phoneNumber': _phoneController.text.trim().isEmpty ? null : _phoneController.text.trim(),
        'userPhoto': imageUrl,
      }).eq('userID', _user!.userID);

      // 重新載入資料
      await _loadUserData();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      String errorMsg = 'Failed to update profile';

      if (e.toString().contains('5MB')) {
        errorMsg = 'Image is too large (maximum 5MB)';
      } else if (e.toString().contains('JPG or PNG')) {
        errorMsg = 'Only JPG or PNG images are supported';
      } else if (e.toString().contains('network') || e.toString().contains('connection')) {
        errorMsg = 'Network error. Please check your internet connection';
      } else {
        errorMsg += ': ${e.toString().split('\n').first}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMsg),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _signOut() async {
    try {
      setState(() => _isLoading = true);
      await supabase.auth.signOut();

      if (!mounted) return;

      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(
          builder: (_) => const LoginPage(),
        ),
            (route) => false,
      );
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Logout failed: $e')),
      );
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) return Scaffold(body: Center(child: CircularProgressIndicator(color: themeColor)));

    return Scaffold(
      appBar: AppBar(
        title: const Text('My Profile'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        child: Column(
          children: [
            // 修改 1: 漂亮的 Header 背景 (对齐队友的详情页风格)
            Stack(
              alignment: Alignment.center,
              children: [
                Container(
                  height: 120,
                  width: double.infinity,
                  decoration: BoxDecoration(
                    color: themeColor,
                    borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.only(top: 40),
                  child: GestureDetector(
                    onTap: _pickImage,
                    child: Stack(
                      children: [
                        CircleAvatar(
                          radius: 60,
                          backgroundColor: Colors.white,
                          child: CircleAvatar(
                            radius: 56,
                            backgroundImage: _pickedImage != null
                                ? FileImage(File(_pickedImage!.path))
                                : (_user?.userPhoto != null ? NetworkImage(_user!.userPhoto!) : null) as ImageProvider?,
                            child: (_pickedImage == null && _user?.userPhoto == null)
                                ? Icon(Icons.person, size: 50, color: themeColor)
                                : null,
                          ),
                        ),
                        Positioned(
                          bottom: 0,
                          right: 4,
                          child: CircleAvatar(
                            backgroundColor: Colors.white,
                            radius: 18,
                            child: Icon(Icons.camera_alt, size: 18, color: themeColor),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 10),
            Text(_user?.email ?? '', style: const TextStyle(color: Colors.grey)),
            const SizedBox(height: 30),

            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Column(
                children: [
                  // 修改 2: 统一风格的输入框
                  TextField(
                    controller: _nameController,
                    decoration: _profileInputStyle('User Name', Icons.badge).copyWith(
                      errorText: _nameErrorText,
                    ),
                    onChanged: (_) => setState(() {}), // 即時更新 error
                  ),

                  const SizedBox(height: 16,),

                  TextField(
                    controller: _phoneController,
                    keyboardType: TextInputType.phone,
                    decoration: _profileInputStyle('Phone Number', Icons.phone).copyWith(
                      errorText: _phoneErrorText,
                    ),
                    onChanged: (_) => setState(() {}),
                  ),

                  const SizedBox(height: 40),

                  // 修改 3: 队友风格的宽大按钮
                  ElevatedButton.icon(
                    onPressed: _saveProfile,
                    icon: const Icon(Icons.check),
                    label: const Text('SAVE PROFILE', style: TextStyle(fontWeight: FontWeight.bold)),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: themeColor,
                      foregroundColor: Colors.white,
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                      elevation: 0,
                    ),
                  ),
                  const SizedBox(height: 12),


                  OutlinedButton.icon(
                    onPressed: _signOut,
                    icon: const Icon(Icons.logout),
                    label: const Text('LOGOUT'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: Colors.red,
                      side: const BorderSide(color: Colors.red),
                      minimumSize: const Size(double.infinity, 55),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}