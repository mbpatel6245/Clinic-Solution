import '../../data/datasources/enterprise_models.dart';
import '../../data/datasources/user_model.dart';
import 'app_role.dart';

bool invitationMatchesMember(TeamInvitation invitation, UserModel member) {
  if (invitation.userId.isNotEmpty) return invitation.userId == member.id;
  final email = invitation.email.trim().toLowerCase();
  return email.isNotEmpty && email == member.email.trim().toLowerCase();
}

bool invitationAccessIsActive(TeamInvitation invitation, UserModel member) {
  if (!invitationMatchesMember(invitation, member) ||
      member.status != 'approved' ||
      !member.clinicIds.contains(invitation.clinicId)) {
    return false;
  }
  final granted =
      (member.clinicRoleLists[invitation.clinicId] ??
              [member.clinicRoles[invitation.clinicId] ?? member.role])
          .map(AppRole.fromValue)
          .toSet();
  final requested = invitation.roles.isEmpty
      ? [invitation.role]
      : invitation.roles;
  return requested.every(granted.contains);
}
