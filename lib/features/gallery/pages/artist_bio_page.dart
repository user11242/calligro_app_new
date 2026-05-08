import 'package:flutter/material.dart';
import 'package:calligro_app/core/theme/colors.dart';
import 'package:calligro_app/l10n/app_localizations.dart';
import '../models/gallery_artist.dart';
import 'artist_gallery_page.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'dart:ui';

class ArtistBioPage extends StatefulWidget {
  final GalleryArtist artist;
  const ArtistBioPage({super.key, required this.artist});

  @override
  State<ArtistBioPage> createState() => _ArtistBioPageState();
}

class _ArtistBioPageState extends State<ArtistBioPage> {
  bool _isExpanded = false;

  @override
  void initState() {
    super.initState();
    // --- FINAL FAIL-SAFE REDIRECT ---
    // If we somehow land here for a bypass category, jump immediately to the gallery
    final String name = widget.artist.name;
    final bool isOttoman = name.contains("خرائط") || name.contains("وثائق") || name.contains("عثمانيه") || name.contains("Ottoman");
    final bool isRiqaa = name.contains("الرقاع") || name.contains("رقاع") || name.contains("Riqaa");
    final bool isDiwani = name.contains("ديواني");
    final bool isMisc = name.contains("منوعات") || name.contains("Varieties");

    if (isOttoman || isRiqaa || isDiwani || isMisc) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => ArtistGalleryPage(artist: widget.artist),
          ),
        );
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    
    // --- SMART FALLBACKS FOR HISTORICAL MASTERS ---
    String displayName = widget.artist.localizedName(context);
    String displayBio = widget.artist.bio;
    String? displayBirth = widget.artist.birthDate;
    String? displayDeath = widget.artist.deathDate;
    String? displayLife = widget.artist.lifeDetails;
    String? localAssetPath;

    // 1. Ahmad Al-Kamel Check
    if (widget.artist.name.contains("احمد") && widget.artist.name.contains("الكامل") || 
        widget.artist.name.contains("أحمد") && widget.artist.name.contains("الكامل")) {
      
      final Map<String, String> nameTr = {
        'ar': "أحمد كامل أكديك",
        'en': "Ahmed Kamil Akdik",
        'tr': "Ahmet Kamil Akdik"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.ahmadKamelBio;
      }
      displayBirth ??= l10n.ahmadKamelBornYear;
      displayDeath ??= l10n.ahmadKamelDiedYear;
      displayLife ??= l10n.ahmadKamelLifeDescription;
      localAssetPath = "assets/images/artists/ahmad_kamel.png";
    } 
    // 2. Hasan Rida Efendi Check
    else if (widget.artist.name.contains("حسن") && widget.artist.name.contains("رضا") || 
             widget.artist.name.contains("Hasan") && widget.artist.name.contains("Riza") ||
             widget.artist.name.contains("Rizâ")) {
      
      final Map<String, String> nameTr = {
        'ar': "حسن رضا أفندي",
        'en': "Hasan Rida Efendi",
        'tr': "Hasan Rıza Efendi"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.hasanRidaBio;
      }
      displayBirth ??= l10n.hasanRidaBornYear;
      displayDeath ??= l10n.hasanRidaDiedYear;
      displayLife ??= l10n.hasanRidaLifeDescription;
      localAssetPath = "assets/images/artists/hasan_rida.jpg";
    }
    // 3. Bakkal Arif Efendi Check
    else if (widget.artist.name.contains("عارف") ||
             widget.artist.name.contains("بقّال") ||
             widget.artist.name.contains("Bakkal") ||
             widget.artist.name.contains("Ârif")) {
      final Map<String, String> nameTr = {
        'ar': "أحمد عارف أفندي (بقّال عارف)",
        'en': "Arif Efendi (Bakkal Arif)",
        'tr': "Bakkal Arif Efendi"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.bakkalarif_bio;
      }
      displayBirth ??= l10n.bakkalarif_born_year;
      displayDeath ??= l10n.bakkalarif_died_year;
      displayLife ??= l10n.bakkalarif_life_description;
    }
    // 4. Ismail Zuhdi Efendi Check
    else if ((widget.artist.name.contains("زُهدي") || widget.artist.name.contains("زهدي") ||
              widget.artist.name.contains("Zühdî") || widget.artist.name.contains("Zuhdi")) &&
             widget.artist.name.contains("إسماعيل") || widget.artist.name.contains("اسماعيل")) {
      final Map<String, String> nameTr = {
        'ar': "إسماعيل زُهدي أفندي",
        'en': "Ismail Zuhdi Efendi",
        'tr': "İsmâil Zühdi Efendi"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.ismailzuhdi_bio;
      }
      displayBirth ??= l10n.ismailzuhdi_born_year;
      displayDeath ??= l10n.ismailzuhdi_died_year;
      displayLife ??= l10n.ismailzuhdi_life_description;
    }
    // 5. Ismail Hakki Altunbezer Check
    else if (widget.artist.name.contains("حقي") || widget.artist.name.contains("ألطونبزر") ||
             widget.artist.name.contains("Altunbezer") || widget.artist.name.contains("Hakkı")) {
      final Map<String, String> nameTr = {
        'ar': "إسماعيل حقي ألطونبزر",
        'en': "Ismail Hakki Altunbezer",
        'tr': "İsmail Hakkı Altunbezer"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.ismailhakki_bio;
      }
      displayBirth ??= l10n.ismailhakki_born_year;
      displayDeath ??= l10n.ismailhakki_died_year;
      displayLife ??= l10n.ismailhakki_life_description;
    }
    // 6. Hafiz Osman Check
    else if ((widget.artist.name.contains("الحافظ") && widget.artist.name.contains("عثمان")) ||
             (widget.artist.name.contains("Hâfız") && widget.artist.name.contains("Osman"))) {
      final Map<String, String> nameTr = {
        'ar': "الحافظ عثمان",
        'en': "Hafiz Osman",
        'tr': "Hafız Osman"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.hafizothman_bio;
      }
      displayBirth ??= l10n.hafizothman_born_year;
      displayDeath ??= l10n.hafizothman_died_year;
      displayLife ??= l10n.hafizothman_life_description;
    }
    // 7. Halim Özyazıcı Check
    else if (widget.artist.name.contains("حليم") || widget.artist.name.contains("Halim") ||
             widget.artist.name.contains("Özyazıcı")) {
      final Map<String, String> nameTr = {
        'ar': "حليم أوزيازجي",
        'en': "Halim Ozyazici",
        'tr': "Halim Özyazıcı"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.halim_bio;
      }
      displayBirth ??= l10n.halim_born_year;
      displayDeath ??= l10n.halim_died_year;
      displayLife ??= l10n.halim_life_description;
    }
    // 8. Sheikh Hamdullah al-Amasi Check
    else if (widget.artist.name.contains("حمدالله") || widget.artist.name.contains("حمد الله") ||
             widget.artist.name.contains("Hamdullah") || widget.artist.name.contains("Hamdullâh")) {
      final Map<String, String> nameTr = {
        'ar': "الشيخ حمد الله الأماسي",
        'en': "Sheikh Hamdullah al-Amasi",
        'tr': "Şeyh Hamdullah"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.hamdullah_bio;
      }
      displayBirth ??= l10n.hamdullah_born_year;
      displayDeath ??= l10n.hamdullah_died_year;
      displayLife ??= l10n.hamdullah_life_description;
    }
    // 9. Sami Efendi Check
    else if (widget.artist.name.contains("سامي") || widget.artist.name.contains("Sâmi") ||
             widget.artist.name.contains("Sami")) {
      final Map<String, String> nameTr = {
        'ar': "سامي أفندي",
        'en': "Sami Efendi",
        'tr': "Sami Efendi"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.samiefendi_bio;
      }
      displayBirth ??= l10n.samiefendi_born_year;
      displayDeath ??= l10n.samiefendi_died_year;
      displayLife ??= l10n.samiefendi_life_description;
    }
    // 10. Shafiq Bey Check
    else if (widget.artist.name.contains("شفيق") || widget.artist.name.contains("Şefik") ||
             widget.artist.name.contains("Shafiq")) {
      final Map<String, String> nameTr = {
        'ar': "شفيق بك",
        'en': "Shafiq Bey",
        'tr': "Şefik Bey"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.shafiqbey_bio;
      }
      displayBirth ??= l10n.shafiqbey_born_year;
      displayDeath ??= l10n.shafiqbey_died_year;
      displayLife ??= l10n.shafiqbey_life_description;
    }
    // 11. Mehmed Şevkî Efendi Check
    else if (widget.artist.name.contains("شوقي") || widget.artist.name.contains("شوقي") ||
             widget.artist.name.contains("Şevkî") || widget.artist.name.contains("Shawqi")) {
      final Map<String, String> nameTr = {
        'ar': "محمد شوقي أفندي",
        'en': "Mehmed Sevki Efendi",
        'tr': "Mehmed Şevki Efendi"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.shawqiefendi_bio;
      }
      displayBirth ??= l10n.shawqiefendi_born_year;
      displayDeath ??= l10n.shawqiefendi_died_year;
      displayLife ??= l10n.shawqiefendi_life_description;
    }
    // 12. Mehmed Nâzîf Bey Check  
    else if (widget.artist.name.contains("نظيف") || widget.artist.name.contains("ناظف") ||
             widget.artist.name.contains("Nâzîf") || widget.artist.name.contains("Nazif")) {
      final Map<String, String> nameTr = {
        'ar': "محمد ناظف بك",
        'en': "Mehmed Nazif Bey",
        'tr': "Mehmed Nazif Bey"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.nazifbey_bio;
      }
      displayBirth ??= l10n.nazifbey_born_year;
      displayDeath ??= l10n.nazifbey_died_year;
      displayLife ??= l10n.nazifbey_life_description;
    }
    // 13. Yaqut al-Mustaasimi Check
    else if (widget.artist.name.contains("ياقوت") || widget.artist.name.contains("المستعصمي") ||
             widget.artist.name.contains("Yâkût") || widget.artist.name.contains("Yaqut")) {
      final Map<String, String> nameTr = {
        'ar': "ياقوت المستعصمي",
        'en': "Yaqut al-Musta'simi",
        'tr': "Yâkût el-Müsta'sımî"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.yaqut_bio;
      }
      displayBirth ??= l10n.yaqut_born_year;
      displayDeath ??= l10n.yaqut_died_year;
      displayLife ??= l10n.yaqut_life_description;
    }
    // 14. Mustafa Izzat Check
    else if (widget.artist.name.contains("مصطفى") && widget.artist.name.contains("عزت") || 
             widget.artist.name.contains("مصطفى") && widget.artist.name.contains("عزّت") ||
             widget.artist.name.contains("Mustafa") && widget.artist.name.contains("Izzat") ||
             widget.artist.name.contains("İzzet")) {
      final Map<String, String> nameTr = {
        'ar': "مصطفى عزّت (قاضي عسكر)",
        'en': "Mustafa Izzat (Kadiasker)",
        'tr': "Kazasker Mustafa İzzet"
      };
      displayName = nameTr[Localizations.localeOf(context).languageCode] ?? nameTr['ar']!;
      if (displayBio.isEmpty || displayBio == "Classical Calligraphy") {
        displayBio = l10n.mustafazzat_bio;
      }
      displayBirth ??= l10n.mustafazzat_born_year;
      displayDeath ??= l10n.mustafazzat_died_year;
      displayLife ??= l10n.mustafazzat_life_description;
      localAssetPath = "assets/images/artists/mustafazzat.webp";
    }

    // --- NUMBER LOCALIZATION FOR ARABIC ---
    if (l10n.localeName == 'ar') {
      displayBio = _localizeNumbers(displayBio);
      displayBirth = displayBirth != null ? _localizeNumbers(displayBirth) : null;
      displayDeath = displayDeath != null ? _localizeNumbers(displayDeath) : null;
      displayLife = displayLife != null ? _localizeNumbers(displayLife) : null;
    }

    final bool hasRemoteImage = widget.artist.photoUrl != null && widget.artist.photoUrl!.isNotEmpty;
    final bool useLocalAsset = !hasRemoteImage && localAssetPath != null;

    return Scaffold(
      backgroundColor: AppColors.primary,
      body: CustomScrollView(
        slivers: [
          // 1. Hero Image Header
          SliverAppBar(
            expandedHeight: 240.0,
            pinned: true,
            backgroundColor: AppColors.primary,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Stack(
                fit: StackFit.expand,
                children: [
                   if (hasRemoteImage || useLocalAsset)
                      Stack(
                        fit: StackFit.expand,
                        children: [
                          // 1. Blurred Background (Fills everything)
                          if (hasRemoteImage)
                            CachedNetworkImage(
                              imageUrl: widget.artist.photoUrl!,
                              fit: BoxFit.cover,
                            )
                          else
                            Image.asset(
                              localAssetPath!,
                              fit: BoxFit.cover,
                            ),
                          BackdropFilter(
                            filter: ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                            child: Container(color: Colors.black.withOpacity(0.2)),
                          ),
                          // 2. Focused Image (Zoomed out / Full view)
                          if (hasRemoteImage)
                            CachedNetworkImage(
                              imageUrl: widget.artist.photoUrl!,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                            )
                          else
                            Image.asset(
                              localAssetPath!,
                              fit: BoxFit.contain,
                              alignment: Alignment.topCenter,
                            ),
                        ],
                      )
                    else
                      Container(
                        color: AppColors.cardBackground,
                        child: Center(
                          child: Icon(Icons.person, color: Colors.white.withOpacity(0.1), size: 100),
                        ),
                      ),
                  // Dark Gradient Overlay
                  DecoratedBox(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [
                          Colors.transparent,
                          AppColors.primary.withOpacity(0.8),
                          AppColors.primary,
                        ],
                        stops: const [0.6, 0.9, 1.0],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 2. Content Section
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const SizedBox(height: 10),
                  Text(
                    displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                      letterSpacing: -0.5,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Container(
                    width: 60,
                    height: 3,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  // Expandable Biography Text
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        displayBio,
                        maxLines: _isExpanded ? null : 4,
                        overflow: _isExpanded ? TextOverflow.visible : TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white.withOpacity(0.8),
                          fontSize: 16,
                          height: 1.8,
                          leadingDistribution: TextLeadingDistribution.even,
                        ),
                      ),
                      const SizedBox(height: 8),
                      GestureDetector(
                        onTap: () => setState(() => _isExpanded = !_isExpanded),
                        child: Text(
                          _isExpanded ? l10n.showLess : l10n.showMore,
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontWeight: FontWeight.bold,
                            fontSize: 14,
                          ),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 32),
                  
                  // Stats Table
                  _buildStatsTable(context, l10n, displayBirth, displayDeath, displayLife),
                  
                  const SizedBox(height: 40),
                  
                  // Action Button
                  SizedBox(
                    width: double.infinity,
                    height: 60,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ArtistGalleryPage(artist: widget.artist),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.accentGold,
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: Text(
                        l10n.viewWorks,
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                  // const SizedBox(height: 60),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStatsTable(BuildContext context, AppLocalizations l10n, String? birth, String? death, String? life) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.cardBackground.withOpacity(0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          _buildTableRow(l10n.born, birth ?? "-"),
          _buildDivider(),
          _buildTableRow(l10n.died, death ?? "-"),
          _buildDivider(),
          _buildTableRow(l10n.lifeDuration, life ?? "-"),
        ],
      ),
    );
  }

  Widget _buildTableRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            label,
            style: TextStyle(
              color: Colors.white.withOpacity(0.5),
              fontSize: 14,
            ),
          ),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDivider() {
    return Divider(
      height: 1,
      color: Colors.white.withOpacity(0.05),
      indent: 20,
      endIndent: 20,
    );
  }

  String _localizeNumbers(String input) {
    const english = ['0', '1', '2', '3', '4', '5', '6', '7', '8', '9'];
    const arabic = ['٠', '١', '٢', '٣', '٤', '٥', '٦', '٧', '٨', '٩'];

    for (int i = 0; i < english.length; i++) {
      input = input.replaceAll(english[i], arabic[i]);
    }
    return input;
  }
}
