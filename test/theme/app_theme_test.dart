import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:absensi_siswa/theme/app_theme.dart';

void main() {
  group('AppColors', () {
    test('memiliki nilai warna yang valid', () {
      expect(AppColors.primary, equals(const Color(0xFF26A269)));
      expect(AppColors.primaryGlow, equals(const Color(0xFF3DD68C)));
      expect(AppColors.accent, equals(const Color(0xFF1AA3E6)));
      expect(AppColors.background, equals(const Color(0xFFF5F8FB)));
      expect(AppColors.card, equals(const Color(0xFFFFFFFF)));
      expect(AppColors.foreground, equals(const Color(0xFF1E2937)));
      expect(AppColors.muted, equals(const Color(0xFF6B7B8C)));
      expect(AppColors.success, equals(const Color(0xFF22C55E)));
      expect(AppColors.warning, equals(const Color(0xFFF59E0B)));
      expect(AppColors.whatsapp, equals(const Color(0xFF25D366)));
      expect(AppColors.border, equals(const Color(0xFFDDE3EB)));
    });

    test('gradientMain memiliki dua warna', () {
      expect(AppColors.gradientMain.colors.length, equals(2));
      expect(AppColors.gradientMain.colors[0], equals(AppColors.primary));
      expect(AppColors.gradientMain.colors[1], equals(AppColors.accent));
    });
  });
}
