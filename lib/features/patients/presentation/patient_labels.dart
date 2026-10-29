import 'package:flutter/widgets.dart';

class PatientLabels {
  const PatientLabels(this.language);
  final String language;
  factory PatientLabels.of(BuildContext context) =>
      PatientLabels(Localizations.localeOf(context).languageCode);
  String call(String key) =>
      (_copy[key] ?? [key, key, key])[language == 'hi'
          ? 1
          : language == 'gu'
          ? 2
          : 0];
  static const _copy = <String, List<String>>{
    'queueBooking': [
      'Save booking request',
      'बुकिंग अनुरोध सहेजें',
      'બુકિંગ વિનંતી સાચવો',
    ],
    'draftPassphrase': [
      'Passphrase (at least 16 characters)',
      'पासफ़्रेज़ (कम से कम 16 अक्षर)',
      'પાસફ્રેઝ (ઓછામાં ઓછા 16 અક્ષર)',
    ],
    'unlockBookings': [
      'Unlock offline bookings',
      'ऑफ़लाइन बुकिंग खोलें',
      'ઑફલાઇન બુકિંગ ખોલો',
    ],
    'bookingUnlockHint': [
      'Use a passphrase of at least 16 characters to protect and restore booking requests on this device. Use the same passphrase after restarting. It cannot be recovered. Requests sync while this workspace is open and unlocked. Offline choices can be restored from snapshots validated within the last 24 hours.',
      'इस उपकरण पर बुकिंग सुरक्षित रखने के लिए कम से कम 16 अक्षरों का पासफ़्रेज़ दें। पुनः आरंभ पर वही पासफ़्रेज़ चाहिए; इसकी पुनर्प्राप्ति नहीं होगी। कार्यक्षेत्र खुला होने पर अनुरोध सिंक होंगे। ऑफ़लाइन विकल्प केवल पिछले 24 घंटों में जाँचे गए स्नैपशॉट से खुलेंगे।',
      'આ ઉપકરણ પર બુકિંગ સાચવવા ઓછામાં ઓછા 16 અક્ષરનો પાસફ્રેઝ આપો. ફરી શરૂ કર્યા પછી એ જ પાસફ્રેઝ જોઈએ; તે પુનઃપ્રાપ્ત થઈ શકતો નથી. કાર્યક્ષેત્ર ખુલ્લું હોય ત્યારે વિનંતીઓ સિંક થાય છે. ઑફલાઇન વિકલ્પો માત્ર છેલ્લા 24 કલાકમાં ચકાસેલા સ્નેપશોટમાંથી ખૂલશે.',
    ],
    'bookingUnlockError': [
      'Could not unlock durable storage. Check the passphrase and browser/device storage availability.',
      'संग्रह खोल नहीं सके। पासफ़्रेज़ और उपकरण की उपलब्धता जाँचें।',
      'સંગ્રહ ખોલી શકાયો નહીં. પાસફ્રેઝ અને ઉપકરણનો સંગ્રહ તપાસો.',
    ],
    'bookingSync': ['Booking requests', 'बुकिंग अनुरोध', 'બુકિંગ વિનંતીઓ'],
    'bookingQueued': [
      'Request saved on this device. Check Booking requests for server confirmation.',
      'अनुरोध उपकरण पर सहेजा। सर्वर की पुष्टि बुकिंग अनुरोध में देखें।',
      'વિનંતી ઉપકરણ પર સાચવી. સર્વરની પુષ્ટિ બુકિંગ વિનંતીઓમાં જુઓ.',
    ],
    'queuedHint': [
      'Pending requests are not appointments. Availability and access are checked again on reconnect. Rejected requests need review before creating a new booking.',
      'लंबित अनुरोध अपॉइंटमेंट नहीं हैं। कनेक्शन पर उपलब्धता और पहुँच दोबारा जाँची जाती है। अस्वीकृत अनुरोध की समीक्षा करें।',
      'બાકી વિનંતીઓ મુલાકાતો નથી. જોડાણ પર ઉપલબ્ધતા અને ઍક્સેસ ફરી તપાસાય છે. નકારાયેલી વિનંતીની સમીક્ષા કરો.',
    ],
    'localBookingError': [
      'Local synchronization could not finish. Your saved requests are retained.',
      'स्थानीय सिंक पूरा नहीं हुआ। सहेजे अनुरोध सुरक्षित हैं।',
      'સ્થાનિક સિંક પૂર્ણ ન થયું. સાચવેલી વિનંતીઓ જાળવાઈ છે.',
    ],
    'reviewRequests': [
      'Review saved requests',
      'सहेजे अनुरोध देखें',
      'સાચવેલી વિનંતીઓ જુઓ',
    ],
    'request_pending': [
      'Waiting to sync',
      'सिंक की प्रतीक्षा',
      'સિંકની રાહમાં',
    ],
    'request_uncertain': [
      'Awaiting server confirmation',
      'सर्वर पुष्टि की प्रतीक्षा',
      'સર્વરની પુષ્ટિની રાહમાં',
    ],
    'request_paused': [
      'Access needs review',
      'पहुँच की समीक्षा आवश्यक',
      'ઍક્સેસની સમીક્ષા જરૂરી',
    ],
    'request_rejected': [
      'Rejected — review availability',
      'अस्वीकृत — उपलब्धता जाँचें',
      'નકારાયું — ઉપલબ્ધતા તપાસો',
    ],
    'request_confirmed': [
      'Confirmed by server',
      'सर्वर द्वारा पुष्ट',
      'સર્વર દ્વારા પુષ્ટિ',
    ],
    'scopeChanged': [
      'Workspace access changed. Close this form and reopen it in your current clinic.',
      'कार्यक्षेत्र की पहुँच बदल गई। फ़ॉर्म बंद कर वर्तमान क्लिनिक में फिर खोलें।',
      'કાર્યક્ષેત્રની ઍક્સેસ બદલાઈ છે. આ ફોર્મ બંધ કરીને વર્તમાન ક્લિનિકમાં ફરી ખોલો.',
    ],
    'dayView': ['Day', 'दिन', 'દિવસ'],
    'weekView': ['Week', 'सप्ताह', 'અઠવાડિયું'],
    'schedule': ['Appointments', 'अपॉइंटमेंट', 'મુલાકાતો'],
    'myCalendar': [
      'My calendar and availability',
      'मेरा कैलेंडर और उपलब्धता',
      'મારું કેલેન્ડર અને ઉપલબ્ધતા',
    ],
    'myAppointments': [
      'My assigned appointments',
      'मेरे निर्धारित अपॉइंटमेंट',
      'મારી સોંપાયેલ મુલાકાતો',
    ],
    'practitioner': ['Practitioner', 'चिकित्सक', 'તબીબ'],
    'minutes': ['minutes', 'मिनट', 'મિનિટ'],
    'duration': ['Visit duration', 'मुलाकात की अवधि', 'મુલાકાતનો સમયગાળો'],
    'visitReason': ['Reason for visit', 'मुलाकात का कारण', 'મુલાકાતનું કારણ'],
    'newAppointment': ['New appointment', 'नया अपॉइंटमेंट', 'નવી મુલાકાત'],
    'confirmBooking': [
      'Confirm appointment',
      'अपॉइंटमेंट की पुष्टि',
      'મુલાકાતની પુષ્ટિ કરો',
    ],
    'bookingConfirmed': [
      'Appointment confirmed by the server.',
      'सर्वर ने अपॉइंटमेंट की पुष्टि की।',
      'સર્વરે મુલાકાતની પુષ્ટિ કરી.',
    ],
    'bookingHint': [
      'The visit is booked only after the complete interval is accepted. Confirmation message delivery is tracked separately.',
      'पूरा समय स्वीकार होने पर ही बुकिंग होगी। पुष्टि संदेश की डिलीवरी अलग जाँची जाती है।',
      'સંપૂર્ણ સમય સ્વીકારાય ત્યારે જ બુકિંગ થાય છે. પુષ્ટિ સંદેશની ડિલિવરી અલગ તપાસાય છે.',
    ],
    'statusUnknown': [
      'Confirmation is uncertain. Check the appointment list. Retry uses the same request ID; keep these details unchanged.',
      'पुष्टि अनिश्चित है। सूची जाँचें। पुनः प्रयास उसी अनुरोध से होगा; विवरण न बदलें।',
      'પુષ્ટિ અનિશ્ચિત છે. યાદી તપાસો. ફરી પ્રયાસમાં એ જ વિનંતી ID રહેશે; વિગતો બદલશો નહીં.',
    ],
    'bookingRejected': [
      'Booking was rejected. Review availability, patient and clinic access before trying again.',
      'बुकिंग अस्वीकृत। उपलब्धता, मरीज़ और क्लिनिक पहुँच जाँचें।',
      'બુકિંગ નકારાયું. ઉપલબ્ધતા, દર્દી અને ક્લિનિક ઍક્સેસ તપાસો.',
    ],
    'retrySame': [
      'Retry same request',
      'उसी अनुरोध से पुनः प्रयास',
      'એ જ વિનંતી ફરી કરો',
    ],
    'saving': ['Saving…', 'सहेज रहे हैं…', 'સાચવી રહ્યું છે…'],
    'availability': [
      'Edit my availability',
      'मेरी उपलब्धता बदलें',
      'મારી ઉપલબ્ધતા બદલો',
    ],
    'availabilityHint': [
      'Review a break within clinic hours for the selected day. Existing bookings are never cancelled automatically.',
      'चुने दिन क्लिनिक के समय में अवकाश की समीक्षा करें। बुकिंग अपने आप रद्द नहीं होगी।',
      'પસંદ કરેલા દિવસે ક્લિનિકના સમયમાં વિરામની સમીક્ષા કરો. બુકિંગ આપમેળે રદ થશે નહીં.',
    ],
    'breakStart': ['Break starts', 'अवकाश शुरू', 'વિરામ શરૂ'],
    'breakEnd': ['Break ends', 'अवकाश समाप्त', 'વિરામ પૂરો'],
    'availabilityReviewed': [
      'I reviewed my sessions for this date.',
      'मैंने इस तिथि के सत्र जाँचे हैं।',
      'મેં આ તારીખના સત્રોની સમીક્ષા કરી છે.',
    ],
    'availabilityConflict': [
      'Change blocked: the session is invalid or overlaps an existing booking.',
      'बदलाव रुका: सत्र अमान्य या बुकिंग से टकराता है।',
      'ફેરફાર રોકાયો: સત્ર અમાન્ય છે અથવા બુકિંગ સાથે અથડાય છે.',
    ],
    'scheduleHint': [
      'Availability is checked again when confirming. Unassigned legacy visits must be reviewed before assigning new visits.',
      'पुष्टि पर उपलब्धता दोबारा जाँची जाती है। पुराने बिना चिकित्सक वाले रिकॉर्ड की समीक्षा करें।',
      'પુષ્ટિ વખતે ઉપલબ્ધતા ફરી તપાસાશે. જૂની તબીબ વગરની મુલાકાતોની સમીક્ષા કરો.',
    ],
    'scheduleUnavailable': [
      'Scheduling service is unavailable. An administrator must complete the clinic migration before using this workspace.',
      'शेड्यूल सेवा अनुपलब्ध है। व्यवस्थापक पहले क्लिनिक माइग्रेशन पूरा करें।',
      'શેડ્યૂલ સેવા ઉપલબ્ધ નથી. સંચાલકે પહેલાં ક્લિનિકનું સ્થળાંતર પૂર્ણ કરવું જરૂરી છે.',
    ],
    'noPractitioners': [
      'No approved practitioners are available in this clinic.',
      'इस क्लिनिक में अनुमोदित चिकित्सक उपलब्ध नहीं हैं।',
      'આ ક્લિનિકમાં મંજૂર તબીબ ઉપલબ્ધ નથી.',
    ],
    'unassigned': ['Unassigned', 'निर्धारित नहीं', 'સોંપાયેલ નથી'],
    'checkIn': [
      'Confirm identity and check in',
      'पहचान की पुष्टि कर चेक-इन करें',
      'ઓળખની પુષ્ટિ કરી ચેક-ઇન કરો',
    ],
    'nameChecked': [
      'Full name and patient ID confirmed.',
      'पूरा नाम और मरीज़ ID जाँचा।',
      'પૂરું નામ અને દર્દી ID ચકાસ્યા.',
    ],
    'contactChecked': [
      'Date of birth or registered mobile confirmed.',
      'जन्म तिथि या पंजीकृत मोबाइल जाँचा।',
      'જન્મતારીખ અથવા નોંધાયેલ મોબાઇલ ચકાસ્યો.',
    ],
    'arrivalConsent': [
      'Patient agrees to today’s check-in.',
      'मरीज़ आज के चेक-इन पर सहमत है।',
      'દર્દી આજના ચેક-ઇન માટે સંમત છે.',
    ],
    'arrivalHint': [
      'Check-in does not change reminder preferences or record clinical consent.',
      'चेक-इन रिमाइंडर प्राथमिकता या चिकित्सकीय सहमति नहीं बदलता।',
      'ચેક-ઇન રીમાઇન્ડરની પસંદગી અથવા તબીબી સંમતિ બદલતું નથી.',
    ],
    'name': ['Full name', 'पूरा नाम', 'પૂરું નામ'],
    'dob': ['Date of birth', 'जन्म तिथि', 'જન્મ તારીખ'],
    'email': ['Email', 'ईमेल', 'ઇમેઇલ'],
    'address': ['Address', 'पता', 'સરનામું'],
    'reason': ['Reason for correction', 'सुधार का कारण', 'સુધારાનું કારણ'],
    'required': [
      'Enter at least 5 characters.',
      'कम से कम 5 अक्षर दर्ज करें।',
      'ઓછામાં ઓછા 5 અક્ષર લખો.',
    ],
    'phoneError': [
      'Use an international phone number starting with +.',
      '+ से शुरू होने वाला अंतरराष्ट्रीय फ़ोन नंबर डालें।',
      '+ થી શરૂ થતો આંતરરાષ્ટ્રીય ફોન નંબર લખો.',
    ],
    'checked': [
      'Details checked with the patient.',
      'मरीज़ के साथ विवरण जाँचे गए।',
      'દર્દી સાથે વિગતો ચકાસી છે.',
    ],
    'save': [
      'Save reviewed changes',
      'समीक्षित बदलाव सहेजें',
      'સમીક્ષા કરેલા ફેરફારો સાચવો',
    ],
    'editHint': [
      'Contact and address changes only. A dated administrative audit is recorded when saved.',
      'केवल संपर्क और पता बदलें। सहेजने पर दिनांक सहित प्रशासनिक ऑडिट दर्ज होगा।',
      'માત્ર સંપર્ક અને સરનામું બદલો. સાચવતાં તારીખ સાથે વહીવટી ઓડિટ નોંધાશે.',
    ],
    'editError': [
      'Save failed or the record changed. Reload and review again.',
      'सहेजना विफल या रिकॉर्ड बदला है। दोबारा लोड कर समीक्षा करें।',
      'સાચવવું નિષ્ફળ અથવા રેકોર્ડ બદલાયો છે. ફરી લોડ કરી સમીક્ષા કરો.',
    ],
    'consentHint': [
      'An appointment or shared phone does not prove consent or portal ownership. Ask the patient before changing communication preferences.',
      'अपॉइंटमेंट या साझा फ़ोन सहमति या पोर्टल स्वामित्व सिद्ध नहीं करता। प्राथमिकताएँ बदलने से पहले मरीज़ से पूछें।',
      'મુલાકાત કે એક જ ફોન સંમતિ કે પોર્ટલ માલિકી સાબિત કરતા નથી. પસંદગી બદલતાં પહેલાં દર્દીને પૂછો.',
    ],
    'patients': ['Patients', 'मरीज़', 'દર્દીઓ'],
    'add': ['Add patient', 'मरीज़ जोड़ें', 'દર્દી ઉમેરો'],
    'register': ['Register patient', 'मरीज़ पंजीकरण', 'દર્દીની નોંધણી'],
    'directory': ['Patient directory', 'मरीज़ सूची', 'દર્દીની યાદી'],
    'directoryHint': [
      'Find patient registration, contact and appointment details. Clinical records are restricted to authorised doctors.',
      'पंजीकरण, संपर्क और अपॉइंटमेंट खोजें। चिकित्सकीय रिकॉर्ड केवल अधिकृत डॉक्टरों के लिए हैं।',
      'નોંધણી, સંપર્ક અને મુલાકાતની વિગતો શોધો. તબીબી રેકોર્ડ અધિકૃત ડૉક્ટરો માટે છે.',
    ],
    'registered': ['Registered patients', 'पंजीकृत मरीज़', 'નોંધાયેલા દર્દીઓ'],
    'newMonth': ['New this month', 'इस महीने नए', 'આ મહિને નવા'],
    'withBooking': [
      'Patients with upcoming appointments',
      'आगामी अपॉइंटमेंट वाले मरीज़',
      'આગામી મુલાકાત ધરાવતા દર્દીઓ',
    ],
    'search': [
      'Search by name, patient ID or phone number',
      'नाम, मरीज़ ID या फ़ोन से खोजें',
      'નામ, દર્દી ID અથવા ફોનથી શોધો',
    ],
    'identity': ['Patient / identifier', 'मरीज़ / पहचान', 'દર્દી / ઓળખ'],
    'ageSex': ['Age / sex', 'आयु / लिंग', 'ઉંમર / જાતિ'],
    'contact': ['Contact', 'संपर्क', 'સંપર્ક'],
    'registeredOn': ['Registered on', 'पंजीकरण तिथि', 'નોંધણી તારીખ'],
    'nextAppointment': ['Next appointment', 'अगला अपॉइंटमेंट', 'આગામી મુલાકાત'],
    'registration': ['Registration', 'पंजीकरण', 'નોંધણી'],
    'notBooked': ['Not booked', 'बुक नहीं हुआ', 'બુક નથી'],
    'manage': [
      'Manage registration →',
      'पंजीकरण प्रबंधित करें →',
      'નોંધણી સંભાળો →',
    ],
    'years': ['years', 'वर्ष', 'વર્ષ'],
    'showing': ['Showing', 'दिखा रहे हैं', 'દર્શાવેલ'],
    'previous': ['Previous page', 'पिछला पृष्ठ', 'પાછલું પાનું'],
    'next': ['Next page', 'अगला पृष्ठ', 'આગલું પાનું'],
    'empty': [
      'No patients registered yet.',
      'अभी कोई मरीज़ पंजीकृत नहीं है।',
      'હજુ દર્દી નોંધાયેલા નથી.',
    ],
    'noMatch': [
      'No patients match your search.',
      'खोज से कोई मरीज़ नहीं मिला।',
      'શોધમાં કોઈ દર્દી મળ્યા નથી.',
    ],
    'privacy': [
      'Administrative access: registration, contact and appointment details. Clinical notes, diagnoses and prescriptions remain in the doctor’s workspace.',
      'प्रशासनिक पहुँच: पंजीकरण, संपर्क और अपॉइंटमेंट। चिकित्सकीय नोट्स, निदान और दवाइयाँ डॉक्टर के कार्यक्षेत्र में हैं।',
      'વહીવટી ઍક્સેસ: નોંધણી, સંપર્ક અને મુલાકાત. તબીબી નોંધ, નિદાન અને પ્રિસ્ક્રિપ્શન ડૉક્ટરના કાર્યક્ષેત્રમાં છે.',
    ],
    'loadError': [
      'Unable to load records. Previously loaded data may be incomplete.',
      'रिकॉर्ड लोड नहीं हुए। पुराने डेटा अधूरे हो सकते हैं।',
      'રેકોર્ડ લોડ થયા નથી. પહેલાનો ડેટા અધૂરો હોઈ શકે છે.',
    ],
    'retry': ['Retry', 'पुनः प्रयास', 'ફરી પ્રયાસ'],
    'review': [
      'Registration review and duplicates',
      'पंजीकरण और डुप्लिकेट समीक्षा',
      'નોંધણી અને ડુપ્લિકેટ સમીક્ષા',
    ],
    'reviewHint': [
      'Not saved until confirmed. Compare possible matches with the patient.',
      'पुष्टि तक सहेजा नहीं गया। मरीज़ के साथ संभावित मिलान जाँचें।',
      'પુષ્ટિ થાય ત્યાં સુધી સાચવેલ નથી. દર્દી સાથે સંભવિત મેળ તપાસો.',
    ],
    'possibleMatch': [
      'Possible duplicate match',
      'संभावित डुप्लिकेट',
      'સંભવિત ડુપ્લિકેટ',
    ],
    'matchHint': [
      'A shared phone or similar name does not establish identity. No records will be merged.',
      'साझा फ़ोन या समान नाम पहचान सिद्ध नहीं करता। रिकॉर्ड नहीं मिलाए जाएँगे।',
      'એક જ ફોન અથવા સમાન નામ ઓળખ સાબિત કરતા નથી. રેકોર્ડ ભેગા કરાશે નહીં.',
    ],
    'reviewed': [
      'I reviewed possible matches with the patient.',
      'मैंने मरीज़ के साथ संभावित मिलान जाँचे हैं।',
      'મેં દર્દી સાથે સંભવિત મેળ તપાસ્યા છે.',
    ],
    'separate': [
      'Create a separate record; do not overwrite a match.',
      'अलग रिकॉर्ड बनाएँ; मिलान को न बदलें।',
      'અલગ રેકોર્ડ બનાવો; મેળ બદલશો નહીં.',
    ],
    'confirm': [
      'Confirm and create registration',
      'पुष्टि कर पंजीकरण बनाएँ',
      'પુષ્ટિ કરો અને નોંધણી બનાવો',
    ],
    'edit': ['Edit details', 'विवरण बदलें', 'વિગતો સંપાદિત કરો'],
    'careConsent': [
      'Patient consents to recording registration details for care and clinic administration.',
      'मरीज़ देखभाल और क्लिनिक प्रशासन के लिए पंजीकरण जानकारी दर्ज करने पर सहमत है।',
      'દર્દી સારવાર અને ક્લિનિક વહીવટ માટે નોંધણી માહિતી નોંધવા સંમત છે.',
    ],
    'careRequired': [
      'Record care consent before creating a new patient.',
      'नया मरीज़ बनाने से पहले सहमति दर्ज करें।',
      'નવા દર્દી બનાવતાં પહેલાં સંમતિ નોંધો.',
    ],
    'reminder': [
      'Reminder preference',
      'रिमाइंडर प्राथमिकता',
      'રીમાઇન્ડર પસંદગી',
    ],
    'yes': ['Recorded opt-in', 'सहमति दर्ज है', 'સંમતિ નોંધેલી છે'],
    'unknown': [
      'Not recorded — ask the patient',
      'दर्ज नहीं — मरीज़ से पूछें',
      'નોંધાયેલ નથી — દર્દીને પૂછો',
    ],
    'none': [
      'No possible matches in the available directory.',
      'उपलब्ध सूची में संभावित मिलान नहीं है।',
      'ઉપલબ્ધ યાદીમાં સંભવિત મેળ નથી.',
    ],
    'profile': [
      'Patient administrative profile',
      'मरीज़ प्रशासनिक प्रोफ़ाइल',
      'દર્દીની વહીવટી પ્રોફાઇલ',
    ],
    'details': ['Contact & identity', 'संपर्क और पहचान', 'સંપર્ક અને ઓળખ'],
    'appointments': [
      'Appointment history',
      'अपॉइंटमेंट इतिहास',
      'મુલાકાતનો ઇતિહાસ',
    ],
    'consent': [
      'Consent & communication',
      'सहमति और संचार',
      'સંમતિ અને સંદેશાવ્યવહાર',
    ],
    'book': [
      'Manage appointments',
      'अपॉइंटमेंट प्रबंधित करें',
      'મુલાકાતો સંભાળો',
    ],
    'back': ['Back to directory', 'सूची पर वापस', 'યાદી પર પાછા'],
    'noAppointments': [
      'No recorded appointments.',
      'कोई अपॉइंटमेंट दर्ज नहीं है।',
      'મુલાકાત નોંધાયેલી નથી.',
    ],
    'draftSave': [
      'Save encrypted draft',
      'एन्क्रिप्टेड ड्राफ्ट सहेजें',
      'એન્ક્રિપ્ટેડ ડ્રાફ્ટ સાચવો',
    ],
    'draftRestore': [
      'Restore encrypted draft',
      'एन्क्रिप्टेड ड्राफ्ट खोलें',
      'એન્ક્રિપ્ટેડ ડ્રાફ્ટ ખોલો',
    ],
    'passphrase': [
      'Draft passphrase (at least 16 characters)',
      'ड्राफ्ट पासफ़्रेज़ (कम से कम 16 अक्षर)',
      'ડ્રાફ્ટ પાસફ્રેઝ (ઓછામાં ઓછા 16 અક્ષર)',
    ],
    'draftHint': [
      'This device stores an encrypted draft only. Remember its passphrase; it cannot be recovered. Saving a draft does not register or book a patient.',
      'इस उपकरण पर केवल एन्क्रिप्टेड ड्राफ्ट रहेगा। पासफ़्रेज़ याद रखें; इसे वापस नहीं पाया जा सकता। ड्राफ्ट से पंजीकरण या बुकिंग नहीं होती।',
      'આ ઉપકરણ પર માત્ર એન્ક્રિપ્ટેડ ડ્રાફ્ટ રહેશે. પાસફ્રેઝ યાદ રાખો; તે પાછો મેળવી શકાતો નથી. ડ્રાફ્ટથી નોંધણી કે બુકિંગ થતી નથી.',
    ],
    'draftSaved': [
      'Encrypted draft saved on this device.',
      'इस उपकरण पर एन्क्रिप्टेड ड्राफ्ट सहेजा गया।',
      'આ ઉપકરણ પર એન્ક્રિપ્ટેડ ડ્રાફ્ટ સાચવ્યો.',
    ],
    'draftError': [
      'Draft unavailable, wrong passphrase, or changed in another tab. Restore the latest draft before replacing it.',
      'ड्राफ्ट अनुपलब्ध, गलत पासफ़्रेज़ या दूसरे टैब में बदला है। पहले नवीनतम ड्राफ्ट खोलें।',
      'ડ્રાફ્ટ ઉપલબ્ધ નથી, પાસફ્રેઝ ખોટો છે અથવા બીજા ટેબમાં બદલાયો છે. પહેલાં નવીનતમ ડ્રાફ્ટ ખોલો.',
    ],
    'draftMissing': [
      'No saved draft in this user and clinic scope.',
      'इस उपयोगकर्ता और क्लिनिक में ड्राफ्ट नहीं है।',
      'આ વપરાશકર્તા અને ક્લિનિકમાં ડ્રાફ્ટ નથી.',
    ],
    'cancel': ['Cancel', 'रद्द करें', 'રદ કરો'],
    'continue': ['Continue', 'जारी रखें', 'ચાલુ રાખો'],
  };
}
