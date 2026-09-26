/// Structured machine specification (ranges), mirrors backend/src/utils/spec.js.
///   cup:    size range (oz | ml), max height (mm), speed range, paper GSM range + PE coating
///   tissue: size range (mm | cm), speed range, GSM range
///   other:  speed range
class Spec {
  const Spec({this.sizeMin, this.sizeMax, this.sizeUnit, this.maxHeightMm, this.speedMin, this.speedMax, this.speedPer, this.gsmMin, this.gsmMax, this.coating});

  final num? sizeMin, sizeMax, maxHeightMm, speedMin, speedMax, gsmMin, gsmMax;
  final String? sizeUnit, speedPer, coating; // speedPer: min | hr | day

  static Spec? fromJson(Object? j) {
    if (j is! Map || j.isEmpty) return null;
    final size = j['size'] as Map?, speed = j['speed'] as Map?, gsm = j['gsm'] as Map?;
    return Spec(
      sizeMin: size?['min'], sizeMax: size?['max'], sizeUnit: size?['unit'], maxHeightMm: j['maxHeightMm'],
      speedMin: speed?['min'], speedMax: speed?['max'], speedPer: speed?['per'],
      gsmMin: gsm?['min'], gsmMax: gsm?['max'], coating: j['coating'],
    );
  }

  bool get hasSize => sizeMin != null && sizeMax != null;
  bool get hasSpeed => speedMin != null && speedMax != null && speedPer != null;
  bool get hasGsm => gsmMin != null && gsmMax != null;

  static const perName = {'min': 'per minute', 'hr': 'per hour', 'day': 'per day'};
  static const coatingName = {'single': 'Single PE coated', 'double': 'Double PE coated', 'either': 'Single or double PE coated', 'none': 'Uncoated'};

  static String n(num v) {
    if (v == v.roundToDouble()) return v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
    return double.parse(v.toStringAsFixed(2)).toString();
  }

  /// "3 – 16" (or just "3" when min equals max)
  static String range(num a, num b) => a == b ? n(a) : '${n(a)} – ${n(b)}';

  String? get sizeText => hasSize ? '${range(sizeMin!, sizeMax!)} $sizeUnit' : null;
  String? get gsmText => hasGsm ? '${range(gsmMin!, gsmMax!)} GSM' : null;
  String? speedText(String typeKey) => hasSpeed ? '${range(speedMin!, speedMax!)} ${nounFor(typeKey)}/$speedPer' : null;

  /// The speed range expressed per minute, per hour or per day (whatever unit it was entered in).
  (int, int)? speedIn(String per) {
    if (!hasSpeed) return null;
    num toMin(num v) => switch (speedPer) { 'hr' => v / 60, 'day' => v / 1440, _ => v };
    num to(num perMinute) => switch (per) { 'hr' => perMinute * 60, 'day' => perMinute * 1440, _ => perMinute };
    return (to(toMin(speedMin!)).round(), to(toMin(speedMax!)).round());
  }
}

String nounFor(String typeKey) => switch (typeKey) { 'paper_cup' => 'cups', 'tissue' => 'tissues', _ => 'units' };

String sizeLabelFor(String typeKey) => switch (typeKey) { 'paper_cup' => 'Cup size', 'tissue' => 'Tissue size', _ => 'Size' };
