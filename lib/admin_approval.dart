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

  Future<void> _handleAction(String id, bool approve, String table, String idField) async {
    setState(() {
      _processedIds.add(id);
    });

    try {
      if (approve) {
        // .select() ensures the Realtime stream is triggered immediately
        await _supabase
            .from(table)
            .update({'isApproved': true})
            .eq(idField, id)
            .select();
      } else {
        await _supabase.from(table).delete().eq(idField, id);
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

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5, // Adoption, Lost, Found, Education, Forum
      child: Scaffold(
        appBar: AppBar(
          title: const Text("Admin Approval", style: TextStyle(fontWeight: FontWeight.bold)),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            isScrollable: true,
            indicatorColor: Colors.orange,
            tabs: [
              Tab(text: "Adoption"), Tab(text: "Lost"),
              Tab(text: "Found"), Tab(text: "Education"),
              Tab(text: "Forum"),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildApprovalList('adoption_posts', 'adoptionPostID', 'petName'),
            _buildApprovalList('lost_post', 'lostPostID', 'location'),
            _buildApprovalList('found_post', 'foundPostID', 'location'),
            _buildApprovalList('pet_material', 'materialID', 'title'),
            _buildApprovalList('forum_post', 'forumPostID', 'title'), // Matches your DB
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalList(String table, String idKey, String titleKey) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase.from(table).stream(primaryKey: [idKey]),
      builder: (context, snapshot) {
        if (snapshot.hasData) {
          // This will tell you if the database is sending ANY data at all
          debugPrint("Admin Stream [${table}]: Received ${snapshot.data!.length} total rows");
        }
        if (snapshot.hasError) debugPrint("Stream Error: ${snapshot.error}");

        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        final items = snapshot.data!.where((item) {
          final id = item[idKey].toString();
          // Show if isApproved is false OR null, and not in local processed set
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

            // Updated to include 'attachedFileURL' for Forum Posts
            final String? imagePath = item['mediaURL'] ??
                item['photoURL'] ??
                item['imageURL'] ??
                item['attachedFileURL']; // Add this line

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
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
                subtitle: Text("ID: $itemId"),
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      icon: const Icon(Icons.check_circle, color: Colors.green),
                      onPressed: () => _handleAction(itemId, true, table, idKey),
                    ),
                    IconButton(
                      icon: const Icon(Icons.cancel, color: Colors.red),
                      onPressed: () => _handleAction(itemId, false, table, idKey),
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