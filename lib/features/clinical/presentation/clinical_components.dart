import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import '../../../core/design/uvilo_theme.dart';
import '../../../core/design/revamp_labels.dart';
import '../../../data/datasources/clinical_models.dart';

class ClinicalLabels {
  ClinicalLabels(this.language);
  final String language;
  factory ClinicalLabels.of(BuildContext context) =>
      ClinicalLabels(Localizations.localeOf(context).languageCode);
  String call(String key) {
    final values = _values[key];
    return values == null
        ? key
        : values[language == 'hi'
              ? 1
              : language == 'gu'
              ? 2
              : 0];
  }

  static const _values = <String, List<String>>{
    'revoke': [
      'Revoke patient access',
      'रोगी की पहुँच वापस लें',
      'દર્દીની ઍક્સેસ રદ કરો',
    ],
    'revokeReason': [
      'Reason for revoking access (at least 5 characters)',
      'पहुँच वापस लेने का कारण (कम से कम 5 अक्षर)',
      'ઍક્સેસ રદ કરવાનું કારણ (ઓછામાં ઓછા 5 અક્ષર)',
    ],
    'publishedVersion': [
      'The previously signed version is still released; this draft is private.',
      'पहले का हस्ताक्षरित संस्करण अभी जारी है; यह मसौदा निजी है।',
      'પહેલાની સહી કરેલ આવૃત્તિ હજી ઉપલબ્ધ છે; આ મુસદ્દો ખાનગી છે.',
    ],
    'done': ['Done', 'पूर्ण', 'પૂર્ણ'],
    'drafts': [
      'Saved consultation drafts',
      'सहेजे गए परामर्श मसौदे',
      'સાચવેલા પરામર્શ મુસદ્દા',
    ],
    'resume': ['Resume draft', 'मसौदा जारी रखें', 'મુસદ્દો ચાલુ રાખો'],
    'versions': [
      'Signed version history',
      'हस्ताक्षरित संस्करणों का इतिहास',
      'સહી કરેલ આવૃત્તિઓનો ઇતિહાસ',
    ],
    'print': ['Print preview', 'प्रिंट पूर्वावलोकन', 'પ્રિન્ટ પૂર્વાવલોકન'],
    'finalReview': [
      'Review, sign and complete visit',
      'समीक्षा, हस्ताक्षर और मुलाकात पूर्ण करें',
      'સમીક્ષા, સહી અને મુલાકાત પૂર્ણ કરો',
    ],
    'signedRecord': [
      'Signed prescription',
      'हस्ताक्षरित प्रिस्क्रिप्शन',
      'સહી કરેલ પ્રિસ્ક્રિપ્શન',
    ],
    'sign': [
      'Sign and complete visit',
      'हस्ताक्षर करके मुलाकात पूर्ण करें',
      'સહી કરીને મુલાકાત પૂર્ણ કરો',
    ],
    'signAck': [
      'I confirm this is the final version. Corrections will require an audited amendment.',
      'मैं पुष्टि करता/करती हूँ कि यह अंतिम संस्करण है। सुधार के लिए दर्ज संशोधन आवश्यक होगा।',
      'હું પુષ્ટિ કરું છું કે આ અંતિમ આવૃત્તિ છે. સુધારા માટે નોંધાયેલ સુધારો જરૂરી રહેશે.',
    ],
    'signHint': [
      'Signing requires an online server acknowledgement and records your practitioner identity. The signed version is immutable. Patient release is a separate action. Private notes stay separate.',
      'हस्ताक्षर के लिए ऑनलाइन सर्वर की पुष्टि आवश्यक है और आपकी चिकित्सक पहचान दर्ज होगी। हस्ताक्षरित संस्करण अपरिवर्तनीय है। रोगी को जारी करना अलग क्रिया है। निजी नोट्स अलग रहेंगे।',
      'સહી માટે ઑનલાઇન સર્વરની પુષ્ટિ જરૂરી છે અને તમારી તબીબ ઓળખ નોંધાશે. સહી કરેલ આવૃત્તિ અપરિવર્તનીય છે. દર્દીને આપવું અલગ ક્રિયા છે. ખાનગી નોંધો અલગ રહેશે.',
    ],
    'release': [
      'Release to linked patient account',
      'लिंक किए गए रोगी खाते को जारी करें',
      'લિંક થયેલ દર્દીના ખાતામાં આપો',
    ],
    'releaseAck': [
      'I verified the linked patient account and consent to release this signed version.',
      'मैंने लिंक किए गए रोगी खाते की जाँच की और यह हस्ताक्षरित संस्करण जारी करने की सहमति ली है।',
      'મેં લિંક થયેલ દર્દીનું ખાતું ચકાસ્યું છે અને આ સહી કરેલ આવૃત્તિ આપવા સંમતિ લીધી છે.',
    ],
    'released': [
      'Released to linked patient account',
      'लिंक किए गए रोगी खाते को जारी किया गया',
      'લિંક થયેલ દર્દીના ખાતામાં આપ્યું',
    ],
    'amend': [
      'Start an audited amendment',
      'दर्ज संशोधन शुरू करें',
      'નોંધાયેલ સુધારો શરૂ કરો',
    ],
    'amendReason': [
      'Reason for amendment (at least 5 characters)',
      'संशोधन का कारण (कम से कम 5 अक्षर)',
      'સુધારાનું કારણ (ઓછામાં ઓછા 5 અક્ષર)',
    ],
    'reload': [
      'Reload server record',
      'सर्वर रिकॉर्ड पुनः लोड करें',
      'સર્વર રેકોર્ડ ફરી ખોલો',
    ],
    'remoteError': [
      'The action is not confirmed. Keep your encrypted recovery copy and reload the server record before retrying. A changed record must be reviewed again.',
      'क्रिया की पुष्टि नहीं हुई। एन्क्रिप्टेड रिकवरी प्रति रखें और फिर कोशिश करने से पहले सर्वर रिकॉर्ड पुनः लोड करें। बदले रिकॉर्ड की दोबारा समीक्षा आवश्यक है।',
      'ક્રિયાની પુષ્ટિ થઈ નથી. એન્ક્રિપ્ટેડ પુનઃપ્રાપ્તિ નકલ રાખો અને ફરી પ્રયાસ પહેલાં સર્વર રેકોર્ડ ફરી ખોલો. બદલાયેલ રેકોર્ડની ફરી સમીક્ષા જરૂરી છે.',
    ],
    'visitNotes': ['Visit notes', 'मुलाकात के नोट्स', 'મુલાકાતની નોંધો'],
    'assessmentPlan': [
      'Assessment and plan',
      'आकलन और योजना',
      'આકલન અને યોજના',
    ],
    'discard': [
      'Delete device recovery copy',
      'डिवाइस की रिकवरी प्रति हटाएँ',
      'ઉપકરણની પુનઃપ્રાપ્તિ નકલ કાઢો',
    ],
    'workspace': [
      'Consultation workspace',
      'परामर्श कार्यक्षेत्र',
      'પરામર્શ કાર્યક્ષેત્ર',
    ],
    'review': [
      'Review prescription',
      'प्रिस्क्रिप्शन की समीक्षा',
      'પ્રિસ્ક્રિપ્શનની સમીક્ષા',
    ],
    'draft': [
      'Draft · not signed',
      'मसौदा · हस्ताक्षरित नहीं',
      'મુસદ્દો · સહી કરેલ નથી',
    ],
    'allergies': ['Recorded allergies', 'दर्ज एलर्जी', 'નોંધાયેલ એલર્જી'],
    'unknownAllergies': [
      'No allergy information recorded. Verify with the patient.',
      'एलर्जी की जानकारी दर्ज नहीं है। रोगी से पुष्टि करें।',
      'એલર્જીની માહિતી નોંધાયેલ નથી. દર્દી સાથે ચકાસો.',
    ],
    'identity': [
      'Patient and encounter details reviewed',
      'रोगी और मुलाकात का विवरण जाँचा',
      'દર્દી અને મુલાકાતની વિગતો તપાસી',
    ],
    'medication': [
      'Allergies and medicine instructions reviewed',
      'एलर्जी और दवा के निर्देश जाँचे',
      'એલર્જી અને દવાની સૂચનાઓ તપાસી',
    ],
    'plan': [
      'Assessment, advice and follow-up reviewed',
      'आकलन, सलाह और फॉलो-अप जाँचे',
      'આકલન, સલાહ અને અનુસરણ તપાસ્યું',
    ],
    'saveHint': [
      'Saving uses the existing clinic workflow. This review does not create a digital signature. Private notes are excluded from this summary and patient PDFs.',
      'सहेजने पर मौजूदा क्लिनिक प्रक्रिया लागू होगी। यह समीक्षा डिजिटल हस्ताक्षर नहीं बनाती। निजी नोट्स इस सारांश और रोगी PDF में शामिल नहीं हैं।',
      'સાચવવા માટે હાલની ક્લિનિક પ્રક્રિયા લાગુ થશે. આ સમીક્ષા ડિજિટલ સહી બનાવતી નથી. ખાનગી નોંધો આ સારાંશ અને દર્દીની PDFમાં સામેલ નથી.',
    ],
    'localSave': [
      'Save encrypted draft',
      'एन्क्रिप्टेड मसौदा सहेजें',
      'એન્ક્રિપ્ટેડ મુસદ્દો સાચવો',
    ],
    'localRestore': [
      'Restore encrypted draft',
      'एन्क्रिप्टेड मसौदा पुनः खोलें',
      'એન્ક્રિપ્ટેડ મુસદ્દો પુનઃ ખોલો',
    ],
    'password': [
      'Draft passphrase (at least 16 characters)',
      'मसौदे का पासफ्रेज (कम से कम 16 अक्षर)',
      'મુસદ્દાનો પાસફ્રેઝ (ઓછામાં ઓછા 16 અક્ષર)',
    ],
    'localHint': [
      'Stored only on this device, encrypted with your passphrase. Restore replaces the open draft. Keep the passphrase safe; it cannot be recovered. Saving to the clinic does not delete this recovery copy.',
      'इस डिवाइस पर पासफ्रेज से एन्क्रिप्ट होकर रहेगा। पुनर्स्थापित करने पर खुला मसौदा बदलेगा। पासफ्रेज सुरक्षित रखें; इसे वापस नहीं पाया जा सकता। क्लिनिक में सहेजने पर यह प्रति नहीं मिटेगी।',
      'આ ઉપકરણ પર પાસફ્રેઝથી એન્ક્રિપ્ટ થયેલ રહેશે. પુનઃ ખોલવાથી ખુલ્લો મુસદ્દો બદલાશે. પાસફ્રેઝ સુરક્ષિત રાખો; તેને પાછો મેળવી શકાતો નથી. ક્લિનિકમાં સાચવવાથી આ નકલ ભૂંસાશે નહીં.',
    ],
    'localDone': [
      'Encrypted draft saved on this device',
      'एन्क्रिप्टेड मसौदा इस डिवाइस पर सहेजा गया',
      'એન્ક્રિપ્ટેડ મુસદ્દો આ ઉપકરણ પર સાચવ્યો',
    ],
    'restored': [
      'Draft restored; review before saving to the clinic',
      'मसौदा बहाल; क्लिनिक में सहेजने से पहले समीक्षा करें',
      'મુસદ્દો પુનઃ ખોલ્યો; ક્લિનિકમાં સાચવતા પહેલાં સમીક્ષા કરો',
    ],
    'localError': [
      'Draft unavailable, incorrect passphrase, or changed in another window. Restore the latest draft before retrying.',
      'मसौदा अनुपलब्ध, गलत पासफ्रेज या दूसरी विंडो में बदला गया। फिर कोशिश करने से पहले नवीनतम मसौदा खोलें।',
      'મુસદ્દો ઉપલબ્ધ નથી, પાસફ્રેઝ ખોટો છે અથવા બીજી વિન્ડોમાં બદલાયો છે. ફરી પ્રયાસ પહેલાં તાજેતરનો મુસદ્દો ખોલો.',
    ],
    'queued': [
      'Saved or queued for clinic sync. Check the clinic record after reconnecting.',
      'क्लिनिक सिंक के लिए सहेजा या कतारबद्ध। कनेक्शन लौटने पर रिकॉर्ड जाँचें।',
      'ક્લિનિક સિંક માટે સાચવ્યું અથવા કતારમાં મૂક્યું. જોડાણ પાછું આવે ત્યારે રેકોર્ડ તપાસો.',
    ],
    'record': ['Patient record', 'रोगी रिकॉर्ड', 'દર્દીનો રેકોર્ડ'],
    'noData': ['Not recorded', 'दर्ज नहीं', 'નોંધાયેલ નથી'],
  };
}

class ClinicalEditorColumns extends StatelessWidget {
  const ClinicalEditorColumns({
    super.key,
    required this.sidebar,
    required this.content,
  });
  final Widget sidebar, content;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) => constraints.maxWidth >= 1000
        ? Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(width: 290, child: sidebar),
              const SizedBox(width: 20),
              Expanded(child: content),
            ],
          )
        : Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [sidebar, const SizedBox(height: 16), content],
          ),
  );
}

class ClinicalCard extends StatelessWidget {
  const ClinicalCard({
    super.key,
    required this.title,
    required this.child,
    this.icon,
  });
  final String title;
  final Widget child;
  final String? icon;
  @override
  Widget build(BuildContext context) => Card(
    child: Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                SvgPicture.asset(
                  'assets/figma/phase3/$icon',
                  width: icon == '4_18896_imgCircleCheck.svg' ? 16 : 18,
                  height: icon == '4_18896_imgCircleCheck.svg' ? 16 : 18,
                ),
                const SizedBox(width: 10),
              ],
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: UviloTheme.ink,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    ),
  );
}

class ClinicalPatientBanner extends StatelessWidget {
  const ClinicalPatientBanner({
    super.key,
    required this.patient,
    this.encounter,
  });
  final PatientModel patient;
  final String? encounter;
  @override
  Widget build(BuildContext context) => ClinicalCard(
    title: ClinicalLabels.of(context)('record'),
    child: Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        CircleAvatar(
          radius: 28,
          backgroundColor: UviloTheme.soft,
          child: Text(
            patient.firstName.isEmpty
                ? '?'
                : patient.firstName.characters.first.toUpperCase(),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                patient.fullName,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                [
                  patient.id,
                  if (patient.age != null)
                    '${patient.age} ${RevampLabels.of(context).text(patient.ageUnit)}',
                  if (patient.gender.isNotEmpty)
                    RevampLabels.of(context).text(patient.gender),
                  if (encounter?.isNotEmpty == true) encounter!,
                ].where((s) => s.isNotEmpty).join(' · '),
              ),
            ],
          ),
        ),
      ],
    ),
  );
}

class ClinicalAllergyBanner extends StatelessWidget {
  const ClinicalAllergyBanner({super.key, required this.allergies});
  final List<String> allergies;
  @override
  Widget build(BuildContext context) {
    final l = ClinicalLabels.of(context);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFFFFF0E6),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFF1C5AA)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SvgPicture.asset(
            'assets/figma/phase3/4_18715_imgShieldAlert.svg',
            width: 18,
            height: 18,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              allergies.isEmpty
                  ? l('unknownAllergies')
                  : '${l('allergies')}: ${allergies.join(', ')}',
            ),
          ),
        ],
      ),
    );
  }
}
