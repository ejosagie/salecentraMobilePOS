import 'package:flutter/foundation.dart';
import 'package:sunmi_printer_plus/sunmi_printer_plus.dart';

class ThermalPrinterService {
  // The regular Sunmi V2 has a built-in 58mm thermal printer, which fits
  // ~32 half-width characters per line at the default font size. Column
  // widths below are sized in characters (not flex weights) to match this,
  // so item/price columns align correctly on the physical receipt.
  static const int _lineWidthChars = 32;

  /// Bind to the Sunmi printer fresh every time. The binding can be lost
  /// between calls, so we must re-bind before each print job.
  static Future<bool> _bind() async {
    try {
      // ignore: deprecated_member_use
      final bound = await SunmiPrinter.bindingPrinter() ?? false;
      if (kDebugMode) {
        print('[ThermalPrinter] Printer bound: $bound');
      }
      return bound;
    } catch (e) {
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
      if (kDebugMode) print('[ThermalPrinter] No Sunmi printer available — binding failed');
      return;
    }

    try {
      // Header
      await SunmiPrinter.printText('SaleCentra Receipt\n',
          style: SunmiTextStyle(bold: true, align: SunmiPrintAlign.CENTER, fontSize: 36));
      await SunmiPrinter.printText('$businessName\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 24));
      if (address.isNotEmpty) {
        await SunmiPrinter.printText('$address\n',
            style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      }
      await SunmiPrinter.printText('$phone\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      await SunmiPrinter.line(type: '*');
      await SunmiPrinter.lineWrap(1);

      // Receipt info
      final now = DateTime.now();
      final dateStr = '${now.year}-${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')} ${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      await SunmiPrinter.printText('Date: $dateStr\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.printText('Receipt: $receiptNo\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.printText('Cashier: $cashier\n',
          style: SunmiTextStyle(fontSize: 18));
      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Items — name on its own full-width line, then qty/price aligned in
      // columns sized for the 58mm/32-char printable width so the line
      // total lands flush right regardless of digit count.
      for (final item in items) {
        final name = item['name'] as String? ?? '';
        final qty = item['quantity'] as int? ?? 1;
        final price = (item['price'] as num?)?.toDouble() ?? 0.0;
        final lineTotal = price * qty;

        await SunmiPrinter.printText('$name\n',
            style: SunmiTextStyle(fontSize: 18));
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(
            text: '  ${qty}x @ ${price.toStringAsFixed(2)}',
            width: _lineWidthChars - 12,
            style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.LEFT),
          ),
          SunmiColumn(
            text: lineTotal.toStringAsFixed(2),
            width: 12,
            style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.RIGHT),
          ),
        ]);
      }

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Totals — same left-label/right-value column split as the items.
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
          text: 'Subtotal',
          width: _lineWidthChars - 12,
          style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: subtotal.toStringAsFixed(2),
          width: 12,
          style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.RIGHT),
        ),
      ]);
      if (discount > 0) {
        await SunmiPrinter.printRow(cols: [
          SunmiColumn(
            text: 'Discount',
            width: _lineWidthChars - 12,
            style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.LEFT),
          ),
          SunmiColumn(
            text: '-${discount.toStringAsFixed(2)}',
            width: 12,
            style: SunmiTextStyle(fontSize: 18, align: SunmiPrintAlign.RIGHT),
          ),
        ]);
      }
      await SunmiPrinter.printRow(cols: [
        SunmiColumn(
          text: 'TOTAL',
          width: _lineWidthChars - 12,
          style: SunmiTextStyle(bold: true, fontSize: 28, align: SunmiPrintAlign.LEFT),
        ),
        SunmiColumn(
          text: total.toStringAsFixed(2),
          width: 12,
          style: SunmiTextStyle(bold: true, fontSize: 28, align: SunmiPrintAlign.RIGHT),
        ),
      ]);

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);

      // Customer info
      if (customerName != null && customerName.isNotEmpty) {
        await SunmiPrinter.printText('Customer: $customerName\n',
            style: SunmiTextStyle(fontSize: 18));
      }
      if (customerPhone != null && customerPhone.isNotEmpty) {
        await SunmiPrinter.printText('Phone: $customerPhone\n',
            style: SunmiTextStyle(fontSize: 18));
      }

      // Payment info
      if (paymentMethod != null) {
        await SunmiPrinter.line(type: '-');
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Payment: $paymentMethod\n',
            style: SunmiTextStyle(fontSize: 18));
        if (paymentStatus != null) {
          await SunmiPrinter.printText('Status: $paymentStatus\n',
              style: SunmiTextStyle(fontSize: 18));
        }
      }

      // Delivery info
      if (deliveryInfo != null) {
        await SunmiPrinter.line(type: '-');
        await SunmiPrinter.lineWrap(1);
        await SunmiPrinter.printText('Delivery: $deliveryInfo\n',
            style: SunmiTextStyle(fontSize: 18));
        if (trackingNo != null) {
          await SunmiPrinter.printText('Tracking: $trackingNo\n',
              style: SunmiTextStyle(fontSize: 18));
        }
      }

      await SunmiPrinter.line(type: '-');
      await SunmiPrinter.lineWrap(1);
      await SunmiPrinter.printText('Thank you for your business!\n',
          style: SunmiTextStyle(align: SunmiPrintAlign.CENTER, fontSize: 18));
      await SunmiPrinter.lineWrap(2);
      await SunmiPrinter.cutPaper();
    } catch (e) {
      if (kDebugMode) print('[ThermalPrinter] Print error: $e');
    }
  }
}
