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
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

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

  String? get _emailErrorText {
    final email = _emailController.text.trim();
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email address';
    }
    return null;
  }

  String? get _passwordErrorText {
    final pw = _passwordController.text;
    if (pw.isEmpty) return 'Password is required';
    if (pw.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  Future<void> _login() async {
    if (_isLoading) return;

    if (_emailErrorText != null || _passwordErrorText != null) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors above'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final res = await supabase.auth.signInWithPassword(
        email: _emailController.text.trim().toLowerCase(),
        password: _passwordController.text.trim(),
      );

      if (res.user != null && mounted) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(builder: (_) => const MainNavigation()),
        );
      }
    } on AuthException catch (e) {
      String msg = 'Login failed';

      if (e.message.contains('Invalid login credentials')) {
        msg = 'Incorrect email or password';
      } else if (e.message.contains('network') ||
          e.message.contains('connection')) {
        msg = 'Network error. Please check your internet connection';
      } else {
        msg += ': ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Unexpected error occurred: $e'),
            backgroundColor: Colors.redAccent,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
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

            TextField(
              controller: _emailController,
              decoration: _loginInputStyle('Email', Icons.email)
                  .copyWith(errorText: _emailErrorText),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              decoration: _loginInputStyle('Password', Icons.lock)
                  .copyWith(errorText: _passwordErrorText),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 24),

            _isLoading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _login,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(borderRadius)),
              ),
              child: const Text('LOGIN',
                  style: TextStyle(fontWeight: FontWeight.bold)),
            ),

            const SizedBox(height: 24),

            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(builder: (_) => const RegisterPage()),
                  ),
                  child: Text('Create Account',
                      style: TextStyle(color: themeColor)),
                ),
                TextButton(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (_) => const ForgotPasswordPage()),
                  ),
                  child: Text('Forgot Password?',
                      style: TextStyle(color: Colors.grey[600])),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

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
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(borderRadius),
        borderSide: BorderSide.none,
      ),
    );
  }

  String? get _nameErrorText {
    final name = _nameController.text.trim();
    if (name.isEmpty) return 'Name is required';
    if (name.length < 3) return 'Name must be at least 3 characters';
    if (name.length > 30) return 'Name is too long (max 30)';
    if (RegExp(r'\d').hasMatch(name)) return 'Name cannot contain numbers';
    return null;
  }

  String? get _emailErrorText {
    final email = _emailController.text.trim();
    if (email.isEmpty) return 'Email is required';
    if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(email)) {
      return 'Please enter a valid email';
    }
    return null;
  }

  String? get _passwordErrorText {
    final pw = _passwordController.text;
    if (pw.isEmpty) return 'Password is required';
    if (pw.length < 8) return 'Password must be at least 8 characters';
    return null;
  }

  bool get _phoneInvalid {
    final phone = _phoneController.text.trim();
    if (phone.isEmpty) return false;

    final clean = phone.replaceAll(RegExp(r'[\s\-]'), '');
    final regExp = RegExp(r'^(?:\+60|0)1[0-9]{1,2}[0-9]{7,8}$');
    return !regExp.hasMatch(clean);
  }

  String? get _phoneErrorText {
    if (_phoneController.text.trim().isEmpty) return null;
    if (_phoneInvalid) return 'Invalid Malaysian phone number';
    return null;
  }

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final picked = await picker.pickImage(source: ImageSource.gallery);

    if (picked != null) {
      setState(() => _pickedImage = picked);
    }
  }

  Future<void> _register() async {
<<<<<<< ken
    if (_isLoading) return;
    if (_nameErrorText != null ||
        _emailErrorText != null ||
        _passwordErrorText != null ||
        _phoneInvalid) {
      setState(() {});
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please fix the errors above'),
          backgroundColor: Colors.redAccent,
        ),
      );
      return;
    }

=======
>>>>>>> master
    setState(() => _isLoading = true);

    try {
<<<<<<< ken
      final email = _emailController.text.trim().toLowerCase();
      final password = _passwordController.text.trim();
      final res = await supabase.auth.signUp(
        email: email,
        password: password,
      );

      if (res.user == null) throw Exception('Registration failed');

      String imageUrl = 'https://example.com/default_avatar.png';

      if (_pickedImage != null) {
        final bytes = await _pickedImage!.readAsBytes();

        if (bytes.lengthInBytes > 5 * 1024 * 1024) {
          throw Exception('Image too large');
        }

        final path = _pickedImage!.path.toLowerCase();
        if (!path.endsWith('.jpg') &&
            !path.endsWith('.jpeg') &&
            !path.endsWith('.png')) {
          throw Exception('Only JPG, JPEG or PNG allowed');
        }

        final ext = path.endsWith('.png') ? 'png' : 'jpg';
        final filePath = '${res.user!.id}/avatar.$ext';

        await supabase.storage.from('user_photos').uploadBinary(filePath, bytes);
        imageUrl = supabase.storage.from('user_photos').getPublicUrl(filePath);
      }

      await supabase.from('users').insert({
        'userID': res.user!.id,
        'userName': _nameController.text.trim(),
        'userEmail': email,
        'phoneNumber': _phoneController.text.trim().isEmpty
            ? null
            : _phoneController.text.trim(),
        'userPhoto': imageUrl,
        'accountStatus': 'Active',
        'role': 'User',
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Registration successful! Please login')),
        );
        Navigator.pop(context);
      }
    } on AuthException catch (e) {
      String msg = 'Registration failed';

      // Supabase rate limit 或其他 Auth 错误
      if (e.message.contains('rate limit')) {
        msg = 'Too many requests. Please wait a few minutes and try again.';
      } else if (e.message.contains('duplicate key') || e.message.contains('already registered')) {
        msg = 'This email is already registered';
      } else if (e.message.contains('weak password')) {
        msg = 'Password is too weak';
      } else {
        msg += ': ${e.message}';
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.redAccent),
        );
=======
      // 1. Sign up to Supabase Auth (Creates the 'Account')
      final AuthResponse res = await supabase.auth.signUp(
        email: _emailController.text.trim(),
        password: _passwordController.text.trim(),
      );

      // 2. Define 'user' so the code knows what 'user.id' is
      final user = res.user;

      if (user != null) {
        // 3. Insert into your custom 'users' table
        await supabase.from('users').insert({
          'userID': user.id,
          'userName': _nameController.text.trim(),
          'userEmail': _emailController.text.trim(),
          'phoneNumber': _phoneController.text.trim(),
          'role': 'User', // Default role
        });

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Registration Successful! Please Login.')),
          );
          Navigator.pop(context);
        }
>>>>>>> master
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
<<<<<<< ken
          SnackBar(
            content: Text('Registration error: ${e.toString().split('\n').first}'),
            backgroundColor: Colors.redAccent,
          ),
=======
          SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red),
>>>>>>> master
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Register'),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            GestureDetector(
              onTap: _pickImage,
              child: CircleAvatar(
                radius: 50,
                backgroundColor: Colors.grey[200],
                backgroundImage:
                _pickedImage != null ? FileImage(File(_pickedImage!.path)) : null,
                child: _pickedImage == null
                    ? Icon(Icons.person, size: 50, color: themeColor)
                    : null,
              ),
            ),

            const SizedBox(height: 30),

            TextField(
              controller: _nameController,
              decoration:
              _regInputStyle('Name', Icons.person).copyWith(errorText: _nameErrorText),
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _emailController,
              decoration:
              _regInputStyle('Email', Icons.email).copyWith(errorText: _emailErrorText),
              keyboardType: TextInputType.emailAddress,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _passwordController,
              decoration:
              _regInputStyle('Password', Icons.lock).copyWith(errorText: _passwordErrorText),
              obscureText: true,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 16),

            TextField(
              controller: _phoneController,
              decoration: _regInputStyle('Phone Number', Icons.phone)
                  .copyWith(errorText: _phoneErrorText),
              keyboardType: TextInputType.phone,
              onChanged: (_) => setState(() {}),
            ),

            const SizedBox(height: 32),

            _isLoading
                ? CircularProgressIndicator(color: themeColor)
                : ElevatedButton(
              onPressed: _register,
              style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                foregroundColor: Colors.white,
                minimumSize: const Size(double.infinity, 55),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(borderRadius),
                ),
              ),
              child: const Text(
                'CREATE ACCOUNT',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }
}