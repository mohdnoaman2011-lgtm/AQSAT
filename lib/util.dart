import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:url_launcher/url_launcher.dart';
import 'db.dart';

String money(num n) =>
    '${n.round().toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (m) => ',')} ج.س';
num pv(String s) => num.tryParse(s.replaceAll(',', '').trim()) ?? 0;
String nf(double v) => v % 1 == 0 ? v.toInt().toString() : v.toString();

String _digits(String p) => p.replaceAll(RegExp(r'\D'), '');
String _intl(String p) {
  var d = _digits(p);
  if (d.startsWith('00')) {
    d = d.substring(2);
  } else if (d.startsWith('0')) {
    d = db.gs('cc') + d.substring(1);
  }
  return d;
}

Future<void> openWa(String phone, String msg) async {
  await launchUrl(Uri.parse('https://wa.me/${_intl(phone)}?text=${Uri.encodeComponent(msg)}'),
      mode: LaunchMode.externalApplication);
}

Future<void> callPhone(String phone) async {
  await launchUrl(Uri.parse('tel:${_digits(phone)}'));
}

/// يطبع/يشارك مستند PDF عربي (عقد أو إيصال).
/// ملاحظة: الجداول في مكتبة pdf لا تنعكس تلقائيًا في العربية، لذلك تُعكس الأعمدة يدويًا.
Future<void> printDoc(String name, String title, List<List<String>> rows,
    {List<String>? head, List<List<String>>? table, bool sign = false, List<String>? big}) async {
  final doc = pw.Document(
      theme: pw.ThemeData.withFont(base: await PdfGoogleFonts.cairoRegular(), bold: await PdfGoogleFonts.cairoBold()));
  const grey = PdfColor.fromInt(0xFFF1F6F9), bord = PdfColor.fromInt(0xFFCBD9E0), green = PdfColor.fromInt(0xFF112C4E);
  pw.Widget cell(String t, {bool bold = false, PdfColor? bg}) => pw.Container(
      color: bg,
      padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      child: pw.Text(t, textAlign: pw.TextAlign.right, style: pw.TextStyle(fontSize: 12, fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal)));
  pw.Widget sig(String l) => pw.Column(children: [pw.Container(width: 150, height: 1, color: PdfColors.black), pw.SizedBox(height: 5), pw.Text(l, style: const pw.TextStyle(fontSize: 11))]);
  doc.addPage(pw.MultiPage(
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => [
      pw.Center(child: pw.Text(db.gs('company'), style: pw.TextStyle(fontSize: 22, fontWeight: pw.FontWeight.bold, color: green))),
      pw.SizedBox(height: 4),
      pw.Center(child: pw.Text(title, style: const pw.TextStyle(fontSize: 14, color: PdfColors.grey700))),
      pw.SizedBox(height: 10),
      pw.Divider(color: green, thickness: 1.5),
      pw.SizedBox(height: 10),
      if (big != null)
        pw.Container(
          width: double.infinity,
          margin: const pw.EdgeInsets.only(bottom: 14),
          padding: const pw.EdgeInsets.all(14),
          decoration: pw.BoxDecoration(color: grey, border: pw.Border.all(color: bord), borderRadius: pw.BorderRadius.circular(8)),
          child: pw.Column(children: [
            pw.Text(big[0], style: const pw.TextStyle(fontSize: 12, color: PdfColors.grey700)),
            pw.SizedBox(height: 4),
            pw.Text(big[1], style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold, color: green)),
          ]),
        ),
      // عمود القيمة أولًا ثم العنوان ليظهر العنوان على اليمين
      pw.Table(
        border: pw.TableBorder.all(color: bord),
        columnWidths: {0: const pw.FlexColumnWidth(), 1: const pw.FixedColumnWidth(130)},
        children: [for (final r in rows) pw.TableRow(children: [cell(r[1]), cell(r[0], bold: true, bg: grey)])],
      ),
      if (table != null) ...[
        pw.SizedBox(height: 18),
        pw.TableHelper.fromTextArray(
          headers: head!.reversed.toList(),
          data: [for (final r in table) r.reversed.toList()],
          border: pw.TableBorder.all(color: bord),
          headerStyle: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          headerDecoration: const pw.BoxDecoration(color: grey),
          cellStyle: const pw.TextStyle(fontSize: 11),
          cellAlignment: pw.Alignment.center,
          headerAlignment: pw.Alignment.center,
          columnWidths: {0: const pw.FlexColumnWidth(2), 1: const pw.FlexColumnWidth(3), 2: const pw.FlexColumnWidth(3), 3: const pw.FixedColumnWidth(36)},
        ),
      ],
      if (sign) ...[
        pw.SizedBox(height: 70),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [sig('توقيع البائع'), sig('توقيع العميل')]),
      ],
    ],
  ));
  await Printing.layoutPdf(onLayout: (_) => doc.save(), name: name);
}

/// حفظ نسخة احتياطية (ملف JSON) في مكان تختاره على الجهاز.
Future<String> backupFile() async {
  final n = today();
  final name = 'aqsat-backup-${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}.json';
  final p = await FilePicker.saveFile(
      dialogTitle: 'حفظ النسخة الاحتياطية', fileName: name, bytes: Uint8List.fromList(utf8.encode(db.export())));
  return p == null ? 'لم يتم الحفظ' : 'تم حفظ النسخة الاحتياطية';
}

/// استعادة البيانات من ملف نسخة احتياطية على الجهاز.
Future<String> restoreFile() async {
  final f = await FilePicker.pickFile();
  if (f == null) return 'لم يتم اختيار ملف';
  try {
    db.restore(utf8.decode(await f.readAsBytes()));
    return 'تمت استعادة البيانات';
  } catch (_) {
    return 'الملف ليس نسخة احتياطية صالحة';
  }
}

// ───────── النسخ الاحتياطي التلقائي الأسبوعي ─────────
// تُحفظ النسخ داخل مجلد التطبيق (آخر 4 نسخ). تُؤخذ نسخة عند فتح التطبيق أو تركه
// إذا مضى 7 أيام أو أكثر على آخر نسخة. لحمايتها من فقدان الجوال صدّر نسخة إلى الجهاز.
class AutoBackup {
  final String path, label;
  AutoBackup(this.path, this.label);
}

Future<Directory> _bdir() async {
  final d = Directory('${(await getApplicationDocumentsDirectory()).path}/backups');
  if (!await d.exists()) await d.create(recursive: true);
  return d;
}

String _alabel(String p) {
  final m = RegExp(r'auto-(\d{4})(\d{2})(\d{2})').firstMatch(p)!;
  return dstr(DateTime(int.parse(m[1]!), int.parse(m[2]!), int.parse(m[3]!)));
}

Future<List<AutoBackup>> listAutoBackups() async {
  final d = await _bdir();
  final fs = <File>[
    for (final e in await d.list().toList())
      if (e is File && RegExp(r'auto-\d{8}\.json$').hasMatch(e.path)) e
  ]..sort((a, b) => b.path.compareTo(a.path));
  return [for (final f in fs) AutoBackup(f.path, _alabel(f.path))];
}

/// يحفظ نسخة الآن ويُبقي آخر 4 نسخ فقط. يرجع true عند النجاح.
Future<bool> runAutoBackup() async {
  try {
    final d = await _bdir(), n = today();
    final name = 'auto-${n.year}${n.month.toString().padLeft(2, '0')}${n.day.toString().padLeft(2, '0')}.json';
    await File('${d.path}/$name').writeAsString(db.export());
    db.setv('lastAuto', DateTime.now().millisecondsSinceEpoch);
    for (final b in (await listAutoBackups()).skip(4)) {
      await File(b.path).delete();
    }
    return true;
  } catch (_) {
    return false;
  }
}

Future<void> autoBackupIfDue() async {
  if (!db.autoBackup || (db.custs.isEmpty && db.cons.isEmpty)) return;
  final l = db.lastAuto;
  if (l != null && DateTime.now().difference(l).inDays < 7) return;
  await runAutoBackup();
}

Future<String> exportLastAuto() async {
  final l = await listAutoBackups();
  if (l.isEmpty) return 'لا توجد نسخ تلقائية بعد';
  final p = await FilePicker.saveFile(dialogTitle: 'تصدير النسخة', fileName: l.first.path.split('/').last, bytes: await File(l.first.path).readAsBytes());
  return p == null ? 'لم يتم الحفظ' : 'تم تصدير النسخة إلى الجهاز';
}

Future<String> restoreAutoFile(String path) async {
  try {
    db.restore(await File(path).readAsString());
    return 'تمت استعادة البيانات';
  } catch (_) {
    return 'تعذّرت الاستعادة';
  }
}
