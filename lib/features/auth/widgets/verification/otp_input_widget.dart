import 'package:flutter/material.dart';


//this page handle the style for the otp input fields
class OtpInputWidget extends StatelessWidget {
  final List<TextEditingController> controllers;
  final String? errorText;

  const OtpInputWidget({
    super.key,
    required this.controllers,
    this.errorText,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 330,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: List.generate(controllers.length, (i) {
          return Container(
            width: 45,
            height: 55,
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.25),
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.3),
                  blurRadius: 6,
                  offset: const Offset(2, 3),
                ),
              ],
            ),
            child: TextField(
              controller: controllers[i],
              maxLength: 1,
              textAlign: TextAlign.center,
              keyboardType: TextInputType.number,
              style: const TextStyle(color: Colors.white, fontSize: 20),
              decoration: InputDecoration(
                counterText: "",
                border: InputBorder.none,
                errorText: i == 0 ? errorText : null, // show error only once
              ),
              onChanged: (val) {
                if (val.isNotEmpty && i < controllers.length - 1) {
                  FocusScope.of(context).nextFocus();
                } else if (val.isEmpty && i > 0) {
                  FocusScope.of(context).previousFocus();
                }
              },
            ),
          );
        }),
      ),
    );
  }
}
