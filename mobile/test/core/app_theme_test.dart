import 'package:buddywize/core/app_theme.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('BuddyWize exposes the approved semantic palette', () {
    final theme = BuddyTheme.light;
    final status = theme.extension<BuddyStatusColors>()!;

    expect(theme.colorScheme.primary, const Color(0xFFFF6B35));
    expect(theme.colorScheme.secondary, const Color(0xFF0066FF));
    expect(theme.colorScheme.onSurface, const Color(0xFF0A0A0A));
    expect(status.success, const Color(0xFF2ECC71));
    expect(status.warning, const Color(0xFFF5A623));
    expect(theme.colorScheme.error, const Color(0xFFE74C3C));
  });
}
