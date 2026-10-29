import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

DateTime today() {
  final n = DateTime.now();
  return DateTime(n.year, n.month, n.day);
}

DateTime addMonths(DateTime d, int m) {
  final t = d.month - 1 + m, y = d.year + (t / 12).floor(), mo = t % 12 + 1;
  final last = DateTime(y, mo + 1, 0).day;
  return DateTime(y, mo, d.day > last ? last : d.day);
}

const months = ['يناير', 'فبراير', 'مارس', 'أبريل', 'مايو', 'يونيو', 'يوليو', 'أغسطس', 'سبتمبر', 'أكتوبر', 'نوفمبر', 'ديسمبر'];
String dstr(DateTime d) => '${d.day} ${months[d.month - 1]} ${d.year}';

class Cust {
  final String id;
  String name, phone;
  Cust(this.id, this.name, this.phone);
  Map<String, dynamic> j() => {'id': id, 'name': name, 'phone': phone};
  factory Cust.f(Map m) => Cust(m['id'], m['name'], m['phone']);
}

class Inst {
  DateTime due;
  double amt, fee = 0, left = 0;
  DateTime? paid;
  String? method, rcpt;
  Inst(this.due, this.amt);
  bool get isPaid => paid != null;
  int get lateDays {
    if (isPaid) return 0;
    final d = today().difference(due).inDays;
    return d > 0 ? d : 0;
  }

  Map<String, dynamic> j() => {'due': due.toIso8601String(), 'amt': amt, 'paid': paid?.toIso8601String(), 'method': method, 'rcpt': rcpt, 'fee': fee, 'left': left};
  factory Inst.f(Map m) {
    final i = Inst(DateTime.parse(m['due']), (m['amt'] as num).toDouble());
    i.paid = m['paid'] == null ? null : DateTime.parse(m['paid']);
    i.method = m['method'];
    i.rcpt = m['rcpt'];
    i.fee = (m['fee'] as num).toDouble();
    i.left = (m['left'] as num).toDouble();
    return i;
  }
}

class Contract {
  final String id, cid, item;
  final double price, down, markup;
  final DateTime date;
  final List<Inst> insts;
  Contract({required this.id, required this.cid, required this.item, required this.price, required this.down, required this.markup, required this.date, required this.insts});
  int get paidCount => insts.where((i) => i.isPaid).length;
  double get remaining => insts.where((i) => !i.isPaid).fold(0.0, (s, i) => s + i.amt);
  Inst? get next => insts.where((i) => !i.isPaid).firstOrNull;
  // 0 نشط · 1 متأخر · 2 مكتمل
  int get st => next == null ? 2 : (insts.any((i) => i.lateDays > 0) ? 1 : 0);
  Map<String, dynamic> j() => {'id': id, 'cid': cid, 'item': item, 'price': price, 'down': down, 'markup': markup, 'date': date.toIso8601String(), 'insts': [for (final i in insts) i.j()]};
  factory Contract.f(Map m) => Contract(id: m['id'], cid: m['cid'], item: m['item'], price: (m['price'] as num).toDouble(), down: (m['down'] as num).toDouble(), markup: (m['markup'] as num).toDouble(), date: DateTime.parse(m['date']), insts: [for (final x in m['insts']) Inst.f(x)]);
}

class Db extends ChangeNotifier {
  List<Cust> custs = [];
  List<Contract> cons = [];
  int seq = 1000;
  Map<String, dynamic> cfg = {'company': 'اسم المنشأة', 'grace': 3, 'fee': 0, 'disc': 5, 'cc': '249'};
  SharedPreferences? _p;

  int gi(String k) => (cfg[k] as num).toInt();
  double gn(String k) => (cfg[k] as num).toDouble();
  String gs(String k) => cfg[k].toString();
  Cust? cust(String id) => custs.where((c) => c.id == id).firstOrNull;
  static String _norm(String s) => s.trim().replaceAll(RegExp(r'\s+'), ' ');
  Cust? byName(String n) => custs.where((c) => _norm(c.name) == _norm(n)).firstOrNull;
  Contract? con(String id) => cons.where((k) => k.id == id).firstOrNull;
  List<(Contract, Inst)> get all => [for (final k in cons) for (final i in k.insts) (k, i)];

  Future<void> load() async {
    _p = await SharedPreferences.getInstance();
    final s = _p!.getString('db');
    if (s != null) {
      try {
        _in(s);
      } catch (_) {}
    }
  }

  void _in(String s) {
    final m = jsonDecode(s);
    final cu = [for (final x in m['custs']) Cust.f(x)];
    final co = [for (final x in m['cons']) Contract.f(x)];
    final cf = Map<String, dynamic>.from(m['cfg']);
    custs = cu;
    cons = co;
    cfg = {...cfg, ...cf};
    seq = m['seq'];
  }

  String export() => jsonEncode({'custs': [for (final c in custs) c.j()], 'cons': [for (final k in cons) k.j()], 'seq': seq, 'cfg': cfg});
  void _save() {
    _p?.setString('db', export());
    notifyListeners();
  }

  void restore(String s) {
    _in(s);
    _save();
  }

  void reset() {
    custs = [];
    cons = [];
    seq = 1000;
    _save();
  }

  void setv(String k, dynamic v) {
    cfg[k] = v;
    _save();
  }

  Cust addCust(String name, String phone) {
    final c = Cust('c${DateTime.now().microsecondsSinceEpoch}', name.trim(), phone.trim());
    custs.add(c);
    _save();
    return c;
  }

  Contract create({required String name, required String phone, required String item, required double price, required double down, required double markup, required int n, DateTime? date}) {
    final c = byName(name) ?? addCust(name, phone);
    final a = (price - down) * (1 + markup / 100) / n, t = date ?? today();
    final k = Contract(id: '${++seq}', cid: c.id, item: item.trim(), price: price, down: down, markup: markup, date: t, insts: [for (var i = 1; i <= n; i++) Inst(addMonths(t, i), a)]);
    cons.insert(0, k);
    _save();
    return k;
  }

  /// تسجيل دفعة للقسط التالي. تُضاف غرامة التأخير إن تجاوز فترة السماح.
  Inst? pay(Contract k, String method) {
    final i = k.next;
    if (i == null) return null;
    i.fee = i.lateDays > gi('grace') ? gn('fee') : 0;
    i.paid = DateTime.now();
    i.method = method;
    i.rcpt = 'R-${k.id}-${k.paidCount}';
    i.left = k.remaining;
    _save();
    return i;
  }

  /// سداد جزئي: يغطي الأقساط بالترتيب، وما يتبقى من المبلغ يُخصم من القسط التالي
  /// (يُقسَّم إلى جزء مدفوع وجزء متبقٍ بنفس تاريخ الاستحقاق).
  Inst? payPartial(Contract k, double amount, String method) {
    var a = amount;
    final done = <Inst>[];
    void mark(Inst i) {
      i.paid = DateTime.now();
      i.method = method;
      i.rcpt = 'R-${k.id}-${k.paidCount}';
      done.add(i);
    }

    while (a > 0.5) {
      final i = k.next;
      if (i == null) break;
      if (a >= i.amt - 0.5) {
        a -= i.amt;
        mark(i);
      } else {
        final part = Inst(i.due, a);
        k.insts.insert(k.insts.indexOf(i), part);
        i.amt -= a;
        a = 0;
        mark(part);
      }
    }
    for (final i in done) {
      i.left = k.remaining;
    }
    _save();
    return done.isEmpty ? null : done.last;
  }

  double settleDue(Contract k) => k.remaining * (1 - gn('disc') / 100);

  void settle(Contract k) {
    final f = 1 - gn('disc') / 100, now = DateTime.now();
    for (final i in k.insts.where((i) => !i.isPaid)) {
      i.amt *= f;
      i.paid = now;
      i.method = 'سداد مبكر';
      i.rcpt = 'R-${k.id}-S';
      i.left = 0;
    }
    _save();
  }

  void postpone(Contract k) {
    final i = k.next;
    if (i == null) return;
    k.insts.remove(i);
    i.due = addMonths(k.insts.isEmpty ? today() : k.insts.last.due, 1);
    k.insts.add(i);
    _save();
  }

  void resched(Contract k, int n) {
    final un = k.insts.where((i) => !i.isPaid).toList();
    if (un.isEmpty) return;
    final rem = k.remaining, s = un.first.due.isBefore(today()) ? today() : un.first.due;
    k.insts.removeWhere((i) => !i.isPaid);
    for (var j = 0; j < n; j++) {
      k.insts.add(Inst(addMonths(s, j), rem / n));
    }
    _save();
  }

}

final db = Db();
