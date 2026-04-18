// lib/models/sms_candidate.dart
class SmsCandidate {
  final int? smsId;
  final String body;
  final DateTime? smsDate;
  const SmsCandidate({this.smsId, required this.body, this.smsDate});
}
