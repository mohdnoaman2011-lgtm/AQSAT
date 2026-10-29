import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

const teal = Color(0xFF0F766E), deep = Color(0xFF0B3D38), mute = Color(0xFF7C8F8B);
const defaultMsg = 'السلام عليكم {name}، نذكّرك بقسط {item} رقم {n} بمبلغ {amount} المستحق بتاريخ {date}. شكراً لك.';

String money(num v) => v.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => ',');
String cur(num v) => '${money(v)} ${app.currency}'.trim();
String dateStr(DateTime d) => '${d.year}/${d.month.toString().padLeft(2, '0')}/${d.day.toString().padLeft(2, '0')}';
// مقارنة الأسماء: لا فرق بين أ/إ/آ/ا، ة/ه، ى/ي، المسافات المتعددة، والتشكيل
String normName(String s) => s
    .replaceAll(RegExp(r'[\u064B-\u065F\u0670\u0640]'), '')
    .replaceAll(RegExp(r'[أإآٱ]'), 'ا')
    .replaceAll('ة', 'ه')
    .replaceAll('ى', 'ي')
    .replaceAll(RegExp(r'\s+'), ' ')
    .trim()
    .toLowerCase();
bool sameName(String a, String b) => normName(a) == normName(b);
Future<void> shareText(String text, {String? subject}) => SharePlus.instance.share(ShareParams(text: text, subject: subject));
void snack(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

// ---------- النموذج ----------
class Payment {
  Payment(this.no, this.date, this.amount);
  final int no;
  final DateTime date;
  final double amount;
  Map<String, dynamic> toJson() => {'no': no, 'date': date.toIso8601String(), 'amount': amount};
  factory Payment.fromJson(Map<String, dynamic> j) => Payment(j['no'] as int, DateTime.parse(j['date'] as String), (j['amount'] as num).toDouble());
}

class Contract {
  Contract({required this.customer, required this.phone, required this.item, required this.price, required this.down,
      required this.profit, required this.months, required this.firstDate, List<Payment>? payments}) : payments = payments ?? [];
  final String customer, phone, item;
  final double price, down, profit;
  final int months;
  final DateTime firstDate;
  final List<Payment> payments;
  int get paid => payments.length;
  double get monthly => (price - down) * (1 + profit / 100) / months;
  double get remaining => monthly * (months - paid);
  double get collected => down + monthly * paid;
  DateTime dueOf(int i) => DateTime(firstDate.year, firstDate.month + i, firstDate.day);
  bool get done => paid >= months;
  bool get late => !done && dueOf(paid).isBefore(DateTime.now());
  String get status => done ? 'مكتمل' : (late ? 'متأخر' : 'نشط');
  Map<String, dynamic> toJson() => {
        'customer': customer, 'phone': phone, 'item': item, 'price': price, 'down': down, 'profit': profit,
        'months': months, 'firstDate': firstDate.toIso8601String(), 'payments': payments.map((p) => p.toJson()).toList(),
      };
  factory Contract.fromJson(Map<String, dynamic> j) => Contract(
        customer: j['customer'] as String, phone: (j['phone'] ?? '') as String, item: j['item'] as String,
        price: (j['price'] as num).toDouble(), down: (j['down'] as num).toDouble(), profit: (j['profit'] as num).toDouble(),
        months: j['months'] as int, firstDate: DateTime.parse(j['firstDate'] as String),
        payments: (j['payments'] as List).map((e) => Payment.fromJson(e as Map<String, dynamic>)).toList(),
      );
}

// ---------- الحالة والتخزين المحلي ----------
class AppState extends ChangeNotifier {
  late SharedPreferences sp;
  List<Contract> contracts = [];
  int receiptNo = 0;
  bool dark = false, alertLate = true;
  String store = '', phone = '', currency = '', msg = defaultMsg;

  Future<void> load() async {
    sp = await SharedPreferences.getInstance();
    final raw = sp.getString('data');
    if (raw != null) _apply(jsonDecode(raw) as Map<String, dynamic>);
  }

  void _apply(Map<String, dynamic> j) {
    contracts = (j['contracts'] as List).map((e) => Contract.fromJson(e as Map<String, dynamic>)).toList();
    receiptNo = (j['receiptNo'] ?? 0) as int;
    dark = (j['dark'] ?? false) as bool;
    alertLate = (j['alertLate'] ?? true) as bool;
    store = (j['store'] ?? '') as String;
    phone = (j['phone'] ?? '') as String;
    currency = (j['currency'] ?? '') as String;
    msg = (j['msg'] ?? defaultMsg) as String;
  }

  String export() => jsonEncode({
        'contracts': contracts.map((c) => c.toJson()).toList(), 'receiptNo': receiptNo, 'dark': dark,
        'alertLate': alertLate, 'store': store, 'phone': phone, 'currency': currency, 'msg': msg,
      });

  bool restore(String s) {
    try { _apply(jsonDecode(s) as Map<String, dynamic>); save(); return true; } catch (_) { return false; }
  }

  void save() { sp.setString('data', export()); notifyListeners(); }
  Contract? customerOf(String n) {
    if (normName(n).isEmpty) return null;
    for (final c in contracts) { if (sameName(c.customer, n)) return c; }
    return null;
  }
  double get remaining => contracts.fold(0.0, (s, c) => s + c.remaining);
  double get collected => contracts.fold(0.0, (s, c) => s + c.collected);
  void add(Contract c) { contracts.insert(0, c); save(); }
  void remove(Contract c) { contracts.remove(c); save(); }
  Payment pay(Contract c) {
    final p = Payment(++receiptNo, DateTime.now(), c.monthly);
    c.payments.add(p);
    save();
    return p;
  }
}

final app = AppState();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  await app.load();
  runApp(const InstallmentsApp());
}

ThemeData mk(Brightness b) {
  final d = b == Brightness.dark;
  final shape = RoundedRectangleBorder(borderRadius: BorderRadius.circular(20));
  OutlineInputBorder ob(Color c, double w) => OutlineInputBorder(borderRadius: BorderRadius.circular(18), borderSide: BorderSide(color: c, width: w));
  return ThemeData(
    colorScheme: ColorScheme.fromSeed(seedColor: teal, brightness: b),
    scaffoldBackgroundColor: d ? const Color(0xFF0E1D1B) : const Color(0xFFF1F5F4),
    textTheme: GoogleFonts.tajawalTextTheme(ThemeData(brightness: b).textTheme),
    appBarTheme: const AppBarTheme(backgroundColor: Colors.transparent, scrolledUnderElevation: 0, centerTitle: false),
    filledButtonTheme: FilledButtonThemeData(style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56), shape: shape, textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800))),
    outlinedButtonTheme: OutlinedButtonThemeData(style: OutlinedButton.styleFrom(minimumSize: const Size(0, 52), shape: shape, textStyle: const TextStyle(fontWeight: FontWeight.w700))),
    inputDecorationTheme: InputDecorationTheme(filled: true, fillColor: d ? const Color(0xFF16302C) : Colors.white, border: ob(Colors.transparent, 0), enabledBorder: ob(Colors.transparent, 0), focusedBorder: ob(teal, 2)),
    navigationBarTheme: NavigationBarThemeData(
      height: 72,
      backgroundColor: d ? const Color(0xFF12262B) : Colors.white,
      indicatorColor: d ? const Color(0xFF1F4A44) : const Color(0xFFD5ECE7),
      labelTextStyle: const WidgetStatePropertyAll(TextStyle(fontSize: 12, fontWeight: FontWeight.w700)),
    ),
    floatingActionButtonTheme: FloatingActionButtonThemeData(backgroundColor: teal, foregroundColor: Colors.white, shape: shape),
    useMaterial3: true,
  );
}

class InstallmentsApp extends StatelessWidget {
  const InstallmentsApp({super.key});
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => MaterialApp(
          title: 'البيع بالأقساط',
          debugShowCheckedModeBanner: false,
          locale: const Locale('ar'),
          supportedLocales: const [Locale('ar')],
          localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
          theme: mk(Brightness.light),
          darkTheme: mk(Brightness.dark),
          themeMode: app.dark ? ThemeMode.dark : ThemeMode.light,
          home: const SplashPage(),
        ),
      );
}

// ---------- مكونات التصميم ----------
void open(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));

Widget box(Widget child, {Color? color, EdgeInsets pad = const EdgeInsets.all(16)}) => Builder(builder: (c) {
      final d = Theme.of(c).brightness == Brightness.dark;
      return Container(
        padding: pad,
        decoration: BoxDecoration(
          color: color ?? (d ? const Color(0xFF16302C) : Colors.white),
          borderRadius: BorderRadius.circular(24),
          boxShadow: d ? null : const [BoxShadow(color: Color(0x0F0B3D38), blurRadius: 18, offset: Offset(0, 6))],
        ),
        child: child,
      );
    });

Widget title(String t, {Widget? action}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [Text(t, style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)), if (action != null) action],
    );

Widget section(String t, {Widget? action}) => Padding(
      padding: const EdgeInsets.only(top: 22, bottom: 10),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(t, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800)), if (action != null) action]),
    );

Widget ibox(IconData i, Color c) => Container(
      width: 42, height: 42,
      decoration: BoxDecoration(color: c.withAlpha(30), borderRadius: BorderRadius.circular(14)),
      child: Icon(i, color: c, size: 22),
    );

Widget empty(IconData i, String t) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(children: [Icon(i, size: 56, color: mute), const SizedBox(height: 10), Text(t, style: const TextStyle(color: mute))]),
    );

class Reveal extends StatelessWidget {
  const Reveal(this.i, this.child, {super.key});
  final int i;
  final Widget child;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: Duration(milliseconds: 350 + (i > 6 ? 6 : i) * 70),
        curve: Curves.easeOutCubic,
        builder: (_, v, c) => Opacity(opacity: v, child: Transform.translate(offset: Offset(0, (1 - v) * 18), child: c)),
        child: child,
      );
}

class Counter extends StatelessWidget {
  const Counter(this.v, {super.key, this.style});
  final double v;
  final TextStyle? style;
  @override
  Widget build(BuildContext context) => TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: v),
        duration: const Duration(milliseconds: 800),
        curve: Curves.easeOutCubic,
        builder: (_, x, __) => Text(cur(x), style: style),
      );
}

class RingAvatar extends StatelessWidget {
  const RingAvatar(this.t, this.v, {super.key, this.size = 52});
  final String t;
  final double v, size;
  @override
  Widget build(BuildContext context) => SizedBox(
        width: size, height: size,
        child: Stack(alignment: Alignment.center, children: [
          TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: v),
            duration: const Duration(milliseconds: 700),
            curve: Curves.easeOutCubic,
            builder: (_, x, __) => SizedBox.expand(child: CircularProgressIndicator(value: x, strokeWidth: 3.5, strokeCap: StrokeCap.round, color: teal, backgroundColor: const Color(0x330F766E))),
          ),
          CircleAvatar(radius: size / 2 - 6, backgroundColor: const Color(0xFFD5ECE7), child: Text(t, style: TextStyle(fontWeight: FontWeight.w800, color: deep, fontSize: size / 3))),
        ]),
      );
}

class StatusChip extends StatelessWidget {
  const StatusChip(this.s, {super.key});
  final String s;
  @override
  Widget build(BuildContext context) {
    final late = s == 'متأخر', done = s == 'مكتمل' || s == 'مدفوع';
    final bgc = late ? const Color(0xFFFDECDD) : done ? const Color(0xFFE3F3EF) : const Color(0xFFE8EEF9);
    final fg = late ? const Color(0xFF8A3B05) : done ? const Color(0xFF0B5A50) : const Color(0xFF1F3F7A);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(color: bgc, borderRadius: BorderRadius.circular(99)),
      child: Text(s, style: TextStyle(fontSize: 11, fontWeight: FontWeight.w800, color: fg)),
    );
  }
}

class ContractTile extends StatelessWidget {
  const ContractTile(this.c, {super.key, this.i = 0});
  final Contract c;
  final int i;
  @override
  Widget build(BuildContext context) => Reveal(
        i,
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(24),
            onTap: () => open(context, DetailsPage(c)),
            child: box(Row(children: [
              RingAvatar(c.customer[0], c.paid / c.months),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(c.customer, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                Text('${c.item} · قسط ${c.done ? c.months : c.paid + 1} من ${c.months}', style: const TextStyle(fontSize: 12, color: mute)),
              ])),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Text(money(c.monthly), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                const SizedBox(height: 4),
                StatusChip(c.status),
              ]),
            ])),
          ),
        ),
      );
}

Widget field(String label, TextEditingController ctl, {String? suffix, bool num = true, IconData? icon, ValueChanged<String>? onChanged}) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: ctl,
        onChanged: onChanged,
        keyboardType: num ? TextInputType.number : TextInputType.text,
        decoration: InputDecoration(labelText: label, suffixText: suffix, prefixIcon: icon == null ? null : Icon(icon, color: mute)),
      ),
    );

Future<String?> askText(BuildContext ctx, String t, String init, {int lines = 1}) {
  final ctl = TextEditingController(text: init);
  return showDialog<String>(
    context: ctx,
    builder: (d) => AlertDialog(
      title: Text(t),
      content: TextField(controller: ctl, maxLines: lines, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(d, ctl.text.trim()), child: const Text('حفظ')),
      ],
    ),
  );
}

Future<bool> confirm(BuildContext ctx, String t, String body) async =>
    await showDialog<bool>(
      context: ctx,
      builder: (d) => AlertDialog(title: Text(t), content: Text(body), actions: [
        TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
        TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد')),
      ]),
    ) ??
    false;

const heroGrad = BoxDecoration(
  gradient: LinearGradient(begin: Alignment.topRight, end: Alignment.bottomLeft, colors: [Color(0xFF0B3D38), Color(0xFF0F766E)]),
  borderRadius: BorderRadius.all(Radius.circular(28)),
);

Widget heroCard(Widget child) => Container(
      decoration: heroGrad,
      clipBehavior: Clip.antiAlias,
      child: Stack(children: [
        Positioned(left: -40, top: -40, child: Container(width: 140, height: 140, decoration: const BoxDecoration(color: Color(0x14FFFFFF), shape: BoxShape.circle))),
        Positioned(right: -30, bottom: -50, child: Container(width: 120, height: 120, decoration: const BoxDecoration(color: Color(0x0FFFFFFF), shape: BoxShape.circle))),
        Padding(padding: const EdgeInsets.all(22), child: child),
      ]),
    );

// ---------- واتساب وPDF ----------
String reminderText(Contract c) {
  final i = c.done ? c.months - 1 : c.paid;
  return app.msg
      .replaceAll('{name}', c.customer)
      .replaceAll('{item}', c.item)
      .replaceAll('{n}', '${i + 1}')
      .replaceAll('{amount}', cur(c.monthly))
      .replaceAll('{date}', dateStr(c.dueOf(i)));
}

Future<void> whatsapp(BuildContext ctx, String phone, String text) async {
  final p = phone.replaceAll(RegExp(r'[^0-9]'), '');
  if (p.isEmpty) { snack(ctx, 'أضف رقم هاتف العميل أولاً (بصيغة دولية)'); return; }
  try {
    final ok = await launchUrl(Uri.parse('https://wa.me/$p?text=${Uri.encodeComponent(text)}'), mode: LaunchMode.externalApplication);
    if (!ok && ctx.mounted) snack(ctx, 'تعذر فتح واتساب');
  } catch (_) {
    if (ctx.mounted) snack(ctx, 'تعذر فتح واتساب');
  }
}

Future<void> printDoc(BuildContext ctx, String name, List<pw.Widget> children, {PdfPageFormat fmt = PdfPageFormat.a4}) async {
  try {
    final regular = await PdfGoogleFonts.tajawalRegular();
    final bold = await PdfGoogleFonts.tajawalBold();
    final doc = pw.Document(theme: pw.ThemeData.withFont(base: regular, bold: bold));
    doc.addPage(pw.MultiPage(pageFormat: fmt, textDirection: pw.TextDirection.rtl, margin: const pw.EdgeInsets.all(32), build: (_) => children));
    await Printing.layoutPdf(name: name, onLayout: (_) async => doc.save());
  } catch (_) {
    if (ctx.mounted) snack(ctx, 'تعذر إنشاء الملف، تأكد من الاتصال بالإنترنت (لتحميل الخط)');
  }
}

pw.Widget pRow(String a, String b) => pw.Container(
      padding: const pw.EdgeInsets.symmetric(vertical: 8),
      decoration: pw.BoxDecoration(border: pw.Border(bottom: pw.BorderSide(color: PdfColors.grey400))),
      child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(a, style: pw.TextStyle(color: PdfColors.grey700)), pw.Text(b)]),
    );

pw.Widget pHead(String t) => pw.Column(children: [
      if (app.store.isNotEmpty) pw.Text(app.store, style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold)),
      if (app.phone.isNotEmpty) pw.Text(app.phone),
      pw.SizedBox(height: 10),
      pw.Text(t, style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
      pw.SizedBox(height: 14),
    ]);

Future<void> printContract(BuildContext ctx, Contract c) => printDoc(ctx, 'عقد-${c.customer}', [
      pHead('عقد بيع بالأقساط'),
      pRow('العميل', c.customer), pRow('الهاتف', c.phone), pRow('السلعة', c.item),
      pRow('السعر', cur(c.price)), pRow('الدفعة الأولى', cur(c.down)), pRow('نسبة الربح', '${c.profit}%'),
      pRow('عدد الأقساط', '${c.months}'), pRow('القسط الشهري', cur(c.monthly)),
      pw.SizedBox(height: 16),
      pw.Table(border: pw.TableBorder.all(color: PdfColors.grey400), children: [
        pw.TableRow(decoration: pw.BoxDecoration(color: PdfColors.grey200), children: [
          for (final h in ['القسط', 'الاستحقاق', 'المبلغ', 'الحالة']) pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(h, style: pw.TextStyle(fontWeight: pw.FontWeight.bold))),
        ]),
        for (var i = 0; i < c.months; i++)
          pw.TableRow(children: [
            for (final t in ['${i + 1}', dateStr(c.dueOf(i)), money(c.monthly), i < c.paid ? 'مدفوع' : 'قادم']) pw.Padding(padding: const pw.EdgeInsets.all(6), child: pw.Text(t)),
          ]),
      ]),
      pw.SizedBox(height: 40),
      pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text('توقيع العميل: ................'), pw.Text('توقيع البائع: ................')]),
    ]);

// ---------- شاشة البداية ----------
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
        body: Container(
          decoration: heroGrad.copyWith(borderRadius: BorderRadius.zero),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(28),
              child: Column(children: [
                const Spacer(),
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0.6, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.elasticOut,
                  builder: (_, v, c) => Transform.scale(scale: v, child: c),
                  child: Container(
                    width: 104, height: 104,
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(32)),
                    child: const Icon(Icons.event_available_rounded, size: 54, color: teal),
                  ),
                ),
                const SizedBox(height: 28),
                const Reveal(2, Text('البيع بالأقساط', style: TextStyle(fontSize: 36, fontWeight: FontWeight.w800, color: Colors.white))),
                const SizedBox(height: 10),
                const Reveal(4, Text('أدر عقودك وأقساطك وعملاءك في مكان واحد', textAlign: TextAlign.center, style: TextStyle(fontSize: 16, color: Color(0xFFCFE9E4)))),
                const Spacer(),
                FilledButton(
                  style: FilledButton.styleFrom(backgroundColor: Colors.white, foregroundColor: deep),
                  onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const Shell())),
                  child: const Text('ابدأ الآن'),
                ),
              ]),
            ),
          ),
        ),
      );
}

// ---------- الهيكل ----------
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellState();
}

class _ShellState extends State<Shell> {
  int i = 0;
  void go(int n) { HapticFeedback.selectionClick(); setState(() => i = n); }
  @override
  Widget build(BuildContext context) {
    final pages = [DashboardPage(go: go), const ContractsPage(), const CustomersPage(), const CalcPage(), const SettingsPage()];
    return Scaffold(
      body: SafeArea(
        child: ListenableBuilder(
          listenable: app,
          builder: (_, __) => AnimatedSwitcher(duration: const Duration(milliseconds: 250), child: KeyedSubtree(key: ValueKey(i), child: pages[i])),
        ),
      ),
      floatingActionButton: i <= 2 ? FloatingActionButton.extended(onPressed: () => open(context, const NewContractPage()), icon: const Icon(Icons.add_rounded), label: const Text('عقد جديد')) : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: i,
        onDestinationSelected: go,
        destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home_rounded), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description_rounded), label: 'العقود'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people_rounded), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.calculate_outlined), selectedIcon: Icon(Icons.calculate_rounded), label: 'الحاسبة'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings_rounded), label: 'الإعدادات'),
        ],
      ),
    );
  }
}

// ---------- الرئيسية ----------
class DashboardPage extends StatelessWidget {
  const DashboardPage({super.key, required this.go});
  final ValueChanged<int> go;

  Widget quick(IconData i, String t, VoidCallback on) => Expanded(
        child: InkWell(
          borderRadius: BorderRadius.circular(24),
          onTap: on,
          child: box(Column(children: [Icon(i, color: teal), const SizedBox(height: 6), Text(t, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w700))]), pad: const EdgeInsets.symmetric(vertical: 14)),
        ),
      );

  Widget stat(IconData i, Color c, String t, String v) => Expanded(
        child: box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          ibox(i, c), const SizedBox(height: 10),
          Text(v, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
          Text(t, style: const TextStyle(fontSize: 12, color: mute)),
        ]), pad: const EdgeInsets.all(14)),
      );

  @override
  Widget build(BuildContext context) {
    final total = app.remaining + app.collected;
    final ratio = total == 0 ? 0.0 : app.collected / total;
    final upcoming = app.contracts.where((c) => !c.done).toList()..sort((a, b) => a.dueOf(a.paid).compareTo(b.dueOf(b.paid)));
    final lateCount = app.contracts.where((c) => c.late).length;
    final name = app.store.isEmpty ? 'البيع بالأقساط' : app.store;
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      Row(children: [
        CircleAvatar(radius: 24, backgroundColor: const Color(0xFFD5ECE7), child: Text(name[0], style: const TextStyle(fontWeight: FontWeight.w800, color: deep, fontSize: 18))),
        const SizedBox(width: 12),
        Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('مرحباً بك', style: TextStyle(fontSize: 13, color: mute)),
          Text(name, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        ])),
        IconButton.filledTonal(onPressed: () => go(4), icon: const Icon(Icons.settings_rounded)),
      ]),
      const SizedBox(height: 18),
      Reveal(0, heroCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('المتبقي للتحصيل', style: TextStyle(color: Color(0xFFCFE9E4))),
        const SizedBox(height: 4),
        Counter(app.remaining, style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800)),
        const SizedBox(height: 14),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: ratio),
          duration: const Duration(milliseconds: 800),
          curve: Curves.easeOutCubic,
          builder: (_, v, __) => LinearProgressIndicator(value: v, minHeight: 8, borderRadius: BorderRadius.circular(9), backgroundColor: const Color(0x33FFFFFF), color: const Color(0xFF7FD6C8)),
        ),
        const SizedBox(height: 10),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          Text('تم تحصيل ${cur(app.collected)}', style: const TextStyle(color: Color(0xFFCFE9E4), fontSize: 13)),
          Text('${(ratio * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ]))),
      const SizedBox(height: 14),
      Row(children: [
        quick(Icons.add_circle_outline_rounded, 'عقد جديد', () => open(context, const NewContractPage())),
        const SizedBox(width: 10),
        quick(Icons.calculate_outlined, 'الحاسبة', () => go(3)),
        const SizedBox(width: 10),
        quick(Icons.people_outline_rounded, 'العملاء', () => go(2)),
      ]),
      const SizedBox(height: 14),
      Row(children: [
        stat(Icons.description_rounded, teal, 'العقود', '${app.contracts.length}'),
        const SizedBox(width: 10),
        stat(Icons.autorenew_rounded, const Color(0xFF1F3F7A), 'نشطة', '${app.contracts.where((c) => !c.done).length}'),
        const SizedBox(width: 10),
        stat(Icons.warning_amber_rounded, const Color(0xFFB45309), 'متأخرة', '$lateCount'),
      ]),
      if (app.alertLate && lateCount > 0) ...[
        const SizedBox(height: 14),
        InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: () => go(1),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(color: const Color(0xFFFDECDD), borderRadius: BorderRadius.circular(20)),
            child: Row(children: [
              const Icon(Icons.notifications_active_rounded, color: Color(0xFF8A3B05)),
              const SizedBox(width: 10),
              Expanded(child: Text('$lateCount أقساط متأخرة تحتاج متابعة', style: const TextStyle(color: Color(0xFF8A3B05), fontWeight: FontWeight.w800))),
              const Icon(Icons.chevron_left_rounded, color: Color(0xFF8A3B05)),
            ]),
          ),
        ),
      ],
      section('الأقساط القادمة', action: TextButton(onPressed: () => go(1), child: const Text('عرض الكل'))),
      if (upcoming.isEmpty) empty(Icons.inbox_rounded, 'لا توجد عقود نشطة. ابدأ بإضافة عقد جديد.'),
      for (var k = 0; k < upcoming.length && k < 4; k++) ContractTile(upcoming[k], i: k),
    ]);
  }
}

// ---------- العقود ----------
class ContractsPage extends StatefulWidget {
  const ContractsPage({super.key});
  @override
  State<ContractsPage> createState() => _ContractsPageState();
}

class _ContractsPageState extends State<ContractsPage> {
  String filter = 'الكل', q = '';
  @override
  Widget build(BuildContext context) {
    final list = app.contracts.where((c) => (filter == 'الكل' || c.status == filter) && (c.customer + c.item).contains(q)).toList();
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      title('العقود'),
      const SizedBox(height: 14),
      TextField(onChanged: (v) => setState(() => q = v), decoration: const InputDecoration(hintText: 'ابحث باسم العميل أو السلعة', prefixIcon: Icon(Icons.search_rounded))),
      const SizedBox(height: 12),
      SegmentedButton<String>(
        showSelectedIcon: false,
        segments: [for (final f in ['الكل', 'نشط', 'متأخر', 'مكتمل']) ButtonSegment(value: f, label: Text(f))],
        selected: {filter},
        onSelectionChanged: (s) => setState(() => filter = s.first),
      ),
      const SizedBox(height: 16),
      if (list.isEmpty) empty(Icons.description_outlined, 'لا توجد عقود'),
      for (var k = 0; k < list.length; k++) ContractTile(list[k], i: k),
    ]);
  }
}

// ---------- العملاء ----------
class CustomersPage extends StatelessWidget {
  const CustomersPage({super.key});
  @override
  Widget build(BuildContext context) {
    final names = <String>[];
    for (final c in app.contracts) { if (!names.any((n) => sameName(n, c.customer))) names.add(c.customer); }
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 100), children: [
      title('العملاء'),
      const SizedBox(height: 16),
      if (names.isEmpty) empty(Icons.people_outline_rounded, 'لا يوجد عملاء بعد'),
      for (var k = 0; k < names.length; k++)
        Reveal(
          k,
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: InkWell(
              borderRadius: BorderRadius.circular(24),
              onTap: () => open(context, CustomerPage(names[k])),
              child: Builder(builder: (_) {
                final cs = app.contracts.where((c) => sameName(c.customer, names[k])).toList();
                final paid = cs.fold(0, (s, c) => s + c.paid), all = cs.fold(0, (s, c) => s + c.months);
                return box(Row(children: [
                  RingAvatar(names[k][0], all == 0 ? 0 : paid / all),
                  const SizedBox(width: 14),
                  Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                    Text(names[k], style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${cs.length} عقد', style: const TextStyle(fontSize: 12, color: mute)),
                  ])),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    const Text('متبقي', style: TextStyle(fontSize: 12, color: mute)),
                    Text(money(cs.fold(0.0, (s, c) => s + c.remaining)), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                  ]),
                ]));
              }),
            ),
          ),
        ),
    ]);
  }
}

class CustomerPage extends StatelessWidget {
  const CustomerPage(this.name, {super.key});
  final String name;
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (_, __) => Scaffold(
          appBar: AppBar(title: Text(name, style: const TextStyle(fontWeight: FontWeight.w800))),
          body: ListView(padding: const EdgeInsets.all(20), children: [
            for (final c in app.contracts.where((c) => sameName(c.customer, name))) ContractTile(c),
          ]),
        ),
      );
}

// ---------- الحاسبة ----------
class CalcPage extends StatefulWidget {
  const CalcPage({super.key});
  @override
  State<CalcPage> createState() => _CalcPageState();
}

class _CalcPageState extends State<CalcPage> {
  final price = TextEditingController(text: '12000'), down = TextEditingController(text: '2000');
  final profit = TextEditingController(text: '15'), months = TextEditingController(text: '10');
  double n(TextEditingController c) => double.tryParse(c.text) ?? 0;
  void up(String _) => setState(() {});
  @override
  Widget build(BuildContext context) {
    final m = n(months) < 1 ? 1 : n(months);
    final total = (n(price) - n(down)) * (1 + n(profit) / 100);
    return ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
      title('حاسبة الأقساط'),
      const SizedBox(height: 16),
      heroCard(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        const Text('القسط الشهري', style: TextStyle(color: Color(0xFFCFE9E4))),
        Text(money(total / m), style: const TextStyle(color: Colors.white, fontSize: 40, fontWeight: FontWeight.w800)),
        const Divider(color: Color(0x33FFFFFF), height: 24),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('الإجمالي بعد الربح', style: TextStyle(color: Color(0xFFCFE9E4))),
          Text(money(total), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
        const SizedBox(height: 6),
        Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
          const Text('إجمالي الربح', style: TextStyle(color: Color(0xFFCFE9E4))),
          Text(money((n(price) - n(down)) * n(profit) / 100), style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
        ]),
      ])),
      const SizedBox(height: 20),
      field('سعر السلعة', price, icon: Icons.sell_outlined, onChanged: up),
      field('الدفعة الأولى', down, icon: Icons.payments_outlined, onChanged: up),
      Row(children: [
        Expanded(child: field('نسبة الربح', profit, suffix: '%', onChanged: up)),
        const SizedBox(width: 10),
        Expanded(child: field('المدة', months, suffix: 'شهر', onChanged: up)),
      ]),
      const SizedBox(height: 6),
      FilledButton(
        onPressed: () => open(context, NewContractPage(price: price.text, down: down.text, profit: profit.text, months: months.text)),
        child: const Text('إنشاء عقد بهذه القيم'),
      ),
    ]);
  }
}

// ---------- عقد جديد ----------
class NewContractPage extends StatefulWidget {
  const NewContractPage({super.key, this.price = '', this.down = '0', this.profit = '15', this.months = '10'});
  final String price, down, profit, months;
  @override
  State<NewContractPage> createState() => _NewContractPageState();
}

class _NewContractPageState extends State<NewContractPage> {
  final name = TextEditingController(), phone = TextEditingController(), item = TextEditingController();
  late final price = TextEditingController(text: widget.price), down = TextEditingController(text: widget.down);
  late final profit = TextEditingController(text: widget.profit), months = TextEditingController(text: widget.months);
  DateTime? first;
  Contract? existing;

  Future<void> pick() async {
    final d = await showDatePicker(context: context, initialDate: first ?? DateTime.now(), firstDate: DateTime(2020), lastDate: DateTime(2100));
    if (d != null) setState(() => first = d);
  }

  void save() {
    final p = double.tryParse(price.text), m = int.tryParse(months.text);
    if (name.text.trim().isEmpty || item.text.trim().isEmpty || p == null || m == null || m < 1) {
      snack(context, 'أكمل الحقول المطلوبة (الاسم، السلعة، السعر، المدة)');
      return;
    }
    final ex = app.customerOf(name.text);
    final c = Contract(customer: ex?.customer ?? name.text.trim(), phone: phone.text.trim().isEmpty ? (ex?.phone ?? '') : phone.text.trim(), item: item.text.trim(), price: p, down: double.tryParse(down.text) ?? 0,
        profit: double.tryParse(profit.text) ?? 0, months: m, firstDate: first ?? DateTime.now());
    app.add(c);
    HapticFeedback.mediumImpact();
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => DetailsPage(c)));
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('عقد جديد', style: TextStyle(fontWeight: FontWeight.w800))),
        body: ListView(padding: const EdgeInsets.all(20), children: [
          field('اسم العميل', name, num: false, icon: Icons.person_outline_rounded, onChanged: (v) {
            final old = app.contracts.where((c) => sameName(c.customer, v) && c.phone.isNotEmpty);
            if (old.isNotEmpty && phone.text.isEmpty) phone.text = old.first.phone;
            setState(() => existing = app.customerOf(v));
          }),
          if (existing != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(16),
                onTap: () => open(context, CustomerPage(existing!.customer)),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(color: const Color(0xFFFDECDD), borderRadius: BorderRadius.circular(16)),
                  child: Row(children: [
                    const Icon(Icons.info_outline_rounded, color: Color(0xFF8A3B05)),
                    const SizedBox(width: 10),
                    Expanded(child: Text('هذا العميل موجود مسبقاً (${existing!.customer}). سيُضاف العقد الجديد إلى نفس العميل.', style: const TextStyle(color: Color(0xFF8A3B05), fontWeight: FontWeight.w700, fontSize: 13))),
                  ]),
                ),
              ),
            ),
          field('رقم الهاتف (بصيغة دولية بدون +)', phone, icon: Icons.phone_outlined),
          field('السلعة', item, num: false, icon: Icons.inventory_2_outlined),
          Row(children: [Expanded(child: field('السعر', price)), const SizedBox(width: 10), Expanded(child: field('الدفعة الأولى', down))]),
          Row(children: [Expanded(child: field('نسبة الربح', profit, suffix: '%')), const SizedBox(width: 10), Expanded(child: field('المدة', months, suffix: 'شهر'))]),
          OutlinedButton.icon(
            onPressed: pick,
            icon: const Icon(Icons.calendar_month_rounded),
            label: Text(first == null ? 'اختيار تاريخ أول قسط' : 'أول قسط: ${dateStr(first!)}'),
          ),
          const SizedBox(height: 24),
          FilledButton(onPressed: save, child: const Text('حفظ العقد')),
        ]),
      );
}

// ---------- تفاصيل العقد ----------
class DetailsPage extends StatelessWidget {
  const DetailsPage(this.c, {super.key});
  final Contract c;

  Widget mini(String t, String v) => Expanded(
        child: Column(children: [
          Text(v, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 15)),
          Text(t, style: const TextStyle(color: Color(0xFFCFE9E4), fontSize: 12)),
        ]),
      );

  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: app,
        builder: (context, _) => Scaffold(
          appBar: AppBar(title: const Text('تفاصيل العقد', style: TextStyle(fontWeight: FontWeight.w800)), actions: [
            IconButton(
              icon: const Icon(Icons.delete_outline_rounded),
              tooltip: 'حذف العقد',
              onPressed: () async {
                if (await confirm(context, 'حذف العقد؟', 'سيتم حذف العقد وكل دفعاته نهائياً.') && context.mounted) {
                  app.remove(c);
                  Navigator.pop(context);
                }
              },
            ),
          ]),
          body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
            heroCard(Column(children: [
              Row(children: [
                SizedBox(
                  width: 84, height: 84,
                  child: Stack(alignment: Alignment.center, children: [
                    SizedBox.expand(child: CircularProgressIndicator(value: c.paid / c.months, strokeWidth: 7, strokeCap: StrokeCap.round, color: const Color(0xFF7FD6C8), backgroundColor: const Color(0x33FFFFFF))),
                    Text('${(c.paid / c.months * 100).round()}%', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 18)),
                  ]),
                ),
                const SizedBox(width: 18),
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text(c.customer, style: const TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                  Text(c.item, style: const TextStyle(color: Color(0xFFCFE9E4))),
                  if (c.phone.isNotEmpty) Text(c.phone, style: const TextStyle(color: Color(0xFFCFE9E4), fontSize: 13)),
                ])),
              ]),
              const Divider(color: Color(0x33FFFFFF), height: 28),
              Row(children: [mini('مدفوع', money(c.collected)), mini('متبقي', money(c.remaining)), mini('القسط', money(c.monthly))]),
            ])),
            section('جدول الأقساط'),
            for (var i = 0; i < c.months; i++) _step(context, i),
            const SizedBox(height: 16),
            if (!c.done)
              FilledButton.icon(
                icon: const Icon(Icons.payments_rounded),
                onPressed: () async {
                  if (!await confirm(context, 'تسجيل دفعة', 'تسجيل استلام ${cur(c.monthly)} للقسط ${c.paid + 1}؟') || !context.mounted) return;
                  HapticFeedback.mediumImpact();
                  final p = app.pay(c);
                  open(context, ReceiptPage(c, p));
                },
                label: const Text('تسجيل دفعة'),
              ),
            const SizedBox(height: 12),
            Row(children: [
              Expanded(child: OutlinedButton.icon(onPressed: () => whatsapp(context, c.phone, reminderText(c)), icon: const Icon(Icons.chat_rounded), label: const Text('تذكير واتساب'))),
              const SizedBox(width: 10),
              Expanded(child: OutlinedButton.icon(onPressed: () => printContract(context, c), icon: const Icon(Icons.print_rounded), label: const Text('طباعة العقد'))),
            ]),
          ]),
        ),
      );

  Widget _step(BuildContext context, int i) {
    final paid = i < c.paid, late = i == c.paid && c.late;
    final col = paid ? teal : (late ? const Color(0xFFB45309) : mute);
    return IntrinsicHeight(
      child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Column(children: [
          Container(
            width: 34, height: 34,
            decoration: BoxDecoration(color: col.withAlpha(32), shape: BoxShape.circle),
            child: Icon(paid ? Icons.check_rounded : (late ? Icons.priority_high_rounded : Icons.schedule_rounded), color: col, size: 20),
          ),
          if (i < c.months - 1) Expanded(child: Container(width: 2, color: col.withAlpha(60))),
        ]),
        const SizedBox(width: 12),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: paid ? () => open(context, ReceiptPage(c, c.payments[i])) : null,
              child: box(Row(children: [
                Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Text('القسط ${i + 1}', style: const TextStyle(fontWeight: FontWeight.w800)),
                  Text('الاستحقاق: ${dateStr(c.dueOf(i))}', style: const TextStyle(fontSize: 12, color: mute)),
                ])),
                StatusChip(paid ? 'مدفوع' : (late ? 'متأخر' : 'قادم')),
              ]), pad: const EdgeInsets.all(12)),
            ),
          ),
        ),
      ]),
    );
  }
}

// ---------- إيصال الدفع ----------
class ReceiptPage extends StatelessWidget {
  const ReceiptPage(this.c, this.p, {super.key});
  final Contract c;
  final Payment p;

  Widget row(String a, String b) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 9),
        child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(a, style: const TextStyle(color: mute)), Text(b, style: const TextStyle(fontWeight: FontWeight.w800))]),
      );

  @override
  Widget build(BuildContext context) {
    final n = c.payments.indexOf(p) + 1;
    final left = c.monthly * (c.months - n);
    final no = p.no.toString().padLeft(4, '0');
    final rows = [['العميل', c.customer], ['السلعة', '${c.item} · القسط $n'], ['تاريخ الدفع', dateStr(p.date)], ['المتبقي بعد الدفعة', cur(left)], ['رقم الإيصال', no]];
    return Scaffold(
      appBar: AppBar(title: const Text('إيصال الدفع', style: TextStyle(fontWeight: FontWeight.w800))),
      body: ListView(padding: const EdgeInsets.fromLTRB(20, 4, 20, 40), children: [
        Reveal(0, Column(children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 26),
            decoration: heroGrad.copyWith(borderRadius: const BorderRadius.vertical(top: Radius.circular(28))),
            child: Column(children: [
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: 1),
                duration: const Duration(milliseconds: 600),
                curve: Curves.elasticOut,
                builder: (_, v, ch) => Transform.scale(scale: v, child: ch),
                child: const CircleAvatar(radius: 30, backgroundColor: Colors.white, child: Icon(Icons.check_rounded, color: teal, size: 34)),
              ),
              const SizedBox(height: 12),
              const Text('تم استلام الدفعة', style: TextStyle(color: Color(0xFFCFE9E4), fontWeight: FontWeight.w700)),
              Text(cur(p.amount), style: const TextStyle(color: Colors.white, fontSize: 34, fontWeight: FontWeight.w800)),
            ]),
          ),
          Builder(builder: (ctx) {
            final d = Theme.of(ctx).brightness == Brightness.dark;
            return Container(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
              decoration: BoxDecoration(color: d ? const Color(0xFF16302C) : Colors.white, borderRadius: const BorderRadius.vertical(bottom: Radius.circular(28))),
              child: Column(children: [
                Row(children: List.generate(26, (_) => Expanded(child: Container(height: 1.5, margin: const EdgeInsets.symmetric(horizontal: 2), color: mute.withAlpha(90))))),
                const SizedBox(height: 8),
                for (final r in rows) row(r[0], r[1]),
              ]),
            );
          }),
        ])),
        const SizedBox(height: 20),
        Row(children: [
          Expanded(child: OutlinedButton.icon(
            onPressed: () => shareText('${app.store.isEmpty ? '' : '${app.store}\n'}إيصال رقم $no\nالعميل: ${c.customer}\nالسلعة: ${c.item} (القسط $n)\nالمبلغ: ${cur(p.amount)}\nالتاريخ: ${dateStr(p.date)}\nالمتبقي: ${cur(left)}'),
            icon: const Icon(Icons.ios_share_rounded), label: const Text('مشاركة'),
          )),
          const SizedBox(width: 10),
          Expanded(child: OutlinedButton.icon(
            onPressed: () => printDoc(context, 'إيصال-$no', [
              pHead('إيصال استلام دفعة'), pRow('رقم الإيصال', no), for (final r in rows.take(4)) pRow(r[0], r[1]), pRow('المبلغ المستلم', cur(p.amount)),
            ], fmt: PdfPageFormat.a5),
            icon: const Icon(Icons.print_rounded), label: const Text('طباعة PDF'),
          )),
        ]),
        const SizedBox(height: 12),
        FilledButton(onPressed: () => Navigator.popUntil(context, (r) => r.isFirst), child: const Text('تم')),
      ]),
    );
  }
}

// ---------- الإعدادات ----------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  Widget tile(IconData i, String t, String v, VoidCallback on) => ListTile(
        leading: ibox(i, teal),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        subtitle: v.isEmpty ? null : Text(v, maxLines: 1, overflow: TextOverflow.ellipsis),
        trailing: const Icon(Icons.chevron_left_rounded),
        onTap: on,
      );

  Widget sw(IconData i, String t, bool v, ValueChanged<bool> on) => SwitchListTile(
        secondary: ibox(i, teal),
        title: Text(t, style: const TextStyle(fontWeight: FontWeight.w700)),
        value: v,
        onChanged: on,
      );

  @override
  Widget build(BuildContext context) => ListView(padding: const EdgeInsets.fromLTRB(20, 16, 20, 40), children: [
        title('الإعدادات'),
        section('المتجر'),
        box(Column(children: [
          tile(Icons.storefront_rounded, 'اسم المتجر', app.store, () async { final v = await askText(context, 'اسم المتجر', app.store); if (v != null) { app.store = v; app.save(); } }),
          tile(Icons.phone_rounded, 'رقم هاتف المتجر', app.phone, () async { final v = await askText(context, 'رقم الهاتف', app.phone); if (v != null) { app.phone = v; app.save(); } }),
          tile(Icons.attach_money_rounded, 'العملة', app.currency, () async { final v = await askText(context, 'العملة (مثال: ج.س)', app.currency); if (v != null) { app.currency = v; app.save(); } }),
        ]), pad: EdgeInsets.zero),
        section('التذكيرات والمظهر'),
        box(Column(children: [
          tile(Icons.chat_rounded, 'نص رسالة التذكير', app.msg, () async {
            final v = await askText(context, 'المتغيرات: {name} {item} {n} {amount} {date}', app.msg, lines: 4);
            if (v != null && v.isNotEmpty) { app.msg = v; app.save(); }
          }),
          sw(Icons.notifications_active_rounded, 'تنبيه الأقساط المتأخرة', app.alertLate, (v) { app.alertLate = v; app.save(); }),
          sw(Icons.dark_mode_rounded, 'الوضع الداكن', app.dark, (v) { app.dark = v; app.save(); }),
        ]), pad: EdgeInsets.zero),
        section('البيانات'),
        box(Column(children: [
          tile(Icons.cloud_upload_outlined, 'نسخ احتياطي', 'مشاركة نسخة من بياناتك', () => shareText(app.export(), subject: 'نسخة احتياطية')),
          tile(Icons.settings_backup_restore_rounded, 'استعادة نسخة', 'الصق النسخة الاحتياطية', () async {
            final v = await askText(context, 'الصق النسخة هنا', '', lines: 5);
            if (v == null || v.isEmpty || !context.mounted) return;
            snack(context, app.restore(v) ? 'تمت الاستعادة' : 'النسخة غير صالحة');
          }),
        ]), pad: EdgeInsets.zero),
        const SizedBox(height: 18),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(foregroundColor: const Color(0xFFB45309), side: const BorderSide(color: Color(0xFFE8B98F))),
          icon: const Icon(Icons.delete_forever_rounded),
          onPressed: () async {
            if (await confirm(context, 'مسح كل البيانات؟', 'سيتم حذف جميع العقود والدفعات نهائياً.')) { app.contracts.clear(); app.receiptNo = 0; app.save(); }
          },
          label: const Text('مسح كل البيانات'),
        ),
      ]);
}
