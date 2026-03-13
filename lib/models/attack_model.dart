class AttackModel {
  final String id;
  final DateTime timestamp;
  final String targetIP;
  final double amount;
  final String vendor;
  final String status;
  final String? response;

  const AttackModel({
    required this.id,
    required this.timestamp,
    required this.targetIP,
    required this.amount,
    required this.vendor,
    required this.status,
    this.response,
  });

  bool get isSuccess => status == 'SUCCESS';

  Map<String, dynamic> toMap() => {
        'id': id,
        'timestamp': timestamp.toIso8601String(),
        'targetIP': targetIP,
        'amount': amount,
        'vendor': vendor,
        'status': status,
        'response': response,
      };

  factory AttackModel.fromMap(Map<String, dynamic> map) => AttackModel(
        id: map['id'] as String,
        timestamp: DateTime.parse(map['timestamp'] as String),
        targetIP: map['targetIP'] as String,
        amount: (map['amount'] as num).toDouble(),
        vendor: map['vendor'] as String,
        status: map['status'] as String,
        response: map['response'] as String?,
      );
}
