const fs = require('fs');
const file = '/Users/yazanqattous/Desktop/flutter_projects/calligro_app/lib/features/teacher/tabs/teacher_home_tab.dart';
let content = fs.readFileSync(file, 'utf8');

const oldStatCard = `class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppColors.cardBackground,
              AppColors.cardBackground.withOpacity(0.9),
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
          borderRadius: BorderRadius.circular(15),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.3),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppColors.accentGold, size: 28),
            const SizedBox(height: 8),
            Text(
              value,
              style: const TextStyle(
                color: AppColors.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: const TextStyle(color: AppColors.textLight, fontSize: 12),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}`;

const newStatCard = `class StatCard extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final int delayMs;
  const StatCard({
    super.key,
    required this.icon,
    required this.value,
    required this.label,
    this.delayMs = 0,
  });
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: FutureBuilder(
        future: Future.delayed(Duration(milliseconds: delayMs)),
        builder: (context, snapshot) {
          final show = snapshot.connectionState == ConnectionState.done;
          return TweenAnimationBuilder<double>(
            tween: Tween(begin: 0.0, end: show ? 1.0 : 0.0),
            duration: const Duration(milliseconds: 500),
            curve: Curves.easeOutBack,
            builder: (context, scale, child) {
              return Transform.scale(
                scale: scale,
                child: child,
              );
            },
            child: Container(
              padding: const EdgeInsets.symmetric(vertical: 16.0, horizontal: 8.0),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppColors.cardBackground,
                    AppColors.cardBackground.withOpacity(0.9),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(15),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.3),
                    blurRadius: 10,
                    offset: const Offset(0, 5),
                  ),
                ],
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, color: AppColors.accentGold, size: 28),
                  const SizedBox(height: 8),
                  Text(
                    value,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    label,
                    style: const TextStyle(color: AppColors.textLight, fontSize: 12),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
          );
        }
      ),
    );
  }
}`;

const oldStatsWidget = `              Widget statsWidget = Row(
                children: [
                  StatCard(
                    icon: Icons.assignment_ind,
                    value: liveCourseCount.toString(),
                    label: l10n.activeCourses,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.groups,
                    value: totalActiveStudents.toString(),
                    label: l10n.activeStudents,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.account_balance_wallet,
                    value: widget.earnings,
                    label: l10n.earnings,
                  ),
                ],
              );`;

const newStatsWidget = `              Widget statsWidget = Row(
                children: [
                  StatCard(
                    icon: Icons.assignment_ind,
                    value: liveCourseCount.toString(),
                    label: l10n.activeCourses,
                    delayMs: 100,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.groups,
                    value: totalActiveStudents.toString(),
                    label: l10n.activeStudents,
                    delayMs: 250,
                  ),
                  const SizedBox(width: 12),
                  StatCard(
                    icon: Icons.account_balance_wallet,
                    value: widget.earnings,
                    label: l10n.earnings,
                    delayMs: 400,
                  ),
                ],
              );`;

if (content.includes(oldStatCard) && content.includes(oldStatsWidget)) {
  content = content.replace(oldStatCard, newStatCard);
  content = content.replace(oldStatsWidget, newStatsWidget);
  fs.writeFileSync(file, content);
  console.log("StatCard updated successfully with animations!");
} else {
  console.log("Could not find the exact strings. Checking line endings or spaces...");
  
  // Try regex replace for robustness
  const oldStatCardRegex = /class StatCard extends StatelessWidget \{[\s\S]*?\}\s*\}\s*\}/;
  content = content.replace(oldStatCardRegex, newStatCard);
  
  const oldStatsWidgetRegex = /Widget statsWidget = Row\([\s\S]*?l10n\.earnings,[\s\S]*?\),[\s\S]*?\],[\s\S]*?\);/;
  content = content.replace(oldStatsWidgetRegex, newStatsWidget);
  
  fs.writeFileSync(file, content);
  console.log("Used Regex to replace StatCard and statsWidget.");
}
