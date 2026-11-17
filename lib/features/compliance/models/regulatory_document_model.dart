/// Represents an uploaded regulatory circular or compliance document.
class RegulatoryDocumentModel {
  final String id;
  final String bankId;
  final String documentName;
  final String issuingAuthority; // 'RBI', 'SEC', 'MAS', 'FINRA', 'EBA', etc.
  final String circularNumber;
  final DateTime? effectiveDate;
  final DateTime? complianceDeadline;
  final String? category; // 'KYC/AML', 'Lending', 'Capital Adequacy', etc.
  final String fileFormat;
  final int fileSizeBytes;
  final String? storagePath;
  final int version;
  final String extractionStatus; // 'PENDING', 'EXTRACTING', 'COMPLETED', 'FAILED'
  final String? extractedText;
  final DateTime createdAt;

  const RegulatoryDocumentModel({
    required this.id,
    required this.bankId,
    required this.documentName,
    required this.issuingAuthority,
    required this.circularNumber,
    this.effectiveDate,
    this.complianceDeadline,
    this.category,
    required this.fileFormat,
    this.fileSizeBytes = 0,
    this.storagePath,
    this.version = 1,
    this.extractionStatus = 'PENDING',
    this.extractedText,
    required this.createdAt,
  });

  factory RegulatoryDocumentModel.fromJson(Map<String, dynamic> json) {
    return RegulatoryDocumentModel(
      id: json['id']?.toString() ?? '',
      bankId: json['bank_id']?.toString() ?? '',
      documentName: json['document_name']?.toString() ?? '',
      issuingAuthority: json['issuing_authority']?.toString() ?? 'Regulatory Body',
      circularNumber: json['circular_number']?.toString() ?? '',
      effectiveDate: json['effective_date'] != null
          ? DateTime.tryParse(json['effective_date'].toString())
          : null,
      complianceDeadline: json['compliance_deadline'] != null
          ? DateTime.tryParse(json['compliance_deadline'].toString())
          : null,
      category: json['category']?.toString(),
      fileFormat: json['file_format']?.toString() ?? 'PDF',
      fileSizeBytes: json['file_size_bytes'] is num
          ? (json['file_size_bytes'] as num).toInt()
          : 0,
      storagePath: json['storage_path']?.toString(),
      version: json['version'] is num ? (json['version'] as num).toInt() : 1,
      extractionStatus: json['extraction_status']?.toString() ?? 'PENDING',
      extractedText: json['extracted_text']?.toString(),
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'bank_id': bankId,
        'document_name': documentName,
        'issuing_authority': issuingAuthority,
        'circular_number': circularNumber,
        'effective_date': effectiveDate?.toIso8601String().split('T').first,
        'compliance_deadline': complianceDeadline?.toIso8601String().split('T').first,
        'category': category,
        'file_format': fileFormat,
        'file_size_bytes': fileSizeBytes,
        'storage_path': storagePath,
        'version': version,
        'extraction_status': extractionStatus,
        'extracted_text': extractedText,
        'created_at': createdAt.toIso8601String(),
      };
}
