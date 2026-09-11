import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/enterprise_models.dart';
import '../../../../data/datasources/user_model.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../../services/session_controller.dart';
import '../../../widgets/app_design.dart';

class TeamRolesScreen extends StatelessWidget {
  const TeamRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    final service = context.read<FirebaseFireStore>();
    final session = context.watch<SessionController>();
    final isOwner = session.role == AppRole.platformOwner;
    final clinicsStream = isOwner
        ? service.streamAllClinics()
        : service.streamClinics(session.clinicIds);
    return StreamBuilder<List<ClinicProfile>>(
      stream: clinicsStream,
      builder: (context, clinicSnapshot) {
        final clinics = clinicSnapshot.data ?? const <ClinicProfile>[];
        final clinicNames = {
          for (final clinic in clinics) clinic.id: clinic.name,
        };
        return StreamBuilder<List<UserModel>>(
          stream: service.streamUsers(allClinics: isOwner),
          builder: (context, userSnapshot) => StreamBuilder<List<TeamInvitation>>(
            stream: service.streamTeamInvitations(allClinics: isOwner),
            builder: (context, inviteSnapshot) {
              final users = userSnapshot.data ?? const <UserModel>[];
              final invitations =
                  inviteSnapshot.data ?? const <TeamInvitation>[];
              final pending = invitations
                  .where((invite) => invite.status == 'pending')
                  .toList();
              final loading =
                  (userSnapshot.connectionState == ConnectionState.waiting &&
                      !userSnapshot.hasData) ||
                  (clinicSnapshot.connectionState == ConnectionState.waiting &&
                      !clinicSnapshot.hasData);
              return AppPage(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            strings.teamAndRoles,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                        FilledButton.icon(
                          onPressed: clinics.isEmpty
                              ? null
                              : () => _invite(
                                  context,
                                  clinics,
                                  isOwner,
                                  session.activeClinicId,
                                ),
                          icon: const Icon(Icons.person_add_alt_1_outlined),
                          label: const Text('Invite member'),
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.xs),
                    Text(
                      isOwner
                          ? 'Platform view of every member, clinic allocation, role and pending approval.'
                          : strings.roleHelp,
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.inkMuted,
                      ),
                    ),
                    if (pending.isNotEmpty) ...[
                      const SizedBox(height: AppSpacing.lg),
                      AppSection(
                        title: 'Pending approvals (${pending.length})',
                        child: Column(
                          children: pending
                              .map(
                                (invite) => ListTile(
                                  contentPadding: EdgeInsets.zero,
                                  leading: const CircleAvatar(
                                    child: Icon(
                                      Icons.mark_email_unread_outlined,
                                    ),
                                  ),
                                  title: Text(invite.email),
                                  subtitle: Text(
                                    '${invite.role.displayName} • ${clinicNames[invite.clinicId] ?? invite.clinicId}',
                                  ),
                                  trailing: isOwner
                                      ? Wrap(
                                          spacing: AppSpacing.xs,
                                          children: [
                                            IconButton(
                                              tooltip: 'Approve',
                                              onPressed: () => _approveInvite(
                                                context,
                                                invite,
                                              ),
                                              icon: const Icon(
                                                Icons.check_circle_outline,
                                              ),
                                            ),
                                            IconButton(
                                              tooltip: 'Delete invitation',
                                              onPressed: () => _deleteInvite(
                                                context,
                                                invite,
                                              ),
                                              icon: const Icon(
                                                Icons.delete_outline,
                                              ),
                                            ),
                                          ],
                                        )
                                      : const Chip(label: Text('Pending')),
                                ),
                              )
                              .toList(),
                        ),
                      ),
                    ],
                    const SizedBox(height: AppSpacing.lg),
                    if (loading)
                      const Center(child: CircularProgressIndicator())
                    else if (users.isEmpty)
                      AppSection(
                        child: Center(child: Text(strings.noTeamMembers)),
                      )
                    else
                      ...users.map(
                        (user) => Padding(
                          padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                          child: _TeamMemberCard(
                            user: user,
                            clinicNames: clinicNames,
                            clinics: clinics,
                            isOwner: isOwner,
                            activeClinicId: session.activeClinicId,
                          ),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  Future<void> _invite(
    BuildContext context,
    List<ClinicProfile> clinics,
    bool isOwner,
    String activeClinicId,
  ) async {
    final email = TextEditingController();
    var role = AppRole.doctor;
    var clinicId = clinics.any((clinic) => clinic.id == activeClinicId)
        ? activeClinicId
        : clinics.first.id;
    final saved = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Invite team member'),
          content: SizedBox(
            width: 460,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: email,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                if (isOwner) ...[
                  const SizedBox(height: AppSpacing.md),
                  DropdownButtonFormField<String>(
                    initialValue: clinicId,
                    decoration: const InputDecoration(labelText: 'Clinic'),
                    items: clinics
                        .map(
                          (clinic) => DropdownMenuItem(
                            value: clinic.id,
                            child: Text(clinic.name),
                          ),
                        )
                        .toList(),
                    onChanged: (value) =>
                        setState(() => clinicId = value ?? clinicId),
                  ),
                ],
                const SizedBox(height: AppSpacing.md),
                DropdownButtonFormField<AppRole>(
                  initialValue: role,
                  decoration: const InputDecoration(labelText: 'Clinic role'),
                  items: AppRole.values
                      .where((item) => item != AppRole.platformOwner)
                      .map(
                        (item) => DropdownMenuItem(
                          value: item,
                          child: Text(item.displayName),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() => role = value ?? role),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(dialogContext, true),
              child: const Text('Create invitation'),
            ),
          ],
        ),
      ),
    );
    if (saved == true && email.text.trim().contains('@') && context.mounted) {
      await context.read<FirebaseFireStore>().inviteTeamMember(
        email.text,
        role,
        clinicId: clinicId,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Invitation created. A one-time password will be emailed automatically.',
            ),
          ),
        );
      }
    }
  }

  Future<void> _approveInvite(
    BuildContext context,
    TeamInvitation invite,
  ) async {
    try {
      await context.read<FirebaseFireStore>().approveTeamInvitation(invite);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Member approved and assigned.')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(error.toString().replaceFirst('Bad state: ', '')),
          ),
        );
      }
    }
  }

  Future<void> _deleteInvite(
    BuildContext context,
    TeamInvitation invite,
  ) async {
    final confirmed = await _confirm(
      context,
      'Delete this pending invitation?',
    );
    if (confirmed && context.mounted) {
      await context.read<FirebaseFireStore>().deleteTeamInvitation(invite);
    }
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({
    required this.user,
    required this.clinicNames,
    required this.clinics,
    required this.isOwner,
    required this.activeClinicId,
  });

  final UserModel user;
  final Map<String, String> clinicNames;
  final List<ClinicProfile> clinics;
  final bool isOwner;
  final String activeClinicId;

  @override
  Widget build(BuildContext context) {
    final memberships = user.clinicIds.isEmpty
        ? const ['No clinic allocated']
        : user.clinicIds.map(
            (id) =>
                '${clinicNames[id] ?? id} (${AppRole.fromValue(user.clinicRoles[id] ?? user.role).displayName})',
          );
    final currentUser = user.id == FirebaseAuth.instance.currentUser?.uid;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: AppColors.ink,
              foregroundColor: AppColors.inverse,
              child: Text(user.name.isEmpty ? '?' : user.name[0].toUpperCase()),
            ),
            const SizedBox(width: AppSpacing.md),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.name.isEmpty ? user.email : user.name,
                    style: Theme.of(context).textTheme.titleSmall,
                  ),
                  Text(user.email, overflow: TextOverflow.ellipsis),
                  if (user.phone.isNotEmpty) Text(user.phone),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    memberships.join(' • '),
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: AppColors.inkMuted),
                  ),
                ],
              ),
            ),
            if (isOwner && user.status == 'pending')
              IconButton(
                tooltip: 'Approve member',
                onPressed: () => _approveRegistration(context, user, clinics),
                icon: const Icon(Icons.check_circle_outline),
              ),
            IconButton(
              tooltip: 'Edit member details',
              onPressed: currentUser ? null : () => _editMember(context, user),
              icon: const Icon(Icons.manage_accounts_outlined),
            ),
            IconButton(
              tooltip: 'Edit clinic role',
              onPressed: currentUser
                  ? null
                  : () => _editRole(
                      context,
                      user,
                      clinics,
                      isOwner,
                      activeClinicId,
                    ),
              icon: const Icon(Icons.edit_outlined),
            ),
            IconButton(
              tooltip: isOwner ? 'Delete member' : 'Remove from this clinic',
              onPressed: currentUser
                  ? null
                  : () => _deleteMember(
                      context,
                      user,
                      isOwner: isOwner,
                      clinicId: activeClinicId,
                    ),
              icon: const Icon(Icons.delete_outline),
            ),
          ],
        ),
      ),
    );
  }
}

Future<void> _editRole(
  BuildContext context,
  UserModel user,
  List<ClinicProfile> clinics,
  bool isOwner,
  String activeClinicId,
) async {
  if (clinics.isEmpty) return;
  var clinicId = clinics.any((clinic) => clinic.id == activeClinicId)
      ? activeClinicId
      : (user.clinicIds.isNotEmpty ? user.clinicIds.first : clinics.first.id);
  if (!clinics.any((clinic) => clinic.id == clinicId)) {
    clinicId = clinics.first.id;
  }
  var role = AppRole.fromValue(user.clinicRoles[clinicId] ?? user.role);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: Text('Edit ${user.name.isEmpty ? user.email : user.name}'),
        content: SizedBox(
          width: 460,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isOwner)
                DropdownButtonFormField<String>(
                  initialValue: clinicId,
                  decoration: const InputDecoration(labelText: 'Clinic'),
                  items: clinics
                      .map(
                        (clinic) => DropdownMenuItem(
                          value: clinic.id,
                          child: Text(clinic.name),
                        ),
                      )
                      .toList(),
                  onChanged: (value) => setState(() {
                    clinicId = value ?? clinicId;
                    role = AppRole.fromValue(
                      user.clinicRoles[clinicId] ?? user.role,
                    );
                  }),
                ),
              if (isOwner) const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AppRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Role'),
                items: AppRole.values
                    .where((item) => item != AppRole.platformOwner)
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => role = value ?? role),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Save'),
          ),
        ],
      ),
    ),
  );
  if (saved == true && context.mounted) {
    await context.read<FirebaseFireStore>().updateUserClinicRole(
      user.id,
      clinicId,
      role.storageValue,
    );
  }
}

Future<void> _approveRegistration(
  BuildContext context,
  UserModel user,
  List<ClinicProfile> clinics,
) async {
  const createValue = '__create_clinic__';
  var clinicId = createValue;
  var role = AppRole.fromValue(user.role);
  final clinicName = TextEditingController(text: user.requestedClinicName);
  final approved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) => AlertDialog(
        title: const Text('Approve enterprise request'),
        content: SizedBox(
          width: 480,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Align(alignment: Alignment.centerLeft, child: Text(user.email)),
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<String>(
                initialValue: clinicId,
                decoration: const InputDecoration(
                  labelText: 'Clinic allocation',
                ),
                items: [
                  const DropdownMenuItem(
                    value: createValue,
                    child: Text('Create requested clinic'),
                  ),
                  ...clinics.map(
                    (clinic) => DropdownMenuItem(
                      value: clinic.id,
                      child: Text(clinic.name),
                    ),
                  ),
                ],
                onChanged: (value) =>
                    setState(() => clinicId = value ?? clinicId),
              ),
              if (clinicId == createValue) ...[
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: clinicName,
                  decoration: const InputDecoration(labelText: 'Clinic name'),
                ),
              ],
              const SizedBox(height: AppSpacing.md),
              DropdownButtonFormField<AppRole>(
                initialValue: role,
                decoration: const InputDecoration(labelText: 'Approved role'),
                items: const [AppRole.clinicAdmin, AppRole.doctor]
                    .map(
                      (item) => DropdownMenuItem(
                        value: item,
                        child: Text(item.displayName),
                      ),
                    )
                    .toList(),
                onChanged: (value) => setState(() => role = value ?? role),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: clinicId == createValue && clinicName.text.trim().isEmpty
                ? null
                : () => Navigator.pop(dialogContext, true),
            child: const Text('Approve & activate'),
          ),
        ],
      ),
    ),
  );
  if (approved != true || !context.mounted) return;
  final service = context.read<FirebaseFireStore>();
  final targetClinicId = clinicId == createValue
      ? await service.createClinicForApproval(clinicName.text)
      : clinicId;
  await service.approveUserForClinic(user.id, targetClinicId, role);
  if (context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Request approved and clinic activated.')),
    );
  }
}

Future<void> _editMember(BuildContext context, UserModel user) async {
  final name = TextEditingController(text: user.name);
  final phone = TextEditingController(text: user.phone);
  final saved = await showDialog<bool>(
    context: context,
    builder: (dialogContext) => AlertDialog(
      title: const Text('Member details'),
      content: SizedBox(
        width: 460,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(labelText: 'Name'),
            ),
            const SizedBox(height: AppSpacing.md),
            TextField(
              controller: phone,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(labelText: 'Phone'),
            ),
            const SizedBox(height: AppSpacing.sm),
            Align(
              alignment: Alignment.centerLeft,
              child: Text('Login email: ${user.email}'),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(dialogContext, false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: () => Navigator.pop(dialogContext, true),
          child: const Text('Save'),
        ),
      ],
    ),
  );
  if (saved == true && context.mounted) {
    await context.read<FirebaseFireStore>().updateMemberDetails(
      user.id,
      name: name.text,
      phone: phone.text,
    );
  }
}

Future<void> _deleteMember(
  BuildContext context,
  UserModel user, {
  required bool isOwner,
  required String clinicId,
}) async {
  final confirmed = await _confirm(
    context,
    isOwner
        ? 'Delete ${user.name.isEmpty ? user.email : user.name}? This removes platform access.'
        : 'Remove ${user.name.isEmpty ? user.email : user.name} from this clinic?',
  );
  if (confirmed && context.mounted) {
    final service = context.read<FirebaseFireStore>();
    if (isOwner) {
      await service.deleteUser(user.id);
    } else {
      await service.removeUserFromClinic(user.id, clinicId);
    }
  }
}

Future<bool> _confirm(BuildContext context, String message) async =>
    await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Please confirm'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text('Confirm'),
          ),
        ],
      ),
    ) ??
    false;
