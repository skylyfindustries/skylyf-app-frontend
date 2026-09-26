import 'countries.dart';

/// Field rules. Mirrored by the API (backend/src/validators/auth.validators.js), which is the source of truth.
/// Every validator returns an error message, or null when the value is fine.
class V {
  static final _email = RegExp(r"^[A-Za-z0-9.!#$%&'*+/=?^_`{|}~-]+@[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?(?:\.[A-Za-z0-9](?:[A-Za-z0-9-]{0,61}[A-Za-z0-9])?)+$");

  static String? required(String? v, [String what = 'This field']) => (v ?? '').trim().isEmpty ? '$what is required' : null;

  static String? email(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email is required';
    if (s.length > 254) return 'Email is too long (max 254)';
    return _email.hasMatch(s) ? null : 'Enter a valid email, like name@company.com';
  }

  /// Sign-in only checks presence: never reveal the password rules to someone guessing.
  static String? loginPassword(String? v) {
    if ((v ?? '').isEmpty) return 'Enter your password';
    return v!.length > 128 ? 'Password is too long (max 128)' : null;
  }

  static String? newPassword(String? v) {
    final s = v ?? '';
    if (s.isEmpty) return 'Password is required';
    if (s.length < 8) return 'At least 8 characters';
    if (s.length > 64) return 'At most 64 characters';
    if (s.contains(RegExp(r'\s'))) return 'No spaces allowed';
    if (!s.contains(RegExp('[a-z]'))) return 'Add a lowercase letter';
    if (!s.contains(RegExp('[A-Z]'))) return 'Add an uppercase letter';
    if (!s.contains(RegExp(r'\d'))) return 'Add a number';
    if (!s.contains(RegExp(r'[^A-Za-z0-9]'))) return r'Add a symbol like @ # $ !';
    return null;
  }

  static String? Function(String?) confirm(String Function() original) => (v) => (v ?? '').isEmpty ? 'Confirm your password' : v == original() ? null : 'Passwords do not match';

  static String? name(String? v, [String what = 'Name']) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return '$what is required';
    if (s.length < 2) return '$what must be at least 2 characters';
    return s.length > 80 ? '$what is too long' : null;
  }

  /// National number for the chosen country (digits only, no country code).
  static String? Function(String?) phone(Country Function() c) => (v) {
        final d = (v ?? '').replaceAll(RegExp(r'\D'), '');
        final country = c();
        if (d.isEmpty) return 'Phone number is required';
        if (country.iso == 'IN' && !RegExp(r'^[6-9]').hasMatch(d)) return 'Indian mobile numbers start with 6, 7, 8 or 9';
        if (d.length < country.min || d.length > country.max) {
          return country.min == country.max ? '${country.name} numbers have ${country.min} digits' : '${country.name} numbers have ${country.min}–${country.max} digits';
        }
        return null;
      };

  static String? Function(String?) text(String what, int min, int max) => (v) {
        final s = (v ?? '').trim();
        if (s.isEmpty) return '$what is required';
        if (s.length < min) return '$what must be at least $min characters';
        return s.length > max ? '$what must be at most $max characters' : null;
      };

  static String? zip(String? v) => RegExp(r'^[A-Za-z0-9][A-Za-z0-9 -]{2,10}$').hasMatch((v ?? '').trim()) ? null : 'Enter a valid zip / postal code';

  /// Technicians must be adults (18+) and not absurdly old.
  static String? dob(DateTime? d) {
    if (d == null) return 'Date of birth is required';
    final age = DateTime.now().difference(d).inDays / 365.25;
    return age < 18 ? 'Technician must be 18 or older' : age > 90 ? 'Check the date of birth' : null;
  }

  // Government IDs: optional; the format is only checked when something is entered.
  static String? _id(String? v, RegExp rx, String msg) {
    final s = (v ?? '').trim().toUpperCase();
    return s.isEmpty || rx.hasMatch(s) ? null : msg;
  }

  static String? gstin(String? v) => _id(v, RegExp(r'^(0[1-9]|[1-2]\d|3[0-8])[A-Z]{5}\d{4}[A-Z][1-9A-Z]Z[0-9A-Z]$'), 'Enter a valid 15-character GSTIN, e.g. 22AAAAA0000A1Z5');
  static String? pan(String? v) => _id(v, RegExp(r'^[A-Z]{5}\d{4}[A-Z]$'), 'Enter a valid 10-character PAN, e.g. ABCDE1234F');
  static String? cin(String? v) => _id(v, RegExp(r'^[LU]\d{5}[A-Z]{2}\d{4}[A-Z]{3}\d{6}$'), 'Enter a valid 21-character CIN, e.g. U12345MH2020PTC123456');
  static String? udyam(String? v) => _id(v, RegExp(r'^UDYAM-[A-Z]{2}-\d{2}-\d{7}$'), 'Enter a valid Udyam number, e.g. UDYAM-MH-12-1234567');

  /// A GSTIN contains the PAN (characters 3 to 12), so when both are given they must agree.
  static String? panMatchesGstin(String? pan, String gstin) {
    final p = (pan ?? '').trim().toUpperCase(), g = gstin.trim().toUpperCase();
    return p.isNotEmpty && g.length == 15 && g.substring(2, 12) != p ? 'PAN does not match the GSTIN' : null;
  }

  static String? otp(String? v) => RegExp(r'^\d{6}$').hasMatch(v ?? '') ? null : 'Enter the 6-digit code';

  /// Email or phone, for the authenticator sign-in where either identifies the account.
  static String? emailOrPhone(String? v) {
    final s = (v ?? '').trim();
    if (s.isEmpty) return 'Email or phone is required';
    if (s.contains('@')) return email(s);
    final d = s.replaceAll(RegExp(r'[\s-]'), '');
    return RegExp(r'^\+?\d{6,15}$').hasMatch(d) ? null : 'Enter a valid email or phone with country code';
  }
}
