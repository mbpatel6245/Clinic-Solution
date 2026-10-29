import 'dart:convert';

/// Immutable identity captured when work is created, never retargeted at sync.
final class ClinicScope {
  ClinicScope({
    required this.projectId,
    required this.userId,
    required this.clinicId,
  }) {
    for (final value in [projectId, userId, clinicId]) {
      if (value.trim().isEmpty || value.contains('/') || value.length > 128) {
        throw ArgumentError('A valid project, user and clinic are required.');
      }
    }
  }
  final String projectId, userId, clinicId;
  String get key => jsonEncode([projectId, userId, clinicId]);
  Map<String, String> toJson() => {
    'projectId': projectId,
    'userId': userId,
    'clinicId': clinicId,
  };
  @override
  bool operator ==(Object other) => other is ClinicScope && key == other.key;
  @override
  int get hashCode => key.hashCode;
}
