import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';

class TeacherSalesHistoryPage extends StatefulWidget {
  const TeacherSalesHistoryPage({super.key});

  @override
  State<TeacherSalesHistoryPage> createState() => _TeacherSalesHistoryPageState();
}

class _TeacherSalesHistoryPageState extends State<TeacherSalesHistoryPage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.salesHistory,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('transactions')
            .where('teacherId', isEqualTo: _currentUserId)
            .where('status', isEqualTo: 'completed')
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }

          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error loading sales.\n${snapshot.error}",
                textAlign: TextAlign.center,
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }

          final docs = snapshot.data?.docs ?? [];

          if (docs.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.sell_outlined,
                    color: Colors.white.withAlpha(50),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noSalesYet,
                    style: TextStyle(
                      color: Colors.white.withAlpha(150),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
            );
          }

          // Group by courseId
          final Map<String, List<QueryDocumentSnapshot>> groupedSales = {};
          final Map<String, double> courseEarnings = {};
          final Map<String, String> courseNames = {};

          for (var doc in docs) {
            final data = doc.data() as Map<String, dynamic>;
            final courseId = data['courseId'] ?? 'UnknownId';
            final courseName = data['courseName'] ?? 'Unknown Course';
            final teacherShare = (data['teacherShare'] ?? 0.0).toDouble();

            if (!groupedSales.containsKey(courseId)) {
              groupedSales[courseId] = [];
              courseEarnings[courseId] = 0.0;
              courseNames[courseId] = courseName;
            }
            groupedSales[courseId]!.add(doc);
            courseEarnings[courseId] = courseEarnings[courseId]! + teacherShare;
          }

          final courseIds = groupedSales.keys.toList();

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: courseIds.length,
            itemBuilder: (context, index) {
              final courseId = courseIds[index];
              final courseName = courseNames[courseId]!;
              final sales = groupedSales[courseId]!;
              final totalEarned = courseEarnings[courseId]!;

              return FutureBuilder<DocumentSnapshot>(
                future: courseId != 'UnknownId'
                    ? FirebaseFirestore.instance.collection('courses').doc(courseId).get()
                    : null,
                builder: (context, snapshot) {
                  String? bannerUrl;
                  DateTime? payoutDate;
                  bool isAvailable = false;
                  
                  if (snapshot.hasData && snapshot.data!.exists) {
                    final courseData = snapshot.data!.data() as Map<String, dynamic>;
                    bannerUrl = courseData['courseBanner'] ?? courseData['thumbnailUrl'];
                    
                    DateTime endDate;
                    if (courseData['endDate'] != null && courseData['endDate'] is Timestamp) {
                      endDate = (courseData['endDate'] as Timestamp).toDate().toLocal();
                    } else if (courseData['createdAt'] != null && courseData['createdAt'] is Timestamp) {
                      endDate = (courseData['createdAt'] as Timestamp).toDate().toLocal().add(const Duration(days: 30));
                    } else {
                      endDate = DateTime.now();
                    }
                    payoutDate = endDate.add(const Duration(days: 2));
                    isAvailable = DateTime.now().isAfter(payoutDate);
                  }

                  return GestureDetector(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CourseSalesDetailsPage(
                            courseName: courseName,
                            totalEarned: totalEarned,
                            sales: sales,
                          ),
                        ),
                      );
                    },
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 24),
                      decoration: BoxDecoration(
                        color: AppColors.cardBackground,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.white.withAlpha(15)),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withAlpha(50),
                            blurRadius: 12,
                            offset: const Offset(0, 6),
                          ),
                        ],
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          // Top part: Image
                          Stack(
                            children: [
                              ClipRRect(
                                borderRadius: const BorderRadius.only(
                                  topLeft: Radius.circular(16),
                                  topRight: Radius.circular(16),
                                ),
                                child: SizedBox(
                                  height: 140,
                                  width: double.infinity,
                                  child: bannerUrl != null && bannerUrl.isNotEmpty
                                      ? Image(
                                          image: bannerUrl.startsWith('assets/')
                                              ? AssetImage(bannerUrl) as ImageProvider
                                              : NetworkImage(bannerUrl),
                                          fit: BoxFit.cover,
                                        )
                                      : Container(
                                          color: AppColors.accentGold.withAlpha(20),
                                          child: const Center(
                                            child: Icon(
                                              Icons.folder_special,
                                              color: AppColors.accentGold,
                                              size: 48,
                                            ),
                                          ),
                                        ),
                                ),
                              ),
                              if (payoutDate != null)
                                Positioned(
                                  top: 12,
                                  left: Localizations.localeOf(context).languageCode == 'ar' ? 12 : null,
                                  right: Localizations.localeOf(context).languageCode == 'ar' ? null : 12,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                    decoration: BoxDecoration(
                                      color: isAvailable ? Colors.green.shade700.withAlpha(230) : Colors.orange.shade700.withAlpha(230),
                                      borderRadius: BorderRadius.circular(24),
                                      border: Border.all(color: Colors.white.withAlpha(50)),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withAlpha(100),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          isAvailable ? Icons.check_circle : Icons.access_time_filled,
                                          color: Colors.white,
                                          size: 16,
                                        ),
                                        const SizedBox(width: 8),
                                        Text(
                                          isAvailable 
                                              ? l10n.availableToWithdraw 
                                              : "${l10n.availableToWithdraw} ${Localizations.localeOf(context).languageCode == 'ar' ? 'في' : 'on'} ${DateFormat('d MMM', Localizations.localeOf(context).languageCode).format(payoutDate)}",
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                            ],
                          ),
                          // Bottom part: Info
                          Padding(
                            padding: const EdgeInsets.all(16.0),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  courseName,
                                  style: const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 16),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Row(
                                      children: [
                                        const Icon(
                                          Icons.sell_outlined,
                                          color: Colors.white54,
                                          size: 14,
                                        ),
                                        const SizedBox(width: 6),
                                        Text(
                                          "${sales.length} مبيعات",
                                          style: const TextStyle(
                                            color: Colors.white54,
                                            fontSize: 13,
                                          ),
                                        ),
                                      ],
                                    ),
                                    Row(
                                      children: [
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: Colors.greenAccent.withAlpha(20),
                                            borderRadius: BorderRadius.circular(8),
                                            border: Border.all(color: Colors.greenAccent.withAlpha(40)),
                                          ),
                                          child: Text(
                                            "+\$${totalEarned.toStringAsFixed(2)}",
                                            style: const TextStyle(
                                              color: Colors.greenAccent,
                                              fontWeight: FontWeight.w900,
                                              fontSize: 14,
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 12),
                                        Icon(
                                          Localizations.localeOf(context).languageCode == 'ar'
                                              ? Icons.arrow_back_ios_new
                                              : Icons.arrow_forward_ios,
                                          color: Colors.white24,
                                          size: 14,
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}


class CourseSalesDetailsPage extends StatelessWidget {
  final String courseName;
  final double totalEarned;
  final List<QueryDocumentSnapshot> sales;

  const CourseSalesDetailsPage({
    super.key,
    required this.courseName,
    required this.totalEarned,
    required this.sales,
  });

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          courseName,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            fontSize: 16,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: ListView.builder(
        padding: const EdgeInsets.all(20),
        itemCount: sales.length,
        itemBuilder: (context, index) {
          final doc = sales[index];
          final data = doc.data() as Map<String, dynamic>;
          final String fallbackName = data['studentName'] ?? 'Unknown Student';
          final String? studentId = data['studentId'] as String?;
          final double teacherShare = (data['teacherShare'] ?? 0.0).toDouble();
          
          DateTime date;
          if (data['createdAt'] is Timestamp) {
            date = (data['createdAt'] as Timestamp).toDate();
          } else {
            date = DateTime.now(); 
          }

          String formattedDate;
          try {
            formattedDate = DateFormat.yMMMMd(Localizations.localeOf(context).languageCode).format(date);
          } catch (e) {
            formattedDate = DateFormat.yMMMMd().format(date);
          }

          Widget buildSaleCard(String displayStudentName, String? photoUrl) {
            return GestureDetector(
              onTap: () => _showSaleBreakdown(context, data, date, l10n, displayStudentName, formattedDate),
              child: Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: Colors.white.withAlpha(20)),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withAlpha(50),
                      blurRadius: 10,
                      offset: const Offset(0, 5),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 24,
                      backgroundColor: AppColors.accentGold.withAlpha(30),
                      backgroundImage: photoUrl != null && photoUrl.isNotEmpty
                          ? NetworkImage(photoUrl)
                          : null,
                      child: photoUrl == null || photoUrl.isEmpty
                          ? const Icon(Icons.person, color: AppColors.accentGold)
                          : null,
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            displayStudentName,
                            style: const TextStyle(
                              color: Colors.white,
                              fontWeight: FontWeight.bold,
                              fontSize: 16,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 4),
                          Text(
                            formattedDate,
                            style: const TextStyle(
                              color: Colors.white54,
                              fontSize: 13,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.greenAccent.withAlpha(20),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        "+\$${teacherShare.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 15,
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),
                    const Icon(
                      Icons.keyboard_arrow_down,
                      color: Colors.white54,
                      size: 20,
                    ),
                  ],
                ),
              ),
            );
          }

          if (studentId == null || studentId.isEmpty) {
            return buildSaleCard(fallbackName, null);
          }

          return FutureBuilder<DocumentSnapshot>(
            future: FirebaseFirestore.instance.collection('users').doc(studentId).get(),
            builder: (context, snapshot) {
              String nameToDisplay = fallbackName;
              String? photoUrl;
              if (snapshot.hasData && snapshot.data!.exists) {
                final userData = snapshot.data!.data() as Map<String, dynamic>;
                nameToDisplay = userData['name'] ?? fallbackName;
                photoUrl = userData['photoUrl'];
              }
              return buildSaleCard(nameToDisplay, photoUrl);
            },
          );
        },
      ),
    );
  }

  void _showSaleBreakdown(BuildContext context, Map<String, dynamic> data, DateTime date, AppLocalizations l10n, String displayStudentName, String formattedDate) {
    final String courseName = data['courseName'] ?? 'Unknown Course';
    final double amountPaid = (data['amount'] ?? 0.0).toDouble();
    final double fee = (data['fee'] ?? 0.0).toDouble();
    final double netAmountPaid = fee > 0 ? amountPaid - fee : amountPaid / 1.08;
    final double teacherShare = (data['teacherShare'] ?? 0.0).toDouble();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        padding: const EdgeInsets.all(24),
        decoration: const BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.only(
            topLeft: Radius.circular(24),
            topRight: Radius.circular(24),
          ),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.white24,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              l10n.saleBreakdown,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 24),
            _buildDetailRow(Icons.book_outlined, l10n.courseName, courseName),
            _buildDetailRow(Icons.person_outline, l10n.studentLabel, displayStudentName),
            _buildDetailRow(Icons.calendar_today_outlined, l10n.dateLabel, formattedDate),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            _buildFinanceRow(l10n.studentPaid, netAmountPaid, Colors.white),
            const SizedBox(height: 16),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.yourCommission,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  "+\$${teacherShare.toStringAsFixed(2)}",
                  style: const TextStyle(
                    color: Colors.greenAccent,
                    fontSize: 24,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildDetailRow(IconData icon, String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        children: [
          Icon(icon, color: Colors.white54, size: 20),
          const SizedBox(width: 12),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 14),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 14,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinanceRow(String label, double amount, Color amountColor) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: Colors.white70,
              fontSize: 15,
            ),
          ),
          Text(
            amount < 0 
                ? "-\$${amount.abs().toStringAsFixed(2)}" 
                : "\$${amount.toStringAsFixed(2)}",
            style: TextStyle(
              color: amountColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
