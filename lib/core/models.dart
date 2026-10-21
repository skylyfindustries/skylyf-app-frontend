import 'spec.dart';
import 'role.dart';

class Machine {
  Machine({
    required this.id, required this.code, required this.typeKey, required this.typeName,
    required this.status, required this.speed, required this.speedUnit, required this.outputUnit,
    required this.todayProduction, required this.todayTarget, required this.efficiency,
    this.model = '', this.company, this.companyId, this.shifts, this.info,
    this.name = '', this.description = '', this.productionSpeed = '', this.cupSize = '', this.paperRequired = '', this.price, this.photos = const [], this.lastSeenAt, this.spec, this.serial = '',
    this.todayPackages = 0, this.startCount = 0, this.stopCount = 0, this.vfdFrequency = 0, this.machineRuntime = 0, this.countInterval = 0,
  });

  final String id, code, typeKey, typeName, status, speedUnit, outputUnit, model;
  final String name, description, productionSpeed, cupSize, paperRequired; // product details entered in the dashboard
  final num? price; // set in the dashboard; null = not priced yet
  final List<String> photos; // paths like /api/v1/uploads/x.jpg (see photoUrl)
  final DateTime? lastSeenAt; // last data received from the machine
  final String serial; // nameplate serial number
  final Spec? spec; // structured size / speed / paper ranges (null on older machines: the text fields still work)
  final String? company, companyId; // set for staff roles; null = not assigned to a customer yet
  final num speed, todayProduction, todayTarget, efficiency;
  final num todayPackages, startCount, stopCount; // from the PLC (MQTT): packages completed, start / stop counters
  final num vfdFrequency, machineRuntime, countInterval; // more PLC readings, raw values
  final Map<String, num>? shifts; // only on the detail endpoint
  final MachineInfo? info; // only on the detail endpoint

  factory Machine.fromJson(Map<String, dynamic> j) => Machine(
        id: j['id'],
        code: j['code'],
        typeKey: j['typeKey'],
        typeName: j['typeName'],
        model: j['model'] ?? '',
        name: j['name'] ?? '',
        description: j['description'] ?? '',
        productionSpeed: j['productionSpeed'] ?? '',
        cupSize: j['cupSize'] ?? '',
        paperRequired: j['paperRequired'] ?? '',
        price: j['price'],
        photos: [for (final p in (j['photos'] as List? ?? const [])) p as String],
        spec: Spec.fromJson(j['spec']),
        serial: j['serial'] ?? '',
        lastSeenAt: j['lastSeenAt'] == null ? null : DateTime.tryParse('${j['lastSeenAt']}')?.toLocal(),
        company: j['company'],
        companyId: j['companyId'],
        status: j['status'],
        speed: j['speed'],
        speedUnit: j['speedUnit'],
        outputUnit: j['outputUnit'],
        todayProduction: j['todayProduction'],
        todayTarget: j['todayTarget'],
        efficiency: j['efficiency'],
        todayPackages: j['todayPackages'] ?? 0,
        startCount: j['startCount'] ?? 0,
        stopCount: j['stopCount'] ?? 0,
        vfdFrequency: j['vfdFrequency'] ?? 0,
        machineRuntime: j['machineRuntime'] ?? 0,
        countInterval: j['countInterval'] ?? 0,
        shifts: (j['shifts'] as Map?)?.map((k, v) => MapEntry(k as String, v as num)),
        info: j['info'] == null ? null : MachineInfo.fromJson(j['info']),
      );

  String get statusLabel => switch (status) { 'running' => 'Running', 'stopped' => 'Stopped', _ => 'Idle' };
}

class Attention {
  Attention(this.machineId, this.code, this.status, {this.company});
  final String machineId, code, status;
  final String? company;
}

class Dashboard {
  Dashboard({required this.running, required this.stopped, required this.idle, required this.today, required this.target, required this.attention, this.packagesToday = 0, this.stats = const Stats()});
  final int running, stopped, idle;
  final num today, target, packagesToday; // packagesToday = packages completed today, all machines
  final List<Attention> attention;
  final Stats stats;

  double get progress => target == 0 ? 0 : (today / target).clamp(0, 1).toDouble();

  factory Dashboard.fromJson(Map<String, dynamic> j) => Dashboard(
        running: j['counts']['running'],
        stopped: j['counts']['stopped'],
        idle: j['counts']['idle'],
        today: j['production']['today'],
        target: j['production']['target'],
        attention: [for (final a in j['attention']) Attention(a['machineId'], a['code'], a['status'])],
        packagesToday: j['packages']?['today'] ?? 0,
        stats: j['stats'] == null ? const Stats() : Stats.fromJson(j['stats']),
      );
}

class Plant {
  Plant(this.id, this.name);
  final String id, name;
  factory Plant.fromJson(Map<String, dynamic> j) => Plant(j['_id'], j['name']);
}

class Me {
  Me({required this.name, required this.email, required this.company, required this.language, this.role = 'customer', this.phone = '', this.photo, this.address = '', this.loginEmail = '', this.shift = '', this.street = '', this.city = '', this.state = '', this.zip = '', this.gstin = '', this.pan = '', this.cin = '', this.udyam = ''});
  final String name, email, company, language, role, phone, address, loginEmail; // email = what to show (email, else phone); loginEmail = the real email or ''
  final String shift; // technicians: "09:00 – 18:00" (set in the dashboard), else ''
  final String street, city, state, zip, gstin, pan, cin, udyam; // company address parts and government IDs (all optional)
  final String? photo; // path like /api/v1/uploads/x.jpg (see photoUrl)
  factory Me.fromJson(Map<String, dynamic> j) => Me(
        name: j['user']['name'] ?? '',
        email: j['user']['email'] ?? j['user']['phone'] ?? '',
        loginEmail: j['user']['email'] ?? '',
        phone: j['user']['phone'] ?? '',
        photo: j['user']['photo'],
        company: j['company']['name'] ?? '',
        address: j['company']['address'] ?? '',
        shift: (j['user']['shift'] is Map && (j['user']['shift']['start'] ?? '') != '') ? '${j['user']['shift']['start']} – ${j['user']['shift']['end']}' : '',
        street: j['company']['location']?['street'] ?? '',
        city: j['company']['location']?['city'] ?? '',
        state: j['company']['location']?['state'] ?? '',
        zip: j['company']['location']?['zip'] ?? '',
        gstin: j['company']['gstin'] ?? '',
        pan: j['company']['pan'] ?? '',
        cin: j['company']['cin'] ?? '',
        udyam: j['company']['udyam'] ?? '',
        language: j['user']['language'] ?? 'en',
        role: j['user']['role'] ?? 'customer',
      );
}

/// One machine given to one technician for one day.
/// One change of a task's stage: who did it, when, and an optional note.
class AssignmentEvent {
  AssignmentEvent({required this.status, required this.at, this.from, this.byName = '', this.role = '', this.note = ''});
  final String status, byName, role, note; // role: technician | customer (owner)
  final String? from; // null for the first entry ("assigned")
  final DateTime at;
  factory AssignmentEvent.fromJson(Map<String, dynamic> j) => AssignmentEvent(
        status: j['status'], from: j['from'], byName: j['byName'] ?? '', role: j['role'] ?? '', note: j['note'] ?? '', at: DateTime.parse(j['at']).toLocal(),
      );
}

class Assignment {
  Assignment({required this.id, required this.date, required this.machineId, required this.code, required this.machine, required this.technicianId, required this.technician, required this.status, this.note = '', this.history = const []});
  final String id, date, machineId, code, machine, technicianId, technician, status, note; // status: assigned | started | running | done
  final List<AssignmentEvent> history; // oldest first
  bool get done => status == 'done';
  bool get working => status == 'started' || status == 'running';
  factory Assignment.fromJson(Map<String, dynamic> j) => Assignment(
        id: j['id'], date: j['date'], machineId: j['machineId'], code: j['code'] ?? '', machine: j['machine'] ?? '',
        technicianId: j['technicianId'], technician: j['technician'] ?? '', status: j['status'], note: j['note'] ?? '',
        history: [for (final h in (j['history'] as List? ?? const [])) AssignmentEvent.fromJson(h)],
      );
}

class ReportData {
  ReportData({required this.series, required this.unit, required this.total, required this.average, this.byMachine = const []});
  final List<({String label, num value})> series;
  final List<({String label, num value, String unit})> byMachine; // production report only
  final String unit;
  final num total, average;
  factory ReportData.fromJson(Map<String, dynamic> j) => ReportData(
        series: [for (final p in j['series']) (label: p['label'] as String, value: p['value'] as num)],
        unit: j['unit'],
        total: j['summary']['total'],
        average: j['summary']['average'],
        byMachine: [for (final m in (j['byMachine'] as List? ?? const [])) (label: m['label'] as String, value: m['value'] as num, unit: m['unit'] as String)],
      );
}

class AlertItem {
  AlertItem({required this.id, required this.machineId, required this.code, required this.message, required this.status, required this.createdAt, this.type = ''});
  final String id, message, status, type;
  final String? machineId, code;
  final DateTime createdAt;
  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'],
        machineId: j['machineId'],
        code: j['code'],
        message: j['message'],
        type: j['type'] ?? '',
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class Part {
  Part({required this.id, required this.name, required this.sku, required this.price, this.description = '', this.image, this.stock = 0, this.images = const [], this.categories = const [], this.shortDescription = '', this.regularPrice = 0, this.onSale = false, this.attributes = const [], this.weight = '', this.dimensions = '', this.tags = const [], this.brands = const [], this.content = const []});
  final String id, name, sku, description, shortDescription, weight, dimensions;
  final num price, regularPrice;
  final bool onSale;
  final List<String> images, categories, tags, brands;
  final List<({String name, String value})> attributes;
  final List<Map<String, dynamic>> content; // description blocks: {t: h|sub|p|ul|table|hr, ...}
  final int stock;
  final String? image; // path like /api/v1/uploads/x.jpg (see photoUrl)
  bool get inStock => stock > 0;
  factory Part.fromJson(Map<String, dynamic> j) => Part(id: j['id'], name: j['name'], sku: j['sku'] ?? '', price: j['price'] ?? 0, description: j['description'] ?? '', image: j['image'], stock: j['stock'] ?? 0,
        images: [for (final i in (j['images'] as List? ?? const [])) '$i'], categories: [for (final c in (j['categories'] as List? ?? const [])) '$c'],
        shortDescription: j['shortDescription'] ?? '', regularPrice: j['regularPrice'] ?? 0, onSale: j['onSale'] ?? false,
        attributes: [for (final a in (j['attributes'] as List? ?? const [])) (name: '${a['name']}', value: '${a['value']}')],
        weight: j['weight'] ?? '', dimensions: j['dimensions'] ?? '',
        tags: [for (final t in (j['tags'] as List? ?? const [])) '$t'], brands: [for (final b in (j['brands'] as List? ?? const [])) '$b'],
        content: [for (final b in (j['content'] as List? ?? const [])) Map<String, dynamic>.from(b as Map)]);
}

class Ticket {
  Ticket({required this.note, required this.type, required this.status, required this.createdAt, this.technician, this.priority});
  final String note, type, status; // status: open | in_progress | done
  final String? technician, priority;
  final DateTime createdAt;
  factory Ticket.fromJson(Map<String, dynamic> j) => Ticket(
        note: j['note'] ?? '',
        type: j['type'],
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        technician: j['technician'],
        priority: j['priority'],
      );
}

class StaffTicket {
  StaffTicket({required this.id, required this.machineId, required this.code, required this.company, required this.note, required this.priority, required this.status, required this.createdAt, this.technician, this.technicianId});
  final String id, machineId, code, company, note, priority, status; // status: open | in_progress | done
  final String? technician, technicianId; // who the customer asked for
  final DateTime createdAt;
  factory StaffTicket.fromJson(Map<String, dynamic> j) => StaffTicket(
        id: j['id'],
        machineId: j['machineId'],
        code: j['code'],
        company: j['company'],
        note: j['note'],
        priority: j['priority'],
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
        technician: j['technician'],
        technicianId: j['technicianId'],
      );
}

class CustomerSummary {
  CustomerSummary({required this.id, required this.name, required this.city, required this.machines, required this.running, required this.stopped, required this.idle, this.technicians = 0});
  final String id, name, city;
  final int machines, running, stopped, idle, technicians;
  factory CustomerSummary.fromJson(Map<String, dynamic> j) => CustomerSummary(
        id: j['id'], name: j['name'], city: j['city'], machines: j['machines'], running: j['running'], stopped: j['stopped'], idle: j['idle'], technicians: j['technicians'] ?? 0,
      );
}

class StaffUser {
  StaffUser({required this.name, required this.email, required this.role, required this.company});
  final String name, email, company;
  final Role role;
  factory StaffUser.fromJson(Map<String, dynamic> j) => StaffUser(name: j['name'], email: j['email'], role: Role.parse(j['role']), company: j['company']);
}

class Overview {
  Overview({required this.customers, required this.machines, required this.users, required this.running, required this.stopped, required this.idle, required this.attention, this.technicians = 0, this.unassigned = 0, this.pending = 0});
  final int customers, machines, users, running, stopped, idle, technicians, unassigned, pending;
  final List<Attention> attention; // Attention.code carries "code" ; company in [company]
  factory Overview.fromJson(Map<String, dynamic> j) => Overview(
        customers: j['customers'], machines: j['machines'], users: j['users'], technicians: j['technicians'] ?? 0, unassigned: j['unassigned'] ?? 0, pending: j['pending'] ?? 0,
        running: j['counts']['running'], stopped: j['counts']['stopped'], idle: j['counts']['idle'],
        attention: [for (final a in j['attention']) Attention(a['machineId'], a['code'], a['status'], company: a['company'])],
      );
}

class MachineEvent {
  MachineEvent(this.time, this.text, this.status);
  final String time, text, status;
}

class MachineInfo {
  MachineInfo({
    required this.serial, required this.installedOn, required this.warrantyUntil, required this.lastService, required this.nextService,
    required this.availability, required this.performance, required this.quality,
    required this.runtimeMin, required this.downtimeMin, required this.rejects, required this.hourly, required this.events,
  });
  final String serial, installedOn, warrantyUntil, lastService, nextService;
  final num availability, performance, quality;
  final int runtimeMin, downtimeMin, rejects;
  final List<num> hourly; // output per hour so far today
  final List<MachineEvent> events;

  num get oee => (availability * performance * quality / 10000).round();

  factory MachineInfo.fromJson(Map<String, dynamic> j) => MachineInfo(
        serial: j['serial'], installedOn: j['installedOn'], warrantyUntil: j['warrantyUntil'], lastService: j['lastService'], nextService: j['nextService'],
        availability: j['availability'], performance: j['performance'], quality: j['quality'],
        runtimeMin: j['runtimeMin'], downtimeMin: j['downtimeMin'], rejects: j['rejects'],
        hourly: [for (final v in j['hourly']) v as num],
        events: [for (final e in j['events']) MachineEvent(e['time'], e['text'], e['status'])],
      );
}

class TopMachine {
  TopMachine(this.id, this.code, this.typeKey, this.value, this.unit, [this.photo]);
  final String id, code, typeKey, unit;
  final String? photo;
  final num value;
}

/// Extra plant-level numbers shown on Home ("only my machines").
class Stats {
  const Stats({this.uptime = 0, this.efficiency = 0, this.downtimeMin = 0, this.weekProduced = 0, this.monthProduced = 0, this.top = const []});
  final num uptime, efficiency, downtimeMin, weekProduced, monthProduced;
  final List<TopMachine> top;
  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        uptime: j['uptime'], efficiency: j['efficiency'], downtimeMin: j['downtimeMin'], weekProduced: j['weekProduced'], monthProduced: j['monthProduced'],
        top: [for (final t in j['top']) TopMachine(t['id'], t['code'], t['typeKey'], t['value'], t['unit'], t['photo'])],
      );
}

/// A Skylyf machine model the customer can register (add to their plant).
class CatalogItem {
  CatalogItem({required this.id, required this.name, required this.model, required this.typeKey, required this.tagline, required this.speed, required this.specs, this.description = '', this.cupSize = '', this.paperRequired = '', this.price, this.photos = const [], this.spec});
  final Spec? spec;
  final String id, name, model, typeKey, tagline, speed, description, cupSize, paperRequired;
  final List<String> specs;
  final num? price;
  final List<String> photos; // paths like /api/v1/uploads/x.jpg (see photoUrl)
  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: j['id'], name: j['name'], model: j['model'], typeKey: j['typeKey'], tagline: j['tagline'] ?? '', speed: j['speed'] ?? '', specs: [for (final s in (j['specs'] as List? ?? const [])) s as String],
        description: j['description'] ?? '', cupSize: j['cupSize'] ?? '', paperRequired: j['paperRequired'] ?? '', price: j['price'],
        photos: [for (final p in (j['photos'] as List? ?? const [])) p as String], spec: Spec.fromJson(j['spec']),
      );
}

/// One machine in the "Register new" grid: a model Skylyf sells (managed in the dashboard's Machines screen). No stock: the owner
/// already bought it and says which one and how many.
class StoreItem {
  StoreItem({required this.id, required this.name, required this.model, required this.typeKey, required this.typeName, this.description = '', this.speed = '', this.cupSize = '', this.paperRequired = '', this.price, this.photos = const [], this.specs = const [], this.spec});
  final Spec? spec;
  final String id, name, model, typeKey, typeName, description, speed, cupSize, paperRequired;
  final num? price;
  final List<String> photos;
  final List<String> specs;

  factory StoreItem.fromCatalog(CatalogItem c) => StoreItem(
        id: c.id, name: c.name, model: c.model, typeKey: c.typeKey,
        typeName: c.typeKey.isEmpty ? '' : c.typeKey.replaceAll('_', ' ').split(' ').map((w) => w.isEmpty ? w : '${w[0].toUpperCase()}${w.substring(1)}').join(' '),
        description: c.description.isNotEmpty ? c.description : c.tagline, speed: c.speed, cupSize: c.cupSize, paperRequired: c.paperRequired, price: c.price, photos: c.photos, specs: c.specs, spec: c.spec,
      );

  /// Body of POST /registrations
  Map<String, dynamic> get pick => {'catalogId': id};
  static const maxQty = 50;
}

class Registration {
  Registration({required this.id, required this.model, required this.typeKey, required this.serial, required this.nickname, required this.status, required this.createdAt, this.company, this.serials = const [], this.qty = 1});
  final String id, model, typeKey, serial, nickname, status; // status: pending | approved | rejected
  final List<String> serials; // one per piece
  final int qty;
  final String? company; // shown to the owner
  final DateTime createdAt;
  factory Registration.fromJson(Map<String, dynamic> j) => Registration(
        id: j['id'], model: j['model'], typeKey: j['typeKey'], serial: j['serial'] ?? '', nickname: j['nickname'] ?? '', status: j['status'], createdAt: DateTime.parse(j['createdAt']).toLocal(), company: j['company'],
        serials: [for (final v in (j['serials'] as List? ?? const [])) v as String], qty: j['qty'] ?? 1,
      );
}

class Technician {
  Technician({required this.id, required this.name, required this.phone, this.assigned = false, this.companies = const [], this.email = '', this.photo, this.shift = '', this.city = ''});
  final String id, name, phone, email, shift, city; // shift like "09:00 – 18:00"
  final String? photo; // path like /api/v1/uploads/x.jpg (see photoUrl)
  final bool assigned; // in a customer's detail: is this technician assigned to that customer?
  final List<String> companies; // owner view: customers this technician serves
  factory Technician.fromJson(Map<String, dynamic> j) => Technician(
        id: j['id'], name: j['name'], phone: j['phone'] ?? '', assigned: j['assigned'] ?? false, companies: [for (final c in (j['companies'] as List? ?? const [])) c as String],
        email: j['email'] ?? '',
        photo: j['photo'],
        shift: (j['shift'] is Map && (j['shift']['start'] ?? '') != '') ? '${j['shift']['start']} – ${j['shift']['end']}' : '',
        city: j['address'] is Map ? (j['address']['city'] ?? '') : '',
      );
}

/// Owner view of one customer (tenant): their machines, technicians and users.
class CustomerDetail {
  CustomerDetail({required this.summary, required this.machines, required this.technicians, required this.users});
  final CustomerSummary summary;
  final List<Machine> machines;
  final List<Technician> technicians; // every technician, with `assigned` set for this customer
  final List<StaffUser> users;
  factory CustomerDetail.fromJson(Map<String, dynamic> j) => CustomerDetail(
        summary: CustomerSummary.fromJson(j),
        machines: [for (final m in j['machineList']) Machine.fromJson(m)],
        technicians: [for (final t in j['technicianList']) Technician.fromJson(t)],
        users: [for (final u in j['userList']) StaffUser.fromJson(u)],
      );
}

class OrderLine {
  OrderLine({required this.partId, required this.name, required this.sku, required this.price, required this.qty, this.photo});
  final String partId, name, sku;
  final num price;
  final int qty;
  final String? photo;
  factory OrderLine.fromJson(Map<String, dynamic> j) => OrderLine(partId: '${j['partId']}', name: j['name'] ?? '', sku: j['sku'] ?? '', price: j['price'] ?? 0, qty: j['qty'] ?? 1, photo: j['photo']);
}

/// A spare-parts order the owner placed. Returns/exchanges open once it is delivered (see [returnDays]).
class PartOrder {
  PartOrder({required this.id, required this.number, required this.invoiceNo, required this.createdAt, required this.status, required this.paid, required this.total, required this.gst, required this.subtotal, required this.items, this.deliveredAt});
  static const returnDays = 7; // keep in step with RETURN_DAYS in the backend
  final String id, number, invoiceNo, status;
  final DateTime createdAt;
  final DateTime? deliveredAt;
  final bool paid;
  final num total, gst, subtotal;
  final List<OrderLine> items;
  bool get canReturn => status == 'delivered' && deliveredAt != null && DateTime.now().difference(deliveredAt!).inDays < returnDays;
  factory PartOrder.fromJson(Map<String, dynamic> j) => PartOrder(
        id: j['id'], number: j['number'], invoiceNo: j['invoiceNo'] ?? '', createdAt: DateTime.parse(j['createdAt']).toLocal(), status: j['status'], paid: j['paid'] ?? false,
        total: j['total'] ?? 0, gst: j['gst'] ?? 0, subtotal: j['subtotal'] ?? 0, items: [for (final i in (j['items'] as List? ?? const [])) OrderLine.fromJson(i)],
        deliveredAt: j['deliveredAt'] == null ? null : DateTime.parse(j['deliveredAt']).toLocal(),
      );
}

class ReturnRequest {
  ReturnRequest({required this.id, required this.number, required this.orderId, required this.type, required this.reason, required this.status, required this.items, this.adminNote = '', this.note = '', required this.createdAt});
  final String id, number, orderId, type, reason, status, adminNote, note; // type: return | exchange
  final List<OrderLine> items;
  final DateTime createdAt;
  factory ReturnRequest.fromJson(Map<String, dynamic> j) => ReturnRequest(
        id: j['id'], number: j['number'], orderId: '${j['orderId']}', type: j['type'], reason: j['reason'], status: j['status'], adminNote: j['adminNote'] ?? '', note: j['note'] ?? '',
        items: [for (final i in (j['items'] as List? ?? const [])) OrderLine.fromJson({...Map<String, dynamic>.from(i), 'price': 0})], createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}
