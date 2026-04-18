// lib/widgets/kpi_card.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import '../theme/app_theme.dart';

class KpiCard extends StatelessWidget {
  final String label;
  final String value;
  final dynamic icon;
  final Color valueColor;
  final bool useGradient;

  const KpiCard({
    super.key,
    required this.label,
    required this.value,
    required this.icon,
    this.valueColor = const Color(0xFF141414), // Use a hardcoded default or handle in build
    this.useGradient = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(28),
        border: Border.all(color: AppColors.border, width: 1.2),
        boxShadow: [
          BoxShadow(color: AppColors.textMain.withValues(alpha: 0.03), blurRadius: 10, offset: const Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: valueColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: HugeIcon(icon: icon, color: valueColor, size: 18),
          ),
          const Spacer(),
          Text(label, style: TextStyle(fontSize: 10, color: AppColors.textMuted, fontWeight: FontWeight.w900, letterSpacing: 0.5)),
          const SizedBox(height: 2),
          Text(value, style: TextStyle(fontSize: 19, fontWeight: FontWeight.w900, color: valueColor)),
        ],
      ),
    );
  }

}
