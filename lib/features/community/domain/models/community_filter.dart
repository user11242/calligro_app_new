/// Feed sorting and filtering criteria in Calligro Community.
enum CommunityFilter {
  all('All'),
  popular('Popular'),
  friends('Friends'),
  teachers('Teachers'),
  myPosts('My Posts'),
  saved('Saved');

  final String displayName;
  const CommunityFilter(this.displayName);

  static CommunityFilter fromString(String? value) {
    if (value == null) return CommunityFilter.all;
    return CommunityFilter.values.firstWhere(
      (f) => f.displayName.toLowerCase() == value.toLowerCase() || f.name.toLowerCase() == value.toLowerCase(),
      orElse: () => CommunityFilter.all,
    );
  }
}

