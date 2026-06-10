import 'package:flutter/material.dart';
import '../constants/app_text.dart';

class MedicalDisclaimerBanner extends StatelessWidget {
  final String? message;
  final IconData? icon;
  final Color? color;
  final Widget? trailing;

  const MedicalDisclaimerBanner({
    super.key,
    this.message,
    this.icon,
    this.color,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final bannerColor = color ?? Colors.redAccent;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      color: bannerColor.withValues(alpha: 0.08),
      child: Row(
        children: [
          Icon(icon ?? Icons.warning_amber_rounded,
              color: bannerColor, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message ?? AppText.emergencyWarning,
              style: TextStyle(
                  color: bannerColor == Colors.redAccent 
                      ? Colors.redAccent.shade100 
                      : bannerColor, 
                  fontSize: 13),
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: 8),
            trailing!,
          ],
        ],
      ),
    );
  }
}
