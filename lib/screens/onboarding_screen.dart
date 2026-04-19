// lib/screens/onboarding_screen.dart
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../theme/app_theme.dart';
import '../services/storage_service.dart';
import '../services/auth_service.dart';
import '../providers/transaction_provider.dart';
import '../widgets/grid_background.dart';
import '../widgets/blob_mascot.dart';
import '../models/mascot_dna.dart';
import '../ui/savyit/index.dart';
import 'financial_plan_screen.dart';
import 'home_screen.dart';

/// Onboarding accents — same neo palette as the rest of the app.
abstract final class _OnboardingJoy {
  static Color get coral => AppNeoColors.pink;
  static Color get sun => AppNeoColors.amber;
  static Color get iris => AppNeoColors.violet;

  static const LinearGradient ctaGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [
      Color(0xFFE8FF9A),
      AppNeoColors.lime,
      Color(0xFFB8E034),
    ],
  );
}

class OnboardingScreen extends StatefulWidget {
  /// After logout: land on sign-in only, then return to [HomeScreen] (no full onboarding replay).
  final bool reauthAfterLogout;

  const OnboardingScreen({super.key, this.reauthAfterLogout = false});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _nameController = TextEditingController();
  String _selectedCurrency = '₹';
  String _selectedOccupation = '';
  String _selectedIncome = '';
  String _selectedAge = '';
  final List<String> _selectedGoals = [];
  String _selectedTheme = 'pastel'; // new
  int _step = 0;
  static const _totalSteps = 12; // +1 for buddy picker step
  MascotDna _draftDna = MascotDna.defaults();

  @override
  void initState() {
    super.initState();
    if (widget.reauthAfterLogout) {
      _step = 11;
      WidgetsBinding.instance.addPostFrameCallback((_) async {
        final n = await StorageService.getUserName();
        if (!mounted) return;
        if (n != null && n.isNotEmpty) _nameController.text = n;
      });
    }
  }

  void _next() => setState(() => _step++);
  void _back() {
    if (widget.reauthAfterLogout && _step >= 11) return;
    if (_step > 0) setState(() => _step--);
  }

  void _finish() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    await StorageService.saveUserName(name);
    await StorageService.saveCurrency(_selectedCurrency);
    if (_selectedOccupation.isNotEmpty) {
      await StorageService.saveOccupation(_selectedOccupation);
    }
    if (_selectedIncome.isNotEmpty) {
      await StorageService.saveMonthlyIncome(_selectedIncome);
    }
    if (_selectedAge.isNotEmpty) {
      await StorageService.saveAgeRange(_selectedAge);
    }
    if (_selectedGoals.isNotEmpty) {
      await StorageService.saveFinancialGoals(_selectedGoals);
    }
    await StorageService.saveThemeMode(_selectedTheme);
    await StorageService.saveMascotDna(_draftDna);
    await StorageService.setProfileComplete(true);
    await StorageService.setOnboardingDone(true);

    if (mounted) {
      context.read<TransactionProvider>().init();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
            builder: (_) => const FinancialPlanScreen(fromOnboarding: true)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !(widget.reauthAfterLogout && _step >= 11),
      child: Scaffold(
      backgroundColor: AppColors.bg,
      body: GridBackground(
        patternColor: AppColors.isMonochrome
            ? null
            : AppNeoColors.shadowInk.withValues(alpha: 0.12),
        child: SafeArea(
          child: Column(
            children: [
              // Progress bar
              if (_step > 0)
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 14, 24, 0),
                  child: Row(
                    children: [
                      if (_step > 0 &&
                          !(widget.reauthAfterLogout && _step >= 11))
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: _back,
                            borderRadius: BorderRadius.circular(12),
                            child: Padding(
                              padding: const EdgeInsets.all(8),
                              child: Icon(
                                Icons.arrow_back_rounded,
                                color: AppColors.textSecondary,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      if (widget.reauthAfterLogout && _step >= 11)
                        const SizedBox(width: 40),
                      const SizedBox(width: 8),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(100),
                          child: TweenAnimationBuilder<double>(
                            tween:
                                Tween(begin: 0, end: _step / (_totalSteps - 1)),
                            duration: const Duration(milliseconds: 400),
                            curve: Curves.easeOutCubic,
                            builder: (_, value, __) => LinearProgressIndicator(
                              value: value,
                              backgroundColor:
                                  AppColors.primarySoft.withValues(alpha: 0.85),
                              valueColor: AlwaysStoppedAnimation(
                                AppColors.isMonochrome
                                    ? AppColors.primary
                                    : AppNeoColors.pink,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Text(
                        '$_step/${_totalSteps - 1}',
                        style: GoogleFonts.inter(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 0.6,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
              // Content
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 400),
                  transitionBuilder: (child, animation) {
                    return FadeTransition(
                      opacity: CurvedAnimation(
                          parent: animation, curve: Curves.easeIn),
                      child: SlideTransition(
                        position: Tween<Offset>(
                          begin: const Offset(0.0, 0.02),
                          end: Offset.zero,
                        ).animate(CurvedAnimation(
                            parent: animation, curve: Curves.easeOutCubic)),
                        child: child,
                      ),
                    );
                  },
                  child: _buildStep(),
                ),
              ),
            ],
          ),
        ),
      ),
    ),
    );
  }

  Widget _buildStep() {
    switch (_step) {
      // ── NEW: Buddy picker (step 0) ────────────────────────────
      case 0:
        return _BuddyPickerStep(
          key: const ValueKey(0),
          dna: _draftDna,
          onDnaChanged: (dna) => setState(() => _draftDna = dna),
          onNext: _next,
        );
      // ── Existing steps shifted +1 ─────────────────────────────
      case 1:
        return _WelcomeStep(key: const ValueKey(1), onStart: _next);
      case 2:
        return _HowItWorksStep(key: const ValueKey(2), onNext: _next);
      case 3:
        return _OccasionFeatureStep(
          key: const ValueKey(3),
          onNext: _next,
        );
      case 4:
        return _NameStep(
          key: const ValueKey(4),
          controller: _nameController,
          currency: _selectedCurrency,
          onCurrencyChange: (c) => setState(() => _selectedCurrency = c),
          onNext: () {
            if (_nameController.text.trim().isNotEmpty) _next();
          },
        );
      case 5:
        return _ChipStep(
          key: const ValueKey(5),
          title: "What do you do?",
          subtitle: "This helps us personalize your financial insights",
          options: const [
            _ChipOption(HugeIcons.strokeRoundedUser, 'Student'),
            _ChipOption(HugeIcons.strokeRoundedBriefcase01, 'Salaried'),
            _ChipOption(HugeIcons.strokeRoundedComputerVideo, 'Freelancer'),
            _ChipOption(HugeIcons.strokeRoundedStore01, 'Business Owner'),
            _ChipOption(HugeIcons.strokeRoundedSun03, 'Retired'),
            _ChipOption(HugeIcons.strokeRoundedStar, 'Other'),
          ],
          selected: _selectedOccupation,
          onSelect: (v) => setState(() => _selectedOccupation = v),
          onNext: () {
            if (_selectedOccupation.isNotEmpty) _next();
          },
        );
      case 6:
        return _ChipStep(
          key: const ValueKey(6),
          title: "Monthly income?",
          subtitle: "We'll use this to gauge your spending habits",
          options: const [
            _ChipOption(HugeIcons.strokeRoundedTree01, '< ₹15K'),
            _ChipOption(HugeIcons.strokeRoundedNaturalFood, '₹15K – 30K'),
            _ChipOption(HugeIcons.strokeRoundedTree02, '₹30K – 50K'),
            _ChipOption(HugeIcons.strokeRoundedMoney03, '₹50K – 1L'),
            _ChipOption(HugeIcons.strokeRoundedDiamond, '₹1L – 3L'),
            _ChipOption(HugeIcons.strokeRoundedRocket, '₹3L+'),
          ],
          selected: _selectedIncome,
          onSelect: (v) => setState(() => _selectedIncome = v),
          onNext: () {
            if (_selectedIncome.isNotEmpty) _next();
          },
        );
      case 7:
        return _ChipStep(
          key: const ValueKey(7),
          title: "How old are you?",
          subtitle: "Age-appropriate advice is better advice",
          options: const [
            _ChipOption(HugeIcons.strokeRoundedUser, '18 – 22'),
            _ChipOption(HugeIcons.strokeRoundedUser, '23 – 27'),
            _ChipOption(HugeIcons.strokeRoundedUser, '28 – 35'),
            _ChipOption(HugeIcons.strokeRoundedUser, '36 – 45'),
            _ChipOption(HugeIcons.strokeRoundedHome01, '46 – 55'),
            _ChipOption(HugeIcons.strokeRoundedSun03, '55+'),
          ],
          selected: _selectedAge,
          onSelect: (v) => setState(() => _selectedAge = v),
          onNext: () {
            if (_selectedAge.isNotEmpty) _next();
          },
        );
      case 8:
        return _GoalsStep(
          key: const ValueKey(8),
          selected: _selectedGoals,
          onToggle: (goal) {
            setState(() {
              if (_selectedGoals.contains(goal)) {
                _selectedGoals.remove(goal);
              } else if (_selectedGoals.length < 3) {
                _selectedGoals.add(goal);
              }
            });
          },
          onFinish: () {
            if (_selectedGoals.isNotEmpty) _next();
          },
        );
      case 9:
        return _ThemePickerStep(
          key: const ValueKey(9),
          selected: _selectedTheme,
          onSelect: (t) {
            setState(() => _selectedTheme = t);
            context.read<TransactionProvider>().setTheme(t);
          },
          onNext: _next,
        );
      case 10:
        return _SmsPermissionStep(
          key: const ValueKey(10),
          onNext: _next,
        );
      case 11:
        return _AuthStep(
          key: const ValueKey(11),
          onAuthenticated: () async {
            if (widget.reauthAfterLogout) {
              if (!mounted) return;
              Navigator.of(context).pushAndRemoveUntil(
                MaterialPageRoute(builder: (_) => const HomeScreen()),
                (route) => false,
              );
            } else {
              _finish();
            }
          },
        );
      default:
        return const SizedBox();
    }
  }
}

// ── Buddy Picker Step ─────────────────────────────────────────────
class _BuddyPickerStep extends StatefulWidget {
  final MascotDna dna;
  final ValueChanged<MascotDna> onDnaChanged;
  final VoidCallback onNext;

  const _BuddyPickerStep({
    super.key,
    required this.dna,
    required this.onDnaChanged,
    required this.onNext,
  });

  @override
  State<_BuddyPickerStep> createState() => _BuddyPickerStepState();
}

class _BuddyPickerStepState extends State<_BuddyPickerStep> {
  late TextEditingController _nameCtrl;
  late MascotDna _dna;

  @override
  void initState() {
    super.initState();
    _dna = widget.dna;
    _nameCtrl = TextEditingController(text: _dna.name);
  }

  @override
  void dispose() {
    _nameCtrl.dispose();
    super.dispose();
  }

  void _update(MascotDna dna) {
    setState(() => _dna = dna);
    widget.onDnaChanged(dna);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 20),

          // Animated blob preview
          BlobMascot(
            dna: _dna,
            mood: MascotMood.curious,
            size: 150,
            contrastPlate: true,
          ),
          const SizedBox(height: 18),

          // Title
          Text(
            'meet your\nmoney buddy',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.displayLarge?.copyWith(
                  fontSize: 34,
                  height: 1.1,
                  fontWeight: FontWeight.w600,
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'They\'ll react to your spending and cheer you on.',
            textAlign: TextAlign.center,
            style: GoogleFonts.inter(
              fontSize: 14,
              color: AppColors.textMuted,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 24),

          // Name field
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'NAME THEM',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _nameCtrl,
            maxLength: 20,
            onChanged: (v) => _update(_dna.copyWith(name: v.isEmpty ? 'Blobby' : v)),
            decoration: InputDecoration(
              hintText: 'e.g. Blobby',
              counterText: '',
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppNeoColors.tealInk, width: 2),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppNeoColors.tealInk, width: 2),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: const BorderSide(color: AppNeoColors.lime, width: 2.5),
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Color swatches
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'PICK A COLOR',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: blobColorOptions.map((opt) {
              final isActive = _dna.color == opt['id'];
              final color = blobColorMap[opt['id']] ?? AppNeoColors.lime;
              return GestureDetector(
                onTap: () => _update(_dna.copyWith(color: opt['id'])),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: AppNeoColors.tealInk,
                      width: isActive ? 3 : 2,
                    ),
                    boxShadow: isActive
                        ? [const BoxShadow(color: AppNeoColors.tealInk, offset: Offset(3, 3), blurRadius: 0)]
                        : [],
                  ),
                  child: isActive
                      ? const Icon(Icons.check, color: AppNeoColors.tealInk, size: 20)
                      : null,
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 20),

          // Accessory row
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'ACCESSORY',
              style: GoogleFonts.inter(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textMuted,
                letterSpacing: 1,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: blobAccessoryOptions.map((opt) {
              final isActive = _dna.accessory == opt['id'];
              return GestureDetector(
                onTap: () => _update(_dna.copyWith(accessory: opt['id'])),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 180),
                  width: 52,
                  height: 52,
                  decoration: BoxDecoration(
                    color: isActive ? AppNeoColors.lime : AppColors.surface,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppNeoColors.tealInk, width: 2),
                    boxShadow: isActive
                        ? [const BoxShadow(color: AppNeoColors.tealInk, offset: Offset(3, 3), blurRadius: 0)]
                        : [],
                  ),
                  child: Center(
                    child: Text(opt['emoji']!, style: const TextStyle(fontSize: 24)),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 28),

          SavyitButton(
            label: "Let's go →",
            onTap: widget.onNext,
            variant: SavyitButtonVariant.cta,
            width: double.infinity,
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ── Step 0: Welcome ──────────────────────────────────────────────
class _WelcomeStep extends StatelessWidget {
  final VoidCallback onStart;
  const _WelcomeStep({super.key, required this.onStart});

  @override
  Widget build(BuildContext context) {
    final ink = AppColors.isMonochrome ? AppColors.textMain : AppNeoColors.ink;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const SizedBox(height: 48),
          _EntranceAnimation(
            delayIndex: 0,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Transform.rotate(
                  angle: -0.08,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.isMonochrome
                          ? AppColors.surface2
                          : AppNeoColors.pink,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border,
                        width: 2,
                      ),
                      boxShadow: AppColors.isMonochrome
                          ? AppShadows.sm
                          : NeoPopDecorations.hardShadow(4),
                    ),
                    child: Text(
                      'NEW',
                      style: GoogleFonts.inter(
                        fontSize: 11,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        letterSpacing: 1,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Transform.rotate(
                  angle: 0.06,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppColors.isMonochrome
                          ? AppColors.surface
                          : AppNeoColors.lime,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: AppColors.border,
                        width: 2,
                      ),
                      boxShadow: AppColors.isMonochrome
                          ? AppShadows.sm
                          : NeoPopDecorations.hardShadow(4),
                    ),
                    child: Text(
                      'LOCAL-FIRST',
                      style: GoogleFonts.inter(
                        fontSize: 10,
                        fontWeight: FontWeight.w900,
                        color: ink,
                        letterSpacing: 0.6,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _FloatingAnimation(
            child: Text(
              'Savyit',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayLarge?.copyWith(
                    fontSize: 48,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ) ??
                  GoogleFonts.fraunces(
                    fontSize: 48,
                    height: 1.02,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
            ),
          ),
          const SizedBox(height: 16),
          _EntranceAnimation(
            delayIndex: 1,
            child: Text(
              'Financial\nIntelligence.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.displayMedium?.copyWith(
                    fontSize: 36,
                    height: 0.98,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ) ??
                  GoogleFonts.fraunces(
                    fontSize: 36,
                    height: 0.98,
                    letterSpacing: -1,
                    fontWeight: FontWeight.w700,
                    color: ink,
                  ),
            ),
          ),
          const SizedBox(height: 20),
          _EntranceAnimation(
            delayIndex: 2,
            child: Text(
              'Smart money tracking with AI insights, privacy-first design, and a plan tailored just for you.',
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
                fontSize: 16,
                height: 1.55,
                letterSpacing: -0.15,
              ),
            ),
          ),
          const Spacer(),
          _EntranceAnimation(
            delayIndex: 3,
            child: _PrimaryButton(label: 'Get Started', onTap: onStart),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Step 1: How It Works ─────────────────────────────────────────
class _HowItWorksStep extends StatelessWidget {
  final VoidCallback onNext;
  const _HowItWorksStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _EntranceAnimation(
            delayIndex: 0,
            child: Text('How it works',
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 34)),
          ),
          const SizedBox(height: 8),
          _EntranceAnimation(
            delayIndex: 1,
            child: Text('Three ways to track, zero reasons to worry.',
                style: GoogleFonts.inter(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                )),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _InfoCard(
                    delayIndex: 2,
                    icon: HugeIcons.strokeRoundedMessage01,
                    title: 'Auto SMS Scan',
                    description:
                        'We safely scan your bank transaction SMS to instantly build your spending dashboard.',
                    color: AppColors.primary,
                  ),
                  _InfoCard(
                    delayIndex: 3,
                    icon: HugeIcons.strokeRoundedFileAttachment,
                    title: 'PDF Uploads',
                    description:
                        'Download statements from GPay, PhonePe, or your bank and upload them for deep AI analysis.',
                    color: _OnboardingJoy.coral,
                  ),
                  _InfoCard(
                    delayIndex: 4,
                    icon: HugeIcons.strokeRoundedPencilEdit01,
                    title: 'Manual Entry',
                    description:
                        'For cash spends or anything else, just log them manually in a few taps.',
                    color: _OnboardingJoy.iris,
                  ),
                  _InfoCard(
                    delayIndex: 5,
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    title: 'Privacy First',
                    description:
                        'All your data stays 100% on your device. We don\'t have a database and we don\'t store your info.',
                    color: _OnboardingJoy.sun,
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EntranceAnimation(
            delayIndex: 6,
            child: _PrimaryButton(label: 'Sounds Great!', onTap: onNext),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _OccasionFeatureStep extends StatelessWidget {
  final VoidCallback onNext;
  const _OccasionFeatureStep({super.key, required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 20),
          _EntranceAnimation(
            delayIndex: 0,
            child: Text(
              'Plan Every\nOccasion',
              style: Theme.of(context)
                  .textTheme
                  .displayLarge
                  ?.copyWith(fontSize: 34),
            ),
          ),
          const SizedBox(height: 8),
          _EntranceAnimation(
            delayIndex: 1,
            child: Text(
              'Birthdays, trips, festivals, gifts. Create a focused budget before spending starts.',
              style: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600,
                height: 1.45,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              child: Column(
                children: [
                  _InfoCard(
                    delayIndex: 2,
                    icon: HugeIcons.strokeRoundedTarget02,
                    title: 'Create Occasion Buckets',
                    description:
                        'Set a clear target amount for each event so your spending has a limit from day one.',
                    color: _OnboardingJoy.coral,
                  ),
                  _InfoCard(
                    delayIndex: 3,
                    icon: HugeIcons.strokeRoundedWallet01,
                    title: 'Track Event Spending',
                    description:
                        'Add transactions into the right bucket and instantly see how much is used vs remaining.',
                    color: AppColors.primary,
                  ),
                  _InfoCard(
                    delayIndex: 4,
                    icon: HugeIcons.strokeRoundedAnalytics01,
                    title: 'Stay in Control',
                    description:
                        'Open Occasion from your Home screen anytime to avoid overspending during busy seasons.',
                    color: _OnboardingJoy.iris,
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          _EntranceAnimation(
            delayIndex: 5,
            child: _PrimaryButton(label: 'Continue', onTap: onNext),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final int delayIndex;
  final dynamic icon;
  final String title;
  final String description;
  final Color color;

  const _InfoCard({
    required this.delayIndex,
    required this.icon,
    required this.title,
    required this.description,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return _EntranceAnimation(
      delayIndex: delayIndex,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.xl),
                border: Border.all(color: AppColors.border, width: 1.2),
                boxShadow: AppShadows.sm,
              )
            : NeoPopDecorations.card(
                fill: AppColors.surface,
                radius: AppRadius.xl,
                shadowOffset: 5,
              ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(14),
                color: color.withValues(alpha: 0.35),
                border: Border.all(
                  color: AppColors.border,
                  width: 2,
                ),
                boxShadow: AppColors.isMonochrome
                    ? null
                    : NeoPopDecorations.hardShadow(3),
              ),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.glyphOnPaleAccent(color),
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: GoogleFonts.inter(
                      fontSize: 17,
                      fontWeight: FontWeight.w800,
                      color: AppColors.textMain,
                      letterSpacing: -0.2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    description,
                    style: GoogleFonts.inter(
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                      color: AppColors.textSecondary,
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingAnimation extends StatefulWidget {
  final Widget child;
  const _FloatingAnimation({required this.child});

  @override
  State<_FloatingAnimation> createState() => _FloatingAnimationState();
}

class _FloatingAnimationState extends State<_FloatingAnimation>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 3),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, child) => Transform.translate(
        offset:
            Offset(0, 10 * Curves.easeInOutQuad.transform(_controller.value)),
        child: child,
      ),
      child: widget.child,
    );
  }
}

// ── Step 1: Name + Currency ──────────────────────────────────────
class _NameStep extends StatelessWidget {
  final TextEditingController controller;
  final String currency;
  final Function(String) onCurrencyChange;
  final VoidCallback onNext;

  const _NameStep({
    super.key,
    required this.controller,
    required this.currency,
    required this.onCurrencyChange,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, 16 + bottomInset),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(height: bottomInset > 0 ? 16 : 40),
            _EntranceAnimation(
              delayIndex: 0,
              child: Text('Let\'s get\nto know you',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 36)),
            ),
            const SizedBox(height: 40),
            _EntranceAnimation(
              delayIndex: 1,
              child: Text('YOUR NAME',
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 12),
            _EntranceAnimation(
              delayIndex: 2,
              child: TextField(
                controller: controller,
                autofocus: true,
                style: GoogleFonts.inter(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textMain),
                decoration: InputDecoration(
                  hintText: 'What should we call you?',
                  hintStyle: GoogleFonts.inter(color: AppColors.textHint),
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.all(20),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.border,
                      width: AppBorders.normal,
                    ),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.border,
                      width: AppBorders.normal,
                    ),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(
                      color: AppColors.isMonochrome
                          ? AppColors.primary
                          : AppNeoColors.lime,
                      width: 2.5,
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 32),
            _EntranceAnimation(
              delayIndex: 3,
              child: Text('CURRENCY',
                  style: Theme.of(context).textTheme.labelSmall),
            ),
            const SizedBox(height: 12),
            _EntranceAnimation(
              delayIndex: 4,
              child: Row(
                children: ['₹', r'$', '€', '£'].map((c) {
                  final isSelected = currency == c;
                  return Expanded(
                    child: GestureDetector(
                      onTap: () => onCurrencyChange(c),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        padding: const EdgeInsets.symmetric(vertical: 18),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppColors.primary
                              : AppColors.surface,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: AppColors.border,
                            width: 2,
                          ),
                          boxShadow: isSelected && !AppColors.isMonochrome
                              ? NeoPopDecorations.hardShadow(4)
                              : (isSelected && AppColors.isMonochrome
                                  ? AppShadows.sm
                                  : null),
                        ),
                        child: Center(
                          child: Text(
                            c,
                            style: GoogleFonts.inter(
                              fontSize: 22,
                              fontWeight: FontWeight.w900,
                              color: isSelected
                                  ? AppColors.labelOnSolid(AppColors.primary)
                                  : AppColors.textMain,
                            ),
                          ),
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            ),
            const SizedBox(height: 32),
            _EntranceAnimation(
              delayIndex: 5,
              child: _PrimaryButton(label: 'Continue', onTap: onNext),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Steps 2-4: Single-select Chip Step ───────────────────────────
class _ChipOption {
  final dynamic icon;
  final String label;
  const _ChipOption(this.icon, this.label);
}

class _ChipStep extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<_ChipOption> options;
  final String selected;
  final Function(String) onSelect;
  final VoidCallback onNext;

  const _ChipStep({
    super.key,
    required this.title,
    required this.subtitle,
    required this.options,
    required this.selected,
    required this.onSelect,
    required this.onNext,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _EntranceAnimation(
            delayIndex: 0,
            child: Text(title,
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 34)),
          ),
          const SizedBox(height: 12),
          _EntranceAnimation(
            delayIndex: 1,
            child: Text(subtitle,
                style: GoogleFonts.inter(
                    color: AppColors.textMuted, fontSize: 15, height: 1.4)),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(options.length, (index) {
              final o = options[index];
              final isSelected = selected == o.label;
              return _EntranceAnimation(
                delayIndex: index + 2,
                  child: GestureDetector(
                  onTap: () => onSelect(o.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected && !AppColors.isMonochrome
                          ? _OnboardingJoy.ctaGradient
                          : null,
                      color: isSelected
                          ? (AppColors.isMonochrome ? AppColors.primary : null)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isSelected && !AppColors.isMonochrome
                          ? NeoPopDecorations.hardShadow(4)
                          : (isSelected && AppColors.isMonochrome
                              ? AppShadows.sm
                              : null),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: o.icon,
                          color: isSelected
                              ? (AppColors.isMonochrome
                                  ? Colors.white
                                  : AppNeoColors.ink)
                              : (AppColors.isMonochrome
                                  ? AppColors.primary
                                  : AppColors.iconOnLight),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          o.label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (AppColors.isMonochrome
                                    ? Colors.white
                                    : AppNeoColors.ink)
                                : AppColors.textMain,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          const Spacer(),
          _EntranceAnimation(
            delayIndex: options.length + 2,
            child: _PrimaryButton(
              label: 'Continue',
              onTap: onNext,
              enabled: selected.isNotEmpty,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Step 5: Multi-select Goals ───────────────────────────────────
class _GoalsStep extends StatelessWidget {
  final List<String> selected;
  final Function(String) onToggle;
  final VoidCallback onFinish;

  const _GoalsStep({
    super.key,
    required this.selected,
    required this.onToggle,
    required this.onFinish,
  });

  static const _goals = [
    _ChipOption(HugeIcons.strokeRoundedMoney03, 'Save More'),
    _ChipOption(HugeIcons.strokeRoundedMoney03, 'Pay Off Debt'),
    _ChipOption(HugeIcons.strokeRoundedShield01, 'Emergency Fund'),
    _ChipOption(HugeIcons.strokeRoundedChartIncrease, 'Invest Wisely'),
    _ChipOption(HugeIcons.strokeRoundedAnalytics01, 'Track Everything'),
    _ChipOption(HugeIcons.strokeRoundedTree01, 'Live Freely'),
  ];

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _EntranceAnimation(
            delayIndex: 0,
            child: Text("What's your\nmoney goal?",
                style: Theme.of(context)
                    .textTheme
                    .displayLarge
                    ?.copyWith(fontSize: 34)),
          ),
          const SizedBox(height: 12),
          _EntranceAnimation(
            delayIndex: 1,
            child: Text(
              'Pick up to 3 goals — we\'ll tailor insights for you',
              style: GoogleFonts.inter(
                  color: AppColors.textMuted, fontSize: 15, height: 1.4),
            ),
          ),
          const SizedBox(height: 36),
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: List.generate(_goals.length, (index) {
              final g = _goals[index];
              final isSelected = selected.contains(g.label);
              return _EntranceAnimation(
                delayIndex: index + 2,
                  child: GestureDetector(
                  onTap: () => onToggle(g.label),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutQuart,
                    padding: const EdgeInsets.symmetric(
                        horizontal: 18, vertical: 14),
                    decoration: BoxDecoration(
                      gradient: isSelected && !AppColors.isMonochrome
                          ? _OnboardingJoy.ctaGradient
                          : null,
                      color: isSelected
                          ? (AppColors.isMonochrome ? AppColors.primary : null)
                          : AppColors.surface,
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      border: Border.all(
                        color: AppColors.border,
                        width: 2,
                      ),
                      boxShadow: isSelected && !AppColors.isMonochrome
                          ? NeoPopDecorations.hardShadow(4)
                          : (isSelected && AppColors.isMonochrome
                              ? AppShadows.sm
                              : null),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        HugeIcon(
                          icon: g.icon,
                          color: isSelected
                              ? (AppColors.isMonochrome
                                  ? Colors.white
                                  : AppNeoColors.ink)
                              : (AppColors.isMonochrome
                                  ? AppColors.primary
                                  : AppColors.iconOnLight),
                          size: 20,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          g.label,
                          style: GoogleFonts.inter(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: isSelected
                                ? (AppColors.isMonochrome
                                    ? Colors.white
                                    : AppNeoColors.ink)
                                : AppColors.textMain,
                          ),
                        ),
                        if (isSelected) ...[
                          const SizedBox(width: 6),
                          Icon(
                            Icons.check_circle_rounded,
                            color: AppColors.isMonochrome
                                ? Colors.white
                                : AppNeoColors.ink,
                            size: 18,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
              );
            }),
          ),
          if (selected.isNotEmpty)
            _EntranceAnimation(
              delayIndex: _goals.length + 2,
              child: Padding(
                padding: const EdgeInsets.only(top: 16),
                child: Text(
                  '${selected.length}/3 selected',
                  style: GoogleFonts.inter(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accentTextOnSurface,
                  ),
                ),
              ),
            ),
          const Spacer(),
          _EntranceAnimation(
            delayIndex: _goals.length + 3,
            child: _PrimaryButton(
              label: 'Complete Setup',
              onTap: onFinish,
              enabled: selected.isNotEmpty,
            ),
          ),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

// ── Shared Primary Button ────────────────────────────────────────
class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;
  final bool enabled;

  const _PrimaryButton({
    required this.label,
    required this.onTap,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    return SavyitButton(
      label: label,
      onTap: enabled ? onTap : null,
      variant: AppColors.isMonochrome
          ? SavyitButtonVariant.primary
          : SavyitButtonVariant.cta,
      width: double.infinity,
    );
  }
}

class _EntranceAnimation extends StatefulWidget {
  final Widget child;
  final int delayIndex;
  const _EntranceAnimation({required this.child, required this.delayIndex});

  @override
  State<_EntranceAnimation> createState() => _EntranceAnimationState();
}

class _EntranceAnimationState extends State<_EntranceAnimation> {
  bool _visible = false;

  @override
  void initState() {
    super.initState();
    Future.delayed(Duration(milliseconds: widget.delayIndex * 80), () {
      if (mounted) setState(() => _visible = true);
    });
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedPadding(
      duration: const Duration(milliseconds: 600),
      curve: Curves.easeOutQuart,
      padding: EdgeInsets.only(top: _visible ? 0 : 20),
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 400),
        opacity: _visible ? 1.0 : 0.0,
        child: widget.child,
      ),
    );
  }
}

// ── Step 7: Theme Picker ─────────────────────────────────────────
class _ThemePickerStep extends StatelessWidget {
  final String selected;
  final Function(String) onSelect;
  final VoidCallback onNext;
  const _ThemePickerStep(
      {super.key,
      required this.selected,
      required this.onSelect,
      required this.onNext});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const SizedBox(height: 40),
          _EntranceAnimation(
              delayIndex: 0,
              child: Text('Pick your\naesthetic.',
                  style: Theme.of(context)
                      .textTheme
                      .displayLarge
                      ?.copyWith(fontSize: 36))),
          const SizedBox(height: 10),
          _EntranceAnimation(
              delayIndex: 1,
              child: Text('You can change this anytime in settings.',
                  style: GoogleFonts.inter(
                      color: AppColors.textMuted, fontSize: 14))),
          const SizedBox(height: 32),
          Expanded(
            child: Row(
              children: [
                Expanded(
                    child: _EntranceAnimation(
                        delayIndex: 2,
                        child: _ThemeCard(
                            label: 'Savyit Neo',
                            subtitle: 'Lime · pink · ink',
                            value: 'pastel',
                            selected: selected,
                            primaryColor: AppNeoColors.lime,
                            accentColor: AppNeoColors.pink,
                            onTap: () => onSelect('pastel')))),
                const SizedBox(width: 14),
                Expanded(
                    child: _EntranceAnimation(
                        delayIndex: 3,
                        child: _ThemeCard(
                            label: 'Minimal',
                            subtitle: 'Clean & focused',
                            value: 'monochrome',
                            selected: selected,
                            primaryColor: const Color(0xFFE0E0E0),
                            accentColor: const Color(0xFF888888),
                            onTap: () => onSelect('monochrome')))),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _EntranceAnimation(
              delayIndex: 4,
              child: _PrimaryButton(label: 'Continue', onTap: onNext)),
          const SizedBox(height: 48),
        ],
      ),
    );
  }
}

class _ThemeCard extends StatelessWidget {
  final String label, subtitle, value, selected;
  final Color primaryColor, accentColor;
  final VoidCallback onTap;
  const _ThemeCard(
      {required this.label,
      required this.subtitle,
      required this.value,
      required this.selected,
      required this.primaryColor,
      required this.accentColor,
      required this.onTap});

  bool get isSelected => selected == value;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutQuart,
        padding: const EdgeInsets.all(16),
        decoration: AppColors.isMonochrome
            ? BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: isSelected ? AppColors.primary : AppColors.border,
                  width: isSelected ? 2.5 : 1.2,
                ),
                boxShadow: AppShadows.sm,
              )
            : BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(AppRadius.card),
                border: Border.all(
                  color: AppNeoColors.strokeBlack,
                  width: 2,
                ),
                boxShadow: isSelected
                    ? NeoPopDecorations.hardShadow(5)
                    : NeoPopDecorations.hardShadow(3),
              ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: double.infinity,
              height: 80,
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.isMonochrome
                      ? AppColors.border
                      : AppNeoColors.strokeBlack,
                  width: 2,
                ),
                gradient: LinearGradient(
                  colors: [primaryColor, accentColor],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
              ),
              child: Stack(children: [
                Positioned(
                    top: 10,
                    left: 12,
                    child: Container(
                        width: 36,
                        height: 7,
                        decoration: BoxDecoration(
                            color: AppNeoColors.ink.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(4)))),
                Positioned(
                    top: 24,
                    left: 12,
                    child: Container(
                        width: 52,
                        height: 7,
                        decoration: BoxDecoration(
                            color: AppNeoColors.ink.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(4)))),
                Positioned(
                    bottom: 8,
                    right: 8,
                    child: Container(
                        width: 26,
                        height: 26,
                        decoration: BoxDecoration(
                            color: AppNeoColors.ink.withValues(alpha: 0.15),
                            shape: BoxShape.circle))),
              ]),
            ),
            const SizedBox(height: 12),
            Text(label,
                style: GoogleFonts.inter(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textMain)),
            const SizedBox(height: 3),
            Text(subtitle,
                style: GoogleFonts.inter(
                    fontSize: 11, color: AppColors.textMuted)),
            const SizedBox(height: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              width: 22,
              height: 22,
              decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isSelected ? AppColors.primary : Colors.transparent,
                  border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.border,
                      width: 2)),
              child: isSelected
                  ? Icon(
                      Icons.check_rounded,
                      color: AppColors.labelOnSolid(AppColors.primary),
                      size: 14,
                    )
                  : null,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Step 8: SMS Permission ───────────────────────────────────────
class _SmsPermissionStep extends StatefulWidget {
  final VoidCallback onNext;
  const _SmsPermissionStep({super.key, required this.onNext});
  @override
  State<_SmsPermissionStep> createState() => _SmsPermissionStepState();
}

class _SmsPermissionStepState extends State<_SmsPermissionStep> {
  bool _loading = false;
  bool _denied = false;

  Future<void> _requestPermission() async {
    if (kIsWeb) { widget.onNext(); return; }
    setState(() => _loading = true);
    final status = await Permission.sms.request();
    setState(() {
      _loading = false;
      _denied = status.isDenied || status.isPermanentlyDenied;
    });
    if (status.isGranted) widget.onNext();
  }

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.fromLTRB(32, 0, 32, 16 + bottomInset),
      child: SingleChildScrollView(
        keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 24),
            _EntranceAnimation(
                delayIndex: 0,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.isMonochrome
                        ? AppColors.primarySoft
                        : AppNeoColors.lime,
                    border: Border.all(
                      color: AppColors.border,
                      width: 2,
                    ),
                    boxShadow: AppColors.isMonochrome
                        ? AppShadows.sm
                        : NeoPopDecorations.hardShadow(4),
                  ),
                  child: Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.surface,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.border, width: 2),
                    ),
                    child: HugeIcon(
                      icon: HugeIcons.strokeRoundedMessage01,
                      color: AppColors.iconOnLight,
                      size: 40,
                    ),
                  ),
                )),
            const SizedBox(height: 28),
            _EntranceAnimation(
                delayIndex: 1,
                child: Text('Auto-detect\nyour transactions',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 34))),
            const SizedBox(height: 16),
            _EntranceAnimation(
                delayIndex: 2,
                child: Text(
                    "Savyit reads your bank SMS on this device and parses common bank formats locally — no cloud SMS upload.\n\n🔒 Parsed totals stay on your phone.",
                    style: GoogleFonts.inter(
                        color: AppColors.textSecondary,
                        fontSize: 15,
                        height: 1.6))),
            if (_denied) ...[
              const SizedBox(height: 16),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                    color: AppColors.redLight,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                        color: AppColors.border,
                        width: 2,
                    )),
                child: Text(
                    'Permission denied. You can still upload PDFs or add transactions manually.',
                    style: GoogleFonts.inter(
                        fontSize: 13, color: AppColors.red, height: 1.4)),
              ),
            ],
            const SizedBox(height: 28),
            _EntranceAnimation(
                delayIndex: 3,
                child: _PrimaryButton(
                    label: _loading ? 'Requesting…' : 'Grant SMS Access',
                    onTap: _loading ? () {} : _requestPermission)),
            const SizedBox(height: 14),
            _EntranceAnimation(
                delayIndex: 4,
                child: Center(
                    child: TextButton(
                        onPressed: widget.onNext,
                        child: Text('Continue without SMS',
                            style: GoogleFonts.inter(
                                fontSize: 14,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textMuted))))),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

// ── Step 11: Auth (Register / Login) ────────────────────────────
class _AuthStep extends StatefulWidget {
  final VoidCallback onAuthenticated;
  const _AuthStep({super.key, required this.onAuthenticated});
  @override
  State<_AuthStep> createState() => _AuthStepState();
}

class _AuthStepState extends State<_AuthStep>
    with SingleTickerProviderStateMixin {
  late final TabController _tab;
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  bool _loading = false;
  bool _obscure = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tab = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tab.dispose();
    _emailCtrl.dispose();
    _passCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final email = _emailCtrl.text.trim();
    final pass = _passCtrl.text;
    if (email.isEmpty || pass.isEmpty) {
      setState(() => _error = 'Please enter your email and password.');
      return;
    }
    if (pass.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters.');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_tab.index == 0) {
        await AuthService.signUpWithEmail(email, pass);
      } else {
        await AuthService.signInWithEmail(email, pass);
      }
      if (mounted) widget.onAuthenticated();
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = switch (e.code) {
          'email-already-in-use' =>
            'This email is already registered. Try logging in.',
          'user-not-found' => 'No account found. Sign up instead?',
          'wrong-password' ||
          'invalid-credential' =>
            'Incorrect password. Please try again.',
          'invalid-email' => 'Please enter a valid email address.',
          'weak-password' => 'Password too weak. Use at least 6 characters.',
          _ => e.message ?? 'Something went wrong. Please try again.',
        };
      });
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final cred = await AuthService.signInWithGoogle();
      if (cred != null && mounted) widget.onAuthenticated();
    } catch (_) {
      setState(() => _error = 'Google sign-in failed. Try email instead.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  InputDecoration _fieldDeco(String hint, IconData icon) => InputDecoration(
        hintText: hint,
        hintStyle: GoogleFonts.inter(color: AppColors.textHint),
        prefixIcon: Icon(icon, color: AppColors.textHint, size: 20),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding:
            const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: AppColors.border,
                width: AppBorders.normal,
            )),
        enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
                color: AppColors.border,
                width: AppBorders.normal,
            )),
        focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(14),
            borderSide: BorderSide(
              color: AppColors.isMonochrome
                  ? AppColors.primary
                  : AppNeoColors.lime,
              width: 2.5,
            )),
      );

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 28),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 32),
            _EntranceAnimation(
                delayIndex: 0,
                child: Text('Save your\nprogress.',
                    style: Theme.of(context)
                        .textTheme
                        .displayLarge
                        ?.copyWith(fontSize: 34))),
            const SizedBox(height: 6),
            _EntranceAnimation(
                delayIndex: 1,
                child: Text(
                    'Sign in is required for cloud AI SMS parsing. Your account also syncs and backs up your data.',
                    style: GoogleFonts.inter(
                        color: AppColors.textMuted,
                        fontSize: 14,
                        height: 1.4))),
            const SizedBox(height: 22),
            _EntranceAnimation(
              delayIndex: 2,
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                    color: AppColors.surface2,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(
                        color: AppColors.border,
                        width: 2,
                    ),
                    boxShadow: AppColors.isMonochrome
                        ? null
                        : NeoPopDecorations.hardShadow(3)),
                child: TabBar(
                  controller: _tab,
                  indicator: BoxDecoration(
                      color: AppColors.primary,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: AppColors.border,
                        width: AppColors.isMonochrome ? 0 : 2,
                      )),
                  indicatorSize: TabBarIndicatorSize.tab,
                  dividerColor: Colors.transparent,
                  labelColor: AppColors.labelOnSolid(AppColors.primary),
                  unselectedLabelColor: AppColors.textMuted,
                  labelStyle: GoogleFonts.inter(
                      fontSize: 14, fontWeight: FontWeight.w700),
                  tabs: const [Tab(text: 'Sign Up'), Tab(text: 'Log In')],
                ),
              ),
            ),
            const SizedBox(height: 18),
            _EntranceAnimation(
                delayIndex: 3,
                child: TextField(
                    controller: _emailCtrl,
                    keyboardType: TextInputType.emailAddress,
                    style: GoogleFonts.inter(
                        fontSize: 16, color: AppColors.textMain),
                    decoration:
                        _fieldDeco('Email address', Icons.email_outlined))),
            const SizedBox(height: 12),
            _EntranceAnimation(
              delayIndex: 4,
              child: TextField(
                controller: _passCtrl,
                obscureText: _obscure,
                style:
                    GoogleFonts.inter(fontSize: 16, color: AppColors.textMain),
                decoration:
                    _fieldDeco('Password', Icons.lock_outlined).copyWith(
                  suffixIcon: IconButton(
                      icon: Icon(
                          _obscure
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                          color: AppColors.textHint,
                          size: 20),
                      onPressed: () => setState(() => _obscure = !_obscure)),
                ),
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!,
                  style: GoogleFonts.inter(
                      fontSize: 13, color: AppColors.red, height: 1.3)),
            ],
            const SizedBox(height: 16),
            _EntranceAnimation(
              delayIndex: 5,
              child: _PrimaryButton(
                  label: _loading
                      ? 'Please wait…'
                      : (_tab.index == 0 ? 'Create Account' : 'Log In'),
                  onTap: _loading ? () {} : _submit),
            ),
            const SizedBox(height: 16),
            Row(children: [
              Expanded(child: Divider(color: AppColors.border)),
              Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  child: Text('or',
                      style: GoogleFonts.inter(
                          color: AppColors.textHint, fontSize: 13))),
              Expanded(child: Divider(color: AppColors.border)),
            ]),
            const SizedBox(height: 12),
            _EntranceAnimation(
              delayIndex: 6,
              child: SizedBox(
                width: double.infinity,
                height: 52,
                child: OutlinedButton.icon(
                  onPressed: _loading ? null : _googleSignIn,
                  icon: Text(
                    'G',
                    style: GoogleFonts.inter(
                      fontSize: 18,
                      fontWeight: FontWeight.w900,
                      color: AppColors.accentTextOnSurface,
                    ),
                  ),
                  label: Text('Continue with Google',
                      style: GoogleFonts.inter(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textMain)),
                  style: OutlinedButton.styleFrom(
                      backgroundColor: AppColors.surface,
                      side: BorderSide(
                        color: AppColors.border,
                        width: 2,
                      ),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14))),
                ),
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}
