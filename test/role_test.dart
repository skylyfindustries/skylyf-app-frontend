import 'package:flutter_test/flutter_test.dart';
import 'package:skylyf_machine/core/role.dart';

void main() {
  test('each role gets its own tabs and permissions', () {
    expect(Role.customer.tabs.map((t) => t.label), ['Home', 'Machines', 'Reports', 'Parts', 'Profile']);
    expect(Role.technician.tabs.map((t) => t.label), ['Dashboard', 'Tickets', 'Machines', 'Profile']);
    expect(Role.admin.tabs.map((t) => t.label), ['Overview', 'Customers', 'Machines', 'Team', 'Profile']);
    expect(Role.customer.canBuyParts && Role.customer.canRequestService, isTrue);
    expect(Role.technician.canManageTickets && !Role.technician.canBuyParts, isTrue);
    expect(Role.admin.isStaff && !Role.admin.canManageTickets, isTrue);
    expect(Role.admin.label, 'Owner');
    expect(Role.admin.canManageMachines && !Role.technician.canManageMachines && !Role.customer.canManageMachines, isTrue);
  });

  test('unknown role from server falls back to customer (least privilege)', () {
    expect(Role.parse('nonsense'), Role.customer);
    expect(Role.parse(null), Role.customer);
    expect(Role.parse('admin'), Role.admin);
  });
}
