import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../../core/theme/colors.dart';
import '../../../../l10n/app_localizations.dart';
import '../../../../core/message/app_messenger.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'dart:ui';
import 'transaction_history_page.dart';

class TeacherFinancePage extends StatefulWidget {
  const TeacherFinancePage({super.key});

  @override
  State<TeacherFinancePage> createState() => _TeacherFinancePageState();
}

class _TeacherFinancePageState extends State<TeacherFinancePage> {
  final String _currentUserId = FirebaseAuth.instance.currentUser?.uid ?? '';
  bool _isLoading = true;
  double _pendingBalance = 0.0;
  double _availableBalance = 0.0;
  double _totalEarnings = 0.0;
  double _totalWithdrawn = 0.0;
  String? _selectedMethod;
  String _teacherName = 'Teacher';
  double? _commissionRate;

  @override
  void initState() {
    super.initState();
    _fetchBalances();
  }

  Future<void> _fetchBalances() async {
    try {
      // 1. Fetch User Settings & Commission Rate First
      final userDoc = await FirebaseFirestore.instance
          .collection('users')
          .doc(_currentUserId)
          .get();

      String? selectedMethod;
      String teacherName = 'Teacher';
      double? commissionRate;

      if (userDoc.exists) {
        final userData = userDoc.data()!;
        teacherName = userData['name'] ?? 'Teacher';

        if (userData.containsKey('commissionRate')) {
          commissionRate = (userData['commissionRate'] as num).toDouble();
        }

        if (userData.containsKey('payoutSettings')) {
          final settings = userData['payoutSettings'] as Map<String, dynamic>;
          selectedMethod = settings['selectedMethod'];
        }
      }

      // 2. Fetch Courses to map end dates
      final coursesQuery = await FirebaseFirestore.instance
          .collection('courses')
          .where('teacherId', isEqualTo: _currentUserId)
          .get();

      Map<String, DateTime?> courseEndDates = {};
      for (var doc in coursesQuery.docs) {
        final data = doc.data();
        DateTime? endDate;
        if (data['endDate'] != null) {
          endDate = (data['endDate'] is Timestamp)
              ? (data['endDate'] as Timestamp).toDate().toLocal()
              : null;
        }
        courseEndDates[doc.id] = endDate;
      }

      // 3. Fetch Transactions and Calculate Earnings
      final txQuery = await FirebaseFirestore.instance
          .collection('transactions')
          .where('teacherId', isEqualTo: _currentUserId)
          .where('status', isEqualTo: 'completed')
          .get();

      double pending = 0.0;
      double available = 0.0;
      double total = 0.0;

      final now = DateTime.now();
      final safetyWindow = now.subtract(const Duration(hours: 48));

      for (var doc in txQuery.docs) {
        final data = doc.data();
        final double teacherShare = (data['teacherShare'] ?? 0.0).toDouble();
        final String courseId = data['courseId'] ?? '';

        total += teacherShare;

        DateTime? endDate = courseEndDates[courseId];

        if (endDate == null || endDate.isAfter(safetyWindow)) {
          pending += teacherShare;
        } else {
          available += teacherShare;
        }
      }

      // 4. Fetch Withdrawals
      final withdrawalsQuery = await FirebaseFirestore.instance
          .collection('withdrawal_requests')
          .where('teacherId', isEqualTo: _currentUserId)
          .get();
          
      double totalWithdrawn = 0.0;
      for (var doc in withdrawalsQuery.docs) {
        final data = doc.data();
        if (data['status'] != 'rejected') {
          totalWithdrawn += (data['amount'] ?? data['netAmount'] ?? data['requestedAmount'] ?? 0.0).toDouble();
        }
      }
      
      // Subtract withdrawn from available
      available -= totalWithdrawn;
      if (available < 0) available = 0;

      if (mounted) {
        setState(() {
          _pendingBalance = pending;
          _availableBalance = available;
          _totalEarnings = total;
          _totalWithdrawn = totalWithdrawn;
          _selectedMethod = selectedMethod;
          _teacherName = teacherName;
          _commissionRate = commissionRate; // Store for UI
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppMessenger.showSnackBar(
          context,
          title: "Error",
          message: "Failed to load balances: $e",
          type: MessengerType.error,
        );
      }
    }
  }

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
          l10n.finance,
          style: const TextStyle(
            color: Colors.white,
            fontWeight: FontWeight.w900,
            letterSpacing: 1.2,
          ),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.history, color: AppColors.accentGold),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const TransactionHistoryPage(),
                ),
              );
            },
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: _isLoading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accentGold),
            )
          : SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children:
                    [
                          _buildTotalEarningsHero(l10n),
                          const SizedBox(height: 24),
                          _buildBalanceSplitCards(l10n),
                          const SizedBox(height: 16),
                          _buildWithdrawnCard(l10n),
                          const SizedBox(height: 32),
                          _buildWithdrawSection(l10n),
                          const SizedBox(height: 32),
                          _buildFinancialPromise(l10n),
                          const SizedBox(height: 32),
                          _buildModernHelpSection(l10n),
                          const SizedBox(height: 40),
                        ]
                        .animate(interval: 50.ms)
                        .fadeIn(duration: 400.ms)
                        .slideY(begin: 0.1, end: 0),
              ),
            ),
    );
  }

  Widget _buildTotalEarningsHero(AppLocalizations l10n) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(32),
        gradient: LinearGradient(
          colors: [AppColors.accentGold.withAlpha(40), Colors.transparent],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        border: Border.all(color: Colors.white.withAlpha(20)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(51),
            blurRadius: 30,
            offset: const Offset(0, 15),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(
            l10n.totalEarnings.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withAlpha(153),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 2.0,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "\$${_totalEarnings.toStringAsFixed(0)}",
            style: const TextStyle(
              color: Colors.white,
              fontSize: 56,
              fontWeight: FontWeight.w900,
              letterSpacing: -1,
            ),
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.trending_up,
                      color: AppColors.accentGold,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "All Time",
                      style: TextStyle(
                        color: AppColors.accentGold.withAlpha(204),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.secondary.withAlpha(30),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(
                      Icons.star,
                      color: AppColors.secondary,
                      size: 14,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      "${l10n.commissionLabel}: ${_commissionRate != null ? (_commissionRate! * 100).toStringAsFixed(0) : l10n.pending}%",
                      style: TextStyle(
                        color: AppColors.secondary.withAlpha(204),
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildBalanceSplitCards(AppLocalizations l10n) {
    return Row(
      children: [
        Expanded(
          child: _buildGlassStatCard(
            l10n.pendingBalance,
            "\$${_pendingBalance.toStringAsFixed(0)}",
            Colors.orangeAccent,
            Icons.timer_outlined,
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: _buildGlassStatCard(
            l10n.availableToWithdraw,
            "\$${_availableBalance.toStringAsFixed(0)}",
            AppColors.accentGold,
            Icons.check_circle_outline,
          ),
        ),
      ],
    );
  }

  Widget _buildWithdrawnCard(AppLocalizations l10n) {
    return _buildGlassStatCard(
      "Total Withdrawn",
      "\$${_totalWithdrawn.toStringAsFixed(0)}",
      Colors.greenAccent,
      Icons.account_balance_wallet_outlined,
    );
  }

  Widget _buildGlassStatCard(
    String label,
    String value,
    Color color,
    IconData icon,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white.withAlpha(13),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withAlpha(20)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 16),
          Text(
            value,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withAlpha(153),
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFinancialPromise(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.secondary.withAlpha(20),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.secondary.withAlpha(50)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.verified_user_outlined,
                color: AppColors.secondary,
                size: 20,
              ),
              const SizedBox(width: 10),
              Text(
                l10n.financialPromiseTitle,
                style: const TextStyle(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.w900,
                  fontSize: 14,
                  letterSpacing: 0.5,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            l10n.financialPromiseDesc,
            style: TextStyle(
              color: Colors.white.withAlpha(178),
              fontSize: 12,
              height: 1.6,
              fontStyle: FontStyle.italic,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWithdrawSection(AppLocalizations l10n) {
    if (_selectedMethod == null) {
      return _buildNoPayoutMethodState(l10n);
    }

    final double fee = _selectedMethod == 'western' ? 10.0 : 0.0;
    final bool canWithdraw = _availableBalance > 0;
    final String methodName = _selectedMethod == 'cliq'
        ? l10n.cliqJordanOnly
        : (_selectedMethod == 'western'
              ? l10n.westernUnion
              : l10n.bankTransfer);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4),
          child: Text(
            l10n.withdrawFunds.toUpperCase(),
            style: TextStyle(
              color: Colors.white.withAlpha(153),
              fontSize: 12,
              fontWeight: FontWeight.w900,
              letterSpacing: 1.5,
            ),
          ),
        ),
        const SizedBox(height: 16),
        Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: AppColors.cardBackground,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: Colors.white.withAlpha(15)),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withAlpha(51),
                blurRadius: 20,
                offset: const Offset(0, 10),
              ),
            ],
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.accentGold.withAlpha(30),
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      _selectedMethod == 'cliq'
                          ? Icons.account_balance_wallet_outlined
                          : Icons.public,
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
                          methodName,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w800,
                            fontSize: 16,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          _selectedMethod == 'cliq'
                              ? l10n.instantFreeOfCharge
                              : l10n.trustedWorldwide,
                          style: TextStyle(
                            color: Colors.white.withAlpha(127),
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    l10n.feeLabel(fee.toStringAsFixed(0)),
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                    ),
                  ),
                ],
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Divider(color: Colors.white10),
              ),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () {
                    if (canWithdraw) {
                      _showWithdrawDialog(l10n, methodName, fee);
                    } else {
                      AppMessenger.showSnackBar(
                        context,
                        title: l10n.noFundsAvailable,
                        message: l10n
                            .payoutMethodNotSelectedDesc, // Reusing a clear message or just a generic one
                        type: MessengerType.info,
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: canWithdraw
                        ? AppColors.accentGold
                        : Colors.white.withAlpha(20),
                    foregroundColor: canWithdraw
                        ? Colors.black
                        : Colors.white.withAlpha(51),
                    padding: const EdgeInsets.symmetric(vertical: 20),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: canWithdraw ? 8 : 0,
                    shadowColor: AppColors.accentGold.withAlpha(102),
                  ),
                  child: Text(
                    canWithdraw
                        ? l10n.requestNow.toUpperCase()
                        : l10n.noFundsAvailable.toUpperCase(),
                    style: const TextStyle(
                      fontWeight: FontWeight.w900,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildNoPayoutMethodState(AppLocalizations l10n) {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: Colors.redAccent.withAlpha(20),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(color: Colors.redAccent.withAlpha(50)),
      ),
      child: Column(
        children: [
          const Icon(
            Icons.warning_amber_rounded,
            color: Colors.redAccent,
            size: 48,
          ),
          const SizedBox(height: 16),
          Text(
            l10n.payoutMethodNotSelected,
            textAlign: TextAlign.center,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            l10n.payoutMethodNotSelectedDesc,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.white.withAlpha(153), fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildModernHelpSection(AppLocalizations l10n) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: Colors.white.withAlpha(10)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 24, 24, 16),
            child: Row(
              children: [
                const Icon(
                  Icons.help_outline,
                  color: AppColors.accentGold,
                  size: 20,
                ),
                const SizedBox(width: 10),
                Text(
                  l10n.howItWorks.toUpperCase(),
                  style: const TextStyle(
                    color: AppColors.accentGold,
                    fontWeight: FontWeight.w900,
                    fontSize: 14,
                    letterSpacing: 1.0,
                  ),
                ),
              ],
            ),
          ),
          _buildStepItem("1", l10n.helpPending),
          _buildStepItem("2", l10n.helpSafety),
          _buildStepItem("3", l10n.helpAvailable),
          _buildStepItem("4", l10n.helpFees, isLast: true),
          const SizedBox(height: 16),
        ],
      ),
    );
  }

  Widget _buildStepItem(String step, String text, {bool isLast = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            decoration: BoxDecoration(
              color: AppColors.accentGold.withAlpha(25),
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.accentGold.withAlpha(50)),
            ),
            alignment: Alignment.center,
            child: Text(
              step,
              style: const TextStyle(
                color: AppColors.accentGold,
                fontSize: 11,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  text,
                  style: TextStyle(
                    color: Colors.white.withAlpha(178),
                    fontSize: 13,
                    height: 1.5,
                  ),
                ),
                if (!isLast)
                  Container(
                    margin: const EdgeInsets.only(top: 12),
                    height: 1,
                    color: Colors.white.withAlpha(13),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showWithdrawDialog(AppLocalizations l10n, String method, double fee) {
    final double netAmount = _availableBalance - fee;

    showDialog(
      context: context,
      builder: (ctx) => BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 8, sigmaY: 8),
        child: AlertDialog(
          backgroundColor: AppColors.cardBackground.withAlpha(230),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(32),
            side: BorderSide(color: Colors.white.withAlpha(30)),
          ),
          title: Text(
            l10n.withdrawVia(method),
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w900,
              fontSize: 20,
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildDialogRow(
                l10n.amountLabel(_availableBalance.toStringAsFixed(0)),
                Colors.white70,
              ),
              const SizedBox(height: 8),
              _buildDialogRow(
                l10n.feeLabel(fee.toStringAsFixed(2)),
                Colors.redAccent,
              ),
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 20),
                child: Divider(color: Colors.white10),
              ),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    l10n
                        .receiveLabel("")
                        .replaceAll(
                          " \$",
                          "",
                        ), // Adjusting to show label & value
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                  Text(
                    "\$${netAmount.toStringAsFixed(0)}",
                    style: const TextStyle(
                      color: AppColors.accentGold,
                      fontWeight: FontWeight.w900,
                      fontSize: 28,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.white.withAlpha(10),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.info_outline,
                      color: Colors.white38,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        l10n.requestManualNote,
                        style: const TextStyle(
                          color: Colors.white38,
                          fontSize: 11,
                          height: 1.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actionsPadding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: Text(
                l10n.cancel,
                style: const TextStyle(
                  color: Colors.white54,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            const SizedBox(width: 8),
            ElevatedButton(
              onPressed: netAmount <= 0
                  ? null
                  : () => _submitWithdrawal(l10n, method, fee, netAmount),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: Text(
                l10n.requestNow,
                style: const TextStyle(fontWeight: FontWeight.w900),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDialogRow(String text, Color color) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          text,
          style: TextStyle(
            color: color,
            fontSize: 14,
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }

  void _submitWithdrawal(
    AppLocalizations l10n,
    String method,
    double fee,
    double amount,
  ) async {
    Navigator.pop(context); // Close dialog
    setState(() => _isLoading = true);

    try {
      await FirebaseFirestore.instance.collection('withdrawal_requests').add({
        'teacherId': _currentUserId,
        'teacherName': _teacherName,
        'method': method,
        'payoutMethod': method, // Redundancy for AdminPayoutsPage
        'fee': fee,
        'requestedAmount': _availableBalance,
        'netAmount': amount,
        'amount': amount, // Redundancy for AdminPayoutsPage
        'status': 'pending',
        'createdAt': FieldValue.serverTimestamp(),
      });

      if (mounted) {
        setState(() {
          _availableBalance = 0; // Reset for mock
          _isLoading = false;
        });

        AppMessenger.showSnackBar(
          context,
          title: l10n.requestSent,
          message: l10n.requestSentDesc,
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
        AppMessenger.showSnackBar(
          context,
          title: "Error",
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    }
  }
}
