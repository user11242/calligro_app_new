import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_number/phone_number.dart';

class StepTeacherPhone extends StatefulWidget {
  final TextEditingController controller;
  final void Function(String fullNumber)? onValidNumber;

  const StepTeacherPhone({
    super.key,
    required this.controller,
    this.onValidNumber,
  });

  @override
  State<StepTeacherPhone> createState() => _StepTeacherPhoneState();
}

class _StepTeacherPhoneState extends State<StepTeacherPhone> {
  final PhoneNumberUtil _phoneNumberUtil = PhoneNumberUtil();
  String? _errorText;

  Future<void> _validatePhone(String number, String isoCode) async {
    try {
      final parsed = await _phoneNumberUtil.parse(number, regionCode: isoCode);

      if (parsed.e164 != null && parsed.e164!.isNotEmpty) {
        // ✅ valid number
        setState(() => _errorText = null);
        widget.controller.text = parsed.e164!; // keep E.164 in controller
        widget.onValidNumber?.call(parsed.e164!);
      } else {
        setState(() => _errorText = "Invalid phone number");
      }
    } catch (_) {
      setState(() => _errorText = "Invalid phone number");
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Text(
          "Your Phone Number",
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
        ),
        const SizedBox(height: 16),

        IntlPhoneField(
          controller: widget.controller,
          initialCountryCode: "JO", // ✅ change to your main country
          style: const TextStyle(color: Colors.white),
          dropdownTextStyle: const TextStyle(color: Colors.white),
          decoration: InputDecoration(
            hintText: "Phone Number",
            hintStyle: const TextStyle(color: Colors.white54),
            filled: true,
            fillColor: Colors.white.withOpacity(0.1),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            errorText: _errorText,
          ),
          onChanged: (phone) {
            _validatePhone(phone.number, phone.countryISOCode);
          },
        ),
      ],
    );
  }
}