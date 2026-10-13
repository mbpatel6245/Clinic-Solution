/// Platform cleanup operates only on direct clinic module documents.
bool isClinicModuleRecordPath(String documentPath, String collection) {
  final parts = documentPath.split('/');
  return parts.length == 4 &&
      parts[0] == 'clinics' &&
      parts[1].isNotEmpty &&
      parts[2] == collection &&
      parts[3].isNotEmpty;
}
