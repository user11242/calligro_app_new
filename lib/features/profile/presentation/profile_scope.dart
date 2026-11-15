import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/features/community/data/firestore_community_repository.dart';

import '../data/firestore_profile_editor.dart';
import '../data/firestore_profile_repository.dart';
import '../data/profile_device_adapters.dart';
import '../domain/profile_models.dart';
import '../domain/profile_repositories.dart';

/// Everything the profile screens talk to. The ONLY place that picks the real
/// (Firebase) implementations — tests put fakes in a [ProfileScope].
class ProfileServices {
  ProfileServices({
    required this.profiles,
    required this.counts,
    required this.followLists,
    required this.courses,
    required this.reviews,
    required this.viewer,
    required this.editor,
    required this.photos,
    required this.phones,
    required this.pickPhoto,
  });

  factory ProfileServices.firebase({FirebaseFirestore? firestore, FirebaseAuth? auth}) => ProfileServices(
        profiles: FirestoreProfileRepository(firestore: firestore),
        counts: FirestoreProfileCountsRepository(
            firestore: firestore, community: FirestoreCommunityRepository(firestore: firestore)),
        followLists: FirestoreFollowListRepository(firestore: firestore),
        courses: FirestoreTeacherCoursesRepository(firestore: firestore),
        reviews: FirestoreTeacherReviewsRepository(firestore: firestore),
        viewer: FirebaseProfileViewerSource(auth: auth, firestore: firestore),
        editor: FirestoreProfileEditorRepository(firestore: firestore),
        photos: FirebaseProfilePhotoUploader(),
        phones: LibPhoneNumberChecker(),
        pickPhoto: pickProfilePhotoFromGallery,
      );

  final ProfileRepository profiles;
  final ProfileCountsRepository counts;
  final FollowListRepository followLists;
  final TeacherCoursesRepository courses;
  final TeacherReviewsRepository reviews;
  final ProfileViewerSource viewer;

  // Editing your own profile.
  final ProfileEditorRepository editor;
  final ProfilePhotoUploader photos;
  final PhoneNumberChecker phones;
  final ProfilePhotoPicker pickPhoto;
}

/// Provides [ProfileServices] below it; without one the real Firebase services are used.
class ProfileScope extends InheritedWidget {
  const ProfileScope({super.key, required this.services, required super.child});

  final ProfileServices services;
  static ProfileServices? _firebase;

  static ProfileServices of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ProfileScope>()?.services ??
      (_firebase ??= ProfileServices.firebase());

  @override
  bool updateShouldNotify(ProfileScope oldWidget) => services != oldWidget.services;
}

/// Loads the viewer once for a screen.
class ProfileViewerGate extends StatefulWidget {
  const ProfileViewerGate({super.key, required this.builder, this.loading});

  final Widget Function(BuildContext context, ProfileViewer viewer) builder;
  final Widget? loading;

  @override
  State<ProfileViewerGate> createState() => _ProfileViewerGateState();
}

class _ProfileViewerGateState extends State<ProfileViewerGate> {
  ProfileViewer? _viewer;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    ProfileScope.of(context).viewer.currentViewer().then((v) {
      if (mounted) setState(() => _viewer = v);
    }, onError: (Object e) {
      debugPrint('Viewer could not be loaded: $e');
      if (mounted) setState(() => _viewer = ProfileViewer.guest);
    });
  }

  @override
  Widget build(BuildContext context) {
    final viewer = _viewer;
    if (viewer == null) {
      return widget.loading ??
          const Scaffold(
            backgroundColor: AppColors.primary,
            body: Center(child: CircularProgressIndicator(color: AppColors.accentGold)),
          );
    }
    return widget.builder(context, viewer);
  }
}
