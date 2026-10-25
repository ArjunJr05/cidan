import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../../core/constants/app_colors.dart';

class OtpInputRow extends StatefulWidget {
  final int length;
  final ValueChanged<String> onChanged;
  final ValueChanged<String>? onCompleted;
  final String? initialValue;

  const OtpInputRow({
    super.key,
    this.length = 6,
    required this.onChanged,
    this.onCompleted,
    this.initialValue,
  });

  @override
  State<OtpInputRow> createState() => OtpInputRowState();
}

class OtpInputRowState extends State<OtpInputRow> {
  late List<TextEditingController> _controllers;
  late List<FocusNode> _focusNodes;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(
      widget.length,
      (i) => TextEditingController(),
    );
    _focusNodes = List.generate(
      widget.length,
      (i) => FocusNode(),
    );

    if (widget.initialValue != null && widget.initialValue!.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        setOtp(widget.initialValue!);
      });
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void setOtp(String code) {
    final cleanCode = code.replaceAll(RegExp(r'[^0-9]'), '');
    for (int i = 0; i < widget.length; i++) {
      if (i < cleanCode.length) {
        _controllers[i].text = cleanCode[i];
      } else {
        _controllers[i].text = '';
      }
    }
    _notifyChange();
    if (cleanCode.length >= widget.length && widget.onCompleted != null) {
      widget.onCompleted!(cleanCode.substring(0, widget.length));
    }
  }

  String get currentOtp => _controllers.map((c) => c.text).join();

  void _notifyChange() {
    final otp = currentOtp;
    widget.onChanged(otp);
    if (otp.length == widget.length && widget.onCompleted != null) {
      widget.onCompleted!(otp);
    }
  }

  void _onDigitChanged(int index, String value) {
    if (value.length > 1) {
      // Handles paste
      final clean = value.replaceAll(RegExp(r'[^0-9]'), '');
      for (int i = 0; i < widget.length; i++) {
        if (i < clean.length) {
          _controllers[i].text = clean[i];
        }
      }
      _notifyChange();
      final targetIndex = (clean.length < widget.length) ? clean.length : widget.length - 1;
      _focusNodes[targetIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    }
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return _buildDigitBox(index);
      }),
    );
  }

  Widget _buildDigitBox(int index) {
    return SizedBox(
      width: 48,
      height: 56,
      child: KeyboardListener(
        focusNode: FocusNode(),
        onKeyEvent: (event) {
          if (event is KeyDownEvent &&
              event.logicalKey == LogicalKeyboardKey.backspace &&
              _controllers[index].text.isEmpty &&
              index > 0) {
            _focusNodes[index - 1].requestFocus();
            _controllers[index - 1].text = '';
            _notifyChange();
          }
        },
        child: ValueListenableBuilder<TextEditingValue>(
          valueListenable: _controllers[index],
          builder: (context, value, child) {
            final isFilled = value.text.isNotEmpty;
            return TextField(
              controller: _controllers[index],
              focusNode: _focusNodes[index],
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              maxLength: 1,
              style: const TextStyle(
                fontFamily: 'Poppins',
                fontSize: 22,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
              inputFormatters: [
                FilteringTextInputFormatter.digitsOnly,
              ],
              decoration: InputDecoration(
                counterText: '',
                contentPadding: EdgeInsets.zero,
                filled: true,
                fillColor: Colors.white,
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: BorderSide(
                    color: isFilled ? AppColors.primary : AppColors.border,
                    width: isFilled ? 1.5 : 1.2,
                  ),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(14),
                  borderSide: const BorderSide(
                    color: AppColors.borderFocus,
                    width: 2.0,
                  ),
                ),
              ),
              onChanged: (val) => _onDigitChanged(index, val),
            );
          },
        ),
      ),
    );
  }
}
