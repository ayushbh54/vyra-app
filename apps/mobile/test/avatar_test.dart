import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:vyra/services/avatar_customization_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  group('AvatarCustomizationService & 3D Avatar Tests', () {
    test('AvatarCustomizationService initializes with default profile', () async {
      final service = AvatarCustomizationService.instance;
      await service.init();

      expect(service.profile.userName, equals('Athlete'));
      expect(service.profile.bodyType, equals('athletic'));
      expect(service.profile.sportPose, isNotEmpty);
    });

    test('AvatarFaceProfile copyWith updates properties accurately', () {
      const profile = AvatarFaceProfile(
        userName: 'Alex',
        avatarGender: 'male',
        bodyType: 'lean',
        sportPose: 'running',
      );

      final updated = profile.copyWith(
        userName: 'Alex Vance',
        bodyType: 'muscular',
        sportPose: 'boxing',
      );

      expect(updated.userName, equals('Alex Vance'));
      expect(updated.avatarGender, equals('male'));
      expect(updated.bodyType, equals('muscular'));
      expect(updated.sportPose, equals('boxing'));
    });

    test('setActiveExercisePose updates current pose and notifies listeners', () async {
      final service = AvatarCustomizationService.instance;
      await service.init();

      var notified = false;
      void listener() {
        notified = true;
      }

      service.addListener(listener);
      await service.setActiveExercisePose('running');

      expect(notified, isTrue);
      expect(service.profile.sportPose, equals('running'));
      expect(service.currentRpmExercisePose, equals('run'));

      service.removeListener(listener);
    });
  });
}
