import 'dart:ui';
import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import 'package:calligro_app/core/widgets/auto_translated_text.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';
import 'package:calligro_app/core/utils/course_utils.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:calligro_app/core/services/iap_service.dart';
import 'package:in_app_purchase/in_app_purchase.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:calligro_app/features/student/pages/purchase_success_page.dart';
import 'dart:async';
import 'package:calligro_app/core/message/app_messenger.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CourseCheckoutPage extends StatefulWidget {
  final String courseId;
  final Map<String, dynamic> courseData;

  const CourseCheckoutPage({
    super.key,
    required this.courseId,
    required this.courseData,
  });

  @override
  State<CourseCheckoutPage> createState() => _CourseCheckoutPageState();
}

class _CourseCheckoutPageState extends State<CourseCheckoutPage> {
  bool _isProcessing = false;
  late StreamSubscription<PurchaseResult> _subscription;

  @override
  void initState() {
    super.initState();
    _subscription = IAPService().purchaseStream.listen((result) {
      if (result.status == PurchaseStatus.purchased || result.status == PurchaseStatus.restored) {
        _handleServerValidation(result);
      } else if (result.status == PurchaseStatus.error || result.status == PurchaseStatus.canceled) {
        _safetyTimer?.cancel();
        if (mounted) setState(() => _isProcessing = false);
        if (result.status == PurchaseStatus.error) {
          AppMessenger.showSnackBar(
            context,
            title: AppLocalizations.of(context)!.error,
            message: result.error ?? "Payment failed. Please try again.",
            type: MessengerType.error,
          );
        }
      }
    });
  }

  Timer? _safetyTimer;

  Future<void> _handleServerValidation(PurchaseResult result) async {
    _safetyTimer?.cancel();
    
    // Safety timer for server response
    _safetyTimer = Timer(const Duration(seconds: 20), () {
      if (mounted && _isProcessing) {
        setState(() => _isProcessing = false);
        AppMessenger.showSnackBar(
          context,
          title: "Waiting for Server",
          message: "The payment succeeded, but the server is taking a moment to unlock your course. Please check your dashboard in a minute.",
          type: MessengerType.info,
        );
      }
    });

    try {
      final String? receipt = result.receipt;
      if (receipt == null) throw "Receipt data missing.";

      debugPrint("📡 [Checkout] Calling verifyPurchase Cloud Function...");
      final callable = FirebaseFunctions.instance.httpsCallable('verifyPurchase');
      final validationResult = await callable.call({
        'receiptData': receipt,
        'courseId': widget.courseId,
        'productId': result.productId,
      });

      final bool success = validationResult.data['success'] ?? false;
      if (success && mounted) {
        _safetyTimer?.cancel();
        setState(() => _isProcessing = false);
        if (!mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseSuccessPage(
              courseId: widget.courseId,
              courseData: widget.courseData,
            ),
          ),
        );
      } else {
        throw validationResult.data['message'] ?? "Validation failed.";
      }
    } catch (e) {
      _safetyTimer?.cancel();
      if (mounted) {
        setState(() => _isProcessing = false);
        AppMessenger.showSnackBar(context, title: "Security Error", message: e.toString(), type: MessengerType.error);
      }
    }
  }

  @override
  void dispose() {
    _subscription.cancel();
    super.dispose();
  }

  Future<void> _enrollStudent() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      await FirebaseFirestore.instance.collection('courses').doc(widget.courseId).update({
        'enrolledStudents': FieldValue.arrayUnion([user.uid]),
        'enrolledCount': FieldValue.increment(1),
      });

      if (mounted) {
        setState(() => _isProcessing = false);
        // Navigate to Success Page
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => PurchaseSuccessPage(
              courseId: widget.courseId,
              courseData: widget.courseData,
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _isProcessing = false);
      debugPrint("Enrollment error: $e");
    }
  }

  Future<void> _handlePurchase() async {
    if (widget.courseData['price'] == 0) {
      _enrollStudent();
      return;
    }

    setState(() => _isProcessing = true);
    
    final productId = widget.courseData['iapProductId'] ?? 
        'com.yazan.calligro.tier_${(widget.courseData['price'] ?? 50.0).toInt()}';

    try {
      await IAPService().buyCourse(productId);
    } catch (e) {
      setState(() => _isProcessing = false);
      AppMessenger.showSnackBar(
        context,
        title: AppLocalizations.of(context)!.error,
        message: e.toString(),
        type: MessengerType.error,
      );
    }
  }

  Future<void> _launchUrl(String url) async {
    final Uri uri = Uri.parse(url);
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (mounted) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text("Could not launch $url")),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final bannerUrl = widget.courseData['courseBanner'] ?? '';
    final price = (widget.courseData['price'] ?? 0).toDouble();
    final String teacherName = widget.courseData['teacherName'] ?? 'Master Artist';

    final isFree = price == 0;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Stack(
        children: [
          // 🌌 Background Ambient Glow
          Positioned(
            top: -100,
            right: -50,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.accentGold.withValues(alpha: 0.1),
              ),
            ).animate().fadeIn(duration: 1000.ms).scale(),
          ),

          CustomScrollView(
            slivers: [
              // --- Header ---
              SliverAppBar(
                expandedHeight: 280,
                pinned: true,
                backgroundColor: AppColors.primary,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(context),
                ),
                flexibleSpace: FlexibleSpaceBar(
                  background: Stack(
                    fit: StackFit.expand,
                    children: [
                      SmartImage(
                        imageUrl: bannerUrl,
                        fit: BoxFit.cover,
                      ),
                      Container(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              Colors.transparent,
                              AppColors.primary.withValues(alpha: 0.8),
                              AppColors.primary,
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // --- Course Info ---
                      AutoTranslatedText(
                        CourseUtils.getLocalizedCourseName(context, widget.courseData),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          letterSpacing: -0.5,
                        ),
                      ).animate().fadeIn().slideY(begin: 0.1),
                      
                      const SizedBox(height: 8),
                      
                      Text(
                        teacherName,
                        style: TextStyle(
                          color: AppColors.accentGold.withValues(alpha: 0.8),
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ).animate().fadeIn(delay: 200.ms),

                      const SizedBox(height: 32),

                      // --- Premium Features Card ---
                      _buildGlassCard(
                        child: Column(
                          children: [
                            _buildFeatureItem(Icons.check_circle_outline, l10n.fullAccess),
                            const Divider(color: Colors.white10),
                            _buildFeatureItem(Icons.devices, l10n.multiDeviceSync),
                            const Divider(color: Colors.white10),
                            _buildFeatureItem(Icons.update, l10n.lifetimeUpdates),
                          ],
                        ),
                      ).animate().fadeIn(delay: 400.ms).scale(),

                      const SizedBox(height: 40),

                      // --- Final Price ---
                      Center(
                        child: Column(
                          children: [
                            Text(
                              l10n.price.toUpperCase(),
                              style: TextStyle(
                                color: Colors.white.withValues(alpha: 0.4),
                                fontSize: 12,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              isFree ? l10n.free.toUpperCase() : "\$$price",
                              style: const TextStyle(
                                color: Colors.white,
                                fontSize: 48,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 600.ms),

                      const SizedBox(height: 40),

                      // --- Apple Compliance Links ---
                      if (!isFree)
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            _buildSmallTextButton(l10n.termsOfUse, () => _launchUrl('https://calligro.com/terms')),
                            Text(" • ", style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                            _buildSmallTextButton(l10n.privacyPolicy, () => _launchUrl('https://calligro.com/privacy')),
                            Text(" • ", style: TextStyle(color: Colors.white.withValues(alpha: 0.2))),
                            _buildSmallTextButton(l10n.restorePurchases, () {
                              // TODO: Implement restore
                            }),
                          ],
                        ).animate().fadeIn(delay: 800.ms),

                      const SizedBox(height: 120), // Bottom padding for fixed button
                    ],
                  ),
                ),
              ),
            ],
          ),

          // --- Bottom Purchase Button ---
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: Container(
              padding: EdgeInsets.fromLTRB(
                24, 20, 24, MediaQuery.of(context).padding.bottom + 20,
              ),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    AppColors.primary.withValues(alpha: 0),
                    AppColors.primary,
                  ],
                ),
              ),
              child: ElevatedButton(
                onPressed: _isProcessing ? null : _handlePurchase,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.accentGold,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                  elevation: 8,
                  shadowColor: AppColors.accentGold.withValues(alpha: 0.3),
                ),
                child: _isProcessing
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black),
                      )
                    : Text(
                        (isFree ? l10n.enrollForFree : l10n.purchaseNow).toUpperCase(),
                        style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16, letterSpacing: 1.5),
                      ),
              ),
            ),
          ).animate().slideY(begin: 1, delay: 1000.ms),
        ],
      ),
    );
  }

  Widget _buildGlassCard({required Widget child}) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 10, sigmaY: 10),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: child,
        ),
      ),
    );
  }

  Widget _buildFeatureItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: AppColors.accentGold, size: 20),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.w500),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSmallTextButton(String text, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
        child: Text(
          text,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.4),
            fontSize: 11,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
