import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../../core/theme/colors.dart';
import '../../../l10n/app_localizations.dart';
import '../../../core/message/app_messenger.dart';
import '../../teacher/pages/public_profile/public_teacher_profile_page.dart';
import '../../student/pages/public_profile/public_student_profile_page.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/utils/date_utils.dart';
import 'package:intl/intl.dart';

class AdminUsersManagementPage extends StatefulWidget {
  const AdminUsersManagementPage({super.key});

  @override
  State<AdminUsersManagementPage> createState() => _AdminUsersManagementPageState();
}

class _AdminUsersManagementPageState extends State<AdminUsersManagementPage> {
  final TextEditingController _searchController = TextEditingController();
  String _selectedFilter = 'all'; // all, student, teacher, admin
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        title: Text(
          l10n.userManagement,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        iconTheme: const IconThemeData(color: AppColors.accentGold),
      ),
      body: Column(
        children: [
          // Search Bar
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: _searchController,
              style: const TextStyle(color: AppColors.textPrimary),
              decoration: InputDecoration(
                hintText: l10n.searchHintUsers,
                hintStyle: TextStyle(color: AppColors.textLight.withOpacity(0.6)),
                prefixIcon: const Icon(Icons.search, color: AppColors.accentGold),
                filled: true,
                fillColor: AppColors.cardBackground,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: BorderSide.none,
                ),
              ),
              onChanged: (value) {
                setState(() {
                  _searchQuery = value.toLowerCase();
                });
              },
            ),
          ),

          // Users List & Filters
          Expanded(
            child: StreamBuilder<QuerySnapshot>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(
                    child: CircularProgressIndicator(color: AppColors.accentGold),
                  );
                }

                if (!snapshot.hasData || snapshot.data!.docs.isEmpty) {
                  return Column(
                    children: [
                      // Render empty filters
                      _buildFiltersRow(l10n, 0, 0, 0, 0),
                      Expanded(
                        child: Center(
                          child: Text(
                            l10n.noUsersFound,
                            style: TextStyle(
                              color: AppColors.textLight.withOpacity(0.7),
                              fontSize: 16,
                            ),
                          ),
                        ),
                      ),
                    ],
                  );
                }

                final allDocs = snapshot.data!.docs;
                
                // Calculate counts
                int totalCount = allDocs.length;
                int studentCount = 0;
                int teacherCount = 0;
                int adminCount = 0;

                for (var doc in allDocs) {
                  final role = (doc.data() as Map<String, dynamic>)['role'] ?? 'student';
                  if (role == 'student') {
                    studentCount++;
                  } else if (role == 'teacher') teacherCount++;
                  else if (role == 'admin') adminCount++;
                }

                // Filter users
                final filteredDocs = allDocs.where((doc) {
                  final data = doc.data() as Map<String, dynamic>;
                  final role = data['role'] ?? 'student';
                  final name = (data['name'] ?? '').toString().toLowerCase();
                  final email = (data['email'] ?? '').toString().toLowerCase();

                  // Apply role filter
                  if (_selectedFilter != 'all' && role != _selectedFilter) {
                    return false;
                  }

                  // Apply search filter
                  if (_searchQuery.isNotEmpty) {
                    return name.contains(_searchQuery) ||
                        email.contains(_searchQuery) ||
                        role.contains(_searchQuery);
                  }

                  return true;
                }).toList();

                return Column(
                  children: [
                    _buildFiltersRow(l10n, totalCount, studentCount, teacherCount, adminCount),
                    const SizedBox(height: 16),
                    Expanded(
                      child: filteredDocs.isEmpty
                          ? Center(
                              child: Text(
                                l10n.noUsersFound,
                                style: TextStyle(
                                  color: AppColors.textLight.withOpacity(0.7),
                                  fontSize: 16,
                                ),
                              ),
                            )
                          : ListView.builder(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              itemCount: filteredDocs.length,
                              itemBuilder: (context, index) {
                                final doc = filteredDocs[index];
                                final data = doc.data() as Map<String, dynamic>;
                                return _buildUserCard(context, doc.id, data);
                              },
                            ),
                    ),
                  ],
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFiltersRow(AppLocalizations l10n, int total, int students, int teachers, int admins) {
    return Container(
      height: 50,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          _buildFilterChip('${l10n.all} ($total)', 'all'),
          const SizedBox(width: 8),
          _buildFilterChip('${l10n.students} ($students)', 'student'),
          const SizedBox(width: 8),
          _buildFilterChip('${l10n.teachers} ($teachers)', 'teacher'),
          const SizedBox(width: 8),
          _buildFilterChip('${l10n.admins} ($admins)', 'admin'),
        ],
      ),
    );
  }

  Widget _buildFilterChip(String label, String value) {
    final isSelected = _selectedFilter == value;
    return ChoiceChip(
      label: Text(
        label,
        style: TextStyle(
          color: isSelected ? Colors.black : AppColors.textLight,
          fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
        ),
      ),
      selected: isSelected,
      onSelected: (selected) {
        setState(() {
          _selectedFilter = value;
        });
      },
      selectedColor: AppColors.accentGold,
      backgroundColor: AppColors.cardBackground,
      side: BorderSide(
        color: isSelected ? AppColors.accentGold : AppColors.textLight.withOpacity(0.3),
      ),
    );
  }

  Widget _buildUserCard(BuildContext context, String userId, Map<String, dynamic> data) {
    final l10n = AppLocalizations.of(context)!;
    final name = data['name'] ?? l10n.anonymous;
    final email = data['email'] ?? l10n.noEmail;
    final role = data['role'] ?? 'student';
    final photoUrl = data['photoUrl'] ?? '';
    final createdAt = CalligroDateUtils.toDateTime(data['createdAt']);

    // Role color
    Color roleColor;
    IconData roleIcon;
    switch (role) {
      case 'admin':
        roleColor = Colors.purple;
        roleIcon = Icons.admin_panel_settings;
        break;
      case 'teacher':
        roleColor = AppColors.accentGold;
        roleIcon = Icons.assignment_ind;
        break;
      default:
        roleColor = Colors.blue;
        roleIcon = Icons.person;
    }

    return Card(
      color: AppColors.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: InkWell(
        onTap: () => _navigateToProfile(context, userId, role),
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Avatar
              ProfileAvatar(
                radius: 28,
                imageUrl: photoUrl,
              ),
              const SizedBox(width: 16),

              // User Info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            name,
                            style: const TextStyle(
                              color: AppColors.textPrimary,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                            ),
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Icon(roleIcon, color: roleColor, size: 18),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      email,
                      style: TextStyle(
                        color: AppColors.textLight.withOpacity(0.8),
                        fontSize: 14,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                    if (createdAt != null) ...[
                      const SizedBox(height: 4),
                      Text(
                        l10n.joinedDate(DateFormat.yMMMd().format(createdAt)),
                        style: TextStyle(
                          color: AppColors.textLight.withOpacity(0.6),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Actions Menu
              PopupMenuButton<String>(
                icon: const Icon(Icons.more_vert, color: AppColors.textLight),
                color: AppColors.cardBackground,
                onSelected: (value) => _handleAction(context, value, userId, data),
                itemBuilder: (context) => [
                  PopupMenuItem(
                    value: 'view',
                    child: Row(
                      children: [
                        const Icon(Icons.visibility, color: AppColors.accentGold, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.viewProfile, style: const TextStyle(color: AppColors.textPrimary)),
                      ],
                    ),
                  ),
                  if (role != 'admin')
                    PopupMenuItem(
                      value: 'makeAdmin',
                      child: Row(
                        children: [
                          const Icon(Icons.admin_panel_settings, color: Colors.purple, size: 20),
                          const SizedBox(width: 12),
                          Text(l10n.makeAdmin, style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  if (role != 'teacher')
                    PopupMenuItem(
                      value: 'makeTeacher',
                      child: Row(
                        children: [
                          const Icon(Icons.assignment_ind, color: AppColors.accentGold, size: 20),
                          const SizedBox(width: 12),
                          Text(l10n.makeTeacher, style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  if (role != 'student')
                    PopupMenuItem(
                      value: 'makeStudent',
                      child: Row(
                        children: [
                          const Icon(Icons.person, color: Colors.blue, size: 20),
                          const SizedBox(width: 12),
                          Text(l10n.makeStudent, style: const TextStyle(color: AppColors.textPrimary)),
                        ],
                      ),
                    ),
                  const PopupMenuDivider(),
                  PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        const Icon(Icons.delete, color: Colors.red, size: 20),
                        const SizedBox(width: 12),
                        Text(l10n.deleteUser, style: const TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _navigateToProfile(BuildContext context, String userId, String role) {
    if (role == 'teacher') {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicTeacherProfilePage(userId: userId),
        ),
      );
    } else {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => PublicStudentProfilePage(userId: userId),
        ),
      );
    }
  }

  Future<void> _handleAction(
    BuildContext context,
    String action,
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final l10n = AppLocalizations.of(context)!;

    switch (action) {
      case 'view':
        _navigateToProfile(context, userId, userData['role'] ?? 'student');
        break;

      case 'makeAdmin':
      case 'makeTeacher':
      case 'makeStudent':
        await _changeUserRole(context, userId, action, userData);
        break;

      case 'delete':
        await _deleteUser(context, userId, userData);
        break;
    }
  }

  Future<void> _changeUserRole(
    BuildContext context,
    String userId,
    String action,
    Map<String, dynamic> userData,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    String newRole;

    switch (action) {
      case 'makeAdmin':
        newRole = 'admin';
        break;
      case 'makeTeacher':
        newRole = 'teacher';
        break;
      case 'makeStudent':
        newRole = 'student';
        break;
      default:
        return;
    }

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'role': newRole,
        if (newRole == 'teacher') 'approved': true, // Auto-approve when making someone a teacher
      });

      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.success,
          message: l10n.roleChanged,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (context.mounted) {
        AppMessenger.showSnackBar(
          context,
          title: l10n.error,
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }

  Future<void> _deleteUser(
    BuildContext context,
    String userId,
    Map<String, dynamic> userData,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    final name = userData['name'] ?? l10n.user;

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        title: Text(
          l10n.deleteUserConfirmTitle,
          style: const TextStyle(color: AppColors.textPrimary),
        ),
        content: Text(
          l10n.deleteUserConfirmMessage(name),
          style: const TextStyle(color: AppColors.textLight),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(l10n.cancel, style: const TextStyle(color: AppColors.textLight)),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(l10n.delete, style: const TextStyle(color: Colors.red)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      try {
        await FirebaseFirestore.instance.collection('users').doc(userId).delete();

        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.success,
            message: '${l10n.deleteUser} ${l10n.success}',
            type: MessengerType.success,
          );
        }
      } catch (e) {
        if (context.mounted) {
          AppMessenger.showSnackBar(
            context,
            title: l10n.error,
            message: e.toString(),
            type: MessengerType.error,
          );
        }
      }
    }
  }
}
