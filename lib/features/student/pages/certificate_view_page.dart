import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/student/data/services/certificate_service.dart';

class CertificateViewPage extends StatefulWidget {
  final CertificateModel certificate;

  const CertificateViewPage({super.key, required this.certificate});

  @override
  State<CertificateViewPage> createState() => _CertificateViewPageState();
}

class _CertificateViewPageState extends State<CertificateViewPage> {
  @override
  void initState() {
    super.initState();
    // Force landscape mode when opening the certificate
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.landscapeRight,
      DeviceOrientation.landscapeLeft,
    ]);
  }

  @override
  void dispose() {
    // Revert back to portrait mode when closing
    SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
    ]);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final dateStr = DateFormat('MMMM d, yyyy', 'en_US').format(widget.certificate.issueDate);
    
    return Scaffold(
      backgroundColor: const Color(0xFF050505),
      body: Stack(
        children: [
          // The Certificate Canvas
          Center(
            child: AspectRatio(
              aspectRatio: 1.414, // A4 aspect ratio (Landscape)
              child: Container(
                margin: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: const Color(0xFFFDFCF9),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.5),
                      blurRadius: 20,
                      spreadRadius: 5,
                    ),
                  ],
                ),
                child: ClipRect(
                  child: Stack(
                    children: [
                      // Bottom Left Gold Shape
                      Positioned(
                        bottom: -100,
                        left: -100,
                        child: Container(
                          width: 400,
                          height: 400,
                          decoration: const BoxDecoration(
                            color: Color(0xFFD4AF37),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                      
                      // Top Right Black Shape
                      Positioned(
                        top: -100,
                        right: -100,
                        child: Container(
                          width: 300,
                          height: 300,
                          decoration: const BoxDecoration(
                            color: Color(0xFF111111),
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),

                      // Outer borders
                      Positioned.fill(
                        child: Container(
                          margin: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            border: Border.all(color: const Color(0xFF111111), width: 4),
                          ),
                          child: Container(
                            margin: const EdgeInsets.all(8),
                            decoration: BoxDecoration(
                              border: Border.all(color: const Color(0xFFD4AF37), width: 1),
                            ),
                          ),
                        ),
                      ),

                      // Watermark
                      Positioned.fill(
                        child: Center(
                          child: Opacity(
                            opacity: 0.03,
                            child: Image.asset(
                              'assets/images/Logo.png',
                              width: 300,
                              height: 300,
                            ),
                          ),
                        ),
                      ),

                      // Left Side Ribbon
                      Positioned(
                        left: 60,
                        top: 0,
                        bottom: 0,
                        child: Container(
                          width: 80,
                          decoration: const BoxDecoration(
                            color: Color(0xFF1A1A1A),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(5, 0),
                              ),
                            ],
                          ),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.end,
                            children: [
                              const Text(
                                'VERIFICATION',
                                style: TextStyle(
                                  color: Color(0xFFD4AF37),
                                  fontSize: 8,
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 2,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
                                margin: const EdgeInsets.only(bottom: 24, left: 8, right: 8),
                                color: const Color(0xFFFCF8F0),
                                child: Text(
                                  widget.certificate.id.substring(0, 10).toUpperCase(),
                                  style: const TextStyle(
                                    color: Colors.black,
                                    fontSize: 8,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // Left Side Seal
                      Positioned(
                        left: 40,
                        top: 100,
                        child: Container(
                          width: 120,
                          height: 120,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(color: const Color(0xFFD4AF37), width: 3),
                            color: Colors.white,
                            boxShadow: const [
                              BoxShadow(color: Colors.black45, blurRadius: 10),
                            ],
                          ),
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.asset('assets/images/gold_seal.png', fit: BoxFit.contain),
                          ),
                        ),
                      ),

                      // Main Content
                      Positioned.fill(
                        child: Padding(
                          padding: const EdgeInsets.only(left: 180, right: 40, top: 40, bottom: 40),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.center,
                            children: [
                              // Header
                              Image.asset('assets/images/Logo.png', width: 40, height: 40),
                              const SizedBox(height: 8),
                              const Text(
                                'أكاديمية كاليغرو',
                                style: TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 18,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const Text(
                                'CALLIGRO ACADEMY',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 8,
                                  letterSpacing: 4,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              
                              const SizedBox(height: 24),
                              
                              const Text(
                                'Certificate of Completion',
                                style: TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 32,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 16),
                              
                              const Text(
                                'PRESENTED TO',
                                style: TextStyle(
                                  color: Colors.black54,
                                  fontSize: 10,
                                  letterSpacing: 2,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),

                              const SizedBox(height: 8),
                              
                              // Name Box
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 8),
                                decoration: BoxDecoration(
                                  border: Border.all(color: const Color(0xFFD4AF37).withOpacity(0.5)),
                                  borderRadius: BorderRadius.circular(8),
                                  color: const Color(0xFFD4AF37).withOpacity(0.05),
                                ),
                                child: Text(
                                  widget.certificate.studentName,
                                  style: const TextStyle(
                                    color: Color(0xFFD4AF37),
                                    fontSize: 36,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),

                              const SizedBox(height: 24),
                              
                              const Text(
                                'For successfully completing the course',
                                style: TextStyle(color: Colors.black87, fontSize: 14),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                widget.certificate.courseName,
                                style: const TextStyle(
                                  color: Color(0xFF111111),
                                  fontSize: 20,
                                  fontWeight: FontWeight.bold,
                                ),
                                textAlign: TextAlign.center,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                              
                              const Spacer(),
                              
                              // Signatures
                              Row(
                                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                                children: [
                                  _buildSignatureBlock('Date', dateStr, null),
                                  _buildSignatureBlock('Instructor', widget.certificate.teacherId, null),
                                  _buildSignatureBlock('CEO', 'Yazan Qattous', 'assets/images/yazan_signature.png'),
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
            ),
          ),
          
          // Back Button
          Positioned(
            top: 16,
            left: 16,
            child: SafeArea(
              child: IconButton(
                icon: const Icon(Icons.close, color: Colors.white, size: 30),
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSignatureBlock(String title, String text, String? imagePath) {
    return Column(
      children: [
        Container(
          width: 100,
          decoration: const BoxDecoration(
            border: Border(bottom: BorderSide(color: Colors.black26, width: 2)),
          ),
          padding: const EdgeInsets.only(bottom: 4),
          child: Text(
            title,
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.black54, fontSize: 10, fontWeight: FontWeight.bold),
          ),
        ),
        const SizedBox(height: 8),
        SizedBox(
          height: 40,
          child: Center(
            child: imagePath != null
                ? Image.asset(imagePath, fit: BoxFit.contain, colorBlendMode: BlendMode.multiply)
                : Text(
                    text,
                    style: const TextStyle(color: Colors.black, fontSize: 14, fontStyle: FontStyle.italic),
                    textAlign: TextAlign.center,
                    maxLines: 1,
                  ),
          ),
        ),
      ],
    );
  }
}
