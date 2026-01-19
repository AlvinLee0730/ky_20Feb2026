import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'userModule/login_page.dart';
import 'userModule/profile_page.dart';
import 'petModule/petProfile.dart';


const String supabaseUrl ='https://zbmxmfnsqlkzguumlfip.supabase.co';
const String supabaseKey ='eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InpibXhtZm5zcWxremd1dW1sZmlwIiwicm9sZSI6ImFub24iLCJpYXQiOjE3Njg2NDc0NDUsImV4cCI6MjA4NDIyMzQ0NX0.c7esc22nznThDauT9wKUDvXHdSMZGqECyPFw6I4GQ4Y';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Supabase.initialize(
    url: supabaseUrl,
    anonKey: supabaseKey,
  );
  runApp(const MyApp());
}

final supabase = Supabase.instance.client;

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
      ),
      home: const LoginPage(), // 默认启动 LoginPage
      debugShowCheckedModeBanner: false,
    );
  }
}

// ==================== Home Page + BottomNavigationBar ====================
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  int _currentIndex = 2; // 默认选中中间 Home icon

  final List<Widget> _pages = [
    const Center(child: Text('Module 1')),
    const Center(child: Text('Module 2 Placeholder')),
    const Center(child: Text('Home Page')), // 中间 Home
    const Center(child: PetProfilePage()),
    const Center(child: ProfilePage()),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _pages[_currentIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _currentIndex,
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.deepPurple,
        unselectedItemColor: Colors.grey,
        onTap: (index) {
          setState(() {
            _currentIndex = index;
          });
        },
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.dashboard),
            label: 'Tab 1',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.notifications),
            label: 'Tab 2',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.home, size: 35),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.pets),
            label: 'Pet Profile',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person),
            label: 'User Profile',
          ),
        ],
      ),
    );
  }
}
