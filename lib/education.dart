import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart'; // 用于打开视频链接

// 预设的专业宠物教育分类
const List<String> educationCategories = [
  'Health & Wellness',
  'Training & Behavior',
  'Diet & Nutrition',
  'Grooming',
  'General Care'
];

class EducationPage extends StatefulWidget {
  const EducationPage({super.key});
  @override
  State<EducationPage> createState() => _EducationPageState();
}

class _EducationPageState extends State<EducationPage> {
  final _supabase = Supabase.instance.client;
  String _userRole = 'User';
  String _selectedFilterCategory = 'All'; // 用于顶部过滤器

  late final Stream<List<Map<String, dynamic>>> _educationStream;

  @override
  void initState() {
    super.initState();
    _checkUserRole();
    // 全局初始化 Stream 保证不闪烁
    _educationStream = _supabase.from('pet_material').stream(primaryKey: ['materialID']);
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
    List<int> ids = res.map((e) => int.parse(e['materialID'].toString().substring(2))).toList();
    ids.sort();
    return "PM${(ids.last + 1).toString().padLeft(5, '0')}";
  }

  // 专属的错误提示弹窗
  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.error_outline, color: Colors.red),
            SizedBox(width: 8),
            Text("Error"),
          ],
        ),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text("OK", style: TextStyle(color: Colors.teal)),
          )
        ],
      ),
    );
  }

  // 构建紧凑型的单选按钮
  Widget _buildRadioOption(String title, int value, int groupValue, Function(int) onChanged) {
    return InkWell(
      onTap: () => onChanged(value),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Radio<int>(
            value: value,
            groupValue: groupValue,
            onChanged: (v) => onChanged(v!),
            activeColor: Colors.teal,
            visualDensity: const VisualDensity(horizontal: -4, vertical: -4),
          ),
          const SizedBox(width: 4),
          Text(title, style: const TextStyle(fontSize: 14)),
        ],
      ),
    );
  }

  // 呼出创建/编辑表单
  void _showForm({Map<String, dynamic>? item}) {
    final titleController = TextEditingController(text: item?['title']);
    final contentController = TextEditingController(text: item?['content']);

    String selectedCategory = item?['category'] ?? educationCategories.first;
    if (!educationCategories.contains(selectedCategory)) {
      selectedCategory = educationCategories.first;
    }

    // 0: Images, 1: Local Video, 2: YouTube
    int mediaTypeIndex = 0;
    List<XFile> selectedImages = [];
    XFile? selectedVideo;
    final youtubeController = TextEditingController(
        text: (item?['videoURL'] != null && item!['videoURL'].toString().contains('youtube'))
            ? item['videoURL'] : ''
    );

    bool isSaving = false;

    showModalBottomSheet(
        context: context,
        isScrollControlled: true,
        shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
        builder: (ctx) {
          return StatefulBuilder(
              builder: (context, setModalState) {
                Future<void> pickImages() async {
                  final ImagePicker picker = ImagePicker();
                  final List<XFile> images = await picker.pickMultiImage();
                  if (images.isNotEmpty) {
                    setModalState(() {
                      selectedImages = images;
                    });
                  }
                }

                Future<void> pickVideo() async {
                  final ImagePicker picker = ImagePicker();
                  final XFile? video = await picker.pickVideo(source: ImageSource.gallery);
                  if (video != null) {
                    setModalState(() {
                      selectedVideo = video;
                    });
                  }
                }

                Future<void> savePost() async {
                  // 验证：跳出错误弹窗
                  if (titleController.text.trim().isEmpty || contentController.text.trim().isEmpty) {
                    _showErrorDialog('Title and Content are required!');
                    return;
                  }

                  // 验证YouTube链接：跳出错误弹窗
                  if (mediaTypeIndex == 2 && youtubeController.text.trim().isEmpty) {
                    _showErrorDialog('Please enter a valid YouTube URL!');
                    return;
                  }

                  setModalState(() => isSaving = true);

                  try {
                    List<String> uploadedImageUrls = [];
                    String? finalVideoUrl;

                    // 1. 处理图片上传
                    if (mediaTypeIndex == 0 && selectedImages.isNotEmpty) {
                      for (int i = 0; i < selectedImages.length; i++) {
                        final file = File(selectedImages[i].path);
                        final ext = file.path.split('.').last;
                        final fileName = 'edu_img_${DateTime.now().millisecondsSinceEpoch}_$i.$ext';
                        await _supabase.storage.from('pet_materials').upload(fileName, file);
                        uploadedImageUrls.add(_supabase.storage.from('pet_materials').getPublicUrl(fileName));
                      }
                    }

                    // 2. 处理本地视频上传
                    if (mediaTypeIndex == 1 && selectedVideo != null) {
                      final file = File(selectedVideo!.path);
                      final ext = file.path.split('.').last;
                      final fileName = 'edu_vid_${DateTime.now().millisecondsSinceEpoch}.$ext';
                      await _supabase.storage.from('pet_materials').upload(fileName, file);
                      finalVideoUrl = _supabase.storage.from('pet_materials').getPublicUrl(fileName);
                    }

                    // 3. 处理 YouTube 链接
                    if (mediaTypeIndex == 2 && youtubeController.text.isNotEmpty) {
                      finalVideoUrl = youtubeController.text.trim();
                    }

                    final postData = {
                      'title': titleController.text.trim(),
                      'content': contentController.text.trim(),
                      'category': selectedCategory,
                      'mediaURLs': uploadedImageUrls.isNotEmpty ? uploadedImageUrls : (item?['mediaURLs'] ?? []),
                      'videoURL': finalVideoUrl ?? item?['videoURL'],
                    };

                    if (item == null) {
                      // 新增
                      postData['materialID'] = await _generateMaterialID();
                      postData['userID'] = _supabase.auth.currentUser!.id;
                      postData['isApproved'] = (_userRole == 'Admin');
                      await _supabase.from('pet_material').insert(postData);
                    } else {
                      // 更新
                      await _supabase.from('pet_material').update(postData).eq('materialID', item['materialID']);
                    }

                    if (mounted) {
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                          content: Text(item == null ? (_userRole == 'Admin' ? 'Posted Successfully!' : 'Submitted for admin approval.') : 'Updated Successfully!')
                      ));
                    }
                  } catch (e) {
                    debugPrint(e.toString());
                    // 保存失败也会弹出错误框
                    _showErrorDialog('Error saving post: $e');
                  } finally {
                    setModalState(() => isSaving = false);
                  }
                }

                return Padding(
                  padding: EdgeInsets.only(
                      bottom: MediaQuery.of(context).viewInsets.bottom,
                      left: 20, right: 20, top: 20
                  ),
                  child: SingleChildScrollView(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(item == null ? "Create Education Post" : "Edit Post", style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 15),

                        const Text("Category", style: TextStyle(fontWeight: FontWeight.bold)),
                        Container(
                          margin: const EdgeInsets.only(top: 5, bottom: 15),
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          decoration: BoxDecoration(border: Border.all(color: Colors.grey), borderRadius: BorderRadius.circular(8)),
                          child: DropdownButtonHideUnderline(
                            child: DropdownButton<String>(
                              isExpanded: true,
                              value: selectedCategory,
                              items: educationCategories.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                              onChanged: (val) {
                                if (val != null) setModalState(() {
                                  selectedCategory = val;
                                });
                              },
                            ),
                          ),
                        ),

                        TextField(
                          controller: titleController,
                          decoration: const InputDecoration(labelText: "Title", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: contentController,
                          maxLines: 4,
                          decoration: const InputDecoration(labelText: "Content", border: OutlineInputBorder()),
                        ),
                        const SizedBox(height: 15),

                        const Text("Attach Media", style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 10),

                        Wrap(
                          spacing: 15,
                          runSpacing: 10,
                          children: [
                            _buildRadioOption("Images", 0, mediaTypeIndex, (v) => setModalState(() { mediaTypeIndex = v; })),
                            _buildRadioOption("Local Video", 1, mediaTypeIndex, (v) => setModalState(() { mediaTypeIndex = v; })),
                            _buildRadioOption("YouTube", 2, mediaTypeIndex, (v) => setModalState(() { mediaTypeIndex = v; })),
                          ],
                        ),
                        const SizedBox(height: 15),

                        if (mediaTypeIndex == 0) ...[
                          ElevatedButton.icon(
                              onPressed: pickImages, icon: const Icon(Icons.photo_library), label: const Text("Select Multiple Images")
                          ),
                          if (selectedImages.isNotEmpty)
                            Padding(
                              padding: const EdgeInsets.only(top: 10),
                              child: Wrap(
                                spacing: 8, runSpacing: 8,
                                children: selectedImages.map((img) => ClipRRect(borderRadius: BorderRadius.circular(8), child: Image.file(File(img.path), width: 60, height: 60, fit: BoxFit.cover))).toList(),
                              ),
                            )
                        ] else if (mediaTypeIndex == 1) ...[
                          ElevatedButton.icon(
                              onPressed: pickVideo, icon: const Icon(Icons.video_library), label: const Text("Select Video")
                          ),
                          if (selectedVideo != null)
                            Padding(padding: const EdgeInsets.only(top: 8), child: Text("Selected: ${selectedVideo!.name}", style: const TextStyle(color: Colors.teal))),
                        ] else if (mediaTypeIndex == 2) ...[
                          TextField(
                            controller: youtubeController,
                            decoration: const InputDecoration(labelText: "YouTube URL", prefixIcon: Icon(Icons.link)),
                          ),
                        ],

                        const SizedBox(height: 20),
                        SizedBox(
                          width: double.infinity,
                          child: ElevatedButton(
                            style: ElevatedButton.styleFrom(backgroundColor: Colors.teal, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 15)),
                            onPressed: isSaving ? null : savePost,
                            child: isSaving ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2)) : const Text("Submit"),
                          ),
                        ),
                        const SizedBox(height: 20),
                      ],
                    ),
                  ),
                );
              }
          );
        }
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text("Pet Education"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Column(
        children: [
          Container(
            height: 60,
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              children: [
                _buildFilterChip('All'),
                ...educationCategories.map((c) => _buildFilterChip(c)),
              ],
            ),
          ),

          Expanded(
            child: StreamBuilder<List<Map<String, dynamic>>>(
              stream: _educationStream,
              builder: (context, snapshot) {
                if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

                final currentUserId = _supabase.auth.currentUser?.id;
                List<Map<String, dynamic>> items = snapshot.data!.where((item) {
                  bool isApprovedOrMine = item['isApproved'] == true || item['userID'] == currentUserId || _userRole == 'Admin';
                  bool matchesFilter = _selectedFilterCategory == 'All' || item['category'] == _selectedFilterCategory;
                  return isApprovedOrMine && matchesFilter;
                }).toList();

                if (items.isEmpty) return const Center(child: Text("No articles found for this category."));

                return ListView.builder(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  itemBuilder: (context, index) {
                    final item = items[index];
                    final bool isPending = item['isApproved'] == false || item['isApproved'] == null;

                    String? coverImage;
                    if (item['mediaURLs'] != null && (item['mediaURLs'] as List).isNotEmpty) {
                      coverImage = item['mediaURLs'][0];
                    } else if (item['mediaURL'] != null && item['mediaURL'].toString().isNotEmpty) {
                      coverImage = item['mediaURL'];
                    }

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      clipBehavior: Clip.antiAlias,
                      child: InkWell(
                        onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => EducationDetailScreen(article: item))),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            if (coverImage != null)
                              Image.network(coverImage, height: 150, width: double.infinity, fit: BoxFit.cover)
                            else if (item['videoURL'] != null)
                              Container(height: 150, width: double.infinity, color: Colors.black87, child: const Icon(Icons.play_circle_fill, color: Colors.white, size: 50)),

                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                children: [
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                          decoration: BoxDecoration(color: Colors.teal.shade100, borderRadius: BorderRadius.circular(10)),
                                          child: Text(item['category'] ?? 'General', style: const TextStyle(fontSize: 10, color: Colors.teal)),
                                        ),
                                        const SizedBox(height: 5),
                                        Text(item['title'] ?? '', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold), maxLines: 1, overflow: TextOverflow.ellipsis),
                                        if (isPending)
                                          const Text("(Pending Approval)", style: TextStyle(color: Colors.red, fontSize: 12, fontWeight: FontWeight.bold)),
                                      ],
                                    ),
                                  ),
                                  if (item['userID'] == currentUserId || _userRole == 'Admin')
                                    Row(
                                      children: [
                                        IconButton(icon: const Icon(Icons.edit, size: 20, color: Colors.grey), onPressed: () => _showForm(item: item)),
                                        IconButton(icon: const Icon(Icons.delete, size: 20, color: Colors.red), onPressed: () async {
                                          await _supabase.from('pet_material').delete().eq('materialID', item['materialID']);
                                        }),
                                      ],
                                    ),
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
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          onPressed: () => _showForm(),
          child: const Icon(Icons.add)
      ),
    );
  }

  Widget _buildFilterChip(String label) {
    bool isSelected = _selectedFilterCategory == label;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: isSelected,
        selectedColor: Colors.teal,
        labelStyle: TextStyle(color: isSelected ? Colors.white : Colors.black87),
        onSelected: (bool selected) {
          if (selected) setState(() => _selectedFilterCategory = label);
        },
      ),
    );
  }
}

// ==========================================
// 详情页：支持多图滑动和视频链接跳转
// ==========================================
class EducationDetailScreen extends StatelessWidget {
  final Map<String, dynamic> article;
  const EducationDetailScreen({super.key, required this.article});

  Future<void> _launchVideoUrl(BuildContext context, String url) async {
    String finalUrl = url.trim();

    // 强制自动补全 https:// 协议，否则 url_launcher 会毫无反应
    if (!finalUrl.startsWith('http://') && !finalUrl.startsWith('https://')) {
      finalUrl = 'https://$finalUrl';
    }

    final Uri uri = Uri.parse(finalUrl);

    try {
      final bool launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
      if (!launched && context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Could not open the video link.')));
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error launching video: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    List<String> images = [];
    if (article['mediaURLs'] != null) {
      images = List<String>.from(article['mediaURLs']);
    } else if (article['mediaURL'] != null && article['mediaURL'].toString().isNotEmpty) {
      images.add(article['mediaURL']);
    }

    final String? videoUrl = article['videoURL'];

    return Scaffold(
      appBar: AppBar(
        title: const Text("Article"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (images.isNotEmpty)
              SizedBox(
                height: 250,
                child: PageView.builder(
                  itemCount: images.length,
                  itemBuilder: (context, index) {
                    return Image.network(images[index], width: double.infinity, fit: BoxFit.cover);
                  },
                ),
              ),

            if (images.length > 1)
              Center(
                child: Padding(
                  padding: const EdgeInsets.only(top: 8.0),
                  child: Text("Swipe to see more photos (${images.length})", style: const TextStyle(color: Colors.grey, fontSize: 12)),
                ),
              ),

            if (videoUrl != null && videoUrl.isNotEmpty)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.all(16),
                child: ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent, foregroundColor: Colors.white, padding: const EdgeInsets.symmetric(vertical: 12)),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text("Watch Video"),
                  onPressed: () => _launchVideoUrl(context, videoUrl),
                ),
              ),

            Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(color: Colors.teal.shade50, borderRadius: BorderRadius.circular(15)),
                    child: Text(article['category'] ?? 'General Care', style: const TextStyle(color: Colors.teal, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 15),
                  Text(article['title'] ?? '', style: const TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 20),
                  Text(article['content'] ?? '', style: const TextStyle(fontSize: 16, height: 1.5)),
                  const SizedBox(height: 40),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}