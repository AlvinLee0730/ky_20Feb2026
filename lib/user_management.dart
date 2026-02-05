import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'forgot_password.dart';
import 'main.dart';

final supabase = Supabase.instance.client;

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  // Core style specifications
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  // Unified input field decorator
  InputDecoration _loginInputStyle(String label, IconData icon) {
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

  // Helper method for direct login
  void _quickLogin(String email, String password) {
    _emailController.text = email;
    _passwordController.text = password;
    _login();
  }

  Future<void> _login() async {
    if (_emailController.text.isEmpty || _passwordController.text.isEmpty) return;

    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );
      if (res.user != null && mounted) {
        Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const MainNavigation()));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Login'),
        centerTitle: true,
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const SizedBox(height: 40),
            Icon(Icons.lock_person, size: 80, color: themeColor),
            const SizedBox(height: 40),
            TextField(controller: _emailController, decoration: _loginInputStyle('Email', Icons.email)),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: _loginInputStyle('Password', Icons.lock), obscureText: true),
            const SizedBox(height: 24),
            _isLoading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                elevation: 0,
              ),
              child: const Text('LOGIN', style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            // --- Direct Login Buttons Section ---
            const SizedBox(height: 32),
            const Text("Quick Login (Dev Mode)", style: TextStyle(color: Colors.grey, fontSize: 12)),
            const Divider(),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickLogin("admin@gmail.com", "123456"),
                    icon: const Icon(Icons.admin_panel_settings, size: 18),
                    label: const Text("Admin"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _quickLogin("ky@gmail.com", "123456"),
                    icon: const Icon(Icons.person, size: 18),
                    label: const Text("User KY"),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: themeColor,
                      side: BorderSide(color: themeColor),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
              ],
            ),
            // ------------------------------------

            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RegisterPage())),
                  child: Text('Create Account', style: TextStyle(color: themeColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ForgotPasswordPage())),
                  child: Text('Forgot Password?', style: TextStyle(color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------- Register Page ----------------
class RegisterPage extends StatefulWidget {
  const RegisterPage({super.key});

  @override
  State<RegisterPage> createState() => _RegisterPageState();
}

class _RegisterPageState extends State<RegisterPage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _phoneController = TextEditingController();
  XFile? _pickedImage;
  bool _isLoading = false;

  InputDecoration _regInputStyle(String label, IconData icon) {
    return InputDecoration(
      labelText: label,
      prefixIcon: Icon(icon, color: themeColor),
      filled: true,
      fillColor: Colors.grey[100],
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(borderRadius), borderSide: BorderSide.none),
    );
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);
    if (picked != null) setState(() => _pickedImage = picked);
  }

  Future<void> _register() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text.trim();
    if (name.isEmpty || email.isEmpty || password.isEmpty) return;
    setState(() => _isLoading = true);
    try {
      final res = await supabase.auth.signUp(email: email, password: password);
      if (res.user != null) {
        String imageUrl = 'https://example.com/default_avatar.png';
        if (_pickedImage != null) {
          final bytes = await _pickedImage!.readAsBytes();
          final filePath = '${res.user!.id}/avatar.png';
          await supabase.storage.from('user_photos').uploadBinary(filePath, bytes);
          imageUrl = supabase.storage.from('user_photos').getPublicUrl(filePath);
        }
        await supabase.from('users').insert({
          'userID': res.user!.id, 'userName': name, 'userEmail': email,
          'phoneNumber': _phoneController.text.trim(), 'userPhoto': imageUrl,
          'accountStatus': 'Active', 'role': 'User',
        });
        if (mounted) Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Register'), backgroundColor: themeColor, foregroundColor: Colors.white, elevation: 0),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: Stack(
                children: [
                  CircleAvatar(
                    radius: 50,
                    backgroundColor: Colors.grey[200],
                    backgroundImage: _pickedImage != null ? FileImage(File(_pickedImage!.path)) : null,
                    child: _pickedImage == null ? Icon(Icons.person, size: 50, color: themeColor) : null,
                  ),
                  Positioned(bottom: 0, right: 0, child: CircleAvatar(backgroundColor: themeColor, radius: 15, child: const Icon(Icons.camera_alt, size: 15, color: Colors.white))),
                ],
              ),
            ),
            const SizedBox(height: 30),
            TextField(controller: _nameController, decoration: _regInputStyle('Name', Icons.person)),
            const SizedBox(height: 16),
            TextField(controller: _emailController, decoration: _regInputStyle('Email', Icons.email)),
            const SizedBox(height: 16),
            TextField(controller: _passwordController, decoration: _regInputStyle('Password', Icons.lock), obscureText: true),
            const SizedBox(height: 16),
            TextField(controller: _phoneController, decoration: _regInputStyle('Phone Number', Icons.phone)),
            const SizedBox(height: 32),
            _isLoading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor, foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(borderRadius)),
                elevation: 0,
              ),
              child: const Text('CREATE ACCOUNT', style: TextStyle(fontWeight: FontWeight.bold)),
            ),
          ],
        ),
      ),
    );
  }
}