import 'package:flutter_test/flutter_test.dart';
import 'package:vyra/models/models.dart';
import 'package:vyra/theme.dart';

void main() {
  group('VYRA Kinetic Obsidian Theme Tests', () {
    test('verifies core brand color palette', () {
      expect(VColor.bg.toARGB32(), equals(0xFF0F131D));
      expect(VColor.surface.toARGB32(), equals(0xFF171C25));
      expect(VColor.surfaceRaised.toARGB32(), equals(0xFF1B2029));
      expect(VColor.accent.toARGB32(), equals(0xFF00D2FF));
      expect(VColor.accentGreen.toARGB32(), equals(0xFF34FF8C));
      expect(VColor.accentOrange.toARGB32(), equals(0xFFFF7700));
    });
  });

  group('VYRA Data Model Serialization Tests', () {
    test('BarcodeProduct model parses JSON correctly', () {
      final json = {
        'barcode': '8901234567890',
        'name': 'Greek Protein Yogurt',
        'brand': 'VYRA Nutrition',
        'calories': 130,
        'proteinG': 15.0,
        'carbsG': 6.0,
        'fatG': 0.0,
        'sodiumMg': 45,
        'fiberG': 0.0,
        'novaScore': 1,
      };

      final product = BarcodeProduct.fromJson(json);
      expect(product.barcode, equals('8901234567890'));
      expect(product.name, equals('Greek Protein Yogurt'));
      expect(product.proteinG, equals(15.0));
      expect(product.novaScore, equals(1));
    });

    test('WaterReminderConfig model default config instantiates correctly', () {
      final config = WaterReminderConfig.defaultConfig();
      expect(config.targetMl, equals(3200));
      expect(config.intervalMinutes, equals(60));
      expect(config.startTime, equals('07:00'));
      expect(config.endTime, equals('22:00'));
      expect(config.soundEnabled, isTrue);
    });

    test('FollowUser model parses JSON correctly', () {
      final json = {
        'id': 'u-123',
        'handle': 'runner_alex',
        'name': 'Alex Vance',
      };

      final user = FollowUser.fromJson(json);
      expect(user.id, equals('u-123'));
      expect(user.handle, equals('runner_alex'));
      expect(user.name, equals('Alex Vance'));
    });
  });
}
