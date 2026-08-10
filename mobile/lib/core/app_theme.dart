import 'package:flutter/material.dart';

/// BuddyWize's product palette. Feature code should use the active
/// [ColorScheme] or [BuddyStatusColors] instead of raw Material swatches.
abstract final class AppColors {
  static const primary = Color(0xFFFF6B35);
  static const secondary = Color(0xFF0066FF);
  static const ink = Color(0xFF0A0A0A);
  static const success = Color(0xFF2ECC71);
  static const warning = Color(0xFFF5A623);
  static const error = Color(0xFFE74C3C);

  static const canvas = Color(0xFFFCFCFC);
  static const surface = Color(0xFFFFFFFF);
  static const muted = Color(0xFF667085);
  static const outline = Color(0xFFE4E7EC);
}

@immutable
class BuddyStatusColors extends ThemeExtension<BuddyStatusColors> {
  const BuddyStatusColors({
    required this.success,
    required this.successContainer,
    required this.onSuccessContainer,
    required this.warning,
    required this.warningContainer,
    required this.onWarningContainer,
    required this.recording,
  });

  final Color success;
  final Color successContainer;
  final Color onSuccessContainer;
  final Color warning;
  final Color warningContainer;
  final Color onWarningContainer;
  final Color recording;

  static const light = BuddyStatusColors(
    success: AppColors.success,
    successContainer: Color(0xFFDDF7E8),
    onSuccessContainer: Color(0xFF126B36),
    warning: AppColors.warning,
    warningContainer: Color(0xFFFFF3D6),
    onWarningContainer: Color(0xFF8A5700),
    recording: AppColors.error,
  );

  @override
  BuddyStatusColors copyWith({
    Color? success,
    Color? successContainer,
    Color? onSuccessContainer,
    Color? warning,
    Color? warningContainer,
    Color? onWarningContainer,
    Color? recording,
  }) {
    return BuddyStatusColors(
      success: success ?? this.success,
      successContainer: successContainer ?? this.successContainer,
      onSuccessContainer: onSuccessContainer ?? this.onSuccessContainer,
      warning: warning ?? this.warning,
      warningContainer: warningContainer ?? this.warningContainer,
      onWarningContainer: onWarningContainer ?? this.onWarningContainer,
      recording: recording ?? this.recording,
    );
  }

  @override
  BuddyStatusColors lerp(BuddyStatusColors? other, double t) {
    if (other == null) return this;
    return BuddyStatusColors(
      success: Color.lerp(success, other.success, t)!,
      successContainer: Color.lerp(
        successContainer,
        other.successContainer,
        t,
      )!,
      onSuccessContainer: Color.lerp(
        onSuccessContainer,
        other.onSuccessContainer,
        t,
      )!,
      warning: Color.lerp(warning, other.warning, t)!,
      warningContainer: Color.lerp(
        warningContainer,
        other.warningContainer,
        t,
      )!,
      onWarningContainer: Color.lerp(
        onWarningContainer,
        other.onWarningContainer,
        t,
      )!,
      recording: Color.lerp(recording, other.recording, t)!,
    );
  }
}

extension BuddyThemeX on BuildContext {
  BuddyStatusColors get statusColors =>
      Theme.of(this).extension<BuddyStatusColors>()!;
}

abstract final class BuddyTheme {
  static ThemeData get light {
    final scheme =
        ColorScheme.fromSeed(
          seedColor: AppColors.primary,
          brightness: Brightness.light,
          surface: AppColors.surface,
        ).copyWith(
          primary: AppColors.primary,
          onPrimary: Colors.white,
          primaryContainer: const Color(0xFFFFE5DC),
          onPrimaryContainer: AppColors.ink,
          secondary: AppColors.secondary,
          onSecondary: Colors.white,
          secondaryContainer: const Color(0xFFE5F0FF),
          onSecondaryContainer: const Color(0xFF003D99),
          error: AppColors.error,
          onError: Colors.white,
          errorContainer: const Color(0xFFFDE8E5),
          onErrorContainer: const Color(0xFF8B1E14),
          surface: AppColors.surface,
          onSurface: AppColors.ink,
          outline: AppColors.outline,
          outlineVariant: const Color(0xFFF0F1F3),
        );

    final base = ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.canvas,
      fontFamily: '.SF Pro Text',
      extensions: const [BuddyStatusColors.light],
    );

    final rounded = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(12),
    );

    return base.copyWith(
      textTheme: base.textTheme.apply(
        bodyColor: AppColors.ink,
        displayColor: AppColors.ink,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.canvas,
        foregroundColor: AppColors.ink,
        centerTitle: false,
        elevation: 0,
        scrolledUnderElevation: 0,
        titleTextStyle: TextStyle(
          color: AppColors.ink,
          fontSize: 22,
          fontWeight: FontWeight.w700,
        ),
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: const BorderSide(color: AppColors.outline),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.outline),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.secondary, width: 1.5),
        ),
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          foregroundColor: Colors.white,
          minimumSize: const Size(48, 50),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w700),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: AppColors.secondary,
          minimumSize: const Size(48, 48),
          side: const BorderSide(color: AppColors.secondary),
          shape: rounded,
          textStyle: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(foregroundColor: AppColors.secondary),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        shape: CircleBorder(),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: AppColors.surface,
        modalBackgroundColor: AppColors.surface,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surface,
        indicatorColor: Colors.transparent,
        height: 70,
        labelTextStyle: WidgetStateProperty.resolveWith((states) {
          return TextStyle(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
            fontSize: 11,
            fontWeight: states.contains(WidgetState.selected)
                ? FontWeight.w700
                : FontWeight.w500,
          );
        }),
        iconTheme: WidgetStateProperty.resolveWith((states) {
          return IconThemeData(
            color: states.contains(WidgetState.selected)
                ? AppColors.primary
                : AppColors.muted,
          );
        }),
      ),
      dividerTheme: const DividerThemeData(color: AppColors.outline),
    );
  }
}
