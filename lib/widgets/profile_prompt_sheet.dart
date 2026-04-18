// lib/widgets/profile_prompt_sheet.dart
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../screens/financial_plan_screen.dart';

/// Bottom sheet that prompts existing users to complete their profile
/// with occupation, income, age, and goals.
class ProfilePromptSheet extends StatefulWidget {
  final VoidCallback onComplete;
  const ProfilePromptSheet({super.key, required this.onComplete});

  @override
  State<ProfilePromptSheet> createState() => _ProfilePromptSheetState();
}

class _ProfilePromptSheetState extends State<ProfilePromptSheet> {
  int _step = 0; // 0 = occupation, 1 = income, 2 = age, 3 = goals
  String _occupation = '';
  String _income = '';
  String _age = '';
  final List<String> _goals = [];

  void _next() {
    if (_step < 3) {
      setState(() => _step++);
    } else {
      _save();
    }
  }

  void _save() async {
    if (_occupation.isNotEmpty) await StorageService.saveOccupation(_occupation);
    if (_income.isNotEmpty) await StorageService.saveMonthlyIncome(_income);
    if (_age.isNotEmpty) await StorageService.saveAgeRange(_age);
    if (_goals.isNotEmpty) await StorageService.saveFinancialGoals(_goals);
    await StorageService.setProfileComplete(true);
    widget.onComplete();
    // Navigate to financial plan
    if (mounted) {
      Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const FinancialPlanScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(24, 8, 24, 32),
      decoration: BoxDecoration(
        color: AppColors.sheetChrome,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          const SizedBox(height: 20),
          // Progress
          Row(
            children: List.generate(4, (i) => Expanded(
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 3),
                height: 3,
                decoration: BoxDecoration(
                  color: i <= _step ? AppColors.primary : AppColors.border,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            )),
          ),
          const SizedBox(height: 24),
          // Step content
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: _buildStepContent(),
          ),
        ],
      ),
    );
  }

  Widget _buildStepContent() {
    switch (_step) {
      case 0:
        return _buildChipSelection(
          key: 'occ',
          title: 'What do you do?',
          subtitle: 'Helps us personalize insights',
          options: ['Student', 'Salaried', 'Freelancer', 'Business Owner', 'Retired', 'Other'],
          selected: _occupation,
          onSelect: (v) => setState(() => _occupation = v),
        );
      case 1:
        return _buildChipSelection(
          key: 'inc',
          title: 'Monthly income?',
          subtitle: 'We\'ll gauge your spending habits',
          options: ['< ₹15K', '₹15K – 30K', '₹30K – 50K', '₹50K – 1L', '₹1L – 3L', '₹3L+'],
          selected: _income,
          onSelect: (v) => setState(() => _income = v),
        );
      case 2:
        return _buildChipSelection(
          key: 'age',
          title: 'Your age range?',
          subtitle: 'Age-appropriate advice is better',
          options: ['18 – 22', '23 – 27', '28 – 35', '36 – 45', '46 – 55', '55+'],
          selected: _age,
          onSelect: (v) => setState(() => _age = v),
        );
      case 3:
        return _buildGoalsSelection();
      default:
        return const SizedBox();
    }
  }

  Widget _buildChipSelection({
    required String key,
    required String title,
    required String subtitle,
    required List<String> options,
    required String selected,
    required Function(String) onSelect,
  }) {
    final isValid = selected.isNotEmpty;
    return Column(
      key: ValueKey(key),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: key == 'occ'
                  ? HugeIcons.strokeRoundedBriefcase01
                  : key == 'inc'
                      ? HugeIcons.strokeRoundedMoney03
                      : HugeIcons.strokeRoundedCalendar03,
              color: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppColors.iconOnLight,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text(title, style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain)),
          ],
        ),
        const SizedBox(height: 4),
        Text(subtitle, style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: options.map((o) {
            final isSel = selected == o;
            return GestureDetector(
              onTap: () => onSelect(o),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSel ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: Text(
                  o,
                  style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    color: isSel
                        ? AppColors.labelOnSolid(AppColors.primary)
                        : AppColors.textMain,
                  ),
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isValid ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.labelOnSolid(AppColors.primary),
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Text('Continue', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
          ),
        ),
      ],
    );
  }

  Widget _buildGoalsSelection() {
    const goals = ['Save More', 'Pay Off Debt', 'Emergency Fund', 'Invest Wisely', 'Track Everything', 'Live Freely'];
    final isValid = _goals.isNotEmpty;
    return Column(
      key: const ValueKey('goals'),
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            HugeIcon(
              icon: HugeIcons.strokeRoundedTarget02,
              color: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppColors.iconOnLight,
              size: 24,
            ),
            const SizedBox(width: 12),
            Text('Money goals?', style: GoogleFonts.inter(fontSize: 20, fontWeight: FontWeight.w800, color: AppColors.textMain)),
          ],
        ),
        const SizedBox(height: 4),
        Text('Pick up to 3', style: GoogleFonts.inter(fontSize: 13, color: AppColors.textMuted)),
        const SizedBox(height: 20),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: goals.map((g) {
            final isSel = _goals.contains(g);
            return GestureDetector(
              onTap: () {
                setState(() {
                  if (isSel) {
                    _goals.remove(g);
                  } else if (_goals.length < 3) {
                    _goals.add(g);
                  }
                });
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 200),
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: isSel ? AppColors.primary : AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: isSel ? AppColors.primary : AppColors.border, width: 1.5),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      g,
                      style: GoogleFonts.inter(
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                        color: isSel
                            ? AppColors.labelOnSolid(AppColors.primary)
                            : AppColors.textMain,
                      ),
                    ),
                    if (isSel) ...[
                      const SizedBox(width: 4),
                      Icon(
                        Icons.check_circle,
                        color: AppColors.labelOnSolid(AppColors.primary),
                        size: 16,
                      ),
                    ],
                  ],
                ),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 24),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(
            onPressed: isValid ? _next : null,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: AppColors.labelOnSolid(AppColors.primary),
              disabledBackgroundColor: AppColors.border,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('Finish', style: GoogleFonts.inter(fontWeight: FontWeight.w800)),
                const SizedBox(width: 8),
                HugeIcon(
                  icon: HugeIcons.strokeRoundedTick01,
                  color: AppColors.labelOnSolid(AppColors.primary),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
