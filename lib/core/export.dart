import 'dart:typed_data';
import 'package:excel/excel.dart';
import 'package:flutter/material.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';

typedef TableData = ({String title, List<String> cols, List<List<String>> rows});

/// Builds an Excel or PDF file in memory and opens the system share sheet (save to Files, WhatsApp, mail…).
Future<void> shareTable(TableData t, {required bool pdf}) async {
  final Uint8List bytes;
  if (pdf) {
    final doc = pw.Document();
    doc.addPage(pw.MultiPage(build: (_) => [
          pw.Text('Skylyf - ${t.title}', style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold)),
          pw.SizedBox(height: 4),
          pw.Text('Generated ${DateTime.now().toString().substring(0, 16)}', style: const pw.TextStyle(fontSize: 9)),
          pw.SizedBox(height: 12),
          pw.TableHelper.fromTextArray(headers: t.cols, data: t.rows, cellStyle: const pw.TextStyle(fontSize: 9)),
        ]));
    bytes = await doc.save();
  } else {
    final book = Excel.createExcel();
    final sheet = book[book.getDefaultSheet()!];
    sheet.appendRow([for (final c in t.cols) TextCellValue(c)]);
    for (final r in t.rows) {
      sheet.appendRow([for (final v in r) TextCellValue(v)]);
    }
    bytes = Uint8List.fromList(book.save()!);
  }
  final name = 'skylyf-${t.title.toLowerCase().replaceAll(RegExp(r'[^a-z0-9]+'), '-')}.${pdf ? 'pdf' : 'xlsx'}';
  await SharePlus.instance.share(ShareParams(
    files: [XFile.fromData(bytes, mimeType: pdf ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet')],
    fileNameOverrides: [name],
  ));
}

/// App-bar style menu: Export as Excel / PDF. `table` is built lazily on tap.
class ExportButton extends StatelessWidget {
  const ExportButton(this.table, {super.key});
  final TableData Function() table;

  @override
  Widget build(BuildContext context) => PopupMenuButton<bool>(
        tooltip: 'Export',
        icon: const Icon(LucideIcons.download),
        onSelected: (pdf) async {
          try {
            await shareTable(table(), pdf: pdf);
          } catch (e) {
            if (context.mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Export failed: $e')));
          }
        },
        itemBuilder: (_) => const [
          PopupMenuItem(value: false, child: ListTile(leading: Icon(LucideIcons.fileSpreadsheet), title: Text('Excel (.xlsx)'), contentPadding: EdgeInsets.zero)),
          PopupMenuItem(value: true, child: ListTile(leading: Icon(LucideIcons.fileText), title: Text('PDF'), contentPadding: EdgeInsets.zero)),
        ],
      );
}
