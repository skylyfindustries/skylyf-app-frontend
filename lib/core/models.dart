import 'role.dart';

class Machine {
  Machine({
    required this.id, required this.code, required this.typeKey, required this.typeName,
    required this.status, required this.speed, required this.speedUnit, required this.outputUnit,
    required this.todayProduction, required this.todayTarget, required this.efficiency,
    this.model = '', this.company, this.companyId, this.shifts, this.info,
  });

  final String id, code, typeKey, typeName, status, speedUnit, outputUnit, model;
  final String? company, companyId; // set for staff roles; null = not assigned to a customer yet
  final num speed, todayProduction, todayTarget, efficiency;
  final Map<String, num>? shifts; // only on the detail endpoint
  final MachineInfo? info; // only on the detail endpoint

  factory Machine.fromJson(Map<String, dynamic> j) => Machine(
        id: j['id'],
        code: j['code'],
        typeKey: j['typeKey'],
        typeName: j['typeName'],
        model: j['model'] ?? '',
        company: j['company'],
        companyId: j['companyId'],
        status: j['status'],
        speed: j['speed'],
        speedUnit: j['speedUnit'],
        outputUnit: j['outputUnit'],
        todayProduction: j['todayProduction'],
        todayTarget: j['todayTarget'],
        efficiency: j['efficiency'],
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
  Dashboard({required this.running, required this.stopped, required this.idle, required this.today, required this.target, required this.attention, this.stats = const Stats()});
  final int running, stopped, idle;
  final num today, target;
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
        stats: j['stats'] == null ? const Stats() : Stats.fromJson(j['stats']),
      );
}

class Plant {
  Plant(this.id, this.name);
  final String id, name;
  factory Plant.fromJson(Map<String, dynamic> j) => Plant(j['_id'], j['name']);
}

class Me {
  Me({required this.name, required this.email, required this.company, required this.language, this.role = 'customer'});
  final String name, email, company, language, role;
  factory Me.fromJson(Map<String, dynamic> j) => Me(
        name: j['user']['name'] ?? '',
        email: j['user']['email'] ?? j['user']['phone'] ?? '',
        company: j['company']['name'] ?? '',
        language: j['user']['language'] ?? 'en',
        role: j['user']['role'] ?? 'customer',
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
  AlertItem({required this.id, required this.machineId, required this.code, required this.message, required this.status, required this.createdAt});
  final String id, message, status;
  final String? machineId, code;
  final DateTime createdAt;
  factory AlertItem.fromJson(Map<String, dynamic> j) => AlertItem(
        id: j['id'],
        machineId: j['machineId'],
        code: j['code'],
        message: j['message'],
        status: j['status'],
        createdAt: DateTime.parse(j['createdAt']).toLocal(),
      );
}

class Part {
  Part({required this.id, required this.name, required this.sku, required this.price});
  final int id;
  final String name, sku, price;
  factory Part.fromJson(Map<String, dynamic> j) => Part(id: j['id'], name: j['name'], sku: j['sku'] ?? '', price: '${j['price']}');
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
  TopMachine(this.id, this.code, this.typeKey, this.value, this.unit);
  final String id, code, typeKey, unit;
  final num value;
}

/// Extra plant-level numbers shown on Home ("only my machines").
class Stats {
  const Stats({this.uptime = 0, this.efficiency = 0, this.downtimeMin = 0, this.weekProduced = 0, this.monthProduced = 0, this.top = const []});
  final num uptime, efficiency, downtimeMin, weekProduced, monthProduced;
  final List<TopMachine> top;
  factory Stats.fromJson(Map<String, dynamic> j) => Stats(
        uptime: j['uptime'], efficiency: j['efficiency'], downtimeMin: j['downtimeMin'], weekProduced: j['weekProduced'], monthProduced: j['monthProduced'],
        top: [for (final t in j['top']) TopMachine(t['id'], t['code'], t['typeKey'], t['value'], t['unit'])],
      );
}

/// A Skylyf machine model the customer can register (add to their plant).
class CatalogItem {
  CatalogItem({required this.id, required this.name, required this.model, required this.typeKey, required this.tagline, required this.speed, required this.specs});
  final String id, name, model, typeKey, tagline, speed;
  final List<String> specs;
  factory CatalogItem.fromJson(Map<String, dynamic> j) => CatalogItem(
        id: j['id'], name: j['name'], model: j['model'], typeKey: j['typeKey'], tagline: j['tagline'], speed: j['speed'], specs: [for (final s in j['specs']) s as String],
      );
}

class Registration {
  Registration({required this.id, required this.model, required this.typeKey, required this.serial, required this.nickname, required this.status, required this.createdAt, this.company});
  final String id, model, typeKey, serial, nickname, status; // status: pending | approved | rejected
  final String? company; // shown to the owner
  final DateTime createdAt;
  factory Registration.fromJson(Map<String, dynamic> j) => Registration(
        id: j['id'], model: j['model'], typeKey: j['typeKey'], serial: j['serial'], nickname: j['nickname'], status: j['status'], createdAt: DateTime.parse(j['createdAt']).toLocal(), company: j['company'],
      );
}

class Technician {
  Technician({required this.id, required this.name, required this.phone, this.assigned = false, this.companies = const []});
  final String id, name, phone;
  final bool assigned; // in a customer's detail: is this technician assigned to that customer?
  final List<String> companies; // owner view: customers this technician serves
  factory Technician.fromJson(Map<String, dynamic> j) => Technician(
        id: j['id'], name: j['name'], phone: j['phone'] ?? '', assigned: j['assigned'] ?? false, companies: [for (final c in (j['companies'] as List? ?? const [])) c as String],
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
