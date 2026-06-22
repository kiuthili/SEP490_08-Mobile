import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/user_model.dart';
import 'package:stayhub_mobile/routes/app_routes.dart';
import 'package:stayhub_mobile/utils/auth_gate.dart';

UserModel userWithRoles(List<String> roles) {
  return UserModel(
    id: 1,
    email: 'customer@stayhub.test',
    fullName: 'StayHub Customer',
    roles: roles,
  );
}

void main() {
  test('customer account can use the mobile app', () {
    expect(userWithRoles(['Customer']).isCustomerOnly, isTrue);
  });

  test('staff account cannot use the customer mobile app', () {
    expect(userWithRoles(['Staff']).isCustomerOnly, isFalse);
  });

  test('accounts with additional roles cannot use the customer mobile app', () {
    expect(userWithRoles(['Customer', 'Staff']).isCustomerOnly, isFalse);
  });

  test('account without a role cannot use the customer mobile app', () {
    expect(userWithRoles([]).isCustomerOnly, isFalse);
  });

  test('login destination preserves a protected route and arguments', () {
    const destination = LoginDestination(
      route: AppRoutes.booking,
      arguments: 'booking-arguments',
    );

    expect(destination.route, AppRoutes.booking);
    expect(destination.arguments, 'booking-arguments');
  });

  test('login destination preserves the requested protected shell tab', () {
    const destination = LoginDestination(shellTab: 3);

    expect(destination.shellTab, 3);
  });
}
