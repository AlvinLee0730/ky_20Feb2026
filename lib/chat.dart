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
    // Poll the list every 5 seconds to update the recent chats view
    _listTimer = Timer.periodic(const Duration(seconds: 5), (timer) => _fetchRecentChats());
  }

  @override
  void dispose() {
    _listTimer?.cancel();
    super.dispose();
  }

  // --- Logic to find users you have sent messages to or received messages from ---
  Future<void> _fetchRecentChats() async {
    try {
      // 1. Get messages where I am the sender
      final sentData = await _supabase.from('Message').select('userID').eq('userID', _myID);

      // 2. Get message IDs targeted at me from PrivateMessage table
      final receivedPMs = await _supabase.from('PrivateMessage').select('messageID').eq('userID', _myID);
      final List<String> msgIDs = (receivedPMs as List).map((e) => e['messageID'] as String).toList();

      // 3. Get the actual messages that were sent to me
      List<dynamic> receivedMessages = [];
      if (msgIDs.isNotEmpty) {
        receivedMessages = await _supabase.from('Message').select('userID').inFilter('messageID', msgIDs);
      }

      // Collect all partner IDs
      final Set<String> partnerIDs = {};
      for (var m in receivedMessages) {
        partnerIDs.add(m['userID']);
      }

      // Check PrivateMessage table for people I sent messages TO
      final mySentPMs = await _supabase.from('PrivateMessage').select('userID');
      // This identifies who the recipient was for my sent messages
      for (var p in (mySentPMs as List)) {
        partnerIDs.add(p['userID']);
      }

      partnerIDs.remove(_myID); // Don't show myself

      if (partnerIDs.isEmpty) return;

      final usersData = await _supabase.from('users').select().inFilter('userID', partnerIDs.toList());
      if (mounted) {
        setState(() {
          _recentConversations = List<Map<String, dynamic>>.from(usersData);
        });
      }
    } catch (e) {
      debugPrint("List fetch error: $e");
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

  void _createGroup() {
    // Implementation for Table 4.10 ChatGroup would go here
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Group Chat feature initiated")));
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
                Expanded(child: ElevatedButton.icon(onPressed: _createGroup, icon: const Icon(Icons.group_add), label: const Text("Group"))),
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
                return ListTile(
                  leading: CircleAvatar(backgroundColor: Colors.teal, child: Text(user['userName'][0], style: const TextStyle(color: Colors.white))),
                  title: Text(user['userName']),
                  subtitle: Text(user['userEmail']),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: user['userID'], title: user['userName']))),
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
  final String? targetUserID;
  final String title;
  const ChatPage({super.key, this.targetUserID, required this.title});

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
      // 1. Get IDs of messages sent specifically to ME
      final pmIn = await _supabase.from('PrivateMessage').select('messageID').eq('userID', _myID);
      final List<String> myInbox = (pmIn as List).map((e) => e['messageID'] as String).toList();

      // 2. Get IDs of messages I sent to THE OTHER USER
      final pmOut = await _supabase.from('PrivateMessage').select('messageID').eq('userID', widget.targetUserID!);
      final List<String> myOutbox = (pmOut as List).map((e) => e['messageID'] as String).toList();

      // 3. Fetch the content from Table 4.7
      final List<String> combinedIDs = [...myInbox, ...myOutbox];
      if (combinedIDs.isEmpty) return;

      final data = await _supabase
          .from('Message')
          .select()
          .inFilter('messageID', combinedIDs)
          .order('timestamp', ascending: false);

      final List<Map<String, dynamic>> filtered = List<Map<String, dynamic>>.from(data).where((m) {
        // Double check to ensure we only show messages where the sender is either me or them
        return m['userID'] == _myID || m['userID'] == widget.targetUserID;
      }).toList();

      if (mounted) setState(() => _messages = filtered);
    } catch (e) {
      debugPrint("Chat Load Error: $e");
    }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;

    final String msgID = "MSG${Random().nextInt(99999).toString().padLeft(5, '0')}";

    // Optimistic Update: Add to list immediately
    setState(() {
      _messages.insert(0, {
        'messageID': msgID,
        'userID': _myID,
        'text': text,
        'timestamp': DateTime.now().toIso8601String(),
      });
    });
    _msgController.clear();

    try {
      // Table 4.7
      await _supabase.from('Message').insert({
        'messageID': msgID,
        'userID': _myID,
        'text': text,
        'isEdited': false,
        'isDeleted': false,
      });

      // Table 4.8: Targeted specifically to the receiver
      await _supabase.from('PrivateMessage').insert({
        'privateMsgID': "PMSG${Random().nextInt(99999).toString().padLeft(5, '0')}",
        'messageID': msgID,
        'userID': widget.targetUserID,
        'isSeen': false,
      });
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