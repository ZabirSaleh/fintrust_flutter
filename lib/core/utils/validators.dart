class Validators {
  static String? requiredField(String? value, String label) {
    if (value == null || value.trim().isEmpty) return '$label is required';
    return null;
  }

  static String? email(String? value) {
    final raw = value?.trim() ?? '';
    if (raw.isEmpty) return 'Email is required';
    if (!raw.contains('@') || !raw.contains('.')) return 'Enter a valid email';
    return null;
  }

  static String? password(String? value) {
    final raw = value ?? '';
    if (raw.length < 6) return 'Password must be at least 6 characters';
    return null;
  }

  static String? amount(String? value) {
    final raw = value?.trim() ?? '';
    final amount = double.tryParse(raw);
    if (amount == null || amount <= 0) return 'Enter a valid amount';
    return null;
  }
}
