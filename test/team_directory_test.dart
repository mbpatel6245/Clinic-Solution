import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:clinic_solution/core/auth/app_role.dart';
import 'package:clinic_solution/core/auth/team_directory.dart';
import 'package:clinic_solution/data/datasources/enterprise_models.dart';
import 'package:clinic_solution/data/datasources/user_model.dart';

UserModel member({String status = 'approved'}) => UserModel(
  id: 'u1',
  name: 'Member',
  email: 'person@example.com',
  phone: '',
  role: 'clinic_admin',
  status: status,
  clinicIds: ['a'],
  clinicRoles: {'a': 'clinic_admin'},
  createdAt: Timestamp.fromMillisecondsSinceEpoch(0),
);
TeamInvitation invite({
  String email = 'person@example.com',
  String uid = '',
  String clinic = 'a',
  AppRole role = AppRole.clinicAdmin,
}) => TeamInvitation(
  id: 'i1',
  email: email,
  userId: uid,
  clinicId: clinic,
  role: role,
  notificationStatus: 'failed',
);
void main() {
  test(
    'legacy invitations match member email without case or space sensitivity',
    () {
      expect(
        invitationMatchesMember(
          invite(email: ' Person@Example.COM '),
          member(),
        ),
        isTrue,
      );
      expect(invitationAccessIsActive(invite(), member()), isTrue);
    },
  );
  test(
    'linked UID takes precedence over email and survives an email change',
    () {
      expect(
        invitationMatchesMember(
          invite(email: 'old@example.com', uid: 'u1'),
          member(),
        ),
        isTrue,
      );
      expect(
        invitationMatchesMember(invite(uid: 'different-user'), member()),
        isFalse,
      );
      expect(
        TeamInvitation.fromMap({
          'email': 'person@example.com',
          'user_id': 'u1',
        }, 'i1').userId,
        'u1',
      );
    },
  );
  test('blank emails and unrelated members are not combined', () {
    expect(invitationMatchesMember(invite(email: ''), member()), isFalse);
    expect(
      invitationMatchesMember(invite(email: 'other@example.com'), member()),
      isFalse,
    );
  });
  test(
    'pending account or new clinic/role requests still require approval',
    () {
      expect(
        invitationAccessIsActive(invite(), member(status: 'pending')),
        isFalse,
      );
      expect(invitationAccessIsActive(invite(clinic: 'b'), member()), isFalse);
      expect(
        invitationAccessIsActive(invite(role: AppRole.doctor), member()),
        isFalse,
      );
    },
  );
}
