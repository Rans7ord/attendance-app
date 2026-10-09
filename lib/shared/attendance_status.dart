import 'package:flutter/material.dart';
import '../core/theme/app_theme.dart';

/// One place that decides how every attendance status looks, so the
/// calendar, Today's Attendance and the history lists can't drift apart.
class StatusStyle {
  final String label;
  final IconData icon;
  final Color color;
  final Color soft;

  /// Calendar cells fill with [color] (white text) when true, otherwise
  /// with [soft] (coloured text).
  final bool solid;

  const StatusStyle({
    required this.label,
    required this.icon,
    required this.color,
    required this.soft,
    this.solid = false,
  });
}

StatusStyle statusStyle(String status) {
  switch (status) {
    case 'present':
      return const StatusStyle(
        label: 'Present', icon: Icons.check_circle_rounded,
        color: AppColors.success, soft: AppColors.successSoft, solid: true,
      );
    case 'late':
      return const StatusStyle(
        label: 'Late', icon: Icons.schedule_rounded,
        color: AppColors.warning, soft: AppColors.warningSoft, solid: true,
      );
    case 'half_day':
      return const StatusStyle(
        label: 'Half day', icon: Icons.contrast_rounded,
        color: AppColors.accent, soft: AppColors.accentSoft, solid: true,
      );
    case 'open':
      return const StatusStyle(
        label: 'Clocked in', icon: Icons.timelapse_rounded,
        color: AppColors.info, soft: AppColors.infoSoft, solid: true,
      );
    case 'absent':
      return const StatusStyle(
        label: 'Absent', icon: Icons.cancel_rounded,
        color: AppColors.danger, soft: AppColors.dangerSoft, solid: true,
      );
    case 'incomplete':
      return const StatusStyle(
        label: 'No clock-out', icon: Icons.error_outline_rounded,
        color: AppColors.danger, soft: AppColors.dangerSoft,
      );
    case 'leave':
      return const StatusStyle(
        label: 'On leave', icon: Icons.beach_access_rounded,
        color: AppColors.primary, soft: AppColors.infoSoft,
      );
    case 'day_off':
      return const StatusStyle(
        label: 'Holiday', icon: Icons.celebration_rounded,
        color: AppColors.info, soft: AppColors.infoSoft,
      );
    case 'closed':
      return const StatusStyle(
        label: 'Off day', icon: Icons.weekend_rounded,
        color: AppColors.textMuted, soft: AppColors.surface,
      );
    case 'upcoming':
      return const StatusStyle(
        label: 'Upcoming', icon: Icons.hourglass_empty_rounded,
        color: AppColors.textSecondary, soft: AppColors.surfaceCard,
      );
    case 'not_joined':
      return const StatusStyle(
        label: 'Not joined yet', icon: Icons.person_off_outlined,
        color: AppColors.textMuted, soft: Colors.transparent,
      );
    case 'unscheduled':
      return const StatusStyle(
        label: 'No schedule', icon: Icons.help_outline_rounded,
        color: AppColors.textMuted, soft: AppColors.surface,
      );
    default:
      // A status this app version doesn't know about: show its real name
      // rather than mislabelling it.
      final words = status.replaceAll('_', ' ');
      final label = words.isEmpty ? 'Unknown' : words[0].toUpperCase() + words.substring(1);
      return StatusStyle(
        label: label, icon: Icons.help_outline_rounded,
        color: AppColors.textMuted, soft: AppColors.surface,
      );
  }
}
