import 'package:flutter/material.dart';
import 'rpm_avatar_viewer.dart';

/// Direct entry to 3D Avatar Studio.
/// Always shows the RPM 3D viewer — default male/female avatar loads
/// automatically if user hasn't created a custom one yet.
class AvatarStudioScreen extends StatelessWidget {
  const AvatarStudioScreen({super.key});

  @override
  Widget build(BuildContext context) => const RpmAvatarViewerScreen();
}
