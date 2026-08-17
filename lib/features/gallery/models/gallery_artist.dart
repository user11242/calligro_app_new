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
    // Remove diacritics and normalize
    final clean = trim()
        .replaceAll('آ', 'ا')
        .replaceAll('إ', 'ا')
        .replaceAll('أ', 'ا')
        .replaceAll('ّ', '')
        .toLowerCase();

    final Map<String, Map<String, String>> translations = {
      'ali ghalib|علي غالب': {
        'en': 'Ali Ghalib',
        'ar': 'علي غالب',
        'tr': 'Ali Galip',
      },
      'abbas albaghdadi|عباس البغدادي|albaghdadi': {
        'en': 'Abbas Al-Baghdadi',
        'ar': 'عباس البغدادي',
        'tr': 'Abbas el-Bağdadi',
      },
      'ottoman|عثماني': {
        'en': 'Ottoman Maps',
        'ar': 'الخرائط العثمانية',
        'tr': 'Osmanlı Haritaları',
      },
      'varieties|منوعات': {
        'en': 'Varieties',
        'ar': 'منوعات',
        'tr': 'Çeşitler',
      },
      'riqaa|رقاع|رقعة': {
        'en': 'Riqaa Script',
        'ar': 'خط الرقعة',
        'tr': 'Rika Hattı',
      },
      'diwani|ديواني': {
        'en': 'Diwani Script',
        'ar': 'الخط الديواني',
        'tr': 'Divani Hattı',
      },
      'naskh|نسخ': {
        'en': 'Naskh Script',
        'ar': 'خط النسخ',
        'tr': 'Nesih Hattı',
      },
      'thuluth|ثلث': {
        'en': 'Thuluth Script',
        'ar': 'خط الثلث',
        'tr': 'Sülüs Hattı',
      },
      'ahmed kamil|احمد الكامل|احمد كامل': {
        'en': 'Ahmed Kamil',
        'ar': 'أحمد الكامل',
        'tr': 'Ahmet Kamil',
      },
      'ismail hakki|اسماعيل حقي': {
        'en': 'Ismail Hakki',
        'ar': 'إسماعيل حقي',
        'tr': 'İsmail Hakkı',
      },
      'sami|سامي': {
        'en': 'Sami Efendi',
        'ar': 'سامي أفندي',
        'tr': 'Sami Efendi',
      },
      'sevki|شوقي': {
        'en': 'Mehmet Sevki',
        'ar': 'محمد شوقي',
        'tr': 'Mehmet Şevki',
      },
      'amidi|حامد|الامدي': {
        'en': 'Hamid Al-Amidi',
        'ar': 'حامد الآمدي',
        'tr': 'Hamid Aytaç',
      },
      'hafiz osman|حافظ عثمان': {
        'en': 'Hafiz Osman',
        'ar': 'حافظ عثمان',
        'tr': 'Hafız Osman',
      },
      'rakim|راقم': {
        'en': 'Mustafa Rakim',
        'ar': 'مصطفى راقم',
        'tr': 'Mustafa Rakım',
      },
      'hashim|هاشم': {
        'en': 'Hashim Al-Baghdadi',
        'ar': 'هاشم البغدادي',
        'tr': 'Haşim el-Bağdadi',
      },
      'rida|رضا': {
        'en': 'Hasan Rida',
        'ar': 'حسن رضا',
        'tr': 'Hasan Rıza',
      },
      'arif|عارف': {
        'en': 'Arif Efendi',
        'ar': 'عارف أفندي',
        'tr': 'Arif Efendi',
      },
      'ahmad al-arif|احمد العارف': {
        'en': 'Ahmad Al-Arif',
        'ar': 'أحمد العارف',
        'tr': 'Ahmet El-Arif',
      },
      'bakkal|بقّال|بقال': {
        'en': 'Bakkal Arif',
        'ar': 'بقّال عارف',
        'tr': 'Bakkal Arif',
      },
      'zuhdi|زهدي': {
        'en': 'Ismail Zuhdi',
        'ar': 'إسماعيل زُهدي',
        'tr': 'İsmail Zühdi',
      },
      'halim|حليم': {
        'en': 'Halim Ozyazici',
        'ar': 'حليم أوزيازجي',
        'tr': 'Halim Özyazıcı',
      },
      'hamdullah|حمدالله|حمد الله': {
        'en': 'Sheikh Hamdullah',
        'ar': 'الشيخ حمد الله الأماسي',
        'tr': 'Şeyh Hamdullah',
      },
      'shafiq|شفيق': {
        'en': 'Shafiq Bey',
        'ar': 'شفيق بك',
        'tr': 'Şefik Bey',
      },
      'nazif|نظيف|ناظف': {
        'en': 'Nazif Bey',
        'ar': 'محمد ناظف بك',
        'tr': 'Nazif Bey',
      },
      'yaqut|ياقوت': {
        'en': 'Yaqut al-Mustaasimi',
        'ar': 'ياقوت المستعصمي',
        'tr': 'Yâkût el-Müsta\'sımî',
      },
      'izzat|عزت': {
        'en': 'Mustafa Izzat',
        'ar': 'مصطفى عزت',
        'tr': 'Mustafa İzzet',
      },
    };

    for (var entry in translations.entries) {
      final keyWords = entry.key.split('|');
      
      final en = entry.value['en']!.toLowerCase();
      final ar = entry.value['ar']!.replaceAll('آ', 'ا').replaceAll('إ', 'ا').replaceAll('أ', 'ا').replaceAll('ّ', '').toLowerCase();
      final tr = entry.value['tr']!.toLowerCase();

      bool matched = false;

      // Match by exact canonical names
      if (clean == en || clean == ar || clean == tr) {
         matched = true;
      }

      // Match by aliases inside the key
      if (!matched) {
         for (final kw in keyWords) {
            if (clean.contains(kw) || kw.contains(clean) && clean.length > 3) {
               matched = true;
               break;
            }
         }
      }

      if (matched) {
        return entry.value[locale] ?? this;
      }
    }

    return this;
  }
}

