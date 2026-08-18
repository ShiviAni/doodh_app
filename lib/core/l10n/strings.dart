import 'package:flutter/widgets.dart';

/// Supported UI languages. Hindi is the default for the delivery role.
enum AppLanguage { hindi, english }

/// Hand-rolled string table.
///
/// Deliberately not ARB/gen-l10n: there are only two locales and a few dozen
/// strings, and the delivery screens need the Hindi and English wording to sit
/// side by side while we tune them for a reader who is not fully literate.
class S {
  const S(this.lang);

  final AppLanguage lang;

  static S of(BuildContext context) => _InheritedStrings.of(context).strings;

  String _p(String hi, String en) => lang == AppLanguage.hindi ? hi : en;

  // --- generic ---
  String get appName => _p('दूध हिसाब', 'Doodh Hisab');
  String get save => _p('सेव करें', 'Save');
  String get cancel => _p('रद्द करें', 'Cancel');
  String get delete => _p('हटाएं', 'Delete');
  String get edit => _p('बदलें', 'Edit');
  String get add => _p('जोड़ें', 'Add');
  String get done => _p('हो गया', 'Done');
  String get back => _p('पीछे', 'Back');
  String get retry => _p('फिर कोशिश करें', 'Retry');
  String get today => _p('आज', 'Today');
  String get yesterday => _p('कल', 'Yesterday');
  String get litre => _p('ली', 'L');
  String get litres => _p('लीटर', 'litres');
  String get rupees => _p('रुपये', 'Rupees');

  // --- auth ---
  String get login => _p('लॉगिन करें', 'Log in');
  String get logout => _p('लॉगआउट', 'Log out');
  String get email => _p('ईमेल', 'Email');
  String get password => _p('पासवर्ड', 'Password');
  String get loginFailed => _p('लॉगिन नहीं हुआ', 'Login failed');
  String get noAccessTitle => _p('पहुँच नहीं है', 'No access');
  String get noAccessBody => _p(
    'यह खाता किसी डेयरी से जुड़ा नहीं है। मालिक से संपर्क करें।',
    'This account is not linked to a dairy. Contact the owner.',
  );

  // --- delivery ---
  String get startRound => _p('आज की सप्लाई शुरू करें', "Start today's round");
  String get resumeRound => _p('सप्लाई जारी रखें', 'Continue round');
  String get delivered => _p('दे दिया', 'Delivered');
  String get notTaken => _p('आज नहीं लिया', 'Not taken today');
  String get houseNo => _p('घर नं.', 'House no.');
  String get usualQty => _p('रोज़ का', 'Usual');
  String get roundComplete =>
      _p('आज का काम पूरा हुआ', "Today's round is complete");
  String get moneyReceived => _p('पैसे मिले', 'Money received');
  String get moneySent => _p('भेज दिया', 'Sent');
  String get amountReceived =>
      _p('कितने रुपये मिले?', 'How much was received?');

  String progress(int done, int total) => '$done/$total';

  String housesLeft(int n) =>
      _p('$n घर बाकी हैं', n == 1 ? '1 house left' : '$n houses left');

  String housesDone(int n) => _p('$n घर हो गए', '$n houses done');

  // --- sync ---
  String get allSynced => _p('सब सेव हो गया', 'All saved');
  String pendingSync(int n) => _p(
    '$n सेव होना बाकी',
    n == 1 ? '1 waiting to save' : '$n waiting to save',
  );
  String get offlineNotice => _p(
    'इंटरनेट नहीं है — काम चलता रहेगा, बाद में अपने आप सेव हो जाएगा।',
    'No internet — keep going, this saves automatically later.',
  );

  // --- owner ---
  String get tabToday => _p('आज', 'Today');
  String get tabReports => _p('रिपोर्ट', 'Reports');
  String get tabCustomers => _p('ग्राहक', 'Customers');
  String get tabMoney => _p('पैसा', 'Money');
  String get tabSettings => _p('सेटिंग', 'Settings');

  String get totalLitres => _p('कुल लीटर', 'Total litres');
  String get totalAmount => _p('कुल रकम', 'Total amount');
  String get housesServed => _p('घर सप्लाई हुए', 'Houses served');
  String get housesSkipped => _p('घर छोड़े', 'Houses skipped');
  String get housesPending => _p('बाकी घर', 'Pending houses');

  String get day => _p('दिन', 'Day');
  String get week => _p('हफ्ता', 'Week');
  String get month => _p('महीना', 'Month');
  String get year => _p('साल', 'Year');

  String get customerName => _p('ग्राहक का नाम', 'Customer name');
  String get phone => _p('फोन नंबर', 'Phone number');
  String get defaultQty => _p('रोज़ का दूध', 'Usual daily milk');
  String get routeOrder => _p('रास्ते में क्रम', 'Order on route');
  String get activeCustomer => _p('चालू है', 'Active');
  String get addCustomer => _p('नया ग्राहक जोड़ें', 'Add customer');
  String get noCustomers => _p('अभी कोई ग्राहक नहीं है', 'No customers yet');
  String get photo => _p('फोटो', 'Photo');

  String get ratePerLitre =>
      _p('दूध का भाव (₹ प्रति लीटर)', 'Rate (₹ per litre)');
  String get paid => _p('चुकाया', 'Paid');
  String get unpaid => _p('बाकी', 'Unpaid');
  String get partial => _p('कुछ चुकाया', 'Partly paid');
  String get balance => _p('बकाया', 'Balance');
  String get recordPayment => _p('भुगतान दर्ज करें', 'Record payment');
  String get pendingApprovals => _p('मंज़ूरी बाकी', 'Pending approvals');
  String get approve => _p('मंज़ूर करें', 'Approve');
  String get reject => _p('मना करें', 'Reject');
  String get sendBillWhatsapp =>
      _p('व्हाट्सएप पर बिल भेजें', 'Send bill on WhatsApp');
  String get exportCsv => _p('एक्सेल में निकालें', 'Export to CSV');
  String get language => _p('भाषा', 'Language');
  String get members => _p('सदस्य', 'Members');
  String get editEntry => _p('एंट्री बदलें', 'Edit entry');
  String get editReason => _p('बदलने की वजह', 'Reason for change');
  String get editedBadge => _p('बदला गया', 'Edited');
}

/// Provides [S] plus the setter used by the settings screen.
class _InheritedStrings extends InheritedWidget {
  const _InheritedStrings({
    required this.strings,
    required this.setLanguage,
    required super.child,
  });

  final S strings;
  final ValueChanged<AppLanguage> setLanguage;

  static _InheritedStrings of(BuildContext context) {
    final result = context
        .dependOnInheritedWidgetOfExactType<_InheritedStrings>();
    assert(result != null, 'No LanguageScope found in context');
    return result!;
  }

  @override
  bool updateShouldNotify(_InheritedStrings oldWidget) =>
      strings.lang != oldWidget.strings.lang;
}

/// Wraps the app so any widget can read [S.of] and change the language.
class LanguageScope extends StatefulWidget {
  const LanguageScope({
    super.key,
    required this.initial,
    required this.onChanged,
    required this.child,
  });

  final AppLanguage initial;
  final ValueChanged<AppLanguage> onChanged;
  final Widget child;

  static void set(BuildContext context, AppLanguage lang) =>
      _InheritedStrings.of(context).setLanguage(lang);

  static AppLanguage current(BuildContext context) =>
      _InheritedStrings.of(context).strings.lang;

  @override
  State<LanguageScope> createState() => _LanguageScopeState();
}

class _LanguageScopeState extends State<LanguageScope> {
  late AppLanguage _lang = widget.initial;

  @override
  Widget build(BuildContext context) => _InheritedStrings(
    strings: S(_lang),
    setLanguage: (lang) {
      if (lang == _lang) return;
      setState(() => _lang = lang);
      widget.onChanged(lang);
    },
    child: widget.child,
  );
}
