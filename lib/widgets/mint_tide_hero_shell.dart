import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

/// Padded shell for the overview balance hero.
///
/// Previously drew a full-bleed lime “tide” wave above the card; that band
/// fought the page gradient and greeting card. The hero frame + canvas
/// gradient now carry depth; this widget only handles width + repaint bounds.
class MintTideHeroShell extends StatelessWidget {
  final Widget child;
  final GlobalKey? repaintBoundaryKey;

  const MintTideHeroShell({
    super.key,
    required this.child,
    this.repaintBoundaryKey,
  });

  @override
  Widget build(BuildContext context) {
    return RepaintBoundary(
      key: repaintBoundaryKey,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.screenHorizontal,
        ),
        child: child,
      ),
    );
  }
}
