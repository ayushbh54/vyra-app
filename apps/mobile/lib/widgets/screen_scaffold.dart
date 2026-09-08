import 'package:flutter/material.dart';

import '../theme.dart';

/// Most VYRA screens have no Scaffold of their own — the bottom-nav shell
/// supplies it. This wraps one in a Scaffold + AppBar for the few places a
/// screen needs to be pushed on top of the shell instead of living in it.
Future<T?> pushScreen<T>(BuildContext context, String title, Widget screen) {
  return Navigator.of(context).push<T>(
    MaterialPageRoute(
      builder: (_) => Scaffold(
        backgroundColor: VColor.bg,
        appBar: AppBar(title: Text(title)),
        body: screen,
      ),
    ),
  );
}
