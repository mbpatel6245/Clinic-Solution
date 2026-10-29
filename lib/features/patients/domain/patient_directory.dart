import '../../../data/datasources/clinical_models.dart';

/// Administrative projection: clinical history is never loaded for reception.
class PatientDirectoryPage {
  const PatientDirectoryPage(this.items, this.total, this.page, this.pages);
  final List<PatientModel> items;
  final int total, page, pages;
}

PatientDirectoryPage patientDirectoryPage(
  List<PatientModel> records, {
  String search = '',
  int page = 0,
  int pageSize = 8,
}) {
  if (pageSize < 1 || pageSize > 100 || page < 0) {
    throw ArgumentError('Invalid page');
  }
  final query = search.trim().toLowerCase();
  final digits = query.replaceAll(RegExp(r'\D'), '');
  final matches =
      records
          .where(
            (p) =>
                query.isEmpty ||
                '${p.fullName} ${p.id}'.toLowerCase().contains(query) ||
                (digits.length >= 3 &&
                    p.phone.replaceAll(RegExp(r'\D'), '').contains(digits)),
          )
          .toList()
        ..sort((a, b) {
          final name = a.fullName.toLowerCase().compareTo(
            b.fullName.toLowerCase(),
          );
          return name == 0 ? a.id.compareTo(b.id) : name;
        });
  final pages = (matches.length / pageSize).ceil().clamp(1, 1000000);
  final current = page.clamp(0, pages - 1);
  return PatientDirectoryPage(
    matches.skip(current * pageSize).take(pageSize).toList(),
    matches.length,
    current,
    pages,
  );
}

/// Candidates are hints only. A shared phone/name never establishes identity.
List<PatientModel> registrationCandidates(
  PatientModel draft,
  List<PatientModel> records,
) {
  String digits(String phone) => phone.replaceAll(RegExp(r'\D'), '');
  final phone = digits(draft.phone);
  final name = draft.fullName.trim().toLowerCase();
  return records
      .where(
        (p) =>
            p.id != draft.id &&
            ((phone.isNotEmpty && digits(p.phone) == phone) ||
                (name.isNotEmpty && p.fullName.trim().toLowerCase() == name)),
      )
      .toList();
}
