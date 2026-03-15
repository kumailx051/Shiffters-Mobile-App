import 'package:flutter/material.dart';

class NavigationUtils {
  // Smooth fade transition for splash screen
  static Route<T> fadeTransition<T extends Object?>(Widget page) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: child,
        );
      },
      transitionDuration: const Duration(milliseconds: 600),
    );
  }

  // Slide transition for intuitive navigation feel (onboarding, main app)
  static Route<T> slideTransition<T extends Object?>(
    Widget page, {
    Offset begin = const Offset(1.0, 0.0),
    Curve curve = Curves.easeOutCubic,
    int durationMs = 500,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return SlideTransition(
          position: Tween<Offset>(
            begin: begin,
            end: Offset.zero,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: child,
        );
      },
      transitionDuration: Duration(milliseconds: durationMs),
    );
  }

  // Scale transition for login/register to main app
  static Route<T> scaleTransition<T extends Object?>(
    Widget page, {
    double beginScale = 0.8,
    Curve curve = Curves.easeOutCubic,
    int durationMs = 600,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return ScaleTransition(
          scale: Tween<double>(
            begin: beginScale,
            end: 1.0,
          ).animate(CurvedAnimation(
            parent: animation,
            curve: curve,
          )),
          child: FadeTransition(
            opacity: animation,
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: durationMs),
    );
  }

  // Combined slide and fade for smooth navigation
  static Route<T> slideAndFadeTransition<T extends Object?>(
    Widget page, {
    Offset begin = const Offset(1.0, 0.0),
    Curve curve = Curves.easeOutCubic,
    int durationMs = 500,
  }) {
    return PageRouteBuilder<T>(
      pageBuilder: (context, animation, secondaryAnimation) => page,
      transitionsBuilder: (context, animation, secondaryAnimation, child) {
        return FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(
              begin: begin,
              end: Offset.zero,
            ).animate(CurvedAnimation(
              parent: animation,
              curve: curve,
            )),
            child: child,
          ),
        );
      },
      transitionDuration: Duration(milliseconds: durationMs),
    );
  }

  // Navigation helper methods
  static void navigateWithFade(BuildContext context, Widget page) {
    Navigator.push(context, fadeTransition(page));
  }

  static void navigateWithSlide(BuildContext context, Widget page, {Offset? begin}) {
    Navigator.push(context, slideTransition(page, begin: begin ?? const Offset(1.0, 0.0)));
  }

  static void navigateWithScale(BuildContext context, Widget page) {
    Navigator.push(context, scaleTransition(page));
  }

  static void replaceWithFade(BuildContext context, Widget page) {
    Navigator.pushReplacement(context, fadeTransition(page));
  }

  static void replaceWithSlide(BuildContext context, Widget page, {Offset? begin}) {
    Navigator.pushReplacement(context, slideTransition(page, begin: begin ?? const Offset(1.0, 0.0)));
  }

  static void replaceWithScale(BuildContext context, Widget page) {
    Navigator.pushReplacement(context, scaleTransition(page));
  }

  // Clear stack and navigate
  static void clearStackAndNavigateWithFade(BuildContext context, Widget page) {
    Navigator.pushAndRemoveUntil(context, fadeTransition(page), (route) => false);
  }

  static void clearStackAndNavigateWithSlide(BuildContext context, Widget page, {Offset? begin}) {
    Navigator.pushAndRemoveUntil(context, slideTransition(page, begin: begin ?? const Offset(1.0, 0.0)), (route) => false);
  }

  static void clearStackAndNavigateWithScale(BuildContext context, Widget page) {
    Navigator.pushAndRemoveUntil(context, scaleTransition(page), (route) => false);
  }
}
