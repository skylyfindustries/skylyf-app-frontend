/// Static demo data so the app can be shown to a client with no backend.
/// Mirrors the API JSON shapes and the multi-tenant rules the real backend will enforce:
///   customer   → only the machines of their own company (2–3 each)
///   technician → only the customers they are assigned to, and only tasks given to them
///   owner      → everything, and can manage (assign machines / technicians)
/// Switch off with --dart-define=USE_API=true.
library;

const _now = '2026-09-24T10:00:00.000Z';

// ---------- who is signed in (chosen at login by the email used) ----------
String _role = 'customer';
String _uid = 'u1'; // user id: u1..u4 customers, tech1..tech3 technicians, owner
String _cid = 'c1'; // customer's company

void mockLogin(String identifier) {
  final id = identifier.toLowerCase();
  if (id.contains('owner') || id.contains('admin')) {
    _role = 'admin';
    _uid = 'owner';
  } else if (id.contains('tech')) {
    _role = 'technician';
    _uid = id.contains('tech2') ? 'tech2' : id.contains('tech3') ? 'tech3' : 'tech1';
  } else {
    _role = 'customer';
    _cid = id.contains('delta') ? 'c2' : id.contains('greencup') ? 'c3' : 'c1';
    _uid = _cid == 'c2' ? 'u3' : _cid == 'c3' ? 'u4' : 'u1';
  }
}

// ---------- tenants ----------
final _companies = <Map<String, dynamic>>[
  {'id': 'c1', 'name': 'ABC INDUSTRIES', 'city': 'Noida'},
  {'id': 'c2', 'name': 'DELTA TISSUE MILLS', 'city': 'Surat'},
  {'id': 'c3', 'name': 'GREENCUP PACKAGING', 'city': 'Pune'},
];

final _technicians = <Map<String, dynamic>>[
  {'id': 'tech1', 'name': 'Amit Verma', 'phone': '+91 98100 11111', 'email': 'tech@skylyf.com'},
  {'id': 'tech2', 'name': 'Ravi Kumar', 'phone': '+91 98100 22222', 'email': 'tech2@skylyf.com'},
  {'id': 'tech3', 'name': 'Sana Khan', 'phone': '+91 98100 33333', 'email': 'tech3@skylyf.com'},
];

/// company id → technician ids the owner assigned to that customer
final _assign = <String, Set<String>>{
  'c1': {'tech1', 'tech2'},
  'c2': {'tech1', 'tech3'},
  'c3': {'tech3'},
};

final _users = <Map<String, dynamic>>[
  {'id': 'u1', 'name': 'Rahul Sharma', 'email': 'customer@abc.com', 'role': 'customer', 'companyId': 'c1'},
  {'id': 'u2', 'name': 'Priya Nair', 'email': 'priya@abc.com', 'role': 'customer', 'companyId': 'c1'},
  {'id': 'u3', 'name': 'Karan Shah', 'email': 'karan@deltatissue.com', 'role': 'customer', 'companyId': 'c2'},
  {'id': 'u4', 'name': 'Meera Joshi', 'email': 'meera@greencup.in', 'role': 'customer', 'companyId': 'c3'},
];

Map<String, dynamic>? _company(String? id) => id == null ? null : _companies.where((c) => c['id'] == id).firstOrNull;

// ---------- machines ----------
const _types = {
  'paper_cup': ('Paper Cup', 'SKY-PC 180', 'Cups/min', 'Cups', 180),
  'tissue': ('Tissue', 'SKY-TS 650', 'm/min', 'm', 650),
};

Map<String, dynamic> _machine(String? cid, String type, String code, String status, int i, {String? id}) {
  final (name, model, unitS, unitO, base) = _types[type]!;
  final prod = status == 'running' ? 4200 + (i * 173 % 700) : status == 'stopped' ? 2600 + (i * 91 % 500) : 3600 + (i * 57 % 300);
  final run = status == 'running' ? 560 - (i * 11 % 40) : status == 'stopped' ? 250 : 390;
  final down = 600 - run;
  final avail = (run / 6).round();
  final perfPct = status == 'running' ? 90 + (i * 3 % 8) : 60;
  final qual = 96 + (i % 4);
  final unitShort = unitS.split('/').first;
  return {
    'id': id ?? (cid == null ? 'u-$code' : cid == 'c1' ? code : '$cid-$code'),
    'companyId': cid,
    'company': _company(cid)?['name'],
    'plantId': 'p1',
    'code': code,
    'model': model,
    'typeKey': type,
    'typeName': name,
    'speedUnit': unitS,
    'outputUnit': unitO,
    'status': status,
    'speed': status == 'running' ? base + (i * 7 % 11) - 5 : 0,
    'todayProduction': prod,
    'todayTarget': 5000,
    'efficiency': (prod / 50).round(),
    'lastSeenAt': _now,
    'info': {
      'serial': 'SKY-${type == 'tissue' ? 'TS' : 'PC'}-23${(i % 12 + 1).toString().padLeft(2, '0')}-${(140 + i * 7).toString().padLeft(4, '0')}',
      'installedOn': '2023-${(i % 12 + 1).toString().padLeft(2, '0')}-1${i % 9}',
      'warrantyUntil': '2027-${(i % 12 + 1).toString().padLeft(2, '0')}-1${i % 9}',
      'lastService': '2026-08-${(i % 20 + 1).toString().padLeft(2, '0')}',
      'nextService': '2026-11-${(i % 20 + 1).toString().padLeft(2, '0')}',
      'availability': avail,
      'performance': perfPct,
      'quality': qual,
      'runtimeMin': run,
      'downtimeMin': down,
      'rejects': (prod * (100 - qual) / 100).round(),
      'hourly': [for (var h = 0; h < 10; h++) status == 'stopped' && h > 5 ? 0 : (prod / 10 * (0.85 + ((h * 7 + i) % 5) * 0.06)).round()],
      'events': status == 'running'
          ? [
              {'time': '09:42', 'text': 'Speed adjusted to $base $unitShort/min', 'status': 'running'},
              {'time': '08:15', 'text': 'Production resumed after break', 'status': 'running'},
              {'time': '07:58', 'text': 'Paused: operator break', 'status': 'idle'},
              {'time': '06:02', 'text': 'Shift A started', 'status': 'running'},
            ]
          : status == 'stopped'
              ? [
                  {'time': '09:14', 'text': 'Machine stopped: fault detected', 'status': 'stopped'},
                  {'time': '07:30', 'text': 'Speed dropped below target', 'status': 'idle'},
                  {'time': '06:02', 'text': 'Shift A started', 'status': 'running'},
                ]
              : [
                  {'time': '09:40', 'text': 'Waiting for material', 'status': 'idle'},
                  {'time': '06:02', 'text': 'Shift A started', 'status': 'running'},
                ],
    },
  };
}

/// 2–3 machines per customer; four more sit unassigned in the owner's pool.
final _machines = <Map<String, dynamic>>[
  _machine('c1', 'paper_cup', 'PC-01', 'running', 1),
  _machine('c1', 'paper_cup', 'PC-02', 'stopped', 2),
  _machine('c1', 'tissue', 'T-01', 'running', 3),
  _machine('c2', 'tissue', 'T-01', 'running', 4),
  _machine('c2', 'tissue', 'T-02', 'idle', 5),
  _machine('c2', 'tissue', 'T-03', 'stopped', 6),
  _machine('c3', 'paper_cup', 'PC-01', 'running', 7),
  _machine('c3', 'paper_cup', 'PC-02', 'running', 8),
  _machine(null, 'paper_cup', 'PC-07', 'idle', 9),
  _machine(null, 'tissue', 'T-07', 'running', 10),
  _machine(null, 'paper_cup', 'PC-08', 'running', 11),
  _machine(null, 'tissue', 'T-08', 'stopped', 12),
];
int _newId = 100;

Map<String, dynamic> _byId(String id) => _machines.firstWhere((m) => m['id'] == id, orElse: () => throw ApiExceptionDemo('Machine not found'));

/// The tenant rule: what the signed-in user is allowed to see.
List<Map<String, dynamic>> _visible() => [
      for (final m in _machines)
        if (_role == 'admin' || (_role == 'technician' && m['companyId'] != null && _assign[m['companyId']]!.contains(_uid)) || (_role == 'customer' && m['companyId'] == _cid)) m,
    ];

List<Map<String, dynamic>> _mine() => [for (final m in _machines) if (m['companyId'] == _cid) m];
Set<String> _myCompanies() => _role == 'admin' ? {for (final c in _companies) c['id'] as String} : {for (final e in _assign.entries) if (e.value.contains(_uid)) e.key};

// ---------- customer-side data ----------
final _acked = <String>{};

const _history = [
  {'note': 'Quarterly lubrication and belt check', 'type': 'history', 'status': 'done', 'createdAt': '2026-08-12T09:00:00.000Z'},
  {'note': 'Heater element replaced', 'type': 'history', 'status': 'done', 'createdAt': '2026-07-03T11:30:00.000Z'},
];

List<Map<String, dynamic>> _alerts() => [
      for (final (i, m) in _mine().where((m) => m['status'] == 'stopped').indexed)
        {'id': 'a-${m['id']}', 'machineId': m['id'], 'code': m['code'], 'type': 'stopped', 'message': '${m['code']} stopped', 'status': _acked.contains('a-${m['id']}') ? 'ack' : 'open', 'createdAt': DateTime.now().subtract(Duration(minutes: 12 + i * 47)).toUtc().toIso8601String()},
    ];

const _parts = [
  {'id': 101, 'name': 'Cup Forming Die', 'sku': 'PC-DIE-01', 'price': '12500', 't': 'paper_cup'},
  {'id': 102, 'name': 'Bottom Sealing Heater', 'sku': 'PC-HTR-02', 'price': '3200', 't': 'paper_cup'},
  {'id': 103, 'name': 'Cam Follower Set', 'sku': 'PC-CAM-03', 'price': '1800', 't': 'paper_cup'},
  {'id': 201, 'name': 'Embossing Roller', 'sku': 'T-EMB-01', 'price': '48000', 't': 'tissue'},
  {'id': 202, 'name': 'Perforation Blade Set', 'sku': 'T-BLD-02', 'price': '5400', 't': 'tissue'},
  {'id': 203, 'name': 'Rewinder Bearing', 'sku': 'T-BRG-03', 'price': '2100', 't': 'tissue'},
  {'id': 301, 'name': 'Servo Drive Belt', 'sku': 'GEN-BLT-01', 'price': '950', 't': ''},
];

// ---------- tasks (service requests): the customer picks the technician ----------
String _ago(int minutes) => DateTime.now().subtract(Duration(minutes: minutes)).toUtc().toIso8601String();

Map<String, dynamic> _ticket(String id, String machineId, String note, String priority, String status, String techId, int minutesAgo) {
  final m = _byId(machineId);
  return {
    'id': id,
    'machineId': machineId,
    'code': m['code'],
    'company': m['company'],
    'companyId': m['companyId'],
    'note': note,
    'priority': priority,
    'status': status,
    'technicianId': techId,
    'technician': _technicians.firstWhere((t) => t['id'] == techId)['name'],
    'createdAt': _ago(minutesAgo),
  };
}

final _tickets = <Map<String, dynamic>>[
  _ticket('t1', 'PC-02', 'Machine not starting after power cut', 'high', 'open', 'tech1', 35),
  _ticket('t2', 'c2-T-03', 'Rewinder jam, blade check needed', 'high', 'in_progress', 'tech1', 190),
  _ticket('t3', 'c3-PC-02', 'Heater temperature fluctuating', 'medium', 'open', 'tech3', 320),
  _ticket('t4', 'T-01', 'Unusual bearing noise', 'medium', 'open', 'tech2', 1500),
  _ticket('t5', 'c2-T-02', 'Scheduled service due', 'low', 'done', 'tech3', 4300),
  _ticket('t6', 'PC-01', 'Quarterly lubrication', 'low', 'done', 'tech1', 9000),
];

// ---------- registrations & catalog ----------
final _registrations = <Map<String, dynamic>>[
  {'id': 'r1', 'model': 'SKY-PC 250', 'typeKey': 'paper_cup', 'serial': 'SKY-PC-2609-0311', 'nickname': 'PC-03', 'status': 'pending', 'companyId': 'c1', 'company': 'ABC INDUSTRIES', 'createdAt': _ago(2880)},
  {'id': 'r2', 'model': 'SKY-TS 650', 'typeKey': 'tissue', 'serial': 'SKY-TS-2608-0207', 'nickname': 'T-04', 'status': 'pending', 'companyId': 'c2', 'company': 'DELTA TISSUE MILLS', 'createdAt': _ago(700)},
];

const _catalog = [
  {'id': 'cat1', 'name': 'Paper Cup Machine', 'model': 'SKY-PC 180', 'typeKey': 'paper_cup', 'tagline': 'Reliable all-rounder for 2 to 16 oz cups', 'speed': 'Up to 180 cups/min', 'specs': ['Cup size 2–16 oz', 'PE coated board 150–350 GSM', 'Auto lubrication', 'Power 18 kW']},
  {'id': 'cat2', 'name': 'Paper Cup Machine Pro', 'model': 'SKY-PC 250', 'typeKey': 'paper_cup', 'tagline': 'High-speed line with ultrasonic sealing', 'speed': 'Up to 250 cups/min', 'specs': ['Cup size 2–22 oz', 'Ultrasonic side sealing', 'Servo driven', 'Power 24 kW']},
  {'id': 'cat3', 'name': 'Tissue Rewinder', 'model': 'SKY-TS 650', 'typeKey': 'tissue', 'tagline': 'Embossing, perforation and rewinding', 'speed': 'Up to 650 m/min', 'specs': ['Log width 2.7 m', 'Edge embossing', 'Auto core loading', 'Power 45 kW']},
  {'id': 'cat4', 'name': 'Tissue Folding Line', 'model': 'SKY-TF 400', 'typeKey': 'tissue', 'tagline': 'Facial tissue folding and stacking', 'speed': 'Up to 400 m/min', 'specs': ['N-fold / V-fold', 'Inline counting', 'Touch-screen HMI', 'Power 32 kW']},
  {'id': 'cat5', 'name': 'Packaging Machine', 'model': 'SKY-PK 90', 'typeKey': 'other', 'tagline': 'Flow-wrap packing for finished goods', 'speed': 'Up to 90 packs/min', 'specs': ['Servo film feed', 'Date coder ready', 'Quick changeover', 'Power 9 kW']},
];

String _lang = 'en';

// ---------- computed views ----------
Map<String, int> _counts(Iterable<Map<String, dynamic>> ms) {
  final c = {'running': 0, 'stopped': 0, 'idle': 0};
  for (final m in ms) {
    c[m['status']] = c[m['status']]! + 1;
  }
  return c;
}

int _sum(Iterable<Map<String, dynamic>> ms, num Function(Map<String, dynamic>) f) => ms.fold<num>(0, (s, m) => s + f(m)).round();
int _avg(Iterable<Map<String, dynamic>> ms, num Function(Map<String, dynamic>) f) => ms.isEmpty ? 0 : (_sum(ms, f) / ms.length).round();

Map<String, dynamic> _dashboard() {
  final ms = _mine();
  final today = _sum(ms, (m) => m['todayProduction']);
  return {
    'counts': _counts(ms),
    'production': {'today': today, 'target': _sum(ms, (m) => m['todayTarget'])},
    'attention': [for (final m in ms.where((m) => m['status'] == 'stopped')) {'machineId': m['id'], 'code': m['code'], 'status': 'stopped'}],
    'stats': {
      'uptime': _avg(ms, (m) => m['info']['availability']),
      'efficiency': _avg(ms, (m) => m['efficiency']),
      'downtimeMin': _sum(ms, (m) => m['info']['downtimeMin']),
      'weekProduced': (today * 6.4).round(),
      'monthProduced': today * 26,
      'top': [
        for (final m in ([...ms]..sort((a, b) => (b['todayProduction'] as int).compareTo(a['todayProduction'] as int))).take(3))
          {'id': m['id'], 'code': m['code'], 'typeKey': m['typeKey'], 'value': m['todayProduction'], 'unit': m['outputUnit']},
      ],
    },
  };
}

Map<String, dynamic> _overview() {
  final ms = _visible();
  final mine = _myCompanies();
  return {
    'customers': mine.length,
    'machines': ms.length,
    'users': _users.length + _technicians.length + 1,
    'technicians': _technicians.length,
    'unassigned': _role == 'admin' ? _machines.where((m) => m['companyId'] == null).length : 0,
    'pending': _role == 'admin' ? _registrations.where((r) => r['status'] == 'pending').length : 0,
    'counts': _counts(ms),
    'attention': [for (final m in ms.where((m) => m['status'] == 'stopped')) {'machineId': m['id'], 'code': m['code'], 'status': 'stopped', 'company': m['company'] ?? 'Unassigned'}],
  };
}

Map<String, dynamic> _report(String range, String kind) {
  final ms = _mine();
  final total = _sum(ms, (m) => m['todayProduction']);
  final hourly = range == 'today';
  final n = hourly ? 11 : range == '7d' ? 7 : 30;
  final labels = hourly
      ? [for (var h = 0; h < n; h++) '${h.toString().padLeft(2, '0')}:00']
      : [for (var d = n - 1; d >= 0; d--) () { final t = DateTime(2026, 9, 24).subtract(Duration(days: d)); return '${t.day.toString().padLeft(2, '0')}/${t.month.toString().padLeft(2, '0')}'; }()];
  List<Map<String, dynamic>> series;
  String unit;
  if (kind == 'performance') {
    series = [for (final m in ms) {'label': m['code'], 'value': m['status'] == 'running' ? 88 + (m['efficiency'] as int) % 10 : m['status'] == 'idle' ? 68 : 41}]
      ..sort((a, b) => (b['value'] as int).compareTo(a['value'] as int));
    unit = '%';
  } else if (kind == 'downtime') {
    final day = _sum(ms, (m) => m['info']['downtimeMin']);
    series = [for (var i = 0; i < n; i++) {'label': labels[i], 'value': hourly ? 4 + (i * 7 % 14) : (day * (0.8 + (i * 13 % 30) / 100)).round()}];
    unit = 'min';
  } else {
    series = [for (var i = 0; i < n; i++) {'label': labels[i], 'value': hourly ? (total / 11 * (0.85 + (i * 37 % 30) / 100)).round() : (total * (0.9 + (i * 13 % 20) / 100)).round()}];
    unit = '';
  }
  final sum = series.fold<int>(0, (s, p) => s + (p['value'] as int));
  return {
    'range': range,
    'kind': kind,
    'unit': unit,
    'series': series,
    'summary': {'total': sum, 'average': series.isEmpty ? 0 : (sum / series.length).round()},
    if (kind == 'production')
      'byMachine': [for (final m in ms) {'label': m['code'], 'value': (m['todayProduction'] as int) * (range == 'today' ? 1 : range == '7d' ? 7 : 30), 'unit': m['outputUnit']}],
  };
}

Map<String, dynamic> _me() {
  if (_role == 'technician') {
    final t = _technicians.firstWhere((t) => t['id'] == _uid);
    return {'user': {'name': t['name'], 'email': t['email'], 'role': 'technician', 'language': _lang}, 'company': {'name': 'SKYLYF TECHNOLOGIES'}};
  }
  if (_role == 'admin') return {'user': {'name': 'Neha Kapoor', 'email': 'owner@skylyf.com', 'role': 'admin', 'language': _lang}, 'company': {'name': 'SKYLYF TECHNOLOGIES'}};
  final u = _users.firstWhere((u) => u['id'] == _uid);
  return {'user': {'name': u['name'], 'email': u['email'], 'role': 'customer', 'language': _lang}, 'company': {'name': _company(_cid)!['name']}};
}

Map<String, dynamic> _summary(Map<String, dynamic> c) {
  final ms = [for (final m in _machines) if (m['companyId'] == c['id']) m];
  final k = _counts(ms);
  return {...c, 'machines': ms.length, 'running': k['running'], 'stopped': k['stopped'], 'idle': k['idle'], 'technicians': _assign[c['id']]?.length ?? 0};
}

Map<String, dynamic> _customerDetail(String id) {
  final c = _company(id);
  if (c == null || !_myCompanies().contains(id)) throw ApiExceptionDemo('Customer not found');
  return {
    ..._summary(c),
    'machineList': [for (final m in _machines) if (m['companyId'] == id) m],
    'technicianList': [for (final t in _technicians) {'id': t['id'], 'name': t['name'], 'phone': t['phone'], 'assigned': _assign[id]!.contains(t['id'])}],
    'userList': [for (final u in _users) if (u['companyId'] == id) {'name': u['name'], 'email': u['email'], 'role': u['role'], 'company': c['name']}],
  };
}

void _needOwner() {
  if (_role != 'admin') throw ApiExceptionDemo('Only the owner can do this');
}

/// Same contract as Api.get/post/patch, answered from memory.
dynamic mockRequest(String method, String path, {Map<String, dynamic>? query, Map<String, dynamic>? body}) {
  final q = query ?? const {};
  final seg = path.split('/').where((s) => s.isNotEmpty).toList();
  switch ((method, seg.isEmpty ? '' : seg[0])) {
    case ('GET', 'me'):
      return _me();
    case ('PATCH', 'me'):
      _lang = body!['language'];
      return body;
    case ('GET', 'plants'):
      return [{'_id': 'p1', 'name': '${_company(_cid)?['city'] ?? 'Main'} Plant'}];
    case ('GET', 'dashboard'):
      return _dashboard();

    // ----- machines -----
    case ('GET', 'machines'):
      if (seg.length == 1) {
        final cid = q['companyId'];
        return [
          for (final m in _visible())
            if (cid == null || (cid == 'unassigned' ? m['companyId'] == null : m['companyId'] == cid)) m,
        ];
      }
      final m = _byId(seg[1]);
      if (!_visible().contains(m)) throw ApiExceptionDemo('Machine not found'); // tenant isolation
      if (seg.length == 2) {
        final p = m['todayProduction'] as int;
        return {...m, 'shifts': {'A': (p * .37).round(), 'B': (p * .40).round(), 'C': (p * .23).round()}};
      }
      // GET /machines/:id/maintenance → history + the tasks raised for this machine
      return [
        for (final t in _tickets.where((t) => t['machineId'] == m['id']))
          {'note': t['note'], 'type': 'request', 'status': t['status'], 'createdAt': t['createdAt'], 'technician': t['technician'], 'priority': t['priority']},
        ..._history,
      ];
    case ('POST', 'machines'):
      final b = body!;
      if (seg.length == 3) {
        // customer creates a task and MUST pick one of the technicians assigned to their company
        final m = _byId(seg[1]);
        if (m['companyId'] != _cid) throw ApiExceptionDemo('Machine not found');
        final techId = b['technicianId'] as String?;
        if (techId == null || !(_assign[_cid]?.contains(techId) ?? false)) throw ApiExceptionDemo('Choose one of your technicians');
        final tech = _technicians.firstWhere((t) => t['id'] == techId);
        final t = {'id': 't${_tickets.length + 1}', 'machineId': m['id'], 'code': m['code'], 'company': m['company'], 'companyId': m['companyId'], 'note': b['note'], 'priority': b['priority'] ?? 'medium', 'status': 'open', 'technicianId': techId, 'technician': tech['name'], 'createdAt': DateTime.now().toUtc().toIso8601String()};
        _tickets.insert(0, t);
        return t;
      }
      // owner adds a machine
      _needOwner();
      final code = (b['code'] as String).trim();
      final type = b['typeKey'] as String;
      final m = _machine(b['companyId'] as String?, type == 'other' ? 'paper_cup' : type, code, 'idle', _newId, id: 'n${_newId++}');
      m
        ..['speed'] = 0
        ..['todayProduction'] = 0
        ..['efficiency'] = 0;
      (m['info'] as Map)['serial'] = b['serial'];
      _machines.add(m);
      return m;
    case ('PATCH', 'machines'):
      _needOwner();
      final m = _byId(seg[1]);
      final cid = body!['companyId'] as String?;
      m['companyId'] = cid;
      m['company'] = _company(cid)?['name'];
      return m;

    // ----- tasks -----
    case ('GET', 'tasks'):
      return [for (final t in _tickets) if (t['companyId'] == _cid) t];
    case ('GET', 'tickets'):
      return [for (final t in _tickets) if (_role == 'admin' || t['technicianId'] == _uid) t];
    case ('PATCH', 'tickets'):
      final t = _tickets.firstWhere((t) => t['id'] == seg[1]);
      if (body!['status'] != null) t['status'] = body['status'];
      if (body['technicianId'] != null) {
        _needOwner();
        t['technicianId'] = body['technicianId'];
        t['technician'] = _technicians.firstWhere((x) => x['id'] == body['technicianId'])['name'];
      }
      return t;
    // the owner (customer role) adds / removes technicians of their own company only
    case ('POST', 'technicians'):
      final tech = {'id': 'tech${_technicians.length + 1}', 'name': body!['name'], 'phone': body['phone'] ?? '', 'email': ''};
      _technicians.add(tech);
      _assign[_cid]!.add(tech['id'] as String);
      return {'id': tech['id'], 'name': tech['name'], 'phone': tech['phone']};
    case ('DELETE', 'technicians'):
      if (!(_assign[_cid]?.remove(seg[1]) ?? false)) throw ApiExceptionDemo('Technician not found');
      if (!_assign.values.any((s) => s.contains(seg[1]))) _technicians.removeWhere((t) => t['id'] == seg[1]);
      return {'deleted': true};
    case ('GET', 'technicians'):
      if (_role == 'customer') {
        return [for (final t in _technicians) if (_assign[_cid]!.contains(t['id'])) {'id': t['id'], 'name': t['name'], 'phone': t['phone']}];
      }
      return [
        for (final t in _technicians)
          {'id': t['id'], 'name': t['name'], 'phone': t['phone'], 'companies': [for (final e in _assign.entries) if (e.value.contains(t['id'])) _company(e.key)!['name']]},
      ];

    // ----- customers (tenants) -----
    case ('GET', 'customers'):
      if (seg.length == 2) return _customerDetail(seg[1]);
      return [for (final c in _companies) if (_myCompanies().contains(c['id'])) _summary(c)];
    case ('POST', 'customers'):
      _needOwner();
      final c = {'id': 'c${_companies.length + 1}', 'name': (body!['name'] as String).trim().toUpperCase(), 'city': (body['city'] as String).trim()};
      _companies.add(c);
      _assign[c['id'] as String] = {};
      return _summary(c);
    case ('PATCH', 'customers'):
      _needOwner();
      _assign[seg[1]] = {for (final id in body!['technicianIds'] as List) id as String};
      return _customerDetail(seg[1]);

    // ----- reports / alerts / parts / orders -----
    case ('GET', 'reports'):
      return _report(q['range'] ?? 'today', q['kind'] ?? 'production');
    case ('GET', 'alerts'):
      return _alerts();
    case ('PATCH', 'alerts'):
      _acked.add(seg[1]);
      return {'id': seg[1], 'status': 'ack'};
    case ('GET', 'parts'):
      final type = q['machineId'] == null ? null : _byId(q['machineId'])['typeKey'];
      final needle = (q['q'] as String?)?.toLowerCase();
      return [
        for (final p in _parts)
          if ((type == null || p['t'] == '' || p['t'] == type) && (needle == null || (p['name'] as String).toLowerCase().contains(needle) || (p['sku'] as String).toLowerCase().contains(needle)))
            {'id': p['id'], 'name': p['name'], 'sku': p['sku'], 'price': p['price']},
      ];
    case ('POST', 'orders'):
      return {'orderId': 'SKY-${1000 + DateTime.now().second}', 'checkoutUrl': null};

    // ----- register machines -----
    case ('GET', 'catalog'):
      return _catalog;
    case ('GET', 'registrations'):
      return [for (final r in _registrations) if (_role == 'admin' || r['companyId'] == _cid) r];
    case ('POST', 'registrations'):
      final b = body!;
      final item = _catalog.firstWhere((c) => c['id'] == b['catalogId']);
      _registrations.insert(0, {'id': 'r${_registrations.length + 1}', 'model': item['model'], 'typeKey': item['typeKey'], 'serial': b['serial'], 'nickname': b['nickname'], 'status': 'pending', 'companyId': _cid, 'company': _company(_cid)!['name'], 'createdAt': DateTime.now().toUtc().toIso8601String()});
      return _registrations.first;
    case ('PATCH', 'registrations'):
      _needOwner();
      final r = _registrations.firstWhere((r) => r['id'] == seg[1]);
      r['status'] = body!['status'];
      if (body['status'] == 'approved') {
        final m = _machine(r['companyId'] as String, r['typeKey'] == 'other' ? 'paper_cup' : r['typeKey'] as String, r['nickname'] as String, 'idle', _newId, id: 'n${_newId++}');
        m
          ..['speed'] = 0
          ..['todayProduction'] = 0
          ..['efficiency'] = 0;
        (m['info'] as Map)['serial'] = r['serial'];
        _machines.add(m);
      }
      return r;

    case ('POST', 'auth'): // POST /auth/password
      if ((body!['newPassword'] as String).length < 8) throw ApiExceptionDemo('Password must be at least 8 characters');
      return {'changed': true};

    // ----- owner / technician overview, team -----
    case ('GET', 'overview'):
      return _overview();
    case ('GET', 'users'):
      return [
        for (final u in _users) {'name': u['name'], 'email': u['email'], 'role': 'customer', 'company': _company(u['companyId'])!['name']},
        for (final t in _technicians) {'name': t['name'], 'email': t['email'], 'role': 'technician', 'company': 'Serves ${[for (final e in _assign.entries) if (e.value.contains(t['id'])) _company(e.key)!['name']].join(', ')}'},
        {'name': 'Neha Kapoor', 'email': 'owner@skylyf.com', 'role': 'admin', 'company': 'SKYLYF TECHNOLOGIES'},
      ];
  }
  throw StateError('No demo data for $method $path');
}

/// Thrown by the demo layer for validation / permission errors; Api rewraps it as ApiException.
class ApiExceptionDemo implements Exception {
  ApiExceptionDemo(this.message);
  final String message;
}
