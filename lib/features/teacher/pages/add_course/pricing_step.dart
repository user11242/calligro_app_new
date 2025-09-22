import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/auth/widgets/auth_text_field.dart';

class CoursePricePage extends StatefulWidget {
  final TextEditingController priceController;
  final Function onNext;
  final Function onBack;

  const CoursePricePage({
    Key? key,
    required this.priceController,
    required this.onNext,
    required this.onBack,
  }) : super(key: key);

  @override
  State<CoursePricePage> createState() => _CoursePricePageState();
}

class _CoursePricePageState extends State<CoursePricePage> {
  // Use a state variable to control when to show the dialog
  bool _isFirstTap = true;

  // Method to show a snack bar message
  void _showMessage(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  // Validation method to check if the price field is empty
  void _validateAndProceed() {
    if (widget.priceController.text.isEmpty) {
      _showMessage(context, 'Please enter a course price.');
    } else {
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
              const Icon(
                Icons.info_outline,
                color: Colors.white,
                size: 50,
              ),
              const SizedBox(height: 10),
              RichText(
                textAlign: TextAlign.center,
                text: TextSpan(
                  style: const TextStyle(color: Colors.white, fontSize: 16),
                  children: [
                    const TextSpan(
                      text: "Note: The price is listed in US dollars. Please note that the final amount you receive may differ. For more details, kindly refer to the ",
                    ),
                    WidgetSpan(
                      child: GestureDetector(
                        onTap: () {
                          // In a real app, this would use a package like `url_launcher`
                          // to open a URL. Here, we'll simulate it with a message.
                          Navigator.of(context).pop(); // Close the current dialog first
                          _showTermsAndConditionsMessage(context);
                        },
                        child: const Text(
                          "terms and conditions",
                          style: TextStyle(
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
              child: const Text(
                'Got It',
                style: TextStyle(color: Colors.white),
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

  void _showTermsAndConditionsMessage(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          content: const Text(
            "This would link to the terms and conditions page in a real application.",
            style: TextStyle(color: Colors.white, fontSize: 16),
            textAlign: TextAlign.center,
          ),
          actions: <Widget>[
            TextButton(
              child: const Text(
                'Close',
                style: TextStyle(color: Colors.white),
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SingleChildScrollView(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 24.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Course Price Input
              AuthTextField(
                controller: widget.priceController,
                hint: 'Enter Course Price',
                icon: Icons.attach_money,
                keyboardType: TextInputType.number,
                // The field is now editable by default,
                // but we only show the dialog on the first tap.
                onTap: () {
                  if (_isFirstTap) {
                    _showPriceInfoDialog(context);
                    setState(() {
                      _isFirstTap = false;
                    });
                  }
                },
              ),
              const SizedBox(height: 24),

              // Navigation buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => widget.onBack(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_back, color: Colors.white),
                      label: const Text("Back", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: () => _validateAndProceed(),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.textColor,
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      icon: const Icon(Icons.arrow_forward, color: Colors.white),
                      label: const Text("Next", style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
