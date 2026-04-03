import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:intl/intl.dart';
import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';

class TransactionHistoryPage extends StatefulWidget {
  const TransactionHistoryPage({super.key});

  @override
  State<TransactionHistoryPage> createState() => _TransactionHistoryPageState();
}

class _TransactionHistoryPageState extends State<TransactionHistoryPage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';

  @override
  Widget build(BuildContext context) {
    // We will use English fallbacks for status if we don't map them, but ideally we'd localize.
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
          l10n.transactionHistory,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
      ),
      body: StreamBuilder<QuerySnapshot>(
        stream: FirebaseFirestore.instance
            .collection('withdrawal_requests')
            .where('teacherId', isEqualTo: _currentUserId)
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
                "Error loading transactions.\n${snapshot.error}",
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
                    Icons.receipt_long_outlined,
                    color: Colors.white.withAlpha(50),
                    size: 64,
                  ),
                  const SizedBox(height: 16),
                  Text(
                    l10n.noTransactionsYet,
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

              final double amountRequested =
                  (data['requestedAmount'] ?? data['amount'] ?? 0.0).toDouble();
              final double fee = (data['fee'] ?? 0.0).toDouble();
              final double netAmount =
                  (data['netAmount'] ?? amountRequested - fee).toDouble();
              final String status = data['status'] ?? 'pending';
              final String method = data['method'] ?? 'unknown';

              DateTime? date;
              if (data['createdAt'] is Timestamp) {
                date = (data['createdAt'] as Timestamp).toDate();
              } else {
                date = DateTime.now(); // Fallback if pending offline write
              }

              return _buildTransactionCard(
                requestedAmount: amountRequested,
                netAmount: netAmount,
                fee: fee,
                status: status,
                method: method,
                date: date,
                l10n: l10n,
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildTransactionCard({
    required double requestedAmount,
    required double netAmount,
    required double fee,
    required String status,
    required String method,
    required DateTime date,
    required AppLocalizations l10n,
  }) {
    Color statusColor;
    IconData statusIcon;
    String statusLabel;

    switch (status.toLowerCase()) {
      case 'processing':
      case 'waiting':
        statusColor = Colors.blueAccent;
        statusIcon = Icons.sync;
        statusLabel = l10n.statusProcessing;
        break;
      case 'successful':
      case 'completed':
        statusColor = Colors.greenAccent;
        statusIcon = Icons.check_circle;
        statusLabel = l10n.statusSuccessful;
        break;
      case 'rejected':
      case 'failed':
        statusColor = Colors.redAccent;
        statusIcon = Icons.cancel;
        statusLabel = l10n.statusFailed;
        break;
      case 'pending':
      default:
        statusColor = Colors.orangeAccent;
        statusIcon = Icons.schedule;
        statusLabel = l10n.statusPending;
        break;
    }

    String displayMethod = method.toUpperCase();
    if (method == 'western') displayMethod = "Western Union";
    if (method == 'cliq') displayMethod = "CliQ";

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(statusIcon, color: statusColor, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.withdrawal,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 16,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        displayMethod,
                        style: TextStyle(
                          color: Colors.white.withAlpha(150),
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    "-\$${requestedAmount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w900,
                      fontSize: 18,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: statusColor.withAlpha(20),
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(color: statusColor.withAlpha(50)),
                    ),
                    child: Text(
                      statusLabel,
                      style: TextStyle(
                        color: statusColor,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),

          if (fee > 0) ...[
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Divider(color: Colors.white10, height: 1),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.feeDeducted,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
                Text(
                  "-\$${fee.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: Colors.redAccent,
                    fontSize: 13,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  l10n.netAmountSent,
                  style: TextStyle(
                    color: Colors.white.withAlpha(150),
                    fontSize: 12,
                  ),
                ),
                Text(
                  "\$${netAmount.toStringAsFixed(0)}",
                  style: const TextStyle(
                    color: AppColors.accentGold,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 16),
          Text(
            DateFormat('MMM dd, yyyy • hh:mm a').format(date),
            style: TextStyle(color: Colors.white.withAlpha(100), fontSize: 11),
          ),
        ],
      ),
    );
  }
}
