import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_tr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('tr'),
  ];

  /// No description provided for @born.
  ///
  /// In en, this message translates to:
  /// **'Born'**
  String get born;

  /// No description provided for @died.
  ///
  /// In en, this message translates to:
  /// **'Died'**
  String get died;

  /// No description provided for @lifeDuration.
  ///
  /// In en, this message translates to:
  /// **'Life Duration'**
  String get lifeDuration;

  /// No description provided for @viewWorks.
  ///
  /// In en, this message translates to:
  /// **'View Works'**
  String get viewWorks;

  /// No description provided for @paste.
  ///
  /// In en, this message translates to:
  /// **'Paste'**
  String get paste;

  /// No description provided for @ahmadKamelBornYear.
  ///
  /// In en, this message translates to:
  /// **'1861'**
  String get ahmadKamelBornYear;

  /// No description provided for @ahmadKamelDiedYear.
  ///
  /// In en, this message translates to:
  /// **'1941'**
  String get ahmadKamelDiedYear;

  /// No description provided for @ahmadKamelLifeDescription.
  ///
  /// In en, this message translates to:
  /// **'80 years, died in Istanbul'**
  String get ahmadKamelLifeDescription;

  /// No description provided for @ahmadKamelBio.
  ///
  /// In en, this message translates to:
  /// **'Ahmad Kamil Akdik was one of the most prominent calligraphers of the late Ottoman Empire and early Republican era in Turkey. He was among the last representatives of the classical Ottoman school in Thuluth and Naskh scripts.\n\nBorn in Istanbul, he received his artistic education in a traditional setting, learning Thuluth and Naskh from the famous calligrapher Mehmet Şevki Efendi. He was also influenced by great masters of his time, particularly Sami Efendi, which artistically linked him to the late classical lineage of Ottoman calligraphy.\n\nHe worked in several official clerical positions in Istanbul before dedicating himself to teaching and producing calligraphy. When the School of Calligraphers (Medresetü\'l-Hattâtîn) was founded, he was appointed among its instructors, teaching Thuluth and Naskh and contributing to the preparation of a generation of calligraphers during a delicate transition period between the Ottoman and Republican eras.\n\nHe was known for his rigorous precision in observing proportions, the strength of his letter construction, and his full commitment to the classical rules that had settled in the 19th century.\n\nHe transcribed several copies of the Holy Quran and wrote religious panels, hilyes, and various calligraphic works. His writings are characterized by clarity of composition, balanced lines, and economy in decoration. In modern studies, he is viewed as a fundamental link in transferring the traditions of the late Ottoman school to the 20th century, before the emergence of subsequent renewal trends.'**
  String get ahmadKamelBio;

  /// No description provided for @hasanRidaBornYear.
  ///
  /// In en, this message translates to:
  /// **'1849'**
  String get hasanRidaBornYear;

  /// No description provided for @hasanRidaDiedYear.
  ///
  /// In en, this message translates to:
  /// **'1910'**
  String get hasanRidaDiedYear;

  /// No description provided for @hasanRidaLifeDescription.
  ///
  /// In en, this message translates to:
  /// **'61 years, died in Istanbul'**
  String get hasanRidaLifeDescription;

  /// No description provided for @hasanRidaBio.
  ///
  /// In en, this message translates to:
  /// **'Hasan Rıza Efendi was one of the calligraphers of the late Ottoman Empire known for his mastery of the Thuluth and Naskh scripts, and for maintaining the classical style that was established in the nineteenth century.\n\nBorn in the city of Amasya, one of the cities that produced a number of Ottoman calligraphy giants, he received his early education there before moving to Istanbul to complete his artistic training in the environment of the great calligraphers.\n\nHe studied under several masters of his time in Istanbul and was influenced by the school of Mehmet Şevki Efendi, which represented the late classical peak in Thuluth and Naskh.\n\nHasan Rıza Efendi was known for his extreme care in adjusting proportions, the precision of letter formation, and the harmony of lines, so much so that he was considered among the distinguished calligraphers in transcribing the Holy Quran. He also wrote religious paintings, hilyes, and other calligraphic works that reflect his strict commitment to inherited Ottoman rules.\n\nHe contributed to teaching calligraphy and passing on its traditions in the late Ottoman era, and he is seen as one of those who preserved the purity of the classical school before the stylistic transformations that the twentieth century witnessed.'**
  String get hasanRidaBio;

  /// No description provided for @bakkalarif_born_year.
  ///
  /// In en, this message translates to:
  /// **'1836'**
  String get bakkalarif_born_year;

  /// No description provided for @bakkalarif_died_year.
  ///
  /// In en, this message translates to:
  /// **'1909'**
  String get bakkalarif_died_year;

  /// No description provided for @bakkalarif_life_description.
  ///
  /// In en, this message translates to:
  /// **'73 years, died in Istanbul'**
  String get bakkalarif_life_description;

  /// No description provided for @bakkalarif_bio.
  ///
  /// In en, this message translates to:
  /// **'Ahmad Arif Efendi, known as \'Bakkal Arif\', was one of the most prominent calligraphers of the late Ottoman school in the nineteenth century, and one of the figures who preserved the classical continuity of the Thuluth and Naskh arts in Istanbul.\n\nHe studied under the great calligrapher Mehmet Şevki Efendi, one of the foremost figures of Ottoman calligraphy, and received his license (ijaza) in Thuluth and Naskh from him, which established his standing within the educational chain of the Ottoman school. He was known for his prolific output and extreme precision, distinguished especially in writing the Noble Hilye (Prophetic description), which was considered among the most beautiful examples of his era. He also transcribed Qurans and produced calligraphic panels and wall decorations.\n\nAmong the works attributed to him is writing the Basmala in prominent script on one of the major mosque doors in Istanbul, in addition to a number of endowment and religious panels. He also contributed to teaching calligraphy and graduating students who continued the traditions of the classical Ottoman school.'**
  String get bakkalarif_bio;

  /// No description provided for @ismailzuhdi_born_year.
  ///
  /// In en, this message translates to:
  /// **'1689'**
  String get ismailzuhdi_born_year;

  /// No description provided for @ismailzuhdi_died_year.
  ///
  /// In en, this message translates to:
  /// **'1758'**
  String get ismailzuhdi_died_year;

  /// No description provided for @ismailzuhdi_life_description.
  ///
  /// In en, this message translates to:
  /// **'69 years, died in Istanbul'**
  String get ismailzuhdi_life_description;

  /// No description provided for @ismailzuhdi_bio.
  ///
  /// In en, this message translates to:
  /// **'Ismail Zuhdi Efendi was one of the greatest calligraphers of the Ottoman state in the eighteenth century, and one of the influential personalities in establishing the classical style of the Thuluth and Naskh scripts within the Ottoman school.\n\nHe was known for his extreme precision in drawing letters, his balance in compositions, and the strength of his control over the calligraphic scale, which made him one of the prominent names in the history of Ottoman Islamic calligraphy.\n\nHe received his education in Istanbul and studied under a number of the greatest calligraphers of his era, until he became a recognized master. He excelled in transcribing Qurans, writing religious panels and official calligraphic pieces, and left behind works that were considered superior examples of quality and artistic mastery.\n\nHe played an important role in teaching calligraphy and preparing a generation of calligraphers who preserved the traditions of the Ottoman school and passed them on to subsequent generations.'**
  String get ismailzuhdi_bio;

  /// No description provided for @ismailhakki_born_year.
  ///
  /// In en, this message translates to:
  /// **'1873'**
  String get ismailhakki_born_year;

  /// No description provided for @ismailhakki_died_year.
  ///
  /// In en, this message translates to:
  /// **'1946'**
  String get ismailhakki_died_year;

  /// No description provided for @ismailhakki_life_description.
  ///
  /// In en, this message translates to:
  /// **'73 years, died in Istanbul'**
  String get ismailhakki_life_description;

  /// No description provided for @ismailhakki_bio.
  ///
  /// In en, this message translates to:
  /// **'Ismail Hakki Altunbezer was one of the most prominent calligraphers and illuminators of the late Ottoman era and the early Republican period in Turkey, and one of the personalities who combined artistic mastery in Arabic calligraphy with distinction in the art of illumination and Islamic ornamentation.\n\nHe received his education in Istanbul, studying calligraphy under the greatest masters, foremost among them Sami Efendi, from whom he learned the fundamentals of Thuluth and Naskh, before excelling especially in the Thuluth and Grand Thuluth scripts.\n\nHe also specialized in the art of illumination, to the point where he was considered one of its leading figures of his time, and his works were distinguished by precision of composition and harmony between the calligraphic text and the decorative elements.\n\nHis artistic mark appeared in decorating a number of mosques, domes, and architectural inscriptions in Istanbul. He worked as a professor at the School of Fine Arts and contributed to forming a generation of artists who continued the traditions of Ottoman calligraphy in the modern era.'**
  String get ismailhakki_bio;

  /// No description provided for @hafizothman_born_year.
  ///
  /// In en, this message translates to:
  /// **'1642'**
  String get hafizothman_born_year;

  /// No description provided for @hafizothman_died_year.
  ///
  /// In en, this message translates to:
  /// **'1698'**
  String get hafizothman_died_year;

  /// No description provided for @hafizothman_life_description.
  ///
  /// In en, this message translates to:
  /// **'56 years, died in Istanbul'**
  String get hafizothman_life_description;

  /// No description provided for @hafizothman_bio.
  ///
  /// In en, this message translates to:
  /// **'Hafiz Osman is considered one of the greatest figures of Ottoman calligraphy in the seventeenth century, and one of the most prominent who reformulated the aesthetic rules of the Thuluth and Naskh scripts in the classical Ottoman school.\n\nHe studied under the greatest calligraphers, foremost among them Darwish Ali, and was influenced by the style of Sheikh Hamdullah al-Amasi, yet he did not content himself with imitation; rather, he re-calibrated the proportions of letters, achieved precise balance in compositions, and developed the visual treatment of the calligraphic page, until his script became an artistic standard whose influence lasted for long centuries.\n\nHe was renowned for transcribing a large number of Qurans distinguished by clarity of writing and fine distribution of text, and he made a decisive contribution to establishing the Ottoman format of the Noble Hilye and spreading it in its well-known classical form.\n\nHe wrote numerous religious panels that spread throughout mosques and homes, and he earned the admiration of Ottoman sultans, to the point where he became the supreme reference for the calligraphy school in his era and for those who came after him.'**
  String get hafizothman_bio;

  /// No description provided for @halim_born_year.
  ///
  /// In en, this message translates to:
  /// **'1898'**
  String get halim_born_year;

  /// No description provided for @halim_died_year.
  ///
  /// In en, this message translates to:
  /// **'1964'**
  String get halim_died_year;

  /// No description provided for @halim_life_description.
  ///
  /// In en, this message translates to:
  /// **'66 years, died in Istanbul'**
  String get halim_life_description;

  /// No description provided for @halim_bio.
  ///
  /// In en, this message translates to:
  /// **'Halim Özyazıcı is considered one of the most prominent calligraphers of Turkey in the twentieth century, and one of the pivotal personalities who maintained the continuity of the Ottoman school after the abolition of the Caliphate and the adoption of the Latin alphabet.\n\nHe studied under Mehmet Kamil Akdik, one of the leading students of Sami Efendi, from whom he learned the fundamentals of Thuluth and Naskh, then was later influenced by Hamid al-Amidi in the Grand Thuluth, which gave him rigor in proportion and strength in structural composition.\n\nHis monumental inscriptions were distinguished by breadth of breath, precision in distributing calligraphic masses, and control of the relationships between vertical and horizontal extensions. He was also known for his great care in the proportionality between letter and space.\n\nHe participated in writing inscriptions in a number of mosques, produced hilyes and religious panels of a clearly classical character, and worked in education, contributing to transmitting the fundamentals of calligraphy to the modern generation in Turkey.'**
  String get halim_bio;

  /// No description provided for @hamdullah_born_year.
  ///
  /// In en, this message translates to:
  /// **'1436'**
  String get hamdullah_born_year;

  /// No description provided for @hamdullah_died_year.
  ///
  /// In en, this message translates to:
  /// **'1520'**
  String get hamdullah_died_year;

  /// No description provided for @hamdullah_life_description.
  ///
  /// In en, this message translates to:
  /// **'About 84 years, died in Istanbul'**
  String get hamdullah_life_description;

  /// No description provided for @hamdullah_bio.
  ///
  /// In en, this message translates to:
  /// **'Sheikh Hamdullah al-Amasi is considered the actual founder of the Ottoman school of calligraphy, and one of the greatest innovators in the history of Arabic script.\n\nHe grew up in Amasya, then moved to Istanbul during the reign of Sultan Bayezid II, who gave him special patronage and provided him with an artistic environment that enabled him to develop an independent style.\n\nHe relied in his early stages on the traditions of Yaqut al-Mustaasimi, but he reformulated the rules of Thuluth and Naskh according to a more flexible and balanced aesthetic vision, softening the sharpness of angles, calibrating letter proportions with geometric precision, and achieving visual harmony between the line and the space.\n\nHe transcribed a large number of Qurans that became standard models, and established the foundations of the school that Ottoman calligraphers followed for centuries. Later generations dubbed him \'Qibla of the Scribes\' for his decisive influence on the course of this art.'**
  String get hamdullah_bio;

  /// No description provided for @samiefendi_born_year.
  ///
  /// In en, this message translates to:
  /// **'1838'**
  String get samiefendi_born_year;

  /// No description provided for @samiefendi_died_year.
  ///
  /// In en, this message translates to:
  /// **'1912'**
  String get samiefendi_died_year;

  /// No description provided for @samiefendi_life_description.
  ///
  /// In en, this message translates to:
  /// **'74 years, died in Istanbul'**
  String get samiefendi_life_description;

  /// No description provided for @samiefendi_bio.
  ///
  /// In en, this message translates to:
  /// **'Sami Efendi is considered one of the greatest calligraphers of the nineteenth century, and one of the most prominent who mastered the Grand Thuluth and brought it to a high degree of perfection.\n\nHe grew up in Istanbul and received his calligraphic education under the greatest masters, until he became one of the primary references of his era.\n\nHis style was distinguished by the strength of structural composition, precision of proportion, and mastery of the relationships between vertical extensions and curves, especially in the Grand Thuluth which requires great ability to control masses within vast spaces.\n\nHe wrote architectural inscriptions in mosques and official institutions, and had a prominent educational role. A number of students who later became pillars of calligraphy in the late Ottoman era studied under him, making him a pivotal link in the transition of the classical school to the modern generation.'**
  String get samiefendi_bio;

  /// No description provided for @shafiqbey_born_year.
  ///
  /// In en, this message translates to:
  /// **'1820'**
  String get shafiqbey_born_year;

  /// No description provided for @shafiqbey_died_year.
  ///
  /// In en, this message translates to:
  /// **'1880'**
  String get shafiqbey_died_year;

  /// No description provided for @shafiqbey_life_description.
  ///
  /// In en, this message translates to:
  /// **'60 years, died in Istanbul'**
  String get shafiqbey_life_description;

  /// No description provided for @shafiqbey_bio.
  ///
  /// In en, this message translates to:
  /// **'Shafiq Bey is considered one of the nineteenth-century calligraphers who became renowned for mastering the Grand Thuluth, a script that requires high precision in controlling proportion and strength in extension.\n\nHe grew up in Istanbul within an artistic environment that enabled him to devote himself to calligraphy, and he progressed in his learning until he became one of the recognized names in architectural inscriptions.\n\nHis works were distinguished by strength of composition and clarity of the calligraphic mass, especially in large panels and wall inscriptions. He wrote Quranic verses and religious panels that adorned mosques and official buildings, and is mentioned among the class of calligraphers who maintained the classical rigor of the Ottoman school.'**
  String get shafiqbey_bio;

  /// No description provided for @shawqiefendi_born_year.
  ///
  /// In en, this message translates to:
  /// **'1829'**
  String get shawqiefendi_born_year;

  /// No description provided for @shawqiefendi_died_year.
  ///
  /// In en, this message translates to:
  /// **'1887'**
  String get shawqiefendi_died_year;

  /// No description provided for @shawqiefendi_life_description.
  ///
  /// In en, this message translates to:
  /// **'58 years, died in Istanbul'**
  String get shawqiefendi_life_description;

  /// No description provided for @shawqiefendi_bio.
  ///
  /// In en, this message translates to:
  /// **'Mehmed Şevkî Efendi is considered one of the greatest calligraphers of the nineteenth century, and one of the most prominent who brought the arts of Thuluth and Naskh to a degree of perfection in the late Ottoman school.\n\nHe grew up in Istanbul and received his education under the greatest masters until he became the primary reference of his era in calibrating letter proportions and mastering compositions.\n\nHe was renowned for transcribing Qurans, which were distinguished by precision of line distribution, clarity of letter, and discipline of proportion, until they became standard models to be emulated in education.\n\nHe also wrote hilyes, religious panels, and masterly large-format works, and a large number of calligraphers who later became luminaries studied under him, making him a fundamental axis in the chain of development of Ottoman calligraphy in the nineteenth century.'**
  String get shawqiefendi_bio;

  /// No description provided for @nazifbey_born_year.
  ///
  /// In en, this message translates to:
  /// **'Not established'**
  String get nazifbey_born_year;

  /// No description provided for @nazifbey_died_year.
  ///
  /// In en, this message translates to:
  /// **'Late 19th century'**
  String get nazifbey_died_year;

  /// No description provided for @nazifbey_life_description.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get nazifbey_life_description;

  /// No description provided for @nazifbey_bio.
  ///
  /// In en, this message translates to:
  /// **'Mehmed Nâzîf Bey is mentioned among the calligraphers of late nineteenth-century Istanbul, and was one of those committed to the style of the classical Ottoman school in Thuluth and Naskh.\n\nHis name appears in biographical works among the class of calligraphers who followed the approach of Mehmed Şevkî and Sami Efendi, indicating his inclusion in the educational chain of the late school.\n\nInformation available about him is limited in primary sources, but he is considered one of the names that preserved the purity of the traditional style during a period that witnessed gradual transformations in artistic taste.'**
  String get nazifbey_bio;

  /// No description provided for @yaqut_born_year.
  ///
  /// In en, this message translates to:
  /// **'c. 1221'**
  String get yaqut_born_year;

  /// No description provided for @yaqut_died_year.
  ///
  /// In en, this message translates to:
  /// **'1298'**
  String get yaqut_died_year;

  /// No description provided for @yaqut_life_description.
  ///
  /// In en, this message translates to:
  /// **'About 77 years, died in Baghdad'**
  String get yaqut_life_description;

  /// No description provided for @yaqut_bio.
  ///
  /// In en, this message translates to:
  /// **'Yaqut al-Mustaasimi is considered one of the greatest calligraphers of the Abbasid era, and one of the most prominent who established the final classical form of Arabic script.\n\nHe lived in Baghdad and was close to Caliph al-Mustaasim Billah, from whom he took his epithet.\n\nHe was influenced by the school of Ibn Muqla and Ibn al-Bawwab, but he developed it to a high degree of elegance and fluidity, until he became the supreme reference for calligraphers after the seventh Hijri century.\n\nHe is credited with establishing the aesthetic rules of the Six Pens in their mature form, and was renowned for his oblique pen-cut method that gave the letter distinctive suppleness. He exerted a profound influence on the Mamluk and Ottoman schools, and was the foundation from which the Ottoman renaissance later sprung.'**
  String get yaqut_bio;

  /// No description provided for @mustafazzat_born_year.
  ///
  /// In en, this message translates to:
  /// **'1801'**
  String get mustafazzat_born_year;

  /// No description provided for @mustafazzat_died_year.
  ///
  /// In en, this message translates to:
  /// **'1876'**
  String get mustafazzat_died_year;

  /// No description provided for @mustafazzat_life_description.
  ///
  /// In en, this message translates to:
  /// **'75 years, died in Istanbul'**
  String get mustafazzat_life_description;

  /// No description provided for @mustafazzat_bio.
  ///
  /// In en, this message translates to:
  /// **'Kazasker Mustafa Izzat Efendi was one of the greatest calligraphers of the Ottoman Empire in the 19th century. He was famous for Thuluth, Naskh, and Jali Thuluth. He combined calligraphy with music and was a renowned ney player. His fame in calligraphy is immense, making him a central figure in Ottoman calligraphic development. He held high religious and judicial positions, most notably Kazasker.\n\nHis artistic importance is especially evident in his Jali Thuluth works, continuing and developing Mustafa Rakim\'s school. His most famous works are the large circular plates in Hagia Sophia, which are among the most famous examples of late Ottoman calligraphy. He also had a significant educational impact on the subsequent generation of calligraphers.'**
  String get mustafazzat_bio;

  /// No description provided for @administrator.
  ///
  /// In en, this message translates to:
  /// **'Administrator'**
  String get administrator;

  /// No description provided for @screenshotWarningTitle.
  ///
  /// In en, this message translates to:
  /// **'Screenshots Disabled'**
  String get screenshotWarningTitle;

  /// No description provided for @screenshotWarningMessage.
  ///
  /// In en, this message translates to:
  /// **'To preserve the masters\' legacy, screenshots are not permitted. Please use the \'Share\' button to export a framed version.'**
  String get screenshotWarningMessage;

  /// No description provided for @fullAccess.
  ///
  /// In en, this message translates to:
  /// **'Full Lifetime Access'**
  String get fullAccess;

  /// No description provided for @multiDeviceSync.
  ///
  /// In en, this message translates to:
  /// **'Multi-device Sync'**
  String get multiDeviceSync;

  /// No description provided for @lifetimeUpdates.
  ///
  /// In en, this message translates to:
  /// **'Lifetime Updates'**
  String get lifetimeUpdates;

  /// No description provided for @purchaseNow.
  ///
  /// In en, this message translates to:
  /// **'Purchase Now'**
  String get purchaseNow;

  /// No description provided for @termsOfUse.
  ///
  /// In en, this message translates to:
  /// **'Terms of Use'**
  String get termsOfUse;

  /// The title of the application
  ///
  /// In en, this message translates to:
  /// **'Calligro'**
  String get appTitle;

  /// No description provided for @appName.
  ///
  /// In en, this message translates to:
  /// **'Calligro'**
  String get appName;

  /// No description provided for @discover.
  ///
  /// In en, this message translates to:
  /// **'Discover'**
  String get discover;

  /// No description provided for @payments.
  ///
  /// In en, this message translates to:
  /// **'Payments'**
  String get payments;

  /// No description provided for @history.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get history;

  /// No description provided for @restorePurchases.
  ///
  /// In en, this message translates to:
  /// **'Restore Purchases'**
  String get restorePurchases;

  /// No description provided for @onboardingTitle.
  ///
  /// In en, this message translates to:
  /// **'Master the Art of\nCalligraphy'**
  String get onboardingTitle;

  /// No description provided for @onboardingSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Begin your artistic journey with a community of masters.'**
  String get onboardingSubtitle;

  /// No description provided for @exploreGuest.
  ///
  /// In en, this message translates to:
  /// **'Explore as Guest'**
  String get exploreGuest;

  /// No description provided for @heroTitle.
  ///
  /// In en, this message translates to:
  /// **'Where Ink\nMeets Artistry'**
  String get heroTitle;

  /// No description provided for @heroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Discover the timeless beauty of Arabic calligraphy with master artisans.'**
  String get heroSubtitle;

  /// No description provided for @heroButton.
  ///
  /// In en, this message translates to:
  /// **'Begin Your Journey'**
  String get heroButton;

  /// No description provided for @guestIntroText.
  ///
  /// In en, this message translates to:
  /// **'Join a community of artists and start your journey today.'**
  String get guestIntroText;

  /// No description provided for @startExploring.
  ///
  /// In en, this message translates to:
  /// **'Start Exploring'**
  String get startExploring;

  /// No description provided for @getStarted.
  ///
  /// In en, this message translates to:
  /// **'Get Started'**
  String get getStarted;

  /// No description provided for @login.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get login;

  /// No description provided for @loginRequired.
  ///
  /// In en, this message translates to:
  /// **'Login Required'**
  String get loginRequired;

  /// No description provided for @loginToInteract.
  ///
  /// In en, this message translates to:
  /// **'Please login to interact with the community and enroll in courses.'**
  String get loginToInteract;

  /// No description provided for @loginTitle.
  ///
  /// In en, this message translates to:
  /// **'Welcome Back'**
  String get loginTitle;

  /// No description provided for @loginSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'re happy to see you again.\nPlease login to continue.'**
  String get loginSubtitle;

  /// No description provided for @register.
  ///
  /// In en, this message translates to:
  /// **'Register'**
  String get register;

  /// No description provided for @registerTitle.
  ///
  /// In en, this message translates to:
  /// **'Create Account'**
  String get registerTitle;

  /// No description provided for @registerSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Join us today and start your journey\nas a Student or Teacher.'**
  String get registerSubtitle;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @forgotPassword.
  ///
  /// In en, this message translates to:
  /// **'Forgot Password?'**
  String get forgotPassword;

  /// No description provided for @orContinueWith.
  ///
  /// In en, this message translates to:
  /// **'Or continue with'**
  String get orContinueWith;

  /// No description provided for @dontHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Don\'t have an account?'**
  String get dontHaveAccount;

  /// No description provided for @alreadyHaveAccount.
  ///
  /// In en, this message translates to:
  /// **'Already have an account?'**
  String get alreadyHaveAccount;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full Name'**
  String get fullName;

  /// No description provided for @confirmPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm Password'**
  String get confirmPassword;

  /// No description provided for @phoneNumber.
  ///
  /// In en, this message translates to:
  /// **'Phone Number'**
  String get phoneNumber;

  /// No description provided for @portfolioLink.
  ///
  /// In en, this message translates to:
  /// **'Personal Page Link (Instagram, Facebook...)'**
  String get portfolioLink;

  /// No description provided for @student.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get student;

  /// No description provided for @teacher.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacher;

  /// No description provided for @enterFullName.
  ///
  /// In en, this message translates to:
  /// **'Please enter your full name.'**
  String get enterFullName;

  /// No description provided for @nameTaken.
  ///
  /// In en, this message translates to:
  /// **'Username is already taken.'**
  String get nameTaken;

  /// No description provided for @nameLengthError.
  ///
  /// In en, this message translates to:
  /// **'Name must be between 3 and 50 characters.'**
  String get nameLengthError;

  /// No description provided for @nameCharError.
  ///
  /// In en, this message translates to:
  /// **'Letters and numbers allowed, but must contain letters.'**
  String get nameCharError;

  /// No description provided for @enterEmail.
  ///
  /// In en, this message translates to:
  /// **'Please enter your email.'**
  String get enterEmail;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email format.'**
  String get invalidEmail;

  /// No description provided for @emailRegistered.
  ///
  /// In en, this message translates to:
  /// **'Email is already registered.'**
  String get emailRegistered;

  /// No description provided for @phoneUsed.
  ///
  /// In en, this message translates to:
  /// **'Phone number already used.'**
  String get phoneUsed;

  /// No description provided for @invalidMobileNumber.
  ///
  /// In en, this message translates to:
  /// **'Invalid mobile number. Please check the length and format.'**
  String get invalidMobileNumber;

  /// No description provided for @enterPassword.
  ///
  /// In en, this message translates to:
  /// **'Please enter a password.'**
  String get enterPassword;

  /// No description provided for @passwordLength.
  ///
  /// In en, this message translates to:
  /// **'Must be at least 6 characters.'**
  String get passwordLength;

  /// No description provided for @passwordComplexity.
  ///
  /// In en, this message translates to:
  /// **'Need 1 Uppercase, 1 Number, 1 Symbol.'**
  String get passwordComplexity;

  /// No description provided for @passwordsMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match.'**
  String get passwordsMatch;

  /// No description provided for @enterPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Please enter your personal page link.'**
  String get enterPortfolio;

  /// No description provided for @invalidPortfolio.
  ///
  /// In en, this message translates to:
  /// **'Please enter a valid link starting with http:// or https:// (e.g., https://google.com)'**
  String get invalidPortfolio;

  /// No description provided for @invalidInput.
  ///
  /// In en, this message translates to:
  /// **'Invalid Input'**
  String get invalidInput;

  /// No description provided for @fixErrors.
  ///
  /// In en, this message translates to:
  /// **'Please fix the red errors above.'**
  String get fixErrors;

  /// No description provided for @termsRequired.
  ///
  /// In en, this message translates to:
  /// **'Terms Required'**
  String get termsRequired;

  /// No description provided for @mustAcceptTerms.
  ///
  /// In en, this message translates to:
  /// **'You must accept the Terms and Conditions.'**
  String get mustAcceptTerms;

  /// No description provided for @verifyingInfo.
  ///
  /// In en, this message translates to:
  /// **'We are verifying your information...'**
  String get verifyingInfo;

  /// No description provided for @verificationIncomplete.
  ///
  /// In en, this message translates to:
  /// **'Verification Incomplete'**
  String get verificationIncomplete;

  /// No description provided for @waitCheckmarks.
  ///
  /// In en, this message translates to:
  /// **'Please wait for the green checkmarks before proceeding.'**
  String get waitCheckmarks;

  /// No description provided for @pleaseSelectAtLeastOneLanguage.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one language.'**
  String get pleaseSelectAtLeastOneLanguage;

  /// No description provided for @welcome.
  ///
  /// In en, this message translates to:
  /// **'Welcome'**
  String get welcome;

  /// No description provided for @registrationSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Registration successful. Enjoy your journey!'**
  String get registrationSuccessful;

  /// No description provided for @applicationReceived.
  ///
  /// In en, this message translates to:
  /// **'Application Received'**
  String get applicationReceived;

  /// No description provided for @teacherUnderReview.
  ///
  /// In en, this message translates to:
  /// **'Your teacher account has been created and is now under review. We will notify you once your profile is approved.'**
  String get teacherUnderReview;

  /// No description provided for @teacherAccountPendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Teacher account pending approval'**
  String get teacherAccountPendingApproval;

  /// No description provided for @teacherPendingPageNote.
  ///
  /// In en, this message translates to:
  /// **'This process typically takes 1-3 business days. You can safely close the app while you wait.\nWe will notify you once approved.'**
  String get teacherPendingPageNote;

  /// No description provided for @teacherApplicationRejectedTitle.
  ///
  /// In en, this message translates to:
  /// **'Application Not Accepted'**
  String get teacherApplicationRejectedTitle;

  /// No description provided for @teacherApplicationRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'We appreciate your interest in joining Calligro. After reviewing your profile and portfolio, we have decided not to move forward with your teacher account at this time.'**
  String get teacherApplicationRejectedMessage;

  /// No description provided for @contactSupport.
  ///
  /// In en, this message translates to:
  /// **'Contact Support'**
  String get contactSupport;

  /// No description provided for @deleteMyAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete My Account'**
  String get deleteMyAccount;

  /// No description provided for @deleteAccountConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountConfirmTitle;

  /// No description provided for @deleteAccountConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will permanently remove your account and all associated data. You can then try applying again with a new profile.'**
  String get deleteAccountConfirmMessage;

  /// No description provided for @accountRejectedPushTitle.
  ///
  /// In en, this message translates to:
  /// **'Application Update'**
  String get accountRejectedPushTitle;

  /// No description provided for @accountRejectedPushBody.
  ///
  /// In en, this message translates to:
  /// **'We have reviewed your teacher application. Tap to see the details.'**
  String get accountRejectedPushBody;

  /// No description provided for @logoutConfirmationTitle.
  ///
  /// In en, this message translates to:
  /// **'Logout Confirmation'**
  String get logoutConfirmationTitle;

  /// No description provided for @logoutConfirmationMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to log out? If you do, you won\'t receive a notification when your account is approved.'**
  String get logoutConfirmationMessage;

  /// No description provided for @stayLoggedIn.
  ///
  /// In en, this message translates to:
  /// **'Stay Logged In'**
  String get stayLoggedIn;

  /// No description provided for @logoutAnyway.
  ///
  /// In en, this message translates to:
  /// **'Log Out Anyway'**
  String get logoutAnyway;

  /// No description provided for @gotIt.
  ///
  /// In en, this message translates to:
  /// **'Got it'**
  String get gotIt;

  /// No description provided for @iAccept.
  ///
  /// In en, this message translates to:
  /// **'I accept the '**
  String get iAccept;

  /// No description provided for @and.
  ///
  /// In en, this message translates to:
  /// **' and '**
  String get and;

  /// No description provided for @privacyPolicy.
  ///
  /// In en, this message translates to:
  /// **'Privacy Policy'**
  String get privacyPolicy;

  /// No description provided for @termsAndConditions.
  ///
  /// In en, this message translates to:
  /// **'terms and conditions'**
  String get termsAndConditions;

  /// No description provided for @success.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get success;

  /// No description provided for @deleted.
  ///
  /// In en, this message translates to:
  /// **'Deleted successfully'**
  String get deleted;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @spokenLanguages.
  ///
  /// In en, this message translates to:
  /// **'Spoken Languages'**
  String get spokenLanguages;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @acceptTerms.
  ///
  /// In en, this message translates to:
  /// **'I accept the Terms & Conditions'**
  String get acceptTerms;

  /// No description provided for @pleaseWait.
  ///
  /// In en, this message translates to:
  /// **'Please wait...'**
  String get pleaseWait;

  /// No description provided for @verifyIdentity.
  ///
  /// In en, this message translates to:
  /// **'Verify your identity'**
  String get verifyIdentity;

  /// No description provided for @phoneNumberInUse.
  ///
  /// In en, this message translates to:
  /// **'Phone number already in use.'**
  String get phoneNumberInUse;

  /// No description provided for @phoneRequired.
  ///
  /// In en, this message translates to:
  /// **'Phone number is required'**
  String get phoneRequired;

  /// No description provided for @enterPhone.
  ///
  /// In en, this message translates to:
  /// **'Enter phone number'**
  String get enterPhone;

  /// No description provided for @verifyMobile.
  ///
  /// In en, this message translates to:
  /// **'Verify Mobile Number'**
  String get verifyMobile;

  /// No description provided for @acceptTermsToFinish.
  ///
  /// In en, this message translates to:
  /// **'Accept terms to finish'**
  String get acceptTermsToFinish;

  /// No description provided for @next.
  ///
  /// In en, this message translates to:
  /// **'Next'**
  String get next;

  /// No description provided for @finish.
  ///
  /// In en, this message translates to:
  /// **'Finish'**
  String get finish;

  /// No description provided for @unavailable.
  ///
  /// In en, this message translates to:
  /// **'Unavailable'**
  String get unavailable;

  /// No description provided for @welcomeUser.
  ///
  /// In en, this message translates to:
  /// **'Hi, {name} 👋'**
  String welcomeUser(String name);

  /// No description provided for @needDetails.
  ///
  /// In en, this message translates to:
  /// **'We’ll just need a few more details to finish setting up your account.'**
  String get needDetails;

  /// No description provided for @chooseRole.
  ///
  /// In en, this message translates to:
  /// **'Choose Your Role'**
  String get chooseRole;

  /// No description provided for @learnOrTeach.
  ///
  /// In en, this message translates to:
  /// **'Are you here to learn or to teach?'**
  String get learnOrTeach;

  /// No description provided for @studentFinishMessage.
  ///
  /// In en, this message translates to:
  /// **'Great! You\'re all set.\nPress Finish to continue.'**
  String get studentFinishMessage;

  /// No description provided for @portfolioHint.
  ///
  /// In en, this message translates to:
  /// **'Enter your personal page link'**
  String get portfolioHint;

  /// No description provided for @teacherFinishMessage.
  ///
  /// In en, this message translates to:
  /// **'Your registration has been submitted for approval. This typically takes 1-3 business days.\nYou will be notified once approved.'**
  String get teacherFinishMessage;

  /// No description provided for @stepOf.
  ///
  /// In en, this message translates to:
  /// **'Step {current} of {total}'**
  String stepOf(int current, int total);

  /// No description provided for @finishAndRegister.
  ///
  /// In en, this message translates to:
  /// **'Finish & Register'**
  String get finishAndRegister;

  /// No description provided for @finalizing.
  ///
  /// In en, this message translates to:
  /// **'Finalizing...'**
  String get finalizing;

  /// No description provided for @verifyOtpTitle.
  ///
  /// In en, this message translates to:
  /// **'Verify Code'**
  String get verifyOtpTitle;

  /// No description provided for @setNewPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Set New Password'**
  String get setNewPasswordTitle;

  /// No description provided for @newPassword.
  ///
  /// In en, this message translates to:
  /// **'New Password'**
  String get newPassword;

  /// No description provided for @confirmNewPassword.
  ///
  /// In en, this message translates to:
  /// **'Confirm New Password'**
  String get confirmNewPassword;

  /// No description provided for @passwordsDoNotMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords do not match'**
  String get passwordsDoNotMatch;

  /// No description provided for @passwordTooShort.
  ///
  /// In en, this message translates to:
  /// **'Password must be at least 6 characters'**
  String get passwordTooShort;

  /// No description provided for @googleUserInfo.
  ///
  /// In en, this message translates to:
  /// **'This account uses Google Sign-In. You can add a password to enable email/password login as well.'**
  String get googleUserInfo;

  /// No description provided for @continueToSetPassword.
  ///
  /// In en, this message translates to:
  /// **'Continue to Set Password'**
  String get continueToSetPassword;

  /// No description provided for @passwordResetSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset successful! You can now log in with your new password.'**
  String get passwordResetSuccess;

  /// No description provided for @enterCodeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Enter the code sent to\n{destination}'**
  String enterCodeSentTo(String destination);

  /// No description provided for @resendIn.
  ///
  /// In en, this message translates to:
  /// **'Resend in {seconds} s'**
  String resendIn(int seconds);

  /// No description provided for @resendCode.
  ///
  /// In en, this message translates to:
  /// **'Resend Code'**
  String get resendCode;

  /// No description provided for @otpSent.
  ///
  /// In en, this message translates to:
  /// **'OTP Sent'**
  String get otpSent;

  /// No description provided for @checkInbox.
  ///
  /// In en, this message translates to:
  /// **'Check your inbox.'**
  String get checkInbox;

  /// No description provided for @smsSent.
  ///
  /// In en, this message translates to:
  /// **'SMS Sent'**
  String get smsSent;

  /// No description provided for @checkMessages.
  ///
  /// In en, this message translates to:
  /// **'Check your messages.'**
  String get checkMessages;

  /// No description provided for @smsError.
  ///
  /// In en, this message translates to:
  /// **'SMS Error'**
  String get smsError;

  /// No description provided for @inputError.
  ///
  /// In en, this message translates to:
  /// **'Input Error'**
  String get inputError;

  /// No description provided for @enter6Digits.
  ///
  /// In en, this message translates to:
  /// **'Enter 6 digits.'**
  String get enter6Digits;

  /// No description provided for @idMissing.
  ///
  /// In en, this message translates to:
  /// **'ID missing, resend code.'**
  String get idMissing;

  /// No description provided for @incorrectCode.
  ///
  /// In en, this message translates to:
  /// **'Incorrect Code'**
  String get incorrectCode;

  /// No description provided for @pleaseTryAgain.
  ///
  /// In en, this message translates to:
  /// **'Please try again.'**
  String get pleaseTryAgain;

  /// No description provided for @verificationFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed.'**
  String get verificationFailed;

  /// No description provided for @allVerified.
  ///
  /// In en, this message translates to:
  /// **'All verified ✅\nPress Finish to complete registration.'**
  String get allVerified;

  /// No description provided for @home.
  ///
  /// In en, this message translates to:
  /// **'Home'**
  String get home;

  /// No description provided for @courses.
  ///
  /// In en, this message translates to:
  /// **'Courses'**
  String get courses;

  /// No description provided for @community.
  ///
  /// In en, this message translates to:
  /// **'Community'**
  String get community;

  /// No description provided for @profile.
  ///
  /// In en, this message translates to:
  /// **'Profile'**
  String get profile;

  /// No description provided for @gallery.
  ///
  /// In en, this message translates to:
  /// **'Gallery'**
  String get gallery;

  /// No description provided for @masterclassGallery.
  ///
  /// In en, this message translates to:
  /// **'Masterclass Gallery'**
  String get masterclassGallery;

  /// No description provided for @searchMasters.
  ///
  /// In en, this message translates to:
  /// **'Search Masters...'**
  String get searchMasters;

  /// No description provided for @notEnrolledGalleryTitle.
  ///
  /// In en, this message translates to:
  /// **'Unlock Masterclass Gallery'**
  String get notEnrolledGalleryTitle;

  /// No description provided for @notEnrolledGalleryMessage.
  ///
  /// In en, this message translates to:
  /// **'Enroll in any course to unlock the full high-resolution gallery and exclusive artwork from our masters.'**
  String get notEnrolledGalleryMessage;

  /// No description provided for @downloadingHighRes.
  ///
  /// In en, this message translates to:
  /// **'Downloading High-Res...'**
  String get downloadingHighRes;

  /// No description provided for @artworkDetails.
  ///
  /// In en, this message translates to:
  /// **'Artwork Details'**
  String get artworkDetails;

  /// No description provided for @artworkViewerDescription.
  ///
  /// In en, this message translates to:
  /// **'This is a high-resolution scan of an original calligraphy piece. Swipe to zoom in and see the fine details of the ink and paper.'**
  String get artworkViewerDescription;

  /// No description provided for @certifiedArtist.
  ///
  /// In en, this message translates to:
  /// **'Certified Artist'**
  String get certifiedArtist;

  /// No description provided for @instructors.
  ///
  /// In en, this message translates to:
  /// **'Instructors'**
  String get instructors;

  /// No description provided for @signInToAccess.
  ///
  /// In en, this message translates to:
  /// **'Sign in to access {title}'**
  String signInToAccess(String title);

  /// No description provided for @registeredStudentsOnly.
  ///
  /// In en, this message translates to:
  /// **'This feature is available for registered students.'**
  String get registeredStudentsOnly;

  /// No description provided for @unlockFullExperience.
  ///
  /// In en, this message translates to:
  /// **'Unlock the Full\nExperience'**
  String get unlockFullExperience;

  /// No description provided for @unlockSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Access 50+ hours of masterclasses, detailed courses, and exclusive resources.'**
  String get unlockSubtitle;

  /// No description provided for @createFreeAccount.
  ///
  /// In en, this message translates to:
  /// **'Create Free Account'**
  String get createFreeAccount;

  /// No description provided for @getPersonalCritiques.
  ///
  /// In en, this message translates to:
  /// **'Get Personal\nMaster Critiques'**
  String get getPersonalCritiques;

  /// No description provided for @critiquesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Submit your artwork and receive video feedback from certified masters.'**
  String get critiquesSubtitle;

  /// No description provided for @joinForCritiques.
  ///
  /// In en, this message translates to:
  /// **'Join for Critiques'**
  String get joinForCritiques;

  /// No description provided for @joinGlobalCommunity.
  ///
  /// In en, this message translates to:
  /// **'Join a Global\nCommunity'**
  String get joinGlobalCommunity;

  /// No description provided for @communitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Connect with 10,000+ calligraphers. Share your work and grow together.'**
  String get communitySubtitle;

  /// No description provided for @exploreCommunity.
  ///
  /// In en, this message translates to:
  /// **'Explore Community'**
  String get exploreCommunity;

  /// No description provided for @premiumAccess.
  ///
  /// In en, this message translates to:
  /// **'PREMIUM ACCESS'**
  String get premiumAccess;

  /// No description provided for @liveMasterclasses.
  ///
  /// In en, this message translates to:
  /// **'Live Masterclasses'**
  String get liveMasterclasses;

  /// No description provided for @seeSchedule.
  ///
  /// In en, this message translates to:
  /// **'See Schedule'**
  String get seeSchedule;

  /// No description provided for @exploreScripts.
  ///
  /// In en, this message translates to:
  /// **'Explore Scripts'**
  String get exploreScripts;

  /// No description provided for @viewAll.
  ///
  /// In en, this message translates to:
  /// **'View All'**
  String get viewAll;

  /// No description provided for @diwaniBasics.
  ///
  /// In en, this message translates to:
  /// **'Diwani Basics'**
  String get diwaniBasics;

  /// No description provided for @kuficGeometry.
  ///
  /// In en, this message translates to:
  /// **'Kufic Geometry'**
  String get kuficGeometry;

  /// No description provided for @liveNow.
  ///
  /// In en, this message translates to:
  /// **'Live • Now'**
  String get liveNow;

  /// No description provided for @tomorrow3PM.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow • 3PM'**
  String get tomorrow3PM;

  /// No description provided for @masterAlHassan.
  ///
  /// In en, this message translates to:
  /// **'Master Al-Hassan'**
  String get masterAlHassan;

  /// No description provided for @thuluth.
  ///
  /// In en, this message translates to:
  /// **'Thuluth'**
  String get thuluth;

  /// No description provided for @naskh.
  ///
  /// In en, this message translates to:
  /// **'Naskh'**
  String get naskh;

  /// No description provided for @diwani.
  ///
  /// In en, this message translates to:
  /// **'Diwani'**
  String get diwani;

  /// No description provided for @kufic.
  ///
  /// In en, this message translates to:
  /// **'Kufic'**
  String get kufic;

  /// No description provided for @motherOfScripts.
  ///
  /// In en, this message translates to:
  /// **'The Mother of Scripts'**
  String get motherOfScripts;

  /// No description provided for @scriptOfQuran.
  ///
  /// In en, this message translates to:
  /// **'The Script of Quran'**
  String get scriptOfQuran;

  /// No description provided for @royalScript.
  ///
  /// In en, this message translates to:
  /// **'The Royal Script'**
  String get royalScript;

  /// No description provided for @geometricHarmony.
  ///
  /// In en, this message translates to:
  /// **'Geometric Harmony'**
  String get geometricHarmony;

  /// No description provided for @salamGuest.
  ///
  /// In en, this message translates to:
  /// **'Salam, Guest.'**
  String get salamGuest;

  /// No description provided for @salamName.
  ///
  /// In en, this message translates to:
  /// **'Salam, {name}.'**
  String salamName(String name);

  /// No description provided for @discoverSacredGeometry.
  ///
  /// In en, this message translates to:
  /// **'Discover the art of sacred geometry.'**
  String get discoverSacredGeometry;

  /// No description provided for @continuePathMastery.
  ///
  /// In en, this message translates to:
  /// **'Continue your path to mastery.'**
  String get continuePathMastery;

  /// No description provided for @myPosts.
  ///
  /// In en, this message translates to:
  /// **'My Posts'**
  String get myPosts;

  /// No description provided for @popular.
  ///
  /// In en, this message translates to:
  /// **'Popular'**
  String get popular;

  /// No description provided for @teachers.
  ///
  /// In en, this message translates to:
  /// **'Teachers'**
  String get teachers;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search Users'**
  String get searchUsers;

  /// No description provided for @searchByName.
  ///
  /// In en, this message translates to:
  /// **'Search by name...'**
  String get searchByName;

  /// No description provided for @searchTeachersStudents.
  ///
  /// In en, this message translates to:
  /// **'Search for teachers and students'**
  String get searchTeachersStudents;

  /// No description provided for @noReviewsYet.
  ///
  /// In en, this message translates to:
  /// **'No reviews yet'**
  String get noReviewsYet;

  /// No description provided for @excellent.
  ///
  /// In en, this message translates to:
  /// **'Excellent'**
  String get excellent;

  /// No description provided for @veryGood.
  ///
  /// In en, this message translates to:
  /// **'Very Good'**
  String get veryGood;

  /// No description provided for @good.
  ///
  /// In en, this message translates to:
  /// **'Good'**
  String get good;

  /// No description provided for @average.
  ///
  /// In en, this message translates to:
  /// **'Average'**
  String get average;

  /// No description provided for @belowAverage.
  ///
  /// In en, this message translates to:
  /// **'Below Average'**
  String get belowAverage;

  /// No description provided for @poor.
  ///
  /// In en, this message translates to:
  /// **'Poor'**
  String get poor;

  /// No description provided for @noPostsFoundForFilter.
  ///
  /// In en, this message translates to:
  /// **'No posts found for \"{filter}\".'**
  String noPostsFoundForFilter(String filter);

  /// No description provided for @errorLoadingPosts.
  ///
  /// In en, this message translates to:
  /// **'Error loading posts.'**
  String get errorLoadingPosts;

  /// No description provided for @totalUsers.
  ///
  /// In en, this message translates to:
  /// **'Total Users'**
  String get totalUsers;

  /// No description provided for @pending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get pending;

  /// No description provided for @adminDashboard.
  ///
  /// In en, this message translates to:
  /// **'Admin Dashboard'**
  String get adminDashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @broadcastMessage.
  ///
  /// In en, this message translates to:
  /// **'Broadcast Message'**
  String get broadcastMessage;

  /// No description provided for @broadcastHint.
  ///
  /// In en, this message translates to:
  /// **'Your message to all users...'**
  String get broadcastHint;

  /// No description provided for @broadcastSent.
  ///
  /// In en, this message translates to:
  /// **'Broadcast sent!'**
  String get broadcastSent;

  /// No description provided for @title.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get title;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @calligro.
  ///
  /// In en, this message translates to:
  /// **'Calligro'**
  String get calligro;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign In'**
  String get signIn;

  /// No description provided for @profilePictureRequired.
  ///
  /// In en, this message translates to:
  /// **'Profile Picture Required'**
  String get profilePictureRequired;

  /// No description provided for @profilePictureSubtitle.
  ///
  /// In en, this message translates to:
  /// **'To ensure a professional environment, all teachers must have a profile photo.'**
  String get profilePictureSubtitle;

  /// No description provided for @uploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Upload Photo'**
  String get uploadPhoto;

  /// No description provided for @activeCourses.
  ///
  /// In en, this message translates to:
  /// **'Active Courses'**
  String get activeCourses;

  /// No description provided for @activeStudents.
  ///
  /// In en, this message translates to:
  /// **'Active Students'**
  String get activeStudents;

  /// No description provided for @earnings.
  ///
  /// In en, this message translates to:
  /// **'Earnings'**
  String get earnings;

  /// No description provided for @happeningNext.
  ///
  /// In en, this message translates to:
  /// **'Happening Next'**
  String get happeningNext;

  /// No description provided for @quickActions.
  ///
  /// In en, this message translates to:
  /// **'Quick Actions'**
  String get quickActions;

  /// No description provided for @newCourse.
  ///
  /// In en, this message translates to:
  /// **'New Course'**
  String get newCourse;

  /// No description provided for @finance.
  ///
  /// In en, this message translates to:
  /// **'Finance'**
  String get finance;

  /// No description provided for @manageCourses.
  ///
  /// In en, this message translates to:
  /// **'Manage Courses'**
  String get manageCourses;

  /// No description provided for @reviews.
  ///
  /// In en, this message translates to:
  /// **'Reviews'**
  String get reviews;

  /// No description provided for @liked.
  ///
  /// In en, this message translates to:
  /// **'Liked'**
  String get liked;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @teachBeautiful.
  ///
  /// In en, this message translates to:
  /// **'Let\'s teach something beautiful.'**
  String get teachBeautiful;

  /// No description provided for @welcomeName.
  ///
  /// In en, this message translates to:
  /// **'Welcome, {name}'**
  String welcomeName(String name);

  /// No description provided for @liveNowCaps.
  ///
  /// In en, this message translates to:
  /// **'LIVE NOW'**
  String get liveNowCaps;

  /// No description provided for @upcomingCaps.
  ///
  /// In en, this message translates to:
  /// **'UPCOMING'**
  String get upcomingCaps;

  /// No description provided for @started.
  ///
  /// In en, this message translates to:
  /// **'Started'**
  String get started;

  /// No description provided for @today.
  ///
  /// In en, this message translates to:
  /// **'Today'**
  String get today;

  /// No description provided for @todayAt.
  ///
  /// In en, this message translates to:
  /// **'Today, {time}'**
  String todayAt(String time);

  /// No description provided for @tomorrowAt.
  ///
  /// In en, this message translates to:
  /// **'Tomorrow, {time}'**
  String tomorrowAt(String time);

  /// No description provided for @profilePictureUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile picture updated!'**
  String get profilePictureUpdated;

  /// No description provided for @termsAcceptedWelcome.
  ///
  /// In en, this message translates to:
  /// **'Terms accepted! Welcome.'**
  String get termsAcceptedWelcome;

  /// No description provided for @noMeetingLink.
  ///
  /// In en, this message translates to:
  /// **'No meeting link provided.'**
  String get noMeetingLink;

  /// No description provided for @couldNotLaunch.
  ///
  /// In en, this message translates to:
  /// **'Could not launch link.'**
  String get couldNotLaunch;

  /// No description provided for @allCaughtUp.
  ///
  /// In en, this message translates to:
  /// **'All Caught Up!'**
  String get allCaughtUp;

  /// No description provided for @noClassesScheduled.
  ///
  /// In en, this message translates to:
  /// **'You have no classes scheduled for Today or Tomorrow. Enjoy your break!'**
  String get noClassesScheduled;

  /// No description provided for @joinClassNow.
  ///
  /// In en, this message translates to:
  /// **'JOIN CLASS NOW'**
  String get joinClassNow;

  /// No description provided for @prepareClass.
  ///
  /// In en, this message translates to:
  /// **'PREPARE CLASS'**
  String get prepareClass;

  /// No description provided for @notifications.
  ///
  /// In en, this message translates to:
  /// **'Notifications'**
  String get notifications;

  /// No description provided for @noNotificationsYet.
  ///
  /// In en, this message translates to:
  /// **'No notifications yet.'**
  String get noNotificationsYet;

  /// No description provided for @newNotifications.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newNotifications;

  /// No description provided for @earlier.
  ///
  /// In en, this message translates to:
  /// **'Earlier'**
  String get earlier;

  /// No description provided for @allMarkedRead.
  ///
  /// In en, this message translates to:
  /// **'All marked as read'**
  String get allMarkedRead;

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot your password?'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Enter your email and we\'ll send you a reset link.'**
  String get forgotPasswordSubtitle;

  /// No description provided for @emailAddress.
  ///
  /// In en, this message translates to:
  /// **'Email Address'**
  String get emailAddress;

  /// No description provided for @sendResetEmail.
  ///
  /// In en, this message translates to:
  /// **'Send Reset Email'**
  String get sendResetEmail;

  /// No description provided for @noAccountFound.
  ///
  /// In en, this message translates to:
  /// **'No account found with this email.'**
  String get noAccountFound;

  /// No description provided for @passwordResetSent.
  ///
  /// In en, this message translates to:
  /// **'Password reset email sent!'**
  String get passwordResetSent;

  /// No description provided for @googleSignInFailed.
  ///
  /// In en, this message translates to:
  /// **'Google sign-in failed'**
  String get googleSignInFailed;

  /// No description provided for @invalidCredentials.
  ///
  /// In en, this message translates to:
  /// **'Incorrect email or password.'**
  String get invalidCredentials;

  /// No description provided for @wrongPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password.'**
  String get wrongPassword;

  /// No description provided for @linkAccountTitle.
  ///
  /// In en, this message translates to:
  /// **'Link Your Account'**
  String get linkAccountTitle;

  /// No description provided for @linkAccountMessage.
  ///
  /// In en, this message translates to:
  /// **'An account with this email already exists. To link your Google account and log in, please enter your password.'**
  String get linkAccountMessage;

  /// No description provided for @linkAccountButton.
  ///
  /// In en, this message translates to:
  /// **'Link & Login'**
  String get linkAccountButton;

  /// No description provided for @invalidPassword.
  ///
  /// In en, this message translates to:
  /// **'Incorrect password. Please try again.'**
  String get invalidPassword;

  /// No description provided for @tooManyRequests.
  ///
  /// In en, this message translates to:
  /// **'Too many failed attempts. Please try again later.'**
  String get tooManyRequests;

  /// No description provided for @addNewPost.
  ///
  /// In en, this message translates to:
  /// **'Add New Post'**
  String get addNewPost;

  /// No description provided for @shareMasterpiece.
  ///
  /// In en, this message translates to:
  /// **'Share your masterpiece...'**
  String get shareMasterpiece;

  /// No description provided for @post.
  ///
  /// In en, this message translates to:
  /// **'Post'**
  String get post;

  /// No description provided for @errorFetchingUserData.
  ///
  /// In en, this message translates to:
  /// **'Error fetching user data: {error}'**
  String errorFetchingUserData(String error);

  /// No description provided for @addPhoto.
  ///
  /// In en, this message translates to:
  /// **'Add photo'**
  String get addPhoto;

  /// No description provided for @limitPhotosReached.
  ///
  /// In en, this message translates to:
  /// **'Limit of {max} photos reached'**
  String limitPhotosReached(int max);

  /// No description provided for @canOnlySelectUpTo.
  ///
  /// In en, this message translates to:
  /// **'You can only select up to {max} photos'**
  String canOnlySelectUpTo(int max);

  /// No description provided for @alreadySelectedMax.
  ///
  /// In en, this message translates to:
  /// **'You have already selected the maximum of {max} images'**
  String alreadySelectedMax(int max);

  /// No description provided for @someImagesNotAdded.
  ///
  /// In en, this message translates to:
  /// **'Limit of {max} photos reached. Some images were not added'**
  String someImagesNotAdded(int max);

  /// No description provided for @deletePost.
  ///
  /// In en, this message translates to:
  /// **'Delete Post?'**
  String get deletePost;

  /// No description provided for @areYouSure.
  ///
  /// In en, this message translates to:
  /// **'Are you sure?'**
  String get areYouSure;

  /// No description provided for @failedToDelete.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete: {error}'**
  String failedToDelete(String error);

  /// No description provided for @publicStudentProfilesNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Public student profiles not available yet.'**
  String get publicStudentProfilesNotAvailable;

  /// No description provided for @seeMore.
  ///
  /// In en, this message translates to:
  /// **'See more'**
  String get seeMore;

  /// No description provided for @showMore.
  ///
  /// In en, this message translates to:
  /// **'Show more'**
  String get showMore;

  /// No description provided for @showLess.
  ///
  /// In en, this message translates to:
  /// **'Show less'**
  String get showLess;

  /// No description provided for @justNow.
  ///
  /// In en, this message translates to:
  /// **'just now'**
  String get justNow;

  /// No description provided for @postedBy.
  ///
  /// In en, this message translates to:
  /// **'{name} posted:'**
  String postedBy(String name);

  /// No description provided for @checkOutImage.
  ///
  /// In en, this message translates to:
  /// **'Check out the image:'**
  String get checkOutImage;

  /// No description provided for @sentFromCalligro.
  ///
  /// In en, this message translates to:
  /// **'Sent from Calligro'**
  String get sentFromCalligro;

  /// No description provided for @likes.
  ///
  /// In en, this message translates to:
  /// **'Likes'**
  String get likes;

  /// No description provided for @searchLikes.
  ///
  /// In en, this message translates to:
  /// **'Search likes...'**
  String get searchLikes;

  /// No description provided for @noLikesYet.
  ///
  /// In en, this message translates to:
  /// **'No likes yet.'**
  String get noLikesYet;

  /// No description provided for @noUsersFound.
  ///
  /// In en, this message translates to:
  /// **'No users found'**
  String get noUsersFound;

  /// No description provided for @youLabel.
  ///
  /// In en, this message translates to:
  /// **'(You)'**
  String get youLabel;

  /// No description provided for @authorLabel.
  ///
  /// In en, this message translates to:
  /// **'(Author)'**
  String get authorLabel;

  /// No description provided for @addComment.
  ///
  /// In en, this message translates to:
  /// **'Add a comment...'**
  String get addComment;

  /// No description provided for @message.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get message;

  /// No description provided for @userNotFound.
  ///
  /// In en, this message translates to:
  /// **'User not found'**
  String get userNotFound;

  /// No description provided for @postsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 post} other{{count} posts}}'**
  String postsCount(num count);

  /// No description provided for @followersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 follower} other{{count} followers}}'**
  String followersCount(num count);

  /// No description provided for @followingCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{0 following} other{{count} following}}'**
  String followingCount(num count);

  /// No description provided for @failedToPostComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to post comment. Please try again.'**
  String get failedToPostComment;

  /// No description provided for @deleteComment.
  ///
  /// In en, this message translates to:
  /// **'Delete Comment?'**
  String get deleteComment;

  /// No description provided for @deleteCommentConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this comment? This cannot be undone.'**
  String get deleteCommentConfirm;

  /// No description provided for @failedToDeleteComment.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete comment. Please try again.'**
  String get failedToDeleteComment;

  /// No description provided for @editComment.
  ///
  /// In en, this message translates to:
  /// **'Edit Comment'**
  String get editComment;

  /// No description provided for @failedToSaveChanges.
  ///
  /// In en, this message translates to:
  /// **'Failed to save changes. Please try again.'**
  String get failedToSaveChanges;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @send.
  ///
  /// In en, this message translates to:
  /// **'Send'**
  String get send;

  /// No description provided for @seeAll.
  ///
  /// In en, this message translates to:
  /// **'See All'**
  String get seeAll;

  /// No description provided for @follow.
  ///
  /// In en, this message translates to:
  /// **'Follow'**
  String get follow;

  /// No description provided for @following.
  ///
  /// In en, this message translates to:
  /// **'Following'**
  String get following;

  /// No description provided for @friends.
  ///
  /// In en, this message translates to:
  /// **'My Friends'**
  String get friends;

  /// No description provided for @saved.
  ///
  /// In en, this message translates to:
  /// **'Saved'**
  String get saved;

  /// No description provided for @myPostsWithCount.
  ///
  /// In en, this message translates to:
  /// **'My Posts ({count})'**
  String myPostsWithCount(String count);

  /// No description provided for @edited.
  ///
  /// In en, this message translates to:
  /// **'Edited'**
  String get edited;

  /// No description provided for @editPost.
  ///
  /// In en, this message translates to:
  /// **'Edit Post'**
  String get editPost;

  /// No description provided for @updateCaptionHint.
  ///
  /// In en, this message translates to:
  /// **'Update your caption...'**
  String get updateCaptionHint;

  /// No description provided for @postUpdated.
  ///
  /// In en, this message translates to:
  /// **'Post updated successfully'**
  String get postUpdated;

  /// No description provided for @profileNotAvailable.
  ///
  /// In en, this message translates to:
  /// **'Profile not available for this user type'**
  String get profileNotAvailable;

  /// No description provided for @comments.
  ///
  /// In en, this message translates to:
  /// **'Comments'**
  String get comments;

  /// No description provided for @noCommentsYet.
  ///
  /// In en, this message translates to:
  /// **'No comments yet.'**
  String get noCommentsYet;

  /// No description provided for @errorLoadingUserData.
  ///
  /// In en, this message translates to:
  /// **'Error: Could not load user data. Please try again.'**
  String get errorLoadingUserData;

  /// No description provided for @failedToPostReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to post reply'**
  String get failedToPostReply;

  /// No description provided for @deleteReply.
  ///
  /// In en, this message translates to:
  /// **'Delete Reply'**
  String get deleteReply;

  /// No description provided for @deleteReplyConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this reply?'**
  String get deleteReplyConfirm;

  /// No description provided for @failedToDeleteReply.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete reply'**
  String get failedToDeleteReply;

  /// No description provided for @writeUpdateHint.
  ///
  /// In en, this message translates to:
  /// **'Write your update...'**
  String get writeUpdateHint;

  /// No description provided for @reply.
  ///
  /// In en, this message translates to:
  /// **'Reply'**
  String get reply;

  /// No description provided for @replyingTo.
  ///
  /// In en, this message translates to:
  /// **'Replying to'**
  String get replyingTo;

  /// No description provided for @replyTo.
  ///
  /// In en, this message translates to:
  /// **'Reply to'**
  String replyTo(String name);

  /// No description provided for @editReply.
  ///
  /// In en, this message translates to:
  /// **'Edit Reply'**
  String get editReply;

  /// No description provided for @editProfile.
  ///
  /// In en, this message translates to:
  /// **'Edit Profile'**
  String get editProfile;

  /// No description provided for @guestMode.
  ///
  /// In en, this message translates to:
  /// **'Guest Mode'**
  String get guestMode;

  /// No description provided for @logInToViewProfile.
  ///
  /// In en, this message translates to:
  /// **'Log in to view your profile and art.'**
  String get logInToViewProfile;

  /// No description provided for @loginRegister.
  ///
  /// In en, this message translates to:
  /// **'Login / Register'**
  String get loginRegister;

  /// No description provided for @backToWelcome.
  ///
  /// In en, this message translates to:
  /// **'Back to Welcome Screen'**
  String get backToWelcome;

  /// No description provided for @noSavedItems.
  ///
  /// In en, this message translates to:
  /// **'No saved items yet.'**
  String get noSavedItems;

  /// No description provided for @studentBadge.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentBadge;

  /// No description provided for @studentProfile.
  ///
  /// In en, this message translates to:
  /// **'Student Profile'**
  String get studentProfile;

  /// No description provided for @findYourCourse.
  ///
  /// In en, this message translates to:
  /// **'Find Your Course'**
  String get findYourCourse;

  /// No description provided for @searchCourseHint.
  ///
  /// In en, this message translates to:
  /// **'Search for calligraphy style or teacher...'**
  String get searchCourseHint;

  /// No description provided for @free.
  ///
  /// In en, this message translates to:
  /// **'Free'**
  String get free;

  /// No description provided for @instructor.
  ///
  /// In en, this message translates to:
  /// **'Instructor'**
  String get instructor;

  /// No description provided for @noCoursesMatchFilter.
  ///
  /// In en, this message translates to:
  /// **'No courses match your filter.'**
  String get noCoursesMatchFilter;

  /// No description provided for @courseFull.
  ///
  /// In en, this message translates to:
  /// **'This course is full.'**
  String get courseFull;

  /// No description provided for @checkout.
  ///
  /// In en, this message translates to:
  /// **'Checkout'**
  String get checkout;

  /// No description provided for @enrollmentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Enrollment Successful!'**
  String get enrollmentSuccessful;

  /// No description provided for @youHaveSuccessfullyJoined.
  ///
  /// In en, this message translates to:
  /// **'You have successfully joined'**
  String get youHaveSuccessfullyJoined;

  /// No description provided for @startLearning.
  ///
  /// In en, this message translates to:
  /// **'Start Learning'**
  String get startLearning;

  /// No description provided for @orderSummary.
  ///
  /// In en, this message translates to:
  /// **'Order Summary'**
  String get orderSummary;

  /// No description provided for @paymentMethod.
  ///
  /// In en, this message translates to:
  /// **'Payment Method'**
  String get paymentMethod;

  /// No description provided for @card.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get card;

  /// No description provided for @paypal.
  ///
  /// In en, this message translates to:
  /// **'PayPal'**
  String get paypal;

  /// No description provided for @cardDetails.
  ///
  /// In en, this message translates to:
  /// **'Card Details'**
  String get cardDetails;

  /// No description provided for @cardNumber.
  ///
  /// In en, this message translates to:
  /// **'Card Number'**
  String get cardNumber;

  /// No description provided for @expiryDate.
  ///
  /// In en, this message translates to:
  /// **'Expiry Date'**
  String get expiryDate;

  /// No description provided for @cvv.
  ///
  /// In en, this message translates to:
  /// **'CVV'**
  String get cvv;

  /// No description provided for @subtotal.
  ///
  /// In en, this message translates to:
  /// **'Subtotal'**
  String get subtotal;

  /// No description provided for @tax.
  ///
  /// In en, this message translates to:
  /// **'Tax (5%)'**
  String get tax;

  /// No description provided for @fee.
  ///
  /// In en, this message translates to:
  /// **'Fee'**
  String get fee;

  /// No description provided for @total.
  ///
  /// In en, this message translates to:
  /// **'Total'**
  String get total;

  /// No description provided for @enrollForFree.
  ///
  /// In en, this message translates to:
  /// **'Enroll for Free'**
  String get enrollForFree;

  /// No description provided for @payNow.
  ///
  /// In en, this message translates to:
  /// **'Pay Now'**
  String get payNow;

  /// No description provided for @myCourses.
  ///
  /// In en, this message translates to:
  /// **'My Courses'**
  String get myCourses;

  /// No description provided for @allCourses.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get allCourses;

  /// No description provided for @upcomingCourses.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcomingCourses;

  /// No description provided for @endedCourses.
  ///
  /// In en, this message translates to:
  /// **'Ended Courses'**
  String get endedCourses;

  /// No description provided for @addNewCourse.
  ///
  /// In en, this message translates to:
  /// **'Add New Course'**
  String get addNewCourse;

  /// No description provided for @teacherIdNotFound.
  ///
  /// In en, this message translates to:
  /// **'Teacher ID not found. Please log in.'**
  String get teacherIdNotFound;

  /// No description provided for @errorFetchingCourses.
  ///
  /// In en, this message translates to:
  /// **'Error fetching courses: {error}'**
  String errorFetchingCourses(String error);

  /// No description provided for @noCoursesCreated.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t created any courses yet!'**
  String get noCoursesCreated;

  /// No description provided for @tapPlusToGetStarted.
  ///
  /// In en, this message translates to:
  /// **'Tap the \'+\' icon above to get started.'**
  String get tapPlusToGetStarted;

  /// No description provided for @noFilteredCoursesFound.
  ///
  /// In en, this message translates to:
  /// **'No {filter} courses found.'**
  String noFilteredCoursesFound(String filter);

  /// No description provided for @trySelectingAllCourses.
  ///
  /// In en, this message translates to:
  /// **'Try selecting \'All Courses\' from the filter menu.'**
  String get trySelectingAllCourses;

  /// No description provided for @noCoursesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No courses available.'**
  String get noCoursesAvailable;

  /// No description provided for @somethingWentWrong.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong or no data exists.'**
  String get somethingWentWrong;

  /// No description provided for @enrolledStudentsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{1 student enrolled} other{{count} students enrolled}}'**
  String enrolledStudentsCount(num count);

  /// No description provided for @selectStartEndDates.
  ///
  /// In en, this message translates to:
  /// **'Please select start and end dates.'**
  String get selectStartEndDates;

  /// No description provided for @coursePublished.
  ///
  /// In en, this message translates to:
  /// **'Course published successfully!'**
  String get coursePublished;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @details.
  ///
  /// In en, this message translates to:
  /// **'Details'**
  String get details;

  /// No description provided for @schedule.
  ///
  /// In en, this message translates to:
  /// **'Schedule'**
  String get schedule;

  /// No description provided for @days.
  ///
  /// In en, this message translates to:
  /// **'Days'**
  String get days;

  /// No description provided for @price.
  ///
  /// In en, this message translates to:
  /// **'Price'**
  String get price;

  /// No description provided for @earningsBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Earnings Breakdown (Per Student)'**
  String get earningsBreakdown;

  /// No description provided for @teacherEarnings.
  ///
  /// In en, this message translates to:
  /// **'Teacher Earnings'**
  String get teacherEarnings;

  /// No description provided for @perStudent.
  ///
  /// In en, this message translates to:
  /// **'Per Student'**
  String get perStudent;

  /// No description provided for @storeFees.
  ///
  /// In en, this message translates to:
  /// **'App Store & Google Fees (15%)'**
  String get storeFees;

  /// No description provided for @calligroPlatform.
  ///
  /// In en, this message translates to:
  /// **'Calligro Platform (25%)'**
  String get calligroPlatform;

  /// No description provided for @summary.
  ///
  /// In en, this message translates to:
  /// **'Summary'**
  String get summary;

  /// No description provided for @arabicCalligraphy.
  ///
  /// In en, this message translates to:
  /// **'Arabic Calligraphy'**
  String get arabicCalligraphy;

  /// No description provided for @normalPenWriting.
  ///
  /// In en, this message translates to:
  /// **'Handwriting Improvement'**
  String get normalPenWriting;

  /// No description provided for @jaliThuluth.
  ///
  /// In en, this message translates to:
  /// **'Jali Thuluth'**
  String get jaliThuluth;

  /// No description provided for @jaliDiwani.
  ///
  /// In en, this message translates to:
  /// **'Jali Diwani'**
  String get jaliDiwani;

  /// No description provided for @persianTaliq.
  ///
  /// In en, this message translates to:
  /// **'Persian (Ta\'liq)'**
  String get persianTaliq;

  /// No description provided for @muhaqqaq.
  ///
  /// In en, this message translates to:
  /// **'Muhaqqaq'**
  String get muhaqqaq;

  /// No description provided for @rayhani.
  ///
  /// In en, this message translates to:
  /// **'Rayhani'**
  String get rayhani;

  /// No description provided for @intermediate.
  ///
  /// In en, this message translates to:
  /// **'Intermediate'**
  String get intermediate;

  /// No description provided for @beginnerDescriptionNormal.
  ///
  /// In en, this message translates to:
  /// **'Transform your handwriting from scratch. Master proper grip, posture, and the fundamental strokes needed to build a clear, confident, and legible writing style perfect for daily use.'**
  String get beginnerDescriptionNormal;

  /// No description provided for @intermediateDescriptionNormal.
  ///
  /// In en, this message translates to:
  /// **'Unlock the next level of penmanship. You will acquire new, effective techniques to enhance your writing flow and precision, giving your everyday handwriting a polished and professional look.'**
  String get intermediateDescriptionNormal;

  /// No description provided for @advancedDescriptionNormal.
  ///
  /// In en, this message translates to:
  /// **'Master the finest details of the art. This course introduces high-level skills and artistic methods, empowering you to develop a unique, distinguished style that leaves a lasting impression.'**
  String get advancedDescriptionNormal;

  /// No description provided for @beginnerDescriptionCalligraphy.
  ///
  /// In en, this message translates to:
  /// **'Embark on your journey into the {style} script. Learn the traditional rules of the reed pen, master the scale (Mizan) of individual letters, and build a strong foundation in this timeless art form.'**
  String beginnerDescriptionCalligraphy(String style);

  /// No description provided for @intermediateDescriptionCalligraphy.
  ///
  /// In en, this message translates to:
  /// **'Expand your artistic capabilities in the {style} script. You will learn essential techniques to strengthen your hand and eye, moving you from basic understanding to confident, fluid execution.'**
  String intermediateDescriptionCalligraphy(String style);

  /// No description provided for @advancedDescriptionCalligraphy.
  ///
  /// In en, this message translates to:
  /// **'Attain the highest level of craftsmanship in {style}. This course focuses on elite artistic skills and professional secrets, enabling you to create breathtaking masterpieces with authority.'**
  String advancedDescriptionCalligraphy(String style);

  /// No description provided for @validation.
  ///
  /// In en, this message translates to:
  /// **'Validation'**
  String get validation;

  /// No description provided for @pleaseSelectWritingType.
  ///
  /// In en, this message translates to:
  /// **'Please select writing type'**
  String get pleaseSelectWritingType;

  /// No description provided for @pleaseSelectCalligraphyStyle.
  ///
  /// In en, this message translates to:
  /// **'Please select calligraphy style'**
  String get pleaseSelectCalligraphyStyle;

  /// No description provided for @pleaseSelectCategory.
  ///
  /// In en, this message translates to:
  /// **'Please select a category'**
  String get pleaseSelectCategory;

  /// No description provided for @descriptionRequired.
  ///
  /// In en, this message translates to:
  /// **'Course description is required'**
  String get descriptionRequired;

  /// No description provided for @maxStudentsRequired.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of students is required'**
  String get maxStudentsRequired;

  /// No description provided for @selectNumberOfStudents.
  ///
  /// In en, this message translates to:
  /// **'Select Number of Students'**
  String get selectNumberOfStudents;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @chooseWritingType.
  ///
  /// In en, this message translates to:
  /// **'Choose Writing Type'**
  String get chooseWritingType;

  /// No description provided for @chooseCalligraphyStyle.
  ///
  /// In en, this message translates to:
  /// **'Choose Calligraphy Style'**
  String get chooseCalligraphyStyle;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose Category'**
  String get chooseCategory;

  /// No description provided for @enterCourseDescription.
  ///
  /// In en, this message translates to:
  /// **'Enter Course Description'**
  String get enterCourseDescription;

  /// No description provided for @maxStudentsHint.
  ///
  /// In en, this message translates to:
  /// **'Maximum number of students'**
  String get maxStudentsHint;

  /// No description provided for @toolsRequirements.
  ///
  /// In en, this message translates to:
  /// **'Tools & Requirements'**
  String get toolsRequirements;

  /// No description provided for @courseTimeline.
  ///
  /// In en, this message translates to:
  /// **'Course Curriculum'**
  String get courseTimeline;

  /// No description provided for @addStepHint.
  ///
  /// In en, this message translates to:
  /// **'Add a step (e.g. Week 1: Basics)'**
  String get addStepHint;

  /// No description provided for @startAddingSteps.
  ///
  /// In en, this message translates to:
  /// **'Start adding steps to build your curriculum.'**
  String get startAddingSteps;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @nextStep.
  ///
  /// In en, this message translates to:
  /// **'Next Step'**
  String get nextStep;

  /// No description provided for @addCustomTool.
  ///
  /// In en, this message translates to:
  /// **'Add Custom Tool'**
  String get addCustomTool;

  /// No description provided for @toolNameHint.
  ///
  /// In en, this message translates to:
  /// **'Tool Name (e.g. Ruler)'**
  String get toolNameHint;

  /// No description provided for @selectIcon.
  ///
  /// In en, this message translates to:
  /// **'Select Icon:'**
  String get selectIcon;

  /// No description provided for @pleaseSelectOneTool.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one tool.'**
  String get pleaseSelectOneTool;

  /// No description provided for @pleaseAddOneStep.
  ///
  /// In en, this message translates to:
  /// **'Please add at least one curriculum step.'**
  String get pleaseAddOneStep;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @bambooPen.
  ///
  /// In en, this message translates to:
  /// **'Bamboo Pen'**
  String get bambooPen;

  /// No description provided for @metalNib.
  ///
  /// In en, this message translates to:
  /// **'Metal Nib'**
  String get metalNib;

  /// No description provided for @likkaSilk.
  ///
  /// In en, this message translates to:
  /// **'Likka (Silk)'**
  String get likkaSilk;

  /// No description provided for @glossyPaper.
  ///
  /// In en, this message translates to:
  /// **'Glossy Paper'**
  String get glossyPaper;

  /// No description provided for @ink.
  ///
  /// In en, this message translates to:
  /// **'Ink'**
  String get ink;

  /// No description provided for @ballpointPen.
  ///
  /// In en, this message translates to:
  /// **'Ballpoint Pen'**
  String get ballpointPen;

  /// No description provided for @gelPen.
  ///
  /// In en, this message translates to:
  /// **'Gel Pen (0.5mm)'**
  String get gelPen;

  /// No description provided for @linedNotebook.
  ///
  /// In en, this message translates to:
  /// **'Lined Notebook'**
  String get linedNotebook;

  /// No description provided for @pencilEraser.
  ///
  /// In en, this message translates to:
  /// **'Pencil & Eraser'**
  String get pencilEraser;

  /// No description provided for @correctionTape.
  ///
  /// In en, this message translates to:
  /// **'Correction Tape'**
  String get correctionTape;

  /// No description provided for @connectingLetters.
  ///
  /// In en, this message translates to:
  /// **'Connecting Letters'**
  String get connectingLetters;

  /// No description provided for @wordSpacing.
  ///
  /// In en, this message translates to:
  /// **'Word Spacing'**
  String get wordSpacing;

  /// No description provided for @lineConsistency.
  ///
  /// In en, this message translates to:
  /// **'Line Consistency'**
  String get lineConsistency;

  /// No description provided for @speedWriting.
  ///
  /// In en, this message translates to:
  /// **'Speed Writing'**
  String get speedWriting;

  /// No description provided for @cursiveStyle.
  ///
  /// In en, this message translates to:
  /// **'Cursive Style'**
  String get cursiveStyle;

  /// No description provided for @signatureDesign.
  ///
  /// In en, this message translates to:
  /// **'Signature Design'**
  String get signatureDesign;

  /// No description provided for @fountainPenBasics.
  ///
  /// In en, this message translates to:
  /// **'Fountain Pen Basics'**
  String get fountainPenBasics;

  /// No description provided for @businessHandwriting.
  ///
  /// In en, this message translates to:
  /// **'Business Handwriting'**
  String get businessHandwriting;

  /// No description provided for @handPosture.
  ///
  /// In en, this message translates to:
  /// **'Hand Posture'**
  String get handPosture;

  /// No description provided for @paperPosition.
  ///
  /// In en, this message translates to:
  /// **'Paper Position'**
  String get paperPosition;

  /// No description provided for @basicShapes.
  ///
  /// In en, this message translates to:
  /// **'Basic Shapes'**
  String get basicShapes;

  /// No description provided for @lowercaseAM.
  ///
  /// In en, this message translates to:
  /// **'Lowercase a-m'**
  String get lowercaseAM;

  /// No description provided for @lowercaseNZ.
  ///
  /// In en, this message translates to:
  /// **'Lowercase n-z'**
  String get lowercaseNZ;

  /// No description provided for @reviewBasics.
  ///
  /// In en, this message translates to:
  /// **'Review Basics'**
  String get reviewBasics;

  /// No description provided for @complexConnections.
  ///
  /// In en, this message translates to:
  /// **'Complex Connections'**
  String get complexConnections;

  /// No description provided for @sentenceStructure.
  ///
  /// In en, this message translates to:
  /// **'Sentence Structure'**
  String get sentenceStructure;

  /// No description provided for @inkControl.
  ///
  /// In en, this message translates to:
  /// **'Ink Control'**
  String get inkControl;

  /// No description provided for @compositionRules.
  ///
  /// In en, this message translates to:
  /// **'Composition Rules'**
  String get compositionRules;

  /// No description provided for @jaliLargeScale.
  ///
  /// In en, this message translates to:
  /// **'Jali (Large Scale)'**
  String get jaliLargeScale;

  /// No description provided for @goldLeaf.
  ///
  /// In en, this message translates to:
  /// **'Gold Leaf'**
  String get goldLeaf;

  /// No description provided for @masterpieceCreation.
  ///
  /// In en, this message translates to:
  /// **'Masterpiece Creation'**
  String get masterpieceCreation;

  /// No description provided for @introToTools.
  ///
  /// In en, this message translates to:
  /// **'Intro to Tools'**
  String get introToTools;

  /// No description provided for @holdingThePen.
  ///
  /// In en, this message translates to:
  /// **'Holding the Pen'**
  String get holdingThePen;

  /// No description provided for @dotsNuqta.
  ///
  /// In en, this message translates to:
  /// **'Dots (Nuqta)'**
  String get dotsNuqta;

  /// No description provided for @letterAlif.
  ///
  /// In en, this message translates to:
  /// **'Letter Alif'**
  String get letterAlif;

  /// No description provided for @lettersBaRa.
  ///
  /// In en, this message translates to:
  /// **'Letters Ba-Ra'**
  String get lettersBaRa;

  /// No description provided for @locationPermissionRequired.
  ///
  /// In en, this message translates to:
  /// **'Location permission is required to handle time zones accurately.'**
  String get locationPermissionRequired;

  /// No description provided for @couldNotDetermineTimeZone.
  ///
  /// In en, this message translates to:
  /// **'Could not determine your time zone.'**
  String get couldNotDetermineTimeZone;

  /// No description provided for @pleaseSelectStartDate.
  ///
  /// In en, this message translates to:
  /// **'Please select a start date.'**
  String get pleaseSelectStartDate;

  /// No description provided for @pleaseSelectEndDate.
  ///
  /// In en, this message translates to:
  /// **'Please select an end date.'**
  String get pleaseSelectEndDate;

  /// No description provided for @pleaseSelectTime.
  ///
  /// In en, this message translates to:
  /// **'Please select a time.'**
  String get pleaseSelectTime;

  /// No description provided for @selectATime.
  ///
  /// In en, this message translates to:
  /// **'Select a Time'**
  String get selectATime;

  /// No description provided for @selectStartTime.
  ///
  /// In en, this message translates to:
  /// **'Select Start Time'**
  String get selectStartTime;

  /// No description provided for @selectEndTime.
  ///
  /// In en, this message translates to:
  /// **'Select End Time'**
  String get selectEndTime;

  /// No description provided for @endTimeBeforeStartTime.
  ///
  /// In en, this message translates to:
  /// **'End time must be after start time.'**
  String get endTimeBeforeStartTime;

  /// No description provided for @sessionTooLong.
  ///
  /// In en, this message translates to:
  /// **'Session duration cannot exceed 2 hours.'**
  String get sessionTooLong;

  /// No description provided for @courseDuration.
  ///
  /// In en, this message translates to:
  /// **'Course Duration'**
  String get courseDuration;

  /// No description provided for @courseDurationDays.
  ///
  /// In en, this message translates to:
  /// **'Course Duration: {count} days'**
  String courseDurationDays(int count);

  /// No description provided for @startDateNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Due to making enough time for students to enroll, you can\'t choose a start date before two weeks from now.'**
  String get startDateNote;

  /// No description provided for @selectAStartDate.
  ///
  /// In en, this message translates to:
  /// **'Select a Start Date'**
  String get selectAStartDate;

  /// No description provided for @endDateNote.
  ///
  /// In en, this message translates to:
  /// **'Note: The course can\'t be longer than 90 days.'**
  String get endDateNote;

  /// No description provided for @selectAnEndDate.
  ///
  /// In en, this message translates to:
  /// **'Select an End Date'**
  String get selectAnEndDate;

  /// No description provided for @timeZoneWaitMessage.
  ///
  /// In en, this message translates to:
  /// **'Please wait while we get your location for time zone handling...'**
  String get timeZoneWaitMessage;

  /// No description provided for @timeZoneNote.
  ///
  /// In en, this message translates to:
  /// **'Note: The time you choose will be displayed in your local time zone, but it will be adjusted to the local time zone of each student\'s country.'**
  String get timeZoneNote;

  /// No description provided for @yourTime.
  ///
  /// In en, this message translates to:
  /// **'Your Time'**
  String get yourTime;

  /// No description provided for @sunday.
  ///
  /// In en, this message translates to:
  /// **'Sunday'**
  String get sunday;

  /// No description provided for @monday.
  ///
  /// In en, this message translates to:
  /// **'Monday'**
  String get monday;

  /// No description provided for @tuesday.
  ///
  /// In en, this message translates to:
  /// **'Tuesday'**
  String get tuesday;

  /// No description provided for @wednesday.
  ///
  /// In en, this message translates to:
  /// **'Wednesday'**
  String get wednesday;

  /// No description provided for @thursday.
  ///
  /// In en, this message translates to:
  /// **'Thursday'**
  String get thursday;

  /// No description provided for @friday.
  ///
  /// In en, this message translates to:
  /// **'Friday'**
  String get friday;

  /// No description provided for @saturday.
  ///
  /// In en, this message translates to:
  /// **'Saturday'**
  String get saturday;

  /// No description provided for @cantChooseMoreThanTwoDays.
  ///
  /// In en, this message translates to:
  /// **'You can\'t choose more than two days.'**
  String get cantChooseMoreThanTwoDays;

  /// No description provided for @mandatoryDayConflict.
  ///
  /// In en, this message translates to:
  /// **'{day} is the course start date and cannot be removed.'**
  String mandatoryDayConflict(String day);

  /// No description provided for @pleaseSelectAtLeastOneDay.
  ///
  /// In en, this message translates to:
  /// **'Please select at least one day.'**
  String get pleaseSelectAtLeastOneDay;

  /// No description provided for @mandatoryDay.
  ///
  /// In en, this message translates to:
  /// **'Mandatory Day'**
  String get mandatoryDay;

  /// No description provided for @enterCoursePrice.
  ///
  /// In en, this message translates to:
  /// **'Enter Course Price'**
  String get enterCoursePrice;

  /// No description provided for @pleaseEnterCoursePrice.
  ///
  /// In en, this message translates to:
  /// **'Please enter a course price.'**
  String get pleaseEnterCoursePrice;

  /// No description provided for @priceInfoNote.
  ///
  /// In en, this message translates to:
  /// **'Note: The price is listed in US dollars. Please note that the final amount you receive may differ. For more details, kindly refer to the '**
  String get priceInfoNote;

  /// No description provided for @termsAndConditionsLinkSim.
  ///
  /// In en, this message translates to:
  /// **'This would link to the terms and conditions page.'**
  String get termsAndConditionsLinkSim;

  /// No description provided for @reviewAndConfirm.
  ///
  /// In en, this message translates to:
  /// **'Review & Confirm'**
  String get reviewAndConfirm;

  /// No description provided for @confirmDetails.
  ///
  /// In en, this message translates to:
  /// **'Confirm Details'**
  String get confirmDetails;

  /// No description provided for @googleMeetIntegration.
  ///
  /// In en, this message translates to:
  /// **'Calligro Meet Integration'**
  String get googleMeetIntegration;

  /// No description provided for @googleMeet.
  ///
  /// In en, this message translates to:
  /// **'Calligro Meet'**
  String get googleMeet;

  /// No description provided for @calligroMeet.
  ///
  /// In en, this message translates to:
  /// **'Calligro Meet'**
  String get calligroMeet;

  /// No description provided for @calligroMeetSubtext.
  ///
  /// In en, this message translates to:
  /// **'Our dedicated secure meeting platform'**
  String get calligroMeetSubtext;

  /// No description provided for @autoGeneratedLink.
  ///
  /// In en, this message translates to:
  /// **'Secure classroom ID'**
  String get autoGeneratedLink;

  /// No description provided for @generatingLink.
  ///
  /// In en, this message translates to:
  /// **'Setting up Classroom...'**
  String get generatingLink;

  /// No description provided for @meetingLinkAttached.
  ///
  /// In en, this message translates to:
  /// **'Classroom Ready'**
  String get meetingLinkAttached;

  /// No description provided for @failedToGenerateLink.
  ///
  /// In en, this message translates to:
  /// **'Failed to Setup Classroom.'**
  String get failedToGenerateLink;

  /// No description provided for @tooEarly.
  ///
  /// In en, this message translates to:
  /// **'Too Early'**
  String get tooEarly;

  /// No description provided for @classEnded.
  ///
  /// In en, this message translates to:
  /// **'Session Ended'**
  String get classEnded;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @courseInformation.
  ///
  /// In en, this message translates to:
  /// **'Course Information'**
  String get courseInformation;

  /// No description provided for @courseName.
  ///
  /// In en, this message translates to:
  /// **'Course Name'**
  String get courseName;

  /// No description provided for @type.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get type;

  /// No description provided for @maxStudents.
  ///
  /// In en, this message translates to:
  /// **'Max Students'**
  String get maxStudents;

  /// No description provided for @description.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get description;

  /// No description provided for @startDate.
  ///
  /// In en, this message translates to:
  /// **'Start Date'**
  String get startDate;

  /// No description provided for @endDate.
  ///
  /// In en, this message translates to:
  /// **'End Date'**
  String get endDate;

  /// No description provided for @startTime.
  ///
  /// In en, this message translates to:
  /// **'Start Time'**
  String get startTime;

  /// No description provided for @endTime.
  ///
  /// In en, this message translates to:
  /// **'End Time'**
  String get endTime;

  /// No description provided for @time.
  ///
  /// In en, this message translates to:
  /// **'Time'**
  String get time;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @confirmAndPost.
  ///
  /// In en, this message translates to:
  /// **'Confirm & Post'**
  String get confirmAndPost;

  /// No description provided for @classroomReady.
  ///
  /// In en, this message translates to:
  /// **'Classroom Ready'**
  String get classroomReady;

  /// No description provided for @learningOutcomes.
  ///
  /// In en, this message translates to:
  /// **'Learning Outcomes'**
  String get learningOutcomes;

  /// No description provided for @paypalEmail.
  ///
  /// In en, this message translates to:
  /// **'PayPal Email'**
  String get paypalEmail;

  /// No description provided for @coursePreviewNote.
  ///
  /// In en, this message translates to:
  /// **'This is how your course will look to students. All details are set and ready for publication!'**
  String get coursePreviewNote;

  /// No description provided for @saveAndReturnToCourse.
  ///
  /// In en, this message translates to:
  /// **'Save & Return to Course'**
  String get saveAndReturnToCourse;

  /// No description provided for @checkVerification.
  ///
  /// In en, this message translates to:
  /// **'Check Again'**
  String get checkVerification;

  /// No description provided for @posts.
  ///
  /// In en, this message translates to:
  /// **'Posts'**
  String get posts;

  /// No description provided for @followers.
  ///
  /// In en, this message translates to:
  /// **'Followers'**
  String get followers;

  /// No description provided for @myWork.
  ///
  /// In en, this message translates to:
  /// **'My Work'**
  String get myWork;

  /// No description provided for @collection.
  ///
  /// In en, this message translates to:
  /// **'Collection'**
  String get collection;

  /// No description provided for @nothingToShow.
  ///
  /// In en, this message translates to:
  /// **'Nothing to show here yet.'**
  String get nothingToShow;

  /// No description provided for @classBoard.
  ///
  /// In en, this message translates to:
  /// **'Class Board'**
  String get classBoard;

  /// No description provided for @newAnnouncement.
  ///
  /// In en, this message translates to:
  /// **'New Announcement'**
  String get newAnnouncement;

  /// No description provided for @writeSomethingToClass.
  ///
  /// In en, this message translates to:
  /// **'Write something to the class...'**
  String get writeSomethingToClass;

  /// No description provided for @publishNow.
  ///
  /// In en, this message translates to:
  /// **'PUBLISH NOW'**
  String get publishNow;

  /// No description provided for @publishing.
  ///
  /// In en, this message translates to:
  /// **'PUBLISHING...'**
  String get publishing;

  /// No description provided for @announcementPublished.
  ///
  /// In en, this message translates to:
  /// **'Announcement published! Students notified.'**
  String get announcementPublished;

  /// No description provided for @translating.
  ///
  /// In en, this message translates to:
  /// **'Translating...'**
  String get translating;

  /// No description provided for @studentSince.
  ///
  /// In en, this message translates to:
  /// **'Joined'**
  String get studentSince;

  /// No description provided for @daysShort.
  ///
  /// In en, this message translates to:
  /// **'DAYS'**
  String get daysShort;

  /// No description provided for @hoursShort.
  ///
  /// In en, this message translates to:
  /// **'HRS'**
  String get hoursShort;

  /// No description provided for @minutesShort.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get minutesShort;

  /// No description provided for @secondsShort.
  ///
  /// In en, this message translates to:
  /// **'SEC'**
  String get secondsShort;

  /// No description provided for @noAnnouncementsYet.
  ///
  /// In en, this message translates to:
  /// **'No announcements yet.'**
  String get noAnnouncementsYet;

  /// No description provided for @assignments.
  ///
  /// In en, this message translates to:
  /// **'Assignments'**
  String get assignments;

  /// No description provided for @newTask.
  ///
  /// In en, this message translates to:
  /// **'New Task'**
  String get newTask;

  /// No description provided for @taskTitle.
  ///
  /// In en, this message translates to:
  /// **'Task Title'**
  String get taskTitle;

  /// No description provided for @instructionsOptional.
  ///
  /// In en, this message translates to:
  /// **'Instructions (Optional)'**
  String get instructionsOptional;

  /// No description provided for @setDeadline.
  ///
  /// In en, this message translates to:
  /// **'Set Deadline'**
  String get setDeadline;

  /// No description provided for @points.
  ///
  /// In en, this message translates to:
  /// **'Points'**
  String get points;

  /// No description provided for @assignTask.
  ///
  /// In en, this message translates to:
  /// **'ASSIGN TASK'**
  String get assignTask;

  /// No description provided for @noTasksAssignedYet.
  ///
  /// In en, this message translates to:
  /// **'No tasks assigned yet.'**
  String get noTasksAssignedYet;

  /// No description provided for @closedAt.
  ///
  /// In en, this message translates to:
  /// **'Closed at {time}'**
  String closedAt(Object time);

  /// No description provided for @dueAt.
  ///
  /// In en, this message translates to:
  /// **'Due at {time}'**
  String dueAt(Object time);

  /// No description provided for @closedCaps.
  ///
  /// In en, this message translates to:
  /// **'CLOSED'**
  String get closedCaps;

  /// No description provided for @activeCaps.
  ///
  /// In en, this message translates to:
  /// **'ACTIVE'**
  String get activeCaps;

  /// No description provided for @totalCaps.
  ///
  /// In en, this message translates to:
  /// **'TOTAL'**
  String get totalCaps;

  /// No description provided for @titleDateTimeRequired.
  ///
  /// In en, this message translates to:
  /// **'Title, Date, and Time are required!'**
  String get titleDateTimeRequired;

  /// No description provided for @joinLiveSession.
  ///
  /// In en, this message translates to:
  /// **'JOIN LIVE SESSION'**
  String get joinLiveSession;

  /// No description provided for @startLiveSession.
  ///
  /// In en, this message translates to:
  /// **'START LIVE SESSION'**
  String get startLiveSession;

  /// No description provided for @coursePreview.
  ///
  /// In en, this message translates to:
  /// **'Course Preview'**
  String get coursePreview;

  /// No description provided for @preview.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get preview;

  /// No description provided for @viewDetails.
  ///
  /// In en, this message translates to:
  /// **'View Details'**
  String get viewDetails;

  /// No description provided for @enrollNow.
  ///
  /// In en, this message translates to:
  /// **'Enroll Now'**
  String get enrollNow;

  /// No description provided for @goToCourse.
  ///
  /// In en, this message translates to:
  /// **'Go to Course'**
  String get goToCourse;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @classroom.
  ///
  /// In en, this message translates to:
  /// **'Classroom'**
  String get classroom;

  /// No description provided for @weeklySession.
  ///
  /// In en, this message translates to:
  /// **'Weekly Session'**
  String get weeklySession;

  /// No description provided for @sessionBreakdown.
  ///
  /// In en, this message translates to:
  /// **'Session Breakdown'**
  String get sessionBreakdown;

  /// No description provided for @totalClasses.
  ///
  /// In en, this message translates to:
  /// **'{count} Total'**
  String totalClasses(Object count);

  /// No description provided for @noMeetingLinkSet.
  ///
  /// In en, this message translates to:
  /// **'No meeting link set for this course'**
  String get noMeetingLinkSet;

  /// No description provided for @couldNotLaunchMeeting.
  ///
  /// In en, this message translates to:
  /// **'Could not launch meeting link'**
  String get couldNotLaunchMeeting;

  /// No description provided for @tbd.
  ///
  /// In en, this message translates to:
  /// **'TBD'**
  String get tbd;

  /// No description provided for @sessionTimeZoneNote.
  ///
  /// In en, this message translates to:
  /// **'Note: Session times are displayed based on your current time zone.'**
  String get sessionTimeZoneNote;

  /// No description provided for @curriculumTbd.
  ///
  /// In en, this message translates to:
  /// **'A detailed curriculum will be provided by the instructor at the start of the course.'**
  String get curriculumTbd;

  /// No description provided for @noToolsListed.
  ///
  /// In en, this message translates to:
  /// **'No specific tools listed by the instructor.'**
  String get noToolsListed;

  /// No description provided for @module.
  ///
  /// In en, this message translates to:
  /// **'Module {number}'**
  String module(Object number);

  /// No description provided for @publicInfoCaps.
  ///
  /// In en, this message translates to:
  /// **'PUBLIC INFO'**
  String get publicInfoCaps;

  /// No description provided for @privateDetailsCaps.
  ///
  /// In en, this message translates to:
  /// **'PRIVATE DETAILS'**
  String get privateDetailsCaps;

  /// No description provided for @aboutMeCaps.
  ///
  /// In en, this message translates to:
  /// **'ABOUT ME'**
  String get aboutMeCaps;

  /// No description provided for @bio.
  ///
  /// In en, this message translates to:
  /// **'Bio'**
  String get bio;

  /// No description provided for @writeShortIntro.
  ///
  /// In en, this message translates to:
  /// **'Write a short introduction...'**
  String get writeShortIntro;

  /// No description provided for @nameRequired.
  ///
  /// In en, this message translates to:
  /// **'Name is required'**
  String get nameRequired;

  /// No description provided for @noChangesDetected.
  ///
  /// In en, this message translates to:
  /// **'No changes detected.'**
  String get noChangesDetected;

  /// No description provided for @phoneInUseAlready.
  ///
  /// In en, this message translates to:
  /// **'This phone number is already in use.'**
  String get phoneInUseAlready;

  /// No description provided for @profileUpdated.
  ///
  /// In en, this message translates to:
  /// **'Profile updated successfully!'**
  String get profileUpdated;

  /// No description provided for @noChanges.
  ///
  /// In en, this message translates to:
  /// **'No Changes'**
  String get noChanges;

  /// No description provided for @security.
  ///
  /// In en, this message translates to:
  /// **'Security'**
  String get security;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @accountCaps.
  ///
  /// In en, this message translates to:
  /// **'ACCOUNT'**
  String get accountCaps;

  /// No description provided for @preferencesCaps.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferencesCaps;

  /// No description provided for @supportLegalCaps.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT & LEGAL'**
  String get supportLegalCaps;

  /// No description provided for @editProfileSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Bio, Specialty, Photo'**
  String get editProfileSubtitle;

  /// No description provided for @payoutSettings.
  ///
  /// In en, this message translates to:
  /// **'Payout Settings'**
  String get payoutSettings;

  /// No description provided for @payoutSettingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Manage bank accounts'**
  String get payoutSettingsSubtitle;

  /// No description provided for @actionRequiredPayout.
  ///
  /// In en, this message translates to:
  /// **'To publish courses and receive payments, please complete your payout setup.'**
  String get actionRequiredPayout;

  /// No description provided for @payoutRequirementTitle.
  ///
  /// In en, this message translates to:
  /// **'Payout Method Required'**
  String get payoutRequirementTitle;

  /// No description provided for @payoutRequirementMessage.
  ///
  /// In en, this message translates to:
  /// **'You must add a payout method (Bank, CliQ, or Western Union) before you can publish your course.'**
  String get payoutRequirementMessage;

  /// No description provided for @setupNow.
  ///
  /// In en, this message translates to:
  /// **'Setup Now'**
  String get setupNow;

  /// No description provided for @securitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password, Account'**
  String get securitySubtitle;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @helpCenter.
  ///
  /// In en, this message translates to:
  /// **'Help Center'**
  String get helpCenter;

  /// No description provided for @termsPrivacy.
  ///
  /// In en, this message translates to:
  /// **'Terms & Privacy'**
  String get termsPrivacy;

  /// No description provided for @aboutCalligro.
  ///
  /// In en, this message translates to:
  /// **'About Calligro'**
  String get aboutCalligro;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign Out'**
  String get signOut;

  /// No description provided for @classNotStarted.
  ///
  /// In en, this message translates to:
  /// **'Class not started'**
  String get classNotStarted;

  /// No description provided for @timerDays.
  ///
  /// In en, this message translates to:
  /// **'DAYS'**
  String get timerDays;

  /// No description provided for @timerHrs.
  ///
  /// In en, this message translates to:
  /// **'HRS'**
  String get timerHrs;

  /// No description provided for @timerMin.
  ///
  /// In en, this message translates to:
  /// **'MIN'**
  String get timerMin;

  /// No description provided for @timerSec.
  ///
  /// In en, this message translates to:
  /// **'SEC'**
  String get timerSec;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version {version}'**
  String version(Object version);

  /// No description provided for @aboutDescription.
  ///
  /// In en, this message translates to:
  /// **'Calligro is a specialized platform for learning Arabic calligraphy, connecting master artists with passionate students worldwide.'**
  String get aboutDescription;

  /// No description provided for @copyright.
  ///
  /// In en, this message translates to:
  /// **'© 2025 Calligro.\nAll Rights Reserved.'**
  String get copyright;

  /// No description provided for @paymentSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Payment Successful!'**
  String get paymentSuccessful;

  /// No description provided for @welcomeToAcademy.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the Calligro Academy!'**
  String get welcomeToAcademy;

  /// No description provided for @unlockPotential.
  ///
  /// In en, this message translates to:
  /// **'Unlock your potential'**
  String get unlockPotential;

  /// No description provided for @startLearningNow.
  ///
  /// In en, this message translates to:
  /// **'START LEARNING NOW'**
  String get startLearningNow;

  /// No description provided for @googleAccountAlertTitle.
  ///
  /// In en, this message translates to:
  /// **'Google Account Detected'**
  String get googleAccountAlertTitle;

  /// No description provided for @googleAccountAlertMessage.
  ///
  /// In en, this message translates to:
  /// **'You are registered with Google. Please use the Google Sign-In button to access your account.'**
  String get googleAccountAlertMessage;

  /// No description provided for @googleCalendarConnection.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar Connection'**
  String get googleCalendarConnection;

  /// No description provided for @googleCalendarConnectionSubtitle.
  ///
  /// In en, this message translates to:
  /// **'One-time setup for hosting meetings'**
  String get googleCalendarConnectionSubtitle;

  /// No description provided for @googleCalendarNote.
  ///
  /// In en, this message translates to:
  /// **'Connect your Google account once to allow Calligro to generate Google Meet links for your courses. You will remain the host of all meetings. This works for both Email and Google registered accounts.'**
  String get googleCalendarNote;

  /// No description provided for @connectCalendar.
  ///
  /// In en, this message translates to:
  /// **'Connect Calendar'**
  String get connectCalendar;

  /// No description provided for @disconnectCalendar.
  ///
  /// In en, this message translates to:
  /// **'Disconnect Calendar'**
  String get disconnectCalendar;

  /// No description provided for @calendarConnected.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar Connected'**
  String get calendarConnected;

  /// No description provided for @calendarDisconnected.
  ///
  /// In en, this message translates to:
  /// **'Google Calendar Disconnected'**
  String get calendarDisconnected;

  /// No description provided for @failedToConnectCalendar.
  ///
  /// In en, this message translates to:
  /// **'Failed to connect Google Calendar.'**
  String get failedToConnectCalendar;

  /// No description provided for @offlineAccessRequired.
  ///
  /// In en, this message translates to:
  /// **'Offline access is required to manage your calendar on your behalf.'**
  String get offlineAccessRequired;

  /// No description provided for @changePassword.
  ///
  /// In en, this message translates to:
  /// **'Change Password'**
  String get changePassword;

  /// No description provided for @currentPassword.
  ///
  /// In en, this message translates to:
  /// **'Current Password'**
  String get currentPassword;

  /// No description provided for @enterCurrentPassword.
  ///
  /// In en, this message translates to:
  /// **'Enter current password'**
  String get enterCurrentPassword;

  /// No description provided for @min6Characters.
  ///
  /// In en, this message translates to:
  /// **'Min 6 characters'**
  String get min6Characters;

  /// No description provided for @update.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get update;

  /// No description provided for @passwordUpdatedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Password updated successfully!'**
  String get passwordUpdatedSuccessfully;

  /// No description provided for @currentPasswordIncorrect.
  ///
  /// In en, this message translates to:
  /// **'Current password is incorrect.'**
  String get currentPasswordIncorrect;

  /// No description provided for @newPasswordWeak.
  ///
  /// In en, this message translates to:
  /// **'New password is too weak.'**
  String get newPasswordWeak;

  /// No description provided for @deleteAccount.
  ///
  /// In en, this message translates to:
  /// **'Delete Account'**
  String get deleteAccount;

  /// No description provided for @deleteAccountQuestion.
  ///
  /// In en, this message translates to:
  /// **'Delete Account?'**
  String get deleteAccountQuestion;

  /// No description provided for @deleteAccountWarning.
  ///
  /// In en, this message translates to:
  /// **'This action is permanent. Your profile and personal data will be erased.'**
  String get deleteAccountWarning;

  /// No description provided for @deleteCaps.
  ///
  /// In en, this message translates to:
  /// **'DELETE'**
  String get deleteCaps;

  /// No description provided for @reloginToDelete.
  ///
  /// In en, this message translates to:
  /// **'Security: Please Log Out and Log In again to delete account.'**
  String get reloginToDelete;

  /// No description provided for @loginSecurityCaps.
  ///
  /// In en, this message translates to:
  /// **'LOGIN SECURITY'**
  String get loginSecurityCaps;

  /// No description provided for @updateCurrentPasswordSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update your current password'**
  String get updateCurrentPasswordSubtitle;

  /// No description provided for @dangerZoneCaps.
  ///
  /// In en, this message translates to:
  /// **'DANGER ZONE'**
  String get dangerZoneCaps;

  /// No description provided for @deleteAccountSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Permanently remove your data'**
  String get deleteAccountSubtitle;

  /// No description provided for @languageUpdated.
  ///
  /// In en, this message translates to:
  /// **'Language updated successfully!'**
  String get languageUpdated;

  /// No description provided for @failedToUpdateLanguage.
  ///
  /// In en, this message translates to:
  /// **'Failed to update language: {error}'**
  String failedToUpdateLanguage(Object error);

  /// No description provided for @selectPreferredLanguageCaps.
  ///
  /// In en, this message translates to:
  /// **'SELECT PREFERRED LANGUAGE'**
  String get selectPreferredLanguageCaps;

  /// No description provided for @languageRestartNote.
  ///
  /// In en, this message translates to:
  /// **'Changing the language will restart the application to apply the new settings.'**
  String get languageRestartNote;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @arabic.
  ///
  /// In en, this message translates to:
  /// **'Arabic'**
  String get arabic;

  /// No description provided for @turkish.
  ///
  /// In en, this message translates to:
  /// **'Turkish'**
  String get turkish;

  /// No description provided for @saveSettings.
  ///
  /// In en, this message translates to:
  /// **'Save Settings'**
  String get saveSettings;

  /// No description provided for @payoutSettingsUpdated.
  ///
  /// In en, this message translates to:
  /// **'Payout settings updated successfully!'**
  String get payoutSettingsUpdated;

  /// No description provided for @selectPayoutMethodCaps.
  ///
  /// In en, this message translates to:
  /// **'SELECT PAYOUT METHOD'**
  String get selectPayoutMethodCaps;

  /// No description provided for @bankName.
  ///
  /// In en, this message translates to:
  /// **'Bank Name'**
  String get bankName;

  /// No description provided for @iban.
  ///
  /// In en, this message translates to:
  /// **'IBAN'**
  String get iban;

  /// No description provided for @payoutsProcessedMonthly.
  ///
  /// In en, this message translates to:
  /// **'You are responsible for providing the correct data. Please double-check all information before saving.'**
  String get payoutsProcessedMonthly;

  /// No description provided for @cliqDetailsCaps.
  ///
  /// In en, this message translates to:
  /// **'CLIQ DETAILS'**
  String get cliqDetailsCaps;

  /// No description provided for @jordanOnly.
  ///
  /// In en, this message translates to:
  /// **'Jordan Only'**
  String get jordanOnly;

  /// No description provided for @cliqAliasHint.
  ///
  /// In en, this message translates to:
  /// **'CliQ Alias / Mobile Number'**
  String get cliqAliasHint;

  /// No description provided for @accountHolderNameOptional.
  ///
  /// In en, this message translates to:
  /// **'Account Holder Name (Optional)'**
  String get accountHolderNameOptional;

  /// No description provided for @bankTransferDetailsCaps.
  ///
  /// In en, this message translates to:
  /// **'BANK TRANSFER DETAILS'**
  String get bankTransferDetailsCaps;

  /// No description provided for @swiftCodeOptional.
  ///
  /// In en, this message translates to:
  /// **'SWIFT Code (Optional)'**
  String get swiftCodeOptional;

  /// No description provided for @wuMoneyTransferCaps.
  ///
  /// In en, this message translates to:
  /// **'WESTERN UNION MONEY TRANSFER'**
  String get wuMoneyTransferCaps;

  /// No description provided for @receiverFullName.
  ///
  /// In en, this message translates to:
  /// **'Full Receiver Name (as on ID)'**
  String get receiverFullName;

  /// No description provided for @cityCountry.
  ///
  /// In en, this message translates to:
  /// **'City / Country'**
  String get cityCountry;

  /// No description provided for @purposeOfTransferOptional.
  ///
  /// In en, this message translates to:
  /// **'Purpose of Transfer (Optional)'**
  String get purposeOfTransferOptional;

  /// No description provided for @changePayoutMethodQuestion.
  ///
  /// In en, this message translates to:
  /// **'Change Payout Method?'**
  String get changePayoutMethodQuestion;

  /// No description provided for @payoutMethodSwitchWarning.
  ///
  /// In en, this message translates to:
  /// **'You are switching from {old} to {newMethod}.\n\nYour old {old} details will be removed.'**
  String payoutMethodSwitchWarning(String old, String newMethod);

  /// No description provided for @confirmChange.
  ///
  /// In en, this message translates to:
  /// **'Confirm Change'**
  String get confirmChange;

  /// No description provided for @bankTransfer.
  ///
  /// In en, this message translates to:
  /// **'Bank Transfer'**
  String get bankTransfer;

  /// No description provided for @westernUnion.
  ///
  /// In en, this message translates to:
  /// **'Western Union'**
  String get westernUnion;

  /// No description provided for @optional.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get optional;

  /// No description provided for @bank.
  ///
  /// In en, this message translates to:
  /// **'Bank'**
  String get bank;

  /// No description provided for @validationRequired.
  ///
  /// In en, this message translates to:
  /// **'{field} is required'**
  String validationRequired(Object field);

  /// No description provided for @setupTitle.
  ///
  /// In en, this message translates to:
  /// **'Let\'s put a picture for your profile'**
  String get setupTitle;

  /// No description provided for @setupSubtitle.
  ///
  /// In en, this message translates to:
  /// **'As a teacher, your profile photo is your brand. Please upload a clear, professional photo to continue.'**
  String get setupSubtitle;

  /// No description provided for @step1UploadPhoto.
  ///
  /// In en, this message translates to:
  /// **'Step 1: Upload Profile Photo'**
  String get step1UploadPhoto;

  /// No description provided for @step2TeachingCalendar.
  ///
  /// In en, this message translates to:
  /// **'Step 2: Teaching Calendar'**
  String get step2TeachingCalendar;

  /// No description provided for @connectCalendarRequired.
  ///
  /// In en, this message translates to:
  /// **'Connect Calendar (Required)'**
  String get connectCalendarRequired;

  /// No description provided for @calendarExplanation.
  ///
  /// In en, this message translates to:
  /// **'To start your classes as the \'Host\' and have full control of the room, you must connect your Google Calendar. This allows the app to create secure video links that YOU own.'**
  String get calendarExplanation;

  /// No description provided for @calendarImportantNote.
  ///
  /// In en, this message translates to:
  /// **'VERY IMPORTANT: You MUST connect the same Google email you used to sign up for Calligro. If you link a different email, you will not be able to enter your meetings as the host or admin.'**
  String get calendarImportantNote;

  /// No description provided for @emailMismatchTitle.
  ///
  /// In en, this message translates to:
  /// **'Wrong Google Account'**
  String get emailMismatchTitle;

  /// No description provided for @emailMismatchDescription.
  ///
  /// In en, this message translates to:
  /// **'You must use your Calligro email to connect Google Calendar.'**
  String get emailMismatchDescription;

  /// No description provided for @requiredEmail.
  ///
  /// In en, this message translates to:
  /// **'Required Email'**
  String get requiredEmail;

  /// No description provided for @connectedEmail.
  ///
  /// In en, this message translates to:
  /// **'Connected Now'**
  String get connectedEmail;

  /// No description provided for @emailMismatchNote.
  ///
  /// In en, this message translates to:
  /// **'The Google account \'{googleEmail}\' does not match your Calligro account \'{appEmail}\'. You must use the same email to ensure you have host control of your meetings.'**
  String emailMismatchNote(String googleEmail, String appEmail);

  /// No description provided for @tryAnotherAccount.
  ///
  /// In en, this message translates to:
  /// **'Try Different Account'**
  String get tryAnotherAccount;

  /// No description provided for @connectGoogleNow.
  ///
  /// In en, this message translates to:
  /// **'Connect Google Calendar Now'**
  String get connectGoogleNow;

  /// No description provided for @calendarLinkedSuccess.
  ///
  /// In en, this message translates to:
  /// **'✅ Calendar Linked Successfully'**
  String get calendarLinkedSuccess;

  /// No description provided for @submitForApproval.
  ///
  /// In en, this message translates to:
  /// **'Complete Account Setup'**
  String get submitForApproval;

  /// No description provided for @searchForHelp.
  ///
  /// In en, this message translates to:
  /// **'Search for help...'**
  String get searchForHelp;

  /// No description provided for @faqHeaderCaps.
  ///
  /// In en, this message translates to:
  /// **'FREQUENTLY ASKED QUESTIONS'**
  String get faqHeaderCaps;

  /// No description provided for @stillNeedHelp.
  ///
  /// In en, this message translates to:
  /// **'Still need help?'**
  String get stillNeedHelp;

  /// No description provided for @supportAvailable247.
  ///
  /// In en, this message translates to:
  /// **'Our support team is available 24/7 to assist you with any issues.'**
  String get supportAvailable247;

  /// No description provided for @faqEarningsQ.
  ///
  /// In en, this message translates to:
  /// **'How do I withdraw my earnings?'**
  String get faqEarningsQ;

  /// No description provided for @faqEarningsA.
  ///
  /// In en, this message translates to:
  /// **'You can withdraw your earnings via Bank Transfer or PayPal. Go to Settings > Payout Settings to add your details. Payouts are processed every Monday.'**
  String get faqEarningsA;

  /// No description provided for @faqAvailabilityQ.
  ///
  /// In en, this message translates to:
  /// **'How do I change my availability?'**
  String get faqAvailabilityQ;

  /// No description provided for @faqAvailabilityA.
  ///
  /// In en, this message translates to:
  /// **'Navigate to your Calendar tab. Tap on a specific date to edit your available slots or set a recurring schedule in the Calendar Settings.'**
  String get faqAvailabilityA;

  /// No description provided for @faqCancellationsQ.
  ///
  /// In en, this message translates to:
  /// **'What happens if a student cancels?'**
  String get faqCancellationsQ;

  /// No description provided for @faqCancellationsA.
  ///
  /// In en, this message translates to:
  /// **'If a student cancels more than 24 hours before the class, they receive a full refund. If they cancel within 24 hours, you receive 50% of the class fee.'**
  String get faqCancellationsA;

  /// No description provided for @faqContactQ.
  ///
  /// In en, this message translates to:
  /// **'How do I contact support?'**
  String get faqContactQ;

  /// No description provided for @faqContactA.
  ///
  /// In en, this message translates to:
  /// **'You can use the \'Contact Us\' button below to send us an email, or reach out via our social media channels for quick updates.'**
  String get faqContactA;

  /// No description provided for @upcomingClass.
  ///
  /// In en, this message translates to:
  /// **'Upcoming Class'**
  String get upcomingClass;

  /// No description provided for @upcomingClassSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{courseName} starts in {time}.'**
  String upcomingClassSubtitle(Object courseName, Object time);

  /// No description provided for @newStudentEnrolled.
  ///
  /// In en, this message translates to:
  /// **'New Student Enrolled'**
  String get newStudentEnrolled;

  /// No description provided for @newStudentEnrolledSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{studentName} just joined \'{courseName}\'.'**
  String newStudentEnrolledSubtitle(Object courseName, Object studentName);

  /// No description provided for @courseApproved.
  ///
  /// In en, this message translates to:
  /// **'Course Approved'**
  String get courseApproved;

  /// No description provided for @courseApprovedSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Your course \'{courseName}\' is now live.'**
  String courseApprovedSubtitle(Object courseName);

  /// No description provided for @newLike.
  ///
  /// In en, this message translates to:
  /// **'New Like'**
  String get newLike;

  /// No description provided for @newLikeSubtitle.
  ///
  /// In en, this message translates to:
  /// **'{name} liked your post \'{postTitle}\'.'**
  String newLikeSubtitle(Object name, Object postTitle);

  /// No description provided for @systemUpdate.
  ///
  /// In en, this message translates to:
  /// **'System Update'**
  String get systemUpdate;

  /// No description provided for @systemUpdateSubtitle.
  ///
  /// In en, this message translates to:
  /// **'We\'ve updated our Terms of Service.'**
  String get systemUpdateSubtitle;

  /// No description provided for @tenMinutesAgo.
  ///
  /// In en, this message translates to:
  /// **'10m ago'**
  String get tenMinutesAgo;

  /// No description provided for @twoHoursAgo.
  ///
  /// In en, this message translates to:
  /// **'2h ago'**
  String get twoHoursAgo;

  /// No description provided for @oneDayAgo.
  ///
  /// In en, this message translates to:
  /// **'1d ago'**
  String get oneDayAgo;

  /// No description provided for @twoDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'2d ago'**
  String get twoDaysAgo;

  /// No description provided for @fiveDaysAgo.
  ///
  /// In en, this message translates to:
  /// **'5d ago'**
  String get fiveDaysAgo;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @comingSoon.
  ///
  /// In en, this message translates to:
  /// **'Coming Soon'**
  String get comingSoon;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get loading;

  /// No description provided for @anonymous.
  ///
  /// In en, this message translates to:
  /// **'Anonymous'**
  String get anonymous;

  /// No description provided for @beginner.
  ///
  /// In en, this message translates to:
  /// **'Beginner'**
  String get beginner;

  /// No description provided for @advanced.
  ///
  /// In en, this message translates to:
  /// **'Advanced'**
  String get advanced;

  /// No description provided for @kufi.
  ///
  /// In en, this message translates to:
  /// **'Kufi'**
  String get kufi;

  /// No description provided for @ruqah.
  ///
  /// In en, this message translates to:
  /// **'Ruqah'**
  String get ruqah;

  /// No description provided for @ijaza.
  ///
  /// In en, this message translates to:
  /// **'Ijaza'**
  String get ijaza;

  /// No description provided for @maghribi.
  ///
  /// In en, this message translates to:
  /// **'Maghribi'**
  String get maghribi;

  /// No description provided for @failedToGenerate.
  ///
  /// In en, this message translates to:
  /// **'Failed to generate'**
  String get failedToGenerate;

  /// No description provided for @noDescriptionProvided.
  ///
  /// In en, this message translates to:
  /// **'No description provided'**
  String get noDescriptionProvided;

  /// No description provided for @curriculum.
  ///
  /// In en, this message translates to:
  /// **'Curriculum'**
  String get curriculum;

  /// No description provided for @announcements.
  ///
  /// In en, this message translates to:
  /// **'Announcements'**
  String get announcements;

  /// No description provided for @bin.
  ///
  /// In en, this message translates to:
  /// **'Bin'**
  String get bin;

  /// No description provided for @submissions.
  ///
  /// In en, this message translates to:
  /// **'Submissions'**
  String get submissions;

  /// No description provided for @students.
  ///
  /// In en, this message translates to:
  /// **'Students'**
  String get students;

  /// No description provided for @notAvailableShort.
  ///
  /// In en, this message translates to:
  /// **'N/A'**
  String get notAvailableShort;

  /// No description provided for @noStudentsEnrolledYet.
  ///
  /// In en, this message translates to:
  /// **'No students enrolled yet'**
  String get noStudentsEnrolledYet;

  /// No description provided for @unknownStudent.
  ///
  /// In en, this message translates to:
  /// **'Unknown Student'**
  String get unknownStudent;

  /// No description provided for @noEmail.
  ///
  /// In en, this message translates to:
  /// **'No email'**
  String get noEmail;

  /// No description provided for @accountHolderName.
  ///
  /// In en, this message translates to:
  /// **'Account Holder Name'**
  String get accountHolderName;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @upcoming.
  ///
  /// In en, this message translates to:
  /// **'Upcoming'**
  String get upcoming;

  /// No description provided for @ended.
  ///
  /// In en, this message translates to:
  /// **'Ended'**
  String get ended;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @introToThuluth.
  ///
  /// In en, this message translates to:
  /// **'Intro to Thuluth'**
  String get introToThuluth;

  /// No description provided for @letterAlifBaa.
  ///
  /// In en, this message translates to:
  /// **'Letter Alif & Baa'**
  String get letterAlifBaa;

  /// No description provided for @jointLetters.
  ///
  /// In en, this message translates to:
  /// **'Joint Letters'**
  String get jointLetters;

  /// No description provided for @sentences.
  ///
  /// In en, this message translates to:
  /// **'Sentences'**
  String get sentences;

  /// No description provided for @finalProject.
  ///
  /// In en, this message translates to:
  /// **'Final Project'**
  String get finalProject;

  /// No description provided for @noChangesToSave.
  ///
  /// In en, this message translates to:
  /// **'No changes to save'**
  String get noChangesToSave;

  /// No description provided for @noPostsYet.
  ///
  /// In en, this message translates to:
  /// **'No posts yet'**
  String get noPostsYet;

  /// No description provided for @selectLanguage.
  ///
  /// In en, this message translates to:
  /// **'Select Language'**
  String get selectLanguage;

  /// No description provided for @continueRegistrationWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue registration with Google'**
  String get continueRegistrationWithGoogle;

  /// No description provided for @continueWithGoogle.
  ///
  /// In en, this message translates to:
  /// **'Continue with Google'**
  String get continueWithGoogle;

  /// No description provided for @maybeLater.
  ///
  /// In en, this message translates to:
  /// **'Maybe later'**
  String get maybeLater;

  /// No description provided for @continueToDashboard.
  ///
  /// In en, this message translates to:
  /// **'Continue to Dashboard'**
  String get continueToDashboard;

  /// No description provided for @viewAnnouncements.
  ///
  /// In en, this message translates to:
  /// **'View announcements'**
  String get viewAnnouncements;

  /// No description provided for @myAssignments.
  ///
  /// In en, this message translates to:
  /// **'My Assignments'**
  String get myAssignments;

  /// No description provided for @assignmentDetails.
  ///
  /// In en, this message translates to:
  /// **'Assignment Details'**
  String get assignmentDetails;

  /// No description provided for @noInstructionsProvided.
  ///
  /// In en, this message translates to:
  /// **'No instructions provided.'**
  String get noInstructionsProvided;

  /// No description provided for @yourSubmission.
  ///
  /// In en, this message translates to:
  /// **'Your Submission'**
  String get yourSubmission;

  /// No description provided for @attachWorkFile.
  ///
  /// In en, this message translates to:
  /// **'Attach Work File (PDF/Image/etc.)'**
  String get attachWorkFile;

  /// No description provided for @addNoteOptional.
  ///
  /// In en, this message translates to:
  /// **'Add a note (Optional)'**
  String get addNoteOptional;

  /// No description provided for @submitAssignment.
  ///
  /// In en, this message translates to:
  /// **'Submit Assignment'**
  String get submitAssignment;

  /// No description provided for @updateSubmission.
  ///
  /// In en, this message translates to:
  /// **'Update Submission'**
  String get updateSubmission;

  /// No description provided for @deleteSubmission.
  ///
  /// In en, this message translates to:
  /// **'Delete Submission'**
  String get deleteSubmission;

  /// No description provided for @deleteSubmissionConfirm.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete your submission? This will remove your attached file and note.'**
  String get deleteSubmissionConfirm;

  /// No description provided for @deadlinePassed.
  ///
  /// In en, this message translates to:
  /// **'Deadline Passed'**
  String get deadlinePassed;

  /// No description provided for @editSubmission.
  ///
  /// In en, this message translates to:
  /// **'Edit Submission'**
  String get editSubmission;

  /// No description provided for @assignmentSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Assignment submitted successfully!'**
  String get assignmentSubmitted;

  /// No description provided for @pleasePickFile.
  ///
  /// In en, this message translates to:
  /// **'Please pick a file to submit.'**
  String get pleasePickFile;

  /// No description provided for @noSubmissionsYet.
  ///
  /// In en, this message translates to:
  /// **'No submissions yet.'**
  String get noSubmissionsYet;

  /// No description provided for @markAsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Mark as Reviewed'**
  String get markAsReviewed;

  /// No description provided for @markedAsReviewed.
  ///
  /// In en, this message translates to:
  /// **'Marked as Reviewed'**
  String get markedAsReviewed;

  /// No description provided for @studentNote.
  ///
  /// In en, this message translates to:
  /// **'Student Note'**
  String get studentNote;

  /// No description provided for @grade.
  ///
  /// In en, this message translates to:
  /// **'Grade'**
  String get grade;

  /// No description provided for @graded.
  ///
  /// In en, this message translates to:
  /// **'Graded'**
  String get graded;

  /// No description provided for @invalidPoints.
  ///
  /// In en, this message translates to:
  /// **'Invalid points value'**
  String get invalidPoints;

  /// No description provided for @gradeSaved.
  ///
  /// In en, this message translates to:
  /// **'Grade saved successfully!'**
  String get gradeSaved;

  /// No description provided for @deadline.
  ///
  /// In en, this message translates to:
  /// **'Deadline'**
  String get deadline;

  /// No description provided for @maxPoints.
  ///
  /// In en, this message translates to:
  /// **'Max Points'**
  String get maxPoints;

  /// No description provided for @instructions.
  ///
  /// In en, this message translates to:
  /// **'Instructions'**
  String get instructions;

  /// No description provided for @submitted.
  ///
  /// In en, this message translates to:
  /// **'Submitted'**
  String get submitted;

  /// No description provided for @enrolled.
  ///
  /// In en, this message translates to:
  /// **'Enrolled'**
  String get enrolled;

  /// No description provided for @noEnrolledCourses.
  ///
  /// In en, this message translates to:
  /// **'You haven\'t enrolled in any courses yet'**
  String get noEnrolledCourses;

  /// No description provided for @browseCoursesToEnroll.
  ///
  /// In en, this message translates to:
  /// **'Browse available courses and start your calligraphy journey!'**
  String get browseCoursesToEnroll;

  /// No description provided for @enrollmentStatus.
  ///
  /// In en, this message translates to:
  /// **'Enrollment Status'**
  String get enrollmentStatus;

  /// No description provided for @accessCourse.
  ///
  /// In en, this message translates to:
  /// **'Access Course'**
  String get accessCourse;

  /// No description provided for @courseNameTemplate.
  ///
  /// In en, this message translates to:
  /// **'{subject} Course for {level}'**
  String courseNameTemplate(Object level, Object subject);

  /// No description provided for @exploreCourses.
  ///
  /// In en, this message translates to:
  /// **'Explore Courses'**
  String get exploreCourses;

  /// No description provided for @myLearning.
  ///
  /// In en, this message translates to:
  /// **'My Learning'**
  String get myLearning;

  /// No description provided for @certificates.
  ///
  /// In en, this message translates to:
  /// **'Certificates'**
  String get certificates;

  /// No description provided for @goodMorning.
  ///
  /// In en, this message translates to:
  /// **'Good Morning'**
  String get goodMorning;

  /// No description provided for @goodAfternoon.
  ///
  /// In en, this message translates to:
  /// **'Good Afternoon'**
  String get goodAfternoon;

  /// No description provided for @goodEvening.
  ///
  /// In en, this message translates to:
  /// **'Good Evening'**
  String get goodEvening;

  /// No description provided for @guest.
  ///
  /// In en, this message translates to:
  /// **'Guest'**
  String get guest;

  /// No description provided for @nextSession.
  ///
  /// In en, this message translates to:
  /// **'Next Session'**
  String get nextSession;

  /// No description provided for @translate.
  ///
  /// In en, this message translates to:
  /// **'Translate'**
  String get translate;

  /// Congratulations message when student completes a course
  ///
  /// In en, this message translates to:
  /// **'🎉 Congratulations! You completed {courseName}'**
  String congratsCourseComplete(String courseName);

  /// No description provided for @rateTeacherPrompt.
  ///
  /// In en, this message translates to:
  /// **'Your opinion helps other students choose the right teacher.'**
  String get rateTeacherPrompt;

  /// No description provided for @rateTeacher.
  ///
  /// In en, this message translates to:
  /// **'Rate Teacher'**
  String get rateTeacher;

  /// No description provided for @writeReview.
  ///
  /// In en, this message translates to:
  /// **'Write a review (optional)'**
  String get writeReview;

  /// No description provided for @submitRating.
  ///
  /// In en, this message translates to:
  /// **'Submit Rating'**
  String get submitRating;

  /// No description provided for @skipRating.
  ///
  /// In en, this message translates to:
  /// **'Skip'**
  String get skipRating;

  /// No description provided for @thankYouRating.
  ///
  /// In en, this message translates to:
  /// **'Thank you for your feedback!'**
  String get thankYouRating;

  /// No description provided for @feedback.
  ///
  /// In en, this message translates to:
  /// **'Feedback'**
  String get feedback;

  /// Text showing days remaining for an assignment
  ///
  /// In en, this message translates to:
  /// **'{days} days remaining'**
  String daysRemaining(int days);

  /// No description provided for @expired.
  ///
  /// In en, this message translates to:
  /// **'Expired'**
  String get expired;

  /// No description provided for @selectRating.
  ///
  /// In en, this message translates to:
  /// **'Please select a rating'**
  String get selectRating;

  /// No description provided for @ratingSubmitted.
  ///
  /// In en, this message translates to:
  /// **'Rating submitted successfully'**
  String get ratingSubmitted;

  /// No description provided for @termsAndConditionsContent.
  ///
  /// In en, this message translates to:
  /// **'Welcome to Calligro.\nBy using the application or creating an account, you acknowledge your full agreement to these Terms and Conditions. If you do not agree to any part of them, please stop using the application.\n\n1. Definitions\nApplication: Calligro digital platform.\nUser: Anyone who uses the application or creates an account.\nStudent: A user who enrolls in educational courses.\nTeacher: A user who offers educational or artistic courses or services.\nContent: All materials published within the application, including text, images, videos, courses, assignments, and artwork.\n\n2. Creating and using an account\nThe user is committed to providing correct and accurate information when creating the account.\nThe user bears full responsibility for maintaining the confidentiality of login data.\nCalligro has the right to suspend or delete any account in the event of suspected illegal use or violation of these terms.\n\n3. User Roles\nStudent\nHas the right to register for courses, attend sessions, and submit assignments.\nIt is prohibited to republish, record, or share any educational content without express permission from the teacher or the platform.\nTeacher\nThe teacher bears full responsibility for the content they provide and its quality.\nCommit to setting accurate appointments and adhering to them.\nA method for receiving earnings must be added before publishing any course.\nThe teacher\'s account is subject to review and approval by Calligro administration.\nThe teacher bears full responsibility for the validity and accuracy of all information they enter into the application, including course descriptions, dates, content, and prices.\nCalligro bears no responsibility for any incorrect or misleading information entered by the teacher.\n\n4. Courses and Educational Sessions\nCourses are offered according to the details shown on each course page.\nSession times are displayed automatically according to each user\'s time zone.\nThe teacher is committed to presenting the course as advertised in terms of content, number of sessions, and dates.\nIn case of teacher non-compliance\nIn the event that the teacher does not comply with the course conditions, including but not limited to:\nCanceling sessions without justification\nRepeated delays\nFailure to provide the agreed content\nLow performance level negatively affecting student experience\nCalligro administration has the right to take appropriate measures, which may include:\nIssuing a warning\nTemporarily suspending the course\nCanceling the course\nSuspending or terminating the teacher\'s account\nAny other action deemed appropriate by the administration to maintain the platform quality\n\n5. Payments and Earnings\nPayments from students are made via approved payment methods within the application.\nTeachers\' earnings are transferred according to the method they specify and according to the approved schedule.\nCalligro retains a commission percentage for the use of the platform and technical services.\nCalligro bears no responsibility for delays resulting from payment service providers or banks.\n\n6. Refund Policy\nThe student has the right to request a refund only before the start of the first session of the course.\nAfter the course starts, the student is not entitled to claim any refund, whether they attended the sessions or not.\nRefund requests are processed according to the payment mechanism used and within the time period specified by payment service providers.\nCalligro reserves the right to refuse any refund request in case of suspected abuse.\n\n7. Ratings\nStudents are allowed to rate the teacher after completing the course or meeting attendance or submission requirements.\nRatings must be honest, respectful, and non-abusive.\nCalligro administration has the right to delete or hide any rating it deems unfair or in violation of platform policies.\n\n8. Content and Intellectual Property\nEach user retains full rights to the content they publish.\nThe user grants Calligro a non-exclusive license to display the content within the application.\nIt is forbidden to copy or reuse any content without written permission from the owner.\n\n9. Community\nIt is forbidden to publish any offensive, immoral, or illegal content.\nIt is forbidden to promote services or platforms outside Calligro without prior permission.\nCalligro administration has the right to delete any post or comment that violates rules without prior notice.\n\n10. Translation\nContent may be automatically translated depending on the application language.\nCalligro bears no responsibility for any errors resulting from machine translation.\n\n11. Suspension or Termination of Account\nAttributes to the user the right to request deletion of their account at any time.\nCalligro has the right to suspend or terminate any account that violates these terms or misuses the platform.\n\n12. Disclaimer\nCalligro is an intermediary platform and is not responsible for any direct dispute between student and teacher.\nYour use of the application is at your own personal responsibility.\n\n13. Amendments to Terms\nCalligro reserves the right to amend these terms at any time.\nUsers will be notified of any material amendment, and continued use of the application constitutes agreement to the amendments.'**
  String get termsAndConditionsContent;

  /// No description provided for @lastLogin.
  ///
  /// In en, this message translates to:
  /// **'Last Login'**
  String get lastLogin;

  /// No description provided for @high.
  ///
  /// In en, this message translates to:
  /// **'High'**
  String get high;

  /// No description provided for @adminRole.
  ///
  /// In en, this message translates to:
  /// **'Admin'**
  String get adminRole;

  /// No description provided for @teacherRole.
  ///
  /// In en, this message translates to:
  /// **'Teacher'**
  String get teacherRole;

  /// No description provided for @studentRole.
  ///
  /// In en, this message translates to:
  /// **'Student'**
  String get studentRole;

  /// No description provided for @userManagement.
  ///
  /// In en, this message translates to:
  /// **'User Management'**
  String get userManagement;

  /// No description provided for @searchHintUsers.
  ///
  /// In en, this message translates to:
  /// **'Search name, email, or role...'**
  String get searchHintUsers;

  /// No description provided for @joinedDate.
  ///
  /// In en, this message translates to:
  /// **'Joined {date}'**
  String joinedDate(String date);

  /// No description provided for @callUser.
  ///
  /// In en, this message translates to:
  /// **'Call User'**
  String get callUser;

  /// No description provided for @whatsappMessage.
  ///
  /// In en, this message translates to:
  /// **'WhatsApp Message'**
  String get whatsappMessage;

  /// No description provided for @sendDirectNotification.
  ///
  /// In en, this message translates to:
  /// **'Send Direct Notification'**
  String get sendDirectNotification;

  /// No description provided for @makeAdmin.
  ///
  /// In en, this message translates to:
  /// **'Make Admin'**
  String get makeAdmin;

  /// No description provided for @makeTeacher.
  ///
  /// In en, this message translates to:
  /// **'Make Teacher'**
  String get makeTeacher;

  /// No description provided for @makeStudent.
  ///
  /// In en, this message translates to:
  /// **'Make Student'**
  String get makeStudent;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete User'**
  String get deleteUser;

  /// No description provided for @deleteUserConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete User?'**
  String get deleteUserConfirmTitle;

  /// No description provided for @deleteUserConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete {name}? This action only removes their Firestore record.'**
  String deleteUserConfirmMessage(String name);

  /// No description provided for @revokeAccess.
  ///
  /// In en, this message translates to:
  /// **'Revoke Access?'**
  String get revokeAccess;

  /// No description provided for @revokeAccessConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove \'{name}\' from the admin team?'**
  String revokeAccessConfirmMessage(String name);

  /// No description provided for @addCoAdmin.
  ///
  /// In en, this message translates to:
  /// **'Add Co-Admin'**
  String get addCoAdmin;

  /// No description provided for @promoteUserSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Promote a user to administrator by entering their email address.'**
  String get promoteUserSubtitle;

  /// No description provided for @currentAdmins.
  ///
  /// In en, this message translates to:
  /// **'Current Admins'**
  String get currentAdmins;

  /// No description provided for @noCoAdminsFound.
  ///
  /// In en, this message translates to:
  /// **'No co-admins found.'**
  String get noCoAdminsFound;

  /// No description provided for @userPromotedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'User promoted to Admin successfully'**
  String get userPromotedSuccessfully;

  /// No description provided for @notificationTitle.
  ///
  /// In en, this message translates to:
  /// **'Notification Title'**
  String get notificationTitle;

  /// No description provided for @notificationBody.
  ///
  /// In en, this message translates to:
  /// **'Notification Body'**
  String get notificationBody;

  /// No description provided for @notificationSent.
  ///
  /// In en, this message translates to:
  /// **'Notification sent!'**
  String get notificationSent;

  /// No description provided for @sendToUser.
  ///
  /// In en, this message translates to:
  /// **'Send to {name}'**
  String sendToUser(String name);

  /// No description provided for @administratorManagement.
  ///
  /// In en, this message translates to:
  /// **'Administrator Management'**
  String get administratorManagement;

  /// No description provided for @revoke.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revoke;

  /// No description provided for @errorPrefix.
  ///
  /// In en, this message translates to:
  /// **'Error: {error}'**
  String errorPrefix(Object error);

  /// No description provided for @communityModeration.
  ///
  /// In en, this message translates to:
  /// **'Community Moderation'**
  String get communityModeration;

  /// No description provided for @courseModeration.
  ///
  /// In en, this message translates to:
  /// **'Course Moderation'**
  String get courseModeration;

  /// No description provided for @pendingTeachers.
  ///
  /// In en, this message translates to:
  /// **'Pending Teachers'**
  String get pendingTeachers;

  /// No description provided for @noPostsFound.
  ///
  /// In en, this message translates to:
  /// **'No community posts yet.'**
  String get noPostsFound;

  /// No description provided for @noCoursesFound.
  ///
  /// In en, this message translates to:
  /// **'No courses found.'**
  String get noCoursesFound;

  /// No description provided for @noPendingTeachersFound.
  ///
  /// In en, this message translates to:
  /// **'No pending teacher requests.'**
  String get noPendingTeachersFound;

  /// No description provided for @deletePostConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Post?'**
  String get deletePostConfirmTitle;

  /// No description provided for @deletePostConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to remove this post from the community?'**
  String get deletePostConfirmMessage;

  /// No description provided for @deleteCourse.
  ///
  /// In en, this message translates to:
  /// **'Delete Course'**
  String get deleteCourse;

  /// No description provided for @deleteCourseConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete Course?'**
  String get deleteCourseConfirmTitle;

  /// No description provided for @deleteCourseConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this course? This action cannot be undone.'**
  String get deleteCourseConfirmMessage;

  /// No description provided for @sessionRescheduled.
  ///
  /// In en, this message translates to:
  /// **'SESSION RESCHEDULED'**
  String get sessionRescheduled;

  /// No description provided for @todaysSchedule.
  ///
  /// In en, this message translates to:
  /// **'TODAY\'S SCHEDULE'**
  String get todaysSchedule;

  /// No description provided for @teacherMovedSession.
  ///
  /// In en, this message translates to:
  /// **'The teacher has moved today\'s session.'**
  String get teacherMovedSession;

  /// No description provided for @newTime.
  ///
  /// In en, this message translates to:
  /// **'New Time:'**
  String get newTime;

  /// No description provided for @sessionOnTime.
  ///
  /// In en, this message translates to:
  /// **'Session is on time as planned.'**
  String get sessionOnTime;

  /// No description provided for @rescheduleToday.
  ///
  /// In en, this message translates to:
  /// **'Reschedule Today'**
  String get rescheduleToday;

  /// No description provided for @updateReschedule.
  ///
  /// In en, this message translates to:
  /// **'Update Reschedule'**
  String get updateReschedule;

  /// No description provided for @cancelReschedule.
  ///
  /// In en, this message translates to:
  /// **'Cancel Reschedule'**
  String get cancelReschedule;

  /// No description provided for @sessionRescheduledSuccess.
  ///
  /// In en, this message translates to:
  /// **'Session rescheduled. Students will see the update.'**
  String get sessionRescheduledSuccess;

  /// No description provided for @sessionBackToNormal.
  ///
  /// In en, this message translates to:
  /// **'Session is back to original schedule.'**
  String get sessionBackToNormal;

  /// No description provided for @cannotRescheduleNotMeetingDay.
  ///
  /// In en, this message translates to:
  /// **'You can only reschedule on active meeting days.'**
  String get cannotRescheduleNotMeetingDay;

  /// No description provided for @classUpdates.
  ///
  /// In en, this message translates to:
  /// **'Class Updates'**
  String get classUpdates;

  /// No description provided for @classUpdatesDesc.
  ///
  /// In en, this message translates to:
  /// **'Welcome to the Class Updates board! This is where the teacher posts important announcements, session updates, and extra materials. Students will receive push notifications for every new update posted here.'**
  String get classUpdatesDesc;

  /// No description provided for @approveTeacher.
  ///
  /// In en, this message translates to:
  /// **'Approve Teacher'**
  String get approveTeacher;

  /// No description provided for @rejectTeacher.
  ///
  /// In en, this message translates to:
  /// **'Reject Teacher'**
  String get rejectTeacher;

  /// No description provided for @approveTeacherConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve Teacher?'**
  String get approveTeacherConfirmTitle;

  /// No description provided for @approveTeacherConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will grant \'{name}\' teacher access to the platform.'**
  String approveTeacherConfirmMessage(String name);

  /// No description provided for @rejectTeacherConfirmTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject Teacher?'**
  String get rejectTeacherConfirmTitle;

  /// No description provided for @rejectTeacherConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'This will remove \'{name}\'\'s application completely.'**
  String rejectTeacherConfirmMessage(String name);

  /// No description provided for @approve.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approve;

  /// No description provided for @approved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get approved;

  /// No description provided for @rejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get rejected;

  /// No description provided for @teacherApprovedMessage.
  ///
  /// In en, this message translates to:
  /// **'Teacher approved!'**
  String get teacherApprovedMessage;

  /// No description provided for @teacherRejectedMessage.
  ///
  /// In en, this message translates to:
  /// **'Application removed.'**
  String get teacherRejectedMessage;

  /// No description provided for @portfolioLinks.
  ///
  /// In en, this message translates to:
  /// **'PERSONAL PAGE / LINKS'**
  String get portfolioLinks;

  /// No description provided for @searchHintCourses.
  ///
  /// In en, this message translates to:
  /// **'Search by course title or teacher...'**
  String get searchHintCourses;

  /// No description provided for @untitledCourse.
  ///
  /// In en, this message translates to:
  /// **'Untitled'**
  String get untitledCourse;

  /// No description provided for @instructorWithName.
  ///
  /// In en, this message translates to:
  /// **'Instructor: {name}'**
  String instructorWithName(String name);

  /// No description provided for @unknown.
  ///
  /// In en, this message translates to:
  /// **'Unknown'**
  String get unknown;

  /// No description provided for @allPlatformActivity.
  ///
  /// In en, this message translates to:
  /// **'All Platform Activity'**
  String get allPlatformActivity;

  /// No description provided for @noActivityHistoryFound.
  ///
  /// In en, this message translates to:
  /// **'No activity history found'**
  String get noActivityHistoryFound;

  /// No description provided for @morningTimeSelected.
  ///
  /// In en, this message translates to:
  /// **'Morning Time Selected'**
  String get morningTimeSelected;

  /// No description provided for @morningSelectionWarning.
  ///
  /// In en, this message translates to:
  /// **'You selected {time}. Most courses are scheduled in the afternoon or evening.'**
  String morningSelectionWarning(String time);

  /// No description provided for @didYouMeanPm.
  ///
  /// In en, this message translates to:
  /// **'Did you mean PM?'**
  String get didYouMeanPm;

  /// No description provided for @switchToPm.
  ///
  /// In en, this message translates to:
  /// **'Switch to PM'**
  String get switchToPm;

  /// No description provided for @keepAm.
  ///
  /// In en, this message translates to:
  /// **'Keep AM'**
  String get keepAm;

  /// No description provided for @adminAccountHeader.
  ///
  /// In en, this message translates to:
  /// **'ADMIN ACCOUNT'**
  String get adminAccountHeader;

  /// No description provided for @preferencesHeader.
  ///
  /// In en, this message translates to:
  /// **'PREFERENCES'**
  String get preferencesHeader;

  /// No description provided for @supportHeader.
  ///
  /// In en, this message translates to:
  /// **'SUPPORT'**
  String get supportHeader;

  /// No description provided for @editProfileAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Update admin display info'**
  String get editProfileAdminSubtitle;

  /// No description provided for @securityAdminSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Password and authentication'**
  String get securityAdminSubtitle;

  /// No description provided for @endDaySuggested.
  ///
  /// In en, this message translates to:
  /// **'Your course ends on {day}. Would you like to include it as a class day?'**
  String endDaySuggested(String day);

  /// No description provided for @shortCourseWarning.
  ///
  /// In en, this message translates to:
  /// **'Short Course detected. Make sure your selected class days (e.g. Wednesday) actually fall within your dates.'**
  String get shortCourseWarning;

  /// No description provided for @adminSettings.
  ///
  /// In en, this message translates to:
  /// **'Admin Settings'**
  String get adminSettings;

  /// No description provided for @financialPromiseTitle.
  ///
  /// In en, this message translates to:
  /// **'Our Financial Promise'**
  String get financialPromiseTitle;

  /// No description provided for @financialPromiseDesc.
  ///
  /// In en, this message translates to:
  /// **'We understand that as a teacher, your art is your life. Calligro is built to protect your earnings. We hold funds securely during your course to ensure both you and the student are protected. Our fees are kept to the absolute minimum required by world banks, because we believe the master deserves the full reward for their mastership.'**
  String get financialPromiseDesc;

  /// No description provided for @totalEarnings.
  ///
  /// In en, this message translates to:
  /// **'Total Earnings'**
  String get totalEarnings;

  /// No description provided for @pendingBalance.
  ///
  /// In en, this message translates to:
  /// **'Pending Balance'**
  String get pendingBalance;

  /// No description provided for @availableToWithdraw.
  ///
  /// In en, this message translates to:
  /// **'Available to Withdraw'**
  String get availableToWithdraw;

  /// No description provided for @withdrawFunds.
  ///
  /// In en, this message translates to:
  /// **'Withdraw Funds'**
  String get withdrawFunds;

  /// No description provided for @cliqJordanOnly.
  ///
  /// In en, this message translates to:
  /// **'CliQ (Jordan Only)'**
  String get cliqJordanOnly;

  /// No description provided for @instantFreeOfCharge.
  ///
  /// In en, this message translates to:
  /// **'Instant & Free of charge'**
  String get instantFreeOfCharge;

  /// No description provided for @feeLabel.
  ///
  /// In en, this message translates to:
  /// **'Fee: \${amount}'**
  String feeLabel(String amount);

  /// No description provided for @trustedWorldwide.
  ///
  /// In en, this message translates to:
  /// **'Trusted Worldwide'**
  String get trustedWorldwide;

  /// No description provided for @howItWorks.
  ///
  /// In en, this message translates to:
  /// **'How it works?'**
  String get howItWorks;

  /// No description provided for @helpPending.
  ///
  /// In en, this message translates to:
  /// **'Money stays \'Pending\' while you are teaching the course.'**
  String get helpPending;

  /// No description provided for @helpSafety.
  ///
  /// In en, this message translates to:
  /// **'After the course ends, we wait 48 hours to ensure students are happy.'**
  String get helpSafety;

  /// No description provided for @helpAvailable.
  ///
  /// In en, this message translates to:
  /// **'Once cleared, money moves to \'Available\' for you to withdraw anytime.'**
  String get helpAvailable;

  /// No description provided for @helpFees.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal fees are charged by banks/Western Union, not Calligro.'**
  String get helpFees;

  /// No description provided for @withdrawVia.
  ///
  /// In en, this message translates to:
  /// **'Withdraw via {method}'**
  String withdrawVia(String method);

  /// No description provided for @amountLabel.
  ///
  /// In en, this message translates to:
  /// **'Amount: \${amount}'**
  String amountLabel(String amount);

  /// No description provided for @receiveLabel.
  ///
  /// In en, this message translates to:
  /// **'You will receive: \${amount}'**
  String receiveLabel(String amount);

  /// No description provided for @requestManualNote.
  ///
  /// In en, this message translates to:
  /// **'Requests are processed manually. You will be notified once the transfer is sent.'**
  String get requestManualNote;

  /// No description provided for @requestNow.
  ///
  /// In en, this message translates to:
  /// **'Request Now'**
  String get requestNow;

  /// No description provided for @requestSent.
  ///
  /// In en, this message translates to:
  /// **'Request Sent!'**
  String get requestSent;

  /// No description provided for @requestSentDesc.
  ///
  /// In en, this message translates to:
  /// **'Wait for admin to process and show note inside head of teacher as you requested.'**
  String get requestSentDesc;

  /// No description provided for @payoutMethodNotSelected.
  ///
  /// In en, this message translates to:
  /// **'Payout Method Not Selected'**
  String get payoutMethodNotSelected;

  /// No description provided for @payoutMethodNotSelectedDesc.
  ///
  /// In en, this message translates to:
  /// **'Please set up your payout method in Settings to withdraw your earnings.'**
  String get payoutMethodNotSelectedDesc;

  /// No description provided for @noFundsAvailable.
  ///
  /// In en, this message translates to:
  /// **'No Funds Available'**
  String get noFundsAvailable;

  /// No description provided for @payoutRequests.
  ///
  /// In en, this message translates to:
  /// **'Payout Requests'**
  String get payoutRequests;

  /// No description provided for @pendingPayouts.
  ///
  /// In en, this message translates to:
  /// **'Pending Payouts'**
  String get pendingPayouts;

  /// No description provided for @processRequest.
  ///
  /// In en, this message translates to:
  /// **'Process Request'**
  String get processRequest;

  /// No description provided for @adminNoteHint.
  ///
  /// In en, this message translates to:
  /// **'Add a note for this payout (optional)...'**
  String get adminNoteHint;

  /// No description provided for @markAsCompleted.
  ///
  /// In en, this message translates to:
  /// **'Mark as Completed'**
  String get markAsCompleted;

  /// No description provided for @markAsRejected.
  ///
  /// In en, this message translates to:
  /// **'Mark as Rejected'**
  String get markAsRejected;

  /// No description provided for @transactionHistory.
  ///
  /// In en, this message translates to:
  /// **'Transaction History'**
  String get transactionHistory;

  /// No description provided for @noTransactionsYet.
  ///
  /// In en, this message translates to:
  /// **'No transactions yet.'**
  String get noTransactionsYet;

  /// No description provided for @feeDeducted.
  ///
  /// In en, this message translates to:
  /// **'Fee Deducted'**
  String get feeDeducted;

  /// No description provided for @netAmountSent.
  ///
  /// In en, this message translates to:
  /// **'Net Amount Sent'**
  String get netAmountSent;

  /// No description provided for @withdrawal.
  ///
  /// In en, this message translates to:
  /// **'Withdrawal'**
  String get withdrawal;

  /// No description provided for @allTime.
  ///
  /// In en, this message translates to:
  /// **'All Time'**
  String get allTime;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusProcessing.
  ///
  /// In en, this message translates to:
  /// **'Processing'**
  String get statusProcessing;

  /// No description provided for @statusSuccessful.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get statusSuccessful;

  /// No description provided for @statusFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get statusFailed;

  /// No description provided for @payoutCompleted.
  ///
  /// In en, this message translates to:
  /// **'Payout Completed'**
  String get payoutCompleted;

  /// No description provided for @payoutRejected.
  ///
  /// In en, this message translates to:
  /// **'Payout Rejected'**
  String get payoutRejected;

  /// No description provided for @noPayoutRequests.
  ///
  /// In en, this message translates to:
  /// **'No payout requests yet'**
  String get noPayoutRequests;

  /// No description provided for @allPayoutRequests.
  ///
  /// In en, this message translates to:
  /// **'All Payout Requests'**
  String get allPayoutRequests;

  /// No description provided for @viewOnCalligro.
  ///
  /// In en, this message translates to:
  /// **'View on Calligro'**
  String get viewOnCalligro;

  /// No description provided for @aboutTheInstructor.
  ///
  /// In en, this message translates to:
  /// **'About the Instructor'**
  String get aboutTheInstructor;

  /// No description provided for @verifiedMaster.
  ///
  /// In en, this message translates to:
  /// **'Verified Master'**
  String get verifiedMaster;

  /// No description provided for @rating.
  ///
  /// In en, this message translates to:
  /// **'Rating'**
  String get rating;

  /// No description provided for @submitYourWork.
  ///
  /// In en, this message translates to:
  /// **'Submit your work'**
  String get submitYourWork;

  /// No description provided for @activeTeachers.
  ///
  /// In en, this message translates to:
  /// **'Active Teachers'**
  String get activeTeachers;

  /// No description provided for @approvedTeachers.
  ///
  /// In en, this message translates to:
  /// **'Approved Teachers'**
  String get approvedTeachers;

  /// No description provided for @teacherApproval.
  ///
  /// In en, this message translates to:
  /// **'Teacher Approval'**
  String get teacherApproval;

  /// No description provided for @viewProfile.
  ///
  /// In en, this message translates to:
  /// **'View Profile'**
  String get viewProfile;

  /// No description provided for @changeRole.
  ///
  /// In en, this message translates to:
  /// **'Change Role'**
  String get changeRole;

  /// No description provided for @roleChanged.
  ///
  /// In en, this message translates to:
  /// **'Role changed successfully'**
  String get roleChanged;

  /// No description provided for @filterByRole.
  ///
  /// In en, this message translates to:
  /// **'Filter by Role'**
  String get filterByRole;

  /// No description provided for @allUsers.
  ///
  /// In en, this message translates to:
  /// **'All Users'**
  String get allUsers;

  /// No description provided for @admins.
  ///
  /// In en, this message translates to:
  /// **'Admins'**
  String get admins;

  /// No description provided for @userDetails.
  ///
  /// In en, this message translates to:
  /// **'User Details'**
  String get userDetails;

  /// No description provided for @totalTeachers.
  ///
  /// In en, this message translates to:
  /// **'Total Teachers'**
  String get totalTeachers;

  /// No description provided for @approvedOn.
  ///
  /// In en, this message translates to:
  /// **'Approved on {date}'**
  String approvedOn(Object date);

  /// No description provided for @pendingApproval.
  ///
  /// In en, this message translates to:
  /// **'Pending Approval'**
  String get pendingApproval;

  /// No description provided for @teacherStats.
  ///
  /// In en, this message translates to:
  /// **'Teacher Stats'**
  String get teacherStats;

  /// No description provided for @totalCourses.
  ///
  /// In en, this message translates to:
  /// **'Total Courses'**
  String get totalCourses;

  /// No description provided for @totalStudents.
  ///
  /// In en, this message translates to:
  /// **'Total Students'**
  String get totalStudents;

  /// No description provided for @averageRating.
  ///
  /// In en, this message translates to:
  /// **'Average Rating'**
  String get averageRating;

  /// No description provided for @suspendTeacher.
  ///
  /// In en, this message translates to:
  /// **'Suspend Teacher'**
  String get suspendTeacher;

  /// No description provided for @activateTeacher.
  ///
  /// In en, this message translates to:
  /// **'Activate Teacher'**
  String get activateTeacher;

  /// No description provided for @teacherSuspended.
  ///
  /// In en, this message translates to:
  /// **'Teacher suspended'**
  String get teacherSuspended;

  /// No description provided for @teacherActivated.
  ///
  /// In en, this message translates to:
  /// **'Teacher activated'**
  String get teacherActivated;

  /// No description provided for @noActiveTeachers.
  ///
  /// In en, this message translates to:
  /// **'No active teachers yet'**
  String get noActiveTeachers;

  /// No description provided for @noPendingTeachers.
  ///
  /// In en, this message translates to:
  /// **'No pending teacher applications'**
  String get noPendingTeachers;

  /// No description provided for @approveAll.
  ///
  /// In en, this message translates to:
  /// **'Approve All'**
  String get approveAll;

  /// No description provided for @rejectAll.
  ///
  /// In en, this message translates to:
  /// **'Reject All'**
  String get rejectAll;

  /// No description provided for @recentActivity.
  ///
  /// In en, this message translates to:
  /// **'Recent Activity'**
  String get recentActivity;

  /// No description provided for @showAll.
  ///
  /// In en, this message translates to:
  /// **'Show All'**
  String get showAll;

  /// No description provided for @manageCommunity.
  ///
  /// In en, this message translates to:
  /// **'View and manage user discussions'**
  String get manageCommunity;

  /// No description provided for @courseManagementDesc.
  ///
  /// In en, this message translates to:
  /// **'Approve or disable courses'**
  String get courseManagementDesc;

  /// No description provided for @manageTeachers.
  ///
  /// In en, this message translates to:
  /// **'Manage active teachers'**
  String get manageTeachers;

  /// No description provided for @teachersCommissions.
  ///
  /// In en, this message translates to:
  /// **'Teachers\' Commissions'**
  String get teachersCommissions;

  /// No description provided for @logout.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logout;

  /// No description provided for @completedCaps.
  ///
  /// In en, this message translates to:
  /// **'COMPLETED'**
  String get completedCaps;

  /// No description provided for @completedCourses.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completedCourses;

  /// No description provided for @endedCaps.
  ///
  /// In en, this message translates to:
  /// **'ENDED'**
  String get endedCaps;

  /// No description provided for @payoutSettingsDesc.
  ///
  /// In en, this message translates to:
  /// **'Manage your payment and bank information'**
  String get payoutSettingsDesc;

  /// No description provided for @setupPayout.
  ///
  /// In en, this message translates to:
  /// **'Setup Payout'**
  String get setupPayout;

  /// No description provided for @payoutInfoMissing.
  ///
  /// In en, this message translates to:
  /// **'Payout information is missing. Please set it up to receive your earnings.'**
  String get payoutInfoMissing;

  /// No description provided for @newUserJoined.
  ///
  /// In en, this message translates to:
  /// **'New User Joined'**
  String get newUserJoined;

  /// No description provided for @newCourseCreated.
  ///
  /// In en, this message translates to:
  /// **'New Course Created'**
  String get newCourseCreated;

  /// No description provided for @newCommunityPost.
  ///
  /// In en, this message translates to:
  /// **'New Community Post'**
  String get newCommunityPost;

  /// No description provided for @enrolledStudentsLabel.
  ///
  /// In en, this message translates to:
  /// **'Enrolled Students'**
  String get enrolledStudentsLabel;

  /// No description provided for @studentsWithCount.
  ///
  /// In en, this message translates to:
  /// **'{count} Students'**
  String studentsWithCount(int count);

  /// No description provided for @level.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get level;

  /// No description provided for @viewCourseDetails.
  ///
  /// In en, this message translates to:
  /// **'View Course Details'**
  String get viewCourseDetails;

  /// No description provided for @noCourseDescription.
  ///
  /// In en, this message translates to:
  /// **'No description available'**
  String get noCourseDescription;

  /// No description provided for @accessAndStudents.
  ///
  /// In en, this message translates to:
  /// **'Access & Students'**
  String get accessAndStudents;

  /// No description provided for @syncAccessToMeet.
  ///
  /// In en, this message translates to:
  /// **'Sync Access to Meet'**
  String get syncAccessToMeet;

  /// No description provided for @preApproved.
  ///
  /// In en, this message translates to:
  /// **'Pre-approved'**
  String get preApproved;

  /// No description provided for @needsSync.
  ///
  /// In en, this message translates to:
  /// **'Needs Sync'**
  String get needsSync;

  /// No description provided for @setCommission.
  ///
  /// In en, this message translates to:
  /// **'Set Commission'**
  String get setCommission;

  /// No description provided for @setCommissionRate.
  ///
  /// In en, this message translates to:
  /// **'Set Commission Rate'**
  String get setCommissionRate;

  /// No description provided for @commissionRateDesc.
  ///
  /// In en, this message translates to:
  /// **'Enter the commission percentage this teacher will earn (e.g., 75 for 75%).'**
  String get commissionRateDesc;

  /// No description provided for @commissionRateUpdated.
  ///
  /// In en, this message translates to:
  /// **'Commission rate updated to {rate}%'**
  String commissionRateUpdated(String rate);

  /// No description provided for @commissionLabel.
  ///
  /// In en, this message translates to:
  /// **'Commission'**
  String get commissionLabel;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'tr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'tr':
      return AppLocalizationsTr();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
