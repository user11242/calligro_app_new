import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

/// The app's theme. Every page is dark, so the page background is black.
class AppTheme {
  AppTheme._();

  /// What shows behind a page while it animates in or out.
  static const Color transitionBackground = Colors.black;

  static ThemeData build() => ThemeData(
        scaffoldBackgroundColor: Colors.black,
        canvasColor: Colors.black,
        // Android's page animation fills the screen with a background colour while it runs.
        // Unset, that is the theme's light "surface" (almost white): a white flash between
        // two dark pages. Same animation (and predictive back), painted black.
        pageTransitionsTheme: const PageTransitionsTheme(
          builders: {
            TargetPlatform.android: PredictiveBackPageTransitionsBuilder(fallbackColor: transitionBackground),
            TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
            TargetPlatform.macOS: CupertinoPageTransitionsBuilder(),
          },
        ),
      );
}
