import 'package:flutter/material.dart';
import 'package:pin_code_fields/pin_code_fields.dart';

// This widget now uses the pin_code_fields plugin but keeps your custom style
class OtpInputWidget extends StatelessWidget {
  final TextEditingController
  controller; // Plugin uses one controller, not a list
  final String? errorText;
  final Function(String)? onChanged;
  final Function(String)? onCompleted;

  const OtpInputWidget({
    super.key,
    required this.controller,
    this.errorText,
    this.onChanged,
    this.onCompleted,
  });

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          SizedBox(
            width: 330, // Matching your container width
            child: Directionality(
              textDirection: TextDirection.ltr,
              child: PinCodeTextField(
                appContext: context,
                length: 6,
                controller: controller,
                keyboardType: TextInputType.number,
                animationType: AnimationType.fade,
                cursorColor: Colors.white,
                textStyle: const TextStyle(color: Colors.white, fontSize: 20),
            
                // Styling to match your BoxDecoration
                pinTheme: PinTheme(
                  shape: PinCodeFieldShape.box,
                  borderRadius: BorderRadius.circular(10),
                  fieldHeight: 55, // Matching your height
                  fieldWidth: 45, // Matching your width
                  // Colors matching: Colors.black.withOpacity(0.25)
                  activeFillColor: Colors.black.withOpacity(0.25),
                  inactiveFillColor: Colors.black.withOpacity(0.25),
                  selectedFillColor: Colors.black.withOpacity(0.4),
            
                  // Borders (Set to transparent to let the shadow/box define the look)
                  activeColor: Colors.transparent,
                  inactiveColor: Colors.transparent,
                  selectedColor: Colors.white.withOpacity(0.5),
                ),
            
                // Applying your specific BoxShadow
                boxShadows: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 6,
                    offset: const Offset(2, 3),
                  ),
                ],
            
                enableActiveFill: true,
                autoDisposeControllers: false, // Important for state management
                onChanged: onChanged ?? (value) {},
                onCompleted: onCompleted,
              ),
            ),
          ),

          // Show error text below if provided
          if (errorText != null)
            Padding(
              padding: const EdgeInsets.only(top: 8.0),
              child: Text(
                errorText!,
                style: const TextStyle(color: Colors.red, fontSize: 12),
              ),
            ),
        ],
      ),
    );
  }
}
