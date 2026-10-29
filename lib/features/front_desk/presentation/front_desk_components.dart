import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../data/datasources/clinical_models.dart';
import '../../../data/datasources/enterprise_models.dart';
import '../../../data/datasources/patient_intake.dart';
import '../../../core/design/revamp_labels.dart';

class DeskLabels {
  DeskLabels.of(BuildContext context)
    : language = Localizations.localeOf(context).languageCode;
  final String language;
  String call(String key) =>
      (_copy[key] ?? [key, key, key])[language == 'hi'
          ? 1
          : language == 'gu'
          ? 2
          : 0];
  static const _copy = <String, List<String>>{
    'noShowConfirmed': [
      'I confirmed the absence with the clinic and the patient is not waiting.',
      'मैंने क्लिनिक से अनुपस्थिति की पुष्टि की है और मरीज़ प्रतीक्षा में नहीं है।',
      'મેં ક્લિનિક સાથે ગેરહાજરીની પુષ્ટિ કરી છે અને દર્દી રાહમાં નથી.',
    ],
    'frontDesk': ['Front desk', 'फ़्रंट डेस्क', 'ફ્રન્ટ ડેસ્ક'],
    'heading': [
      'A clear view of your clinic day.',
      'आपके क्लिनिक के दिन की स्पष्ट जानकारी।',
      'તમારા ક્લિનિકના દિવસની સ્પષ્ટ માહિતી.',
    ],
    'arrivalHeading': [
      'A smooth arrival, a clear hand-off.',
      'सुगम आगमन, स्पष्ट हस्तांतरण।',
      'સરળ આગમન, સ્પષ્ટ હસ્તાંતરણ.',
    ],
    'today': ['Appointments today', 'आज के अपॉइंटमेंट', 'આજની મુલાકાતો'],
    'waiting': [
      'Checked in / waiting',
      'चेक-इन / प्रतीक्षा',
      'ચેક-ઇન / રાહમાં',
    ],
    'upcoming': ['Still to arrive', 'आगमन बाकी', 'આવવાનું બાકી'],
    'completed': ['Completed', 'पूर्ण', 'પૂર્ણ'],
    'collected': [
      'Collected against today’s invoices',
      'आज के बिलों के लिए प्राप्त',
      'આજનાં બિલો માટે મળેલી રકમ',
    ],
    'outstanding': [
      'Outstanding today',
      'आज के बिलों में बकाया',
      'આજનાં બિલોમાં બાકી',
    ],
    'todayAppointments': [
      'Today’s front-desk appointments',
      'आज के फ़्रंट-डेस्क अपॉइंटमेंट',
      'આજની ફ્રન્ટ-ડેસ્ક મુલાકાતો',
    ],
    'todayArrivals': [
      'Today’s arrivals & queue',
      'आज के आगमन और कतार',
      'આજનાં આગમન અને કતાર',
    ],
    'calendar': ['View calendar', 'कैलेंडर देखें', 'કૅલેન્ડર જુઓ'],
    'schedule': [
      'Schedule appointment',
      'अपॉइंटमेंट बुक करें',
      'મુલાકાત બુક કરો',
    ],
    'liveQueue': ['Live queue', 'लाइव कतार', 'હાલની કતાર'],
    'tasks': ['Tasks to close the loop', 'शेष कार्य', 'બાકી કાર્યો'],
    'quick': ['Quick actions', 'त्वरित कार्य', 'ઝડપી કાર્યો'],
    'register': ['Register a patient', 'मरीज़ पंजीकरण', 'દર્દી નોંધણી'],
    'invoice': ['Create invoice', 'बिल बनाएँ', 'બિલ બનાવો'],
    'activity': [
      'Recent front-desk activity',
      'हाल की फ़्रंट-डेस्क गतिविधि',
      'તાજેતરની ફ્રન્ટ-ડેસ્ક પ્રવૃત્તિ',
    ],
    'arrival': [
      'Arrival & doctor hand-off',
      'आगमन और डॉक्टर को हस्तांतरण',
      'આગમન અને ડૉક્ટરને હસ્તાંતરણ',
    ],
    'find': [
      'Find & check in a patient',
      'मरीज़ खोजें और चेक-इन करें',
      'દર્દી શોધો અને ચેક-ઇન કરો',
    ],
    'search': [
      'Search patient name, ID or mobile',
      'मरीज़ का नाम, ID या मोबाइल खोजें',
      'દર્દીનું નામ, ID કે મોબાઇલ શોધો',
    ],
    'viewArrival': [
      'View arrival details',
      'आगमन विवरण देखें',
      'આગમનની વિગતો જુઓ',
    ],
    'time': ['Booked time', 'बुक किया समय', 'બુક કરેલો સમય'],
    'practitioner': ['Practitioner', 'डॉक्टर', 'ડૉક્ટર'],
    'patient': ['Patient / arrival', 'मरीज़ / आगमन', 'દર્દી / આગમન'],
    'status': ['Appointment status', 'अपॉइंटमेंट स्थिति', 'મુલાકાતની સ્થિતિ'],
    'action': ['Action', 'कार्य', 'કાર્ય'],
    'notArrived': ['Not yet arrived', 'अभी नहीं पहुँचे', 'હજી આવ્યા નથી'],
    'notRecorded': ['Not recorded', 'दर्ज नहीं', 'નોંધાયેલ નથી'],
    'select': [
      'Select an appointment to review arrival details.',
      'आगमन विवरण के लिए अपॉइंटमेंट चुनें।',
      'આગમનની વિગતો માટે મુલાકાત પસંદ કરો.',
    ],
    'scope': [
      'Front-desk access: identity, contact, appointments, arrival and authorised billing. Clinical notes and prescriptions remain in the doctor’s workspace.',
      'फ़्रंट-डेस्क पहुँच: पहचान, संपर्क, अपॉइंटमेंट, आगमन और अधिकृत बिलिंग। चिकित्सा विवरण डॉक्टर के कार्यक्षेत्र में हैं।',
      'ફ્રન્ટ-ડેસ્ક ઍક્સેસ: ઓળખ, સંપર્ક, મુલાકાતો, આગમન અને અધિકૃત બિલિંગ. ક્લિનિકલ વિગતો ડૉક્ટરના કાર્યક્ષેત્રમાં છે.',
    ],
    'footer': [
      'Confidential information · Authorised front-desk use only',
      'गोपनीय जानकारी · केवल अधिकृत फ़्रंट-डेस्क उपयोग',
      'ગોપનીય માહિતી · માત્ર અધિકૃત ફ્રન્ટ-ડેસ્ક ઉપયોગ',
    ],
    'handoffHint': [
      'Arrival is recorded separately from clinical consultation. Appointment status is shown as stored; missing arrival times are never inferred.',
      'आगमन चिकित्सा परामर्श से अलग दर्ज होता है। अनुपलब्ध आगमन समय का अनुमान नहीं लगाया जाता।',
      'આગમન ક્લિનિકલ પરામર્શથી અલગ નોંધાય છે. ગેરહાજર આગમન સમયનું અનુમાન થતું નથી.',
    ],
    'noShow': [
      'Late arrival or no-show?',
      'देर से आगमन या अनुपस्थिति?',
      'મોડું આગમન કે ગેરહાજરી?',
    ],
    'noShowHint': [
      'Review an unarrived appointment and confirm with the clinic before recording a no-show. Never mark someone already waiting as a no-show.',
      'अनुपस्थिति दर्ज करने से पहले क्लिनिक से पुष्टि करें। प्रतीक्षा कर रहे मरीज़ को अनुपस्थित न दिखाएँ।',
      'ગેરહાજરી નોંધતાં પહેલાં ક્લિનિક સાથે પુષ્ટિ કરો. રાહ જોતા દર્દીને ગેરહાજર ન ગણો.',
    ],
    'noActivity': [
      'No recorded arrival activity today.',
      'आज आगमन गतिविधि दर्ज नहीं है।',
      'આજે આગમનની પ્રવૃત્તિ નોંધાયેલી નથી.',
    ],
    'reviewBalance': [
      'Review outstanding balances',
      'बकाया की समीक्षा करें',
      'બાકી રકમની સમીક્ષા કરો',
    ],
    'reviewArrivals': [
      'Review arrivals',
      'आगमन की समीक्षा करें',
      'આગમનની સમીક્ષા કરો',
    ],
  };
}

class DeskIcon extends StatelessWidget {
  const DeskIcon(this.name, {super.key, this.size = 18, this.queue = false});
  final String name;
  final double size;
  final bool queue;
  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: SvgPicture.asset(
      'assets/figma/phase2/n${queue ? '12_4553' : '4_17763'}_$name.svg',
    ),
  );
}

List<AppointmentModel> deskDay(
  List<AppointmentModel> items,
  ClinicProfile clinic,
  DateTime now,
) =>
    items
        .where((a) => ClinicSchedule.sameDay(clinic, a.scheduledAt, now))
        .toList()
      ..sort((a, b) => a.scheduledAt.compareTo(b.scheduledAt));
String deskTime(BuildContext context, ClinicProfile clinic, DateTime value) =>
    DateFormat.jm(
      Localizations.localeOf(context).toString(),
    ).format(ClinicSchedule.local(clinic, value));

class DeskPanel extends StatelessWidget {
  const DeskPanel({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.soft = false,
  });
  final String title;
  final Widget child;
  final Widget? trailing;
  final bool soft;
  @override
  Widget build(BuildContext context) => Card(
    color: soft ? UviloTheme.soft : Colors.white,
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Wrap(
            alignment: WrapAlignment.spaceBetween,
            crossAxisAlignment: WrapCrossAlignment.center,
            spacing: 12,
            runSpacing: 8,
            children: [
              Text(
                title,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              ?trailing,
            ],
          ),
          const SizedBox(height: 18),
          child,
        ],
      ),
    ),
  );
}

class DeskMetrics extends StatelessWidget {
  const DeskMetrics({super.key, required this.values});
  final List<(String, String)> values;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final maxColumns = MediaQuery.textScalerOf(context).scale(14) > 22
          ? 1
          : box.maxWidth >= 1000
          ? 4
          : box.maxWidth >= 600
          ? 2
          : 1;
      final columns = values.length < maxColumns ? values.length : maxColumns;
      final width = (box.maxWidth - 16 * (columns - 1)) / columns;
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final value in values)
            SizedBox(
              width: width,
              child: Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        value.$1,
                        style: const TextStyle(
                          fontSize: 12,
                          color: UviloTheme.muted,
                        ),
                      ),
                      const SizedBox(height: 12),
                      Text(
                        value.$2,
                        style: const TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}

class DeskColumns extends StatelessWidget {
  const DeskColumns({super.key, required this.main, required this.side});
  final Widget main, side;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) =>
        box.maxWidth >= 1050 && MediaQuery.textScalerOf(context).scale(14) < 22
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(child: main),
              const SizedBox(width: 24),
              SizedBox(width: 340, child: side),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [main, const SizedBox(height: 24), side],
          ),
  );
}

class DeskAppointmentTable extends StatelessWidget {
  const DeskAppointmentTable({
    super.key,
    required this.items,
    required this.clinic,
    this.selectedId,
    this.onSelect,
    this.actions,
  });
  final List<AppointmentModel> items;
  final ClinicProfile clinic;
  final String? selectedId;
  final ValueChanged<AppointmentModel>? onSelect;
  final Widget Function(AppointmentModel)? actions;
  @override
  Widget build(BuildContext context) {
    final l = DeskLabels.of(context), p = RevampLabels.of(context);
    Widget identity(AppointmentModel a, {bool withDoctor = false}) => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          a.patientName,
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w500),
        ),
        Text(
          '${a.patientId} · ${a.arrivalAt == null ? l(a.status == 'confirmed' ? 'notRecorded' : 'notArrived') : deskTime(context, clinic, a.arrivalAt!)}',
          style: const TextStyle(fontSize: 11, color: UviloTheme.muted),
        ),
        if (withDoctor && a.practitionerName.isNotEmpty)
          Text(
            a.practitionerName,
            style: const TextStyle(fontSize: 11, color: UviloTheme.muted),
          ),
      ],
    );
    Widget badge(AppointmentModel a) => Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: a.status == 'confirmed'
            ? const Color(0xFFEDF2F8)
            : UviloTheme.soft,
        borderRadius: BorderRadius.circular(5),
      ),
      child: Text(
        p.text(
          a.status == 'booked' || a.status == 'pending'
              ? 'scheduled'
              : a.status == 'confirmed'
              ? 'live'
              : a.status == 'completed'
              ? 'completed'
              : a.status == 'no_show'
              ? 'noShow'
              : a.status,
        ),
        style: const TextStyle(fontSize: 11, color: UviloTheme.primary),
      ),
    );
    return LayoutBuilder(
      builder: (context, box) {
        if (box.maxWidth < 640 ||
            MediaQuery.textScalerOf(context).scale(14) > 22) {
          return Column(
            children: [
              for (final a in items)
                InkWell(
                  onTap: onSelect == null ? null : () => onSelect!(a),
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    decoration: const BoxDecoration(
                      border: Border(
                        bottom: BorderSide(color: UviloTheme.border),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(deskTime(context, clinic, a.scheduledAt)),
                        const SizedBox(height: 8),
                        identity(a, withDoctor: true),
                        const SizedBox(height: 8),
                        Wrap(
                          spacing: 12,
                          runSpacing: 8,
                          children: [
                            badge(a),
                            if (actions != null) actions!(a),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }
        return Column(
          children: [
            Container(
              color: UviloTheme.canvas,
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  SizedBox(
                    width: 85,
                    child: Text(
                      l('time'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  Expanded(
                    child: Text(
                      l('patient'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  SizedBox(
                    width: 125,
                    child: Text(
                      l('status'),
                      style: const TextStyle(fontSize: 10),
                    ),
                  ),
                  if (actions == null)
                    SizedBox(
                      width: 140,
                      child: Text(
                        l('practitioner'),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                  if (actions != null)
                    SizedBox(
                      width: 105,
                      child: Text(
                        l('action'),
                        style: const TextStyle(fontSize: 10),
                      ),
                    ),
                ],
              ),
            ),
            for (final a in items)
              InkWell(
                onTap: onSelect == null ? null : () => onSelect!(a),
                child: Container(
                  color: selectedId == a.id ? UviloTheme.canvas : null,
                  padding: const EdgeInsets.symmetric(
                    vertical: 10,
                    horizontal: 12,
                  ),
                  child: Column(
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          SizedBox(
                            width: 85,
                            child: Text(
                              deskTime(context, clinic, a.scheduledAt),
                              style: const TextStyle(fontSize: 12),
                            ),
                          ),
                          Expanded(child: identity(a)),
                          SizedBox(
                            width: 125,
                            child: Align(
                              alignment: Alignment.centerLeft,
                              child: badge(a),
                            ),
                          ),
                          if (actions == null)
                            SizedBox(
                              width: 140,
                              child: Text(
                                a.practitionerName,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: UviloTheme.muted,
                                ),
                              ),
                            ),
                          if (actions != null)
                            SizedBox(width: 105, child: actions!(a)),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(height: 1),
                    ],
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}
