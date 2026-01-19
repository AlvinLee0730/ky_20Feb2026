import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'edit.dart';
import 'login_page.dart';

final supabase = Supabase.instance.client;

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {

  String userName = 'Loading...';
  String userEmail = 'Loading...';
  String phoneNumber = 'Loading...';
  String userPhoto =
      'https://example.com/default_avatar.png';

  @override
  void initState() {
    super.initState();
    _loadUserData();
  }

  Future<void> _loadUserData() async {
    try {
      final user = supabase.auth.currentUser;
      if (user != null) {
        final response = await supabase
            .from('users')
            .select()
            .eq('userID', user.id)
            .single();

        setState(() {
          userName = response['userName'] ?? 'No Name';
          userEmail = response['userEmail'] ?? 'No Email';
          phoneNumber = response['phoneNumber'] ?? 'No Phone';
          userPhoto = response['userPhoto'] ??
              'https://example.com/default_avatar.png';
        });
      }
    } catch (e) {
      print('Error loading user data: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: true,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              CircleAvatar(
                radius: 50,
                backgroundImage: NetworkImage(userPhoto),
              ),
              const SizedBox(height: 16),
              Text(
                userName,
                style: const TextStyle(
                    fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(userEmail),
              const SizedBox(height: 8),
              Text(phoneNumber),
              const SizedBox(height: 32),
              ElevatedButton(
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const EditProfilePage()),
                  );
                },
                child: const Text('Edit Profile'),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () async {
                  await supabase.auth.signOut();
                  Navigator.pushReplacement(
                    context,
                    MaterialPageRoute(
                        builder: (context) => const LoginPage()),
                  );
                },
                child: const Text('Logout'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
