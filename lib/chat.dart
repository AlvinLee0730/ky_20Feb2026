import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'dart:math';

class ChatModuleList extends StatefulWidget {
  const ChatModuleList({super.key});

  @override
  State<ChatModuleList> createState() => _ChatModuleListState();
}

class _ChatModuleListState extends State<ChatModuleList> {
  final _supabase = Supabase.instance.client;
  String get _myID => _supabase.auth.currentUser!.id;
  List<Map<String, dynamic>> _recentConversations = [];
  Timer? _listTimer;

  @override
  void initState() {
    super.initState();
    _fetchRecentChats();
    _listTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchRecentChats());
  }

  @override
  void dispose() {
    _listTimer?.cancel();
    super.dispose();
  }

  Future<void> _fetchRecentChats() async {
    try {
      // Fetching from the view you created
      final data = await _supabase
          .from('recent_chats_view')
          .select()
          .order('timestamp', ascending: false);

      if (mounted) {
        setState(() {
          _recentConversations = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Recent Chats Error: $e");
    }
  }

  void _searchUserByEmail() async {
    final emailController = TextEditingController();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text("Search User by Email"),
        content: TextField(controller: emailController, decoration: const InputDecoration(hintText: "example@gmail.com")),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(
            onPressed: () async {
              final res = await _supabase.from('users').select().eq('userEmail', emailController.text.trim()).maybeSingle();
              if (res != null) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: res['userID'], title: res['userName'])));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found")));
              }
            },
            child: const Text("Chat"),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Chats"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(onPressed: _searchUserByEmail, icon: const Icon(Icons.search), label: const Text("Email"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(onPressed: () {}, icon: const Icon(Icons.group_add), label: const Text("Group"))),
              ],
            ),
          ),
          const Divider(),
          Expanded(
            child: _recentConversations.isEmpty
                ? const Center(child: Text("No recent chats. Search an email to start!"))
                : ListView.builder(
              itemCount: _recentConversations.length,
              itemBuilder: (context, index) {
                final user = _recentConversations[index];
                // Note: Depending on your view, the keys might be 'partner_id' or 'userID'
                final String partnerId = user['partner_id'] ?? user['userID'];
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.teal, child: Text(user['userName'][0], style: const TextStyle(color: Colors.white))),
                  title: Text(user['userName']),
                  subtitle: Text(user['last_message'] ?? user['userEmail']),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: partnerId, title: user['userName']))),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class ChatPage extends StatefulWidget {
  final String targetUserID;
  final String title;
  const ChatPage({super.key, required this.targetUserID, required this.title});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _supabase = Supabase.instance.client;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;
  String get _myID => _supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _loadMessages());
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
      // This calls the SQL function we just fixed above
      final List<dynamic> data = await _supabase.rpc('get_chat_history', params: {
        'me': _myID,
        'them': widget.targetUserID,
      });

      if (mounted) {
        setState(() {
          _messages = List<Map<String, dynamic>>.from(data);
        });
      }
    } catch (e) {
      debugPrint("Chat Load Error: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final String msgID = "MSG${Random().nextInt(999999)}";

    _msgController.clear();

    try {
      await _supabase.from('Message').insert({
        'messageID': msgID,
        'userID': _myID,
        'text': text,
      });

      await _supabase.from('PrivateMessage').insert({
        'privateMsgID': "PMSG${Random().nextInt(999999)}",
        'messageID': msgID,
        'userID': widget.targetUserID,
      });

      _loadMessages(); // Refresh immediately
    } catch (e) {
      debugPrint("Send Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true,
              controller: _scrollController,
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];
                final isMe = msg['userID'] == _myID;
                return Align(
                  alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 12),
                    decoration: BoxDecoration(
                      color: isMe ? Colors.teal : Colors.grey[300],
                      borderRadius: BorderRadius.circular(15),
                    ),
                    child: Text(msg['text'] ?? "", style: TextStyle(color: isMe ? Colors.white : Colors.black)),
                  ),
                );
              },
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(8.0),
            child: Row(
              children: [
                Expanded(child: TextField(controller: _msgController, decoration: const InputDecoration(hintText: "Type a message..."))),
                IconButton(icon: const Icon(Icons.send, color: Colors.teal), onPressed: _sendMessage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}