import 'package:flutter_test/flutter_test.dart';
import 'package:stayhub_mobile/models/auth_models.dart';

void main() {
  test('register request contains every field required by AuthAPI', () {
    final request = RegisterRequest(
      email: 'customer@stayhub.test',
      password: 'Password1!',
      fullName: 'StayHub Customer',
      phoneNumber: '0901234567',
      otpCode: '123456',
    );

    expect(request.toJson(), {
      'email': 'customer@stayhub.test',
      'password': 'Password1!',
      'fullName': 'StayHub Customer',
      'phoneNumber': '0901234567',
      'otpCode': '123456',
    });
  });

  test('login response parses tokens and user returned by AuthAPI', () {
    final response = LoginResponse.fromJson({
      'user': {
        'id': 7,
        'email': 'customer@stayhub.test',
        'fullName': 'StayHub Customer',
        'phoneNumber': '0901234567',
        'gender': 'Female',
        'dateOfBirth': '2000-01-02',
        'provider': 'Local',
        'requirePasswordChange': true,
        'roles': ['Customer'],
      },
      'token': 'access-token',
      'refreshToken': 'refresh-token',
    });

    expect(response.token, 'access-token');
    expect(response.refreshToken, 'refresh-token');
    expect(response.user.email, 'customer@stayhub.test');
    expect(response.user.phoneNumber, '0901234567');
    expect(response.user.gender, 'Female');
    expect(response.user.dateOfBirth, '2000-01-02');
    expect(response.user.provider, 'Local');
    expect(response.user.requirePasswordChange, isTrue);
    expect(response.user.roles, ['Customer']);
  });
}
