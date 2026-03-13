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

  // Helper: Check if vaccine is expiring soon (within 30 days but not expired)
  bool _isVaccineExpiringSoon(DateTime? expiry) {
    if (expiry == null) return false;
    final now = DateTime.now();
    return expiry.isBefore(now.add(const Duration(days: 30))) && !expiry.isBefore(now);
  }

  // Helper: Check if vaccine is already expired
  bool _isVaccineExpired(DateTime? expiry) {
    if (expiry == null) return false;
    return expiry.isBefore(DateTime.now());
  }

  // Helper: Calculate precise age (years, months, or days)
  String _calculateAge(String? birthDateStr) {
    if (birthDateStr == null || birthDateStr.isEmpty) return '-';

    final birthDate = DateTime.tryParse(birthDateStr);
    if (birthDate == null) return '-';

    final now = DateTime.now();
    int years = now.year - birthDate.year;
    int months = now.month - birthDate.month;
    int days = now.day - birthDate.day;

    // Adjust if birthday hasn't occurred this year
    if (months < 0 || (months == 0 && days < 0)) {
      years--;
    }

    if (years > 0) {
      return '$years yr${years > 1 ? 's' : ''}';
    } else if (months > 0) {
      return '$months mo${months > 1 ? 's' : ''}';
    } else {
      return '$days day${days > 1 ? 's' : ''}';
    }
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
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text("Failed to load pets. Please try again."),
            action: SnackBarAction(
              label: "Retry",
              onPressed: _fetchPets,
            ),
          ),
        );
      }
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
          // Top quick actions
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

          // Pet list title
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

          // Pet list
          Expanded(
            child: _pets.isEmpty ? _buildEmptyState() : _buildPetList(),
          ),
        ],
      ),
    );
  }

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

  Widget _buildPetList() {
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: _pets.length,
      itemBuilder: (context, index) {
        final pet = _pets[index];
        final String photoUrl = pet['petPhoto']?.toString() ?? '';

        // Calculate age precisely
        final String ageText = _calculateAge(pet['birthDate']);

        // Vaccine status
        String vaccineStatus = "Protected";
        Color vaccineColor = Colors.green;

        if (pet['vaccinationExpiry'] != null) {
          final expiryDate = DateTime.tryParse(pet['vaccinationExpiry'].toString());
          if (expiryDate != null) {
            if (_isVaccineExpired(expiryDate)) {
              vaccineStatus = "Expired!";
              vaccineColor = Colors.red;
            } else if (_isVaccineExpiringSoon(expiryDate)) {
              vaccineStatus = "Due soon!";
              vaccineColor = Colors.orange;
            }
          }
        }

        // Weight display
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
                Text(
                  '${pet['species']} | ${pet['breed']} | $ageText',
                  style: TextStyle(color: Colors.grey[600], fontSize: 13),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
                    // Weight
                    Icon(Icons.monitor_weight_outlined, size: 14, color: themeColor),
                    const SizedBox(width: 4),
                    Text(
                      weightText,
                      style: TextStyle(color: themeColor, fontSize: 12, fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(width: 12),

                    // Vaccine status
                    if (pet['vaccinationExpiry'] != null) ...[
                      Icon(Icons.vaccines, size: 14, color: vaccineColor),
                      const SizedBox(width: 4),
                      Text(
                        vaccineStatus,
                        style: TextStyle(color: vaccineColor, fontSize: 11),
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
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text("Register First Pet", style: TextStyle(color: Colors.white)),
          )
        ],
      ),
    );
  }
}