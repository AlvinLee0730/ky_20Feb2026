import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

class AdminApprovalPage extends StatefulWidget {
  const AdminApprovalPage({super.key});
  @override
  State<AdminApprovalPage> createState() => _AdminApprovalPageState();
}

class _AdminApprovalPageState extends State<AdminApprovalPage> {
  final _supabase = Supabase.instance.client;
  final Set<String> _locallyProcessedIds = {};

  // STREAM: Only pending posts (isApproved = false)
  Stream<List<Map<String, dynamic>>> get _pendingStream => _supabase
      .from('adoption_posts')
      .stream(primaryKey: ['adoptionPostID'])
      .eq('isApproved', false)
      .order('uploadDate', ascending: true);

  Future<void> _handlePost(String id, bool approve) async {
    setState(() => _locallyProcessedIds.add(id));
    try {
      if (approve) {
        // UPDATE the database
        await _supabase
            .from('adoption_posts')
            .update({'isApproved': true})
            .eq('adoptionPostID', id);
      } else {
        // DELETE the database entry
        await _supabase
            .from('adoption_posts')
            .delete()
            .eq('adoptionPostID', id);
      }

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(approve ? "Post Approved!" : "Post Rejected"))
        );
      }
    } catch (e) {
      // If it fails, put it back in the list
      setState(() => _locallyProcessedIds.remove(id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text("Error: $e"), backgroundColor: Colors.red)
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text("Pending Approvals"), backgroundColor: Colors.teal, foregroundColor: Colors.white),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _pendingStream,
        builder: (context, snapshot) {
          if (snapshot.hasError) return Center(child: Text("Error: ${snapshot.error}"));
          if (!snapshot.hasData) return const Center(child: CircularProgressIndicator());

          // Filter out IDs that were just clicked to prevent "flickering"
          final posts = snapshot.data!
              .where((p) => !_locallyProcessedIds.contains(p['adoptionPostID'].toString()))
              .toList();

          if (posts.isEmpty) return const Center(child: Text("No pending posts."));

          return ListView.builder(
            itemCount: posts.length,
            itemBuilder: (context, index) {
              final post = posts[index];
              final id = post['adoptionPostID'].toString();
              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 15, vertical: 8),
                child: ListTile(
                  leading: post['photoURL'] != null
                      ? Image.network(post['photoURL'], width: 50, height: 50, fit: BoxFit.cover)
                      : const Icon(Icons.pets),
                  title: Text(post['petName'] ?? "Unnamed Pet"),
                  subtitle: Text("${post['breed'] ?? "Unknown"} • ID: $id"),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                          icon: const Icon(Icons.check_circle, color: Colors.green),
                          onPressed: () => _handlePost(id, true)
                      ),
                      IconButton(
                          icon: const Icon(Icons.cancel, color: Colors.red),
                          onPressed: () => _handlePost(id, false)
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}