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

          return ListView.builder(
            padding: const EdgeInsets.all(20),
            itemCount: docs.length,
            itemBuilder: (context, index) {
              final data = docs[index].data() as Map<String, dynamic>;

              final String courseName = data['courseName'] ?? 'Unknown Course';
              final String studentName = data['studentName'] ?? 'Unknown Student';
              final double teacherShare = (data['teacherShare'] ?? 0.0).toDouble();
              
              DateTime? date;
              if (data['createdAt'] is Timestamp) {
                date = (data['createdAt'] as Timestamp).toDate();
              } else {
                date = DateTime.now(); 
              }

              return GestureDetector(
                onTap: () => _showSaleBreakdown(context, data, date, l10n),
                child: Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withAlpha(15),
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                      color: Colors.white.withAlpha(20),
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: AppColors.accentGold.withAlpha(20),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.monetization_on_outlined,
                          color: AppColors.accentGold,
                          size: 24,
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
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
                            const SizedBox(height: 4),
                            Text(
                              "$studentName • ${date != null ? DateFormat('MMM d, yyyy').format(date) : ''}",
                              style: const TextStyle(
                                color: Colors.white70,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        "+\$${teacherShare.toStringAsFixed(2)}",
                        style: const TextStyle(
                          color: Colors.greenAccent,
                          fontWeight: FontWeight.w900,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }

  void _showSaleBreakdown(BuildContext context, Map<String, dynamic> data, DateTime? date, AppLocalizations l10n) {
    final String courseName = data['courseName'] ?? 'Unknown Course';
    final String studentName = data['studentName'] ?? 'Unknown Student';
    final double amountPaid = (data['amount'] ?? 0.0).toDouble();
    final double processingFee = (data['fee'] ?? 0.0).toDouble();
    final double netRevenue = amountPaid - processingFee;
    final double teacherShare = (data['teacherShare'] ?? 0.0).toDouble();
    final String source = data['source'] ?? 'website';

    final String sourceString = source.toLowerCase() == 'app' ? l10n.sourceApp : l10n.sourceWebsite;

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
            _buildDetailRow(Icons.person_outline, l10n.studentLabel, studentName),
            _buildDetailRow(Icons.public, l10n.sourceWebsite, sourceString), 
            _buildDetailRow(Icons.calendar_today_outlined, l10n.dateLabel, date != null ? DateFormat('MMM d, yyyy').format(date) : ''),
            const SizedBox(height: 24),
            const Divider(color: Colors.white12),
            const SizedBox(height: 16),
            _buildFinanceRow(l10n.studentPaid, amountPaid, Colors.white),
            _buildFinanceRow(l10n.processingFee, -processingFee, Colors.redAccent),
            _buildFinanceRow(l10n.netRevenue, netRevenue, Colors.white70),
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
