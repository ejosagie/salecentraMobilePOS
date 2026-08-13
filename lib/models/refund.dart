class Refund {
  final String id;
  final String saleId;
  final String userId;
  final double amount;
  final String? reason;
  final String refundType;
  final String? refundedBy;
  final DateTime refundedAt;
  final String? saleItem;
  final int? saleQuantity;
  final double? saleTotal;

  Refund({
    required this.id,
    required this.saleId,
    required this.userId,
    required this.amount,
    this.reason,
    required this.refundType,
    this.refundedBy,
    required this.refundedAt,
    this.saleItem,
    this.saleQuantity,
    this.saleTotal,
  });

  bool get isFull => refundType == 'full';
  bool get isPartial => refundType == 'partial';

  factory Refund.fromMap(Map<String, dynamic> map) {
    return Refund(
      id: map['id']?.toString() ?? '',
      saleId: map['sale_id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      amount: (map['amount'] as num?)?.toDouble() ?? 0.0,
      reason: map['reason']?.toString(),
      refundType: map['refund_type']?.toString() ?? 'partial',
      refundedBy: map['refunded_by']?.toString(),
      refundedAt: map['refunded_at'] != null
          ? DateTime.tryParse(map['refunded_at']) ?? DateTime.now()
          : DateTime.now(),
      saleItem: map['sale_item']?.toString(),
      saleQuantity: (map['sale_quantity'] as num?)?.toInt(),
      saleTotal: (map['sale_total'] as num?)?.toDouble(),
    );
  }
}
