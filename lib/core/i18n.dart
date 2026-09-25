import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'providers.dart';

class LangNotifier extends Notifier<String> {
  @override
  String build() => 'en';

  /// Local change first, server sync best-effort.
  Future<void> set(String lang) async {
    state = lang;
    try {
      await ref.read(apiProvider).patch('/me', {'language': lang});
    } catch (_) {}
  }

  void setFromServer(String lang) => state = lang;
}

final langProvider = NotifierProvider<LangNotifier, String>(LangNotifier.new);

const _hi = {
  'Home': 'होम', 'Machines': 'मशीनें', 'Reports': 'रिपोर्ट', 'Parts': 'पार्ट्स', 'Profile': 'प्रोफ़ाइल',
  'Running': 'चालू', 'Stopped': 'बंद', 'Idle': 'खाली', 'Attention': 'ध्यान दें',
  "Today's Production": 'आज का उत्पादन', 'ALL': 'सभी', 'PAPER CUP': 'पेपर कप', 'TISSUE': 'टिश्यू', 'OTHER': 'अन्य',
  'Speed': 'गति', 'Production': 'उत्पादन', 'Target': 'लक्ष्य', 'Efficiency': 'दक्षता',
  'Maintenance': 'रखरखाव', 'Today': 'आज', '7 Days': '7 दिन', '30 Days': '30 दिन',
  'Downtime': 'डाउनटाइम', 'Machine Performance': 'मशीन प्रदर्शन', 'Alerts': 'अलर्ट', 'Logout': 'लॉग आउट',
  'Language': 'भाषा', 'Buy': 'खरीदें', 'Login': 'लॉगिन', 'Request service': 'सेवा का अनुरोध करें',
  'Total': 'कुल', 'Average': 'औसत', 'All machines OK': 'सभी मशीनें ठीक हैं',
};

/// Tiny EN/HI lookup — unknown keys fall back to English.
final trProvider = Provider<String Function(String)>((ref) {
  final hi = ref.watch(langProvider) == 'hi';
  return (s) => hi ? (_hi[s] ?? s) : s;
});
