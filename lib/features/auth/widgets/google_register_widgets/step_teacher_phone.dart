import 'package:flutter/material.dart';
import 'package:intl_phone_field/intl_phone_field.dart';
import 'package:phone_number/phone_number.dart';
import 'package:device_region/device_region.dart'; // 🔹 Import the device_region package

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
  String _initialCountryCode = "US"; // 🔹 Default to a common country

  @override
  void initState() {
    super.initState();
    _getInitialCountryCode(); // 🔹 Get the country code when widget is initialized
  }

  // 🔹 Get the SIM country code using DeviceRegion package
  Future<void> _getInitialCountryCode() async {
    try {
      final String? countryCode = await DeviceRegion.getSIMCountryCode();
      if (countryCode != null) {
        setState(() {
          _initialCountryCode = countryCode.toUpperCase(); // Set the country code based on SIM
        });
      }
    } catch (e) {
      debugPrint("Error getting country code: $e");
    }
  }

  // 🔹 Validate the phone number and format it properly
  Future<void> _validateAndFormatPhone(String number, String isoCode) async {
    try {
      final parsed = await _phoneNumberUtil.parse(number, regionCode: isoCode);

      if (parsed.e164!.isNotEmpty) {
        setState(() => _errorText = null);
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
          initialCountryCode: _initialCountryCode, // 🔹 Use the fetched country code
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
            _validateAndFormatPhone(phone.number, phone.countryISOCode);
            widget.controller.text = phone.completeNumber;
          },
        ),
      ],
    );
  }
}
