import 'dart:convert';
import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
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
Future<void> printDoc(String name, String title, List<List<String>> rows,
    {List<String>? head, List<List<String>>? table, bool sign = false}) async {
  final doc = pw.Document(
      theme: pw.ThemeData.withFont(
          base: await PdfGoogleFonts.notoSansArabicRegular(),
          bold: await PdfGoogleFonts.notoSansArabicBold()));
  doc.addPage(pw.MultiPage(
    textDirection: pw.TextDirection.rtl,
    margin: const pw.EdgeInsets.all(36),
    build: (_) => [
      pw.Center(child: pw.Text(db.gs('company'), style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold))),
      pw.SizedBox(height: 6),
      pw.Center(child: pw.Text(title, style: const pw.TextStyle(fontSize: 15))),
      pw.SizedBox(height: 18),
      for (final r in rows)
        pw.Padding(
            padding: const pw.EdgeInsets.symmetric(vertical: 3),
            child: pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [pw.Text(r[0]), pw.Text(r[1])])),
      if (table != null) ...[
        pw.SizedBox(height: 14),
        pw.TableHelper.fromTextArray(headers: head, data: table),
      ],
      if (sign) ...[
        pw.SizedBox(height: 50),
        pw.Row(mainAxisAlignment: pw.MainAxisAlignment.spaceBetween, children: [
          pw.Text('توقيع البائع: ________'),
          pw.Text('توقيع العميل: ________'),
        ]),
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
