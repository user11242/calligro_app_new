import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/widgets.dart';

import 'package:calligro_app/features/community/data/community_device_adapters.dart';
import 'package:calligro_app/features/community/data/firestore_community_adapters.dart';
import 'package:calligro_app/features/community/data/firestore_community_repository.dart';
import 'package:calligro_app/features/community/domain/repositories/community_repositories.dart';

/// Everything the community screens talk to. The ONLY place that picks real
/// (Firebase) implementations — tests put fakes in a [CommunityScope].
class CommunityServices {
  CommunityServices({
    required this.repository,
    required this.follows,
    required this.users,
    required this.sessions,
    required this.media,
    required this.translator,
    required this.imagePicker,
  });

  /// Real services. Pass [firestore] / [auth] to run against fakes (dashboard tests).
  factory CommunityServices.firebase({FirebaseFirestore? firestore, FirebaseAuth? auth}) => CommunityServices(
        repository: FirestoreCommunityRepository(firestore: firestore),
        follows: FirestoreFollowRepository(firestore: firestore),
        users: FirestoreCommunityUserRepository(firestore: firestore),
        sessions: FirebaseCommunitySessionSource(auth: auth, firestore: firestore),
        media: FirebaseCommunityMediaStorage(),
        translator: ServiceCommunityTranslator(),
        imagePicker: AssetCommunityImagePicker.new,
      );

  final CommunityRepository repository;
  final FollowRepository follows;
  final CommunityUserRepository users;
  final CommunitySessionSource sessions;
  final CommunityMediaStorage media;
  final CommunityTranslator translator;

  /// The gallery picker needs a BuildContext.
  final CommunityImagePicker Function(BuildContext context) imagePicker;
}

/// Provides [CommunityServices] to the community widgets below it.
/// Without a scope (the normal app) the real Firebase services are used.
class CommunityScope extends InheritedWidget {
  const CommunityScope({super.key, required this.services, required super.child});

  final CommunityServices services;

  static CommunityServices? _firebase;

  static CommunityServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CommunityScope>()?.services ??
      (_firebase ??= CommunityServices.firebase());

  @override
  bool updateShouldNotify(CommunityScope oldWidget) => services != oldWidget.services;
}
