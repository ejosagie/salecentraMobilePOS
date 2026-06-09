import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/invoice.dart';
import '../models/user.dart';

class PdfService {
  static pw.Font? _notoFont;

  static Future<void> _loadFont() async {
    if (_notoFont != null) return;
    final fontData = await rootBundle.load('assets/fonts/NotoSans-Regular.ttf');
    _notoFont = pw.Font.ttf(fontData);
  }

  static pw.Widget? _buildLogo(User user) {
    if (user.logoBase64 == null || user.logoBase64!.isEmpty) return null;
    try {
      final bytes = Uint8List.fromList(base64Decode(user.logoBase64!));
      final image = pw.MemoryImage(bytes);
      return pw.Center(
        child: pw.Image(image, width: 80, height: 80, fit: pw.BoxFit.contain),
      );
    } catch (e) {
      return null;
    }
  }

  static Future<void> generateAndShareReceipt(Sale sale, User user) async {
    await _loadFont();
    final subtotal = sale.price * sale.quantity;
    final discount = subtotal - sale.total;
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _notoFont!,
        bold: _notoFont!,
        italic: _notoFont!,
        boldItalic: _notoFont!,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_buildLogo(user) != null) ...[
                _buildLogo(user)!,
                pw.SizedBox(height: 10),
              ],
              pw.Center(
                child: pw.Text(
                  'SALECENTRA POS RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2563EB'),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Smart Sales Made Simple',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              if (user.phoneNumber.isNotEmpty)
                pw.Text(user.phoneNumber, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
              if (user.businessAddress.isNotEmpty)
                pw.Text(user.businessAddress, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(sale.date)}'),
                  pw.Text('Receipt #: ${sale.id.substring(0, 8).toUpperCase()}'),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Text(
                'Item: ${sale.item}',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Quantity: ${sale.quantity}'),
                  pw.Text('Price: ${user.currencySymbol}${sale.price.toStringAsFixed(2)}'),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 10),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Subtotal:'),
                    pw.Text('${user.currencySymbol}${subtotal.toStringAsFixed(2)}'),
                  ],
                ),
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text('Discount:'),
                    pw.Text('-${user.currencySymbol}${discount.toStringAsFixed(2)}'),
                  ],
                ),
              ],
              pw.SizedBox(height: 10),
              pw.Divider(),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'TOTAL',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                  pw.Text(
                    '${user.currencySymbol}${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#64748B')),
                ),
              ),
              if (sale.enteredByStaffName != null) ...[
                pw.SizedBox(height: 6),
                pw.Center(
                  child: pw.Text(
                    'Sold by: ${sale.enteredByStaffName}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                  ),
                ),
              ],
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Generated with SaleCentra',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Powered by SaleCentra — Smart Sales, Simple Life',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'Receipt_${sale.id.substring(0, 8)}');
  }

  static Future<void> generateAndShareGroupedReceipt({
    required String receiptId,
    required DateTime date,
    required List<CartItem> items,
    required User user,
    String? enteredByStaffName,
  }) async {
    await _loadFont();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _notoFont!,
        bold: _notoFont!,
        italic: _notoFont!,
        boldItalic: _notoFont!,
      ),
    );
    final total = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return [
            if (_buildLogo(user) != null) ...[
              _buildLogo(user)!,
              pw.SizedBox(height: 10),
            ],
            pw.Center(
              child: pw.Text(
                'SALECENTRA POS RECEIPT',
                style: pw.TextStyle(
                  fontSize: 14,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                ),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Smart Sales Made Simple',
                style: pw.TextStyle(
                  fontSize: 10,
                  color: PdfColor.fromHex('#64748B'),
                ),
              ),
            ),
            pw.SizedBox(height: 16),
            pw.Text(
              user.businessName,
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
            ),
            if (user.phoneNumber.isNotEmpty)
              pw.Text(user.phoneNumber, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
            if (user.businessAddress.isNotEmpty)
              pw.Text(user.businessAddress, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Date: ${DateFormat('yyyy-MM-dd HH:mm').format(date)}'),
                pw.Text('Receipt #: ${receiptId.substring(0, 8).toUpperCase()}'),
              ],
            ),
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(2.6),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.4),
                3: const pw.FlexColumnWidth(1.4),
                4: const pw.FlexColumnWidth(1.6),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#EFF6FF')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold)),
                    ),
                  ],
                ),
                ...items.map(
                  (item) => pw.TableRow(
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item.itemName),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text(item.quantity.toString()),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${user.currencySymbol}${item.unitPrice.toStringAsFixed(2)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${user.currencySymbol}${item.discount.toStringAsFixed(2)}'),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(6),
                        child: pw.Text('${user.currencySymbol}${item.totalPrice.toStringAsFixed(2)}'),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 10),
            pw.Divider(),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${user.currencySymbol}${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 18,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 24),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#64748B')),
              ),
            ),
            if (enteredByStaffName != null) ...[
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Sold by: $enteredByStaffName',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#64748B')),
                ),
              ),
            ],
            pw.SizedBox(height: 16),
            pw.Center(
              child: pw.Text(
                'Generated with SaleCentra',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Powered by SaleCentra — Smart Sales, Simple Life',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
          ];
        },
      ),
    );

    await _sharePdf(pdf, 'Receipt_${receiptId.substring(0, 8)}');
  }

  static Future<void> generateAndShareInvoice(Invoice invoice, User user) async {
    await _loadFont();
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _notoFont!,
        bold: _notoFont!,
        italic: _notoFont!,
        boldItalic: _notoFont!,
      ),
    );

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (_buildLogo(user) != null) ...[
                _buildLogo(user)!,
                pw.SizedBox(height: 10),
              ],
              pw.Center(
                child: pw.Text(
                  'SALECENTRA INVOICE',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2563EB'),
                  ),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Smart Sales Made Simple',
                  style: pw.TextStyle(
                    fontSize: 10,
                    color: PdfColor.fromHex('#64748B'),
                  ),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
              if (user.phoneNumber.isNotEmpty)
                pw.Text(user.phoneNumber, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
              if (user.businessAddress.isNotEmpty)
                pw.Text(user.businessAddress, style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569'))),
              pw.SizedBox(height: 16),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Invoice #: ${invoice.id.substring(0, 8).toUpperCase()}'),
                  pw.Text('Status: ${invoice.status.toUpperCase()}'),
                ],
              ),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('Date: ${DateFormat('yyyy-MM-dd').format(invoice.date)}'),
                  if (invoice.dueDate != null)
                    pw.Text('Due: ${DateFormat('yyyy-MM-dd').format(invoice.dueDate!)}'),
                ],
              ),
              pw.SizedBox(height: 20),
              pw.Divider(),
              pw.SizedBox(height: 10),
              pw.Text(
                'TOTAL AMOUNT',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.SizedBox(height: 5),
              pw.Text(
                '${user.currencySymbol}${invoice.total.toStringAsFixed(2)}',
                style: pw.TextStyle(
                  fontSize: 24,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              if (invoice.notes != null) ...[
                pw.SizedBox(height: 20),
                pw.Text(
                  'Notes:',
                  style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                ),
                pw.SizedBox(height: 5),
                pw.Text(invoice.notes!),
              ],
              pw.SizedBox(height: 24),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 12, color: PdfColor.fromHex('#64748B')),
                ),
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Generated with SaleCentra',
                  style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#64748B')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Powered by SaleCentra — Smart Sales, Simple Life',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'Invoice_${invoice.id.substring(0, 8)}');
  }

  static Future<void> _sharePdf(pw.Document pdf, String fileName) async {
    final output = await getTemporaryDirectory();
    final file = File('${output.path}/$fileName.pdf');
    await file.writeAsBytes(await pdf.save());

    await Share.shareXFiles(
      [XFile(file.path)],
      subject: 'SaleCentra Document',
      text: 'Please find the attached document from SaleCentra.',
      sharePositionOrigin: const Rect.fromLTWH(0, 0, 1, 1),
    );
  }
}
