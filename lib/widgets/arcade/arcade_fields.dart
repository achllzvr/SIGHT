import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/lumi_theme.dart';

/// Labeled pill text field (password / email / long input).
class ArcadeTextField extends StatelessWidget {
  const ArcadeTextField({
    super.key,
    required this.label,
    required this.controller,
    this.obscureText = false,
    this.keyboardType,
    this.textInputAction,
    this.maxLength,
    this.inputFormatters,
    this.errorText,
    this.onChanged,
  });

  final String label;
  final TextEditingController controller;
  final bool obscureText;
  final TextInputType? keyboardType;
  final TextInputAction? textInputAction;
  final int? maxLength;
  final List<TextInputFormatter>? inputFormatters;
  final String? errorText;
  final ValueChanged<String>? onChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(label, style: LumiTheme.clanMedium(16, color: LumiColors.textDark)),
        const SizedBox(height: LumiSpacing.sm),
        TextField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          textInputAction: textInputAction,
          maxLength: maxLength,
          inputFormatters: inputFormatters,
          onChanged: onChanged,
          style: LumiTheme.clanMedium(16, color: LumiColors.textDark),
          decoration: InputDecoration(
            counterText: maxLength != null ? '' : null,
            errorText: errorText,
            contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              borderSide: const BorderSide(color: LumiColors.secondaryLight, width: ArcadeSizes.fieldBorder),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              borderSide: const BorderSide(color: LumiColors.primaryPurple, width: ArcadeSizes.fieldBorder),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(LumiRadii.pill),
              borderSide: const BorderSide(color: LumiColors.redAlert, width: ArcadeSizes.fieldBorder),
            ),
          ),
        ),
      ],
    );
  }
}

/// Six single-character child-code boxes bound to one controller.
class ArcadeCodeField extends StatefulWidget {
  const ArcadeCodeField({
    super.key,
    required this.label,
    required this.controller,
    this.length = 6,
  });

  final String label;
  final TextEditingController controller;
  final int length;

  @override
  State<ArcadeCodeField> createState() => _ArcadeCodeFieldState();
}

class _ArcadeCodeFieldState extends State<ArcadeCodeField> {
  late final List<TextEditingController> _boxes;
  late final List<FocusNode> _nodes;

  @override
  void initState() {
    super.initState();
    _boxes = List.generate(widget.length, (_) => TextEditingController());
    _nodes = List.generate(widget.length, (_) => FocusNode());
    _syncFromMaster();
    widget.controller.addListener(_syncFromMaster);
  }

  void _syncFromMaster() {
    final text = widget.controller.text;
    for (var i = 0; i < widget.length; i++) {
      final ch = i < text.length ? text[i] : '';
      if (_boxes[i].text != ch) _boxes[i].text = ch;
    }
  }

  void _writeMaster() {
    final value = _boxes.map((c) => c.text).join();
    if (widget.controller.text != value) {
      widget.controller.value = TextEditingValue(
        text: value,
        selection: TextSelection.collapsed(offset: value.length),
      );
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_syncFromMaster);
    for (final c in _boxes) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(widget.label, style: LumiTheme.clanMedium(16, color: LumiColors.textDark)),
        const SizedBox(height: LumiSpacing.sm),
        LayoutBuilder(
          builder: (context, constraints) {
            final gap = 6.0;
            final boxW = ((constraints.maxWidth - gap * (widget.length - 1)) / widget.length)
                .clamp(32.0, ArcadeSizes.codeBoxW);
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: List.generate(widget.length, (i) {
                return SizedBox(
                  width: boxW,
                  height: ArcadeSizes.codeBoxH,
                  child: TextField(
                    controller: _boxes[i],
                    focusNode: _nodes[i],
                    textAlign: TextAlign.center,
                    maxLength: 1,
                    keyboardType: TextInputType.number,
                    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                    style: LumiTheme.clanMedium(20, color: LumiColors.textDark),
                    decoration: InputDecoration(
                      counterText: '',
                      contentPadding: EdgeInsets.zero,
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: LumiColors.secondaryLight,
                          width: ArcadeSizes.fieldBorder,
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: const BorderSide(
                          color: LumiColors.primaryPurple,
                          width: ArcadeSizes.fieldBorder,
                        ),
                      ),
                    ),
                    onChanged: (v) {
                      _writeMaster();
                      if (v.isNotEmpty && i < widget.length - 1) {
                        _nodes[i + 1].requestFocus();
                      } else if (v.isEmpty && i > 0) {
                        _nodes[i - 1].requestFocus();
                      }
                    },
                  ),
                );
              }),
            );
          },
        ),
      ],
    );
  }
}
