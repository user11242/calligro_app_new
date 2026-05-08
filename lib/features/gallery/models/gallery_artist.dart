import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/widgets.dart';

class GalleryArtist {
  final String id;
  final String name;
  final String bio;
  final String? photoUrl;
  final String? birthDate;
  final String? deathDate;
  final String? lifeDetails;
  final DateTime? createdAt;

  GalleryArtist({
    required this.id,
    required this.name,
    required this.bio,
    this.photoUrl,
    this.birthDate,
    this.deathDate,
    this.lifeDetails,
    this.createdAt,
  });

  factory GalleryArtist.fromFirestore(DocumentSnapshot doc) {
    Map<String, dynamic> data = doc.data() as Map<String, dynamic>;
    return GalleryArtist(
      id: doc.id,
      name: data['name'] ?? '',
      bio: data['bio'] ?? '',
      photoUrl: data['photoUrl'],
      birthDate: data['birthDate'],
      deathDate: data['deathDate'],
      lifeDetails: data['lifeDetails'],
      createdAt: (data['createdAt'] as Timestamp?)?.toDate(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'bio': bio,
      'photoUrl': photoUrl,
      'birthDate': birthDate,
      'deathDate': deathDate,
      'lifeDetails': lifeDetails,
      'createdAt': createdAt != null ? Timestamp.fromDate(createdAt!) : FieldValue.serverTimestamp(),
    };
  }
}

extension LocalizedArtist on GalleryArtist {
  String localizedName(BuildContext context) {
    return name.localizedName(context);
  }
}

extension LocalizedString on String {
  String localizedName(BuildContext context) {
    final locale = Localizations.localeOf(context).languageCode;
    final clean = trim().replaceAll('آ', 'ا').replaceAll('إ', 'ا').replaceAll('أ', 'ا').toLowerCase();

    final Map<String, Map<String, String>> translations = {
      'ali ghalib': {
        'en': 'Ali Ghalib',
        'ar': 'علي غالب',
        'tr': 'Ali Galip',
      },
      'abbas albaghdadi': {
        'en': 'Abbas Al-Baghdadi',
        'ar': 'عباس البغدادي',
        'tr': 'Abbas el-Bağdadi',
      },
      'albaghdadi': {
        'en': 'Abbas Al-Baghdadi',
        'ar': 'عباس البغدادي',
        'tr': 'Abbas el-Bağdadi',
      },
      'ottoman': {
        'en': 'Ottoman Maps',
        'ar': 'الخرائط العثمانية',
        'tr': 'Osmanlı Haritaları',
      },
      'varieties': {
        'en': 'Varieties',
        'ar': 'منوعات',
        'tr': 'Çeşitler',
      },
      'riqaa': {
        'en': 'Riqaa Script',
        'ar': 'خط الرقعة',
        'tr': 'Rika Hattı',
      },
      'diwani': {
        'en': 'Diwani Script',
        'ar': 'الخط الديواني',
        'tr': 'Divani Hattı',
      },
      'naskh': {
        'en': 'Naskh Script',
        'ar': 'خط النسخ',
        'tr': 'Nesih Hattı',
      },
      'thuluth': {
        'en': 'Thuluth Script',
        'ar': 'خط الثلث',
        'tr': 'Sülüs Hattı',
      },
      'احمد الكامل': {
        'en': 'Ahmed Kamil',
        'ar': 'أحمد الكامل',
        'tr': 'Ahmet Kamil',
      },
      'اسماعيل حقي': {
        'en': 'Ismail Hakki',
        'ar': 'إسماعيل حقي',
        'tr': 'İsmail Hakkı',
      },
      'سامي افندي': {
        'en': 'Sami Efendi',
        'ar': 'سامي أفندي',
        'tr': 'Sami Efendi',
      },
      'محمد شوقي': {
        'en': 'Mehmet Sevki',
        'ar': 'محمد شوقي',
        'tr': 'Mehmet Şevki',
      },
      'حامد الامدي': {
        'en': 'Hamid Al-Amidi',
        'ar': 'حامد الآمدي',
        'tr': 'Hamid Aytaç',
      },
      'حافظ عثمان': {
        'en': 'Hafiz Osman',
        'ar': 'حافظ عثمان',
        'tr': 'Hafız Osman',
      },
      'مصطفى راقم': {
        'en': 'Mustafa Rakim',
        'ar': 'مصطفى راقم',
        'tr': 'Mustafa Rakım',
      },
      'هاشم البغدادي': {
        'en': 'Hashim Al-Baghdadi',
        'ar': 'هاشم البغدادي',
        'tr': 'Haşim el-Bağdadi',
      },
      'حسن رضا': {
        'en': 'Hasan Rida',
        'ar': 'حسن رضا',
        'tr': 'Hasan Rıza',
      },
      'عارف': {
        'en': 'Arif Efendi',
        'ar': 'عارف أفندي',
        'tr': 'Arif Efendi',
      },
      'بقّال': {
        'en': 'Bakkal Arif',
        'ar': 'بقّال عارف',
        'tr': 'Bakkal Arif',
      },
      'زهدي': {
        'en': 'Ismail Zuhdi',
        'ar': 'إسماعيل زُهدي',
        'tr': 'İsmail Zühdi',
      },
      'حليم': {
        'en': 'Halim Ozyazici',
        'ar': 'حليم أوزيازجي',
        'tr': 'Halim Özyazıcı',
      },
      'حمدالله': {
        'en': 'Sheikh Hamdullah',
        'ar': 'الشيخ حمد الله الأماسي',
        'tr': 'Şeyh Hamdullah',
      },
      'شفيق': {
        'en': 'Shafiq Bey',
        'ar': 'شفيق بك',
        'tr': 'Şefik Bey',
      },
      'نظيف': {
        'en': 'Nazif Bey',
        'ar': 'محمد ناظف بك',
        'tr': 'Nazif Bey',
      },
      'ياقوت': {
        'en': 'Yaqut al-Mustaasimi',
        'ar': 'ياقوت المستعصمي',
        'tr': 'Yâkût el-Müsta\'sımî',
      },
      'مصطفى عزت': {
        'en': 'Mustafa Izzat',
        'ar': 'مصطفى عزت',
        'tr': 'Mustafa İzzet',
      },
    };

    for (var entry in translations.values) {
      final en = entry['en']!.toLowerCase();
      final ar = entry['ar']!.replaceAll('آ', 'ا').replaceAll('إ', 'ا').replaceAll('أ', 'ا').toLowerCase();
      final tr = entry['tr']!.toLowerCase();

      if (clean == en || clean == ar || clean == tr || 
          clean.contains(en) || clean.contains(ar) || clean.contains(tr) ||
          toLowerCase().contains(en)) {
        return entry[locale] ?? this;
      }
    }

    return this;
  }
}

