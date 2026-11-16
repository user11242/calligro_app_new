# Calligro app architecture

The Flutter app is organised **feature-first**. Each feature has the same
layers, and **role shells** (admin, student, teacher) only assemble those
features into each role's dashboard. Tests mirror the source tree, and
guard-rail tests enforce the rules below, so the structure cannot drift
without a test failing.

(The Next.js `web_portal/` is a separate project and is not covered here.)

## Folders

```
lib/
  main.dart            app start-up and named routes
  screens/             splash, onboarding, auth_wrapper (picks the role's dashboard)
  core/                shared building blocks, not tied to one feature:
                       theme, widgets, utils, localization, messages, services
  l10n/                translations
  features/
    <feature>/
      domain/          pure Dart: models, rules, repository interfaces (no Flutter, no Firebase)
      application/     use cases / controllers (ChangeNotifier); depend on domain only
      data/            Firebase implementations of the domain interfaces
      presentation/    screens and widgets, plus the feature's Scope
    admin/ student/ teacher/      role shells (see below)
```

**Features:** auth, courses, classroom (course page, chat, assignments,
materials, recordings), meet (Calligro Meet / LiveKit), community, profile,
gallery, rating, notifications, teacher_money, settings, and admin.
Admin is both a feature (`domain/admin_rules.dart`, `data/admin_service.dart`)
and a role shell.

## How a screen gets its data

Every feature has a **Scope**, an `InheritedWidget` holding that feature's
services: `CourseScope`, `ClassroomScope`, `AuthScope`, `MoneyScope`,
`ProfileScope`, `GalleryScope`, `NotificationScope`, `RatingScope`,
`CommunityScope`.

- Screens call `XScope.of(context)` and never `FirebaseFirestore.instance`,
  `FirebaseAuth.instance` and so on.
- With no Scope above the screen, `of` returns the real Firebase services
  (cached). The app therefore needs no set-up to run.
- Tests put fakes in a Scope above the screen. This is how screens are
  tested without Firebase.

## Rules that live on the server

The app never decides these on its own; Cloud Functions do (`functions/`):

- enrolment and purchases;
- withdrawals (`requestWithdrawal`, run in a transaction);
- rating totals;
- notification delivery (once per event);
- email codes and password reset;
- push-token ownership.

Firestore and Storage rules are tested on the emulators
(`functions/test/*rules*.test.js`).

## Role shells: admin, student, teacher

A shell holds only:

| shell   | contains                                                                 |
|---------|--------------------------------------------------------------------------|
| student | `presentation/` (dashboard, home page, drawer, settings, teachers list), `data/` (StudentService, StudentUserModel) |
| teacher | `presentation/` (dashboard, home tab, settings, first-time setup)        |
| admin   | `presentation/` (dashboard, admin pages, drawer), `data/`, `domain/`     |

Rules (in `test/architecture_guardrails_test.dart`):

1. A shell has no other folders. Feature code goes in its feature.
2. Shells never import each other.
3. Features never import a shell. Three older links are **frozen** in an
   allow-list; the list may only shrink:
   - `notifications/.../app_notification_navigator.dart` opens the admin's
     pending-teachers page;
   - `profile/.../my_profile_tab.dart` opens each role's settings page;
   - `classroom/.../course_details_page.dart` uses
     `AdminService.sendCourseNotification`.

## Tests

`test/` mirrors `lib/`:

```
test/
  architecture_guardrails_test.dart     structure rules (this file)
  core/  screens/
  features/<feature>/
    domain/ application/ data/ presentation/
    fakes/                                 in-memory fakes for that feature's interfaces
    <feature>_guardrails_test.dart         that feature's layering rules
```

- Every feature has a guard-rail test: no Firebase in the UI, domain stays
  pure, one source for each rule. Each guard-rail was checked with a planted
  bug to prove it fails.
- To run the app tests: `flutter test`.
- To run the server and rules tests: `cd functions && npm test` (Jest,
  `--runInBand`; the rules suites need the emulators, see the CI workflow).
- CI (`.github/workflows/calligro_tests.yml`) runs the whole app suite, the
  function tests and the rules tests.

## Adding something new

1. Pick the feature. If none fits, create
   `lib/features/<name>/{domain,application,data,presentation}`.
2. Put rules in `domain/` and test them there first.
3. Add a repository interface in `domain/`, its Firebase version in `data/`,
   and a fake in `test/features/<name>/fakes/`.
4. Expose the services through the feature's Scope; screens use `Scope.of`.
5. Put the tests under `test/features/<name>/<layer>/`, and extend the
   feature's guard-rail test if you add a new rule.
