import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:google_fonts/google_fonts.dart';

const green = Color(0xFF0F6B4F), ink = Color(0xFF14201C), bg = Color(0xFFF6F7F4);
const muted = Color(0xFF4B5651), line = Color(0xFFD5DAD4), okFg = Color(0xFF0B5A41);
const bd = TextStyle(fontWeight: FontWeight.bold);
const mu = TextStyle(fontSize: 13, color: muted);

String money(num n) =>
    '${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} ج.س';
void go(BuildContext c, Widget w) => Navigator.push(c, MaterialPageRoute(builder: (_) => w));
void sb(BuildContext c, String m) =>
    ScaffoldMessenger.of(c).showSnackBar(SnackBar(content: Text(m)));
num pv(String s) => num.tryParse(s.replaceAll(',', '')) ?? 0;

void main() => runApp(const App());

class App extends StatelessWidget {
  const App({super.key});
  @override
  Widget build(BuildContext context) => MaterialApp(
        debugShowCheckedModeBanner: false,
        title: 'أقساط',
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        theme: ThemeData(
          useMaterial3: true,
          colorScheme: ColorScheme.fromSeed(seedColor: green, primary: green),
          scaffoldBackgroundColor: bg,
          textTheme: GoogleFonts.ibmPlexSansArabicTextTheme()
              .apply(bodyColor: ink, displayColor: ink),
        ),
        home: const Shell(),
      );
}

// ───────────── مكونات مشتركة ─────────────
enum K { ok, late, neu }

const _pc = {
  K.ok: [Color(0xFFE3F1EA), okFg],
  K.late: [Color(0xFFFDEBDD), Color(0xFF9A3412)],
  K.neu: [Color(0xFFECEEEA), Color(0xFF3F4A46)],
};

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
  final Color color;
  final double pad;
  final VoidCallback? onTap;
  const Box(this.child, {this.color = Colors.white, this.pad = 16, this.onTap, super.key});
  @override
  Widget build(BuildContext c) => Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: Material(
          color: color,
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
          CircleAvatar(
              radius: 22,
              backgroundColor: const Color(0xFFE3F1EA),
              child: Text(av, style: bd.copyWith(color: okFg))),
          const SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(n, style: bd.copyWith(fontSize: 15)),
            Text(s, style: mu),
          ])),
          Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text(a, style: bd.copyWith(fontSize: 14)),
            Pill(p, k),
          ]),
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
          child: ListView(padding: const EdgeInsets.fromLTRB(20, 12, 20, 24), children: [
            Row(children: [
              if (back) ...[
                IconButton.outlined(
                    onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.arrow_forward)),
                const SizedBox(width: 10),
              ],
              Expanded(child: Text(t, style: bd.copyWith(fontSize: back ? 18 : 22))),
              ...acts,
            ]),
            const SizedBox(height: 16),
            ...c,
          ]),
        ),
      );
}

Widget btn(String t, VoidCallback f, {bool outline = false, bool dark = false}) {
  final sh = RoundedRectangleBorder(borderRadius: BorderRadius.circular(16));
  const sz = Size.fromHeight(52);
  return outline
      ? OutlinedButton(
          onPressed: f,
          style: OutlinedButton.styleFrom(
              minimumSize: sz,
              shape: sh,
              foregroundColor: green,
              backgroundColor: Colors.white,
              side: const BorderSide(color: green)),
          child: Text(t, style: bd))
      : FilledButton(
          onPressed: f,
          style: FilledButton.styleFrom(
              minimumSize: sz, shape: sh, backgroundColor: dark ? ink : green),
          child: Text(t, style: bd));
}

Widget two(Widget a, Widget b) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 6),
    child: Row(children: [Expanded(child: a), const SizedBox(width: 10), Expanded(child: b)]));

Widget kv(String l, String v, {Color? c, bool first = false}) => Container(
      padding: const EdgeInsets.symmetric(vertical: 10),
      decoration: BoxDecoration(
          border: first ? null : const Border(top: BorderSide(color: Color(0xFFEDEFEB)))),
      child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
        Text(l, style: const TextStyle(color: muted)),
        Text(v, style: bd.copyWith(color: c)),
      ]),
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
                decoration: BoxDecoration(
                    color: i == a ? green : Colors.white,
                    border: i == a ? null : Border.all(color: line),
                    borderRadius: BorderRadius.circular(14)),
                child: Text(it[i],
                    style: TextStyle(
                        color: i == a ? Colors.white : ink,
                        fontWeight: i == a ? FontWeight.bold : FontWeight.normal)),
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
          decoration: BoxDecoration(
              color: warn ? const Color(0xFFFDEBDD) : Colors.white,
              borderRadius: BorderRadius.circular(16)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(v,
                style: bd.copyWith(fontSize: 17, color: warn ? const Color(0xFF9A3412) : ink)),
            Text(l, style: TextStyle(fontSize: 12, color: warn ? const Color(0xFF9A3412) : muted)),
          ]),
        )));

Widget hd(String t) => Padding(
    padding: const EdgeInsets.only(top: 6, bottom: 10),
    child: Text(t, style: bd.copyWith(fontSize: 16)));

Widget fld(String l, {TextEditingController? c, String? init, ValueChanged<String>? f, bool num = false}) {
  final b = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14), borderSide: const BorderSide(color: line));
  final d = InputDecoration(
      labelText: l, filled: true, fillColor: Colors.white, border: b, enabledBorder: b);
  final k = num ? TextInputType.number : TextInputType.text;
  return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: c != null
          ? TextField(controller: c, onChanged: f, keyboardType: k, decoration: d)
          : TextFormField(initialValue: init, onChanged: f, keyboardType: k, decoration: d));
}

Widget dark(String l, String v, List<Widget> more) => Container(
    padding: const EdgeInsets.all(18),
    decoration: BoxDecoration(color: ink, borderRadius: BorderRadius.circular(20)),
    child: DefaultTextStyle(
        style: const TextStyle(color: Colors.white, fontSize: 13),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text(l),
          Text(v, style: bd.copyWith(fontSize: 30, color: Colors.white)),
          ...more,
        ])));

// ───────────── الهيكل والتنقل ─────────────
class Shell extends StatefulWidget {
  const Shell({super.key});
  @override
  State<Shell> createState() => _ShellS();
}

class _ShellS extends State<Shell> {
  int i = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
        body: IndexedStack(index: i, children: const [
          Home(), ContractsScr(), CustomersScr(), ReportsScr(), SettingsScr(),
        ]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: i,
          onDestinationSelected: (v) => setState(() => i = v),
          destinations: const [
            NavigationDestination(icon: Icon(Icons.home_outlined), selectedIcon: Icon(Icons.home), label: 'الرئيسية'),
            NavigationDestination(icon: Icon(Icons.description_outlined), selectedIcon: Icon(Icons.description), label: 'العقود'),
            NavigationDestination(icon: Icon(Icons.people_outline), selectedIcon: Icon(Icons.people), label: 'العملاء'),
            NavigationDestination(icon: Icon(Icons.bar_chart_outlined), selectedIcon: Icon(Icons.bar_chart), label: 'التقارير'),
            NavigationDestination(icon: Icon(Icons.settings_outlined), selectedIcon: Icon(Icons.settings), label: 'الإعدادات'),
          ],
        ),
      );
}

// ───────────── 1) الرئيسية ─────────────
class Home extends StatelessWidget {
  const Home({super.key});
  @override
  Widget build(BuildContext c) => Pg(
        'لوحة التحصيل',
        [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(24)),
            child: DefaultTextStyle(
              style: const TextStyle(color: Colors.white, fontSize: 13),
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                const Text('المستحق هذا الشهر', style: TextStyle(fontSize: 14)),
                Text(money(4830000), style: bd.copyWith(fontSize: 30, color: Colors.white)),
                const SizedBox(height: 12),
                ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: const LinearProgressIndicator(
                        value: .64, minHeight: 8, backgroundColor: Colors.white24, color: Colors.white)),
                const SizedBox(height: 8),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [const Text('تم تحصيل 64٪'), Text('متبقٍ ${money(1740000)}')]),
              ]),
            ),
          ),
          const SizedBox(height: 14),
          Row(children: [
            stat('7', 'أقساط متأخرة', warn: true),
            stat('12', 'تستحق اليوم'),
            stat('86', 'عقد نشط'),
          ]),
          const SizedBox(height: 16),
          hd('الأقساط القادمة'),
          Item('ع', 'عبدالله الحربي', 'ثلاجة سامسونج · قسط 5 من 12', money(85000), 'متأخر 3 أيام', K.late,
              onTap: () => go(c, const ContractDetail())),
          Item('س', 'سارة القحطاني', 'غسالة LG · قسط 2 من 10', money(62000), 'اليوم', K.neu,
              onTap: () => go(c, const ContractDetail())),
          Item('م', 'محمد العتيبي', 'جوال آيفون · قسط 8 من 12', money(115000), 'تم السداد', K.ok,
              onTap: () => go(c, const ContractDetail())),
        ],
        acts: [
          IconButton(
              tooltip: 'حاسبة الأقساط',
              onPressed: () => go(c, const Calc()),
              icon: const Icon(Icons.calculate_outlined)),
          IconButton(
              tooltip: 'الإشعارات',
              onPressed: () => sb(c, 'لا توجد إشعارات جديدة'),
              icon: const Icon(Icons.notifications_none)),
        ],
        fab: FloatingActionButton.extended(
          backgroundColor: ink,
          foregroundColor: Colors.white,
          onPressed: () => go(c, const NewContract()),
          icon: const Icon(Icons.add),
          label: const Text('عقد جديد'),
        ),
      );
}

// ───────────── 2) العقود ─────────────
const _cs = [
  ('1042', 'عبدالله', 'ثلاجة سامسونج', 5, 12, 595000, 1),
  ('1067', 'عبدالله', 'تلفاز 55 بوصة', 3, 8, 490000, 0),
  ('1031', 'سارة', 'غسالة LG', 2, 10, 496000, 0),
  ('1018', 'محمد', 'جوال آيفون', 12, 12, 0, 2),
];
const _sl = ['نشط', 'متأخر', 'مكتمل'];
const _sk = [K.neu, K.late, K.ok];

class ContractsScr extends StatefulWidget {
  const ContractsScr({super.key});
  @override
  State<ContractsScr> createState() => _CsS();
}

class _CsS extends State<ContractsScr> {
  int f = 0;
  String q = '';
  @override
  Widget build(BuildContext c) => Pg('العقود', [
        fld('ابحث برقم العقد أو اسم العميل', f: (v) => setState(() => q = v)),
        seg(['الكل', 'نشط', 'متأخر', 'مكتمل'], f, (v) => setState(() => f = v)),
        for (final (id, n, it, p, t, r, s) in _cs.where(
            (e) => (f == 0 || e.$7 == f - 1) && ('${e.$1}${e.$2}${e.$3}').contains(q)))
          Item(n[0], '#$id · $n', '$it · $p من $t', money(r), _sl[s], _sk[s],
              onTap: () => go(c, const ContractDetail())),
      ]);
}

// ───────────── 3) تفاصيل العقد ─────────────
class ContractDetail extends StatelessWidget {
  const ContractDetail({super.key});
  @override
  Widget build(BuildContext c) => Pg('عقد #1042', back: true, [
        Box(Column(children: [
          const Row(children: [
            CircleAvatar(
                radius: 24,
                backgroundColor: Color(0xFFE3F1EA),
                child: Text('ع', style: TextStyle(color: okFg, fontWeight: FontWeight.bold))),
            SizedBox(width: 12),
            Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text('عبدالله الحربي', style: bd),
              Text('ثلاجة سامسونج 18 قدم', style: mu),
            ])),
            Pill('متأخر', K.late),
          ]),
          const SizedBox(height: 14),
          Row(children: [
            for (var i = 0; i < 12; i++)
              Expanded(
                  child: Container(
                      height: 8,
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                          color: i < 4
                              ? green
                              : i == 4
                                  ? const Color(0xFFE58A4B)
                                  : const Color(0xFFDDE1DB),
                          borderRadius: BorderRadius.circular(4)))),
          ]),
          const SizedBox(height: 8),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('سُدّد ${money(340000)}', style: mu),
            Text('المتبقي ${money(595000)}', style: mu),
          ]),
        ])),
        two(btn('تسجيل دفعة', () => go(c, const Receipt())),
            btn('إرسال تذكير', () => sb(c, 'تم إرسال التذكير للعميل'), outline: true)),
        btn('طباعة العقد PDF', () => sb(c, 'ربط الطباعة: استخدم حزمتي pdf و printing'), outline: true),
        const SizedBox(height: 10),
        btn('سداد مبكر / إعادة جدولة', () => go(c, const Settlement()), dark: true),
        const SizedBox(height: 16),
        hd('جدول الأقساط'),
        Item('4', 'القسط الرابع', '1 أكتوبر 2026', money(85000), 'مدفوع', K.ok),
        Item('5', 'القسط الخامس', '24 أكتوبر 2026', money(85000), 'متأخر', K.late),
        Item('6', 'القسط السادس', '24 نوفمبر 2026', money(85000), 'قادم', K.neu),
      ]);
}

// ───────────── 4) عقد جديد (مع الضامن) ─────────────
class NewContract extends StatefulWidget {
  const NewContract({super.key});
  @override
  State<NewContract> createState() => _NcS();
}

class _NcS extends State<NewContract> {
  final price = TextEditingController(text: '935000'), down = TextEditingController(text: '100000');
  int ni = 1;
  static const ns = [6, 10, 12, 24];
  @override
  Widget build(BuildContext c) {
    final m = (pv(price.text) - pv(down.text)) / ns[ni];
    return Pg('عقد تقسيط جديد', back: true, [
      fld('العميل', init: 'عبدالله الحربي'),
      fld('السلعة', init: 'ثلاجة سامسونج 18 قدم'),
      Row(children: [
        Expanded(child: fld('السعر الإجمالي', c: price, num: true, f: (_) => setState(() {}))),
        const SizedBox(width: 10),
        Expanded(child: fld('الدفعة المقدمة', c: down, num: true, f: (_) => setState(() {}))),
      ]),
      Row(children: [
        Expanded(flex: 6, child: fld('الضامن (مطلوب)', init: 'محمد إبراهيم')),
        const SizedBox(width: 10),
        Expanded(flex: 5, child: fld('هاتف الضامن', init: '09XX XXX XXX', num: true)),
      ]),
      const Text('عدد الأقساط', style: mu),
      const SizedBox(height: 6),
      seg([for (final n in ns) '$n'], ni, (v) => setState(() => ni = v)),
      dark('القسط الشهري', money(m < 0 ? 0 : m), [
        const SizedBox(height: 6),
        const Text('أول استحقاق بعد 30 يومًا من تاريخ العقد'),
      ]),
      const SizedBox(height: 16),
      btn('إنشاء العقد وإرسال للتوقيع', () {
        sb(c, 'تم إنشاء العقد');
        Navigator.pop(c);
      }),
    ]);
  }
}

// ───────────── 5) حاسبة الأقساط ─────────────
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
    final p = pv(price.text), fin = p * (1 - down), profit = fin * markup / 100;
    final total = fin + profit, monthly = total / ns[ni];
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
        child: DefaultTextStyle(
          style: const TextStyle(color: Colors.white, fontSize: 14),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('القسط الشهري'),
            Text(money(monthly), style: bd.copyWith(fontSize: 32, color: Colors.white)),
            const SizedBox(height: 8),
            for (final r in [['المبلغ الممول', fin], ['الربح', profit], ['إجمالي السداد بعد المقدمة', total]])
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 5),
                  child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text(r[0] as String), Text(money(r[1] as num), style: bd)])),
          ]),
        ),
      ),
      const SizedBox(height: 14),
      two(btn('مشاركة العرض', () => sb(c, 'تمت مشاركة العرض'), outline: true),
          btn('إنشاء عقد', () => go(c, const NewContract()), dark: true)),
    ]);
  }
}

// ───────────── 6) العملاء ─────────────
const _cu = [
  ('ع', 'عبدالله الحربي', 'عقدان نشطان', 1085000, 1, 'متأخر'),
  ('س', 'سارة القحطاني', 'عقد واحد', 496000, 0, 'ملتزمة'),
  ('م', 'محمد العتيبي', '3 عقود', 1240000, 0, 'ملتزم'),
  ('ه', 'هالة بابكر', 'عقد واحد', 310000, 2, 'متوسط'),
  ('أ', 'أحمد النور', 'عقد واحد', 275000, 0, 'ملتزم'),
];
const _ck = [K.ok, K.late, K.neu];

class CustomersScr extends StatefulWidget {
  const CustomersScr({super.key});
  @override
  State<CustomersScr> createState() => _CuS();
}

class _CuS extends State<CustomersScr> {
  String q = '';
  @override
  Widget build(BuildContext c) => Pg('العملاء', [
        fld('ابحث بالاسم أو رقم الهاتف', f: (v) => setState(() => q = v)),
        for (final (a, n, s, r, k, l) in _cu.where((e) => e.$2.contains(q)))
          Item(a, n, s, money(r), l, _ck[k], onTap: () => go(c, CustomerProfile(a, n))),
      ]);
}

// ───────────── 7) ملف العميل ─────────────
class CustomerProfile extends StatelessWidget {
  final String av, name;
  const CustomerProfile(this.av, this.name, {super.key});
  @override
  Widget build(BuildContext c) => Pg('ملف العميل', back: true, [
        Row(children: [
          CircleAvatar(
              radius: 30,
              backgroundColor: green,
              child: Text(av, style: bd.copyWith(color: Colors.white, fontSize: 22))),
          const SizedBox(width: 14),
          Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(name, style: bd.copyWith(fontSize: 18)),
            const Text('09XX XXX XXX', style: mu),
          ]),
        ]),
        const SizedBox(height: 14),
        Row(children: [
          stat('2', 'عقود نشطة'),
          stat('1,085,000', 'المتبقي (ج.س)'),
          stat('78٪', 'نسبة الالتزام', warn: true),
        ]),
        two(btn('اتصال', () => sb(c, 'جارٍ الاتصال...'), outline: true),
            btn('واتساب', () => sb(c, 'فتح واتساب'))),
        hd('العقود'),
        Item('1', '#1042 · ثلاجة سامسونج', 'قسط 5 من 12', money(595000), 'متأخر', K.late,
            onTap: () => go(c, const ContractDetail())),
        Item('2', '#1067 · تلفاز 55 بوصة', 'قسط 3 من 8', money(490000), 'في الموعد', K.ok,
            onTap: () => go(c, const ContractDetail())),
        hd('الضامن'),
        Box(kv('محمد إبراهيم', '09XX XXX XXX', first: true)),
      ]);
}

// ───────────── 8) التقارير ─────────────
class ReportsScr extends StatefulWidget {
  const ReportsScr({super.key});
  @override
  State<ReportsScr> createState() => _RpS();
}

class _RpS extends State<ReportsScr> {
  int p = 1;
  static const h = [50.0, 72.0, 62.0, 84.0, 98.0, 116.0];
  static const m = ['مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر'];
  @override
  Widget build(BuildContext c) => Pg('التقارير', [
        seg(['أسبوع', 'شهر', 'سنة'], p, (v) => setState(() => p = v)),
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(color: green, borderRadius: BorderRadius.circular(22)),
          child: DefaultTextStyle(
            style: const TextStyle(color: Colors.white, fontSize: 13),
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              const Text('إجمالي التحصيل · أكتوبر'),
              Text(money(3090000), style: bd.copyWith(fontSize: 28, color: Colors.white)),
            ]),
          ),
        ),
        const SizedBox(height: 10),
        Row(children: [stat(money(412000), 'الأرباح'), stat(money(1150000), 'المتأخرات', warn: true)]),
        const SizedBox(height: 14),
        Box(SizedBox(
          height: 150,
          child: Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            for (var i = 0; i < 6; i++)
              Expanded(
                  child: Column(mainAxisAlignment: MainAxisAlignment.end, children: [
                Container(
                    height: h[i],
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                        color: i == 5 ? green : const Color(0xFFBFD9CD),
                        borderRadius: BorderRadius.circular(6))),
                const SizedBox(height: 6),
                Text(m[i], style: const TextStyle(fontSize: 11, color: muted)),
              ])),
          ]),
        )),
        hd('أكثر العملاء تأخرًا'),
        Item('ع', 'عبدالله الحربي', 'متأخر 3 أيام', money(85000), 'متأخر', K.late),
        Item('ه', 'هالة بابكر', 'متأخرة يومين', money(48000), 'متأخر', K.late),
      ]);
}

// ───────────── 9) إيصال الدفعة ─────────────
class Receipt extends StatelessWidget {
  const Receipt({super.key});
  @override
  Widget build(BuildContext c) => Pg('إيصال الدفعة', back: true, [
        Box(
            Column(children: [
              const CircleAvatar(
                  radius: 28,
                  backgroundColor: Color(0xFFE3F1EA),
                  child: Icon(Icons.check, color: okFg, size: 30)),
              const SizedBox(height: 10),
              const Text('تم تسجيل الدفعة', style: mu),
              Text(money(85000), style: bd.copyWith(fontSize: 30)),
              const SizedBox(height: 10),
              kv('رقم الإيصال', 'R-2058', first: true),
              kv('العميل', 'عبدالله الحربي'),
              kv('العقد', '#1042 · القسط 5 من 12'),
              kv('التاريخ', '27 أكتوبر 2026'),
              kv('طريقة الدفع', 'تحويل بنكي'),
              kv('المتبقي بعد الدفعة', money(510000)),
            ]),
            pad: 20),
        two(btn('واتساب', () => sb(c, 'مشاركة الإيصال'), outline: true),
            btn('طباعة PDF', () => sb(c, 'ربط الطباعة: pdf + printing'), outline: true)),
        btn('تم', () => Navigator.pop(c), dark: true),
      ]);
}

// ───────────── 10) سداد مبكر وجدولة ─────────────
class Settlement extends StatefulWidget {
  const Settlement({super.key});
  @override
  State<Settlement> createState() => _StS();
}

class _StS extends State<Settlement> {
  int t = 0;
  double months = 10;
  static const rem = 595000;
  @override
  Widget build(BuildContext c) => Pg('سداد مبكر وجدولة', back: true, [
        seg(['سداد مبكر', 'تأجيل قسط', 'إعادة جدولة'], t, (v) => setState(() => t = v)),
        if (t == 0) ...[
          Box(Column(children: [
            kv('المتبقي على العقد', money(rem), first: true),
            kv('خصم السداد المبكر 5٪', '− ${money(rem * .05)}', c: okFg),
            kv('المبلغ المستحق الآن', money(rem * .95)),
          ])),
          const SizedBox(height: 6),
          btn('تسوية العقد', () {
            sb(c, 'تمت تسوية العقد');
            Navigator.pop(c);
          }),
        ],
        if (t == 1) ...[
          const Box(Text('تأجيل القسط السادس (24 نوفمبر 2026) إلى نهاية الجدول، وتمتد مدة العقد شهرًا إضافيًا.')),
          btn('تأكيد التأجيل', () => sb(c, 'تم تأجيل القسط')),
        ],
        if (t == 2)
          Box(Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('مدّ المتبقي ${money(rem)} على ${months.round()} شهرًا', style: bd),
            Slider(value: months, min: 7, max: 24, divisions: 17, onChanged: (v) => setState(() => months = v)),
            Text('القسط الجديد: ${money(rem / months.round())}', style: bd.copyWith(color: green, fontSize: 18)),
            const SizedBox(height: 12),
            btn('تعديل الجدول', () => sb(c, 'تم تعديل الجدول'), outline: true),
          ])),
      ]);
}

// ───────────── 11) الإعدادات ─────────────
class SettingsScr extends StatefulWidget {
  const SettingsScr({super.key});
  @override
  State<SettingsScr> createState() => _SeS();
}

class _SeS extends State<SettingsScr> {
  bool remind = true, wa = true, late = false, darkMode = false, bio = true;
  Widget link(String l, String v) => ListTile(
      title: Text(l),
      trailing: Row(mainAxisSize: MainAxisSize.min, children: [
        Text(v, style: mu),
        const Icon(Icons.chevron_left, color: muted),
      ]));
  Widget sw(String l, bool v, ValueChanged<bool> f) =>
      SwitchListTile(title: Text(l), value: v, onChanged: f, activeColor: green);
  Widget sec(String t, List<Widget> c) => Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Padding(
            padding: const EdgeInsets.fromLTRB(4, 14, 4, 8),
            child: Text(t, style: bd.copyWith(fontSize: 13, color: muted))),
        Box(Column(children: c), pad: 0),
      ]);
  @override
  Widget build(BuildContext c) => Pg('الإعدادات', [
        Box(const Row(children: [
          CircleAvatar(radius: 26, backgroundColor: green,
              child: Text('أ', style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold))),
          SizedBox(width: 12),
          Expanded(
              child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('معرض الأمل للأجهزة', style: bd),
            Text('الخطة الاحترافية · 3 مستخدمين', style: mu),
          ])),
          Icon(Icons.chevron_left, color: muted),
        ])),
        sec('التحصيل والأقساط', [
          link('العملة', 'جنيه سوداني'),
          link('فترة السماح', '3 أيام'),
          link('غرامة التأخير', money(5000)),
        ]),
        sec('التنبيهات', [
          sw('تذكير قبل الاستحقاق', remind, (v) => setState(() => remind = v)),
          sw('رسائل واتساب للعملاء', wa, (v) => setState(() => wa = v)),
          sw('تنبيه الأقساط المتأخرة', late, (v) => setState(() => late = v)),
        ]),
        sec('المظهر والأمان', [
          link('اللغة', 'العربية'),
          sw('الوضع الداكن', darkMode, (v) => setState(() => darkMode = v)),
          sw('الدخول بالبصمة', bio, (v) => setState(() => bio = v)),
          link('النسخ الاحتياطي', 'أمس 11:40 م'),
        ]),
        Center(
            child: TextButton(
                onPressed: () => sb(c, 'تم تسجيل الخروج'),
                child: const Text('تسجيل الخروج', style: TextStyle(color: Color(0xFF9A3412), fontWeight: FontWeight.bold)))),
      ]);
}
