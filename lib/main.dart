import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';
import 'db.dart';
import 'util.dart';

const green = Color(0xFF0F6B4F), ink = Color(0xFF14201C), bg = Color(0xFFF6F7F4);
const muted = Color(0xFF4B5651), line = Color(0xFFD5DAD4), okFg = Color(0xFF0B5A41);
const bd = TextStyle(fontWeight: FontWeight.bold);
const mu = TextStyle(fontSize: 13, color: muted);
const sl = ['نشط', 'متأخر', 'مكتمل'];
const sk = [K.neu, K.late, K.ok];

void go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));
/// الحرف الأول للصورة الرمزية: يتجاوز «ال» التعريف حتى لا يظهر الحرف «ا» فقط
String ini(String n) {
  var t = n.trim();
  if (t.length > 3 && t.startsWith('ال')) t = t.substring(2);
  return t.isEmpty ? '؟' : t.substring(0, 1);
}

void sb(BuildContext c, String m) => ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await db.load();
  runApp(const App());
}

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'أقساط',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [GlobalMaterialLocalizations.delegate, GlobalWidgetsLocalizations.delegate, GlobalCupertinoLocalizations.delegate],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
          scaffoldBackgroundColor: bg,
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme().apply(bodyColor: ink, displayColor: ink),
        ),
        home: const Splash(),
      );
}

// ───────── شاشة البداية ─────────
class Splash extends StatefulWidget {
  const Splash({super.key});
  @override
  State<Splash> createState() => _SplashS();
}

class _SplashS extends State<Splash> {
  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 2200), () {
      if (!mounted) return;
      Navigator.pushReplacement(
          context,
          PageRouteBuilder(
            transitionDuration: const Duration(milliseconds: 500),
            pageBuilder: (_, __, ___) => const Shell(),
            transitionsBuilder: (_, a, __, child) => FadeTransition(opacity: a, child: child),
          ));
    });
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        backgroundColor: Colors.white,
        body: Center(
          child: TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: const Duration(milliseconds: 900),
            curve: Curves.easeOut,
            builder: (_, v, child) => Opacity(opacity: v, child: Transform.scale(scale: .85 + .15 * v, child: child)),
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              Image.asset('assets/logo.png', width: 260),
              const SizedBox(height: 8),
              const Text('إدارة البيع بالأقساط', style: TextStyle(color: muted, fontSize: 15)),
              const SizedBox(height: 28),
              const SizedBox(width: 26, height: 26, child: CircularProgressIndicator(strokeWidth: 3, color: green)),
            ]),
          ),
        ),
      );
}

// ───────── مكونات مشتركة ─────────
enum K { ok, late, neu }

const _pc = {
  K.ok: [Color(0xFFE3F1EA), okFg],
  K.late: [Color(0xFFFDEBDD), Color(0xFF9A3412)],
  K.neu: [Color(0xFFECEEEA), Color(0xFF3F4A46)],
};

Widget live(Widget Function() f) => ListenableBuilder(listenable: db, builder: (_, __) => f());

class Pill extends StatelessWidget {
  final String t;
  final K k;
  const Pill(this.t, this.k, {super.key});
  @override
  Widget build(BuildContext c) => Container(
        margin: const EdgeInsets.only(top: 4),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(color: _pc[k]![0], borderRadius: BorderRadius.circular(10)),
        child: Text(t, style: TextStyle(fontSize: 12, color: _pc[k]![1])),
      );
}

class Box extends StatelessWidget {
  final Widget child;
  final double pad;
  final VoidCallback? onTap;
  const Box(this.child, {this.pad = 16, this.onTap, super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          clipBehavior: Clip.antiAlias,
          child: InkWell(onTap: onTap, child: Padding(padding: EdgeInsets.all(pad), child: child)),
        ),
      );
}

class Item extends StatelessWidget {
  final String av, n, s, a, p;
  final K k;
  final VoidCallback? onTap;
  const Item(this.av, this.n, this.s, this.a, this.p, this.k, {this.onTap, super.key});
  @override
  Widget build(BuildContext c) => Box(
        Row(children: [
          CircleAvatar(radius: 22, backgroundColor: const Color(0xFFE3F1EA), child: Text(av, style: bd.copyWith(color: okFg))),
          const SizedBox(width: 12),
          Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(n, style: bd.copyWith(fontSize: 15)), Text(s, style: mu)])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [Text(a, style: bd.copyWith(fontSize: 14)), Pill(p, k)]),
        ]),
        pad: 14,
        onTap: onTap,
      );
}

class Pg extends StatelessWidget {
  final String t;
  final List<Widget> c;
  final bool back;
  final Widget? fab;
  final List<Widget> acts;
  const Pg(this.t, this.c, {this.back = false, this.fab, this.acts = const [], super.key});
  @override
  Widget build(BuildContext ctx) => Scaffold(
        floatingActionButton: fab,
        body: SafeArea(
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 90), children: [
            Row(children: [
              if (back) ...[IconButton.outlined(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.arrow_forward)), const SizedBox(width: 10)],
              Expanded(child: Text(t, style: bd.copyWith(fontSize: back ? 18 : 22))),
              ...acts,
            ]),
            const SizedBox(height: 16),
            ...c,
          ]),
        ),
      );
}

Widget btn(String t, VoidCallback? f, {bool outline = false, bool dark = false}) {
  final sh = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const sz = Size.fromHeight(52);
  return outline
      ? OutlinedButton(onPressed: f, style: OutlinedButton.styleFrom(minimumSize: sz, shape: sh, foregroundColor: green, backgroundColor: Colors.white, side: const BorderSide(color: green)), child: Text(t, style: bd))
      : FilledButton(onPressed: f, style: FilledButton.styleFrom(minimumSize: sz, shape: sh, backgroundColor: dark ? ink : green), child: Text(t, style: bd));
}

Widget two(Widget a, Widget b) => Padding(padding: const EdgeInsets.symmetric(vertical: 6), child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]));

Widget kv(String l, String v, {Color? c, bool first = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(border: first ? null : const Border(top: BorderSide(color: Color(0xFFEDEFEB)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(l, style: const TextStyle(color: muted)), Text(v, style: bd.copyWith(color: c))]),
    );

Widget seg(List<String> it, int a, ValueChanged<int> f) => Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(children: [
        for (var i = 0; i < it.length; i++)
          Expanded(
              child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 4),
            child: GestureDetector(
              onTap: () => f(i),
              child: Container(
                height: 42,
                alignment: Alignment.center,
                decoration: BoxDecoration(color: i == a ? green : Colors.white, border: i == a ? null : Border.all(color: line), borderRadius: BorderRadius.circular(14)),
                child: Text(it[i], style: TextStyle(color: i == a ? Colors.white : ink, fontWeight: i == a ? FontWeight.bold : FontWeight.normal)),
              ),
            ),
          )),
      ]),
    );

Widget stat(String v, String l, {bool warn = false}) => Expanded(
    child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 4),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(color: warn ? const Color(0xFFFDEBDD) : Colors.white, borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            FittedBox(fit: BoxFit.scaleDown, alignment: AlignmentDirectional.centerStart, child: Text(v, style: bd.copyWith(fontSize: 16, color: warn ? const Color(0xFF9A3412) : ink))),
            Text(l, style: TextStyle(fontSize: 12, color: warn ? const Color(0xFF9A3412) : muted)),
          ]),
        )));

Widget hd(String t) => Padding(padding: const EdgeInsets.only(top: 6, bottom: 10), child: Text(t, style: bd.copyWith(fontSize: 16)));
Widget empty(String t) => Padding(padding: const EdgeInsets.all(32), child: Center(child: Text(t, textAlign: TextAlign.center, style: mu)));

Widget fld(String l, {TextEditingController? c, ValueChanged<String>? f, bool num = false}) {
  final b = OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line));
  return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(controller: c, onChanged: f, keyboardType: num ? TextInputType.number : TextInputType.text, decoration: InputDecoration(labelText: l, filled: true, fillColor: Colors.white, border: b, enabledBorder: b)));
}

Future<String?> ask(BuildContext c, String t, {String init = '', bool num = false}) {
  final k = TextEditingController(text: init);
  return showDialog<String>(
      context: c,
      builder: (d) => AlertDialog(
            title: Text(t),
            content: TextField(controller: k, autofocus: true, keyboardType: num ? TextInputType.number : TextInputType.text),
            actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(d, k.text), child: const Text('حفظ'))],
          ));
}

Future<bool> sure(BuildContext c, String t) async =>
    await showDialog<bool>(
        context: c,
        builder: (d) => AlertDialog(title: Text(t), actions: [TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')), TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('تأكيد'))])) ??
    false;

Future<void> alert(BuildContext c, String m) => showDialog<void>(
    context: c,
    builder: (d) => AlertDialog(title: const Text('تنبيه'), content: Text(m), actions: [TextButton(onPressed: () => Navigator.pop(d), child: const Text('حسنًا'))]));

Future<String?> pickMethod(BuildContext c, double amt, double fee) => showModalBottomSheet<String>(
    context: c,
    builder: (d) => SafeArea(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
          Padding(padding: const EdgeInsets.all(16), child: Text('المبلغ: ${money(amt)}${fee > 0 ? ' (شامل غرامة ${money(fee)})' : ''}', style: bd)),
          for (final m in ['نقدًا', 'تحويل بنكي']) ListTile(title: Text(m), onTap: () => Navigator.pop(d, m)),
        ])));

List<Contract> consOf(Cust c) => db.cons.where((k) => k.cid == c.id).toList();
double remOf(Cust c) => consOf(c).fold(0.0, (s, k) => s + k.remaining);

/// (تقييم، لون، نسبة الالتزام)
(String, K, int) rate(Cust c) {
  final ks = consOf(c), g = db.gi('grace');
  final paid = [for (final k in ks) for (final i in k.insts.where((i) => i.isPaid)) i];
  final ok = paid.where((i) => !i.paid!.isAfter(i.due.add(Duration(days: g + 1)))).length;
  final pct = paid.isEmpty ? 100 : ok * 100 ~/ paid.length;
  if (ks.any((k) => k.st == 1)) return ('متأخر', K.late, pct);
  return pct >= 90 ? ('ملتزم', K.ok, pct) : ('متوسط', K.neu, pct);
}

Widget instItem(BuildContext c, Contract k, Inst i) {
  final cu = db.cust(k.cid), late = i.lateDays;
  return Item(ini(cu?.name ?? ''), cu?.name ?? '', '${k.item} · قسط ${k.insts.indexOf(i) + 1} من ${k.insts.length}', money(i.amt),
      late > 0 ? 'متأخر $late يوم' : (i.due == today() ? 'اليوم' : dstr(i.due)), late > 0 ? K.late : K.neu,
      onTap: () => go(c, ContractDetail(k.id)));
}

// ───────── الهيكل ─────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [Home(), ContractsScr(), CustomersScr(), ReportsScr(), SettingsScr()]),
        bottomNavigationBar: NavigationBar(selectedIndex: i, onDestinationSelected: (v) => setState(() => i = v), destinations: const [
          NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
          NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'العقود'),
          NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العملاء'),
          NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
          NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
        ]),
      );
}

// ───────── الرئيسية ─────────
class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final t = today(), all = db.all;
        final mo = all.where((e) => e.$2.due.year == t.year && e.$2.due.month == t.month);
        final tot = mo.fold(0.0, (s, e) => s + e.$2.amt);
        final got = mo.where((e) => e.$2.isPaid).fold(0.0, (s, e) => s + e.$2.amt);
        final pct = tot == 0 ? 0.0 : got / tot;
        final un = all.where((e) => !e.$2.isPaid).toList()..sort((a, b) => a.$2.due.compareTo(b.$2.due));
        // قسط واحد فقط لكل عقد (القسط التالي)، حتى لا يتكرر اسم العميل
        final nxt = [for (final k in db.cons) if (k.next != null) (k, k.next!)]..sort((a, b) => a.$2.due.compareTo(b.$2.due));
        return Pg(
          'لوحة التحصيل',
          [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(24)),
              child: DefaultTextStyle(
                style: const TextStyle(color: Colors.white, fontSize: 13),
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  const Text('المستحق هذا الشهر', style: TextStyle(fontSize: 14)),
                  Text(money(tot), style: bd.copyWith(fontSize: 30, color: Colors.white)),
                  const SizedBox(height: 12),
                  ClipRRect(borderRadius: BorderRadius.circular(4), child: LinearProgressIndicator(value: pct, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white)),
                  const SizedBox(height: 8),
                  Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('تم تحصيل ${(pct * 100).round()}٪'), Text('متبقٍ ${money(tot - got)}')]),
                ]),
              ),
            ),
            const SizedBox(height: 14),
            Row(children: [
              stat('${un.where((e) => e.$2.lateDays > 0).length}', 'أقساط متأخرة', warn: true),
              stat('${un.where((e) => e.$2.due == t).length}', 'تستحق اليوم'),
              stat('${db.cons.where((k) => k.st != 2).length}', 'عقد نشط'),
            ]),
            const SizedBox(height: 16),
            hd('الأقساط القادمة'),
            if (un.isEmpty) empty('لا توجد أقساط مستحقة.\nأضف عقدًا جديدًا من الزر بالأسفل.'),
            for (final (k, i) in nxt.take(5)) instItem(c, k, i),
          ],
          acts: [IconButton(tooltip: 'حاسبة الأقساط', onPressed: () => go(c, const Calc()), icon: const Icon(Icons.calculate_outlined))],
          fab: FloatingActionButton.extended(backgroundColor: ink, foregroundColor: Colors.white, onPressed: () => go(c, const NewContract()), icon: const Icon(Icons.add), label: const Text('عقد جديد')),
        );
      });
}

// ───────── العقود ─────────
class ContractsScr extends StatefulWidget {
  const ContractsScr({super.key});
  @override
  State<ContractsScr> createState() => _CsS();
}

class _CsS extends State<ContractsScr> {
  int f = 0;
  String q = '';
  @override
  Widget build(BuildContext c) => live(() {
        final list = db.cons.where((k) => (f == 0 || k.st == f - 1) && ('${k.id}${db.cust(k.cid)?.name}${k.item}').contains(q.trim())).toList();
        return Pg('العقود', [
          fld('ابحث برقم العقد أو اسم العميل', f: (v) => setState(() => q = v)),
          seg(['الكل', 'نشط', 'متأخر', 'مكتمل'], f, (v) => setState(() => f = v)),
          if (list.isEmpty) empty('لا توجد عقود'),
          for (final k in list)
            Item(ini(db.cust(k.cid)?.name ?? ''), '#${k.id} · ${db.cust(k.cid)?.name}', '${k.item} · ${k.paidCount} من ${k.insts.length}', money(k.remaining), sl[k.st], sk[k.st], onTap: () => go(c, ContractDetail(k.id))),
        ]);
      });
}

// ───────── تفاصيل العقد ─────────
Future<void> payFlow(BuildContext c, Contract k) async {
  final nx = k.next;
  if (nx == null) return;
  final fee = nx.lateDays > db.gi('grace') ? db.gn('fee') : 0.0;
  final m = await pickMethod(c, nx.amt + fee, fee);
  if (m == null) return;
  final i = db.pay(k, m)!;
  if (c.mounted) go(c, Receipt(k.id, k.insts.indexOf(i)));
}

class ContractDetail extends StatelessWidget {
  final String id;
  const ContractDetail(this.id, {super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final k = db.con(id), cu = k == null ? null : db.cust(k.cid);
        if (k == null || cu == null) return const Pg('عقد', back: true, [Text('العقد غير موجود')]);
        final nx = k.next;
        return Pg('عقد #${k.id}', back: true, [
          Box(Column(children: [
            Row(children: [
              CircleAvatar(radius: 24, backgroundColor: const Color(0xFFE3F1EA), child: Text(ini(cu.name), style: bd.copyWith(color: okFg))),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(cu.name, style: bd), Text(k.item, style: mu), Text('تاريخ العقد: ${dstr(k.date)}', style: mu)])),
              Pill(sl[k.st], sk[k.st]),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              for (var i = 0; i < k.insts.length; i++)
                Expanded(child: Container(height: 8, margin: const EdgeInsets.symmetric(horizontal: 1.5), decoration: BoxDecoration(color: k.insts[i].isPaid ? green : (k.insts[i].lateDays > 0 ? const Color(0xFFE58A4B) : const Color(0xFFDDE1DB)), borderRadius: BorderRadius.circular(4)))),
            ]),
            const SizedBox(height: 8),
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('سُدّد ${money(k.insts.where((i) => i.isPaid).fold(0.0, (s, i) => s + i.amt))}', style: mu), Text('المتبقي ${money(k.remaining)}', style: mu)]),
          ])),
          two(btn('تسجيل دفعة', nx == null ? null : () => payFlow(c, k)),
              btn('إرسال تذكير', nx == null ? null : () => openWa(cu.phone, 'السلام عليكم ${cu.name}، تذكير بقسط ${money(nx.amt)} من العقد #${k.id} المستحق في ${dstr(nx.due)}. شكرًا لكم.'), outline: true)),
          btn('طباعة العقد PDF', () => printDoc('contract-${k.id}.pdf', 'عقد بيع بالأقساط رقم ${k.id}', [
                ['التاريخ', dstr(k.date)], ['العميل', cu.name], ['هاتف العميل', cu.phone], ['السلعة', k.item],
                ['السعر الإجمالي', money(k.price)], ['الدفعة المقدمة', money(k.down)], ['نسبة الربح', '${nf(k.markup)}٪'],
                ['عدد الأقساط', '${k.insts.length}'],
              ], head: ['م', 'تاريخ الاستحقاق', 'المبلغ', 'الحالة'], table: [for (var i = 0; i < k.insts.length; i++) ['${i + 1}', dstr(k.insts[i].due), money(k.insts[i].amt), k.insts[i].isPaid ? 'مدفوع' : 'قادم']], sign: true), outline: true),
          const SizedBox(height: 10),
          btn('سداد مبكر / جدولة', nx == null ? null : () => go(c, Settlement(k.id)), dark: true),
          const SizedBox(height: 16),
          hd('جدول الأقساط'),
          for (var n = 0; n < k.insts.length; n++)
            Item('${n + 1}', 'القسط ${n + 1}', dstr(k.insts[n].due), money(k.insts[n].amt), k.insts[n].isPaid ? 'مدفوع' : (k.insts[n].lateDays > 0 ? 'متأخر' : 'قادم'), k.insts[n].isPaid ? K.ok : (k.insts[n].lateDays > 0 ? K.late : K.neu),
                onTap: k.insts[n].isPaid ? () => go(c, Receipt(k.id, n)) : null),
        ]);
      });
}

// ───────── عقد جديد ─────────
class NewContract extends StatefulWidget {
  final double price, down, markup;
  final int n;
  final Cust? cust; // عند فتحها من ملف عميل موجود
  const NewContract({this.price = 0, this.down = 0, this.markup = 0, this.n = 10, this.cust, super.key});
  @override
  State<NewContract> createState() => _NcS();
}

class _NcS extends State<NewContract> {
  static const ns = [6, 10, 12, 24];
  late final name = TextEditingController(text: widget.cust?.name), phone = TextEditingController(text: widget.cust?.phone), item = TextEditingController();
  late final price = TextEditingController(text: widget.price == 0 ? '' : widget.price.round().toString());
  late final down = TextEditingController(text: widget.down == 0 ? '' : widget.down.round().toString());
  late final mk = TextEditingController(text: nf(widget.markup));
  late int ni = ns.contains(widget.n) ? ns.indexOf(widget.n) : 1;
  DateTime date = today();

  bool old = false; // وضع تسجيل عقد قديم (الحقل مغلق في العقود الجديدة)
  Future<void> pickDate() async {
    if (!old) {
      final ok = await showDialog<bool>(
              context: context,
              builder: (d) => AlertDialog(
                    title: const Text('تنبيه'),
                    content: const Text('تغيير تاريخ العقد لتسجيل عقد قديم فقط. العقد الجديد يُسجَّل بتاريخ اليوم تلقائيًا.'),
                    actions: [
                      TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('إلغاء')),
                      TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('تسجيل عقد قديم')),
                    ],
                  )) ??
          false;
      if (!ok || !mounted) return;
    }
    final d = await showDatePicker(context: context, initialDate: date, firstDate: DateTime(2015), lastDate: today());
    if (d != null) {
      setState(() {
        date = d;
        old = true;
      });
    }
  }

  void rf(String _) => setState(() {});

  String _auto = ''; // آخر هاتف عُبّئ تلقائيًا
  void onName(String _) {
    final x = db.byName(name.text);
    if (x != null) {
      phone.text = x.phone;
      _auto = x.phone;
    } else if (_auto.isNotEmpty && phone.text == _auto) {
      phone.clear();
      _auto = '';
    }
    setState(() {});
  }
  @override
  Widget build(BuildContext c) {
    final p = pv(price.text).toDouble(), d = pv(down.text).toDouble(), m = pv(mk.text).toDouble();
    final monthly = p > d ? (p - d) * (1 + m / 100) / ns[ni] : 0.0;
    return Pg('عقد تقسيط جديد', back: true, [
      fld('اسم العميل', c: name, f: onName),
      if (db.byName(name.text) != null && db.byName(name.text)!.id != widget.cust?.id) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('هذا الاسم موجود مسبقًا، سيُضاف العقد إلى ملف العميل نفسه', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)))),
      fld('هاتف العميل', c: phone, num: true),
      fld('السلعة', c: item),
      Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: InkWell(
          onTap: pickDate,
          child: InputDecorator(
            decoration: InputDecoration(
              labelText: 'تاريخ العقد',
              filled: true,
              fillColor: old ? Colors.white : const Color(0xFFECEEEA),
              suffixIcon: Icon(old ? Icons.calendar_today_outlined : Icons.lock_outline),
              border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line)),
            ),
            child: Text(dstr(date), style: TextStyle(color: old ? ink : muted)),
          ),
        ),
      ),
      if (old) Align(alignment: AlignmentDirectional.centerStart, child: TextButton(onPressed: () => setState(() { date = today(); old = false; }), child: const Text('إلغاء التاريخ القديم (عقد جديد)'))),
      if (date.isBefore(today())) const Padding(padding: EdgeInsets.only(bottom: 10), child: Text('عقد بتاريخ سابق: الأقساط التي حلّ موعدها قبل اليوم ستظهر متأخرة', style: TextStyle(fontSize: 12, color: Color(0xFF9A3412)))),
      Row(children: [Expanded(child: fld('السعر الإجمالي', c: price, num: true, f: rf)), const SizedBox(width: 10), Expanded(child: fld('الدفعة المقدمة', c: down, num: true, f: rf))]),
      fld('نسبة الربح ٪ على المبلغ الممول', c: mk, num: true, f: rf),
      const Text('عدد الأقساط', style: mu),
      const SizedBox(height: 6),
      seg([for (final n in ns) '$n'], ni, (v) => setState(() => ni = v)),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(20)),
        child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('القسط الشهري'),
          Text(money(monthly), style: bd.copyWith(fontSize: 30, color: Colors.white)),
          Text('أول استحقاق: ${dstr(addMonths(date, 1))}'),
        ])),
      ),
      const SizedBox(height: 16),
      btn('إنشاء العقد', () async {
        if (name.text.trim().isEmpty || phone.text.trim().isEmpty || item.text.trim().isEmpty) return sb(c, 'أكمل بيانات العميل والسلعة');
        if (p <= 0 || d < 0 || d >= p) return sb(c, 'تحقق من السعر والدفعة المقدمة');
        if (db.byName(name.text) != null && db.byName(name.text)!.id != widget.cust?.id) {
          final use = await showDialog<bool>(
                  context: c,
                  builder: (d) => AlertDialog(
                        title: const Text('تنبيه'),
                        content: const Text('هذا الاسم موجود مسبقًا. سيُضاف العقد الجديد إلى ملف العميل نفسه.'),
                        actions: [
                          TextButton(onPressed: () => Navigator.pop(d, false), child: const Text('تعديل الاسم')),
                          TextButton(onPressed: () => Navigator.pop(d, true), child: const Text('إضافة عقد للعميل')),
                        ],
                      )) ??
              false;
          if (!use || !c.mounted) return;
        }
        final k = db.create(name: name.text, phone: phone.text, item: item.text, price: p, down: d, markup: m, n: ns[ni], date: date);
        Navigator.pushReplacement(c, MaterialPageRoute(builder: (_) => ContractDetail(k.id)));
      }),
    ]);
  }
}

// ───────── الحاسبة ─────────
class Calc extends StatefulWidget {
  const Calc({super.key});
  @override
  State<Calc> createState() => _CalcS();
}

class _CalcS extends State<Calc> {
  final price = TextEditingController(text: '1200000');
  double down = .25, markup = 10;
  int ni = 2;
  static const ns = [6, 10, 12, 24];
  @override
  Widget build(BuildContext c) {
    final p = pv(price.text).toDouble(), fin = p * (1 - down), profit = fin * markup / 100, total = fin + profit, monthly = total / ns[ni];
    return Pg('حاسبة الأقساط', back: true, [
      fld('سعر السلعة', c: price, num: true, f: (_) => setState(() {})),
      Text('الدفعة المقدمة: ${money(p * down)} · ${(down * 100).round()}٪', style: bd),
      Slider(value: down, min: 0, max: .8, divisions: 16, onChanged: (v) => setState(() => down = v)),
      Text('نسبة الربح على المبلغ الممول: ${markup.round()}٪', style: bd),
      Slider(value: markup, min: 0, max: 30, divisions: 30, onChanged: (v) => setState(() => markup = v)),
      const Text('عدد الأقساط', style: mu),
      const SizedBox(height: 6),
      seg([for (final n in ns) '$n'], ni, (v) => setState(() => ni = v)),
      Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(22)),
        child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 14), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('القسط الشهري'),
          Text(money(monthly), style: bd.copyWith(fontSize: 32, color: Colors.white)),
          const SizedBox(height: 8),
          for (final r in [['المبلغ الممول', fin], ['الربح', profit], ['إجمالي السداد بعد المقدمة', total]])
            Padding(padding: const EdgeInsets.symmetric(vertical: 5), child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text(r[0] as String), Text(money(r[1] as num), style: bd)])),
        ])),
      ),
      const SizedBox(height: 14),
      two(btn('مشاركة العرض', () => Clipboard.setData(ClipboardData(text: 'عرض تقسيط: سعر ${money(p)}، مقدمة ${money(p * down)}، ${ns[ni]} قسطًا بقيمة ${money(monthly)} شهريًا.')).then((_) => c.mounted ? sb(c, 'تم نسخ العرض') : null), outline: true),
          btn('إنشاء عقد', () => go(c, NewContract(price: p, down: p * down, markup: markup, n: ns[ni])), dark: true)),
    ]);
  }
}

// ───────── العملاء ─────────
class CustomersScr extends StatefulWidget {
  const CustomersScr({super.key});
  @override
  State<CustomersScr> createState() => _CuS();
}

class _CuS extends State<CustomersScr> {
  String q = '';
  @override
  Widget build(BuildContext c) => live(() {
        final list = db.custs.where((x) => '${x.name}${x.phone}'.contains(q.trim())).toList();
        return Pg('العملاء', [
          fld('ابحث بالاسم أو رقم الهاتف', f: (v) => setState(() => q = v)),
          if (list.isEmpty) empty('لا يوجد عملاء'),
          for (final x in list) () {
            final r = rate(x);
            return Item(ini(x.name), x.name, '${consOf(x).length} عقد · ${x.phone}', money(remOf(x)), r.$1, r.$2, onTap: () => go(c, CustomerProfile(x.id)));
          }(),
        ], fab: FloatingActionButton.extended(
          backgroundColor: ink, foregroundColor: Colors.white, icon: const Icon(Icons.person_add_alt), label: const Text('عميل جديد'),
          onPressed: () async {
            final n = await ask(c, 'اسم العميل');
            if (n == null || n.trim().isEmpty || !c.mounted) return;
            if (db.byName(n) != null) return alert(c, 'هذا الاسم موجود مسبقًا');
            final p = await ask(c, 'رقم الهاتف', num: true);
            if (p != null && p.trim().isNotEmpty) db.addCust(n, p);
          },
        ));
      });
}

class CustomerProfile extends StatelessWidget {
  final String id;
  const CustomerProfile(this.id, {super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final x = db.cust(id);
        if (x == null) return const Pg('ملف العميل', back: true, [Text('العميل غير موجود')]);
        final ks = consOf(x), r = rate(x);
        return Pg('ملف العميل', back: true, [
          Row(children: [
            CircleAvatar(radius: 30, backgroundColor: green, child: Text(ini(x.name), style: bd.copyWith(color: Colors.white, fontSize: 22))),
            const SizedBox(width: 14),
            Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(x.name, style: bd.copyWith(fontSize: 18)), Text(x.phone, style: mu)]),
          ]),
          const SizedBox(height: 14),
          Row(children: [stat('${ks.where((k) => k.st != 2).length}', 'عقود نشطة'), stat(money(remOf(x)), 'المتبقي'), stat('${r.$3}٪', 'نسبة الالتزام', warn: r.$2 == K.late)]),
          two(btn('اتصال', () => callPhone(x.phone), outline: true), btn('واتساب', () => openWa(x.phone, 'السلام عليكم ${x.name}'))),
        btn('عقد جديد لهذا العميل', () => go(c, NewContract(cust: x)), dark: true),
          hd('العقود'),
          if (ks.isEmpty) empty('لا توجد عقود لهذا العميل'),
          for (final k in ks) Item('${ks.indexOf(k) + 1}', '#${k.id} · ${k.item}', 'قسط ${k.paidCount} من ${k.insts.length}', money(k.remaining), sl[k.st], sk[k.st], onTap: () => go(c, ContractDetail(k.id))),
        ]);
      });
}

// ───────── التقارير ─────────
class ReportsScr extends StatefulWidget {
  const ReportsScr({super.key});
  @override
  State<ReportsScr> createState() => _RpS();
}

class _RpS extends State<ReportsScr> {
  int p = 1;
  @override
  Widget build(BuildContext c) => live(() {
        final t = today(), all = db.all;
        final from = p == 0 ? t.subtract(const Duration(days: 6)) : (p == 1 ? DateTime(t.year, t.month, 1) : DateTime(t.year, 1, 1));
        final paid = all.where((e) => e.$2.isPaid && !e.$2.paid!.isBefore(from)).toList();
        final coll = paid.fold(0.0, (s, e) => s + e.$2.amt);
        final profit = paid.fold(0.0, (s, e) => s + e.$2.amt * e.$1.markup / (100 + e.$1.markup));
        final late = all.where((e) => e.$2.lateDays > 0).toList();
        final bars = [for (var j = 5; j >= 0; j--) addMonths(DateTime(t.year, t.month, 1), -j)];
        final vals = [for (final m in bars) all.where((e) => e.$2.isPaid && e.$2.paid!.year == m.year && e.$2.paid!.month == m.month).fold(0.0, (s, e) => s + e.$2.amt)];
        final mx = vals.fold(0.0, (a, b) => a > b ? a : b);
        final byC = <String, double>{};
        for (final e in late) { byC[e.$1.cid] = (byC[e.$1.cid] ?? 0) + e.$2.amt; }
        final top = byC.entries.toList()..sort((a, b) => b.value.compareTo(a.value));
        return Pg('التقارير', [
          seg(['آخر 7 أيام', 'هذا الشهر', 'هذه السنة'], p, (v) => setState(() => p = v)),
          Container(
            padding: const EdgeInsets.all(18),
            decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(22)),
            child: DefaultTextStyle(style: const TextStyle(color: Colors.white, fontSize: 13), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إجمالي التحصيل'),
              Text(money(coll), style: bd.copyWith(fontSize: 28, color: Colors.white)),
            ])),
          ),
          const SizedBox(height: 10),
          Row(children: [stat(money(profit), 'الأرباح'), stat(money(late.fold(0.0, (s, e) => s + e.$2.amt)), 'المتأخرات', warn: true)]),
          const SizedBox(height: 14),
          Box(SizedBox(height: 150, child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 6; i++)
              Expanded(child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(height: mx == 0 ? 6 : 6 + 100 * vals[i] / mx, margin: const EdgeInsets.symmetric(horizontal: 4), decoration: BoxDecoration(color: i == 5 ? green : const Color(0xFFBFD9CD), borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Text(months[bars[i].month - 1], style: const TextStyle(fontSize: 11, color: muted)),
              ])),
          ]))),
          hd('أكثر العملاء تأخرًا'),
          if (top.isEmpty) empty('لا توجد متأخرات 👌'),
          for (final e in top.take(3)) () {
            final x = db.cust(e.key);
            return Item(ini(x?.name ?? ''), x?.name ?? '', '${late.where((l) => l.$1.cid == e.key).length} أقساط متأخرة', money(e.value), 'متأخر', K.late, onTap: x == null ? null : () => go(c, CustomerProfile(x.id)));
          }(),
        ]);
      });
}

// ───────── الإيصال ─────────
class Receipt extends StatelessWidget {
  final String id;
  final int idx;
  const Receipt(this.id, this.idx, {super.key});
  @override
  Widget build(BuildContext c) => live(() {
        final k = db.con(id), cu = k == null ? null : db.cust(k.cid);
        if (k == null || cu == null || idx >= k.insts.length || !k.insts[idx].isPaid) return const Pg('إيصال', back: true, [Text('الإيصال غير موجود')]);
        final i = k.insts[idx], tot = i.amt + i.fee;
        final rows = [
          ['رقم الإيصال', i.rcpt ?? '-'], ['العميل', cu.name], ['العقد', '#${k.id} · القسط ${idx + 1} من ${k.insts.length}'],
          ['التاريخ', dstr(i.paid!)], ['طريقة الدفع', i.method ?? '-'], if (i.fee > 0) ['غرامة التأخير', money(i.fee)], ['المتبقي بعد الدفعة', money(i.left)],
        ];
        return Pg('إيصال الدفعة', back: true, [
          Box(Column(children: [
            const CircleAvatar(radius: 28, backgroundColor: Color(0xFFE3F1EA), child: Icon(Icons.check, color: okFg, size: 30)),
            const SizedBox(height: 10),
            const Text('تم تسجيل الدفعة', style: mu),
            Text(money(tot), style: bd.copyWith(fontSize: 30)),
            const SizedBox(height: 10),
            for (var n = 0; n < rows.length; n++) kv(rows[n][0], rows[n][1], first: n == 0),
          ]), pad: 20),
          two(btn('واتساب', () => openWa(cu.phone, 'إيصال ${i.rcpt}: تم استلام ${money(tot)} من ${cu.name} للعقد #${k.id}. المتبقي ${money(i.left)}.'), outline: true),
              btn('طباعة PDF', () => printDoc('receipt-${i.rcpt}.pdf', 'إيصال استلام', [['رقم الإيصال', i.rcpt ?? '-'], ['العميل', cu.name], ['رقم العقد', k.id], ['القسط', '${idx + 1} من ${k.insts.length}'], ['التاريخ', dstr(i.paid!)], ['طريقة الدفع', i.method ?? '-'], if (i.fee > 0) ['غرامة التأخير', money(i.fee)], ['المتبقي بعد الدفعة', money(i.left)]], big: ['المبلغ المستلم', money(tot)]), outline: true)),
          btn('تم', () => Navigator.pop(c), dark: true),
        ]);
      });
}

// ───────── سداد مبكر وجدولة ─────────
class Settlement extends StatefulWidget {
  final String id;
  const Settlement(this.id, {super.key});
  @override
  State<Settlement> createState() => _StS();
}

class _StS extends State<Settlement> {
  int t = 0;
  double months = 10;
  @override
  Widget build(BuildContext c) => live(() {
        final k = db.con(widget.id);
        if (k == null || k.next == null) return const Pg('سداد مبكر وجدولة', back: true, [Text('لا توجد أقساط متبقية لهذا العقد')]);
        final rem = k.remaining, disc = db.gn('disc');
        return Pg('سداد مبكر وجدولة', back: true, [
          seg(['سداد مبكر', 'تأجيل قسط', 'إعادة جدولة'], t, (v) => setState(() => t = v)),
          if (t == 0) ...[
            Box(Column(children: [kv('المتبقي على العقد', money(rem), first: true), kv('خصم السداد المبكر ${nf(disc)}٪', '− ${money(rem - db.settleDue(k))}', c: okFg), kv('المبلغ المستحق الآن', money(db.settleDue(k)))])),
            btn('تسوية العقد', () async {
              if (!await sure(c, 'تسوية العقد بمبلغ ${money(db.settleDue(k))}؟')) return;
              db.settle(k);
              if (c.mounted) { Navigator.pop(c); sb(c, 'تمت تسوية العقد'); }
            }),
            const SizedBox(height: 10),
            btn('سداد جزئي', () async {
              final v = await ask(c, 'المبلغ المدفوع الآن', num: true);
              final a = pv(v ?? '').toDouble();
              if (a <= 0) return;
              if (a >= rem) {
                if (c.mounted) sb(c, 'المبلغ يغطي كامل المتبقي، استخدم «تسوية العقد»');
                return;
              }
              if (!c.mounted) return;
              final m = await pickMethod(c, a, 0);
              if (m == null) return;
              final i = db.payPartial(k, a, m);
              if (i != null && c.mounted) go(c, Receipt(k.id, k.insts.indexOf(i)));
            }, outline: true),
          ],
          if (t == 1) ...[
            Box(Text('سيُنقل القسط القادم (${dstr(k.next!.due)}) إلى نهاية الجدول، وتمتد مدة العقد شهرًا.')),
            btn('تأكيد التأجيل', () { db.postpone(k); sb(c, 'تم تأجيل القسط'); }),
          ],
          if (t == 2)
            Box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('مدّ المتبقي ${money(rem)} على ${months.round()} شهرًا', style: bd),
              Slider(value: months, min: 1, max: 24, divisions: 23, onChanged: (v) => setState(() => months = v)),
              Text('القسط الجديد: ${money(rem / months.round())}', style: bd.copyWith(color: green, fontSize: 18)),
              const SizedBox(height: 12),
              btn('تعديل الجدول', () { db.resched(k, months.round()); sb(c, 'تم تعديل الجدول'); }, outline: true),
            ])),
        ]);
      });
}

// ───────── الإعدادات ─────────
class SettingsScr extends StatelessWidget {
  const SettingsScr({super.key});
  Widget row(String l, String v, VoidCallback f) => ListTile(title: Text(l), trailing: Row(mainAxisSize: MainAxisSize.min, children: [Text(v, style: mu), const Icon(Icons.chevron_left, color: muted)]), onTap: f);
  Widget sec(String t, List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(padding: const EdgeInsets.fromLTRB(4, 14, 4, 8), child: Text(t, style: bd.copyWith(fontSize: 13, color: muted))),
        Box(Column(children: c), pad: 0),
      ]);
  Widget numRow(BuildContext c, String l, String k, {bool isMoney = false}) =>
      row(l, isMoney ? money(db.gn(k)) : nf(db.gn(k)), () async {
        final v = await ask(c, l, init: nf(db.gn(k)), num: true);
        if (v != null && v.trim().isNotEmpty) db.setv(k, pv(v));
      });
  @override
  Widget build(BuildContext c) => live(() => Pg('الإعدادات', [
        sec('المنشأة', [
          row('اسم المنشأة (يظهر في المستندات)', db.gs('company'), () async {
            final v = await ask(c, 'اسم المنشأة', init: db.gs('company'));
            if (v != null && v.trim().isNotEmpty) db.setv('company', v.trim());
          }),
        ]),
        sec('التحصيل', [
          numRow(c, 'فترة السماح (أيام)', 'grace'),
          numRow(c, 'غرامة التأخير', 'fee', isMoney: true),
          numRow(c, 'خصم السداد المبكر ٪', 'disc'),
          row('رمز الدولة للواتساب', '+${db.gs('cc')}', () async {
            final v = await ask(c, 'رمز الدولة (مثال: 249)', init: db.gs('cc'), num: true);
            if (v != null && v.trim().isNotEmpty) db.setv('cc', v.trim());
          }),
        ]),
        sec('البيانات', [
          row('نسخ احتياطي إلى الجهاز', '', () async {
            if (db.custs.isEmpty && db.cons.isEmpty) return alert(c, 'لا توجد بيانات للنسخ الاحتياطي');
            final m = await backupFile();
            if (c.mounted) sb(c, m);
          }),
          row('استعادة من ملف في الجهاز', '', () async {
            if (!await sure(c, 'ستُستبدل البيانات الحالية بالنسخة المختارة. متابعة؟')) return;
            final m = await restoreFile();
            if (c.mounted) sb(c, m);
          }),
          row('حذف كل البيانات', '', () async {
            if (await sure(c, 'حذف كل العملاء والعقود نهائيًا؟')) db.reset();
          }),
        ]),
      ]));
}
