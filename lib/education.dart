import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';
import 'package:intl/intl.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});
  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final _supabase = Supabase.instance.client;
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();

  File? _mediaFile;
  bool _isImage = true;
  bool _isSaving = false;
  String _selectedCategory = 'Pet Training';
  String _userRole = 'User';

  @override
  void initState() {
    super.initState();
    _checkUserRole();
  }

  Future<void> _checkUserRole() async {
    final user = _supabase.auth.currentUser;
    if (user != null) {
      final data = await _supabase.from('users').select('role').eq('userID', user.id).maybeSingle();
      if (mounted) setState(() => _userRole = data?['role'] ?? 'User');
    }
  }

  Future<String> _generateMaterialID() async {
    final res = await _supabase.from('pet_material').select('materialID');
    if (res.isEmpty) return "PM00001";
    List<int> nums = res.map((i) => int.tryParse(i['materialID'].toString().replaceAll(RegExp(r'[^0-9]'), '')) ?? 0).toList();
    nums.sort();
    return "PM${(nums.last + 1).toString().padLeft(5, '0')}";
  }

  Future<void> _saveMaterial({Map<String, dynamic>? item}) async {
    setState(() => _isSaving = true);
    try {
      String? url = item?['mediaURL'];
      if (_mediaFile != null) {
        final path = 'edu_${DateTime.now().millisecondsSinceEpoch}';
        await _supabase.storage.from('pet_images').upload(path, _mediaFile!);
        url = _supabase.storage.from('pet_images').getPublicUrl(path);
      }

      final data = {
        'userID': _supabase.auth.currentUser!.id,
        'category': _selectedCategory,
        'title': _titleController.text,
        'content': _contentController.text,
        'mediaURL': url,
        'isApproved': _userRole == 'Admin', // Admin posts are auto-approved
      };

      if (item == null) {
        data['materialID'] = await _generateMaterialID();
        await _supabase.from('pet_material').insert(data);
      } else {
        await _supabase.from('pet_material').update(data).eq('materialID', item['materialID']);
      }
      Navigator.pop(context);
    } finally {
      setState(() => _isSaving = false);
    }
  }

  void _showForm({Map<String, dynamic>? item}) {
    if (item != null) {
      _titleController.text = item['title'];
      _contentController.text = item['content'];
      _selectedCategory = item['category'];
    }
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title")),
            TextField(controller: _contentController, decoration: const InputDecoration(labelText: "Content"), maxLines: 3),
            const SizedBox(height: 10),
            ElevatedButton(onPressed: () async {
              final p = await ImagePicker().pickMedia();
              if (p != null) setState(() => _mediaFile = File(p.path));
            }, child: const Text("Pick Media (Img/Vid)")),
            const SizedBox(height: 20),
            _isSaving ? const CircularProgressIndicator() : ElevatedButton(onPressed: () => _saveMaterial(item: item), child: const Text("Post")),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String currentUid = _supabase.auth.currentUser?.id ?? "";

    return Scaffold(
      appBar: AppBar(title: const Text("Pet Education"), backgroundColor: Colors.teal),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _supabase.from('pet_material').stream(primaryKey: ['materialID']),
        builder: (context, snapshot) {
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          final items = snapshot.data!;
          return GridView.builder(
            padding: const EdgeInsets.all(10),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, childAspectRatio: 0.8, crossAxisSpacing: 10, mainAxisSpacing: 10),
            itemCount: items.length,
            itemBuilder: (context, index) {
              final item = items[index];
              final bool isOwner = item['userID'] == currentUid;
              final bool isAdmin = _userRole == 'Admin';

              return GestureDetector(
                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (c) => EducationDetailScreen(article: item))),
                child: Card(
                  clipBehavior: Clip.antiAlias,
                  child: Stack(
                    children: [
                      Column(
                        children: [
                          Expanded(child: item['mediaURL'] != null ? Image.network(item['mediaURL'], fit: BoxFit.cover, width: double.infinity) : Container(color: Colors.grey[200])),
                          Padding(padding: const EdgeInsets.all(8.0), child: Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold))),
                        ],
                      ),
                      if (item['isApproved'] == false)
                        Container(color: Colors.black45, child: const Center(child: Text("PENDING", style: TextStyle(color: Colors.white)))),

                      // BUTTONS: Only show for owner or admin
                      if (isOwner || isAdmin)
                        Positioned(
                          top: 5, right: 5,
                          child: Row(
                            children: [
                              CircleAvatar(radius: 14, backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.edit, size: 14), onPressed: () => _showForm(item: item))),
                              const SizedBox(width: 5),
                              CircleAvatar(radius: 14, backgroundColor: Colors.white, child: IconButton(icon: const Icon(Icons.delete, size: 14, color: Colors.red), onPressed: () async {
                                await _supabase.from('pet_material').delete().eq('materialID', item['materialID']);
                              })),
                            ],
                          ),
                        ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
      floatingActionButton: FloatingActionButton(onPressed: () => _showForm(), child: const Icon(Icons.add)),
    );
  }
}

class EducationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  const EducationDetailScreen({super.key, required this.article});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(article['title'])),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (article['mediaURL'] != null) Image.network(article['mediaURL']),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Text(article['content'], style: const TextStyle(fontSize: 16)),
            ),
          ],
        ),
      ),
    );
  }
}