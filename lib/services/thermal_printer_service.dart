import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/column_maker.dart';
import 'package:sunmi_printer_plus/enums.dart';
import 'package:sunmi_printer_plus/sunmi_style.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ThermalPrinterService {
  static const int _lineWidthChars = 32;
  static bool _bindLock = false;

  /// Bind to the Sunmi printer. In v3.x, bindingPrinter() actually works.
  /// Must be called before every print job.
  static Future<bool> _bind() async {
    if (_bindLock) return true;
    _bindLock = true;
    try {
      final bound = await SunmiPrinter.bindingPrinter() ?? false;
      if (kDebugMode) {
        print('[ThermalPrinter] Printer bound: $bound');
      }
      _bindLock = false;
      return bound;
    } catch (e) {
      _bindLock = false;
      if (kDebugMode) {
        print('[ThermalPrinter] Binding failed: $e');
      }
      return false;
    }
  }

  static Future<bool> isSunmiDevice() async {
    return await _bind();
  }

  static Future<void> printReceipt({
    required String businessName,
    required String address,
    required String phone,
    required String receiptNo,
    required String cashier,
    required List<Map<String, dynamic>> items,
    required double subtotal,
    required double discount,
    required double total,
    String? customerName,
    String? customerPhone,
    String? paymentMethod,
    String? paymentStatus,
    String? deliveryInfo,
    String? trackingNo,
  }) async {
    final isSunmi = await _bind();
    if (!isSunmi) {
      if (kDebugMode) print('[ThermalPrinter] No Sunmi printer available');
      return;
    }

    try {
      await SunmiPrinter.initPrinter();
      await SunmiPrinter.startTransactionPrint(true);

      // Tighten line spacing via ESC/POS command: ESC 3 n
      // Default is ~30 dots; 16 gives compact output without crowding.
      await SunmiPrinter.printRawData(
        Uint8List.fromList([0x1B, 0x33, 16]),
      );

      // Use SM (18px) for everything — one unit below the default MD (24px)
      // that printRow falls back to after printText's initPrinter() reset.
      final sm = SunmiStyle(fontSize: SunmiFontSize.SM);
      final smBold = SunmiStyle(fontSize: SunmiFontSize.SM, bold: true);
      final smCenter = SunmiStyle(fontSize: SunmiFontSize.SM, align: SunmiPrintAlign.CENTER);
      final smBoldCenter = SunmiStyle(fontSize: SunmiFontSize.SM, bold: true, align: SunmiPrintAlign.CENTER);

      // Header — combine business info into one printText call to avoid
      // the initPrinter() reset (and extra spacing) between each line.
      // printText auto-appends \n, so don't add trailing \n ourselves.
      await SunmiPrinter.printText('SaleCentra', style: smBoldCenter);
      final headerBuf = StringBuffer(businessName.isEmpty ? 'N/A' : businessName);
      if (address.isNotEmpty) headerBuf.write('\n$address');
      headerBuf.write('\n${phone.isEmpty ? 'N/A' : phone}');
      await SunmiPrinter.printText(headerBuf.toString(), style: smCenter);
      await SunmiPrinter.line();

      // Receipt info
      final now = DateTime.now();
      final dateStr = '${now.day.toString().padLeft(2, '0')}/${now.month.toString().padLeft(2, '0')}/${now.year} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      // Combine Date/Receipt/Cashier into one call — printText auto-appends \n.
      await SunmiPrinter.printText(
        'Date: $dateStr\nReceipt: $receiptNo\nCashier: $cashier',
        style: sm,
      );
      await SunmiPrinter.line();

      // Items — set font to SM before each printRow since printText's
      // initPrinter() resets the font to MD (24) which causes overlap.
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        await SunmiPrinter.setFontSize(SunmiFontSize.SM);
        await SunmiPrinter.printRow(cols: [
          ColumnMaker(
            text: '${qty}x $name',
            width: 20,
            align: SunmiPrintAlign.LEFT,
          ),
          ColumnMaker(
            text: lineTotal.toStringAsFixed(2),
            width: 12,
            align: SunmiPrintAlign.RIGHT,
          ),
        ]);
      }

      await SunmiPrinter.line();

      // Totals
      await SunmiPrinter.setFontSize(SunmiFontSize.SM);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Subtotal', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(text: subtotal.toStringAsFixed(2), width: 12, align: SunmiPrintAlign.RIGHT),
      ]);
      await SunmiPrinter.setFontSize(SunmiFontSize.SM);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'Discount', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(text: '-${discount.toStringAsFixed(2)}', width: 12, align: SunmiPrintAlign.RIGHT),
      ]);
      await SunmiPrinter.setFontSize(SunmiFontSize.SM);
      await SunmiPrinter.printRow(cols: [
        ColumnMaker(text: 'TOTAL', width: 20, align: SunmiPrintAlign.LEFT),
        ColumnMaker(text: total.toStringAsFixed(2), width: 12, align: SunmiPrintAlign.RIGHT),
      ]);

      await SunmiPrinter.line();

      // Customer info
      if (customerName != null && customerName.isNotEmpty) {
        final custBuf = StringBuffer('Customer: $customerName');
        if (customerPhone != null && customerPhone.isNotEmpty) {
          custBuf.write('\nPhone: $customerPhone');
        }
        await SunmiPrinter.printText(custBuf.toString(), style: sm);
      }

      // Payment info
      if (paymentMethod != null) {
        await SunmiPrinter.line();
        final payBuf = StringBuffer('Payment: $paymentMethod');
        if (paymentStatus != null) {
          payBuf.write('\nStatus: $paymentStatus');
        }
        await SunmiPrinter.printText(payBuf.toString(), style: sm);
      }

      // Delivery info
      if (deliveryInfo != null) {
        await SunmiPrinter.line();
        final delBuf = StringBuffer('Delivery: $deliveryInfo');
        if (trackingNo != null) {
          delBuf.write('\nTracking: $trackingNo');
        }
        await SunmiPrinter.printText(delBuf.toString(), style: sm);
      }

      await SunmiPrinter.line();
      // Footer — combine into one call to avoid extra spacing
      await SunmiPrinter.printText(
        'Thank you!\nPowered by SaleCentra\nSmart. Simple. Complete.',
        style: smCenter,
      );
      await SunmiPrinter.lineWrap(1);

      // Reset line spacing to default (ESC 2)
      await SunmiPrinter.printRawData(
        Uint8List.fromList([0x1B, 0x32]),
      );

      await SunmiPrinter.exitTransactionPrint(true);
    } catch (e) {
      if (kDebugMode) print('[ThermalPrinter] Print error: $e');
      try {
        await SunmiPrinter.exitTransactionPrint(true);
      } catch (_) {}
    }
  }
}
