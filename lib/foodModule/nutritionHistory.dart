import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';

class NutritionHistoryPage extends StatelessWidget {
  final String petID; // 接收 String 类型的 UUID
  const NutritionHistoryPage({super.key, required this.petID});

  @override
  Widget build(BuildContext context) {
    final supabase = Supabase.instance.client;
    final String today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Nutrition History"),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: FutureBuilder(
        future: supabase
            .from('nutrition')
            .select()
            .eq('petID', petID)
            .lt('date', today)
            .order('date', ascending: false),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator(color: Colors.teal));
          }

          if (snapshot.hasError) {
            return Center(child: Text("Error: ${snapshot.error}"));
          }

          final List rawData = snapshot.data as List? ?? [];

          if (rawData.isEmpty) {
            return const Center(
              child: Text("No past records found.", style: TextStyle(color: Colors.grey)),
            );
          }

          // 按日期分組求和（原邏輯不變）
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
              // 只加這一段提示
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                color: Colors.teal.withOpacity(0.1),
                child: const Text(
                  "僅顯示過去記錄，今天的營養請查看當日總覽",
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
                        trailing: const Icon(Icons.chevron_right, color: Colors.grey),
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