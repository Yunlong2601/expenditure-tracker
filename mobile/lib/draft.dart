/// An expense being entered or checked, before it is saved.
class ExpenseDraft {
  const ExpenseDraft({
    required this.amount,
    required this.currency,
    this.date,
    this.merchant,
    this.category,
    this.paymentMethod,
    this.summary,
    this.moneyIn = false,
  });

  final double amount;
  final String currency;
  final DateTime? date;
  final String? merchant;
  final String? category;
  final String? paymentMethod;
  final String? summary;

  /// Money she got rather than spent.
  final bool moneyIn;
}
