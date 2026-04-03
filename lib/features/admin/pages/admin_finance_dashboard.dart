import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/admin/data/services/admin_service.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:intl/intl.dart';

class AdminFinanceDashboard extends StatefulWidget {
  const AdminFinanceDashboard({super.key});

  @override
  State<AdminFinanceDashboard> createState() => _AdminFinanceDashboardState();
}

class _AdminFinanceDashboardState extends State<AdminFinanceDashboard> {
  final AdminService _adminService = AdminService();
  String _searchQuery = '';
  final NumberFormat _currencyFormat = NumberFormat.currency(symbol: '\$');

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final isDesktop = MediaQuery.of(context).size.width > 900;

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFF0F0F0F),
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          title: Text(
            l10n.payments,
            style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
          ),
          bottom: TabBar(
            dividerColor: Colors.transparent,
            indicatorColor: AppColors.accentGold,
            labelColor: AppColors.accentGold,
            unselectedLabelColor: Colors.white38,
            tabs: [
              Tab(text: l10n.overview),
              const Tab(text: 'Transactions'),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.refresh, color: Colors.white70),
              onPressed: () => setState(() {}),
            ),
          ],
        ),
        body: TabBarView(
          children: [
            // TAB 1: OVERVIEW
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getFinancialTransactions(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator(color: AppColors.accentGold));
                }
                if (snapshot.hasError) {
                  return Center(child: Text('Error: ${snapshot.error}', style: const TextStyle(color: Colors.red)));
                }

                final transactions = snapshot.data ?? [];
                final teachersStream = _adminService.getTeacherFinancialSnapshots();

                return CustomScrollView(
                  slivers: [
                    // 1. TOP METRICS
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: SliverToBoxAdapter(
                        child: _buildGlobalMetrics(transactions),
                      ),
                    ),

                    // 2. SEARCH & FILTERS
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
                        child: _buildSearchBar(),
                      ),
                    ),

                    // 3. TEACHER LIST
                    SliverPadding(
                      padding: const EdgeInsets.all(20),
                      sliver: StreamBuilder<Map<String, Map<String, dynamic>>>(
                        stream: teachersStream,
                        builder: (context, teacherSnapshot) {
                          final teacherData = teacherSnapshot.data ?? {};
                          final filteredTeachers = teacherData.entries.where((e) {
                            final name = e.value['name'].toString().toLowerCase();
                            return name.contains(_searchQuery.toLowerCase());
                          }).toList();

                          if (filteredTeachers.isEmpty) {
                            return const SliverToBoxAdapter(
                              child: Center(
                                child: Padding(
                                  padding: EdgeInsets.all(40.0),
                                  child: Text('No data found', style: TextStyle(color: Colors.white38)),
                                ),
                              ),
                            );
                          }

                          return SliverList(
                            delegate: SliverChildBuilderDelegate(
                              (context, index) {
                                final teacherId = filteredTeachers[index].key;
                                final data = filteredTeachers[index].value;
                                return _buildTeacherRow(teacherId, data, isDesktop);
                              },
                              childCount: filteredTeachers.length,
                            ),
                          );
                        },
                      ),
                    ),
                    
                    const SliverToBoxAdapter(child: SizedBox(height: 100)),
                  ],
                );
              },
            ),

            // TAB 2: RAW TRANSACTIONS & SETTLEMENT
            StreamBuilder<List<Map<String, dynamic>>>(
              stream: _adminService.getFinancialTransactions(),
              builder: (context, snapshot) {
                final transactions = snapshot.data ?? [];
                if (transactions.isEmpty) {
                  return const Center(child: Text('No transactions recorded yet', style: TextStyle(color: Colors.white38)));
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(20),
                  itemCount: transactions.length,
                  itemBuilder: (context, index) {
                    final tx = transactions[index];
                    return _buildTransactionSettlementCard(tx);
                  },
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionSettlementCard(Map<String, dynamic> tx) {
    final status = tx['status'] as String? ?? 'pending_store';
    final isSettled = status == 'settled';

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: (isSettled ? Colors.green : Colors.amber).withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  isSettled ? Icons.check_circle_outline : Icons.hourglass_top_rounded,
                  color: isSettled ? Colors.green : Colors.amber,
                  size: 20,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      tx['studentName'] ?? 'Student',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                    Text(
                      tx['courseName'] ?? 'Course',
                      style: const TextStyle(color: Colors.white38, fontSize: 12),
                    ),
                  ],
                ),
              ),
              Text(
                _currencyFormat.format(tx['amount'] ?? 0),
                style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
              ),
            ],
          ),
          const Divider(color: Colors.white10, height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                isSettled ? 'Settled in Bank' : 'Pending Store Transfer',
                style: TextStyle(
                  color: isSettled ? Colors.green : Colors.amber,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
              if (!isSettled)
                TextButton.icon(
                  onPressed: () => _showSettlementConfirmation(tx),
                  icon: const Icon(Icons.account_balance_outlined, size: 16),
                  label: const Text('Mark Settled'),
                  style: TextButton.styleFrom(
                    foregroundColor: AppColors.accentGold,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                    backgroundColor: AppColors.accentGold.withOpacity(0.1),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _showSettlementConfirmation(Map<String, dynamic> tx) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1A1A1A),
        title: const Text('Confirm Settlement', style: TextStyle(color: Colors.white)),
        content: Text(
          'Have you received the bank transfer from ${tx['source'] == 'in_app_purchase' ? 'the App Store' : 'HyperPay'} for this transaction?',
          style: const TextStyle(color: Colors.white70),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.white38)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
            onPressed: () async {
              Navigator.pop(ctx);
              await _adminService.updateTransactionStatus(tx['id'], 'settled');
              if (mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('Transaction marked as settled')),
                );
              }
            },
            child: const Text('Yes, Received'),
          ),
        ],
      ),
    );
  }

  Widget _buildGlobalMetrics(List<Map<String, dynamic>> transactions) {
    double totalGross = 0;
    double pendingStore = 0;
    double settledBank = 0;
    double academyProfit = 0;

    for (var tx in transactions) {
      final amount = (tx['amount'] ?? 0).toDouble();
      final profit = (tx['academyProfit'] ?? 0).toDouble();
      totalGross += amount;
      academyProfit += profit;
      
      if (tx['status'] == 'settled') {
        settledBank += amount;
      } else {
        pendingStore += amount;
      }
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final crossAxisCount = constraints.maxWidth > 900 ? 4 : 2;
        return GridView.count(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          crossAxisCount: crossAxisCount,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 2.2,
          children: [
            _buildMetricCard('Total Revenue', totalGross, Icons.payments_outlined, Colors.blue),
            _buildMetricCard('Pending (Store)', pendingStore, Icons.hourglass_empty_rounded, Colors.amber),
            _buildMetricCard('Settled (Bank)', settledBank, Icons.account_balance_rounded, Colors.green),
            _buildMetricCard('Calligro Profit', academyProfit, Icons.trending_up_rounded, AppColors.accentGold),
          ],
        );
      },
    );
  }

  Widget _buildMetricCard(String label, double value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  style: const TextStyle(color: Colors.white38, fontSize: 12),
                ),
                const SizedBox(height: 4),
                FittedBox(
                  child: Text(
                    _currencyFormat.format(value),
                    style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSearchBar() {
    return Container(
      height: 50,
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(15),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: TextField(
        onChanged: (v) => setState(() => _searchQuery = v),
        style: const TextStyle(color: Colors.white, fontSize: 14),
        decoration: InputDecoration(
          hintText: 'Search Teachers...',
          hintStyle: const TextStyle(color: Colors.white24),
          prefixIcon: const Icon(Icons.search, color: Colors.white38),
          border: InputBorder.none,
          contentPadding: const EdgeInsets.symmetric(vertical: 15),
        ),
      ),
    );
  }

  Widget _buildTeacherRow(String teacherId, Map<String, dynamic> data, bool isDesktop) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.03)),
      ),
      child: Theme(
        data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
        child: ExpansionTile(
          shape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          collapsedShape: const RoundedRectangleBorder(borderRadius: BorderRadius.all(Radius.circular(20))),
          leading: CircleAvatar(
            backgroundColor: AppColors.accentGold.withOpacity(0.1),
            child: Text(
              data['name'].toString().substring(0, 1).toUpperCase(),
              style: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold),
            ),
          ),
          title: Text(
            data['name'],
            style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
          ),
          subtitle: Text(
            '${data['courses'].length} Courses • Total Share: ${_currencyFormat.format(data['totalTeacherShare'])}',
            style: const TextStyle(color: Colors.white38, fontSize: 12),
          ),
          trailing: _buildTeacherTrailing(data),
          childrenPadding: const EdgeInsets.all(20),
          children: [
            const Divider(color: Colors.white10),
            const SizedBox(height: 10),
            ...data['courses'].entries.map<Widget>((cEntry) {
              final cData = cEntry.value;
              return _buildCourseSubRow(cEntry.key, cData, isDesktop);
            }).toList(),
          ],
        ),
      ),
    );
  }

  Widget _buildTeacherTrailing(Map<String, dynamic> data) {
    final pending = data['pendingAmount'] as double;
    final settled = data['settledAmount'] as double;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        Text(
          _currencyFormat.format(settled),
          style: const TextStyle(color: Colors.green, fontWeight: FontWeight.bold, fontSize: 14),
        ),
        Text(
          'Pending: ${_currencyFormat.format(pending)}',
          style: const TextStyle(color: Colors.amber, fontSize: 10),
        ),
      ],
    );
  }

  Widget _buildCourseSubRow(String courseId, Map<String, dynamic> cData, bool isDesktop) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.03),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.book_outlined, color: Colors.white38, size: 18),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  cData['name'],
                  style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  '${cData['count']} Enrollments',
                  style: const TextStyle(color: Colors.white38, fontSize: 11),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                'Share: ${_currencyFormat.format(cData['share'])}',
                style: const TextStyle(color: Colors.white, fontSize: 14, fontWeight: FontWeight.bold),
              ),
              Text(
                'Gross: ${_currencyFormat.format(cData['gross'])}',
                style: const TextStyle(color: Colors.white24, fontSize: 10),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
