import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

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
      home: StreamBuilder<AuthState>(
        stream: Supabase.instance.client.auth.onAuthStateChange,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Scaffold(body: Center(child: CircularProgressIndicator()));
          }
          final session = snapshot.data?.session;
          if (session != null) {
            return const MainNavigation();
          } else {
            return const LoginPage();
          }
        },
      ),
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
  int _totalUnreadChats = 0; // 新增：全局未读聊天总数
  Timer? _chatBadgeTimer;
  final _supabase = Supabase.instance.client;

  final List<Widget> _pages = [
    const ExpenseTrackingPage(), // Index 0
    const ChatModuleList(),      // Index 1
    const HomePage(),            // Index 2
    const PetProfilePage(),      // Index 3
    const ProfilePage(),         // Index 4
  ];

  @override
  void initState() {
    super.initState();
    _fetchUnreadChats();
    // 每隔 3 秒刷新一次全局未读消息数量
    _chatBadgeTimer = Timer.periodic(const Duration(seconds: 3), (_) => _fetchUnreadChats());
  }

  @override
  void dispose() {
    _chatBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUnreadChats() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      try {
        final res = await _supabase.rpc('get_total_unread_chats', params: {'user_id': user.id});
        if (mounted) setState(() => _totalUnreadChats = (res as num).toInt());
      } catch (e) {
        debugPrint("Error fetching unread chats: $e");
      }
    }
  }

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
        items: [
          const BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: "Expense"),
          // Chat 图标加上了 Badge 提醒
          BottomNavigationBarItem(
            icon: Badge(
              isLabelVisible: _totalUnreadChats > 0,
              label: Text(_totalUnreadChats.toString()),
              child: const Icon(Icons.chat),
            ),
            label: "Chat",
          ),
          const BottomNavigationBarItem(icon: Icon(Icons.home), label: "Home"),
          const BottomNavigationBarItem(icon: Icon(Icons.pets), label: "Pet"),
          const BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profile"),
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
  int _adminPendingCount = 0;
  Timer? _adminBadgeTimer;

  late final Stream<List<Map<String, dynamic>>> _notificationStream;

  @override
  void initState() {
    super.initState();
    _notificationStream = Supabase.instance.client
        .from('system_notifications')
        .stream(primaryKey: ['id']);

    _fetchUserRole().then((_) {
      if (_userRole == 'Admin') {
        _fetchAdminPendingCount();
        _adminBadgeTimer = Timer.periodic(const Duration(seconds: 5), (t) => _fetchAdminPendingCount());
      }
    });
  }

  @override
  void dispose() {
    _adminBadgeTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchUserRole() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      try {
        final data = await Supabase.instance.client.from('users').select('role').eq('userID', user.id).single();
        if (mounted) setState(() => _userRole = data['role'] ?? 'User');
      } catch (e) {
        debugPrint("Error fetching role: $e");
      }
    }
  }

  Future<void> _fetchAdminPendingCount() async {
    int total = 0;
    final tables = ['adoption_posts', 'lost_post', 'found_post', 'pet_material', 'forum_post'];
    try {
      for (var table in tables) {
        final data = await Supabase.instance.client.from(table).select('isApproved');
        total += data.where((item) => item['isApproved'] == false || item['isApproved'] == null).length;
      }
      if (mounted) setState(() => _adminPendingCount = total);
    } catch (e) {
      debugPrint("Error fetching admin badge count: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    final myID = Supabase.instance.client.auth.currentUser?.id ?? '';

    return Scaffold(
      appBar: AppBar(
        title: const Text("PetCare Hub", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        actions: [
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _notificationStream,
            builder: (context, snapshot) {
              int unreadCount = 0;
              if (snapshot.hasData) {
                unreadCount = snapshot.data!.where((n) {
                  return n['userID'] == myID && n['isRead'] == false;
                }).length;
              }
              return IconButton(
                icon: Badge(
                  isLabelVisible: unreadCount > 0,
                  label: Text(unreadCount.toString()),
                  child: const Icon(Icons.notifications),
                ),
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => const SystemNotificationsPage()));
                },
              );
            },
          ),
        ],
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
                    _buildMenuCard(
                      context, "Approve Posts", "Review pending posts", Icons.fact_check, Colors.teal, const AdminApprovalPage(),
                      trailing: _adminPendingCount > 0
                          ? Badge(
                        label: Text(_adminPendingCount.toString()),
                        child: const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                      )
                          : const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
                    ),
                  ]
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMenuCard(BuildContext context, String title, String subtitle, IconData icon, Color color, Widget destination, {Widget? trailing}) {
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
        trailing: trailing ?? const Icon(Icons.arrow_forward_ios, size: 16, color: Colors.grey),
        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => destination)),
      ),
    );
  }
}

// ==========================================
// 全新页面：用户专属的通知中心列表
// ==========================================
class SystemNotificationsPage extends StatefulWidget {
  const SystemNotificationsPage({super.key});

  @override
  State<SystemNotificationsPage> createState() => _SystemNotificationsPageState();
}

class _SystemNotificationsPageState extends State<SystemNotificationsPage> {
  final _supabase = Supabase.instance.client;
  String get _myID => _supabase.auth.currentUser!.id;
  late final Stream<List<Map<String, dynamic>>> _pageNotificationStream;

  @override
  void initState() {
    super.initState();
    _pageNotificationStream = _supabase.from('system_notifications').stream(primaryKey: ['id']);
  }

  Future<void> _markAsRead(String id) async {
    await _supabase.from('system_notifications').update({'isRead': true}).eq('id', id);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Notifications"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _pageNotificationStream,
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          List<Map<String, dynamic>> items = snapshot.data!
              .where((n) => n['userID'] == _myID)
              .toList();

          items.sort((a, b) {
            final aTime = DateTime.tryParse(a['createdAt']?.toString() ?? '') ?? DateTime.now();
            final bTime = DateTime.tryParse(b['createdAt']?.toString() ?? '') ?? DateTime.now();
            return bTime.compareTo(aTime);
          });

          if (items.isEmpty) return const Center(child: Text("No notifications yet.", style: TextStyle(color: Colors.grey)));

          return ListView.builder(
            itemCount: items.length,
            itemBuilder: (context, index) {
              final notif = items[index];
              final bool isRead = notif['isRead'] == true;

              String timeString = '';
              if (notif['createdAt'] != null) {
                try {
                  final date = DateTime.parse(notif['createdAt']).toLocal();
                  timeString = DateFormat('MMM dd, hh:mm a').format(date);
                } catch (e) {}
              }

              return ListTile(
                tileColor: isRead ? Colors.transparent : Colors.teal.shade50,
                leading: CircleAvatar(
                  backgroundColor: isRead ? Colors.grey.shade200 : Colors.teal.shade100,
                  child: Icon(
                    notif['title'].toString().contains('Approved') ? Icons.check_circle : Icons.error,
                    color: notif['title'].toString().contains('Approved') ? Colors.green : Colors.red,
                  ),
                ),
                title: Text(notif['title'] ?? '', style: TextStyle(fontWeight: isRead ? FontWeight.normal : FontWeight.bold)),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4),
                    Text(notif['message'] ?? ''),
                    const SizedBox(height: 4),
                    Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                  ],
                ),
                onTap: () {
                  if (!isRead) _markAsRead(notif['id']);
                },
              );
            },
          );
        },
      ),
    );
  }
}