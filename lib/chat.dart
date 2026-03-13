import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // 引入 intl 以格式化 12小时制时间
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
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
            onPressed: () async {
              final res = await _supabase.from('users').select().eq('userEmail', emailController.text.trim()).maybeSingle();
              if (res != null) {
                Navigator.pop(context);
                Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: res['userID'], title: res['userName'])));
              } else {
                ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("User not found")));
              }
            },
            child: const Text("Chat", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(title: const Text("Chats"), backgroundColor: Colors.teal, foregroundColor: Colors.white, elevation: 0),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(
                    child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: _searchUserByEmail,
                        icon: const Icon(Icons.search, size: 18),
                        label: const Text("Search Email")
                    )
                ),
                const SizedBox(width: 10),
                Expanded(
                    child: ElevatedButton.icon(
                        style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))),
                        onPressed: () {},
                        icon: const Icon(Icons.group_add, size: 18),
                        label: const Text("New Group")
                    )
                ),
              ],
            ),
          ),
          Expanded(
            child: _recentConversations.isEmpty
                ? const Center(child: Text("No recent chats. Search an email to start!", style: TextStyle(color: Colors.grey)))
                : ListView.builder(
              itemCount: _recentConversations.length,
              itemBuilder: (context, index) {
                final user = _recentConversations[index];
                final String partnerId = user['partner_id'] ?? user['userID'];
                final String name = user['userName'] ?? 'Unknown';
                final String? avatarUrl = user['userPhoto'];

                // 格式化列表时间
                String timeString = '';
                if (user['timestamp'] != null) {
                  try {
                    final date = DateTime.parse(user['timestamp']).toLocal();
                    // 如果是今天就显示时间，否则显示日期
                    if (date.day == DateTime.now().day && date.month == DateTime.now().month) {
                      timeString = DateFormat('hh:mm a').format(date);
                    } else {
                      timeString = DateFormat('MMM dd').format(date);
                    }
                  } catch(e) { }
                }

                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: Colors.teal.shade100,
                    backgroundImage: avatarUrl != null && avatarUrl.isNotEmpty ? NetworkImage(avatarUrl) : null,
                    child: (avatarUrl == null || avatarUrl.isEmpty)
                        ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold))
                        : null,
                  ),
                  title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                  subtitle: Text(
                    user['last_message'] ?? user['userEmail'] ?? '',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(color: Colors.black54),
                  ),
                  trailing: Text(timeString, style: const TextStyle(fontSize: 12, color: Colors.grey)),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: partnerId, title: name))),
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
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _loadMessages() async {
    try {
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

    final String msgID = "MSG${Random().nextInt(99999999)}";
    _msgController.clear();

    try {
      await _supabase.from('Message').insert({
        'messageID': msgID,
        'userID': _myID,
        'text': text,
        // timestamp 是由 supabase 自动生成的
      });

      await _supabase.from('PrivateMessage').insert({
        'privateMsgID': "PMSG${Random().nextInt(99999999)}",
        'messageID': msgID,
        'userID': widget.targetUserID,
      });

      _loadMessages();
    } catch (e) {
      debugPrint("Send Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.title, style: const TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 1,
      ),
      body: Column(
        children: [
          Expanded(
            child: ListView.builder(
              reverse: true, // 保持最新消息在最下面
              controller: _scrollController,
              padding: const EdgeInsets.symmetric(vertical: 10),
              itemCount: _messages.length,
              itemBuilder: (context, index) {
                final msg = _messages[index];

                // 从我们升级后的 SQL 函数获取资料
                final bool isMe = msg['sender_id'] == _myID;
                final String senderName = msg['sender_name'] ?? (isMe ? 'Me' : widget.title);
                final String? senderPhoto = msg['sender_photo'];

                // --- 转换并格式化 12 小时制时间 ---
                String timeString = '';
                if (msg['timestamp'] != null) {
                  try {
                    final date = DateTime.parse(msg['timestamp']).toLocal();
                    timeString = DateFormat('hh:mm a').format(date); // 例: 10:30 AM
                  } catch (e) {
                    timeString = '';
                  }
                }

                // --- 抽取头像部件 ---
                Widget avatar = CircleAvatar(
                  radius: 16,
                  backgroundColor: Colors.teal.shade200,
                  backgroundImage: senderPhoto != null && senderPhoto.isNotEmpty ? NetworkImage(senderPhoto) : null,
                  child: (senderPhoto == null || senderPhoto.isEmpty)
                      ? Text(senderName.isNotEmpty ? senderName[0].toUpperCase() : '?', style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold))
                      : null,
                );

                return Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                  child: Row(
                    mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.end, // 头像和气泡底部对齐
                    children: [
                      // 如果不是我，头像在左边
                      if (!isMe) ...[
                        avatar,
                        const SizedBox(width: 8),
                      ],

                      // 消息体
                      Flexible(
                        child: Column(
                          crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                          children: [
                            // 名字
                            Text(senderName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            const SizedBox(height: 2),

                            // 对话气泡
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                              decoration: BoxDecoration(
                                  color: isMe ? Colors.teal : Colors.white,
                                  border: isMe ? null : Border.all(color: Colors.grey.shade300),
                                  borderRadius: BorderRadius.only(
                                    topLeft: const Radius.circular(15),
                                    topRight: const Radius.circular(15),
                                    // 关键细节：聊天气泡指向头像的那个角设为直角
                                    bottomLeft: isMe ? const Radius.circular(15) : const Radius.circular(2),
                                    bottomRight: isMe ? const Radius.circular(2) : const Radius.circular(15),
                                  ),
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.black.withOpacity(0.05),
                                      offset: const Offset(0, 1),
                                      blurRadius: 2,
                                    )
                                  ]
                              ),
                              child: Text(msg['text'] ?? "", style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                            ),

                            // 12小时制时间
                            const SizedBox(height: 4),
                            Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                          ],
                        ),
                      ),

                      // 如果是我，头像在右边
                      if (isMe) ...[
                        const SizedBox(width: 8),
                        avatar,
                      ],
                    ],
                  ),
                );
              },
            ),
          ),

          // 底部输入框
          Container(
            padding: EdgeInsets.fromLTRB(10, 10, 10, MediaQuery.of(context).padding.bottom + 10),
            decoration: BoxDecoration(
                color: Colors.white,
                border: Border(top: BorderSide(color: Colors.grey.shade300))
            ),
            child: Row(
              children: [
                Expanded(
                    child: TextField(
                        controller: _msgController,
                        decoration: InputDecoration(
                            hintText: "Type a message...",
                            filled: true,
                            fillColor: Colors.grey[100],
                            contentPadding: const EdgeInsets.symmetric(horizontal: 15, vertical: 10),
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(25),
                              borderSide: BorderSide.none,
                            )
                        )
                    )
                ),
                const SizedBox(width: 8),
                Container(
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: IconButton(
                      icon: const Icon(Icons.send, color: Colors.white, size: 20),
                      onPressed: _sendMessage
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}