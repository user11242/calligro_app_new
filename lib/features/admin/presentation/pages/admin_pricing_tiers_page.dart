import 'package:flutter/material.dart';
import 'package:calligro_app/core/services/price_tier_service.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/message/app_messenger.dart';

class AdminPricingTiersPage extends StatefulWidget {
  const AdminPricingTiersPage({super.key});

  @override
  State<AdminPricingTiersPage> createState() => _AdminPricingTiersPageState();
}

class _AdminPricingTiersPageState extends State<AdminPricingTiersPage> {
  final PriceTierService _tierService = PriceTierService();
  bool _isLoading = true;
  bool _isSaving = false;

  List<Map<String, dynamic>> _tiers = [];

  @override
  void initState() {
    super.initState();
    _loadTiers();
  }

  Future<void> _loadTiers() async {
    setState(() => _isLoading = true);
    try {
      final list = await _tierService.getAllTiers();
      if (mounted) {
        setState(() {
          _tiers = list;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  Future<void> _saveTiers() async {
    setState(() => _isSaving = true);
    try {
      await _tierService.saveTiers(_tiers);
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'تم الحفظ',
          message: 'تم تحديث وتطبيق باقات الأسعار بنجاح.',
          type: MessengerType.success,
        );
      }
    } catch (e) {
      if (mounted) {
        AppMessenger.showSnackBar(
          context,
          title: 'خطأ أثناء الحفظ',
          message: e.toString(),
          type: MessengerType.error,
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _addNewTierDialog() {
    final priceCtrl = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1E2026),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          title: const Text(
            'إضافة باقة سعر جديدة',
            style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
          ),
          content: TextField(
            controller: priceCtrl,
            keyboardType: TextInputType.number,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              labelText: 'السعر بالدولار',
              labelStyle: const TextStyle(color: Colors.white60),
              prefixText: '\$ ',
              prefixStyle: const TextStyle(color: AppColors.accentGold, fontWeight: FontWeight.bold),
              filled: true,
              fillColor: Colors.black26,
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('إلغاء', style: TextStyle(color: Colors.white60)),
            ),
            ElevatedButton(
              onPressed: () {
                final price = int.tryParse(priceCtrl.text.trim());
                if (price != null && price > 0) {
                  setState(() {
                    if (!_tiers.any((t) => (t['price'] as num).toInt() == price)) {
                      _tiers.add({'price': price, 'enabled': true});
                      _tiers.sort((a, b) => (a['price'] as num).compareTo(b['price'] as num));
                    }
                  });
                  Navigator.pop(ctx);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accentGold,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('إضافة', style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
            ),
          ],
        );
      },
    );
  }

  void _setAll(bool enabled) {
    setState(() {
      for (var t in _tiers) {
        t['enabled'] = enabled;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final enabledCount = _tiers.where((t) => (t['enabled'] as bool?) ?? false).length;
    final allEnabled = enabledCount == _tiers.length;

    return Scaffold(
      backgroundColor: AppColors.primary,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        elevation: 0,
        title: const Text(
          'باقات أسعار الدورات',
          style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 18),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        centerTitle: true,
        actions: [
          IconButton(
            icon: const Icon(Icons.add_rounded, color: AppColors.accentGold, size: 26),
            tooltip: 'إضافة باقة سعر',
            onPressed: _addNewTierDialog,
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: AppColors.accentGold))
          : Column(
              children: [
                // ── Sleek Subtitle & Quick Toggle ──
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Text(
                                '$enabledCount باقة مفعلة',
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                                decoration: BoxDecoration(
                                  color: AppColors.accentGold.withValues(alpha: 0.15),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Text(
                                  'من إجمالي ${_tiers.length}',
                                  style: const TextStyle(
                                    color: AppColors.accentGold,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'الباقات التي يمكن للمعلمين اختيارها عند تسعير دوراتهم',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.5),
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                      TextButton(
                        onPressed: () => _setAll(!allEnabled),
                        style: TextButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                          backgroundColor: allEnabled
                              ? Colors.redAccent.withValues(alpha: 0.12)
                              : AppColors.accentGold.withValues(alpha: 0.12),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: Text(
                          allEnabled ? 'تعطيل الكل' : 'تفعيل الكل',
                          style: TextStyle(
                            color: allEnabled ? Colors.redAccent : AppColors.accentGold,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                // ── Grouped Tiers List ──
                Expanded(
                  child: SingleChildScrollView(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF1E2026),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(
                          color: Colors.white.withValues(alpha: 0.07),
                          width: 1,
                        ),
                      ),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(20),
                        child: ListView.separated(
                          shrinkWrap: true,
                          physics: const NeverScrollableScrollPhysics(),
                          itemCount: _tiers.length,
                          separatorBuilder: (context, index) => Divider(
                            height: 1,
                            thickness: 0.8,
                            indent: 68,
                            endIndent: 16,
                            color: Colors.white.withValues(alpha: 0.05),
                          ),
                          itemBuilder: (context, index) {
                            final tier = _tiers[index];
                            final price = (tier['price'] as num).toInt();
                            final isEnabled = (tier['enabled'] as bool?) ?? false;

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  tier['enabled'] = !isEnabled;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Circular Price Badge
                                    Container(
                                      width: 44,
                                      height: 44,
                                      decoration: BoxDecoration(
                                        color: isEnabled
                                            ? AppColors.accentGold.withValues(alpha: 0.15)
                                            : Colors.white.withValues(alpha: 0.04),
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isEnabled
                                              ? AppColors.accentGold.withValues(alpha: 0.4)
                                              : Colors.white.withValues(alpha: 0.08),
                                          width: 1,
                                        ),
                                      ),
                                      child: Center(
                                        child: Text(
                                          '\$$price',
                                          style: TextStyle(
                                            color: isEnabled ? AppColors.accentGold : Colors.white38,
                                            fontSize: 15,
                                            fontWeight: FontWeight.w800,
                                          ),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // Tier Details
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'باقة $price دولار',
                                            style: TextStyle(
                                              color: isEnabled ? Colors.white : Colors.white38,
                                              fontSize: 15,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                          const SizedBox(height: 2),
                                          Text(
                                            isEnabled ? 'متاحة للمعلمين' : 'مخفية',
                                            style: TextStyle(
                                              color: isEnabled
                                                  ? AppColors.accentGold.withValues(alpha: 0.8)
                                                  : Colors.white24,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),

                                    // Switch
                                    Switch(
                                      value: isEnabled,
                                      activeTrackColor: AppColors.accentGold.withValues(alpha: 0.35),
                                      activeThumbColor: AppColors.accentGold,
                                      inactiveThumbColor: Colors.white38,
                                      inactiveTrackColor: Colors.white12,
                                      onChanged: (val) {
                                        setState(() {
                                          tier['enabled'] = val;
                                        });
                                      },
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  ),
                ),

                // ── Bottom Action Button ──
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1E2026),
                    border: Border(
                      top: BorderSide(color: Colors.white.withValues(alpha: 0.06)),
                    ),
                  ),
                  child: SafeArea(
                    top: false,
                    child: SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton(
                        onPressed: _isSaving ? null : _saveTiers,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.accentGold,
                          foregroundColor: Colors.black,
                          elevation: 2,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        ),
                        child: _isSaving
                            ? const SizedBox(
                                width: 22,
                                height: 22,
                                child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.black),
                              )
                            : const Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  Icon(Icons.check_circle_rounded, size: 20),
                                  SizedBox(width: 8),
                                  Text(
                                    'حفظ وتطبيق التغييرات',
                                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                                  ),
                                ],
                              ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
