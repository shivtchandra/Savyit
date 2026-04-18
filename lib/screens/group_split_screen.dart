import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:path_provider/path_provider.dart';

import '../models/split_expense.dart';
import '../models/split_person.dart';
import '../models/split_recurring_template.dart';
import '../models/split_settlement.dart';
import '../providers/transaction_provider.dart';
import '../services/share_service.dart';
import '../theme/app_theme.dart';
import '../widgets/grid_background.dart';

class GroupSplitScreen extends StatefulWidget {
  const GroupSplitScreen({super.key});

  @override
  State<GroupSplitScreen> createState() => _GroupSplitScreenState();
}

class _GroupSplitScreenState extends State<GroupSplitScreen> {
  final _personController = TextEditingController();

  final _titleController = TextEditingController();
  final _amountController = TextEditingController();
  final Map<String, TextEditingController> _weightControllers = {};
  final Set<String> _selectedParticipants = {};
  String? _selectedPayerId;

  final _recurringTitleController = TextEditingController();
  final _recurringAmountController = TextEditingController();
  final Map<String, TextEditingController> _recurringWeightControllers = {};
  final Set<String> _selectedRecurringParticipants = {};
  String? _selectedRecurringPayerId;
  SplitRecurringFrequency _recurringFrequency = SplitRecurringFrequency.monthly;
  DateTime _recurringStartDate = DateTime.now();

  final GlobalKey _settlementBoundaryKey = GlobalKey();
  bool _isSharing = false;
  String _settlementShareBlurb = '';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      context.read<TransactionProvider>().runRecurringCatchUp(DateTime.now());
    });
  }

  @override
  void dispose() {
    _personController.dispose();
    _titleController.dispose();
    _amountController.dispose();
    _recurringTitleController.dispose();
    _recurringAmountController.dispose();

    for (final controller in _weightControllers.values) {
      controller.dispose();
    }
    for (final controller in _recurringWeightControllers.values) {
      controller.dispose();
    }
    super.dispose();
  }

  void _syncPeople(List<SplitPerson> people) {
    final ids = people.map((p) => p.id).toSet();

    _syncWeightControllers(_weightControllers, ids);
    _syncWeightControllers(_recurringWeightControllers, ids);

    if (_selectedPayerId == null || !ids.contains(_selectedPayerId)) {
      _selectedPayerId = people.isNotEmpty ? people.first.id : null;
    }
    if (_selectedRecurringPayerId == null ||
        !ids.contains(_selectedRecurringPayerId)) {
      _selectedRecurringPayerId = people.isNotEmpty ? people.first.id : null;
    }

    _selectedParticipants.removeWhere((id) => !ids.contains(id));
    if (_selectedParticipants.isEmpty && people.isNotEmpty) {
      _selectedParticipants.addAll(ids);
    }

    _selectedRecurringParticipants.removeWhere((id) => !ids.contains(id));
    if (_selectedRecurringParticipants.isEmpty && people.isNotEmpty) {
      _selectedRecurringParticipants.addAll(ids);
    }
  }

  void _syncWeightControllers(
    Map<String, TextEditingController> controllers,
    Set<String> ids,
  ) {
    final staleIds = controllers.keys.where((id) => !ids.contains(id)).toList();
    for (final id in staleIds) {
      controllers[id]?.dispose();
      controllers.remove(id);
    }
    for (final id in ids) {
      controllers.putIfAbsent(id, () => TextEditingController(text: '1'));
    }
  }

  String _formatCurrency(TransactionProvider provider, double amount,
      {bool showSign = false}) {
    final formatter = NumberFormat.currency(
      locale: 'en_IN',
      symbol: provider.selectedCurrency,
      decimalDigits: 2,
    );
    final rounded = (amount * 100).roundToDouble() / 100;
    if (showSign) {
      if (rounded > 0) return '+${formatter.format(rounded)}';
      if (rounded < 0) return '-${formatter.format(rounded.abs())}';
    }
    return formatter.format(rounded.abs());
  }

  Future<void> _pickRecurringStartDate() async {
    final now = DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: _recurringStartDate,
      firstDate: DateTime(now.year - 5),
      lastDate: DateTime(now.year + 10),
    );
    if (picked == null) return;
    setState(() => _recurringStartDate = picked);
  }

  Map<String, double>? _readWeights({
    required Map<String, TextEditingController> controllers,
    required Set<String> selectedPeople,
  }) {
    if (selectedPeople.isEmpty) {
      _showSnack('Select at least one participant');
      return null;
    }

    final weights = <String, double>{};
    for (final personId in selectedPeople) {
      final raw = controllers[personId]?.text.trim() ?? '1';
      final factor = double.tryParse(raw);
      if (factor == null || factor <= 0) {
        _showSnack('X-factor must be greater than 0 for selected people');
        return null;
      }
      weights[personId] = factor;
    }
    return weights;
  }

  Future<void> _addPerson(TransactionProvider provider) async {
    await provider.addSplitPerson(_personController.text);
    _personController.clear();
  }

  Future<void> _addExpense(TransactionProvider provider) async {
    final payerId = _selectedPayerId;
    if (payerId == null) {
      _showSnack('Add people first');
      return;
    }

    final amount = double.tryParse(_amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid amount');
      return;
    }

    final weights = _readWeights(
      controllers: _weightControllers,
      selectedPeople: _selectedParticipants,
    );
    if (weights == null) return;

    await provider.addSplitExpense(
      title: _titleController.text,
      amount: amount,
      paidByPersonId: payerId,
      participantWeights: weights,
    );

    _titleController.clear();
    _amountController.clear();
    for (final participantId in _selectedParticipants) {
      _weightControllers[participantId]?.text = '1';
    }
  }

  Future<void> _addRecurringTemplate(TransactionProvider provider) async {
    final payerId = _selectedRecurringPayerId;
    if (payerId == null) {
      _showSnack('Add people first');
      return;
    }

    final amount = double.tryParse(_recurringAmountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid recurring amount');
      return;
    }

    final weights = _readWeights(
      controllers: _recurringWeightControllers,
      selectedPeople: _selectedRecurringParticipants,
    );
    if (weights == null) return;

    await provider.addRecurringTemplate(
      title: _recurringTitleController.text,
      amount: amount,
      paidByPersonId: payerId,
      participantWeights: weights,
      frequency: _recurringFrequency,
      startDate: _recurringStartDate,
    );
    await provider.runRecurringCatchUp(DateTime.now());

    _recurringTitleController.clear();
    _recurringAmountController.clear();
    for (final participantId in _selectedRecurringParticipants) {
      _recurringWeightControllers[participantId]?.text = '1';
    }
  }

  Future<void> _editRecurringTemplate(
    TransactionProvider provider,
    SplitRecurringTemplate template,
  ) async {
    final titleController = TextEditingController(text: template.title);
    final amountController = TextEditingController(
      text: template.amount.toStringAsFixed(2),
    );
    var editFrequency = template.frequency;
    var effectiveFrom = DateTime.now();

    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Edit This & Future'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    TextField(
                      controller: titleController,
                      decoration: const InputDecoration(
                        labelText: 'Title',
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    TextField(
                      controller: amountController,
                      keyboardType:
                          const TextInputType.numberWithOptions(decimal: true),
                      decoration: const InputDecoration(
                        labelText: 'Amount',
                      ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    DropdownButtonFormField<SplitRecurringFrequency>(
                      initialValue: editFrequency,
                      decoration: const InputDecoration(
                        labelText: 'Frequency',
                      ),
                      items: SplitRecurringFrequency.values
                          .map(
                            (value) => DropdownMenuItem(
                              value: value,
                              child: Text(
                                value == SplitRecurringFrequency.weekly
                                    ? 'Weekly'
                                    : 'Monthly',
                              ),
                            ),
                          )
                          .toList(),
                      onChanged: (value) {
                        if (value == null) return;
                        setDialogState(() => editFrequency = value);
                      },
                    ),
                    SizedBox(height: AppSpacing.md),
                    OutlinedButton.icon(
                      onPressed: () async {
                        final picked = await showDatePicker(
                          context: dialogContext,
                          initialDate: effectiveFrom,
                          firstDate: DateTime.now().subtract(
                            const Duration(days: 3650),
                          ),
                          lastDate: DateTime.now().add(
                            const Duration(days: 3650),
                          ),
                        );
                        if (picked == null) return;
                        setDialogState(() => effectiveFrom = picked);
                      },
                      icon: const Icon(Icons.calendar_today_rounded, size: 16),
                      label: Text(
                        'Effective from ${DateFormat('dd MMM yyyy').format(effectiveFrom)}',
                      ),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialogContext, false),
                  child: const Text('Cancel'),
                ),
                ElevatedButton(
                  onPressed: () => Navigator.pop(dialogContext, true),
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (saved != true) return;

    final amount = double.tryParse(amountController.text.trim());
    if (amount == null || amount <= 0) {
      _showSnack('Enter a valid recurring amount');
      return;
    }

    await provider.updateRecurringTemplateThisAndFuture(
      templateId: template.id,
      effectiveFrom: effectiveFrom,
      title: titleController.text,
      amount: amount,
      frequency: editFrequency,
    );
    await provider.runRecurringCatchUp(DateTime.now());
  }

  void _showSnack(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _shareSettlement() async {
    if (_isSharing) return;
    setState(() {
      _isSharing = true;
      _settlementShareBlurb = SavyitShareCopy.loadingBlurb();
    });

    try {
      await Future.delayed(const Duration(milliseconds: 100));

      final boundary = _settlementBoundaryKey.currentContext?.findRenderObject()
          as RenderRepaintBoundary?;
      if (boundary == null) throw Exception('Could not find render object');

      final image = await boundary.toImage(pixelRatio: 3.0);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) throw Exception('Could not encode image');

      final buffer = byteData.buffer.asUint8List();
      final tempDir = await getTemporaryDirectory();
      final file = File(
          '${tempDir.path}/savyit_settlement_${DateTime.now().millisecondsSinceEpoch}.png');
      await file.writeAsBytes(buffer);

      await ShareService.shareImage(
        imageFile: file,
        subject: SavyitShareCopy.settlementSubject(),
        text: SavyitShareCopy.settlementBody(),
      );
    } catch (e) {
      debugPrint('Error sharing report: $e');
      if (!mounted) return;
      _showSnack('Failed to generate sharing image');
    } finally {
      if (mounted) setState(() => _isSharing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<TransactionProvider>();
    final people = provider.splitPeople;
    final expenses = provider.splitExpenses;
    final recurringTemplates = provider.splitRecurringTemplates;
    final summary = provider.splitSummary;

    _syncPeople(people);
    final peopleById = {for (final p in people) p.id: p.name};

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.bg,
        appBar: AppBar(
          title: const Text('Group Split'),
          bottom: TabBar(
            // Lime indicator only — label must stay dark for contrast on pale bg.
            indicatorColor: AppColors.primary,
            indicatorWeight: 3,
            labelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w900,
              color: AppColors.textMain,
              letterSpacing: -0.2,
            ),
            unselectedLabelStyle: GoogleFonts.inter(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: AppColors.textMuted,
            ),
            tabs: const [
              Tab(text: 'Add'),
              Tab(text: 'Expenses'),
              Tab(text: 'Settlements'),
            ],
          ),
        ),
        body: Theme(
          data: Theme.of(context).copyWith(
            inputDecorationTheme:
                Theme.of(context).inputDecorationTheme.copyWith(
              hintStyle: GoogleFonts.inter(
                color: AppColors.textSecondary,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          child: GridBackground(
            child: TabBarView(
            children: [
              _buildAddTab(
                  context,
                  provider,
                  people,
                  _personController,
                  _titleController,
                  _amountController,
                  _selectedPayerId,
                  _weightControllers,
                  _selectedParticipants,
                  _recurringTitleController,
                  _recurringAmountController,
                  _selectedRecurringPayerId,
                  _recurringFrequency,
                  _recurringStartDate,
                  _recurringWeightControllers,
                  _selectedRecurringParticipants),
              _buildExpensesTab(
                  context, provider, peopleById, expenses, recurringTemplates),
              _buildSettlementTab(context, provider, peopleById, summary),
            ],
          ),
        ),
        ),
      ),
    );
  }

  Widget _buildAddTab(
    BuildContext context,
    TransactionProvider provider,
    List<SplitPerson> people,
    TextEditingController personController,
    TextEditingController titleController,
    TextEditingController amountController,
    String? selectedPayerId,
    Map<String, TextEditingController> weightControllers,
    Set<String> selectedParticipants,
    TextEditingController recurringTitleController,
    TextEditingController recurringAmountController,
    String? selectedRecurringPayerId,
    SplitRecurringFrequency recurringFrequency,
    DateTime recurringStartDate,
    Map<String, TextEditingController> recurringWeightControllers,
    Set<String> selectedRecurringParticipants,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Create Expenses',
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.textMain,
                ),
          ),
          SizedBox(height: 2),
          Text(
            'Track shared costs, use X-factor for weighted splits.',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'People',
            icon: HugeIcons.strokeRoundedUser,
            child: Column(
              children: [
                TextField(
                  controller: _personController,
                  textInputAction: TextInputAction.done,
                  decoration: InputDecoration(
                    hintText: 'Add person name',
                    suffixIcon: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          padding: const EdgeInsets.symmetric(horizontal: 16),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(AppRadius.sm),
                          ),
                        ),
                        onPressed: () => _addPerson(provider),
                        child: const Text('Add'),
                      ),
                    ),
                  ),
                  onSubmitted: (_) => _addPerson(provider),
                ),
                SizedBox(height: AppSpacing.md),
                if (people.isEmpty)
                  const _MutedLabel(
                    text: 'No people added yet.',
                  )
                else
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: AppSpacing.sm,
                    children: people.map((person) {
                      return Chip(
                        label: Text(
                          person.name,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    fontWeight: FontWeight.w600,
                                    color: AppColors.textMain,
                                  ),
                        ),
                        backgroundColor: AppColors.surface2,
                        side: BorderSide.none,
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 0),
                        deleteIcon: Container(
                          padding: const EdgeInsets.all(2),
                          decoration: BoxDecoration(
                            color: AppColors.border,
                            shape: BoxShape.circle,
                          ),
                          child: HugeIcon(
                            icon: HugeIcons.strokeRoundedCancel01,
                            size: 12,
                            color: AppColors.textMain,
                          ),
                        ),
                        onDeleted: () => provider.removeSplitPerson(person.id),
                      );
                    }).toList(),
                  ),
              ],
            ),
          ),
          SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Add Expense',
            icon: HugeIcons.strokeRoundedMoney03,
            child: people.isEmpty
                ? const _MutedLabel(
                    text: 'Add at least one person to create expenses.',
                  )
                : Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _titleController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Expense title',
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _amountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Amount',
                                prefixText: '${provider.selectedCurrency} ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        key: ValueKey('payer_${_selectedPayerId ?? ''}'),
                        initialValue: _selectedPayerId,
                        decoration: const InputDecoration(
                          labelText: 'Paid by',
                        ),
                        items: people
                            .map(
                              (person) => DropdownMenuItem<String>(
                                value: person.id,
                                child: Text(person.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedPayerId = value);
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Participants + X-factor',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      ..._participantRows(
                        people: people,
                        selected: _selectedParticipants,
                        controllers: _weightControllers,
                      ),
                      SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _addExpense(provider),
                          child: const Text('Add Expense'),
                        ),
                      ),
                    ],
                  ),
          ),
          SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Recurring',
            icon: HugeIcons.strokeRoundedCalendar03,
            child: people.isEmpty
                ? const _MutedLabel(
                    text: 'Add people first to create recurring templates.',
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextField(
                              controller: _recurringTitleController,
                              textInputAction: TextInputAction.next,
                              decoration: const InputDecoration(
                                hintText: 'Recurring title',
                              ),
                            ),
                          ),
                          SizedBox(width: AppSpacing.sm),
                          Expanded(
                            flex: 2,
                            child: TextField(
                              controller: _recurringAmountController,
                              keyboardType:
                                  const TextInputType.numberWithOptions(
                                      decimal: true),
                              textInputAction: TextInputAction.done,
                              decoration: InputDecoration(
                                hintText: 'Amount',
                                prefixText: '${provider.selectedCurrency} ',
                              ),
                            ),
                          ),
                        ],
                      ),
                      SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<String>(
                        key: ValueKey(
                            'rpayer_${_selectedRecurringPayerId ?? ''}'),
                        initialValue: _selectedRecurringPayerId,
                        decoration: const InputDecoration(
                          labelText: 'Paid by',
                        ),
                        items: people
                            .map(
                              (person) => DropdownMenuItem<String>(
                                value: person.id,
                                child: Text(person.name),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _selectedRecurringPayerId = value);
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                      DropdownButtonFormField<SplitRecurringFrequency>(
                        initialValue: _recurringFrequency,
                        decoration: const InputDecoration(
                          labelText: 'Frequency',
                        ),
                        items: SplitRecurringFrequency.values
                            .map(
                              (frequency) => DropdownMenuItem(
                                value: frequency,
                                child: Text(
                                  frequency == SplitRecurringFrequency.weekly
                                      ? 'Weekly'
                                      : 'Monthly',
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (value) {
                          if (value == null) return;
                          setState(() => _recurringFrequency = value);
                        },
                      ),
                      SizedBox(height: AppSpacing.md),
                      OutlinedButton.icon(
                        onPressed: _pickRecurringStartDate,
                        icon:
                            const Icon(Icons.calendar_today_rounded, size: 16),
                        label: Text(
                          'Start date ${DateFormat('dd MMM yyyy').format(_recurringStartDate)}',
                        ),
                      ),
                      SizedBox(height: AppSpacing.md),
                      Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Participants + X-factor',
                          style: Theme.of(context).textTheme.labelLarge,
                        ),
                      ),
                      SizedBox(height: AppSpacing.sm),
                      ..._participantRows(
                        people: people,
                        selected: _selectedRecurringParticipants,
                        controllers: _recurringWeightControllers,
                      ),
                      SizedBox(height: AppSpacing.md),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed: () => _addRecurringTemplate(provider),
                          child: const Text('Add Recurring Template'),
                        ),
                      ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildExpensesTab(
    BuildContext context,
    TransactionProvider provider,
    Map<String, String> peopleById,
    List<SplitExpense> expenses,
    List<SplitRecurringTemplate> recurringTemplates,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _SectionCard(
            title: 'Expenses',
            icon: HugeIcons.strokeRoundedFileAttachment,
            trailing: expenses.isNotEmpty
                ? TextButton(
                    onPressed: provider.clearSplitExpenses,
                    child: const Text('Clear all'),
                  )
                : null,
            child: expenses.isEmpty
                ? const _MutedLabel(text: 'No shared expenses yet.')
                : Column(
                    children: expenses.map((expense) {
                      final payerName =
                          peopleById[expense.paidByPersonId] ?? 'Unknown';
                      return _ExpenseRow(
                        expense: expense,
                        payerName: payerName,
                        subtitle:
                            '${expense.participantCount} people • ${_formatWeightText(expense.participantWeights.values)}',
                        amountText: _formatCurrency(provider, expense.amount),
                        onDelete: () => provider.removeSplitExpense(expense.id),
                      );
                    }).toList(),
                  ),
          ),
          SizedBox(height: AppSpacing.lg),
          _SectionCard(
            title: 'Recurring Templates',
            icon: HugeIcons.strokeRoundedCalendar03,
            child: recurringTemplates.isEmpty
                ? const _MutedLabel(text: 'No recurring templates yet.')
                : Column(
                    children: recurringTemplates.map((template) {
                      final payerName =
                          peopleById[template.paidByPersonId] ?? 'Unknown';
                      final status = template.isActive ? 'Active' : 'Paused';
                      final statusColor =
                          template.isActive ? AppColors.green : AppColors.red;
                      return Container(
                        margin: EdgeInsets.only(bottom: AppSpacing.sm),
                        padding: EdgeInsets.all(AppSpacing.md),
                        decoration: BoxDecoration(
                          color: AppColors.surface,
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                              color: AppColors.borderLight, width: 0.5),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    template.title,
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(provider, template.amount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                        color: AppColors.textMain,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              'Paid by $payerName • ${template.frequency == SplitRecurringFrequency.weekly ? 'Weekly' : 'Monthly'} • Next ${DateFormat('dd MMM yyyy').format(template.nextRunAt)}',
                              style: Theme.of(context).textTheme.bodySmall,
                            ),
                            SizedBox(height: AppSpacing.xs),
                            Text(
                              status,
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: statusColor,
                                    fontWeight: FontWeight.w700,
                                  ),
                            ),
                            if ((template.pauseReason ?? '')
                                .trim()
                                .isNotEmpty) ...[
                              SizedBox(height: AppSpacing.xs),
                              Text(
                                template.pauseReason!,
                                style: Theme.of(context)
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(color: AppColors.red),
                              ),
                            ],
                            SizedBox(height: AppSpacing.sm),
                            Wrap(
                              spacing: AppSpacing.sm,
                              children: [
                                OutlinedButton(
                                  onPressed: () => _editRecurringTemplate(
                                    provider,
                                    template,
                                  ),
                                  child: const Text('Edit future'),
                                ),
                                OutlinedButton(
                                  onPressed: () async {
                                    if (template.isActive) {
                                      await provider.pauseRecurringTemplate(
                                        template.id,
                                      );
                                    } else {
                                      await provider.resumeRecurringTemplate(
                                        template.id,
                                      );
                                      await provider.runRecurringCatchUp(
                                        DateTime.now(),
                                      );
                                    }
                                  },
                                  child: Text(
                                    template.isActive ? 'Pause' : 'Resume',
                                  ),
                                ),
                                OutlinedButton(
                                  onPressed: () =>
                                      provider.deleteRecurringTemplate(
                                    template.id,
                                  ),
                                  child: const Text('Delete'),
                                ),
                              ],
                            ),
                          ],
                        ),
                      );
                    }).toList(),
                  ),
          )
        ],
      ),
    );
  }

  Widget _buildSettlementTab(
    BuildContext context,
    TransactionProvider provider,
    Map<String, String> peopleById,
    SplitSettlementSummary summary,
  ) {
    return SingleChildScrollView(
      padding: EdgeInsets.fromLTRB(
        AppSpacing.lg,
        AppSpacing.md,
        AppSpacing.lg,
        120,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          RepaintBoundary(
            key: _settlementBoundaryKey,
            child: Container(
              color:
                  AppColors.bg, // Solid background color for the exported image
              child: _SectionCard(
                title: 'Settlement',
                icon: HugeIcons.strokeRoundedExchange01,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Total shared: ${_formatCurrency(provider, summary.totalExpense)} (${summary.expenseCount} expenses)',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMain,
                          ),
                    ),
                    SizedBox(height: AppSpacing.md),
                    if (summary.isSettled)
                      const _MutedLabel(text: 'All settled up.')
                    else
                      Column(
                        children: summary.transfers.map((transfer) {
                          final fromName =
                              peopleById[transfer.fromPersonId] ?? 'Unknown';
                          final toName =
                              peopleById[transfer.toPersonId] ?? 'Unknown';
                          return Container(
                            margin: EdgeInsets.only(bottom: AppSpacing.sm),
                            padding: EdgeInsets.all(AppSpacing.md),
                            decoration: BoxDecoration(
                              color: AppColors.surface2,
                              borderRadius: BorderRadius.circular(AppRadius.md),
                            ),
                            child: Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '$fromName pays $toName',
                                    style: Theme.of(context)
                                        .textTheme
                                        .bodyMedium
                                        ?.copyWith(
                                          color: AppColors.textMain,
                                          fontWeight: FontWeight.w700,
                                        ),
                                  ),
                                ),
                                Text(
                                  _formatCurrency(provider, transfer.amount),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: AppColors.primaryDark,
                                        fontWeight: FontWeight.w800,
                                      ),
                                ),
                              ],
                            ),
                          );
                        }).toList(),
                      ),
                    SizedBox(height: AppSpacing.md),
                    Divider(color: AppColors.border),
                    SizedBox(height: AppSpacing.sm),
                    ..._buildNetRows(provider, peopleById, summary.netByPerson),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(height: AppSpacing.xl),
          if (summary.transfers.isNotEmpty || summary.netByPerson.isNotEmpty)
            Center(
              child: _isSharing
                  ? _SplitShareLoadingPill(line: _settlementShareBlurb)
                  : _SplitShareNeoButton(
                      onTap: _shareSettlement,
                      title: SavyitShareCopy.settlementButtonTitle(),
                      subtitle: SavyitShareCopy.settlementButtonSubtitle(),
                    ),
            ),
        ],
      ),
    );
  }

  List<Widget> _participantRows({
    required List<SplitPerson> people,
    required Set<String> selected,
    required Map<String, TextEditingController> controllers,
  }) {
    return people.map((person) {
      final isSelected = selected.contains(person.id);
      final controller = controllers[person.id]!;

      return GestureDetector(
        onTap: () {
          setState(() {
            if (isSelected) {
              selected.remove(person.id);
            } else {
              selected.add(person.id);
            }
          });
        },
        child: Container(
          margin: EdgeInsets.only(bottom: AppSpacing.sm),
          padding: EdgeInsets.symmetric(
            horizontal: AppSpacing.sm,
            vertical: 4,
          ),
          decoration: BoxDecoration(
            color: isSelected ? AppColors.primarySoft : AppColors.surface,
            borderRadius: BorderRadius.circular(AppRadius.md),
            border: Border.all(
              color: isSelected
                  ? AppColors.primary.withValues(alpha: 0.3)
                  : AppColors.borderLight,
            ),
          ),
          child: Row(
            children: [
              Checkbox(
                value: isSelected,
                activeColor: AppColors.primary,
                side: BorderSide(color: AppColors.border),
                onChanged: (value) {
                  setState(() {
                    if (value == true) {
                      selected.add(person.id);
                    } else {
                      selected.remove(person.id);
                    }
                  });
                },
              ),
              Expanded(
                child: Text(
                  person.name,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: isSelected
                            ? AppColors.primaryDark
                            : AppColors.textMain,
                        fontWeight:
                            isSelected ? FontWeight.w700 : FontWeight.w500,
                      ),
                ),
              ),
              if (isSelected)
                SizedBox(
                  width: 60,
                  height: 36,
                  child: TextField(
                    controller: controller,
                    enabled: isSelected,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                        fontWeight: FontWeight.w700, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: '1',
                      contentPadding: EdgeInsets.zero,
                      filled: true,
                      fillColor: AppColors.surface,
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.sm),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      );
    }).toList();
  }

  List<Widget> _buildNetRows(
    TransactionProvider provider,
    Map<String, String> peopleById,
    Map<String, double> netByPerson,
  ) {
    final sorted = netByPerson.entries.toList()
      ..sort((a, b) => b.value.abs().compareTo(a.value.abs()));

    return sorted.map((entry) {
      final amount = entry.value;
      final color = amount > 0
          ? AppColors.green
          : amount < 0
              ? AppColors.red
              : AppColors.textMuted;
      final label = amount > 0
          ? 'Receives'
          : amount < 0
              ? 'Pays'
              : 'Settled';

      return Padding(
        padding: EdgeInsets.only(bottom: AppSpacing.xs),
        child: Row(
          children: [
            Expanded(
              child: Text(
                peopleById[entry.key] ?? 'Unknown',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.textMain,
                      fontWeight: FontWeight.w600,
                    ),
              ),
            ),
            Text(
              '$label ${_formatCurrency(provider, amount, showSign: true)}',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: color,
                    fontWeight: FontWeight.w700,
                  ),
            ),
          ],
        ),
      );
    }).toList();
  }

  String _formatWeightText(Iterable<double> weights) {
    final max =
        weights.fold<double>(0, (curr, value) => value > curr ? value : curr);
    final min = weights.fold<double>(
        double.infinity, (curr, value) => value < curr ? value : curr);
    if ((max - min).abs() < 0.001) {
      return '${max.toStringAsFixed(max == max.roundToDouble() ? 0 : 1)}x each';
    }
    return 'weighted';
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final dynamic icon;
  final Widget child;
  final Widget? trailing;

  const _SectionCard({
    required this.title,
    required this.icon,
    required this.child,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: EdgeInsets.all(AppSpacing.md),
      decoration: AppDecorations.card.copyWith(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 10,
            offset: const Offset(0, 4),
          )
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: EdgeInsets.all(AppSpacing.sm),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(AppRadius.sm),
                ),
                child: HugeIcon(
                  icon: icon,
                  color: AppColors.isMonochrome
                      ? AppColors.primary
                      : AppColors.iconOnLight,
                  size: 16,
                ),
              ),
              SizedBox(width: AppSpacing.sm),
              Text(
                title,
                style: Theme.of(context).textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: AppColors.textMain,
                    ),
              ),
              const Spacer(),
              if (trailing != null) trailing!,
            ],
          ),
          SizedBox(height: AppSpacing.md),
          child,
        ],
      ),
    );
  }
}

class _ExpenseRow extends StatelessWidget {
  final SplitExpense expense;
  final String payerName;
  final String subtitle;
  final String amountText;
  final VoidCallback onDelete;

  const _ExpenseRow({
    required this.expense,
    required this.payerName,
    required this.subtitle,
    required this.amountText,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final occurrence = expense.occurrenceDate;
    final recurringLabel = occurrence == null
        ? 'Recurring'
        : 'Recurring ${DateFormat('dd MMM').format(occurrence)}';

    return Container(
      margin: EdgeInsets.only(bottom: AppSpacing.sm),
      padding: EdgeInsets.symmetric(
          horizontal: AppSpacing.md, vertical: AppSpacing.sm),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(color: AppColors.borderLight, width: 0.5),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        expense.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              color: AppColors.textMain,
                            ),
                      ),
                    ),
                    if (expense.isAutoGenerated)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.primarySoft,
                          borderRadius: BorderRadius.circular(999),
                          border: Border.all(
                            color: AppColors.primary.withValues(alpha: 0.25),
                          ),
                        ),
                        child: Text(
                          recurringLabel,
                          style:
                              Theme.of(context).textTheme.bodySmall?.copyWith(
                                    color: AppColors.primaryDark,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10,
                                  ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: AppSpacing.xs),
                Text(
                  'Paid by $payerName • $subtitle',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ],
            ),
          ),
          SizedBox(width: AppSpacing.sm),
          Text(
            amountText,
            style: GoogleFonts.inter(
              fontWeight: FontWeight.w800,
              color: AppColors.textMain,
              fontSize: 13,
            ),
          ),
          IconButton(
            onPressed: onDelete,
            icon: HugeIcon(
              icon: HugeIcons.strokeRoundedDelete02,
              size: 16,
              color: AppColors.textMuted,
            ),
            tooltip: 'Delete',
          ),
        ],
      ),
    );
  }
}

class _SplitShareNeoButton extends StatelessWidget {
  final VoidCallback onTap;
  final String title;
  final String subtitle;

  const _SplitShareNeoButton({
    required this.onTap,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final isNeo = !AppColors.isMonochrome;
    final fg = isNeo ? AppNeoColors.ink : Colors.white;
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Ink(
          padding: const EdgeInsets.fromLTRB(20, 14, 20, 14),
          decoration: isNeo
              ? NeoPopDecorations.card(
                  fill: AppNeoColors.lime,
                  radius: AppRadius.lg,
                  shadowOffset: 5,
                )
              : BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  boxShadow: AppShadows.md,
                ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  HugeIcon(
                    icon: HugeIcons.strokeRoundedShare01,
                    color: fg,
                    size: 20,
                  ),
                  const SizedBox(width: 10),
                  Flexible(
                    child: Text(
                      title,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.inter(
                        fontSize: 15,
                        fontWeight: FontWeight.w900,
                        color: fg,
                        letterSpacing: -0.3,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                  fontStyle: FontStyle.italic,
                  color: fg.withValues(alpha: isNeo ? 0.82 : 0.9),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SplitShareLoadingPill extends StatelessWidget {
  final String line;

  const _SplitShareLoadingPill({required this.line});

  @override
  Widget build(BuildContext context) {
    final msg = line.trim().isEmpty ? 'Baking settlement PNG…' : line;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      decoration: !AppColors.isMonochrome
          ? NeoPopDecorations.card(
              fill: AppColors.surface2,
              radius: AppRadius.md,
              shadowOffset: 3,
            )
          : BoxDecoration(
              color: AppColors.surface2,
              borderRadius: BorderRadius.circular(AppRadius.md),
              border: Border.all(color: AppColors.border),
            ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: AppColors.chartStrokeOnCard,
            ),
          ),
          const SizedBox(width: 12),
          Flexible(
            child: Text(
              msg,
              style: GoogleFonts.inter(
                fontSize: 12,
                fontWeight: FontWeight.w800,
                fontStyle: FontStyle.italic,
                color: AppColors.textMain,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _MutedLabel extends StatelessWidget {
  final String text;
  const _MutedLabel({required this.text});

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: Theme.of(context)
          .textTheme
          .bodyMedium
          ?.copyWith(color: AppColors.textMuted),
    );
  }
}
