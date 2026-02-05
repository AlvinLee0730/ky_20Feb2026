import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});
  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final _supabase = Supabase.instance.client;

  // Local set to track IDs that are currently being processed
  // This ensures they disappear IMMEDIATELY from the UI
  final Set<String> _processedIds = {};

  Future<void> _handleAction(String id, bool approve, String table, String idField) async {
    setState(() {
      _processedIds.add(id); // Instant UI removal
    });

    try {
      if (approve) {
        await _supabase.from(table).update({'isApproved': true}).eq(idField, id);
      } else {
        await _supabase.from(table).delete().eq(idField, id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(approve ? "Approved Successfully" : "Rejected and Deleted")),
        );
      }
    } catch (e) {
      // If it fails, remove from set so it reappears for a retry
      setState(() {
        _processedIds.remove(id);
      });
      debugPrint("Admin Action Error: $e");
    }
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 4,
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
            ],
          ),
        ),
        body: TabBarView(
          children: [
            _buildApprovalList('adoption_posts', 'adoptionPostID', 'petName'),
            _buildApprovalList('lost_post', 'lostPostID', 'location'),
            _buildApprovalList('found_post', 'foundPostID', 'location'),
            _buildApprovalList('pet_material', 'materialID', 'title'),
          ],
        ),
      ),
    );
  }

  Widget _buildApprovalList(String table, String idKey, String titleKey) {
    return StreamBuilder<List<Map<String, dynamic>>>(
      stream: _supabase
          .from(table)
          .stream(primaryKey: [idKey])
          .order(idKey),
      builder: (context, snapshot) {
        if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

        // FILTER LOGIC:
        // 1. Must have isApproved == false
        // 2. Must NOT be in the _processedIds set (Optimistic UI)
        final items = snapshot.data!.where((item) {
          final id = item[idKey].toString();
          return item['isApproved'] == false && !_processedIds.contains(id);
        }).toList();

        if (items.isEmpty) {
          return Center(child: Text("No pending posts in ${table.replaceAll('_', ' ')}"));
        }

        return ListView.builder(
          itemCount: items.length,
          itemBuilder: (context, index) {
            final item = items[index];
            final String itemId = item[idKey].toString();
            final String? imagePath = item['mediaURL'] ?? item['photoURL'];

            return Card(
              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              child: ListTile(
                leading: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: imagePath != null
                      ? Image.network(imagePath, width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.description),
                ),
                title: Text(item[titleKey] ?? "No Title"),
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