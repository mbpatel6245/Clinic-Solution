import 'package:flutter/widgets.dart';

/// Copy for the new workspace. Kept in one place so all three supported
/// languages ship together, including navigation and empty/error states.
class RevampLabels {
  RevampLabels(this.language);
  final String language;
  factory RevampLabels.of(BuildContext context) =>
      RevampLabels(Localizations.localeOf(context).languageCode);

  String text(String key) {
    final values = _copy[key];
    assert(values != null, 'Missing workspace translation: $key');
    return values?[switch (language) {
          'hi' => 1,
          'gu' => 2,
          _ => 0,
        }] ??
        key;
  }

  static const _copy = <String, List<String>>{
    'signingIn': ['Signing in…', 'साइन इन हो रहा है…', 'સાઇન ઇન થઈ રહ્યું છે…'],
    'wrongPortal': [
      'Use the clinic login for this account. Your administrator assigns staff access.',
      'इस खाते के लिए क्लिनिक लॉगिन का उपयोग करें। प्रशासक स्टाफ एक्सेस देता है।',
      'આ ખાતા માટે ક્લિનિક લૉગિન વાપરો. સંચાલક સ્ટાફ ઍક્સેસ આપે છે.',
    ],
    'profileMissing': [
      'Your clinic profile is missing. Contact your clinic administrator.',
      'आपकी क्लिनिक प्रोफ़ाइल नहीं मिली। प्रशासक से संपर्क करें।',
      'તમારી ક્લિનિક પ્રોફાઇલ મળી નથી. સંચાલકનો સંપર્ક કરો.',
    ],
    'approvalPending': [
      'Your account is not approved for access. Contact your clinic administrator.',
      'आपके खाते को एक्सेस की मंजूरी नहीं है। प्रशासक से संपर्क करें।',
      'તમારા ખાતાને ઍક્સેસની મંજૂરી નથી. સંચાલકનો સંપર્ક કરો.',
    ],
    'year': ['This year', 'इस वर्ष', 'આ વર્ષે'],
    'customRange': ['Custom dates', 'चुनी हुई तारीखें', 'પસંદ કરેલી તારીખો'],
    'analytics': ['Analytics', 'विश्लेषण', 'વિશ્લેષણ'],
    'noShow': ['No-show', 'नहीं आए', 'આવ્યા નથી'],
    'ageDistribution': ['Age distribution', 'आयु वितरण', 'ઉંમરનું વિતરણ'],
    'genderDistribution': [
      'Gender distribution',
      'लिंग वितरण',
      'લિંગનું વિતરણ',
    ],
    'topMedicines': [
      'Frequently recorded medicines',
      'अक्सर दर्ज दवाएँ',
      'વારંવાર નોંધાયેલી દવાઓ',
    ],
    'attendance': [
      'Recorded no-show rate',
      'दर्ज अनुपस्थिति दर',
      'નોંધાયેલ ગેરહાજરીનો દર',
    ],
    'attendanceHint': [
      'Based on appointments explicitly marked checked-in, completed or no-show. Unresolved bookings are excluded.',
      'चेक-इन, पूर्ण या अनुपस्थित दर्ज बुकिंग पर आधारित। अनिर्णीत बुकिंग शामिल नहीं हैं।',
      'ચેક-ઇન, પૂર્ણ કે ગેરહાજર નોંધાયેલી બુકિંગ પર આધારિત. અનિર્ણિત બુકિંગ સામેલ નથી.',
    ],
    'unspecified': ['Not recorded', 'दर्ज नहीं', 'નોંધાયેલ નથી'],
    'male': ['Male', 'पुरुष', 'પુરુષ'],
    'female': ['Female', 'महिला', 'સ્ત્રી'],
    'other': ['Other', 'अन्य', 'અન્ય'],
    'updateTemplate': [
      'Update template',
      'टेम्पलेट अपडेट करें',
      'ટેમ્પલેટ અપડેટ કરો',
    ],
    'privateNotes': [
      'Private clinical notes',
      'निजी क्लिनिकल नोट्स',
      'ખાનગી ક્લિનિકલ નોંધો',
    ],
    'privateNotesHint': [
      'Visible only to authorized clinicians; excluded from patient-shared prescriptions and reusable templates.',
      'केवल अधिकृत डॉक्टरों के लिए; मरीज़ के साथ साझा प्रिस्क्रिप्शन और टेम्पलेट में शामिल नहीं।',
      'માત્ર અધિકૃત ડૉક્ટર માટે; દર્દી સાથે શેર કરેલ પ્રિસ્ક્રિપ્શન અને ટેમ્પલેટમાં સામેલ નથી.',
    ],
    'templates': [
      'Prescription templates',
      'प्रिस्क्रिप्शन टेम्पलेट',
      'પ્રિસ્ક્રિપ્શન ટેમ્પલેટ',
    ],
    'useTemplate': ['Use template', 'टेम्पलेट उपयोग करें', 'ટેમ્પલેટ વાપરો'],
    'saveTemplate': [
      'Save as template',
      'टेम्पलेट के रूप में सहेजें',
      'ટેમ્પલેટ તરીકે સાચવો',
    ],
    'templateName': ['Template name', 'टेम्पलेट का नाम', 'ટેમ્પલેટનું નામ'],
    'templateHint': [
      'Templates contain clinical instructions, never patient identity or measured vitals. Review before applying.',
      'टेम्पलेट में मरीज़ की पहचान या मापे गए वाइटल नहीं हैं। उपयोग से पहले जाँचें।',
      'ટેમ્પલેટમાં દર્દીની ઓળખ કે માપેલા વાઇટલ નથી. ઉપયોગ પહેલાં તપાસો.',
    ],
    'noTemplates': [
      'Save your first template from the prescription editor.',
      'प्रिस्क्रिप्शन संपादक से पहला टेम्पलेट सहेजें।',
      'પ્રિસ્ક્રિપ્શન સંપાદકમાંથી પહેલું ટેમ્પલેટ સાચવો.',
    ],
    'plans': ['Treatment plans', 'उपचार योजनाएँ', 'સારવાર યોજનાઓ'],
    'newPlan': ['New treatment plan', 'नई उपचार योजना', 'નવી સારવાર યોજના'],
    'planHint': [
      'Plan visits and track completed sittings. Payments remain in billing.',
      'मुलाकातें तय करें और पूर्ण सत्र देखें। भुगतान बिलिंग में है।',
      'મુલાકાતો નક્કી કરો અને પૂર્ણ સત્રો જુઓ. ચુકવણી બિલિંગમાં છે.',
    ],
    'sessions': ['Sittings', 'सत्र', 'સત્રો'],
    'addSitting': ['Add sitting', 'सत्र जोड़ें', 'સત્ર ઉમેરો'],
    'noPlans': [
      'No treatment plans yet.',
      'अभी कोई उपचार योजना नहीं है।',
      'હજુ કોઈ સારવાર યોજના નથી.',
    ],
    'laboratory': [
      'Lab values & trends',
      'लैब मान और रुझान',
      'લેબ મૂલ્યો અને વલણ',
    ],
    'addLab': ['Record lab value', 'लैब मान दर्ज करें', 'લેબ મૂલ્ય નોંધો'],
    'labHint': [
      'Record values and ranges from the original report. Flags compare only the ranges you enter; they are not a diagnosis.',
      'मूल रिपोर्ट से मान और सीमा दर्ज करें। चिह्न आपकी दर्ज सीमा से तुलना हैं; निदान नहीं।',
      'મૂળ રિપોર્ટમાંથી મૂલ્યો અને મર્યાદા નોંધો. ચિહ્નો નોંધેલી મર્યાદાની સરખામણી છે; નિદાન નથી.',
    ],
    'analyte': ['Test / analyte', 'जाँच / विश्लेष्य', 'પરીક્ષણ / વિશ્લેષ્ય'],
    'value': ['Reported value', 'रिपोर्ट में दिया मान', 'રિપોર્ટનું મૂલ્ય'],
    'unit': ['Unit', 'इकाई', 'એકમ'],
    'lower': [
      'Lower reference limit (optional)',
      'निचली संदर्भ सीमा (वैकल्पिक)',
      'નીચલી સંદર્ભ મર્યાદા (વૈકલ્પિક)',
    ],
    'upper': [
      'Upper reference limit (optional)',
      'ऊपरी संदर्भ सीमा (वैकल्पिक)',
      'ઉપલી સંદર્ભ મર્યાદા (વૈકલ્પિક)',
    ],
    'outsideRange': [
      'Outside entered range',
      'दर्ज सीमा से बाहर',
      'નોંધેલી મર્યાદાની બહાર',
    ],
    'noLabs': [
      'No lab values recorded.',
      'कोई लैब मान दर्ज नहीं है।',
      'કોઈ લેબ મૂલ્ય નોંધાયેલ નથી.',
    ],
    'messages': ['Team messages', 'टीम संदेश', 'ટીમ સંદેશા'],
    'messageHint': [
      'Shared with authorized clinic staff. Keep alerts brief and avoid unnecessary patient details.',
      'अधिकृत क्लिनिक स्टाफ के साथ साझा है। अनावश्यक मरीज़ जानकारी न लिखें।',
      'અધિકૃત ક્લિનિક સ્ટાફ સાથે શેર થાય છે. બિનજરૂરી દર્દીની માહિતી ન લખો.',
    ],
    'send': ['Send', 'भेजें', 'મોકલો'],
    'noMessages': [
      'No team messages yet.',
      'अभी कोई टीम संदेश नहीं है।',
      'હજુ કોઈ ટીમ સંદેશ નથી.',
    ],
    'years': ['Years', 'वर्ष', 'વર્ષ'],
    'months': ['Months', 'महीने', 'મહિના'],
    'weeks': ['Weeks', 'सप्ताह', 'અઠવાડિયા'],
    'days': ['Days', 'दिन', 'દિવસ'],
    'dob': ['Date of birth', 'जन्म तिथि', 'જન્મ તારીખ'],
    'allergies': [
      'Allergies (comma-separated)',
      'एलर्जी (अल्पविराम से अलग)',
      'એલર્જી (અલ્પવિરામથી અલગ)',
    ],
    'consent': [
      'Patient agreed to clinic SMS and email updates',
      'मरीज़ क्लिनिक के SMS और ईमेल के लिए सहमत है',
      'દર્દી ક્લિનિકના SMS અને ઈમેલ માટે સંમત છે',
    ],
    'clinicLogin': [
      'Doctor / clinic login',
      'डॉक्टर / क्लिनिक लॉगिन',
      'ડૉક્ટર / ક્લિનિક લૉગિન',
    ],
    'staffLogin': ['Staff login', 'स्टाफ लॉगिन', 'સ્ટાફ લૉગિન'],
    'clinicLoginHint': [
      'Sign in to your clinic workspace.',
      'अपने क्लिनिक में साइन इन करें।',
      'તમારા ક્લિનિકમાં સાઇન ઇન કરો.',
    ],
    'staffLoginHint': [
      'Front-desk access for your clinic team.',
      'क्लिनिक टीम के लिए रिसेप्शन एक्सेस।',
      'ક્લિનિક ટીમ માટે રિસેપ્શન ઍક્સેસ.',
    ],
    'staffInviteHint': [
      'Use the work email and password from your clinic invitation. Your administrator manages your permissions.',
      'क्लिनिक आमंत्रण वाले ईमेल और पासवर्ड का उपयोग करें। प्रशासक आपकी अनुमतियाँ तय करता है।',
      'ક્લિનિક આમંત્રણના ઈમેલ અને પાસવર્ડનો ઉપયોગ કરો. સંચાલક તમારી પરવાનગી નક્કી કરે છે.',
    ],
    'workspace': [
      'Your practice, connected',
      'आपका क्लिनिक, एक साथ',
      'તમારું ક્લિનિક, એક સાથે',
    ],
    'home': ['Home', 'होम', 'હોમ'],
    'practice': ['Practice', 'क्लिनिक', 'ક્લિનિક'],
    'operations': ['Operations', 'संचालन', 'સંચાલન'],
    'manage': ['Management', 'प्रबंधन', 'સંચાલન વ્યવસ્થા'],
    'today': ['Today', 'आज', 'આજે'],
    'patients': ['Patients', 'मरीज़', 'દર્દીઓ'],
    'queue': ['Patient queue', 'मरीज़ों की कतार', 'દર્દીઓની કતાર'],
    'pharmacy': ['Pharmacy & stock', 'फार्मेसी और स्टॉक', 'ફાર્મસી અને સ્ટોક'],
    'vaccines': ['Vaccination', 'टीकाकरण', 'રસીકરણ'],
    'reminders': ['Reminders', 'अनुस्मारक', 'યાદ અપાવવું'],
    'billing': ['Billing & payments', 'बिल और भुगतान', 'બિલ અને ચુકવણી'],
    'reports': ['Reports', 'रिपोर्ट', 'અહેવાલો'],
    'exchange': ['Import / export', 'आयात / निर्यात', 'આયાત / નિકાસ'],
    'setup': ['Clinic settings', 'क्लिनिक सेटिंग', 'ક્લિનિક સેટિંગ'],
    'more': ['More', 'और', 'વધુ'],
    'findTool': [
      'Find a workspace tool',
      'क्लिनिक टूल खोजें',
      'ક્લિનિક ટૂલ શોધો',
    ],
    'welcome': [
      'A clear view of your practice.',
      'आपके क्लिनिक की पूरी झलक।',
      'તમારા ક્લિનિકની સંપૂર્ણ ઝલક.',
    ],
    'welcomeHint': [
      'Your patients, visits and next steps in one place.',
      'मरीज़, मुलाकातें और अगले कदम एक जगह।',
      'દર્દીઓ, મુલાકાતો અને આગળનાં પગલાં એક જગ્યાએ.',
    ],
    'week': ['This week', 'इस सप्ताह', 'આ અઠવાડિયે'],
    'month': ['This month', 'इस महीने', 'આ મહિને'],
    'consultations': ['Consultations', 'परामर्श', 'પરામર્શ'],
    'registered': ['Registered patients', 'पंजीकृत मरीज़', 'નોંધાયેલા દર્દીઓ'],
    'newPatients': ['New patients', 'नए मरीज़', 'નવા દર્દીઓ'],
    'collected': ['Payments collected', 'प्राप्त भुगतान', 'પ્રાપ્ત ચુકવણી'],
    'outstanding': ['Outstanding balance', 'बकाया राशि', 'બાકી રકમ'],
    'allTime': ['All time', 'अब तक', 'અત્યાર સુધી'],
    'visitsTrend': ['Consultation trend', 'परामर्श का रुझान', 'પરામર્શનો વલણ'],
    'lastSeven': ['Last 7 days', 'पिछले 7 दिन', 'છેલ્લા 7 દિવસ'],
    'diagnoses': ['Common diagnoses', 'सामान्य निदान', 'સામાન્ય નિદાન'],
    'noDiagnoses': [
      'No diagnoses recorded in this period.',
      'इस अवधि में कोई निदान दर्ज नहीं है।',
      'આ સમયગાળામાં કોઈ નિદાન નોંધાયેલ નથી.',
    ],
    'noVisits': [
      'Your consultation trend will appear after visits are recorded.',
      'मुलाकातें दर्ज करने के बाद परामर्श का रुझान दिखेगा।',
      'મુલાકાતો નોંધાયા પછી પરામર્શનો વલણ દેખાશે.',
    ],
    'payments': ['Payments', 'भुगतान', 'ચુકવણી'],
    'activity': ['Recent visits', 'हाल की मुलाकातें', 'તાજેતરની મુલાકાતો'],
    'dueVaccines': ['Upcoming vaccine doses', 'आगामी टीके', 'આગામી રસીના ડોઝ'],
    'doseHint': [
      'Recorded next-dose dates; confirm the schedule with the clinician.',
      'दर्ज अगली खुराक की तारीखें; डॉक्टर से पुष्टि करें।',
      'નોંધાયેલ આગામી ડોઝની તારીખો; ડૉક્ટર સાથે પુષ્ટિ કરો.',
    ],
    'noDoses': [
      'No upcoming doses recorded.',
      'आगामी खुराक दर्ज नहीं है।',
      'આગામી ડોઝ નોંધાયેલ નથી.',
    ],
    'noActivity': [
      'No visits recorded in this period.',
      'इस अवधि में कोई मुलाकात दर्ज नहीं है।',
      'આ સમયગાળામાં કોઈ મુલાકાત નોંધાયેલ નથી.',
    ],
    'noPayments': [
      'No invoices issued in this period.',
      'इस अवधि में कोई बिल जारी नहीं हुआ।',
      'આ સમયગાળામાં કોઈ બિલ બનાવવામાં આવ્યું નથી.',
    ],
    'hide': ['Hide values', 'आंकड़े छुपाएँ', 'આંકડા છુપાવો'],
    'show': ['Show values', 'आंकड़े दिखाएँ', 'આંકડા બતાવો'],
    'loadError': [
      'Some practice data could not be loaded. Check your connection and access.',
      'कुछ जानकारी लोड नहीं हो सकी। कनेक्शन और अनुमति जाँचें।',
      'કેટલીક માહિતી લોડ થઈ નથી. કનેક્શન અને પરવાનગી તપાસો.',
    ],
    'search': [
      'Search by name or phone',
      'नाम या फ़ोन से खोजें',
      'નામ અથવા ફોનથી શોધો',
    ],
    'patientHint': [
      'A single place for patient profiles and visit history.',
      'मरीज़ों की जानकारी और मुलाकातों का इतिहास एक जगह।',
      'દર્દીઓની માહિતી અને મુલાકાતોનો ઇતિહાસ એક જગ્યાએ.',
    ],
    'addPatient': ['Add patient', 'मरीज़ जोड़ें', 'દર્દી ઉમેરો'],
    'noPatients': [
      'No patients found. Add a patient to get started.',
      'कोई मरीज़ नहीं मिला। नया मरीज़ जोड़ें।',
      'કોઈ દર્દી મળ્યો નથી. નવો દર્દી ઉમેરો.',
    ],
    'history': ['Visit history', 'मुलाकातों का इतिहास', 'મુલાકાતોનો ઇતિહાસ'],
    'noHistory': [
      'No clinical visits recorded yet.',
      'अभी कोई मुलाकात दर्ज नहीं है।',
      'હજુ કોઈ મુલાકાત નોંધાયેલ નથી.',
    ],
    'details': ['Patient details', 'मरीज़ की जानकारी', 'દર્દીની માહિતી'],
    'scheduled': ['Scheduled', 'निर्धारित', 'નિયત'],
    'live': ['Checked in', 'चेक इन', 'ચેક ઇન'],
    'done': ['Completed', 'पूर्ण', 'પૂર્ણ'],
    'cancelled': ['Cancelled', 'रद्द', 'રદ'],
    'walkIn': ['Register walk-in', 'बिना बुकिंग पंजीकरण', 'વૉક-ઇન નોંધણી'],
    'queueHint': [
      'From arrival to consultation, keep today moving.',
      'आगमन से परामर्श तक, आज की व्यवस्था एक जगह।',
      'આગમનથી પરામર્શ સુધી, આજનું સંચાલન એક જગ્યાએ.',
    ],
    'noQueue': [
      'No patients in this queue.',
      'इस कतार में कोई मरीज़ नहीं है।',
      'આ કતારમાં કોઈ દર્દી નથી.',
    ],
    'checkIn': ['Check in', 'चेक इन करें', 'ચેક ઇન કરો'],
    'startVisit': [
      'Start consultation',
      'परामर्श शुरू करें',
      'પરામર્શ શરૂ કરો',
    ],
    'quickActions': ['Quick actions', 'त्वरित कार्य', 'ઝડપી કાર્યો'],
    'saveError': [
      'Could not save. Please try again.',
      'सहेज नहीं सके। फिर कोशिश करें।',
      'સાચવી શકાયું નથી. ફરી પ્રયાસ કરો.',
    ],
    'invoicePeriodHint': [
      'Paid amounts against invoices issued in this period.',
      'इस अवधि में जारी बिलों पर भुगतान की गई राशि।',
      'આ સમયગાળામાં જારી થયેલા બિલો પર ચૂકવેલી રકમ.',
    ],
    'retry': ['Retry', 'फिर कोशिश करें', 'ફરી પ્રયાસ કરો'],
  };
}
