import 'package:flutter/material.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import '../../../../core/message/app_messenger.dart';
import 'package:calligro_app/features/auth/pages/terms_and_conditions_page.dart';

class CoursePricePage extends StatefulWidget {
  final TextEditingController priceController;
  final double teacherEarningPercentage;
  final bool hasCommissionRate;
  final Function onNext;
  final Function onBack;

  const CoursePricePage({
    super.key,
    required this.priceController,
    required this.teacherEarningPercentage,
    required this.hasCommissionRate,
    required this.onNext,
    required this.onBack,
  });

  @override
  State<CoursePricePage> createState() => _CoursePricePageState();
}

class _CoursePricePageState extends State<CoursePricePage> {
  // Use a state variable to control when to show the content
  bool _isFirstTap = true;
  double _price = 0.0;

  // Define the master tiers
  final List<int> _priceTiers = [100, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200];

  @override
  void initState() {
    super.initState();
    _price = double.tryParse(widget.priceController.text) ?? 0.0;
    widget.priceController.addListener(_onPriceChanged);
  }

  @override
  void dispose() {
    widget.priceController.removeListener(_onPriceChanged);
    super.dispose();
  }

  void _onPriceChanged() {
    final text = widget.priceController.text;
    final normalized = CourseUtils.normalizeNumerics(text);
    
    if (text != normalized) {
      widget.priceController.value = widget.priceController.value.copyWith(
        text: normalized,
        selection: TextSelection.collapsed(offset: normalized.length),
      );
      return;
    }

    final newPrice = double.tryParse(normalized) ?? 0.0;
    if (newPrice != _price) {
      setState(() {
        _price = newPrice;
      });
    }
  }

  // Validation method to check if the price field is empty
  void _validateAndProceed() {
    final originalText = widget.priceController.text;
    final normalizedText = CourseUtils.normalizeNumerics(originalText);
    
    if (originalText != normalizedText) {
      widget.priceController.text = normalizedText;
    }

    if (widget.priceController.text.isEmpty) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.validation,
        message: AppLocalizations.of(context)!.pleaseEnterCoursePrice,
        type: MessengerType.info,
      );
    } else if (!widget.hasCommissionRate) {
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.actionRequired,
        message: AppLocalizations.of(context)!.cannotProceedNoCommission,
        type: MessengerType.error,
      );
    } else {
      FocusScope.of(context).unfocus();
      widget.onNext();
    }
  }

  void _showPriceInfoDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.info_outline, color: Colors.white, size: 50),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  children: [
                    TextSpan(
                      text: AppLocalizations.of(context)!.priceInfoNote,
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {
                          Navigator.of(context).pop(); // Close current dialog
                          _showTermsAndConditionsPage(context);
                        },
                        child: Text(
                          AppLocalizations.of(context)!.termsAndConditions,
                          style: const TextStyle(
                            color: Colors.blueAccent,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                    const TextSpan(text: "."),
                  ],
                ),
              ),
            ],
          ),
          actions: <Widget>[
            TextButton(
              child: Text(
                AppLocalizations.of(context)!.gotIt,
                style: const TextStyle(color: Colors.white),
              ),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

  void _showTermsAndConditionsPage(BuildContext context) {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (context) => const TermsAndConditionsPage()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: GestureDetector(
        onTap: () => FocusScope.of(context).unfocus(),
        behavior: HitTestBehavior.opaque,
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        l10n.enterCoursePrice,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          letterSpacing: 0.5,
                        ),
                      ),
                      const SizedBox(height: 16),
                      // Price Tier Selection
                      SizedBox(
                        height: 100,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          itemCount: _priceTiers.length,
                          separatorBuilder: (context, index) => const SizedBox(width: 12),
                          itemBuilder: (context, index) {
                            final tier = _priceTiers[index];
                            final isSelected = _price.toInt() == tier;

                            return GestureDetector(
                              onTap: () {
                                widget.priceController.text = tier.toString();
                                FocusScope.of(context).unfocus();
                                if (_isFirstTap) {
                                  _showPriceInfoDialog(context);
                                  setState(() {
                                    _isFirstTap = false;
                                  });
                                }
                              },
                              child: Container(
                                width: 90,
                                decoration: BoxDecoration(
                                  color: isSelected
                                      ? AppColors.textColor.withOpacity(0.9)
                                      : Colors.white.withOpacity(0.05),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: isSelected
                                        ? AppColors.textColor
                                        : Colors.white.withOpacity(0.1),
                                    width: isSelected ? 2 : 1,
                                  ),
                                  boxShadow: isSelected
                                      ? [
                                          BoxShadow(
                                            color: AppColors.textColor.withOpacity(0.3),
                                            blurRadius: 12,
                                            offset: const Offset(0, 4),
                                          )
                                        ]
                                      : null,
                                ),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Text(
                                      "\$$tier",
                                      style: TextStyle(
                                        color: isSelected ? Colors.black : Colors.white,
                                        fontSize: 22,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      "Tier ${index + 1}",
                                      style: TextStyle(
                                        color: isSelected
                                            ? Colors.black.withOpacity(0.6)
                                            : Colors.white60,
                                        fontSize: 12,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        l10n.priceInfoNote,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.4),
                          fontSize: 12,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                      const SizedBox(height: 24),
                      // Real-time Breakdown Table
                      if (_price > 0)
                        widget.hasCommissionRate
                            ? _buildPriceBreakdown()
                            : _buildCommissionWarning(),
                    ],
                  ),
                ),
              ),
  
              // Bottom Navigation Panel
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
                  decoration: BoxDecoration(
                    color: AppColors.white.withOpacity(0.05),
                    borderRadius:
                        const BorderRadius.vertical(top: Radius.circular(32)),
                    border: Border(
                      top: BorderSide(color: Colors.white.withOpacity(0.1)),
                    ),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: OutlinedButton(
                              onPressed: () => widget.onBack(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: Colors.white,
                                side: const BorderSide(color: Colors.white54),
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                              ),
                              child: Text(
                                l10n.back,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: ElevatedButton.icon(
                              onPressed: _validateAndProceed,
                              style: ElevatedButton.styleFrom(
                                backgroundColor: AppColors.textColor,
                                foregroundColor: Colors.black,
                                padding: const EdgeInsets.symmetric(vertical: 18),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                elevation: 4,
                              ),
                              icon: const Icon(Icons.arrow_forward),
                              label: Text(
                                l10n.next,
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildPriceBreakdown() {
    final teacherShare = _price * (widget.teacherEarningPercentage / 100);

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.cardBackground,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.textColor.withOpacity(0.1)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.2),
            blurRadius: 15,
            offset: const Offset(0, 8),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.textColor.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: const Icon(
                  Icons.account_balance_wallet_rounded,
                  color: AppColors.textColor,
                  size: 28,
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      AppLocalizations.of(context)!.teacherEarnings,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      AppLocalizations.of(context)!.perStudent,
                      style: const TextStyle(
                        color: Colors.white60,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          const Divider(color: Colors.white12, height: 1),
          const SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.commissionRateLabel,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 15,
                ),
              ),
              Text(
                "${widget.teacherEarningPercentage}%",
                style: const TextStyle(
                  color: AppColors.textColor,
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                AppLocalizations.of(context)!.yourShareLabel,
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                ),
              ),
              Text(
                "\$${teacherShare.toStringAsFixed(2)}",
                style: const TextStyle(
                  color: AppColors.textColor,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCommissionWarning() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.redAccent.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.redAccent.withOpacity(0.3)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.redAccent.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.warning_amber_rounded,
              color: Colors.redAccent,
              size: 28,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  AppLocalizations.of(context)!.noCommissionSet,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  AppLocalizations.of(context)!.noCommissionSetDescription,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontSize: 13,
                    height: 1.4,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
