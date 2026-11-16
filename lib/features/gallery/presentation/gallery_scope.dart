import 'package:flutter/widgets.dart';

import '../data/gallery_service.dart';
import '../domain/gallery_models.dart';

/// The ONE place that picks the real gallery implementations.
class GalleryServices {
  GalleryServices({required this.gallery, required this.urls});
  final GalleryRepository gallery;
  final ImageUrlResolver urls;

  static GalleryServices? _instance;
  static GalleryServices get instance => _instance ??= GalleryServices(gallery: GalleryService(), urls: StorageUrlResolver());
}

class GalleryScope extends InheritedWidget {
  const GalleryScope({super.key, required this.services, required super.child});
  final GalleryServices services;

  static GalleryServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<GalleryScope>()?.services ?? GalleryServices.instance;

  @override
  bool updateShouldNotify(GalleryScope oldWidget) => services != oldWidget.services;
}
