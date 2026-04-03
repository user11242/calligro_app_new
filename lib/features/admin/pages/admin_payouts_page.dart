import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:flutter_animate/flutter_animate.dart';

class AdminPayoutsPage extends StatefulWidget {
  const AdminPayoutsPage({super.key});

  @override
  State<AdminPayoutsPage> createState() => _AdminPayoutsPageState();
}

class _AdminPayoutsPageState extends State<AdminPayoutsPage> {
  final AdminService _adminService = AdminService();

  void _showProcessDialog(BuildContext context, Map<String, dynamic> request) {
    final l10n = AppLocalizations.of(context)!;
    final noteController = TextEditingController();
    final String requestId = request['id'];

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.cardBackground,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text(
          l10n.processRequest,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              "Teacher: ${request['teacherName'] ?? 'Unknown'}",
              style: const TextStyle(color: Colors.white70, fontSize: 14),
            ),
            const SizedBox(height: 8),
            Text(
              "Amount: \$${request['amount'] ?? request['netAmount'] ?? '0'}",
              style: const TextStyle(
                color: AppColors.accentGold,
                fontWeight: FontWeight.bold,
                fontSize: 18,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: noteController,
              style: const TextStyle(color: Colors.white, fontSize: 14),
              maxLines: 3,
              decoration: InputDecoration(
                hintText: l10n.adminNoteHint,
                hintStyle: const TextStyle(color: Colors.white24, fontSize: 13),
                filled: true,
                fillColor: Colors.white.withOpacity(0.05),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: BorderSide.none,
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(
              l10n.cancel,
              style: const TextStyle(color: Colors.white54),
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent.withOpacity(0.1),
              foregroundColor: Colors.redAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await _adminService.updateWithdrawalStatus(
                requestId: requestId,
                status: 'rejected',
                adminNote: noteController.text,
              );
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                AppMessenger.showSnackBar(
                  context,
                  title: l10n.payoutRejected,
                  message: "Request has been rejected.",
                  type: MessengerType.info,
                );
              }
            },
            child: Text(l10n.markAsRejected),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.blueAccent.withOpacity(0.1),
              foregroundColor: Colors.blueAccent,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await _adminService.updateWithdrawalStatus(
                requestId: requestId,
                status: 'processing',
                adminNote: noteController.text,
              );
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                AppMessenger.showSnackBar(
                  context,
                  title: "Processing",
                  message: "Request marked as waiting/processing.",
                  type: MessengerType.info,
                );
              }
            },
            child: const Text("Mark as Processing"),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.accentGold,
              foregroundColor: Colors.black,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onPressed: () async {
              await _adminService.updateWithdrawalStatus(
                requestId: requestId,
                status: 'completed',
                adminNote: noteController.text,
              );
              if (context.mounted) Navigator.pop(context);
              if (context.mounted) {
                AppMessenger.showSnackBar(
                  context,
                  title: l10n.payoutCompleted,
                  message: "Request marked as completed.",
                  type: MessengerType.success,
                );
              }
            },
            child: Text(l10n.markAsCompleted),
          ),
        ],
      ),
    );
  }

  void _showProofOfMath(
    BuildContext context,
    String teacherId,
    String teacherName,
  ) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
            color: AppColors.accentGold.withOpacity(0.3),
          ),
        ),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    "Proof of Math: $teacherName",
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            const Text(
              "Formula: Students × Course Price × 0.65 (Teacher Share)",
              style: TextStyle(
                color: AppColors.accentGold,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            const Text(
              "Available = Course Ended > 48 hours ago.\nPending = Upcoming or ended < 48 hours ago.",
              style: TextStyle(color: Colors.white54, fontSize: 12),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: FutureBuilder<QuerySnapshot>(
                future: FirebaseFirestore.instance
                    .collection('courses')
                    .where('teacherId', isEqualTo: teacherId)
                    .get(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Center(
                      child: CircularProgressIndicator(
                        color: AppColors.accentGold,
                      ),
                    );
                  }

                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) {
                    return const Center(
                      child: Text(
                        "No courses found.",
                        style: TextStyle(color: Colors.white54),
                      ),
                    );
                  }

                  double totalAvailable = 0;
                  double totalPending = 0;
                  final now = DateTime.now();
                  final safetyWindow = now.subtract(const Duration(hours: 48));

                  // Calculate totals first
                  for (var doc in docs) {
                    final data = doc.data() as Map<String, dynamic>;
                    final double price = (data['price'] ?? 0.0).toDouble();
                    final int count =
                        data['enrolledCount'] ??
                        (data['enrolledStudents'] as List?)?.length ??
                        0;
                    final double sharePerStudent = price * 0.65;
                    final double totalShare = sharePerStudent * count;
                    DateTime? endDate;
                    if (data['endDate'] != null) {
                      endDate = (data['endDate'] is Timestamp)
                          ? (data['endDate'] as Timestamp).toDate().toLocal()
                          : null;
                    }
                    if (endDate != null && endDate.isBefore(safetyWindow)) {
                      totalAvailable += totalShare;
                    } else {
                      totalPending += totalShare;
                    }
                  }

                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: docs.length,
                          itemBuilder: (context, index) {
                            final data =
                                docs[index].data() as Map<String, dynamic>;
                            final String courseName =
                                data['courseName'] ?? 'Unknown Course';
                            final double price = (data['price'] ?? 0.0)
                                .toDouble();
                            final int count =
                                data['enrolledCount'] ??
                                (data['enrolledStudents'] as List?)?.length ??
                                0;
                            final double sharePerStudent = price * 0.65;
                            final double totalShare = sharePerStudent * count;

                            DateTime? endDate;
                            if (data['endDate'] != null) {
                              endDate = (data['endDate'] is Timestamp)
                                  ? (data['endDate'] as Timestamp)
                                        .toDate()
                                        .toLocal()
                                  : null;
                            }

                            bool isAvailable = false;
                            if (endDate != null &&
                                endDate.isBefore(safetyWindow)) {
                              isAvailable = true;
                            }

                            return Container(
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(16),
                              decoration: BoxDecoration(
                                color: Colors.white.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(16),
                                border: Border.all(
                                  color: isAvailable
                                      ? Colors.green.withOpacity(0.3)
                                      : Colors.orange.withOpacity(0.3),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    mainAxisAlignment:
                                        MainAxisAlignment.spaceBetween,
                                    children: [
                                      Expanded(
                                        child: Text(
                                          courseName,
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 8,
                                          vertical: 4,
                                        ),
                                        decoration: BoxDecoration(
                                          color: isAvailable
                                              ? Colors.green.withOpacity(
                                                  0.1,
                                                )
                                              : Colors.orange.withOpacity(
                                                  0.1,
                                                ),
                                          borderRadius: BorderRadius.circular(
                                            8,
                                          ),
                                        ),
                                        child: Text(
                                          isAvailable
                                              ? "Available"
                                              : "Pending (-48h)",
                                          style: TextStyle(
                                            color: isAvailable
                                                ? Colors.green
                                                : Colors.orange,
                                            fontSize: 10,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Students: $count",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  Text(
                                    "Course Base Price: \$${price.toStringAsFixed(2)}",
                                    style: const TextStyle(
                                      color: Colors.white70,
                                      fontSize: 13,
                                    ),
                                  ),
                                  const SizedBox(height: 8),
                                  Text(
                                    "Calculation: $count × \$${price.toStringAsFixed(2)} × 0.65",
                                    style: const TextStyle(
                                      color: Colors.white54,
                                      fontSize: 12,
                                      fontStyle: FontStyle.italic,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    "= \$${totalShare.toStringAsFixed(2)} Total Share",
                                    style: const TextStyle(
                                      color: AppColors.accentGold,
                                      fontSize: 14,
                                      fontWeight: FontWeight.bold,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(
                            color: Colors.white.withOpacity(0.1),
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  "Total Pend (-48h)",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "\$${totalPending.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.orange,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 16,
                                  ),
                                ),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.end,
                              children: [
                                const Text(
                                  "Total Available",
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                                Text(
                                  "\$${totalAvailable.toStringAsFixed(2)}",
                                  style: const TextStyle(
                                    color: Colors.green,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 18,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(
            Icons.arrow_back_ios_new,
            color: Colors.white,
            size: 20,
          ),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          l10n.payoutRequests,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
      body: StreamBuilder<List<Map<String, dynamic>>>(
        stream: _adminService.getWithdrawalRequests(),
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            );
          }
          if (snapshot.hasError) {
            return Center(
              child: Text(
                "Error: ${snapshot.error}",
                style: const TextStyle(color: Colors.redAccent),
              ),
            );
          }
          final requests = snapshot.data ?? [];
          if (requests.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.payments_outlined,
                    color: Colors.white.withOpacity(0.1),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noPayoutRequests,
                    style: const TextStyle(color: Colors.white30),
                  ),
                ],
              ),
            );
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: requests.length,
            itemBuilder: (context, index) {
              final req = requests[index];
              final DateTime date = (req['createdAt'] as Timestamp).toDate();
              final status = req['status'] ?? 'pending';

              Color statusColor = Colors.amber;
              if (status == 'completed' || status == 'successful') {
                statusColor = Colors.green;
              }
              if (status == 'rejected') statusColor = Colors.redAccent;
              if (status == 'processing' || status == 'waiting') {
                statusColor = Colors.blueAccent;
              }

              return Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.cardBackground,
                  borderRadius: BorderRadius.circular(24),
                  border: Border.all(
                    color: Colors.white.withOpacity(0.05),
                    width: 1,
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            (req['payoutMethod'] ?? req['method']) == 'cliq'
                                ? Icons.account_balance_wallet_outlined
                                : Icons.public,
                            color: statusColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req['teacherName'] ?? 'Teacher',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.bold,
                                  fontSize: 16,
                                ),
                              ),
                              Text(
                                DateFormat(
                                  'MMM dd, yyyy • hh:mm a',
                                  Localizations.localeOf(context).toString(),
                                ).format(date),
                                style: TextStyle(
                                  color: Colors.white.withOpacity(0.4),
                                  fontSize: 12,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "\$${req['amount'] ?? req['netAmount'] ?? '0'}",
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 18,
                          ),
                        ),
                      ],
                    ),
                    const Padding(
                      padding: EdgeInsets.symmetric(vertical: 16),
                      child: Divider(color: Colors.white10),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: statusColor.withOpacity(0.2),
                            ),
                          ),
                          child: Text(
                            status.toUpperCase(),
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 10,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 1,
                            ),
                          ),
                        ),
                        if (status == 'pending' || status == 'processing')
                          ElevatedButton(
                            onPressed: () => _showProcessDialog(context, req),
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.accentGold.withOpacity(
                                0.1,
                              ),
                              foregroundColor: AppColors.accentGold,
                              elevation: 0,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                              ),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 20,
                                vertical: 8,
                              ),
                            ),
                            child: Text(
                              l10n.processRequest,
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        icon: const Icon(Icons.calculate_outlined, size: 16),
                        label: const Text("View Proof of Earnings (Math)"),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: Colors.white70,
                          side: BorderSide(
                            color: Colors.white.withOpacity(0.2),
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => _showProofOfMath(
                          context,
                          req['teacherId'],
                          req['teacherName'] ?? 'Unknown',
                        ),
                      ),
                    ),
                    if (req['adminNote'] != null &&
                        req['adminNote'].toString().isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.05),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          "Note: ${req['adminNote']}",
                          style: TextStyle(
                            color: Colors.white.withOpacity(0.6),
                            fontSize: 12,
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ).animate().fadeIn(delay: (index * 50).ms).slideY(begin: 0.1);
            },
          );
        },
      ),
    );
  }
}
