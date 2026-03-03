import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:intl/intl.dart';
import 'dart:math' as math;

class NutritionPage extends StatefulWidget {
  final Map<String, dynamic> petData;
  const NutritionPage({super.key, required this.petData});

  @override
  State<NutritionPage> createState() => _NutritionPageState();
}

class _NutritionPageState extends State<NutritionPage> {
  final supabase = Supabase.instance.client;
  final Color themeColor = Colors.teal;

  bool _isLoading = true;
  double totalCal = 0.0;
  double totalProtein = 0.0;
  double totalFat = 0.0;
  double totalCarbs = 0.0;
  double totalFiber = 0.0;
  String dynamicTip = "Analyzing data...";

  // 这里的目标会根据体重动态计算
  double dailyCaloryGoal = 300;

  @override
  void initState() {
    super.initState();
    _refreshData();
  }

  // 刷新逻辑：先拿最新体重，再拿今日营养
  Future<void> _refreshData() async {
    await _updatePetWeight();
    await _fetchTodayNutrition();
  }

  // 1. 从数据库获取最新体重并计算目标
  Future<void> _updatePetWeight() async {
    try {
      final petId = widget.petData['petID'];
      final data = await supabase
          .from('pet')
          .select('weight')
          .eq('petID', petId)
          .single();

      if (data != null && data['weight'] != null) {
        double weight = (data['weight'] as num).toDouble();

        double rer = 70 * math.pow(weight, 0.75).toDouble();

        setState(() {
          dailyCaloryGoal = (rer * 1.2).toDouble();
          if (dailyCaloryGoal < 200) dailyCaloryGoal = 300.0;
        });
      }
    } catch (e) {
      debugPrint("Weight Update Error: $e");
    }
  }

  Future<void> _fetchTodayNutrition() async {
    setState(() => _isLoading = true);
    final today = DateFormat('yyyy-MM-dd').format(DateTime.now());

    try {
      final response = await supabase
          .from('nutrition')
          .select()
          .eq('petID', widget.petData['petID'])
          .eq('date', today);

      // ⭐ 明确初始化为 double 0.0
      double cal = 0.0;
      double pro = 0.0;
      double fat = 0.0;
      double carbs = 0.0;
      double fiber = 0.0;

      if (response != null) {
        for (var row in response) {
          cal += (row['calory'] as num? ?? 0.0).toDouble();
          pro += (row['protein'] as num? ?? 0.0).toDouble();
          fat += (row['fat'] as num? ?? 0.0).toDouble();
          carbs += (row['carbs'] as num? ?? 0.0).toDouble();
          fiber += (row['fiber'] as num? ?? 0.0).toDouble();
        }
      }

      // ... 剩下的 Tip 逻辑 ...
      setState(() {
        totalCal = cal;
        totalProtein = pro;
        totalFat = fat;
        totalCarbs = carbs;
        totalFiber = fiber;
      });
    } catch (e) {
      debugPrint("Fetch Error: $e");
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    double progressRatio = totalCal / dailyCaloryGoal;
    bool isOverLimit = totalCal > dailyCaloryGoal;

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text("${widget.petData['petName']}'s Health Analysis"),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _isLoading
          ? Center(child: CircularProgressIndicator(color: themeColor))
          : RefreshIndicator(
        onRefresh: _refreshData,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(20),
          child: Column(
            children: [
              _buildMainCard(progressRatio, isOverLimit),
              const SizedBox(height: 25),
              _buildTipCard(isOverLimit),
              const SizedBox(height: 30),
              const Align(
                alignment: Alignment.centerLeft,
                child: Text("Nutrient Breakdown (g)",
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              ),
              const SizedBox(height: 15),
              _buildNutrientGrid(),
            ],
          ),
        ),
      ),
    );
  }

  // --- 卡路里进度卡片 ---
  Widget _buildMainCard(double progress, bool isOver) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(25),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(25),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 15)],
      ),
      child: Column(
        children: [
          const Text("Daily Calorie Progress", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 10),
          Text(
            "${totalCal.toStringAsFixed(1)} / ${dailyCaloryGoal.toStringAsFixed(0)} kcal",
            style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: isOver ? Colors.redAccent : themeColor
            ),
          ),
          const SizedBox(height: 25),
          Stack(
            children: [
              Container(
                height: 14,
                decoration: BoxDecoration(color: Colors.grey[200], borderRadius: BorderRadius.circular(10)),
              ),
              FractionallySizedBox(
                widthFactor: progress > 1 ? 1 : progress,
                child: Container(
                  height: 14,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: isOver ? [Colors.red, Colors.redAccent] : [themeColor, Colors.tealAccent],
                    ),
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            isOver ? "Limit Exceeded!" : "${(progress * 100).toStringAsFixed(0)}% of daily goal",
            style: TextStyle(color: isOver ? Colors.red : Colors.grey[600], fontWeight: FontWeight.w600),
          ),
        ],
      ),
    );
  }

  // --- 智能建议卡片 ---
  Widget _buildTipCard(bool isOver) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isOver ? Colors.red[50] : themeColor.withOpacity(0.08),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: isOver ? Colors.red[200]! : themeColor.withOpacity(0.3)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(isOver ? Icons.warning_amber_rounded : Icons.auto_awesome,
                  color: isOver ? Colors.red : themeColor),
              const SizedBox(width: 10),
              Text("Health Tip",
                  style: TextStyle(fontWeight: FontWeight.bold, color: isOver ? Colors.red[900] : themeColor)),
            ],
          ),
          const SizedBox(height: 10),
          Text(dynamicTip, style: TextStyle(fontSize: 15, height: 1.5, color: Colors.grey[800])),
        ],
      ),
    );
  }

  // --- 营养网格 ---
  Widget _buildNutrientGrid() {
    return GridView.count(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      crossAxisCount: 2,
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.3,
      children: [
        _nutrientItem("Protein", totalProtein, Colors.orange, Icons.fitness_center),
        _nutrientItem("Fat", totalFat, Colors.redAccent, Icons.opacity),
        _nutrientItem("Carbs", totalCarbs, Colors.blue, Icons.bakery_dining),
        _nutrientItem("Fiber", totalFiber, Colors.green, Icons.eco),
      ],
    );
  }

  Widget _nutrientItem(String title, double value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(15),
          border: Border.all(color: Colors.grey[200]!)
      ),
      child: Row(
        children: [
          Icon(icon, color: color.withOpacity(0.6), size: 20),
          const SizedBox(width: 8),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(title, style: const TextStyle(color: Colors.grey, fontSize: 12)),
              Text("${value.toStringAsFixed(1)}g",
                  style: TextStyle(fontWeight: FontWeight.bold, color: color, fontSize: 15)),
            ],
          ),
        ],
      ),
    );
  }
}