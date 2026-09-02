import 'dart:convert';
import 'dart:io';
import 'package:flutter/services.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/invoice.dart';
import '../models/user.dart';

class PdfService {
  static pw.Font? _notoFont;

  // Thermal printer page format (58mm roll, ~164pt wide, 200mm tall)
  // Using this instead of A4 prevents tiny text when the PrintService
  // scales the PDF down to 384 dots for a 58mm thermal printer.
  static final PdfPageFormat thermal58 = PdfPageFormat(
    58 * 72 / 25.4,       // width: ~164pt (58mm)
    200 * 72 / 25.4,      // height: ~567pt (200mm roll)
    marginAll: 4 * 72 / 25.4,  // ~11pt margins (4mm)
  );

  // 80mm thermal printer page format (~227pt wide)
  static final PdfPageFormat thermal80 = PdfPageFormat(
    80 * 72 / 25.4,       // width: ~227pt (80mm)
    200 * 72 / 25.4,      // height: ~567pt (200mm roll)
    marginAll: 4 * 72 / 25.4,  // ~11pt margins (4mm)
  );

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
    final discount = sale.discount;
    final logo = _buildLogo(user);
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
        pageFormat: thermal58,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business header â€” logo + name + contact
              if (logo != null) ...[logo, pw.SizedBox(height: 10)],
              pw.Center(
                child: pw.Text(
                  user.businessName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (user.phoneNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.phoneNumber,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              if (user.businessAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.businessAddress,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2563EB'),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(sale.date)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                  pw.Text(
                    'Receipt #: ${sale.id.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 6),
              pw.Text(
                sale.item,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${sale.quantity} x ${user.currencySymbol}${sale.price.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                  ),
                  pw.Text(
                    '${user.currencySymbol}${subtotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  '  Discount: -${user.currencySymbol}${discount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#D97706')),
                ),
              ],
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${user.currencySymbol}${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
                  'Powered by SaleCentra',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'SMART. SIMPLE. COMPLETE',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Visit www.salecentra.com',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'Receipt_${sale.id.substring(0, 8)}');
  }

  static Future<void> printThermalReceipt(Sale sale, User user) async {
    await _loadFont();
    final subtotal = sale.price * sale.quantity;
    final discount = sale.discount;
    final logo = _buildLogo(user);
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
        pageFormat: thermal58,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              if (logo != null) ...[logo, pw.SizedBox(height: 10)],
              pw.Center(
                child: pw.Text(
                  user.businessName,
                  style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (user.phoneNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.phoneNumber,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              if (user.businessAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.businessAddress,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'SALES RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2563EB'),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(sale.date)}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                  pw.Text(
                    'Receipt #: ${sale.id.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ],
              ),
              pw.SizedBox(height: 12),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 6),
              pw.Text(
                sale.item,
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold, fontSize: 10),
              ),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    '${sale.quantity} x ${user.currencySymbol}${sale.price.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                  ),
                  pw.Text(
                    '${user.currencySymbol}${subtotal.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                ],
              ),
              if (discount > 0) ...[
                pw.SizedBox(height: 2),
                pw.Text(
                  '  Discount: -${user.currencySymbol}${discount.toStringAsFixed(2)}',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#D97706')),
                ),
              ],
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 10),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text('TOTAL', style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold)),
                  pw.Text(
                    '${user.currencySymbol}${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(fontSize: 14, fontWeight: pw.FontWeight.bold),
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
                  'Powered by SaleCentra',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'SMART. SIMPLE. COMPLETE',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Visit www.salecentra.com',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
            ],
          );
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Receipt_${sale.id.substring(0, 8)}',
      onLayout: (format) => pdf.save(),
    );
  }

  static Future<void> generateAndShareRichReceiptFromSale(Sale sale, User user) async {
    await _loadFont();
    final subtotal = sale.price * sale.quantity;
    final discount = sale.discount;
    final logo = _buildLogo(user);
    final pdf = pw.Document(
      theme: pw.ThemeData.withFont(
        base: _notoFont!,
        bold: _notoFont!,
        italic: _notoFont!,
        boldItalic: _notoFont!,
      ),
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            if (logo != null) ...[logo, pw.SizedBox(height: 10)],
            pw.Center(
              child: pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (user.phoneNumber.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.phoneNumber,
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ),
            if (user.businessAddress.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.businessAddress,
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Receipt #: ${sale.id.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(sale.date)}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ],
            ),
            if (sale.enteredByStaffName != null && sale.enteredByStaffName!.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Staff: ${sale.enteredByStaffName}',
                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2563EB')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11))),
                  ],
                ),
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#F8FAFC')),
                  children: [
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(sale.item, style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text(sale.quantity.toString(), style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${user.currencySymbol}${sale.price.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${user.currencySymbol}${discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11))),
                    pw.Padding(padding: const pw.EdgeInsets.all(8), child: pw.Text('${user.currencySymbol}${sale.total.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold))),
                  ],
                ),
              ],
            ),
            pw.SizedBox(height: 16),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569'))),
                          pw.Text('${user.currencySymbol}${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      if (discount > 0) ...[
                        pw.Row(
                          mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                          children: [
                            pw.Text('Discount:', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#D97706'))),
                            pw.Text('-${user.currencySymbol}${discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#D97706'))),
                          ],
                        ),
                        pw.SizedBox(height: 4),
                      ],
                      pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            '${user.currencySymbol}${sale.total.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontSize: 13, color: PdfColor.fromHex('#64748B')),
              ),
            ),
            if (sale.enteredByStaffName != null) ...[
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Sold by: ${sale.enteredByStaffName}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B')),
                ),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Powered by SaleCentra',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'SMART. SIMPLE. COMPLETE',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Visit www.salecentra.com',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
          ];
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
    String? customerName,
    String? customerPhone,
    String? customerAddress,
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

    final logo = _buildLogo(user);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: thermal58,
        build: (pw.Context context) {
          return [
            // Business header â€” logo + name + contact
            if (logo != null) ...[logo, pw.SizedBox(height: 10)],
            pw.Center(
              child: pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (user.phoneNumber.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.phoneNumber,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ),
            if (user.businessAddress.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.businessAddress,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ),
            pw.SizedBox(height: 14),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(date)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
                pw.Text(
                  'Receipt #: ${receiptId.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ],
            ),
            if (enteredByStaffName != null && enteredByStaffName.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Staff: $enteredByStaffName',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
              ),
            ],
            if (customerName != null && customerName.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 0.5),
              pw.SizedBox(height: 8),
              pw.Text(
                'Customer: $customerName',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (customerPhone != null && customerPhone.isNotEmpty)
                pw.Text(
                  'Phone: $customerPhone',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              if (customerAddress != null && customerAddress.isNotEmpty)
                pw.Text(
                  'Address: $customerAddress',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
            ],
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                pw.Text('Amt', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 6),
            ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.itemName,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.quantity} x ${user.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                      ),
                      pw.Text(
                        '${user.currencySymbol}${item.totalPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  if (item.discount > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '  Discount: -${user.currencySymbol}${item.discount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#D97706')),
                    ),
                  ],
                ],
              ),
            )),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${user.currencySymbol}${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 14,
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
                'Powered by SaleCentra',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'SMART. SIMPLE. COMPLETE',
                style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
          ];
        },
      ),
    );

    await _sharePdf(pdf, 'Receipt_${receiptId.substring(0, 8)}');
  }

  static Future<void> printThermalGroupedReceipt({
    required String receiptId,
    required DateTime date,
    required List<CartItem> items,
    required User user,
    String? enteredByStaffName,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
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

    final logo = _buildLogo(user);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: thermal58,
        build: (pw.Context context) {
          return [
            if (logo != null) ...[logo, pw.SizedBox(height: 10)],
            pw.Center(
              child: pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (user.phoneNumber.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.phoneNumber,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ),
            if (user.businessAddress.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.businessAddress,
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ),
            pw.SizedBox(height: 14),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 8),
            pw.Center(
              child: pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(
                  fontSize: 13,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                ),
              ),
            ),
            pw.SizedBox(height: 8),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(date)}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
                pw.Text(
                  'Receipt #: ${receiptId.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              ],
            ),
            if (enteredByStaffName != null && enteredByStaffName.isNotEmpty) ...[
              pw.SizedBox(height: 6),
              pw.Text(
                'Staff: $enteredByStaffName',
                style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
              ),
            ],
            if (customerName != null && customerName.isNotEmpty) ...[
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 0.5),
              pw.SizedBox(height: 8),
              pw.Text(
                'Customer: $customerName',
                style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
              ),
              if (customerPhone != null && customerPhone.isNotEmpty)
                pw.Text(
                  'Phone: $customerPhone',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
              if (customerAddress != null && customerAddress.isNotEmpty)
                pw.Text(
                  'Address: $customerAddress',
                  style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                ),
            ],
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 6),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text('Item', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
                pw.Text('Amt', style: pw.TextStyle(fontSize: 9, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#64748B'))),
              ],
            ),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 6),
            ...items.map((item) => pw.Padding(
              padding: const pw.EdgeInsets.only(bottom: 8),
              child: pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  pw.Text(
                    item.itemName,
                    style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                  ),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        '${item.quantity} x ${user.currencySymbol}${item.unitPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#475569')),
                      ),
                      pw.Text(
                        '${user.currencySymbol}${item.totalPrice.toStringAsFixed(2)}',
                        style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold),
                      ),
                    ],
                  ),
                  if (item.discount > 0) ...[
                    pw.SizedBox(height: 2),
                    pw.Text(
                      '  Discount: -${user.currencySymbol}${item.discount.toStringAsFixed(2)}',
                      style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#D97706')),
                    ),
                  ],
                ],
              ),
            )),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'TOTAL',
                  style: pw.TextStyle(
                    fontSize: 14,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
                pw.Text(
                  '${user.currencySymbol}${total.toStringAsFixed(2)}',
                  style: pw.TextStyle(
                    fontSize: 14,
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
                'Powered by SaleCentra',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'SMART. SIMPLE. COMPLETE',
                style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
          ];
        },
      ),
    );

    await Printing.layoutPdf(
      name: 'Receipt_${receiptId.substring(0, 8)}',
      onLayout: (format) => pdf.save(),
    );
  }

  static Future<void> generateAndShareRichReceipt({
    required String receiptId,
    required DateTime date,
    required List<CartItem> items,
    required User user,
    String? enteredByStaffName,
    String? customerName,
    String? customerPhone,
    String? customerAddress,
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
    final subtotal = items.fold(0.0, (sum, item) => sum + (item.unitPrice * item.quantity));
    final totalDiscount = items.fold(0.0, (sum, item) => sum + item.discount);
    final total = items.fold(0.0, (sum, item) => sum + item.totalPrice);

    final logo = _buildLogo(user);
    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(40),
        build: (pw.Context context) {
          return [
            // Header with logo and business info
            if (logo != null) ...[logo, pw.SizedBox(height: 10)],
            pw.Center(
              child: pw.Text(
                user.businessName,
                style: pw.TextStyle(fontSize: 24, fontWeight: pw.FontWeight.bold),
              ),
            ),
            if (user.phoneNumber.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.phoneNumber,
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ),
            if (user.businessAddress.isNotEmpty)
              pw.Center(
                child: pw.Text(
                  user.businessAddress,
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ),
            pw.SizedBox(height: 16),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            // Title
            pw.Center(
              child: pw.Text(
                'SALES RECEIPT',
                style: pw.TextStyle(
                  fontSize: 18,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColor.fromHex('#2563EB'),
                ),
              ),
            ),
            pw.SizedBox(height: 12),
            // Receipt info row
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Text(
                  'Receipt #: ${receiptId.substring(0, 8).toUpperCase()}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
                pw.Text(
                  'Date: ${DateFormat('dd MMM yyyy, HH:mm').format(date)}',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                ),
              ],
            ),
            if (enteredByStaffName != null && enteredByStaffName.isNotEmpty) ...[
              pw.SizedBox(height: 4),
              pw.Text(
                'Staff: $enteredByStaffName',
                style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
              ),
            ],
            // Customer info
            if (customerName != null && customerName.isNotEmpty) ...[
              pw.SizedBox(height: 16),
              pw.Container(
                padding: const pw.EdgeInsets.all(12),
                decoration: pw.BoxDecoration(
                  color: PdfColor.fromHex('#F8FAFC'),
                  borderRadius: pw.BorderRadius.circular(8),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      'Bill To',
                      style: pw.TextStyle(
                        fontSize: 10,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColor.fromHex('#64748B'),
                      ),
                    ),
                    pw.SizedBox(height: 4),
                    pw.Text(
                      customerName,
                      style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
                    ),
                    if (customerPhone != null && customerPhone.isNotEmpty)
                      pw.Text(
                        'Phone: $customerPhone',
                        style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                      ),
                    if (customerAddress != null && customerAddress.isNotEmpty)
                      pw.Text(
                        'Address: $customerAddress',
                        style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569')),
                      ),
                  ],
                ),
              ),
            ],
            pw.SizedBox(height: 20),
            // Items table
            pw.Table(
              border: pw.TableBorder.all(color: PdfColor.fromHex('#CBD5E1'), width: 0.5),
              columnWidths: {
                0: const pw.FlexColumnWidth(3),
                1: const pw.FlexColumnWidth(1),
                2: const pw.FlexColumnWidth(1.5),
                3: const pw.FlexColumnWidth(1.5),
                4: const pw.FlexColumnWidth(1.8),
              },
              children: [
                pw.TableRow(
                  decoration: pw.BoxDecoration(color: PdfColor.fromHex('#2563EB')),
                  children: [
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Item', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Qty', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Unit Price', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Discount', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11)),
                    ),
                    pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text('Total', style: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 11)),
                    ),
                  ],
                ),
                ...items.asMap().entries.map((entry) {
                  final i = entry.key;
                  final item = entry.value;
                  return pw.TableRow(
                    decoration: pw.BoxDecoration(
                      color: i.isEven ? PdfColor.fromHex('#F8FAFC') : PdfColors.white,
                    ),
                    children: [
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.itemName, style: pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text(item.quantity.toString(), style: pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${user.currencySymbol}${item.unitPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${user.currencySymbol}${item.discount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11)),
                      ),
                      pw.Padding(
                        padding: const pw.EdgeInsets.all(8),
                        child: pw.Text('${user.currencySymbol}${item.totalPrice.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, fontWeight: pw.FontWeight.bold)),
                      ),
                    ],
                  );
                }),
              ],
            ),
            pw.SizedBox(height: 16),
            // Summary section
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.end,
              children: [
                pw.Container(
                  width: 250,
                  child: pw.Column(
                    children: [
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Subtotal:', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#475569'))),
                          pw.Text('${user.currencySymbol}${subtotal.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11)),
                        ],
                      ),
                      pw.SizedBox(height: 4),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('Discount:', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#D97706'))),
                          pw.Text('-${user.currencySymbol}${totalDiscount.toStringAsFixed(2)}', style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#D97706'))),
                        ],
                      ),
                      pw.SizedBox(height: 8),
                      pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
                      pw.SizedBox(height: 8),
                      pw.Row(
                        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                        children: [
                          pw.Text('TOTAL', style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold)),
                          pw.Text(
                            '${user.currencySymbol}${total.toStringAsFixed(2)}',
                            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold, color: PdfColor.fromHex('#2563EB')),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 30),
            pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
            pw.SizedBox(height: 10),
            pw.Center(
              child: pw.Text(
                'Thank you for your business!',
                style: pw.TextStyle(fontSize: 13, color: PdfColor.fromHex('#64748B')),
              ),
            ),
            if (enteredByStaffName != null) ...[
              pw.SizedBox(height: 6),
              pw.Center(
                child: pw.Text(
                  'Sold by: $enteredByStaffName',
                  style: pw.TextStyle(fontSize: 11, color: PdfColor.fromHex('#64748B')),
                ),
              ),
            ],
            pw.SizedBox(height: 20),
            pw.Center(
              child: pw.Text(
                'Powered by SaleCentra',
                style: pw.TextStyle(fontSize: 9, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'SMART. SIMPLE. COMPLETE',
                style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
              ),
            ),
            pw.Center(
              child: pw.Text(
                'Visit www.salecentra.com',
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

    final invoiceLogo = _buildLogo(user);
    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // Business header â€” logo + name + contact
              if (invoiceLogo != null) ...[invoiceLogo, pw.SizedBox(height: 10)],
              pw.Center(
                child: pw.Text(
                  user.businessName,
                  style: pw.TextStyle(fontSize: 20, fontWeight: pw.FontWeight.bold),
                ),
              ),
              if (user.phoneNumber.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.phoneNumber,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              if (user.businessAddress.isNotEmpty)
                pw.Center(
                  child: pw.Text(
                    user.businessAddress,
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                ),
              pw.SizedBox(height: 14),
              pw.Divider(color: PdfColor.fromHex('#CBD5E1'), height: 1),
              pw.SizedBox(height: 8),
              pw.Center(
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 13,
                    fontWeight: pw.FontWeight.bold,
                    color: PdfColor.fromHex('#2563EB'),
                  ),
                ),
              ),
              pw.SizedBox(height: 8),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Invoice #: ${invoice.id.substring(0, 8).toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
                  pw.Text(
                    'Status: ${invoice.status.toUpperCase()}',
                    style: pw.TextStyle(fontSize: 10, color: PdfColor.fromHex('#475569')),
                  ),
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
                  'Powered by SaleCentra',
                  style: pw.TextStyle(fontSize: 8, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'SMART. SIMPLE. COMPLETE',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
                ),
              ),
              pw.Center(
                child: pw.Text(
                  'Visit www.salecentra.com',
                  style: pw.TextStyle(fontSize: 7, color: PdfColor.fromHex('#94A3B8')),
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
