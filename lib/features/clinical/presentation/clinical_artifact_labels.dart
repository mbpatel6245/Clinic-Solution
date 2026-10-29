import 'package:flutter/widgets.dart';

class ArtifactLabels {
  const ArtifactLabels(this.language);
  final String language;
  factory ArtifactLabels.of(BuildContext context) =>
      ArtifactLabels(Localizations.localeOf(context).languageCode);
  String call(String key) =>
      (_values[key] ?? [key, key, key])[language == 'hi'
          ? 1
          : language == 'gu'
          ? 2
          : 0];
  static const _values = <String, List<String>>{
    'deviceTime': [
      'Time zone on this device',
      'इस डिवाइस का समय क्षेत्र',
      'આ ઉપકરણનો સમય ઝોન',
    ],
    'resaveHint': [
      'If the patient or source records changed, return to the draft, save it again and repeat the review.',
      'यदि रोगी या स्रोत रिकॉर्ड बदले हैं, मसौदे पर वापस जाएँ, फिर सहेजें और समीक्षा दोहराएँ।',
      'દર્દી કે સ્રોત રેકોર્ડ બદલાયા હોય તો મુસદ્દા પર પાછા જઈ ફરી સાચવો અને સમીક્ષા કરો.',
    ],
    'documents': [
      'Clinical documents',
      'क्लिनिकल दस्तावेज़',
      'તબીબી દસ્તાવેજો',
    ],
    'openReview': [
      'Open current version for review',
      'समीक्षा के लिए मौजूदा संस्करण खोलें',
      'સમીક્ષા માટે હાલની આવૃત્તિ ખોલો',
    ],
    'releaseAck': [
      'I verified the linked patient account and consent to release this reviewed version.',
      'मैंने लिंक किए गए रोगी खाते की जाँच की और यह समीक्षित संस्करण जारी करने की सहमति ली है।',
      'મેં લિંક થયેલ દર્દીનું ખાતું ચકાસ્યું છે અને આ સમીક્ષિત આવૃત્તિ આપવા સંમતિ લીધી છે.',
    ],
    'publishedVersion': [
      'The previously issued version is still released; this amendment is private.',
      'पहले जारी संस्करण की पहुँच बनी है; यह संशोधन निजी है।',
      'અગાઉ આપેલી આવૃત્તિ હજી ઉપલબ્ધ છે; આ સુધારો ખાનગી છે.',
    ],
    'versions': [
      'Issued version history',
      'जारी संस्करणों का इतिहास',
      'આપેલ આવૃત્તિઓનો ઇતિહાસ',
    ],
    'collectionPrecision': [
      'Collection time is recorded to the minute.',
      'संग्रह समय मिनट तक दर्ज किया जाता है।',
      'સંગ્રહ સમય મિનિટ સુધી નોંધાય છે.',
    ],
    'noNewVaccination': [
      'Releasing this copy does not record a new vaccination.',
      'यह प्रति जारी करने से नया टीकाकरण दर्ज नहीं होता।',
      'આ નકલ આપવાથી નવું રસીકરણ નોંધાતું નથી.',
    ],
    'reference': ['Document reference', 'दस्तावेज़ संदर्भ', 'દસ્તાવેજ સંદર્ભ'],
    'recordedCompleted': [
      'Recorded as completed',
      'पूर्ण के रूप में दर्ज',
      'પૂર્ણ થયેલ તરીકે નોંધાયેલ',
    ],
    'recordedPlanned': [
      'Recorded as planned',
      'नियोजित के रूप में दर्ज',
      'આયોજન તરીકે નોંધાયેલ',
    ],
    'withinRange': [
      'Within reported range',
      'रिपोर्ट की सीमा में',
      'રિપોર્ટની મર્યાદામાં',
    ],
    'result': ['Result', 'परिणाम', 'પરિણામ'],
    'referenceRange': [
      'Reported reference range',
      'रिपोर्ट की संदर्भ सीमा',
      'રિપોર્ટની સંદર્ભ મર્યાદા',
    ],
    'dose': [
      'Recorded dose number',
      'दर्ज खुराक संख्या',
      'નોંધાયેલ ડોઝ ક્રમાંક',
    ],
    'batch': ['Batch / lot', 'बैच / लॉट', 'બેચ / લોટ'],
    'administered': ['Administration date', 'टीकाकरण तिथि', 'રસીકરણ તારીખ'],
    'labs': [
      'Lab orders and results',
      'लैब आदेश और परिणाम',
      'લેબ ઓર્ડર અને પરિણામો',
    ],
    'care': ['Care-plan release', 'देखभाल योजना जारी करना', 'સંભાળ યોજના આપવી'],
    'newOrder': ['New lab order', 'नया लैब आदेश', 'નવો લેબ ઓર્ડર'],
    'newResult': [
      'Review a lab report',
      'लैब रिपोर्ट की समीक्षा',
      'લેબ રિપોર્ટની સમીક્ષા',
    ],
    'newCare': [
      'Review care-plan copy',
      'देखभाल योजना की प्रति की समीक्षा',
      'સંભાળ યોજનાની નકલની સમીક્ષા',
    ],
    'labOrder': ['Lab requisition', 'लैब अनुरोध पत्र', 'લેબ વિનંતી પત્ર'],
    'labResult': [
      'Reviewed lab report',
      'समीक्षित लैब रिपोर्ट',
      'સમીક્ષિત લેબ રિપોર્ટ',
    ],
    'carePlan': [
      'Reviewed care plan',
      'समीक्षित देखभाल योजना',
      'સમીક્ષિત સંભાળ યોજના',
    ],
    'title': ['Document title', 'दस्तावेज़ का शीर्षक', 'દસ્તાવેજનું શીર્ષક'],
    'tests': [
      'Investigations — one per line',
      'जाँचें — प्रत्येक पंक्ति में एक',
      'તપાસો — દરેક પંક્તિમાં એક',
    ],
    'plannedDate': [
      'Requested collection date',
      'नमूना संग्रह की अनुरोधित तिथि',
      'નમૂનો એકત્ર કરવાની વિનંતી તારીખ',
    ],
    'indication': [
      'Clinical indication — included on requisition',
      'क्लिनिकल कारण — अनुरोध पत्र में शामिल',
      'તબીબી કારણ — વિનંતી પત્રમાં સામેલ',
    ],
    'reportedDate': [
      'Date printed on report',
      'रिपोर्ट पर दर्ज तिथि',
      'રિપોર્ટ પર નોંધાયેલ તારીખ',
    ],
    'source': [
      'Report identifier / checked source',
      'रिपोर्ट पहचान / जाँचा गया स्रोत',
      'રિપોર્ટ ઓળખ / ચકાસેલો સ્રોત',
    ],
    'reviewNote': [
      'Clinical review — included in patient copy',
      'क्लिनिकल समीक्षा — रोगी की प्रति में शामिल',
      'તબીબી સમીક્ષા — દર્દીની નકલમાં સામેલ',
    ],
    'analyte': ['Investigation', 'जाँच', 'તપાસ'],
    'value': [
      'Numeric or text result',
      'संख्यात्मक या पाठ परिणाम',
      'આંકડાકીય અથવા લખાણ પરિણામ',
    ],
    'unit': [
      'Unit (required for numbers)',
      'इकाई (संख्या के लिए आवश्यक)',
      'એકમ (આંકડા માટે જરૂરી)',
    ],
    'lower': [
      'Reported lower reference bound',
      'रिपोर्ट की निचली संदर्भ सीमा',
      'રિપોર્ટની નીચલી સંદર્ભ મર્યાદા',
    ],
    'upper': [
      'Reported upper reference bound',
      'रिपोर्ट की ऊपरी संदर्भ सीमा',
      'રિપોર્ટની ઉપલી સંદર્ભ મર્યાદા',
    ],
    'addRow': ['Add result row', 'परिणाम पंक्ति जोड़ें', 'પરિણામ પંક્તિ ઉમેરો'],
    'encounter': ['Source consultation', 'स्रोत परामर्श', 'સ્રોત પરામર્શ'],
    'noEncounter': [
      'No consultation link',
      'परामर्श लिंक नहीं',
      'પરામર્શ લિંક નથી',
    ],
    'order': [
      'Linked collected order',
      'संबंधित संग्रहित आदेश',
      'લિંક થયેલ એકત્રિત ઓર્ડર',
    ],
    'externalReport': [
      'External report — no order link',
      'बाहरी रिपोर्ट — आदेश लिंक नहीं',
      'બાહ્ય રિપોર્ટ — ઓર્ડર લિંક નથી',
    ],
    'instructions': [
      'Select existing signed advice',
      'मौजूदा हस्ताक्षरित सलाह चुनें',
      'હાલની સહી કરેલ સલાહ પસંદ કરો',
    ],
    'sourcePlan': [
      'Existing treatment plan (optional)',
      'मौजूदा उपचार योजना (वैकल्पिक)',
      'હાલની સારવાર યોજના (વૈકલ્પિક)',
    ],
    'noPlan': [
      'No treatment plan included',
      'उपचार योजना शामिल नहीं',
      'સારવાર યોજના સામેલ નથી',
    ],
    'vaccines': [
      'Recorded vaccination history',
      'दर्ज टीकाकरण इतिहास',
      'નોંધાયેલ રસીકરણ ઇતિહાસ',
    ],
    'unknownHistory': [
      'History not selected or unavailable. Verify with the patient; this does not mean unvaccinated.',
      'इतिहास चयनित या उपलब्ध नहीं है। रोगी से पुष्टि करें; इसका अर्थ टीकाकरण न होना नहीं है।',
      'ઇતિહાસ પસંદ કરેલ નથી અથવા ઉપલબ્ધ નથી. દર્દી સાથે ચકાસો; તેનો અર્થ રસી ન લીધી હોય તેવો નથી.',
    ],
    'verification': [
      'Vaccination source/verification note — private',
      'टीकाकरण स्रोत/सत्यापन नोट — निजी',
      'રસીકરણ સ્રોત/ચકાસણી નોંધ — ખાનગી',
    ],
    'sourceHint': [
      'This copy uses existing advice and selected records. Private treatment notes are excluded. To change advice, amend the consultation first.',
      'इस प्रति में मौजूदा सलाह और चुने गए रिकॉर्ड हैं। निजी उपचार नोट शामिल नहीं हैं। सलाह बदलने के लिए पहले परामर्श में संशोधन करें।',
      'આ નકલમાં હાલની સલાહ અને પસંદ કરેલા રેકોર્ડ છે. ખાનગી સારવાર નોંધો સામેલ નથી. સલાહ બદલવા પહેલાં પરામર્શમાં સુધારો કરો.',
    ],
    'saveReview': [
      'Save draft and review',
      'मसौदा सहेजकर समीक्षा करें',
      'મુસદ્દો સાચવીને સમીક્ષા કરો',
    ],
    'issue': [
      'Confirm reviewed document',
      'समीक्षित दस्तावेज़ की पुष्टि करें',
      'સમીક્ષિત દસ્તાવેજની પુષ્ટિ કરો',
    ],
    'ackIdentity': [
      'Patient and responsible practitioner verified',
      'रोगी और जिम्मेदार चिकित्सक सत्यापित',
      'દર્દી અને જવાબદાર તબીબ ચકાસ્યા',
    ],
    'ackContent': [
      'Document contents and dates reviewed',
      'दस्तावेज़ की सामग्री और तिथियाँ जाँचीं',
      'દસ્તાવેજની સામગ્રી અને તારીખો તપાસી',
    ],
    'ackSource': [
      'Source records, values and units checked; existing care remains unchanged',
      'स्रोत रिकॉर्ड, मान और इकाइयाँ जाँचीं; मौजूदा देखभाल अपरिवर्तित है',
      'સ્રોત રેકોર્ડ, મૂલ્યો અને એકમો તપાસ્યા; હાલની સંભાળ યથાવત છે',
    ],
    'ackFinal': [
      'Confirm an immutable reviewed version; patient release is separate',
      'अपरिवर्तनीय समीक्षित संस्करण की पुष्टि; रोगी को जारी करना अलग है',
      'અપરિવર્તનીય સમીક્ષિત આવૃત્તિની પુષ્ટિ; દર્દીને આપવું અલગ છે',
    ],
    'separateStatus': [
      'An order is not a result. Printing a requisition does not record collection or release a patient copy.',
      'आदेश परिणाम नहीं है। अनुरोध पत्र प्रिंट करने से संग्रह दर्ज या रोगी को प्रति जारी नहीं होती।',
      'ઓર્ડર પરિણામ નથી. વિનંતી પત્ર છાપવાથી સંગ્રહ નોંધાતો નથી કે દર્દીને નકલ મળતી નથી.',
    ],
    'rangeHint': [
      'Reference ranges are those entered from the report; they are not individual treatment targets.',
      'संदर्भ सीमाएँ रिपोर्ट से दर्ज हैं; ये व्यक्तिगत उपचार लक्ष्य नहीं हैं।',
      'સંદર્ભ મર્યાદાઓ રિપોર્ટમાંથી નોંધાયેલ છે; તે વ્યક્તિગત સારવારના લક્ષ્યો નથી.',
    ],
    'outsideRange': [
      'Outside reported range',
      'रिपोर्ट की सीमा से बाहर',
      'રિપોર્ટની મર્યાદા બહાર',
    ],
    'draft': ['Draft · not issued', 'मसौदा · जारी नहीं', 'મુસદ્દો · આપેલ નથી'],
    'issued': [
      'Issued reviewed copy',
      'समीक्षित प्रति जारी',
      'સમીક્ષિત નકલ આપી',
    ],
    'ordered': ['Pending collection', 'संग्रह लंबित', 'સંગ્રહ બાકી'],
    'collected': ['Collection recorded', 'संग्रह दर्ज', 'સંગ્રહ નોંધાયો'],
    'cancelled': ['Cancelled', 'रद्द', 'રદ'],
    'collect': [
      'Record actual collection',
      'वास्तविक संग्रह दर्ज करें',
      'વાસ્તવિક સંગ્રહ નોંધો',
    ],
    'collectAck': [
      'I checked the order, patient and actual collection time',
      'मैंने आदेश, रोगी और वास्तविक संग्रह समय जाँचा',
      'મેં ઓર્ડર, દર્દી અને વાસ્તવિક સંગ્રહ સમય તપાસ્યો',
    ],
    'cancelOrder': ['Cancel this order', 'यह आदेश रद्द करें', 'આ ઓર્ડર રદ કરો'],
    'reason': [
      'Reason (at least 5 characters)',
      'कारण (कम से कम 5 अक्षर)',
      'કારણ (ઓછામાં ઓછા 5 અક્ષર)',
    ],
    'matchingOrder': [
      'A matching pending order exists. Review it before creating another. Your new draft is retained.',
      'मिलता हुआ लंबित आदेश मौजूद है। दूसरा बनाने से पहले उसकी समीक्षा करें। नया मसौदा सुरक्षित है।',
      'સમાન બાકી ઓર્ડર છે. બીજો બનાવતાં પહેલાં તેની સમીક્ષા કરો. નવો મુસદ્દો સાચવેલો છે.',
    ],
    'viewExisting': [
      'Review existing order',
      'मौजूदा आदेश की समीक्षा',
      'હાલના ઓર્ડરની સમીક્ષા',
    ],
    'legacy': [
      'Existing measurements and records',
      'मौजूदा माप और रिकॉर्ड',
      'હાલના માપ અને રેકોર્ડ',
    ],
    'legacyHint': [
      'Existing measurements are retained. Their original review status is not inferred.',
      'मौजूदा माप सुरक्षित हैं। उनकी मूल समीक्षा स्थिति का अनुमान नहीं लगाया जाता।',
      'હાલના માપ સાચવેલા છે. તેમની મૂળ સમીક્ષા સ્થિતિનો અંદાજ લગાવાતો નથી.',
    ],
    'empty': [
      'No clinical documents yet',
      'अभी कोई क्लिनिकल दस्तावेज़ नहीं',
      'હજુ કોઈ તબીબી દસ્તાવેજ નથી',
    ],
    'choosePatient': [
      'Select a registered patient',
      'पंजीकृत रोगी चुनें',
      'નોંધાયેલ દર્દી પસંદ કરો',
    ],
    'sourcesUnavailable': [
      'Sources could not be refreshed. Saved recovery is still available; final review requires a connection.',
      'स्रोत पुनः लोड नहीं हुए। सहेजी रिकवरी उपलब्ध है; अंतिम समीक्षा के लिए कनेक्शन चाहिए।',
      'સ્રોત ફરી ખોલી શકાયા નથી. સાચવેલી પુનઃપ્રાપ્તિ ઉપલબ્ધ છે; અંતિમ સમીક્ષા માટે જોડાણ જરૂરી છે.',
    ],
    'sharingDisabled': [
      'Patient sharing is not enabled for lab and care-plan copies.',
      'लैब और देखभाल योजना की प्रतियों के लिए रोगी साझाकरण सक्षम नहीं है।',
      'લેબ અને સંભાળ યોજનાની નકલો માટે દર્દી સાથે વહેંચણી સક્ષમ નથી.',
    ],
    'sharingSetting': [
      'Allow patient access to reviewed lab and care-plan copies',
      'समीक्षित लैब और देखभाल योजना की प्रतियों तक रोगी की पहुँच दें',
      'સમીક્ષિત લેબ અને સંભાળ યોજનાની નકલો માટે દર્દીને ઍક્સેસ આપો',
    ],
    'sharingSettingHint': [
      'Doctors must still explicitly review and release each copy. Turning this off withdraws existing access.',
      'चिकित्सक को फिर भी प्रत्येक प्रति की समीक्षा करके उसे जारी करना होगा। इसे बंद करने पर मौजूदा पहुँच हटती है।',
      'તબીબે દરેક નકલની સમીક્ષા કરીને તેને આપવી જરૂરી છે. આ બંધ કરવાથી હાલની ઍક્સેસ દૂર થાય છે.',
    ],
    'patientCopies': [
      'Shared lab reports and care plans',
      'साझा लैब रिपोर्ट और देखभाल योजनाएँ',
      'વહેંચાયેલ લેબ રિપોર્ટ અને સંભાળ યોજનાઓ',
    ],
    'plannedReview': [
      'Planned review date — not a confirmed appointment',
      'समीक्षा की नियोजित तिथि — पुष्ट अपॉइंटमेंट नहीं',
      'સમીક્ષાની આયોજન તારીખ — પુષ્ટિ થયેલ મુલાકાત નથી',
    ],
    'version': ['Version', 'संस्करण', 'આવૃત્તિ'],
    'history': ['Release history', 'जारी करने का इतिहास', 'આપવાનો ઇતિહાસ'],
  };
}
