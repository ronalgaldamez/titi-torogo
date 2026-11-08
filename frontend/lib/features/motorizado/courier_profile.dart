import '../shared/account_profile.dart';

class CourierProfile extends AccountProfile {
  const CourierProfile({required super.onLogout, super.key})
    : super(courier: true);
}
