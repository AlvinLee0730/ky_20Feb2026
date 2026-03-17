import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart'; // 🌟 新增：导入日期格式化工具

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});
  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final _supabase = Supabase.instance.client;
  final Set<String> _processedIds = {};

  // 万能图片解析器
  String? _extractImage(Map<String, dynamic> item) {
    try {
      final possibleImageKeys = [
        'imageURL', 'photoURL', 'mediaURLs', 'mediaURL', 'attachedFileURL',
        'image', 'photo', 'imageUrl', 'photoUrl', 'coverImage', 'coverPhoto'
      ];

      for (var key in possibleImageKeys) {
        if (item[key] != null && item[key].toString().trim().isNotEmpty) {
          var val = item[key];

          if (val is List && val.isNotEmpty) {
            return val[0].toString();
          }
          else if (val is String) {
            if (val.startsWith('[') && val.endsWith(']')) {
              final cleanUrls = val.replaceAll(RegExp(r'[\[\]\"\x27]'), '').split(',');
              if (cleanUrls.isNotEmpty && cleanUrls[0].trim().startsWith('http')) {
                return cleanUrls[0].trim();
              }
            }
            else if (val.startsWith('http')) {
              return val;
            }
          }
        }
      }
    } catch (e) {
      debugPrint("Image parse error: $e");
    }
    return null;
  }

  // 字段名格式化工具 (把 lostPostID 变成 LOST POST ID)
  String _formatFieldName(String key) {
    String formatted = key.replaceAll('_', ' ');
    formatted = formatted.replaceAllMapped(RegExp(r'(?<=[a-z])([A-Z])'), (Match m) => ' ${m.group(1)}');
    return formatted.toUpperCase();
  }

  // 🌟 新增：专门用来处理“机器时间”变成“人类时间”的工具
  String _formatValue(String key, dynamic val) {
    String strVal = val.toString();

    // 如果这个字段的名称里包含 date, time 或者 created_at，说明它是时间
    if (key.toLowerCase().contains('date') || key.toLowerCase().contains('time') || key.toLowerCase() == 'created_at') {
      try {
        // 把数据库的 UTC 时间转换成手机本地时间，并排版
        final parsedDate = DateTime.parse(strVal).toLocal();
        return DateFormat('MMM dd, yyyy, hh:mm a').format(parsedDate);
      } catch (e) {
        // 如果万一解析失败，就原样显示，不至于报错
        return strVal;
      }
    }
    return strVal;
  }

  // 接收 postOwnerId 以发送通知
  Future<void> _handleAction(String id, bool approve, String table, String idField, String? postOwnerId, {String? rejectReason}) async {
    setState(() {
      _processedIds.add(id);
    });

    try {
      if (approve) {
        await _supabase
            .from(table)
            .update({'isApproved': true})
            .eq(idField, id)
            .select();
      } else {
        await _supabase.from(table).delete().eq(idField, id);
      }

      if (postOwnerId != null) {
        String friendlyTableName = table.replaceAll('_', ' ').toUpperCase();

        String notificationMessage = approve
            ? 'Your post in $friendlyTableName has been approved! It is now live.'
            : 'Your post in $friendlyTableName has been rejected by the admin.';

        if (!approve && rejectReason != null && rejectReason.isNotEmpty) {
          notificationMessage += '\nReason: $rejectReason';
        }

        await _supabase.from('system_notifications').insert({
          'userID': postOwnerId,
          'title': approve ? 'Post Approved' : 'Post Rejected',
          'message': notificationMessage
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

  // 填写拒绝理由的弹窗
  void _showRejectDialog(String itemId, String table, String idKey, String? postOwnerId) {
    final TextEditingController reasonController = TextEditingController();

    showDialog(
        context: context,
        builder: (ctx) {
          return AlertDialog(
            title: const Text("Reject Post", style: TextStyle(fontWeight: FontWeight.bold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text("Please provide a reason for rejecting this post. This will be sent to the user.", style: TextStyle(fontSize: 13, color: Colors.grey)),
                const SizedBox(height: 15),
                TextField(
                  controller: reasonController,
                  decoration: const InputDecoration(
                    labelText: "Rejection Reason",
                    border: OutlineInputBorder(),
                    hintText: "e.g., Inappropriate content, missing info...",
                  ),
                  maxLines: 3,
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                child: const Text("Cancel", style: TextStyle(color: Colors.grey)),
              ),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(backgroundColor: Colors.red),
                icon: const Icon(Icons.cancel, size: 16, color: Colors.white),
                label: const Text("Confirm Reject", style: TextStyle(color: Colors.white)),
                onPressed: () {
                  final reason = reasonController.text.trim();
                  if (reason.isEmpty) {
                    ScaffoldMessenger.of(ctx).showSnackBar(const SnackBar(content: Text("Please provide a reason!")));
                    return;
                  }
                  Navigator.pop(ctx);
                  _handleAction(itemId, false, table, idKey, postOwnerId, rejectReason: reason);
                },
              ),
            ],
          );
        }
    );
  }

  // 弹窗展示详情
  Future<void> _showPostDetails(Map<String, dynamic> item, String table, String idKey, String itemId, String? postOwnerId) async {
    String? coverImage = _extractImage(item);

    String authorName = "Unknown User";
    String authorEmail = "Unknown Email";

    if (postOwnerId != null) {
      try {
        final userRes = await _supabase.from('users').select('userName, userEmail').eq('userID', postOwnerId).maybeSingle();
        if (userRes != null) {
          authorName = userRes['userName'] ?? "Unknown User";
          authorEmail = userRes['userEmail'] ?? "Unknown Email";
        }
      } catch (e) {
        debugPrint("Fetch User Error: $e");
      }
    }

    if (!mounted) return;

    showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: const Text("Post Details", style: TextStyle(fontWeight: FontWeight.bold)),
            content: SizedBox(
              width: double.maxFinite,
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (coverImage != null) ...[
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

                    Padding(
                      padding: const EdgeInsets.only(bottom: 8.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            const TextSpan(text: "AUTHOR NAME: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            TextSpan(text: authorName),
                          ],
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12.0),
                      child: RichText(
                        text: TextSpan(
                          style: const TextStyle(color: Colors.black87, fontSize: 14),
                          children: [
                            const TextSpan(text: "AUTHOR EMAIL: ", style: TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),
                            TextSpan(text: authorEmail),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    const SizedBox(height: 8),

                    // 安全遍历数据
                    ...item.keys.where((key) {
                      final val = item[key];
                      return val != null &&
                          val.toString().trim().isNotEmpty &&
                          !['mediaURL', 'mediaURLs', 'photoURL', 'imageURL', 'attachedFileURL', 'isApproved', 'userID', 'likeCount', 'replyCount'].contains(key);
                    }).map((key) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: RichText(
                          text: TextSpan(
                            style: const TextStyle(color: Colors.black87, fontSize: 14),
                            children: [
                              TextSpan(text: "${_formatFieldName(key)}: ", style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.teal)),

                              // 🌟 修改点：在这里呼叫时间格式化工具处理值
                              TextSpan(text: _formatValue(key, item[key])),
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
                  _showRejectDialog(itemId, table, idKey, postOwnerId);
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
      length: 5,
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Approval", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: TabBar(
            isScrollable: false,
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

            String? imagePath = _extractImage(item);

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                onTap: () => _showPostDetails(item, table, idKey, itemId, postOwnerId),
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath != null
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
                      onPressed: () => _showRejectDialog(itemId, table, idKey, postOwnerId),
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