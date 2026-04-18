class SettlementTransfer {
  final String fromPersonId;
  final String toPersonId;
  final double amount;

  const SettlementTransfer({
    required this.fromPersonId,
    required this.toPersonId,
    required this.amount,
  });
}

class SplitSettlementSummary {
  final Map<String, double> netByPerson;
  final List<SettlementTransfer> transfers;
  final double totalExpense;
  final int expenseCount;

  const SplitSettlementSummary({
    required this.netByPerson,
    required this.transfers,
    required this.totalExpense,
    required this.expenseCount,
  });

  bool get isSettled => transfers.isEmpty;
}
