import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:golden_toolkit/golden_toolkit.dart';

// We import the widget we want to visually test
// Simulating the "Sold Out" button UI for golden pixel matching.

class SoldOutButton extends StatelessWidget {
  const SoldOutButton({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        backgroundColor: Colors.grey, // Disabled color
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(12),
        ),
      ),
      onPressed: null, // Disabled
      child: const Text(
        'SOLD OUT',
        style: TextStyle(
          color: Colors.white70,
          fontWeight: FontWeight.bold,
          fontSize: 16,
        ),
      ),
    );
  }
}

void main() {
  // Ensure the Golden Toolkit is initialized
  setUpAll(() async {
    await loadAppFonts();
  });

  group('Phase 10: Golden Tests (Visual Pixel Matching)', () {
    testGoldens('Sold Out button should match exact pixel layout', (tester) async {
      // 1. Build the UI Scenario
      final builder = DeviceBuilder()
        ..overrideDevicesForAllScenarios(devices: [
          Device.phone,
          Device.iphone11,
          Device.tabletLandscape,
        ])
        ..addScenario(
          widget: const SoldOutButton(),
          name: 'sold_out_button_disabled_state',
        );

      // 2. Pump the widget to the virtual screen
      await tester.pumpDeviceBuilder(builder);

      // 3. Take a snapshot and compare pixel-by-pixel against the master image
      // If someone accidentally changes the color or padding, this will fail.
      await screenMatchesGolden(tester, 'sold_out_button_layout');
    });
  });
}
