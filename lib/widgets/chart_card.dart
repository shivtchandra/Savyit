// lib/widgets/chart_card.dart
import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ChartCard extends StatelessWidget {
  final String title;
  final String? subtitle;
  final Widget child;
  final double height;
  final Widget? action;

  const ChartCard({
    super.key,
    required this.title,
    this.subtitle,
    required this.child,
    this.height = 220,
    this.action,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: AppDecorations.card,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: EdgeInsets.fromLTRB(
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.xl,
              AppSpacing.md,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (subtitle != null) ...[
                        SizedBox(height: AppSpacing.xs),
                        Text(
                          subtitle!,
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      ],
                    ],
                  ),
                ),
                if (action != null) action!,
              ],
            ),
          ),
          SizedBox(
            height: height,
            child: Padding(
              padding: EdgeInsets.fromLTRB(
                AppSpacing.lg,
                0,
                AppSpacing.lg,
                AppSpacing.lg,
              ),
              child: child,
            ),
          ),
        ],
      ),
    );
  }
}
