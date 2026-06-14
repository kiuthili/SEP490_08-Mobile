import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/user_model.dart';

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
}
