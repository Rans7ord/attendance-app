import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_theme.dart';

/// A 4-box PIN entry field. Typing a digit auto-advances to the next box;
/// backspace on an empty box moves back. Reports the full 4-digit string
/// via [onCompleted] once all boxes are filled, and always via [onChanged]
/// (which may be shorter than 4 digits mid-entry).
class PinCodeField extends StatefulWidget {
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onCompleted;
  final bool obscure;

  const PinCodeField({super.key, this.onChanged, this.onCompleted, this.obscure = false});

  @override
  State<PinCodeField> createState() => PinCodeFieldState();
}

class PinCodeFieldState extends State<PinCodeField> {
  final List<TextEditingController> _controllers = List.generate(4, (_) => TextEditingController());
  final List<FocusNode> _nodes = List.generate(4, (_) => FocusNode());

  String get value => _controllers.map((c) => c.text).join();

  void clear() {
    for (final c in _controllers) {
      c.clear();
    }
    _nodes.first.requestFocus();
  }

  void _handleChanged(int index, String digit) {
    if (digit.isNotEmpty && index < 3) {
      _nodes[index + 1].requestFocus();
    }
    widget.onChanged?.call(value);
    if (value.length == 4) {
      widget.onCompleted?.call(value);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    for (final n in _nodes) {
      n.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(4, (i) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 6),
          child: SizedBox(
            width: 56,
            height: 64,
            child: KeyboardListener(
              focusNode: FocusNode(skipTraversal: true),
              onKeyEvent: (event) {
                if (event is KeyDownEvent &&
                    event.logicalKey == LogicalKeyboardKey.backspace &&
                    _controllers[i].text.isEmpty &&
                    i > 0) {
                  _nodes[i - 1].requestFocus();
                  _controllers[i - 1].clear();
                  widget.onChanged?.call(value);
                }
              },
              child: TextField(
                controller: _controllers[i],
                focusNode: _nodes[i],
                obscureText: widget.obscure,
                textAlign: TextAlign.center,
                keyboardType: TextInputType.number,
                maxLength: 1,
                style: Theme.of(context).textTheme.headlineSmall,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: InputDecoration(
                  counterText: '',
                  contentPadding: EdgeInsets.zero,
                  filled: true,
                  fillColor: AppColors.surfaceCard,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.border),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(AppRadius.md),
                    borderSide: const BorderSide(color: AppColors.primary, width: 1.6),
                  ),
                ),
                onChanged: (v) => _handleChanged(i, v),
              ),
            ),
          ),
        );
      }),
    );
  }
}