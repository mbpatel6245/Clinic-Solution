import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:provider/provider.dart';

import '../../../../core/auth/app_role.dart';
import '../../../../core/design/app_theme.dart';
import '../../../../data/datasources/user_model.dart';
import '../../../../l10n/generated/app_localizations.dart';
import '../../../../services/firestore_services.dart';
import '../../../widgets/app_design.dart';

class TeamRolesScreen extends StatelessWidget {
  const TeamRolesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final strings = AppLocalizations.of(context)!;
    return StreamBuilder<List<UserModel>>(
      stream: context.read<FirebaseFireStore>().streamUsers(),
      builder: (context, snapshot) => AppPage(
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
                  onPressed: () => _invite(context),
                  icon: const Icon(Icons.person_add_alt_1_outlined),
                  label: const Text('Invite member'),
                ),
              ],
            ),
            const SizedBox(height: AppSpacing.xs),
            Text(
              strings.roleHelp,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.inkMuted),
            ),
            const SizedBox(height: AppSpacing.lg),
            if (snapshot.connectionState == ConnectionState.waiting &&
                !snapshot.hasData)
              const Center(child: CircularProgressIndicator())
            else if ((snapshot.data ?? const []).isEmpty)
              AppSection(child: Center(child: Text(strings.noTeamMembers)))
            else
              ...snapshot.data!.map(
                (user) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: _TeamMemberCard(user: user),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _invite(BuildContext context) async {
    final email = TextEditingController();
    var role = AppRole.doctor;
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
      );
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Invitation created.')));
      }
    }
  }
}

class _TeamMemberCard extends StatelessWidget {
  const _TeamMemberCard({required this.user});

  final UserModel user;

  @override
  Widget build(BuildContext context) {
    final picker = DropdownButton<AppRole>(
      value: AppRole.fromValue(
        user.clinicRoles[context.read<FirebaseFireStore>().activeClinicId] ??
            user.role,
      ),
      isExpanded: true,
      underline: const SizedBox.shrink(),
      items: AppRole.values
          .map(
            (role) =>
                DropdownMenuItem(value: role, child: Text(role.displayName)),
          )
          .toList(),
      onChanged: user.id == FirebaseAuth.instance.currentUser?.uid
          ? null
          : (role) {
              if (role != null) {
                context.read<FirebaseFireStore>().updateUserRole(
                  user.id,
                  role.storageValue,
                );
              }
            },
    );
    return LayoutBuilder(
      builder: (context, constraints) => Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: constraints.maxWidth < AppBreakpoints.compact
              ? Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _identity(),
                    const Divider(height: AppSpacing.lg),
                    picker,
                  ],
                )
              : Row(
                  children: [
                    Expanded(child: _identity()),
                    SizedBox(width: 220, child: picker),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _identity() => Row(
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
            Text(user.name.isEmpty ? user.email : user.name),
            Text(user.email, overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    ],
  );
}
