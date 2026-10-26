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
    final init = widget.initialValue?.replaceAll(RegExp(r'[^0-9]'), '') ?? '';
    _controllers = List.generate(widget.length, (i) {
      final initialDigit = i < init.length ? init[i] : '';
      return TextEditingController(text: initialDigit);
    });

    _focusNodes = List.generate(widget.length, (i) {
      final node = FocusNode();
      node.onKeyEvent = (focusNode, event) {
        if (event is KeyDownEvent &&
            event.logicalKey == LogicalKeyboardKey.backspace &&
            _controllers[i].text.isEmpty &&
            i > 0) {
          _focusNodes[i - 1].requestFocus();
          _controllers[i - 1].text = '';
          _notifyChange();
          return KeyEventResult.handled;
        }
        return KeyEventResult.ignored;
      };
      return node;
    });
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
      final targetIndex = (clean.length < widget.length)
          ? clean.length
          : widget.length - 1;
      _focusNodes[targetIndex].requestFocus();
      return;
    }

    if (value.isNotEmpty) {
      if (index < widget.length - 1) {
        _focusNodes[index + 1].requestFocus();
      } else {
        _focusNodes[index].unfocus();
      }
    } else {
      if (index > 0) {
        _focusNodes[index - 1].requestFocus();
      }
    }
    _notifyChange();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final availableWidth = (screenWidth - 48.0).clamp(260.0, 440.0);
    final gap = (availableWidth * 0.024).clamp(4.0, 10.0);
    final boxWidth =
        ((availableWidth - (gap * (widget.length - 1))) / widget.length)
            .clamp(38.0, 50.0);
    final boxHeight = (boxWidth * 1.16).clamp(46.0, 56.0);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(widget.length, (index) {
        return SizedBox(
          width: boxWidth,
          height: boxHeight,
          child: _buildDigitBox(index),
        );
      }),
    );
  }

  Widget _buildDigitBox(int index) {
    return ValueListenableBuilder<TextEditingValue>(
      valueListenable: _controllers[index],
      builder: (context, value, child) {
        final isFilled = value.text.isNotEmpty;
        return TextField(
          controller: _controllers[index],
          focusNode: _focusNodes[index],
          keyboardType: TextInputType.number,
          textAlign: TextAlign.center,
          textAlignVertical: TextAlignVertical.center,
          maxLength: 1,
          style: const TextStyle(
            fontFamily: 'Poppins',
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
          inputFormatters: [FilteringTextInputFormatter.digitsOnly],
          decoration: InputDecoration(
            counterText: '',
            contentPadding: EdgeInsets.zero,
            isDense: true,
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
    );
  }
}
