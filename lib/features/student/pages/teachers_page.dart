import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/features/student/data/services/student_service.dart';
import 'package:calligro_app/core/widgets/profile_avatar.dart';
import 'package:calligro_app/core/widgets/rating_display.dart';
import 'package:calligro_app/features/teacher/pages/public_profile/public_teacher_profile_page.dart';
import 'package:google_fonts/google_fonts.dart';
import 'dart:ui';

class TeachersPage extends StatefulWidget {
  const TeachersPage({super.key});

  @override
  State<TeachersPage> createState() => _TeachersPageState();
}

class _TeachersPageState extends State<TeachersPage> {
  late Stream<List<Map<String, dynamic>>> _teachersStream;
  final StudentService _service = StudentService();
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = "";

  @override
  void initState() {
    super.initState();
    _teachersStream = _service.getTeachersStream();
    _searchController.addListener(() {
      setState(() {
        _searchQuery = _searchController.text.toLowerCase();
      });
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: CustomScrollView(
        slivers: [
          // 1. Premium Header with Search
          SliverAppBar(
            expandedHeight: 220,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                  // Decorative background pattern/gradient
                  Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          AppColors.accentGold.withOpacity(0.15),
                          AppColors.primary,
                        ],
                      ),
                    ),
                  ),
                  Positioned(
                    right: -50,
                    top: -50,
                    child: Container(
                      width: 200,
                      height: 200,
                      decoration: BoxDecoration(
                        color: AppColors.accentGold.withOpacity(0.05),
                        shape: BoxShape.circle,
                      ),
                    ),
                  ),
                  
                  // Content
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 80, 24, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          l10n.instructors,
                          style: GoogleFonts.outfit(
                            color: Colors.white,
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          l10n.searchTeachersStudents,
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.5),
                            fontSize: 14,
                          ),
                        ),
                        const SizedBox(height: 20),
                        
                        // Integrated Search Bar
                        Container(
                          height: 50,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(color: Colors.white.withOpacity(0.1)),
                          ),
                          child: TextField(
                            controller: _searchController,
                            style: const TextStyle(color: Colors.white),
                            decoration: InputDecoration(
                              hintText: l10n.searchByName,
                              hintStyle: TextStyle(color: Colors.white.withOpacity(0.3)),
                              prefixIcon: Icon(Icons.search, color: Colors.white.withOpacity(0.4)),
                              border: InputBorder.none,
                              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Teachers Grid
          StreamBuilder<List<Map<String, dynamic>>>(
            stream: _teachersStream,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
                );
              }

              var teachers = snapshot.data ?? [];
              
              // Local Filtering
              if (_searchQuery.isNotEmpty) {
                teachers = teachers.where((teacher) {
                  final name = (teacher['name'] ?? '').toString().toLowerCase();
                  return name.contains(_searchQuery);
                }).toList();
              }

              if (teachers.isEmpty) {
                return SliverFillRemaining(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(Icons.search_off_rounded, size: 60, color: Colors.white.withOpacity(0.2)),
                      const SizedBox(height: 16),
                      Text(
                        l10n.noUsersFound,
                        style: TextStyle(color: Colors.white.withOpacity(0.5), fontSize: 16),
                      ),
                    ],
                  ),
                );
              }

              return SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    crossAxisSpacing: 16,
                    mainAxisSpacing: 16,
                    childAspectRatio: 0.68,
                  ),
                  delegate: SliverChildBuilderDelegate(
                    (context, index) {
                      final teacher = teachers[index];
                      return _buildPremiumTeacherCard(teacher);
                    },
                    childCount: teachers.length,
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Widget _buildPremiumTeacherCard(Map<String, dynamic> teacher) {
    final l10n = AppLocalizations.of(context)!;
    
    return GestureDetector(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => PublicTeacherProfilePage(userId: teacher['id'] ?? ''),
          ),
        );
      },
      child: ClipRRect(
        borderRadius: BorderRadius.circular(24),
        child: BackdropFilter(
          filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.cardBackground.withOpacity(0.4),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withOpacity(0.08)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Colors.white.withOpacity(0.05),
                  Colors.transparent,
                ],
              ),
            ),
            child: Column(
              children: [
                const SizedBox(height: 8),
                // Avatar with border
                Container(
                  padding: const EdgeInsets.all(3),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.accentGold.withOpacity(0.3), width: 1.5),
                  ),
                  child: ProfileAvatar(
                    radius: 38,
                    imageUrl: teacher['photoUrl']?.toString() ?? '',
                  ),
                ),
                const SizedBox(height: 14),
                Text(
                  teacher['name'] ?? 'Artist',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 16,
                  ),
                ),
                const SizedBox(height: 6),
                RatingDisplay(
                  averageRating: (teacher['totalStars'] ?? 0).toDouble(),
                  reviewCount: teacher['reviewCount'] ?? 0,
                  isCompact: true,
                  starSize: 12,
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: Text(
                    teacher['bio'] ?? 'Expert Calligrapher dedicated to the art of script.',
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      color: Colors.white.withOpacity(0.45),
                      fontSize: 11,
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                // Premium Styled Button
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.accentGold.withOpacity(0.2),
                        blurRadius: 8,
                        offset: const Offset(0, 4),
                      ),
                    ],
                    gradient: LinearGradient(
                      colors: [
                        AppColors.accentGold,
                        const Color(0xFFC5A059),
                      ],
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Center(
                    child: Text(
                      l10n.viewDetails.toUpperCase(),
                      style: const TextStyle(
                        color: AppColors.primary,
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        letterSpacing: 1.2,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
