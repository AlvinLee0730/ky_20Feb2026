import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:video_player/video_player.dart';

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});

  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final _supabase = Supabase.instance.client;

  // Controllers
  final _titleController = TextEditingController();
  final _contentController = TextEditingController();
  final _searchController = TextEditingController();

  // Filter States
  String _searchQuery = "";
  String _filterCategory = 'All';

  // Form State
  File? _mediaFile;
  bool _isImage = true; // Toggle between Image or Video upload
  bool _isSaving = false;
  String _selectedCategory = 'Training';

  Stream<List<Map<String, dynamic>>> get _eduStream => _supabase
      .from('pet_education')
      .stream(primaryKey: ['id'])
      .order('created_at', ascending: false);

  void _clearAllFilters() {
    setState(() {
      _filterCategory = 'All';
      _searchQuery = "";
      _searchController.clear();
    });
  }

  Future<void> _deleteArticle(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text("Delete Guide?"),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text("Cancel")),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("Delete", style: TextStyle(color: Colors.red))),
        ],
      ),
    );

    if (confirm == true) {
      await _supabase.from('pet_education').delete().eq('id', id);
      setState(() {});
    }
  }

  Future<void> _saveArticle({int? existingId, String? existingMediaUrl, String? existingType}) async {
    if (_titleController.text.isEmpty) return;
    setState(() => _isSaving = true);
    try {
      String? mediaUrl = existingMediaUrl;
      String mediaType = existingType ?? (_isImage ? 'image' : 'video');

      if (_mediaFile != null) {
        final ext = _isImage ? 'jpg' : 'mp4';
        final fileName = 'edu_${DateTime.now().millisecondsSinceEpoch}.$ext';
        await _supabase.storage.from('pet_images').upload(fileName, _mediaFile!);
        mediaUrl = _supabase.storage.from('pet_images').getPublicUrl(fileName);
        mediaType = _isImage ? 'image' : 'video';
      }

      final data = {
        'title': _titleController.text.trim(),
        'category': _selectedCategory,
        'content': _contentController.text.trim(),
        'media_url': mediaUrl,
        'media_type': mediaType,
      };

      if (existingId == null) {
        await _supabase.from('pet_education').insert(data);
      } else {
        await _supabase.from('pet_education').update(data).eq('id', existingId);
      }

      if (mounted) Navigator.pop(context);
    } finally {
      if (mounted) setState(() => _isSaving = false);
    }
  }

  void _showAddDialog({Map<String, dynamic>? article}) {
    if (article != null) {
      _titleController.text = article['title'] ?? '';
      _contentController.text = article['content'] ?? '';
      _selectedCategory = article['category'] ?? 'Training';
      _isImage = (article['media_type'] ?? 'image') == 'image';
    } else {
      _titleController.clear(); _contentController.clear();
      _mediaFile = null; _isImage = true;
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(25))),
      builder: (context) => StatefulBuilder(
        builder: (context, setModalState) => Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, top: 20, left: 20, right: 20),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(article == null ? "Add Education Guide" : "Edit Guide", style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(height: 15),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    ChoiceChip(
                      label: const Text("Image"),
                      selected: _isImage,
                      onSelected: (v) => setModalState(() => _isImage = true),
                    ),
                    const SizedBox(width: 10),
                    ChoiceChip(
                      label: const Text("Video"),
                      selected: !_isImage,
                      onSelected: (v) => setModalState(() => _isImage = false),
                    ),
                  ],
                ),
                InkWell(
                  onTap: () async {
                    final picker = ImagePicker();
                    final picked = _isImage
                        ? await picker.pickImage(source: ImageSource.gallery)
                        : await picker.pickVideo(source: ImageSource.gallery);
                    if (picked != null) setModalState(() => _mediaFile = File(picked.path));
                  },
                  child: Container(
                    height: 120, width: double.infinity,
                    margin: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(color: Colors.grey[100], borderRadius: BorderRadius.circular(15), border: Border.all(color: Colors.grey.shade300)),
                    child: _mediaFile != null
                        ? Center(child: Text(_isImage ? "Image Selected ✅" : "Video Selected ✅"))
                        : (article?['media_url'] != null
                        ? const Center(child: Text("Media Attached ✅"))
                        : Icon(_isImage ? Icons.add_a_photo : Icons.video_call, color: Colors.blue, size: 40)),
                  ),
                ),
                TextField(controller: _titleController, decoration: const InputDecoration(labelText: "Title")),
                DropdownButtonFormField(
                  value: _selectedCategory,
                  items: ['Training', 'Health', 'Nutrition', 'Behavior'].map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                  onChanged: (val) => setModalState(() => _selectedCategory = val!),
                  decoration: const InputDecoration(labelText: "Category"),
                ),
                TextField(controller: _contentController, maxLines: 3, decoration: const InputDecoration(labelText: "Guide Content")),
                const SizedBox(height: 20),
                _isSaving ? const CircularProgressIndicator() : ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.blue, foregroundColor: Colors.white, minimumSize: const Size(double.infinity, 45)),
                  onPressed: () => _saveArticle(
                      existingId: article?['id'],
                      existingMediaUrl: article?['media_url'],
                      existingType: article?['media_type']
                  ),
                  child: Text(article == null ? "POST GUIDE" : "UPDATE GUIDE"),
                ),
                const SizedBox(height: 30),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Education"),
        actions: [
          if (_searchQuery.isNotEmpty || _filterCategory != 'All')
            IconButton(icon: const Icon(Icons.refresh), onPressed: _clearAllFilters),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchController,
              decoration: InputDecoration(
                hintText: "Search guides...",
                prefixIcon: const Icon(Icons.search),
                filled: true, fillColor: Colors.grey[100],
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(15), borderSide: BorderSide.none),
              ),
              onChanged: (val) => setState(() => _searchQuery = val.toLowerCase()),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: _buildDropdownFilter("Category", _filterCategory, ['All', 'Training', 'Health', 'Nutrition', 'Behavior'], (val) {
              setState(() => _filterCategory = val!);
            }),
          ),
          const Divider(),
          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _eduStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final filtered = snapshot.data!.where((item) {
                  final title = item['title'].toString().toLowerCase();
                  bool matchesSearch = title.contains(_searchQuery);
                  bool matchesCat = _filterCategory == 'All' || item['category'] == _filterCategory;
                  return matchesSearch && matchesCat;
                }).toList();

                return GridView.builder(
                  padding: const EdgeInsets.all(12),
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2, crossAxisSpacing: 12, mainAxisSpacing: 12, childAspectRatio: 0.8,
                  ),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final item = filtered[index];
                    final isVideo = item['media_type'] == 'video';

                    return Card(
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (context) => EducationDetail(article: item))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Stack(
                                children: [
                                  Container(
                                    width: double.infinity,
                                    color: Colors.blue[50],
                                    child: Icon(isVideo ? Icons.play_circle : Icons.article, size: 40, color: Colors.blue),
                                  ),
                                  Positioned(
                                    top: 5, right: 5,
                                    child: Row(
                                      children: [
                                        _actionCircle(Icons.edit, Colors.blue, () => _showAddDialog(article: item)),
                                        const SizedBox(width: 4),
                                        _actionCircle(Icons.delete, Colors.red, () => _deleteArticle(item['id'])),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(8.0),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(item['title'], style: const TextStyle(fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                  Text(item['category'], style: const TextStyle(fontSize: 12, color: Colors.grey)),
                                ],
                              ),
                            )
                          ],
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showAddDialog(),
        backgroundColor: Colors.blue,
        child: const Icon(Icons.add, color: Colors.white),
      ),
    );
  }

  Widget _actionCircle(IconData icon, Color color, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: CircleAvatar(
        radius: 14, backgroundColor: Colors.white.withOpacity(0.9),
        child: Icon(icon, size: 14, color: color),
      ),
    );
  }

  Widget _buildDropdownFilter(String label, String value, List<String> items, ValueChanged<String?> onChanged) {
    return DropdownButton<String>(
      value: value, isExpanded: true,
      onChanged: onChanged,
      items: items.map((i) => DropdownMenuItem(value: i, child: Text(i))).toList(),
    );
  }
}

class EducationDetail extends StatefulWidget {
  final Map<String, dynamic> article;
  const EducationDetail({super.key, required this.article});

  @override
  State<EducationDetail> createState() => _EducationDetailState();
}

class _EducationDetailState extends State<EducationDetail> {
  VideoPlayerController? _controller;

  @override
  void initState() {
    super.initState();
    if (widget.article['media_type'] == 'video' && widget.article['media_url'] != null) {
      _controller = VideoPlayerController.networkUrl(Uri.parse(widget.article['media_url']))
        ..initialize().then((_) => setState(() {}));
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isVideo = widget.article['media_type'] == 'video';
    final mediaUrl = widget.article['media_url'];

    return Scaffold(
      appBar: AppBar(title: Text(widget.article['title'])),
      body: SingleChildScrollView(
        child: Column(
          children: [
            if (mediaUrl != null)
              isVideo
                  ? (_controller != null && _controller!.value.isInitialized
                  ? AspectRatio(
                aspectRatio: _controller!.value.aspectRatio,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    VideoPlayer(_controller!),
                    IconButton(
                      icon: Icon(_controller!.value.isPlaying ? Icons.pause_circle : Icons.play_circle, color: Colors.white, size: 50),
                      onPressed: () => setState(() => _controller!.value.isPlaying ? _controller!.pause() : _controller!.play()),
                    ),
                  ],
                ),
              )
                  : const Center(child: CircularProgressIndicator()))
                  : Image.network(mediaUrl, width: double.infinity, fit: BoxFit.cover),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(widget.article['title'], style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 10),
                  Text(widget.article['content'] ?? "", style: const TextStyle(fontSize: 16)),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}