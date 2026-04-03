import 'package:calligro_app/features/admin/widgets/admin_drawer.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/features/admin/tabs/admin_home_tab.dart';
import 'package:calligro_app/features/admin/tabs/admin_profile_tab.dart';
import 'package:calligro_app/features/admin/pages/admin_users.dart';
import 'package:calligro_app/features/community/pages/community_page.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

class AdminDashboardPage extends StatefulWidget {
  const AdminDashboardPage({super.key});

  @override
  State<AdminDashboardPage> createState() => _AdminDashboardPageState();
}

class _AdminDashboardPageState extends State<AdminDashboardPage> {
  int _selectedIndex = 0;
  final AdminService _adminService = AdminService();

  String _userName = "Admin";
  String _userEmail = "admin@calligro.com";
  String _userProfileImage = "";
  bool _isLoading = true;

  final List<Widget> _pages = [];

  @override
  void initState() {
    super.initState();
    _fetchUserData();
  }

  Future<void> _fetchUserData() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null) {
      final doc = await FirebaseFirestore.instance.collection('users').doc(user.uid).get();
      if (doc.exists && mounted) {
        final data = doc.data() as Map<String, dynamic>;
        setState(() {
          _userName = data['name'] ?? "Admin";
          _userEmail = data['email'] ?? user.email ?? "";
          _userProfileImage = data['photoUrl'] ?? "";
          _isLoading = false;
          _initializePages();
        });
        return;
      }
    }
    if (mounted) {
      setState(() {
        _isLoading = false;
        _initializePages();
      });
    }
  }

  void _initializePages() {
    _pages.clear();
    _pages.addAll([
      const AdminHomeTab(),
      const AdminUsersPage(),
      CommunityPage(onProfileTap: (uid, role) {
        // Handle profile tap if needed
      }),
      AdminProfileTab(
        userName: _userName,
        userEmail: _userEmail,
        userProfileImage: _userProfileImage,
      ),
    ]);
  }

  void _onNavTap(int index) {
    setState(() => _selectedIndex = index);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(
        backgroundColor: AppColors.primary,
        body: Center(child: CircularProgressIndicator(color: Colors.amber)),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.primary,
      drawer: const AdminDrawer(),
      appBar: _selectedIndex == 0 ? AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white), 
        title: Text(
          AppLocalizations.of(context)!.adminDashboard,
          style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign_outlined, color: Colors.amber),
            onPressed: () => _showBroadcastDialog(context),
          ),
          const SizedBox(width: 8),
        ],
      ) : null,
      body: IndexedStack(
        index: _selectedIndex,
        children: _pages,
      ),
      bottomNavigationBar: BottomAppBar(
        color: AppColors.cardBackground,
        elevation: 0,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _buildNavItem(0, Icons.home_outlined, Icons.home, AppLocalizations.of(context)!.home),
            _buildNavItem(1, Icons.people_outline, Icons.people, AppLocalizations.of(context)!.users),
            _buildNavItem(2, Icons.people_alt_outlined, Icons.people_alt, AppLocalizations.of(context)!.community),
            _buildCentralNavItem(3, Icons.person_outline, Icons.person, AppLocalizations.of(context)!.profile),
          ],
        ),
      ),
    );
  }

  Widget _buildNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                isSelected ? selectedIcon : unselectedIcon,
                color: isSelected ? AppColors.accentGold : AppColors.textLight,
                size: isSelected ? 26 : 24,
              ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentGold : AppColors.textLight,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCentralNavItem(int index, IconData unselectedIcon, IconData selectedIcon, String label) {
    bool isSelected = _selectedIndex == index;
    return Expanded(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _onNavTap(index),
          borderRadius: BorderRadius.circular(50),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.accentGold : Colors.transparent,
                ),
                child: Icon(
                  isSelected ? selectedIcon : unselectedIcon,
                  color: isSelected ? AppColors.primary : AppColors.textLight,
                  size: 24,
                ),
              ),
              Text(
                label,
                style: TextStyle(
                  color: isSelected ? AppColors.accentGold : AppColors.textLight,
                  fontSize: 11,
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showBroadcastDialog(BuildContext context) {
    final titleController = TextEditingController();
    final messageController = TextEditingController();
    String selectedAudience = 'all'; // Default to all

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) {
          return AlertDialog(
            backgroundColor: AppColors.cardBackground,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
            title: Text(AppLocalizations.of(context)!.broadcastMessage, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            content: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Audience Selector
                DropdownButtonHideUnderline(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    decoration: BoxDecoration(
                      color: Colors.white.withAlpha(15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: DropdownButton<String>(
                      value: selectedAudience,
                      isExpanded: true,
                      dropdownColor: AppColors.cardBackground,
                      icon: const Icon(Icons.arrow_drop_down, color: Colors.amber),
                      style: const TextStyle(color: Colors.white),
                      items: [
                        DropdownMenuItem(
                          value: 'all',
                          child: Text(AppLocalizations.of(context)!.all),
                        ),
                        DropdownMenuItem(
                          value: 'teachers',
                          child: Text(AppLocalizations.of(context)!.teachers),
                        ),
                        DropdownMenuItem(
                          value: 'students',
                          child: Text(AppLocalizations.of(context)!.students),
                        ),
                      ],
                      onChanged: (value) {
                        if (value != null) {
                          setState(() => selectedAudience = value);
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                TextField(
                  controller: titleController,
                  style: const TextStyle(color: Colors.white),
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.title,
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: messageController,
                  style: const TextStyle(color: Colors.white),
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText: AppLocalizations.of(context)!.broadcastHint,
                    hintStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withAlpha(15),
                  ),
                ),
              ],
            ),
          ),
          actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(AppLocalizations.of(context)!.cancel, style: const TextStyle(color: Colors.white54)),
              ),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.amber,
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                ),
                onPressed: () async {
                  if (titleController.text.isNotEmpty && messageController.text.isNotEmpty) {
                    try {
                      await _adminService.broadcastMessage(titleController.text, messageController.text, selectedAudience);
                      if (context.mounted) {
                        Navigator.pop(context);
                        AppMessenger.showSnackBar(
                          context,
                          title: AppLocalizations.of(context)!.success,
                          message: AppLocalizations.of(context)!.broadcastSent,
                          type: MessengerType.success,
                        );
                      }
                    } catch (e) {
                      if (context.mounted) {
                        Navigator.pop(context); // Optional: close dialog on error too
                        AppMessenger.showSnackBar(
                          context,
                          title: AppLocalizations.of(context)!.error,
                          message: "$e",
                          type: MessengerType.error,
                        );
                      }
                    }
                  }
                },
                child: Text(AppLocalizations.of(context)!.send, style: const TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
              ),
            ],
          );
        }
      ),
    );
  }
}
