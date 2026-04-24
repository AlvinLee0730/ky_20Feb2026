import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NutritionHistoryPage extends StatefulWidget {
  final String petID;
  const NutritionHistoryPage({super.key, required this.petID});

  @override
  State<NutritionHistoryPage> createState() => _NutritionHistoryPageState();
}

class _NutritionHistoryPageState extends State<NutritionHistoryPage> {
  final supabase = Supabase.instance.client;

  // Store the future here so it only fetches ONCE when the page loads
  late Future<List<dynamic>> _historyFuture;

  @override
  void initState() {
    super.initState();
    _fetchHistory();
  }

  void _fetchHistory() {
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());
    _historyFuture = supabase
        .from('nutrition')
        .select()
        .eq('petID', widget.petID)
        .lt('date', today)
        .order('date', ascending: false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Nutrition History"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder<List<dynamic>>(
        future: _historyFuture, // Use the stored future
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final List rawData = snapshot.data ?? [];

          if (rawData.isEmpty) {
            return const Center(
              child: Text("No past records found.", style: TextStyle(color: Colors.grey)),
            );
          }

          // Group by date and calculate totals
          Map<String, Map<String, double>> dailyTotals = {};

          for (var row in rawData) {
            String date = row['date'].toString();
            if (!dailyTotals.containsKey(date)) {
              dailyTotals[date] = {'cal': 0, 'pro': 0, 'fat': 0};
            }
            dailyTotals[date]!['cal'] = dailyTotals[date]!['cal']! + (row['calory'] as num? ?? 0).toDouble();
            dailyTotals[date]!['pro'] = dailyTotals[date]!['pro']! + (row['protein'] as num? ?? 0).toDouble();
            dailyTotals[date]!['fat'] = dailyTotals[date]!['fat']! + (row['fat'] as num? ?? 0).toDouble();
          }

          List<String> sortedDates = dailyTotals.keys.toList()..sort((a, b) => b.compareTo(a));

          return Column(
            children: [
              // Notice Banner (Translated to English to match the rest of the UI)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.teal.withOpacity(0.1),
                child: const Text(
                  "Showing past records only. Check today's overview for today's nutrition.",
                  style: TextStyle(color: Colors.teal, fontSize: 14),
                  textAlign: TextAlign.center,
                ),
              ),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: sortedDates.length,
                  itemBuilder: (context, index) {
                    String date = sortedDates[index];
                    var stats = dailyTotals[date]!;

                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(15)),
                      elevation: 2,
                      child: ListTile(
                        contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                        leading: const CircleAvatar(
                          backgroundColor: Colors.teal,
                          child: Icon(Icons.calendar_month, color: Colors.white, size: 20),
                        ),
                        title: Text(
                          date,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            "Calories: ${stats['cal']!.toStringAsFixed(1)} kcal\n"
                                "Protein: ${stats['pro']!.toStringAsFixed(1)}g | Fat: ${stats['fat']!.toStringAsFixed(1)}g",
                            style: TextStyle(color: Colors.grey[700], height: 1.4),
                          ),
                        ),
                        // Removed the chevron_right icon to prevent confusion,
                        // since there is no onTap detail page implemented yet.
                      ),
                    );
                  },
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}