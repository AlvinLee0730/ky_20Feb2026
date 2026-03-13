import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});
  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final _supabase = Supabase.instance.client;
  final Set<String> _processedIds = {};

  // 接收 postOwnerId (发帖者的 userID) 以发送通知
  Future<void> _handleAction(String id, bool approve, String table, String idField, String? postOwnerId) async {
    setState(() {
      _processedIds.add(id);
    });

    try {
      if (approve) {
        await _supabase
            .from(table)
            .update({'isApproved': true})
            .eq(idField, id)
            .select(); // trigger stream update
      } else {
        await _supabase.from(table).delete().eq(idField, id);
      }

      // 给用户发系统通知
      if (postOwnerId != null) {
        String friendlyTableName = table.replaceAll('_', ' ').toUpperCase();
        await _supabase.from('system_notifications').insert({
          'userID': postOwnerId,
          'title': approve ? 'Post Approved' : 'Post Rejected',
          'message': 'Your post in $friendlyTableName has been ${approve ? "approved! It is now live." : "rejected by the admin."}'
        });
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? "Approved Successfully" : "Rejected and Deleted")),
        );
      }
    } catch (e) {
      setState(() {
        _processedIds.remove(id);
      });
      debugPrint("Admin Action Error: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text("Error: $e")));
      }
    }
  }

  // 动态展示帖子详情的弹窗（修复了不显示的问题）
  void _showPostDetails(Map<String, dynamic> item, String table, String idKey, String itemId, String? postOwnerId) {
    String? coverImage;

    // 安全地提取图片，防止因为格式不对导致弹窗崩溃
    try {
      if (item['mediaURLs'] != null && item['mediaURLs'] is List && (item['mediaURLs'] as List).isNotEmpty) {
        coverImage = item['mediaURLs'][0];
      } else {
        coverImage = item['mediaURL'] ?? item['photoURL'] ?? item['imageURL'] ?? item['attachedFileURL'];
      }
    } catch (e) {
      debugPrint("Image parse error: $e");
    }

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Post Details", style: TextStyle(fontWeight: FontWeight.bold)),
            // 加上明确的宽度约束，防止 Flutter 渲染崩溃导致啥都不显示
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (coverImage != null && coverImage.toString().isNotEmpty) ...[
                      ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.network(
                          coverImage,
                          width: double.infinity,
                          height: 200,
                          fit: BoxFit.cover,
                          errorBuilder: (c, e, s) => Container(
                            height: 200, color: Colors.grey.shade200,
                            child: const Icon(Icons.broken_image, size: 50, color: Colors.grey),
                          ),
                        ),
                      ),
                      const SizedBox(height: 15),
                    ],

                    // 安全遍历数据，过滤掉空值和链接
                    ...item.keys.where((key) {
                      final val = item[key];
                      return val != null &&
                          val.toString().trim().isNotEmpty &&
                          !['mediaURL', 'mediaURLs', 'photoURL', 'imageURL', 'attachedFileURL', 'isApproved'].contains(key);
                    }).map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              TextSpan(text: "${key.toUpperCase()}: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                              TextSpan(text: item[key].toString()),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ],
                ),
              ),
            ),
            actions: [
              TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text("Close", style: TextStyle(color: Colors.grey))
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.cancel, size: 16, color: Colors.white),
                label: const Text("Reject", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  _handleAction(itemId, false, table, idKey, postOwnerId);
                },
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.check_circle, size: 16, color: Colors.white),
                label: const Text("Approve", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  Navigator.pop(context);
                  _handleAction(itemId, true, table, idKey, postOwnerId);
                },
              ),
            ],
          );
        }
    );
  }

  Widget _buildBadgedTab(String label, String table, String idKey) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from(table).stream(primaryKey: [idKey]),
      builder: (context, snapshot) {
        int count = 0;
        if (snapshot.hasData) {
          count = snapshot.data!.where((item) {
            final isPending = item['isApproved'] == false || item['isApproved'] == null;
            final notProcessed = !_processedIds.contains(item[idKey].toString());
            return isPending && notProcessed;
          }).length;
        }

        return Tab(
          child: Badge(
            isLabelVisible: count > 0,
            label: Text(count.toString()),
            child: Text(label),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Adoption, Lost, Found, Education, Forum
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Approval", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: TabBar(
            // 关键修改 1：关闭滚动，强行挤在同一页
            isScrollable: false,
            // 关键修改 2：去除 Padding 并调小字体，确保 5 个字不超标
            labelPadding: EdgeInsets.zero,
            labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.bold),
            unselectedLabelStyle: const TextStyle(fontSize: 11),
            indicatorColor: Colors.orange,
            tabs: [
              _buildBadgedTab("Adoption", "adoption_posts", "adoptionPostID"),
              _buildBadgedTab("Lost", "lost_post", "lostPostID"),
              _buildBadgedTab("Found", "found_post", "foundPostID"),
              _buildBadgedTab("Education", "pet_material", "materialID"),
              _buildBadgedTab("Forum", "forum_post", "forumPostID"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildApprovalList('adoption_posts', 'adoptionPostID', 'petName'),
            _buildApprovalList('lost_post', 'lostPostID', 'location'),
            _buildApprovalList('found_post', 'foundPostID', 'location'),
            _buildApprovalList('pet_material', 'materialID', 'title'),
            _buildApprovalList('forum_post', 'forumPostID', 'title'),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalList(String table, String idKey, String titleKey) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from(table).stream(primaryKey: [idKey]),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final items = snapshot.data!.where((item) {
          final id = item[idKey].toString();
          final isApprovedValue = item['isApproved'];
          final bool isPending = isApprovedValue == false || isApprovedValue == null;

          return isPending && !_processedIds.contains(id);
        }).toList();

        if (items.isEmpty) {
          return Center(child: Text("No pending posts in ${table.replaceAll('_', ' ')}"));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final String itemId = item[idKey].toString();
            final String? postOwnerId = item['userID'];

            String? imagePath;
            try {
              if (item['mediaURLs'] != null && item['mediaURLs'] is List && (item['mediaURLs'] as List).isNotEmpty) {
                imagePath = item['mediaURLs'][0];
              } else {
                imagePath = item['mediaURL'] ?? item['photoURL'] ?? item['imageURL'] ?? item['attachedFileURL'];
              }
            } catch (e) {
              imagePath = null;
            }

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                // 关键修改 3：绑定点击事件（点击列表里的任何文字/图片即可触发详情弹窗）
                onTap: () => _showPostDetails(item, table, idKey, itemId, postOwnerId),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath != null && imagePath.isNotEmpty
                      ? Image.network(
                    imagePath,
                    width: 50,
                    height: 50,
                    fit: BoxFit.cover,
                    errorBuilder: (c, e, s) => const Icon(Icons.broken_image),
                  )
                      : const Icon(Icons.forum_outlined),
                ),
                title: Text(
                    item[titleKey] ?? "No Title",
                    style: const TextStyle(fontWeight: FontWeight.bold)
                ),
                subtitle: const Text("Tap to view details", style: TextStyle(color: Colors.teal, fontSize: 12)),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _handleAction(itemId, true, table, idKey, postOwnerId),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _handleAction(itemId, false, table, idKey, postOwnerId),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}