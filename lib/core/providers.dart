import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'api.dart';
import 'models.dart';
import 'role.dart';

enum Session { unknown, out, active }

final apiProvider = Provider<Api>((ref) => Api(onLoggedOut: () => ref.read(authProvider.notifier).markLoggedOut()));

class RoleNotifier extends Notifier<Role?> {
  @override
  Role? build() => null;
  void set(Role? r) => state = r;
}

final roleProvider = NotifierProvider<RoleNotifier, Role?>(RoleNotifier.new);

class AuthNotifier extends Notifier<Session> {
  @override
  Session build() {
    _init();
    return Session.unknown;
  }

  Future<void> _init() async {
    final api = ref.read(apiProvider);
    if (!await api.loadSession()) {
      state = Session.out;
      return;
    }
    try {
      await _loadRole();
      state = Session.active;
    } catch (_) {
      state = Session.out;
    }
  }

  // The server decides the role; the UI only follows it.
  Future<void> _loadRole() async {
    final me = await ref.read(apiProvider).get('/me');
    ref.read(roleProvider.notifier).set(Role.parse(me['user']['role']));
  }

  /// Any sign-in method (password, OTP, passkey, authenticator, register): [method] stores the tokens, then the server-side role is loaded.
  Future<void> signIn(Future<void> Function(Api api) method) async {
    await method(ref.read(apiProvider));
    await _loadRole();
    state = Session.active;
  }

  Future<void> logout() async {
    await ref.read(apiProvider).logout();
    markLoggedOut();
  }

  void markLoggedOut() {
    ref.read(selectedPlantProvider.notifier).select(null);
    ref.read(roleProvider.notifier).set(null);
    state = Session.out;
  }
}

final authProvider = NotifierProvider<AuthNotifier, Session>(AuthNotifier.new);

/// null = all plants
class SelectedPlant extends Notifier<String?> {
  @override
  String? build() => null;
  void select(String? id) => state = id;
}

final selectedPlantProvider = NotifierProvider<SelectedPlant, String?>(SelectedPlant.new);

final meProvider = FutureProvider.autoDispose<Me>((ref) async => Me.fromJson(await ref.watch(apiProvider).get('/me')));

final plantsProvider = FutureProvider.autoDispose<List<Plant>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/plants') as List;
  return [for (final r in rows) Plant.fromJson(r)];
});

final dashboardProvider = FutureProvider.autoDispose<Dashboard>((ref) async {
  final plant = ref.watch(selectedPlantProvider);
  return Dashboard.fromJson(await ref.watch(apiProvider).get('/dashboard', query: {if (plant != null) 'plantId': plant}));
});

final machinesProvider = FutureProvider.autoDispose<List<Machine>>((ref) async {
  final plant = ref.watch(selectedPlantProvider);
  final rows = await ref.watch(apiProvider).get('/machines', query: {if (plant != null) 'plantId': plant}) as List;
  return [for (final r in rows) Machine.fromJson(r)];
});

final machineProvider = FutureProvider.autoDispose.family<Machine, String>((ref, id) async => Machine.fromJson(await ref.watch(apiProvider).get('/machines/$id')));

typedef ReportKey = ({String range, String kind});

final reportProvider = FutureProvider.autoDispose.family<ReportData, ReportKey>((ref, k) async {
  final plant = ref.watch(selectedPlantProvider);
  return ReportData.fromJson(await ref.watch(apiProvider).get('/reports', query: {'range': k.range, 'kind': k.kind, if (plant != null) 'plantId': plant}));
});

/// Table reports (machines / assignments / service): { title, cols, rows } from the server, ready to export.
final tableReportProvider = FutureProvider.autoDispose.family<({String title, List<String> cols, List<List<String>> rows}), ReportKey>((ref, k) async {
  final j = await ref.watch(apiProvider).get('/reports/table', query: {'range': k.range, 'kind': k.kind});
  return (
    title: j['title'] as String,
    cols: [for (final c in j['cols']) '$c'],
    rows: [for (final r in j['rows']) [for (final v in r) '$v']],
  );
});

/// Assignments of one day (YYYY-MM-DD): the whole company for an owner, only mine for a technician.
final assignmentsProvider = FutureProvider.autoDispose.family<List<Assignment>, String>((ref, date) async {
  final rows = await ref.watch(apiProvider).get('/assignments', query: {'date': date}) as List;
  return [for (final r in rows) Assignment.fromJson(r)];
});

/// The technician's own tasks: a week back to two weeks ahead ("My tasks").
final myTasksProvider = FutureProvider.autoDispose<List<Assignment>>((ref) async {
  String ymd(DateTime d) => '${d.year}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
  final now = DateTime.now();
  final rows = await ref.watch(apiProvider).get('/assignments', query: {'from': ymd(now.subtract(const Duration(days: 7))), 'to': ymd(now.add(const Duration(days: 14)))}) as List;
  return [for (final r in rows) Assignment.fromJson(r)];
});

final alertsProvider = FutureProvider.autoDispose<List<AlertItem>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/alerts') as List;
  return [for (final r in rows) AlertItem.fromJson(r)];
});

typedef PartsKey = ({String? machineId, String q});

final partsProvider = FutureProvider.autoDispose.family<List<Part>, PartsKey>((ref, k) async {
  final rows = await ref.watch(apiProvider).get('/parts', query: {if (k.machineId != null) 'machineId': k.machineId, if (k.q.isNotEmpty) 'q': k.q}) as List;
  return [for (final r in rows) Part.fromJson(r)];
});

final partProvider = FutureProvider.autoDispose.family<Part, String>((ref, id) async => Part.fromJson(await ref.watch(apiProvider).get('/parts/$id')));

/// Liked spare parts (ids). Toggling updates the heart at once and rolls back if the server call fails.
class WishlistNotifier extends Notifier<Set<String>> {
  @override
  Set<String> build() {
    _load();
    return {};
  }

  Future<void> _load() async {
    try {
      final rows = await ref.read(apiProvider).get('/wishlist') as List;
      state = {for (final r in rows) r['id'] as String};
    } catch (_) {}
  }

  Future<void> toggle(String id) async {
    final was = state.contains(id);
    state = was ? ({...state}..remove(id)) : {...state, id};
    try {
      final api = ref.read(apiProvider);
      if (was) {
        await api.delete('/wishlist/$id');
      } else {
        await api.put('/wishlist/$id', {});
      }
      ref.invalidate(wishlistPartsProvider);
    } catch (_) {
      state = was ? {...state, id} : ({...state}..remove(id));
    }
  }
}

final wishlistProvider = NotifierProvider<WishlistNotifier, Set<String>>(WishlistNotifier.new);

final wishlistPartsProvider = FutureProvider.autoDispose<List<Part>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/wishlist') as List;
  return [for (final r in rows) Part.fromJson(r)];
});

final myOrdersProvider = FutureProvider.autoDispose<List<PartOrder>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/orders') as List;
  return [for (final r in rows) PartOrder.fromJson(r)];
});

final myReturnsProvider = FutureProvider.autoDispose<List<ReturnRequest>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/returns') as List;
  return [for (final r in rows) ReturnRequest.fromJson(r)];
});

final ticketsProvider = FutureProvider.autoDispose.family<List<Ticket>, String>((ref, id) async {
  final rows = await ref.watch(apiProvider).get('/machines/$id/maintenance') as List;
  return [for (final r in rows) Ticket.fromJson(r)];
});

// ---------- staff (technician / admin) ----------
final overviewProvider = FutureProvider.autoDispose<Overview>((ref) async => Overview.fromJson(await ref.watch(apiProvider).get('/overview')));

final staffTicketsProvider = FutureProvider.autoDispose<List<StaffTicket>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/tickets') as List;
  return [for (final r in rows) StaffTicket.fromJson(r)];
});

final customersProvider = FutureProvider.autoDispose<List<CustomerSummary>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/customers') as List;
  return [for (final r in rows) CustomerSummary.fromJson(r)];
});

final usersProvider = FutureProvider.autoDispose<List<StaffUser>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/users') as List;
  return [for (final r in rows) StaffUser.fromJson(r)];
});

final customerMachinesProvider = FutureProvider.autoDispose.family<List<Machine>, String>((ref, companyId) async {
  final rows = await ref.watch(apiProvider).get('/machines', query: {'companyId': companyId}) as List;
  return [for (final r in rows) Machine.fromJson(r)];
});

// ---------- register machines ----------
final catalogProvider = FutureProvider.autoDispose<List<CatalogItem>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/catalog') as List;
  return [for (final r in rows) CatalogItem.fromJson(r)];
});

/// Machines available to register: every machine model Skylyf sells (photos, price, details).
final storeProvider = FutureProvider.autoDispose<List<StoreItem>>((ref) async => [for (final c in await ref.watch(catalogProvider.future)) StoreItem.fromCatalog(c)]);

final registrationsProvider = FutureProvider.autoDispose<List<Registration>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/registrations') as List;
  return [for (final r in rows) Registration.fromJson(r)];
});

// ---------- tenants, technicians, tasks ----------
/// Customer: technicians assigned to my company (the ones I can give a task to).
/// Owner: every technician and the customers they serve.
final techniciansProvider = FutureProvider.autoDispose<List<Technician>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/technicians') as List;
  return [for (final r in rows) Technician.fromJson(r)];
});

final customerDetailProvider = FutureProvider.autoDispose.family<CustomerDetail, String>((ref, id) async => CustomerDetail.fromJson(await ref.watch(apiProvider).get('/customers/$id')));

/// Customer: every service request my company made, with the technician chosen.
final tasksProvider = FutureProvider.autoDispose<List<StaffTicket>>((ref) async {
  final rows = await ref.watch(apiProvider).get('/tasks') as List;
  return [for (final r in rows) StaffTicket.fromJson(r)];
});
