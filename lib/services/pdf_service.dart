import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:share_plus/share_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'dart:io';
import 'package:intl/intl.dart';
import '../models/sale.dart';
import '../models/invoice.dart';
import '../models/user.dart';

class PdfService {
  static Future<void> generateAndShareReceipt(Sale sale, User user) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'SALE RECEIPT',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Business: ${user.businessName}'),
              pw.Text('Contact: ${user.phoneNumber}'),
              pw.Text('Address: ${user.businessAddress}'),
              pw.SizedBox(height: 20),
              pw.Divider(),
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
                  pw.Text('Price: ₦${sale.price.toStringAsFixed(2)}'),
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
                    '₦${sale.total.toStringAsFixed(2)}',
                    style: pw.TextStyle(
                      fontSize: 18,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 14),
                ),
              ),
              if (sale.enteredByStaffName != null) ...[
                pw.SizedBox(height: 10),
                pw.Center(
                  child: pw.Text(
                    'Sold by: ${sale.enteredByStaffName}',
                    style: pw.TextStyle(fontSize: 12),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );

    await _sharePdf(pdf, 'Receipt_${sale.id.substring(0, 8)}');
  }

  static Future<void> generateAndShareInvoice(Invoice invoice, User user) async {
    final pdf = pw.Document();

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Center(
                child: pw.Text(
                  'INVOICE',
                  style: pw.TextStyle(
                    fontSize: 24,
                    fontWeight: pw.FontWeight.bold,
                  ),
                ),
              ),
              pw.SizedBox(height: 20),
              pw.Text('Business: ${user.businessName}'),
              pw.Text('Contact: ${user.phoneNumber}'),
              pw.Text('Address: ${user.businessAddress}'),
              pw.SizedBox(height: 20),
              pw.Divider(),
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
                '₦${invoice.total.toStringAsFixed(2)}',
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
              pw.SizedBox(height: 30),
              pw.Center(
                child: pw.Text(
                  'Thank you for your business!',
                  style: pw.TextStyle(fontSize: 14),
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
    );
  }
}
