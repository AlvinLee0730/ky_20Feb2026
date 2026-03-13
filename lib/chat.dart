import 'dart:async';
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math';

// ==========================================
// 1. 聊天列表主页 (加入红点展示)
// ==========================================
class ChatModuleList extends StatefulWidget {
  const ChatModuleList({super.key});

  @override
  State<ChatModuleList> createState() => _ChatModuleListState();
}

class _ChatModuleListState extends State<ChatModuleList> with SingleTickerProviderStateMixin {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _recentConversations = [];
  List<Map<String, dynamic>> _myGroups = [];

  Map<String, int> _privateUnread = {};
  Map<String, int> _groupUnread = {};

  Timer? _listTimer;
  late TabController _tabController;

  String get _myID => _supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _fetchData();
    _listTimer = Timer.periodic(const Duration(seconds: 3), (timer) => _fetchData());
  }

  @override
  void dispose() {
    _listTimer?.cancel();
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _fetchData() async {
    _fetchRecentChats();
    _fetchMyGroups();
    _fetchUnreadCounts();
  }

  Future<void> _fetchUnreadCounts() async {
    try {
      final pRes = await _supabase.rpc('get_private_unread_counts', params: {'my_id': _myID});
      final gRes = await _supabase.rpc('get_group_unread_counts', params: {'my_id': _myID});

      if (mounted) {
        setState(() {
          _privateUnread = { for (var item in pRes) item['sender_id']: (item['unread_count'] as num).toInt() };
          _groupUnread = { for (var item in gRes) item['group_id']: (item['unread_count'] as num).toInt() };
        });
      }
    } catch (e) {
      debugPrint("Unread Count Error: $e");
    }
  }

  Future<void> _fetchRecentChats() async {
    try {
      final data = await _supabase.from('recent_chats_view').select().order('timestamp', ascending: false);
      if (mounted) setState(() => _recentConversations = List<Map<String, dynamic>>.from(data));
    } catch (e) {}
  }

  Future<void> _fetchMyGroups() async {
    try {
      final data = await _supabase
          .from('ChatGroup')
          .select('*, GroupMembers!inner(*)')
          .eq('GroupMembers.userID', _myID)
          .order('createdAt', ascending: false);
      if (mounted) setState(() => _myGroups = List<Map<String, dynamic>>.from(data));
    } catch (e) {}
  }

  void _searchUserByEmail() async {
    final emailController = TextEditingController();
    String? errorMessage;
    bool isLoading = false;

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Search User"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(controller: emailController, decoration: const InputDecoration(hintText: "example@gmail.com")),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel", style: TextStyle(color: Colors.grey))),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: isLoading ? null : () async {
                    setStateDialog(() { isLoading = true; errorMessage = null; });
                    final res = await _supabase.from('users').select().eq('userEmail', emailController.text.trim()).maybeSingle();
                    setStateDialog(() => isLoading = false);

                    if (res != null) {
                      if (!mounted) return;
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: res['userID'], title: res['userName'])));
                    } else {
                      setStateDialog(() => errorMessage = "User not found in database!");
                    }
                  },
                  child: isLoading ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Chat", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Chats", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
        elevation: 0,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: Colors.white,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.teal.shade100,
          tabs: const [Tab(text: "Private"), Tab(text: "Groups")],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: _searchUserByEmail, icon: const Icon(Icons.search, size: 18), label: const Text("Search Email"))),
                const SizedBox(width: 10),
                Expanded(child: ElevatedButton.icon(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20))), onPressed: () => showDialog(context: context, builder: (_) => const CreateGroupDialog()), icon: const Icon(Icons.group_add, size: 18), label: const Text("New Group"))),
              ],
            ),
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // 私聊列表
                _recentConversations.isEmpty
                    ? const Center(child: Text("No recent chats. Search an email to start!", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  itemCount: _recentConversations.length,
                  itemBuilder: (context, index) {
                    final user = _recentConversations[index];
                    final String partnerId = user['partner_id'] ?? user['userID'];
                    final String name = user['userName'] ?? 'Unknown';
                    final String? avatarUrl = user['userPhoto'];

                    int unreadCount = _privateUnread[partnerId] ?? 0;

                    String timeString = '';
                    if (user['timestamp'] != null) {
                      try {
                        final date = DateTime.parse(user['timestamp']).toLocal();
                        timeString = (date.day == DateTime.now().day && date.month == DateTime.now().month)
                            ? DateFormat('hh:mm a').format(date) : DateFormat('MMM dd').format(date);
                      } catch (e) {}
                    }
                    return ListTile(
                      leading: CircleAvatar(
                        backgroundColor: Colors.teal.shade100, backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        child: avatarUrl == null ? Text(name.isNotEmpty ? name[0].toUpperCase() : '?', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)) : null,
                      ),
                      title: Text(name, style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(user['last_message'] ?? '', maxLines: 1, overflow: TextOverflow.ellipsis, style: TextStyle(color: unreadCount > 0 ? Colors.black87 : Colors.black54, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                      trailing: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Text(timeString, style: TextStyle(fontSize: 12, color: unreadCount > 0 ? Colors.teal : Colors.grey, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                          if (unreadCount > 0)
                            Container(
                              margin: const EdgeInsets.only(top: 4),
                              padding: const EdgeInsets.all(6),
                              decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                              child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                            ),
                        ],
                      ),
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ChatPage(targetUserID: partnerId, title: name))),
                    );
                  },
                ),
                // 群聊列表
                _myGroups.isEmpty
                    ? const Center(child: Text("No groups yet. Create one!", style: TextStyle(color: Colors.grey)))
                    : ListView.builder(
                  itemCount: _myGroups.length,
                  itemBuilder: (context, index) {
                    final group = _myGroups[index];
                    final String groupId = group['chatGroupID'];
                    int unreadCount = _groupUnread[groupId] ?? 0;

                    return ListTile(
                      leading: CircleAvatar(backgroundColor: Colors.orange.shade100, child: const Icon(Icons.group, color: Colors.orange)),
                      title: Text(group['groupName'] ?? 'Unnamed Group', style: const TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text("Tap to enter group chat", style: TextStyle(color: unreadCount > 0 ? Colors.black87 : Colors.grey, fontSize: 12, fontWeight: unreadCount > 0 ? FontWeight.bold : FontWeight.normal)),
                      trailing: unreadCount > 0
                          ? Container(
                        padding: const EdgeInsets.all(6),
                        decoration: const BoxDecoration(color: Colors.red, shape: BoxShape.circle),
                        child: Text(unreadCount.toString(), style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold)),
                      )
                          : null,
                      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupID: groupId, groupName: group['groupName']))),
                    );
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ==========================================
// 2. 创建群组对话框 (建立时分配 Owner 身份)
// ==========================================
class CreateGroupDialog extends StatefulWidget {
  const CreateGroupDialog({super.key});
  @override
  State<CreateGroupDialog> createState() => _CreateGroupDialogState();
}

class _CreateGroupDialogState extends State<CreateGroupDialog> {
  final _supabase = Supabase.instance.client;
  final _groupNameController = TextEditingController();
  final _emailController = TextEditingController();
  final List<Map<String, dynamic>> _selectedUsers = [];
  bool _isLoading = false;
  String? _errorMessage;

  void _addEmail() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) return;

    setState(() { _errorMessage = null; _isLoading = true; });

    if (_selectedUsers.any((u) => u['userEmail'] == email)) {
      setState(() { _errorMessage = "User already added in the list!"; _isLoading = false; });
      return;
    }

    try {
      final res = await _supabase.from('users').select().eq('userEmail', email).maybeSingle();
      if (res != null) {
        if (res['userID'] == _supabase.auth.currentUser!.id) {
          setState(() => _errorMessage = "You will be the Owner automatically!");
        } else {
          setState(() { _selectedUsers.add(res); _emailController.clear(); });
        }
      } else {
        setState(() => _errorMessage = "User not found in database!");
      }
    } catch (e) {
      setState(() => _errorMessage = "Error checking user.");
    }
    setState(() => _isLoading = false);
  }

  Future<void> _createGroup() async {
    final groupName = _groupNameController.text.trim();
    setState(() => _errorMessage = null);

    if (groupName.isEmpty || _selectedUsers.isEmpty) {
      setState(() => _errorMessage = "Please enter group name & add at least 1 user.");
      return;
    }

    setState(() => _isLoading = true);
    try {
      final String groupID = "CG${Random().nextInt(99999999)}";
      final String myID = _supabase.auth.currentUser!.id;
      await _supabase.from('ChatGroup').insert({'chatGroupID': groupID, 'groupName': groupName, 'isPublic': false});

      // 创建者设为 Owner
      await _supabase.from('GroupMembers').insert({'chatGroupID': groupID, 'userID': myID, 'role': 'Owner'});

      final membersData = _selectedUsers.map((u) => {'chatGroupID': groupID, 'userID': u['userID'], 'role': 'Member'}).toList();
      await _supabase.from('GroupMembers').insert(membersData);

      if (mounted) {
        Navigator.pop(context);
        Navigator.push(context, MaterialPageRoute(builder: (_) => GroupChatPage(groupID: groupID, groupName: groupName)));
      }
    } catch (e) {
      setState(() => _errorMessage = "Failed to create group.");
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text("Create Group"),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(controller: _groupNameController, decoration: const InputDecoration(labelText: "Group Name", border: OutlineInputBorder())),
            const SizedBox(height: 15),
            Row(
              children: [
                Expanded(child: TextField(controller: _emailController, decoration: const InputDecoration(hintText: "user@email.com", isDense: true))),
                IconButton(
                    icon: _isLoading ? const SizedBox(width:20, height:20, child: CircularProgressIndicator(strokeWidth: 2)) : const Icon(Icons.add_circle, color: Colors.teal),
                    onPressed: _isLoading ? null : _addEmail
                )
              ],
            ),
            if (_errorMessage != null) ...[
              const SizedBox(height: 5),
              Text(_errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: _selectedUsers.map((u) => Chip(
                label: Text(u['userName'] ?? u['userEmail'], style: const TextStyle(fontSize: 12)),
                deleteIcon: const Icon(Icons.cancel, size: 16),
                onDeleted: () => setState(() => _selectedUsers.remove(u)),
              )).toList(),
            )
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(style: ElevatedButton.styleFrom(backgroundColor: Colors.teal), onPressed: _isLoading ? null : _createGroup, child: const Text("Create", style: TextStyle(color: Colors.white))),
      ],
    );
  }
}

// ==========================================
// 3. 私聊页面 (加入已读标记功能)
// ==========================================
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
    _markAsRead();
    _loadMessages();
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages();
      _markAsRead(); // 不断把对方新发来的标记为已读
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  // 通知数据库：把对方发给我的消息标为已读
  Future<void> _markAsRead() async {
    try {
      await _supabase.rpc('mark_private_messages_read', params: {
        'sender_id': widget.targetUserID,
        'receiver_id': _myID
      });
    } catch (e) {}
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase.rpc('get_chat_history', params: {'me': _myID, 'them': widget.targetUserID});
      if (mounted) setState(() => _messages = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("Chat Load Error: $e"); }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    try {
      final String msgID = "MSG${Random().nextInt(99999999)}";
      await _supabase.from('Message').insert({'messageID': msgID, 'userID': _myID, 'text': text});
      await _supabase.from('PrivateMessage').insert({'privateMsgID': "PMSG${Random().nextInt(99999999)}", 'messageID': msgID, 'userID': widget.targetUserID});
      _loadMessages();
    } catch (e) {}
  }

  Future<void> _showEditDialog(String messageID, String oldText) async {
    final editController = TextEditingController(text: oldText);
    showDialog(context: context, builder: (context) => AlertDialog(
      title: const Text("Edit Message"),
      content: TextField(controller: editController, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
        ElevatedButton(
          style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
          onPressed: () async {
            if (editController.text.trim().isNotEmpty && editController.text != oldText) {
              await _supabase.rpc('edit_message', params: {'msg_id': messageID, 'new_text': editController.text.trim()});
              _loadMessages();
            }
            if (mounted) Navigator.pop(context);
          }, child: const Text("Save", style: TextStyle(color: Colors.white)),
        ),
      ],
    ));
  }

  Future<void> _unsendGlobal(String messageID) async {
    await _supabase.rpc('delete_message_global', params: {'msg_id': messageID});
    _loadMessages();
  }

  Future<void> _deleteLocal(String messageID) async {
    await _supabase.rpc('delete_message_local', params: {'msg_id': messageID});
    _loadMessages();
  }

  Widget _buildMessageMenu(Map<String, dynamic> msg, bool isMe) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') _showEditDialog(msg['messageID'], msg['text']);
        if (value == 'unsend') _unsendGlobal(msg['messageID']);
        if (value == 'delete_local') _deleteLocal(msg['messageID']);
      },
      itemBuilder: (context) => [
        if (isMe) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (isMe) const PopupMenuItem(value: 'unsend', child: Text('Unsend (Everyone)', style: TextStyle(color: Colors.red))),
        const PopupMenuItem(value: 'delete_local', child: Text('Delete for me')),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(title: Text(widget.title), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: ListView.builder(
                reverse: true, controller: _scrollController, padding: const EdgeInsets.symmetric(vertical: 10), itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final bool isMe = msg['sender_id'] == _myID;
                  final senderName = msg['sender_name'] ?? (isMe ? 'Me' : widget.title);
                  String timeString = '';
                  if (msg['timestamp'] != null) {
                    try { timeString = DateFormat('hh:mm a').format(DateTime.parse(msg['timestamp']).toLocal()); } catch (e) {}
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) CircleAvatar(radius: 16, backgroundColor: Colors.teal.shade200, child: Text(senderName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                        if (!isMe) const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                if (isMe) _buildMessageMenu(msg, isMe),
                                Text(senderName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (!isMe) _buildMessageMenu(msg, isMe),
                              ]),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                decoration: BoxDecoration(color: isMe ? Colors.teal : Colors.white, borderRadius: BorderRadius.circular(15), border: isMe ? null : Border.all(color: Colors.grey.shade300)),
                                child: Text(msg['text'] ?? "", style: TextStyle(color: isMe ? Colors.white : Colors.black87, fontSize: 15)),
                              ),
                              Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10), color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Type a message...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
                  const SizedBox(width: 8),
                  Container(decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 4. 群聊页面 (加入已读标记功能)
// ==========================================
class GroupChatPage extends StatefulWidget {
  final String groupID;
  final String groupName;
  const GroupChatPage({super.key, required this.groupID, required this.groupName});
  @override
  State<GroupChatPage> createState() => _GroupChatPageState();
}

class _GroupChatPageState extends State<GroupChatPage> {
  final _supabase = Supabase.instance.client;
  final _msgController = TextEditingController();
  final _scrollController = ScrollController();
  List<Map<String, dynamic>> _messages = [];
  Timer? _chatTimer;
  String _myRole = 'Member';
  String get _myID => _supabase.auth.currentUser!.id;

  @override
  void initState() {
    super.initState();
    _checkMyRole();
    _markAsRead();
    _loadMessages();
    _chatTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      _loadMessages();
      _markAsRead(); // 不断更新最后阅读时间
    });
  }

  @override
  void dispose() {
    _chatTimer?.cancel();
    _msgController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  Future<void> _markAsRead() async {
    try {
      await _supabase.rpc('mark_group_messages_read', params: {
        'group_id': widget.groupID,
        'user_id': _myID
      });
    } catch (e) {}
  }

  Future<void> _checkMyRole() async {
    final res = await _supabase.from('GroupMembers').select('role').eq('chatGroupID', widget.groupID).eq('userID', _myID).maybeSingle();
    if (res != null && mounted) setState(() => _myRole = res['role']);
  }

  Future<void> _loadMessages() async {
    try {
      final data = await _supabase.rpc('get_group_chat_history', params: {'group_id': widget.groupID});
      if (mounted) setState(() => _messages = List<Map<String, dynamic>>.from(data));
    } catch (e) { debugPrint("Group Load Error: $e"); }
  }

  Future<void> _sendMessage() async {
    final text = _msgController.text.trim();
    if (text.isEmpty) return;
    _msgController.clear();
    try {
      final String msgID = "MSG${Random().nextInt(99999999)}";
      await _supabase.from('Message').insert({'messageID': msgID, 'userID': _myID, 'text': text});
      await _supabase.from('GroupMessage').insert({'groupMsgID': "GMSG${Random().nextInt(99999999)}", 'messageID': msgID, 'chatGroupID': widget.groupID});
      _loadMessages();
    } catch (e) {}
  }

  Future<void> _togglePin(String msgID, bool currentStatus) async {
    if (_myRole != 'Admin' && _myRole != 'Owner') {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Only Admins and Owners can pin/unpin messages.")));
      return;
    }
    await _supabase.rpc('toggle_pin_group_message', params: {'msg_id': msgID, 'group_id': widget.groupID, 'pin_status': !currentStatus});
    _loadMessages();
  }

  void _scrollToMessage(String msgID) {
    final index = _messages.indexWhere((m) => m['messageID'] == msgID);
    if (index != -1) {
      final targetOffset = index * 80.0;
      _scrollController.animateTo(
        targetOffset.clamp(0.0, _scrollController.position.maxScrollExtent),
        duration: const Duration(milliseconds: 500),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _unsendGlobal(String msgID) async {
    await _supabase.rpc('delete_message_global', params: {'msg_id': msgID});
    _loadMessages();
  }

  Future<void> _deleteLocal(String msgID) async {
    await _supabase.rpc('hide_group_message_local', params: {'msg_id': msgID});
    _loadMessages();
  }

  Future<void> _editMessage(String msgID, String oldText) async {
    final c = TextEditingController(text: oldText);
    showDialog(context: context, builder: (_) => AlertDialog(
        title: const Text("Edit"),
        content: TextField(controller: c, autofocus: true),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text("Cancel")),
          ElevatedButton(onPressed: () async {
            if (c.text.trim().isNotEmpty && c.text != oldText) {
              await _supabase.rpc('edit_message', params: {'msg_id': msgID, 'new_text': c.text.trim()});
              _loadMessages();
            }
            if (mounted) Navigator.pop(context);
          }, child: const Text("Save"))
        ]
    ));
  }

  Widget _buildMenu(Map<String, dynamic> msg, bool isMe) {
    return PopupMenuButton<String>(
      icon: const Icon(Icons.more_vert, size: 16, color: Colors.grey),
      padding: EdgeInsets.zero,
      onSelected: (value) {
        if (value == 'edit') _editMessage(msg['messageID'], msg['text']);
        if (value == 'unsend') _unsendGlobal(msg['messageID']);
        if (value == 'delete_me') _deleteLocal(msg['messageID']);
        if (value == 'pin') _togglePin(msg['messageID'], msg['isPinned'] ?? false);
      },
      itemBuilder: (context) => [
        if (_myRole == 'Admin' || _myRole == 'Owner') PopupMenuItem(value: 'pin', child: Text(msg['isPinned'] == true ? 'Unpin Message' : 'Pin Message')),
        if (isMe) const PopupMenuItem(value: 'edit', child: Text('Edit')),
        if (isMe) const PopupMenuItem(value: 'unsend', child: Text('Unsend (Everyone)', style: TextStyle(color: Colors.red))),
        const PopupMenuItem(value: 'delete_me', child: Text('Delete for me')),
      ],
    );
  }

  void _openGroupManage() {
    showDialog(context: context, builder: (_) => GroupManageDialog(groupID: widget.groupID, myRole: _myRole));
  }

  @override
  Widget build(BuildContext context) {
    final pinnedMessages = _messages.where((m) => m['isPinned'] == true).toList();

    return Scaffold(
      backgroundColor: Colors.grey[100],
      appBar: AppBar(
        title: Text(widget.groupName), backgroundColor: Colors.teal, foregroundColor: Colors.white,
        actions: [IconButton(icon: const Icon(Icons.groups), onPressed: _openGroupManage)],
      ),
      body: SafeArea(
        child: Column(
          children: [
            if (pinnedMessages.isNotEmpty) Container(
              width: double.infinity, padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6), color: Colors.amber.shade100,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: pinnedMessages.map((m) => Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4.0),
                  child: Row(
                    children: [
                      GestureDetector(
                        onTap: () => _togglePin(m['messageID'], true),
                        child: const Icon(Icons.push_pin, size: 18, color: Colors.orange),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => _scrollToMessage(m['messageID']),
                          child: Text("${m['sender_name']}: ${m['text']}", maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 13, color: Colors.black87, fontWeight: FontWeight.w500)),
                        ),
                      ),
                    ],
                  ),
                )).toList(),
              ),
            ),
            Expanded(
              child: ListView.builder(
                reverse: true, controller: _scrollController, padding: const EdgeInsets.all(10), itemCount: _messages.length,
                itemBuilder: (context, index) {
                  final msg = _messages[index];
                  final bool isMe = msg['sender_id'] == _myID;
                  final senderName = msg['sender_name'] ?? 'Unknown';
                  String timeString = '';
                  if (msg['timestamp'] != null) {
                    try { timeString = DateFormat('hh:mm a').format(DateTime.parse(msg['timestamp']).toLocal()); } catch (e) {}
                  }
                  return Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      mainAxisAlignment: isMe ? MainAxisAlignment.end : MainAxisAlignment.start, crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        if (!isMe) CircleAvatar(radius: 16, backgroundColor: Colors.orange.shade200, child: Text(senderName[0].toUpperCase(), style: const TextStyle(color: Colors.white))),
                        if (!isMe) const SizedBox(width: 8),
                        Flexible(
                          child: Column(
                            crossAxisAlignment: isMe ? CrossAxisAlignment.end : CrossAxisAlignment.start,
                            children: [
                              Row(mainAxisSize: MainAxisSize.min, children: [
                                if (isMe) _buildMenu(msg, isMe),
                                Text(isMe ? 'Me' : senderName, style: const TextStyle(fontSize: 11, color: Colors.grey)),
                                if (!isMe) _buildMenu(msg, isMe),
                              ]),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(color: isMe ? Colors.teal : Colors.white, borderRadius: BorderRadius.circular(15), border: isMe ? null : Border.all(color: Colors.grey.shade300)),
                                child: Text(msg['text'] ?? "", style: TextStyle(color: isMe ? Colors.white : Colors.black87)),
                              ),
                              Text(timeString, style: const TextStyle(fontSize: 10, color: Colors.grey)),
                            ],
                          ),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
            Container(
              padding: const EdgeInsets.all(10), color: Colors.white,
              child: Row(
                children: [
                  Expanded(child: TextField(controller: _msgController, decoration: InputDecoration(hintText: "Type in group...", filled: true, fillColor: Colors.grey[100], border: OutlineInputBorder(borderRadius: BorderRadius.circular(25), borderSide: BorderSide.none)))),
                  const SizedBox(width: 8),
                  Container(decoration: const BoxDecoration(color: Colors.teal, shape: BoxShape.circle), child: IconButton(icon: const Icon(Icons.send, color: Colors.white), onPressed: _sendMessage)),
                ],
              ),
            )
          ],
        ),
      ),
    );
  }
}

// ==========================================
// 5. 群组成员管理面板 (Owner/Admin 权限分级)
// ==========================================
class GroupManageDialog extends StatefulWidget {
  final String groupID;
  final String myRole;
  const GroupManageDialog({super.key, required this.groupID, required this.myRole});
  @override
  State<GroupManageDialog> createState() => _GroupManageDialogState();
}

class _GroupManageDialogState extends State<GroupManageDialog> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _members = [];

  @override
  void initState() {
    super.initState();
    _fetchMembers();
  }

  Future<void> _fetchMembers() async {
    final data = await _supabase.from('GroupMembers').select('*, users(*)').eq('chatGroupID', widget.groupID);
    if (mounted) setState(() => _members = List<Map<String, dynamic>>.from(data));
  }

  Future<void> _kickUser(String userID) async {
    await _supabase.from('GroupMembers').delete().eq('chatGroupID', widget.groupID).eq('userID', userID);
    _fetchMembers();
  }

  Future<void> _changeRole(String userID, String newRole) async {
    await _supabase.from('GroupMembers').update({'role': newRole}).eq('chatGroupID', widget.groupID).eq('userID', userID);
    _fetchMembers();
  }

  Future<void> _addMemberByEmail() async {
    final emailController = TextEditingController();
    String? errorMessage;
    bool isSearching = false;

    await showDialog(
      context: context,
      builder: (ctx) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text("Add New Member"),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  TextField(
                    controller: emailController,
                    decoration: const InputDecoration(hintText: "Enter user email"),
                  ),
                  if (errorMessage != null) ...[
                    const SizedBox(height: 8),
                    Text(errorMessage!, style: const TextStyle(color: Colors.red, fontSize: 12)),
                  ]
                ],
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx), child: const Text("Cancel")),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.teal),
                  onPressed: isSearching ? null : () async {
                    setStateDialog(() { isSearching = true; errorMessage = null; });
                    final email = emailController.text.trim();

                    if (email.isEmpty) {
                      setStateDialog(() { isSearching = false; errorMessage = "Email cannot be empty"; });
                      return;
                    }

                    try {
                      final res = await _supabase.from('users').select().eq('userEmail', email).maybeSingle();
                      if (res == null) {
                        setStateDialog(() { isSearching = false; errorMessage = "User not found in database!"; });
                        return;
                      }

                      final newUserId = res['userID'];

                      final checkGroup = await _supabase.from('GroupMembers')
                          .select()
                          .eq('chatGroupID', widget.groupID)
                          .eq('userID', newUserId)
                          .maybeSingle();

                      if (checkGroup != null) {
                        setStateDialog(() { isSearching = false; errorMessage = "User is already in the group!"; });
                        return;
                      }

                      await _supabase.from('GroupMembers').insert({
                        'chatGroupID': widget.groupID,
                        'userID': newUserId,
                        'role': 'Member',
                      });

                      if (mounted) {
                        Navigator.pop(ctx);
                        _fetchMembers();
                        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Member added successfully!")));
                      }

                    } catch (e) {
                      setStateDialog(() { isSearching = false; errorMessage = "Error: $e"; });
                    }
                  },
                  child: isSearching
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                      : const Text("Add", style: TextStyle(color: Colors.white)),
                ),
              ],
            );
          }
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Text("Group Members"),
          IconButton(
            icon: const Icon(Icons.person_add, color: Colors.teal),
            onPressed: _addMemberByEmail,
            tooltip: "Add Member",
          )
        ],
      ),
      content: SizedBox(
        width: double.maxFinite,
        child: ListView.builder(
          shrinkWrap: true,
          itemCount: _members.length,
          itemBuilder: (context, index) {
            final m = _members[index];
            final user = m['users'];
            final role = m['role'];
            final isMe = user['userID'] == _supabase.auth.currentUser!.id;

            // 根据我的权限，判断能对这个成员做什么操作
            List<PopupMenuEntry<String>> menuItems = [];

            if (!isMe) {
              if (widget.myRole == 'Owner') {
                // Owner 可以操作 Admin 和 Member
                if (role == 'Admin') {
                  menuItems.add(const PopupMenuItem(value: 'demote', child: Text("Demote to Member")));
                  menuItems.add(const PopupMenuItem(value: 'kick', child: Text("Kick User", style: TextStyle(color: Colors.red))));
                } else if (role == 'Member') {
                  menuItems.add(const PopupMenuItem(value: 'admin', child: Text("Make Admin")));
                  menuItems.add(const PopupMenuItem(value: 'kick', child: Text("Kick User", style: TextStyle(color: Colors.red))));
                }
              } else if (widget.myRole == 'Admin') {
                // Admin 只能踢掉 Member
                if (role == 'Member') {
                  menuItems.add(const PopupMenuItem(value: 'kick', child: Text("Kick User", style: TextStyle(color: Colors.red))));
                }
              }
            }

            return ListTile(
              title: Text(user['userName'] ?? user['userEmail'], style: TextStyle(fontWeight: isMe ? FontWeight.bold : FontWeight.normal)),
              subtitle: Text(role, style: TextStyle(color: role == 'Owner' ? Colors.redAccent : (role == 'Admin' ? Colors.orange : Colors.grey))),
              trailing: menuItems.isNotEmpty ? PopupMenuButton<String>(
                onSelected: (val) {
                  if (val == 'kick') _kickUser(user['userID']);
                  if (val == 'admin') _changeRole(user['userID'], 'Admin');
                  if (val == 'demote') _changeRole(user['userID'], 'Member');
                },
                itemBuilder: (_) => menuItems,
              ) : null,
            );
          },
        ),
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(context), child: const Text("Close"))],
    );
  }
}