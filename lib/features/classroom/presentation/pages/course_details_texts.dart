part of 'course_details_page.dart';

/// Split out of course_details_page.dart (unchanged code): sections that only
/// read the page's state.
extension _TextLocalization on _CourseDetailsPageState {
  String _localizeContent(String text) {
    final l10n = AppLocalizations.of(context)!;

    // 1. Normalize input (trim spaces)
    final trimmedText = text.trim();

    // 2. Define the lookup map (Reverse Mapping)
    // Key: Standard text in AR/EN/TR => Value: Localized string getter
    final Map<String, String> lookup = {
      // --- TOOLS ---
      // Bamboo Pen
      'Bamboo Pen': l10n.bambooPen,
      'Kamış Kalem': l10n.bambooPen,
      'قلم قصب (بامبو)': l10n.bambooPen,
      // Metal Nib
      'Metal Nib': l10n.metalNib,
      'Metal Uç': l10n.metalNib,
      'قلم معدني (Slater)': l10n.metalNib,
      'قلم معدني': l10n.metalNib,
      // Likka
      'Likka (Silk)': l10n.likkaSilk,
      'Lika (İpek)': l10n.likkaSilk,
      'ليقة (حرير)': l10n.likkaSilk,
      // Glossy Paper
      'Glossy Paper': l10n.glossyPaper,
      'Kuşe Kağıt': l10n.glossyPaper,
      'ورق مقهر (Lined/Glossy)': l10n.glossyPaper,
      'ورق مقهر': l10n.glossyPaper,
      // Ink
      'Ink': l10n.ink,
      'Mürekkep': l10n.ink,
      'حبر (Ecoline/Schmincke)': l10n.ink,
      'حبر': l10n.ink,
      // Ballpoint
      'Ballpoint Pen': l10n.ballpointPen,
      'Tükenmez Kalem': l10n.ballpointPen,
      'قلم جاف': l10n.ballpointPen,
      // Gel Pen
      'Gel Pen (0.5mm)': l10n.gelPen,
      'Jel Kalem (0.5mm)': l10n.gelPen,
      'قلم جل (0.5mm)': l10n.gelPen,
      // Notebook
      'Lined Notebook': l10n.linedNotebook,
      'Çizgili Defter': l10n.linedNotebook,
      'دفتر مسطر': l10n.linedNotebook,
      // Pencil/Eraser
      'Pencil & Eraser': l10n.pencilEraser,
      'Kurşun Kalem ve Silgi': l10n.pencilEraser,
      'قلم رصاص وممحاة': l10n.pencilEraser,
      // Correction Tape
      'Correction Tape': l10n.correctionTape,
      'Daksil': l10n.correctionTape,
      'مصحح (Correction Tape)': l10n.correctionTape,

      // --- CURRICULUM MODULES (Beginner Calligraphy) ---
      'Intro to Tools': l10n.introToTools,
      'Araçlara Giriş': l10n.introToTools,
      'مقدمة عن الأدوات': l10n.introToTools,
      'Holding the Pen': l10n.holdingThePen,
      'Kalem Tutuşu': l10n.holdingThePen,
      'طريقة مسك القلم': l10n.holdingThePen,
      'Dots (Nuqta)': l10n.dotsNuqta,
      'Noktalar (Mizan)': l10n.dotsNuqta,
      'النقط والميزان': l10n.dotsNuqta,
      'Letter Alif': l10n.letterAlif,
      'Elif Harfi': l10n.letterAlif,
      'حرف الألف': l10n.letterAlif,
      'Letters Ba-Ra': l10n.lettersBaRa,
      'Be-Ra Harfleri': l10n.lettersBaRa,
      'حروف الباء - الراء': l10n.lettersBaRa,

      // --- CURRICULUM MODULES (Intermediate Calligraphy) ---
      'Review Basics': l10n.reviewBasics,
      'Temellerin Gözden Geçirilmesi': l10n.reviewBasics,
      'مراجعة الأساسيات': l10n.reviewBasics,
      'Complex Connections': l10n.complexConnections,
      'Karmaşık Bağlantılar': l10n.complexConnections,
      'اتصالات الحروف المركبة': l10n.complexConnections,
      'Sentence Structure': l10n.sentenceStructure,
      'Cümle Yapısı': l10n.sentenceStructure,
      'tarkib (تركيب الجمل)': l10n.sentenceStructure,
      'تركيب الجمل': l10n.sentenceStructure,
      'Ink Control': l10n.inkControl,
      'Mürekkep Kontrolü': l10n.inkControl,
      'التحكم بالحبر': l10n.inkControl,

      // --- CURRICULUM MODULES (Advanced Calligraphy) ---
      'Composition Rules': l10n.compositionRules,
      'Kompozisyon Kuralları': l10n.compositionRules,
      'قواعد التكوين': l10n.compositionRules,
      'Jali (Large Scale)': l10n.jaliLargeScale,
      'Celi (Büyük Ölçekli)': l10n.jaliLargeScale,
      'الكتابة الجلية (Jali)': l10n.jaliLargeScale,
      'Gold Leaf': l10n.goldLeaf,
      'Altın Varak': l10n.goldLeaf,
      'التذهيب (Gold Leaf)': l10n.goldLeaf,
      'Masterpiece Creation': l10n.masterpieceCreation,
      'Eser Oluşturma': l10n.masterpieceCreation,
      'إنجاز اللوحة النهائية': l10n.masterpieceCreation,

      // --- CURRICULUM MODULES (Beginner Handwriting) ---
      'Hand Posture': l10n.handPosture,
      'El Duruşu': l10n.handPosture,
      'وضعية اليد والجلوس': l10n.handPosture,
      'Paper Position': l10n.paperPosition,
      'Kağıt Pozisyonu': l10n.paperPosition,
      'وضعية الورقة': l10n.paperPosition,
      'Basic Shapes': l10n.basicShapes,
      'Temel Şekiller': l10n.basicShapes,
      'الأشكال الأساسية': l10n.basicShapes,
      'Lowercase a-m': l10n.lowercaseAM,
      'Küçük Harfler a-m': l10n.lowercaseAM,
      'الحروف الصغيرة a-m': l10n.lowercaseAM,
      'Lowercase n-z': l10n.lowercaseNZ,
      'Küçük Harfler n-z': l10n.lowercaseNZ,
      'الحروف الصغيرة n-z': l10n.lowercaseNZ,

      // --- CURRICULUM MODULES (Intermediate Handwriting) ---
      'Connecting Letters': l10n.connectingLetters,
      'Harf Bağlantıları': l10n.connectingLetters,
      'وصل الحروف': l10n.connectingLetters,
      'Word Spacing': l10n.wordSpacing,
      'Kelime Boşlukları': l10n.wordSpacing,
      'المسافات بين الكلمات': l10n.wordSpacing,
      'Line Consistency': l10n.lineConsistency,
      'Satır Tutarlılığı': l10n.lineConsistency,
      'الاستقامة على السطر': l10n.lineConsistency,
      'Speed Writing': l10n.speedWriting,
      'Hızlı Yazma': l10n.speedWriting,
      'الكتابة السريعة': l10n.speedWriting,

      // --- CURRICULUM MODULES (Advanced Handwriting) ---
      'Cursive Style': l10n.cursiveStyle,
      'Bitişik El Yazısı Stili': l10n.cursiveStyle,
      'الكتابة المتصلة (Cursive)': l10n.cursiveStyle,
      'Signature Design': l10n.signatureDesign,
      'İmza Tasarımı': l10n.signatureDesign,
      'تصميم التوقيع': l10n.signatureDesign,
      'Fountain Pen Basics': l10n.fountainPenBasics,
      'Dolma Kalem Temelleri': l10n.fountainPenBasics,
      'أساسيات قلم الحبر السائل': l10n.fountainPenBasics,
      'Business Handwriting': l10n.businessHandwriting,
      'İş El Yazısı': l10n.businessHandwriting,
      'الكتابة الرسمية للأعمال': l10n.businessHandwriting,

      // --- LEGACY / THULUTH DEFAULTS ---
      'Intro to Thuluth': l10n.introToThuluth,
      'Sülüs\'e Giriş': l10n.introToThuluth,
      'مقدمة في خط الثلث': l10n.introToThuluth,
      'Letter Alif & Baa': l10n.letterAlifBaa,
      'Elif ve Ba Harfleri': l10n.letterAlifBaa,
      'حرف الألف والباء': l10n.letterAlifBaa,
      'Joint Letters': l10n.jointLetters,
      'Bitişik Harfler': l10n.jointLetters,
      'الحروف المتصلة': l10n.jointLetters,
      'Sentences': l10n.sentences,
      'Cümleler': l10n.sentences,
      'كتابة الجمل': l10n.sentences,
      'Final Project': l10n.finalProject,
      'Final Projesi': l10n.finalProject,
      'المشروع النهائي': l10n.finalProject,
    };

    return lookup[trimmedText] ?? text;
  }

  String _localizeDescription(String text) {
    if (text.isEmpty) return text;
    final l10n = AppLocalizations.of(context)!;
    final t = text.trim();

    // writingType logic from widget.courseData
    final wType = (widget.courseData['writingType'] as String? ?? "").trim();
    final cStyle = (widget.courseData['calligraphyStyle'] as String? ?? "")
        .trim();

    // Standard Description Substring Checks
    // We check for unique phrases from the Standard Descriptions in AR/EN/TR
    bool contains(List<String> fragments) {
      for (final f in fragments) {
        if (t.contains(f)) return true;
      }
      return false;
    }

    // --- NORMAL PEN WRITING ---
    if ([
      "Normal Pen Writing",
      "Normal Kalem Yazısı",
      "الكتابة بالقلم العادي",
    ].contains(wType)) {
      // Beginner Normal
      if (contains([
        "Transform your handwriting",
        "El yazınızı sıfırdan",
        "حول خط يدك من الصفر",
      ])) {
        return l10n.beginnerDescriptionNormal;
      }
      // Intermediate Normal
      if (contains([
        "Unlock the next level",
        "sonraki seviyenin kilidini",
        "افتح المستوى التالي",
      ])) {
        return l10n.intermediateDescriptionNormal;
      }
      // Advanced Normal
      if (contains([
        "Master the finest details",
        "en ince detaylarında",
        "أتقن أدق تفاصيل",
      ])) {
        return l10n.advancedDescriptionNormal;
      }
    }
    // --- CALLIGRAPHY ---
    else {
      // Reuse logic from _getLocalizedCourseName (simplified)
      String localizedStyle = cStyle;
      if (['Thuluth', 'Sülüs', 'الثلث'].contains(cStyle)) {
        localizedStyle = l10n.thuluth;
      } else if (['Naskh', 'Nesih', 'النسخ'].contains(cStyle)) {
        localizedStyle = l10n.naskh;
      } else if (['Diwani', 'Divani', 'الديواني'].contains(cStyle)) {
        localizedStyle = l10n.diwani;
      } else if (['Kufi', 'Kufic', 'الكوفي', 'كوفي'].contains(cStyle)) {
        localizedStyle = l10n.kufi;
      } else if ([
        'Ruq\'ah',
        'Ruqah',
        'Rika',
        'الرقعة',
        'رقعة',
      ].contains(cStyle)) {
        localizedStyle = l10n.ruqah;
      } else if (['Jali Thuluth', 'Celi Sülüs', 'ثلث جلي'].contains(cStyle)) {
        localizedStyle = l10n.jaliThuluth;
      } else if ([
        'Jali Diwani',
        'Celi Divani',
        'ديواني جلي',
      ].contains(cStyle)) {
        localizedStyle = l10n.jaliDiwani;
      } else if ([
        'Persian (Ta\'liq)',
        'Nestalik (Farsça)',
        'نستعليق (فارسي)',
      ].contains(cStyle)) {
        localizedStyle = l10n.persianTaliq;
      } else if (['Ijaza', 'İcazet', 'إجازة'].contains(cStyle)) {
        localizedStyle = l10n.ijaza;
      } else if (['Muhaqqaq', 'Muhakkak', 'محقق'].contains(cStyle)) {
        localizedStyle = l10n.muhaqqaq;
      } else if (['Rayhani', 'Reyhani', 'ريحاني'].contains(cStyle)) {
        localizedStyle = l10n.rayhani;
      } else {
        localizedStyle = l10n.arabicCalligraphy;
      }

      // Beginner Calligraphy
      if (contains([
        "Embark on your journey",
        "yolculuğunuza başlayın",
        "ابدأ رحلتك في خط",
      ])) {
        return l10n.beginnerDescriptionCalligraphy(localizedStyle);
      }
      // Intermediate Calligraphy
      if (contains([
        "Expand your artistic capabilities",
        "yeteneklerinizi genişletin",
        "وسع قدراتك الفنية",
      ])) {
        return l10n.intermediateDescriptionCalligraphy(localizedStyle);
      }
      // Advanced Calligraphy
      if (contains([
        "Attain the highest level",
        "seviyesine ulaşın",
        "أعلى مستويات المهارة",
      ])) {
        return l10n.advancedDescriptionCalligraphy(localizedStyle);
      }
    }

    return text; // Return original if no standard template detected
  }
}
