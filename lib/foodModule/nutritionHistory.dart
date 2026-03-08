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
        // 查询该宠物所有日期早于今天 (< today) 的记录
        future: supabase
            .from('nutrition')
            .select()
            .eq('petID', petID)
            .lt('date', today) // 过滤掉今天的数据
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

          // --- 核心逻辑：按日期分组求和 ---
          // 因为数据库里一天可能有多次喂食，我们要把同一天的加在一起
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

          // 将 Map 转换为 List 方便显示
          List<String> sortedDates = dailyTotals.keys.toList()..sort((a, b) => b.compareTo(a));

          return ListView.builder(
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
          );
        },
      ),
    );
  }
}