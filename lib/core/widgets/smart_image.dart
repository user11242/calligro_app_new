import 'package:flutter/material.dart';
import 'package:cached_network_image/cached_network_image.dart';

class SmartImage extends StatelessWidget {
  final String imageUrl;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Widget? placeholder;
  final Widget? errorWidget;
  final ColorFilter? colorFilter;
  final BorderRadius? borderRadius;

  const SmartImage({
    super.key,
    required this.imageUrl,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.placeholder,
    this.errorWidget,
    this.colorFilter,
    this.borderRadius,
  });

  @override
  Widget build(BuildContext context) {
    Widget image;
    
    // Support local assets that are assigned as default course banners
    if (imageUrl.startsWith('assets/')) {
      Widget assetImage = Image.asset(
        imageUrl,
        width: width,
        height: height,
        fit: fit,
        errorBuilder: (context, error, stackTrace) => errorWidget ?? const Icon(Icons.error),
      );
      
      if (colorFilter != null) {
        assetImage = ColorFiltered(
          colorFilter: colorFilter!,
          child: assetImage,
        );
      }
      image = assetImage;
    } else {
      // Normal network image
      image = CachedNetworkImage(
        imageUrl: imageUrl,
        width: width,
        height: height,
        fit: fit,
        placeholder: (context, url) => placeholder ?? const Center(child: CircularProgressIndicator()),
        errorWidget: (context, url, error) => errorWidget ?? const Icon(Icons.error),
        imageBuilder: (context, imageProvider) {
          Widget result = Image(
            image: imageProvider,
            fit: fit,
            width: width,
            height: height,
          );

          if (colorFilter != null) {
            result = ColorFiltered(
              colorFilter: colorFilter!,
              child: result,
            );
          }

          return result;
        },
      );
    }

    if (borderRadius != null) {
      image = ClipRRect(
        borderRadius: borderRadius!,
        child: image,
      );
    }

    return image;
  }
}
