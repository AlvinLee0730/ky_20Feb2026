import 'package:flutter/material.dart';
import 'addPet.dart';
import 'editPet.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:newfypken/scheduleModule/schedule.dart';
import 'package:newfypken/foodModule/foodListPage.dart';

final supabase = Supabase.instance.client;

class PetProfilePage extends StatefulWidget {
  const PetProfilePage({super.key});

  @override
  State<PetProfilePage> createState() => _PetProfilePageState();
}

class _PetProfilePageState extends State<PetProfilePage> {
  final Color themeColor = Colors.teal;
  final double borderRadius = 15.0;

  List<Map<String, dynamic>> _pets = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchPets();
  }

  Future<void> _fetchPets() async {
    setState(() => _loading = true);
    try {
      final userId = supabase.auth.currentUser!.id;
      final response = await supabase
          .from('pet')
          .select()
          .eq('userID', userId)
          .order('petName');
      setState(() {
        _pets = List<Map<String, dynamic>>.from(response);
      });
    } catch (e) {
      debugPrint("Fetch pets error: $e");
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        body: Center(child: CircularProgressIndicator(color: themeColor)),
      );
    }

    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: const Text("Pet Dashboard", style: TextStyle(fontWeight: FontWeight.bold)),
        backgroundColor: themeColor,
        foregroundColor: Colors.white,
        centerTitle: true,
        elevation: 0,
      ),
      body: Column(
        children: [
          // ================= 顶部功能区 (Grid Layout) =================
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: themeColor,
              borderRadius: const BorderRadius.vertical(bottom: Radius.circular(30)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _buildQuickAction(Icons.add_circle_outline, "Add Pet", () async {
                  final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePetPage()));
                  if (result == true) _fetchPets();
                }),
                _buildQuickAction(Icons.calendar_month, "Schedule", () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => SchedulePage(pets: _pets, petIds: _pets.map((p) => p['petID'].toString()).toList()),
                    ),
                  );
                }),

                _buildQuickAction(Icons.restaurant, "Food", () {
                  if (_pets.isEmpty) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text("Please add a pet first!")),
                    );
                    return;
                  }

                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => FoodListPage(pets: _pets),
                    ),
                  );
                }),
              ],
            ),
          ),

          const SizedBox(height: 10),

          // ================= 宠物列表标题 =================
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
            child: Row(
              children: [
                const Text("My Pet Family", style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                const Spacer(),
                Text("${_pets.length} Pets", style: TextStyle(color: themeColor, fontWeight: FontWeight.w600)),
              ],
            ),
          ),

          // ================= 宠物列表 =================
          Expanded(
            child: _pets.isEmpty ? _buildEmptyState() : _buildPetList(),
          ),
        ],
      ),
    );
  }

  // 构建顶部圆形功能按钮
  Widget _buildQuickAction(IconData icon, String label, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
          const SizedBox(height: 8),
          Text(label, style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500)),
        ],
      ),
    );
  }

  // ================= 宠物列表 =================
  // ================= 宠物列表 =================
  Widget _buildPetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _pets.length,
      itemBuilder: (context, index) {
        final pet = _pets[index];
        final String photoUrl = pet['petPhoto']?.toString() ?? '';

        // --- 逻辑处理：计算年龄 ---
        String ageText = '-';
        if (pet['birthDate'] != null) {
          final birthDate = DateTime.parse(pet['birthDate']);
          final years = DateTime.now().year - birthDate.year;
          ageText = '$years yr${years > 1 ? 's' : ''}';
        }

        // --- 逻辑处理：判断疫苗是否快过期 ---
        bool isVaccineExpiring = false;
        if (pet['vaccinationExpiry'] != null) {
          final expiryDate = DateTime.parse(pet['vaccinationExpiry']);
          // 如果过期时间少于 30 天，显示警告
          isVaccineExpiring = expiryDate.isBefore(DateTime.now().add(const Duration(days: 30)));
        }

        // --- 逻辑处理：体重展示 ---
        final weightText = pet['weight'] != null ? "${pet['weight']} kg" : "No weight";

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(borderRadius),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 10, offset: const Offset(0, 4))],
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            leading: Container(
              width: 65,
              height: 65,
              decoration: BoxDecoration(
                color: themeColor.withOpacity(0.1),
                borderRadius: BorderRadius.circular(15),
                image: photoUrl.isNotEmpty ? DecorationImage(image: NetworkImage(photoUrl), fit: BoxFit.cover) : null,
              ),
              child: photoUrl.isEmpty ? Icon(Icons.pets, color: themeColor, size: 30) : null,
            ),
            title: Row(
              children: [
                Text(pet['petName'] ?? '-', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                const SizedBox(width: 8),
                // ⭐ 性别图标
                Icon(
                  pet['gender'] == 'Male' ? Icons.male : Icons.female,
                  size: 16,
                  color: pet['gender'] == 'Male' ? Colors.blue : Colors.pink,
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${pet['species']} | ${pet['breed']} | $ageText', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // ⭐ 显示体重
                    Icon(Icons.monitor_weight_outlined, size: 14, color: themeColor),
                    const SizedBox(width: 4),
                    Text(weightText, style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold)),
                    const SizedBox(width: 12),
                    // ⭐ 疫苗到期提醒
                    if (pet['vaccinationExpiry'] != null) ...[
                      Icon(Icons.vaccines, size: 14, color: isVaccineExpiring ? Colors.orange : Colors.grey),
                      const SizedBox(width: 4),
                      Text(
                        isVaccineExpiring ? "Vaccine Due!" : "Protected",
                        style: TextStyle(color: isVaccineExpiring ? Colors.orange : Colors.grey, fontSize: 11),
                      ),
                    ]
                  ],
                ),
              ],
            ),
            trailing: const Icon(Icons.chevron_right, color: Colors.grey),
            onTap: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => EditPetPage(petData: pet)));
              if (result == true) _fetchPets();
            },
          ),
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.pets, size: 80, color: Colors.grey[300]),
          const SizedBox(height: 16),
          const Text("Start your pet's journey!", style: TextStyle(color: Colors.grey, fontSize: 16)),
          const SizedBox(height: 20),
          ElevatedButton(
            onPressed: () async {
              final result = await Navigator.push(context, MaterialPageRoute(builder: (_) => const CreatePetPage()));
              if (result == true) _fetchPets();
            },
            style: ElevatedButton.styleFrom(
                backgroundColor: themeColor,
                padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 15),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
            child: const Text("Register First Pet", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}
