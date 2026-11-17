import 'package:flutter/material.dart';
import '../models/regulatory_document_model.dart';

/// Dialog allowing compliance auditors to capture or edit structured metadata
/// for an uploaded regulatory circular document.
class CircularMetadataDialog extends StatefulWidget {
  final String fileName;
  final int fileSizeBytes;
  final RegulatoryDocumentModel? initialModel;
  final Function(RegulatoryDocumentModel) onSave;

  const CircularMetadataDialog({
    super.key,
    required this.fileName,
    required this.fileSizeBytes,
    this.initialModel,
    required this.onSave,
  });

  @override
  State<CircularMetadataDialog> createState() => _CircularMetadataDialogState();
}

class _CircularMetadataDialogState extends State<CircularMetadataDialog> {
  final _formKey = GlobalKey<FormState>();

  String _issuingAuthority = 'RBI';
  late final TextEditingController _circularNumberController;
  late final TextEditingController _categoryController;
  DateTime _effectiveDate = DateTime.now();
  DateTime _complianceDeadline = DateTime.now().add(const Duration(days: 90));
  int _version = 1;

  final List<String> _authorities = [
    'RBI',
    'SEC',
    'MAS',
    'FINRA',
    'EBA',
    'OCC',
    'FCA',
    'Federal Reserve',
    'Other Authority',
  ];

  final List<String> _commonCategories = [
    'KYC & Anti-Money Laundering',
    'Digital Lending & Underwriting',
    'Capital Adequacy & Liquidity (Basel III)',
    'IT Governance & Cyber Resilience',
    'Consumer Protection & Grievance',
    'Cross-Border Remittance & Forex',
  ];

  @override
  void initState() {
    super.initState();
    final init = widget.initialModel;
    if (init != null) {
      if (_authorities.contains(init.issuingAuthority)) {
        _issuingAuthority = init.issuingAuthority;
      }
      _circularNumberController =
          TextEditingController(text: init.circularNumber);
      _categoryController =
          TextEditingController(text: init.category ?? _commonCategories.first);
      if (init.effectiveDate != null) _effectiveDate = init.effectiveDate!;
      if (init.complianceDeadline != null) {
        _complianceDeadline = init.complianceDeadline!;
      }
      _version = init.version;
    } else {
      _circularNumberController =
          TextEditingController(text: 'RBI/2026-27/CIRCULAR-${DateTime.now().millisecondsSinceEpoch % 1000}');
      _categoryController =
          TextEditingController(text: _commonCategories.first);
    }
  }

  @override
  void dispose() {
    _circularNumberController.dispose();
    _categoryController.dispose();
    super.dispose();
  }

  Future<void> _pickDate(bool isEffective) async {
    final current = isEffective ? _effectiveDate : _complianceDeadline;
    final picked = await showDatePicker(
      context: context,
      initialDate: current,
      firstDate: DateTime(2020),
      lastDate: DateTime(2035),
      builder: (context, child) {
        return Theme(
          data: Theme.of(context).copyWith(
            colorScheme: const ColorScheme.light(
              primary: Color(0xFF6366F1),
              onPrimary: Colors.white,
              onSurface: Color(0xFF0F172A),
            ),
          ),
          child: child!,
        );
      },
    );
    if (picked != null) {
      setState(() {
        if (isEffective) {
          _effectiveDate = picked;
        } else {
          _complianceDeadline = picked;
        }
      });
    }
  }

  void _handleSave() {
    if (!_formKey.currentState!.validate()) return;

    final format = widget.fileName.contains('.')
        ? widget.fileName.split('.').last.toUpperCase()
        : 'PDF';

    final model = RegulatoryDocumentModel(
      id: widget.initialModel?.id ??
          'reg-${DateTime.now().millisecondsSinceEpoch}',
      bankId: widget.initialModel?.bankId ?? 'default-bank',
      documentName: widget.fileName,
      issuingAuthority: _issuingAuthority,
      circularNumber: _circularNumberController.text.trim(),
      effectiveDate: _effectiveDate,
      complianceDeadline: _complianceDeadline,
      category: _categoryController.text.trim(),
      fileFormat: format,
      fileSizeBytes: widget.fileSizeBytes,
      version: _version,
      extractionStatus: 'PENDING',
      createdAt: DateTime.now(),
    );

    widget.onSave(model);
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: Colors.white,
      surfaceTintColor: Colors.transparent,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: Padding(
          padding: const EdgeInsets.all(22),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: const Color(0xFF6366F1),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: const Icon(
                        Icons.description_rounded,
                        color: Colors.white,
                        size: 18,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Regulatory Circular Metadata',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 15,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0F172A),
                            ),
                          ),
                          Text(
                            widget.fileName,
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 11,
                              color: Color(0xFF64748B),
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded,
                          size: 20, color: Color(0xFF64748B)),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ],
                ),
                const Divider(height: 24, color: Color(0xFFE2E8F0)),

                // Issuing Authority & Version
                Row(
                  children: [
                    Expanded(
                      flex: 3,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Issuing Authority',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<String>(
                            initialValue: _issuingAuthority,
                            items: _authorities
                                .map((a) =>
                                    DropdownMenuItem(value: a, child: Text(a)))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) {
                                setState(() => _issuingAuthority = v);
                              }
                            },
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Version',
                            style: TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              color: Color(0xFF334155),
                            ),
                          ),
                          const SizedBox(height: 4),
                          DropdownButtonFormField<int>(
                            initialValue: _version,
                            items: [1, 2, 3, 4, 5]
                                .map((v) => DropdownMenuItem(
                                    value: v, child: Text('v$v.0')))
                                .toList(),
                            onChanged: (v) {
                              if (v != null) setState(() => _version = v);
                            },
                            style: const TextStyle(
                              fontFamily: 'packages/cidan/Poppins',
                              fontSize: 12.5,
                              color: Color(0xFF0F172A),
                            ),
                            decoration: InputDecoration(
                              isDense: true,
                              filled: true,
                              fillColor: Colors.white,
                              contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 10, vertical: 10),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(8),
                                borderSide:
                                    const BorderSide(color: Color(0xFFCBD5E1)),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Circular Number
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Circular / Reference Number',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    TextFormField(
                      controller: _circularNumberController,
                      validator: (v) => v == null || v.isEmpty
                          ? 'Circular number required'
                          : null,
                      style: const TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12.5,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        prefixIcon: const Icon(Icons.tag_rounded,
                            size: 16, color: Color(0xFF64748B)),
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Category Dropdown
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Regulatory Domain / Category',
                      style: TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF334155),
                      ),
                    ),
                    const SizedBox(height: 4),
                    DropdownButtonFormField<String>(
                      initialValue: _commonCategories.contains(_categoryController.text)
                          ? _categoryController.text
                          : _commonCategories.first,
                      items: _commonCategories
                          .map((c) =>
                              DropdownMenuItem(value: c, child: Text(c)))
                          .toList(),
                      onChanged: (v) {
                        if (v != null) {
                          setState(() => _categoryController.text = v);
                        }
                      },
                      style: const TextStyle(
                        fontFamily: 'packages/cidan/Poppins',
                        fontSize: 12,
                        color: Color(0xFF0F172A),
                      ),
                      decoration: InputDecoration(
                        isDense: true,
                        filled: true,
                        fillColor: Colors.white,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(8),
                          borderSide:
                              const BorderSide(color: Color(0xFFCBD5E1)),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

                // Date Selectors
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(true),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Effective Date',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.calendar_today_rounded,
                                      size: 13, color: Color(0xFF0F172A)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_effectiveDate.year}-${_effectiveDate.month.toString().padLeft(2, '0')}-${_effectiveDate.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontFamily: 'packages/cidan/Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: InkWell(
                        onTap: () => _pickDate(false),
                        borderRadius: BorderRadius.circular(8),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 9),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: const Color(0xFFCBD5E1)),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              const Text(
                                'Compliance Deadline',
                                style: TextStyle(
                                  fontFamily: 'packages/cidan/Poppins',
                                  fontSize: 10.5,
                                  color: Color(0xFF64748B),
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  const Icon(Icons.event_available_rounded,
                                      size: 13, color: Color(0xFF0F172A)),
                                  const SizedBox(width: 5),
                                  Text(
                                    '${_complianceDeadline.year}-${_complianceDeadline.month.toString().padLeft(2, '0')}-${_complianceDeadline.day.toString().padLeft(2, '0')}',
                                    style: const TextStyle(
                                      fontFamily: 'packages/cidan/Poppins',
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0F172A),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Save Button
                ElevatedButton(
                  onPressed: _handleSave,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF6366F1),
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Save Metadata',
                    style: TextStyle(
                      fontFamily: 'packages/cidan/Poppins',
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
