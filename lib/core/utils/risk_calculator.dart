enum RiskDecision { allow, stepUp, deny }

class RiskResult {
  final int score;
  final String band;
  final RiskDecision decision;
  final List<String> reasons;

  const RiskResult({
    required this.score,
    required this.band,
    required this.decision,
    required this.reasons,
  });
}

class RiskCalculator {
  static RiskResult evaluate({
    required double amount,
    required String currency,
    required int deviceTrust,
    required bool isNewPayee,
  }) {
    int score = 0;
    final reasons = <String>[];

    if (amount >= 5000) {
      score += 35;
      reasons.add('High transfer amount');
    } else if (amount >= 2000) {
      score += 20;
      reasons.add('Medium-high transfer amount');
    }

    if (currency.toUpperCase() != 'MYR') {
      score += 25;
      reasons.add('Foreign currency transfer');
    }

    if (deviceTrust < 60) {
      score += 20;
      reasons.add('Low device trust');
    }

    if (isNewPayee) {
      score += 10;
      reasons.add('New payee');
    }

    score = score.clamp(0, 100);
    if (score < 30) {
      return RiskResult(score: score, band: 'LOW', decision: RiskDecision.allow, reasons: reasons);
    }
    if (score < 60) {
      return RiskResult(score: score, band: 'MEDIUM', decision: RiskDecision.stepUp, reasons: reasons);
    }
    return RiskResult(
      score: score,
      band: score >= 85 ? 'CRITICAL' : 'HIGH',
      decision: RiskDecision.deny,
      reasons: reasons,
    );
  }
}
