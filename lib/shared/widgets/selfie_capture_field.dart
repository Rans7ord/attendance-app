import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../../core/theme/app_theme.dart';

/// A circular "take a selfie" control. Opens the device camera (or the
/// browser's camera/file prompt on web) via image_picker, shows a preview
/// once captured, and lets the person retake it.
///
/// [required] only affects the label/helper text shown here — the server is
/// the actual source of truth for whether a photo is mandatory, since that's
/// a per-company admin setting this widget doesn't know about on its own.
class SelfieCaptureField extends StatefulWidget {
  final ValueChanged<XFile?> onChanged;
  final bool required;

  const SelfieCaptureField({super.key, required this.onChanged, this.required = true});

  @override
  State<SelfieCaptureField> createState() => _SelfieCaptureFieldState();
}

class _SelfieCaptureFieldState extends State<SelfieCaptureField> {
  XFile? _photo;
  Uint8List? _previewBytes;
  bool _capturing = false;

  Future<void> _capture() async {
    setState(() => _capturing = true);
    try {
      final picked = await ImagePicker().pickImage(
        source: ImageSource.camera,
        preferredCameraDevice: CameraDevice.front,
        maxWidth: 640,
        imageQuality: 70,
      );
      if (picked == null) return;

      final bytes = await picked.readAsBytes();
      setState(() {
        _photo = picked;
        _previewBytes = bytes;
      });
      widget.onChanged(picked);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open the camera')),
        );
      }
    } finally {
      if (mounted) setState(() => _capturing = false);
    }
  }

  void _clear() {
    setState(() {
      _photo = null;
      _previewBytes = null;
    });
    widget.onChanged(null);
  }

  @override
  Widget build(BuildContext context) {
    final hasPhoto = _previewBytes != null;

    return Column(
      children: [
        GestureDetector(
          onTap: _capturing ? null : _capture,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 112,
                height: 112,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: hasPhoto ? null : AppGradients.brand,
                  color: hasPhoto ? AppColors.surface : null,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withValues(alpha: 0.20),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                padding: const EdgeInsets.all(3),
                child: ClipOval(
                  child: Container(
                    color: AppColors.surface,
                    child: _capturing
                        ? const Center(
                            child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 2.4),
                            ),
                          )
                        : hasPhoto
                            ? Image.memory(_previewBytes!, fit: BoxFit.cover)
                            : const Icon(Icons.camera_alt_rounded, size: 34, color: AppColors.primary),
                  ),
                ),
              ),
              Positioned(
                bottom: 0,
                right: 0,
                child: Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    border: Border.all(color: AppColors.surfaceCard, width: 3),
                  ),
                  child: Icon(
                    hasPhoto ? Icons.edit_rounded : Icons.add_a_photo_rounded,
                    size: 16,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.sm),
        Text(
          hasPhoto ? 'Selfie captured' : (widget.required ? 'Take a selfie (required)' : 'Take a selfie (optional)'),
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: hasPhoto ? AppColors.success : AppColors.textSecondary,
                fontWeight: hasPhoto ? FontWeight.w600 : FontWeight.w400,
              ),
        ),
        if (hasPhoto)
          TextButton.icon(
            onPressed: _clear,
            icon: const Icon(Icons.refresh_rounded, size: 16),
            label: const Text('Retake'),
          ),
      ],
    );
  }
}