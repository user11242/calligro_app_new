part of 'course_details_page.dart';

/// Split out of course_details_page.dart (unchanged code): sections that only
/// read the page's state.
extension _OverviewSections on _CourseDetailsPageState {
  Widget _buildOverviewTab() {
    final l10n = AppLocalizations.of(context)!;
    List<Widget> children = [
      _buildSectionTitle(l10n.description, Icons.menu_book),
      const SizedBox(height: 12),
      Text(
        _translatedDescription ?? _localizeDescription(courseDescription),
        style: const TextStyle(
          color: Colors.white70,
          fontSize: 15,
          height: 1.6,
        ),
      ),
      if (_isTranslating)
        Padding(
          padding: const EdgeInsets.only(top: 8.0),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const SizedBox(
                width: 12,
                height: 12,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accentGold,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                AppLocalizations.of(
                  context,
                )!.translating, // Silent translation in progress
                style: const TextStyle(
                  color: AppColors.accentGold,
                  fontSize: 13,
                  fontStyle: FontStyle.italic,
                ),
              ),
            ],
          ),
        ),
      const SizedBox(height: 32),
    ];

    // --- TOOLS SECTION ---
    if (requiredTools.isNotEmpty) {
      children.add(_buildSectionTitle(l10n.toolsRequirements, Icons.brush));
      children.add(const SizedBox(height: 16));
      children.add(
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: (_translatedTools ?? requiredTools).map((tool) {
            String name = '';
            String iconKey = '';
            if (tool is Map) {
              name = tool['name'] ?? '';
              iconKey = tool['icon'] ?? 'generic';
            } else {
              name = tool.toString();
              iconKey = 'generic';
            }
            return _buildToolChip(name, iconKey);
          }).toList(),
        ),
      );
      children.add(const SizedBox(height: 32));
    }

    children.addAll([
      _buildSectionTitle(
        l10n.localeName == 'ar' ? 'نتائج التعلم' : 'Learning Outcomes',
        Icons.map,
      ),
      const SizedBox(height: 16),
      _buildCurriculumTimeline(),
    ]);

    return SingleChildScrollView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 120),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }

  Widget _buildCurriculumTimeline() {
    final modules =
        _translatedCurriculum ??
        (curriculumSteps.isNotEmpty
            ? curriculumSteps
            : [
                AppLocalizations.of(context)!.introToThuluth,
                AppLocalizations.of(context)!.letterAlifBaa,
                AppLocalizations.of(context)!.jointLetters,
                AppLocalizations.of(context)!.sentences,
                AppLocalizations.of(context)!.finalProject,
              ]);
    return Column(
      children: List.generate(modules.length, (index) {
        final isLast = index == modules.length - 1;
        return IntrinsicHeight(
          child: Row(
            children: [
              Column(
                children: [
                  Container(
                    width: 16,
                    height: 16,
                    decoration: BoxDecoration(
                      color: AppColors.accentGold,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.accentGold.withOpacity(0.4),
                          blurRadius: 8,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                  ),
                  if (!isLast)
                    Expanded(
                      child: Container(
                        width: 2,
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [
                              AppColors.accentGold.withOpacity(0.5),
                              Colors.white10,
                            ],
                          ),
                        ),
                      ),
                    ),
                ],
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24),
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.03),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.05)),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          AppLocalizations.of(
                            context,
                          )!.module(index + 1).toUpperCase(),
                          style: const TextStyle(
                            color: AppColors.accentGold,
                            fontSize: 10,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          _localizeContent(modules[index]),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                            fontFamily: 'Urbanist',
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
      }),
    );
  }

  Widget _buildToolChip(String label, String iconKey) {
    final Map<String, IconData> iconRegistry = {
      'brush': Icons.brush,
      'pen': Icons.create,
      'paper': Icons.article,
      'ink': Icons.water_drop,
      'generic': Icons.check_circle_outline,
      'star': Icons.star,
      'build': Icons.build,
      'palette': Icons.palette,
      'hand': Icons.front_hand,
      'book': Icons.book,
      'school': Icons.assignment_ind,
    };

    return ClipRRect(
      borderRadius: BorderRadius.circular(16),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 5, sigmaY: 5),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.05),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withOpacity(0.1)),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: AppColors.accentGold.withOpacity(0.1),
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  iconRegistry[iconKey] ?? Icons.check_circle_outline,
                  color: AppColors.accentGold,
                  size: 16,
                ),
              ),
              const SizedBox(width: 12),
              Text(
                _localizeContent(label),
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  fontFamily: 'Urbanist',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, IconData icon) {
    return Row(
      children: [
        Icon(icon, color: AppColors.accentGold, size: 22),
        const SizedBox(width: 10),
        Expanded(
          child: Text(
            title,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildInfoColumn(
    String label,
    DateTime? date,
    DateFormat formatter,
    IconData icon,
  ) {
    return Expanded(
      child: Column(
        children: [
          Icon(icon, color: Colors.white38, size: 18),
          const SizedBox(height: 6),
          Text(
            label,
            style: const TextStyle(color: Colors.white54, fontSize: 12),
          ),
          const SizedBox(height: 2),
          Text(
            date != null
                ? formatter.format(date)
                : AppLocalizations.of(context)!.notAvailableShort,
            style: const TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.w600,
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    return Container(
      width: double.infinity,
      constraints: const BoxConstraints(
        minHeight: 150,
      ), // Changed from fixed height to minHeight and slightly increased
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A1A),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: color.withOpacity(0.3), width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withOpacity(0.1),
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          splashColor: color.withOpacity(0.1),
          highlightColor: Colors.transparent,
          borderRadius: BorderRadius.circular(24),
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 16,
              vertical: 20,
            ), // Reduced horizontal padding slightly
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize:
                  MainAxisSize.min, // Allow column to be as small as possible
              children: [
                Container(
                  padding: const EdgeInsets.all(10), // Reduced from 12
                  decoration: BoxDecoration(
                    color: color.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Icon(
                    icon,
                    color: color,
                    size: 24, // Reduced from 28
                  ),
                ),
                const SizedBox(
                  height: 20,
                ), // Explicit spacing instead of Spacer
                Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    fontSize: 18, // Reduced from 20
                    letterSpacing: -0.5,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
