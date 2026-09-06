import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/design/app_theme.dart';
import '../../../l10n/generated/app_localizations.dart';
import '../../../services/sync_status_service.dart';

class SyncStatusBanner extends StatelessWidget {
  const SyncStatusBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final sync = context.watch<SyncStatusService>();
    final strings = AppLocalizations.of(context)!;
    final message = switch (sync.state) {
      ClinicSyncState.offline => strings.offlineMode,
      ClinicSyncState.pending => strings.changesWaitingToSync,
      ClinicSyncState.synced => strings.allChangesSynced,
      ClinicSyncState.checking => strings.checkingConnection,
    };
    final icon = switch (sync.state) {
      ClinicSyncState.offline => Icons.cloud_off_outlined,
      ClinicSyncState.pending => Icons.cloud_upload_outlined,
      ClinicSyncState.synced => Icons.cloud_done_outlined,
      ClinicSyncState.checking => Icons.sync,
    };
    return Material(
      color: sync.state == ClinicSyncState.synced
          ? AppColors.surface
          : AppColors.ink,
      shape: RoundedRectangleBorder(
        side: const BorderSide(color: AppColors.line),
        borderRadius: BorderRadius.circular(AppRadius.md),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: sync.state == ClinicSyncState.pending ? sync.syncNow : null,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 17,
                color: sync.state == ClinicSyncState.synced
                    ? AppColors.inkMuted
                    : AppColors.inverse,
              ),
              const SizedBox(width: AppSpacing.sm),
              Flexible(
                child: Text(
                  message,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: sync.state == ClinicSyncState.synced
                        ? AppColors.inkMuted
                        : AppColors.inverse,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
