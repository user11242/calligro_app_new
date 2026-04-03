import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/core/widgets/smart_image.dart';

class ProfileAvatar extends StatelessWidget {
  final String? imageUrl;
  final double radius;
  final String? heroTag;
  final VoidCallback? onTap;
  final Color? backgroundColor;
  final IconData placeholderIcon;

  const ProfileAvatar({
    super.key,
    required this.imageUrl,
    this.radius = 22,
    this.heroTag,
    this.onTap,
    this.backgroundColor,
    this.placeholderIcon = Icons.person,
  });

  @override
  Widget build(BuildContext context) {
    Widget avatar = CircleAvatar(
      radius: radius,
      backgroundColor: backgroundColor ?? AppColors.goldGradientEnd,
      child: _buildImage(),
    );

    if (heroTag != null) {
      avatar = Hero(
        tag: heroTag!,
        child: avatar,
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatar,
      );
    }

    return avatar;
  }

  Widget _buildImage() {
    if (imageUrl == null || imageUrl!.isEmpty) {
      return Icon(
        placeholderIcon,
        color: AppColors.primary,
        size: radius * 1.2,
      );
    }

    return SmartImage(
      imageUrl: imageUrl!,
      width: radius * 2,
      height: radius * 2,
      fit: BoxFit.cover,
      borderRadius: BorderRadius.circular(radius * 2),
      placeholder: Container(
        color: AppColors.goldGradientEnd.withOpacity(0.1),
        child: Icon(
          placeholderIcon,
          color: AppColors.primary.withOpacity(0.3),
          size: radius * 1.2,
        ),
      ),
      errorWidget: Icon(
        placeholderIcon,
        color: AppColors.primary,
        size: radius * 1.2,
      ),
    );
  }
}
