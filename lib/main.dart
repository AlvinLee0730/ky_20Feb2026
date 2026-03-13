import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

// Your existing local files
import 'lost_and_found.dart';
import 'pet_adoption.dart';
import 'education.dart';
import 'expense_tracking.dart';
import 'admin_approval.dart';
import 'user_management.dart';
import 'chat.dart';
import 'forum.dart';
import 'user_profile.dart';
import 'petModule/petProfile.dart';
import 'notification_service.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://pypxpvamkqtnjyhqsycs.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InB5cHhwdmFta3F0bmp5aHFzeWNzIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzE0MjAwNzAsImV4cCI6MjA4Njk5NjA3MH0.hhBjN5JK5UpvaOv3FJXPi0KcbmpAdJOlpcMfKUEKqX0',
  );

  await NotificationService.initialize();
  await NotificationService.refreshRepeatingReminders();

  runApp(const PetCareApp());
}

class PetCareApp extends StatelessWidget {
  const PetCareApp({super.key});

  @override
  Widget build(BuildContext context) {
    final session = Supabase.instance.client.auth.currentSession;

    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'PetCare Hub',
      theme: ThemeData(
        primarySwatch: Colors.teal,
        useMaterial3: true,
        scaffoldBackgroundColor: Colors.grey[50],
      ),

      home: session != null
          ? const MainNavigation()
          : const LoginPage(),
    );
  }
}

class MainNavigation extends StatefulWidget {
  const MainNavigation({super.key});

  @override
  State<MainNavigation> createState() => _MainNavigationState();
}

class _MainNavigationState extends State<MainNavigation> {
  int _selectedIndex = 2;

  final List<Widget> _pages = [
    const ExpenseTrackingPage(), // Index 0
    const ChatModuleList(),      // Index 1
    const HomePage(),            // Index 2
    const PetProfilePage(),           // Index 3
    const ProfilePage(),         // Index 4 -> 从 user_profile.dart 引入
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) => setState(() => _selectedIndex = index),
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        showUnselectedLabels: true,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Expense"),
          BottomNavigationBarItem(icon: Icon(Icons.chat), label: "Chat"),
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          BottomNavigationBarItem(icon: Icon(Icons.pets), label: "Pet"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
        ],
      ),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String _userRole = 'User';

  @override
  void initState() {
    super.initState();
    _fetchUserRole();

  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client
            .from('users')
            .select('role')
            .eq('userID', user.id)
            .single();
        if (mounted) setState(() => _userRole = data['role'] ?? 'User');
      } catch (e) {
        debugPrint("Error fetching role: $e");
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("PetCare Hub", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Colors.teal,
              borderRadius: BorderRadius.only(
                bottomLeft: Radius.circular(30),
                bottomRight: Radius.circular(30),
              ),
            ),
            child: Row(
              children: [
                const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.pets, color: Colors.teal, size: 30)),
                const SizedBox(width: 15),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text("Welcome back!", style: TextStyle(color: Colors.white70, fontSize: 14)),
                    Text("Role: $_userRole", style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
                  ],
                ),
              ],
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: ListView(
                children: [
                  const Text("Quick Actions", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  _buildMenuCard(context, "Community Forum", "Join discussions with other owners", Icons.forum, Colors.deepPurple, const ForumPage()),
                  _buildMenuCard(context, "Lost & Found", "Report and find missing pets", Icons.location_on, Colors.orange, const LostAndFoundPage()),
                  _buildMenuCard(context, "Pet Adoption", "Find a forever home for pets", Icons.pets, Colors.green, const PetAdoptionPage()),
                  _buildMenuCard(context, "Pet Education", "Learn how to care for your pet", Icons.menu_book, Colors.blue, const EducationPage()),
                  if (_userRole == 'Admin') ...[
                    const Divider(height: 30),
                    const Text("Admin Tools", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.teal)),
                    const SizedBox(height: 10),
                    _buildMenuCard(context, "Approve Posts", "Review pending pet adoption posts", Icons.fact_check, Colors.teal, const AdminApprovalPage()),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget destination) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
      child: ListTile(
        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        leading: CircleAvatar(
          backgroundColor: color.withOpacity(0.1),
          child: Icon(icon, color: color),
        ),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(subtitle, style: const TextStyle(fontSize: 12)),
        trailing: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      ),
    );
  }
}
