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
  // --- 队友的 UI 规范参数 ---
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

  // 统一输入框装饰器 (参考队友的 Education/Chat 风格)
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
      _loadUserData();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Profile updated!')));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Failed: $e')));
    } finally {
      setState(() => _isLoading = false);
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
                  TextField(controller: _nameController, decoration: _profileInputStyle('User Name', Icons.badge)),
                  const SizedBox(height: 16),
                  TextField(controller: _phoneController, decoration: _profileInputStyle('Phone Number', Icons.phone)),

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

                  // 修改 4: 退出登录按钮 (使用 Outlined 风格，不抢主色调的戏)
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