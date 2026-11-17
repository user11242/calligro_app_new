import 'dart:math' as math;

import 'meet_protocol.dart';

/// "Show a student's work to the class": the teacher puts one submission
/// (image or PDF) on everyone's screen, turns PDF pages, zooms, and draws on it.
///
/// Everything here is pure Dart: what a wire message means ([SharedWorkMessage]),
/// how every screen ends up showing the same thing ([SharedWorkReducer]), and the
/// messages the teacher sends ([SharedWorkProtocol]). Only the course teacher may
/// send these (checked in MeetMessageHandler).

enum SharedWorkKind {
  image,
  pdf;

  static const _imageExtensions = {'jpg', 'jpeg', 'png', 'heic', 'heif', 'webp', 'gif'};

  /// What kind of file a submission is, or null when it cannot be shown in class.
  static SharedWorkKind? fromFile({required String? fileName, required String url}) {
    String? ext(String s) {
      final clean = s.split('?').first.split('#').first;
      final dot = clean.lastIndexOf('.');
      return dot < 0 ? null : clean.substring(dot + 1).toLowerCase();
    }

    SharedWorkKind? kindOf(String? e) =>
        e == 'pdf' ? SharedWorkKind.pdf : (_imageExtensions.contains(e) ? SharedWorkKind.image : null);

    // The file name, when it has an extension, decides on its own.
    final named = fileName == null ? null : ext(fileName);
    if (named != null) return kindOf(named);

    for (final candidate in [
      ext(Uri.decodeComponent(url.split('?').first)),
      ...RegExp(r'\.([a-zA-Z0-9]{2,5})(?:$|[&#])').allMatches(url).map((m) => m.group(1)!.toLowerCase()),
    ]) {
      final kind = kindOf(candidate);
      if (kind != null) return kind;
    }
    return null;
  }
}

/// A point on the document, as a fraction of its width (x) and height (y): 0..1.
/// Fractions make a drawing land on the same spot on every screen size.
class SharedPoint {
  final double x;
  final double y;
  const SharedPoint(this.x, this.y);

  @override
  bool operator ==(Object other) => other is SharedPoint && other.x == x && other.y == y;
  @override
  int get hashCode => Object.hash(x, y);
  @override
  String toString() => '($x, $y)';
}

/// One pen stroke by the teacher on [page]. [width] is a fraction of the page width.
class SharedStroke {
  final String id;
  final int page;
  final int color;
  final double width;
  final List<SharedPoint> points;
  const SharedStroke({required this.id, required this.page, required this.color, required this.width, required this.points});

  SharedStroke withPoints(List<SharedPoint> points) =>
      SharedStroke(id: id, page: page, color: color, width: width, points: List.unmodifiable(points));

  @override
  bool operator ==(Object other) =>
      other is SharedStroke &&
      other.id == id &&
      other.page == page &&
      other.color == color &&
      other.width == width &&
      _listEq(other.points, points);
  @override
  int get hashCode => Object.hash(id, page, color, width, Object.hashAll(points));
}

/// The teacher's zoom: [scale] (1 = whole page) and the pan as a fraction of the screen.
class SharedView {
  static const maxScale = 6.0;
  static const maxShift = 5.0;
  static const identity = SharedView(scale: 1, dx: 0, dy: 0);

  final double scale;
  final double dx;
  final double dy;
  const SharedView({required this.scale, required this.dx, required this.dy});

  SharedView clamped() => SharedView(
        scale: scale.clamp(1.0, maxScale).toDouble(),
        dx: dx.clamp(-maxShift, maxShift).toDouble(),
        dy: dy.clamp(-maxShift, maxShift).toDouble(),
      );

  @override
  bool operator ==(Object other) => other is SharedView && other.scale == scale && other.dx == dx && other.dy == dy;
  @override
  int get hashCode => Object.hash(scale, dx, dy);
}

/// What is on everyone's screen right now.
class SharedWork {
  final String shareId;
  final String url;
  final SharedWorkKind kind;
  final String studentName;
  final String assignmentTitle;

  /// 0-based PDF page (always 0 for an image).
  final int page;
  final SharedView view;

  /// All strokes on all pages, oldest first.
  final List<SharedStroke> strokes;

  const SharedWork({
    required this.shareId,
    required this.url,
    required this.kind,
    required this.studentName,
    required this.assignmentTitle,
    this.page = 0,
    this.view = SharedView.identity,
    this.strokes = const [],
  });

  List<SharedStroke> get strokesOnPage => strokes.where((s) => s.page == page).toList();

  SharedWork copyWith({int? page, SharedView? view, List<SharedStroke>? strokes, String? studentName, String? assignmentTitle}) =>
      SharedWork(
        shareId: shareId,
        url: url,
        kind: kind,
        studentName: studentName ?? this.studentName,
        assignmentTitle: assignmentTitle ?? this.assignmentTitle,
        page: page ?? this.page,
        view: view ?? this.view,
        strokes: strokes == null ? this.strokes : List.unmodifiable(strokes),
      );

  @override
  bool operator ==(Object other) =>
      other is SharedWork &&
      other.shareId == shareId &&
      other.url == url &&
      other.kind == kind &&
      other.studentName == studentName &&
      other.assignmentTitle == assignmentTitle &&
      other.page == page &&
      other.view == view &&
      _listEq(other.strokes, strokes);
  @override
  int get hashCode => Object.hash(shareId, url, kind, studentName, assignmentTitle, page, view, Object.hashAll(strokes));
}

// ─────────────────────────────────────────────────────────────────────────────
// Wire messages
// ─────────────────────────────────────────────────────────────────────────────

sealed class SharedWorkMessage {
  final String shareId;
  const SharedWorkMessage(this.shareId);

  static const maxNameLength = 80;
  static const maxTitleLength = 120;
  static const maxPage = 499;
  static const maxPointsPerMessage = 3000;

  /// The typed message, or null when [m] is not a valid shared-work message.
  static SharedWorkMessage? parse(Map<String, dynamic> m) {
    final type = m['type'];
    final shareId = m['shareId'];
    if (type is! String || shareId is! String || shareId.isEmpty || shareId.length > 64) return null;
    switch (type) {
      case MeetProtocol.workShow:
        final url = m['url'];
        final kind = SharedWorkKind.values.asNameMap()[m['kind']];
        if (url is! String || kind == null || !isAllowedUrl(url)) return null;
        return ShowWork(shareId,
            url: url,
            kind: kind,
            studentName: _text(m['studentName'], maxNameLength),
            assignmentTitle: _text(m['assignmentTitle'], maxTitleLength));
      case MeetProtocol.workPage:
        final page = m['page'];
        if (page is! int || page < 0 || page > maxPage) return null;
        return SetPage(shareId, page);
      case MeetProtocol.workView:
        final s = m['scale'], dx = m['dx'], dy = m['dy'];
        if (s is! num || dx is! num || dy is! num) return null;
        return SetView(shareId, SharedView(scale: s.toDouble(), dx: dx.toDouble(), dy: dy.toDouble()).clamped());
      case MeetProtocol.workStroke:
        final id = m['strokeId'], page = m['page'], color = m['color'], width = m['width'], pts = m['points'];
        final from = m['from'] ?? 0;
        if (id is! String || id.isEmpty || id.length > 64) return null;
        if (page is! int || page < 0 || page > maxPage || color is! int || width is! num || from is! int || from < 0) return null;
        if (pts is! List || pts.length.isOdd || pts.length > maxPointsPerMessage * 2 || pts.any((v) => v is! num)) return null;
        final points = [
          for (var i = 0; i < pts.length; i += 2)
            SharedPoint((pts[i] as num).toDouble().clamp(0.0, 1.0).toDouble(), (pts[i + 1] as num).toDouble().clamp(0.0, 1.0).toDouble()),
        ];
        return DrawStroke(shareId,
            SharedStroke(id: id, page: page, color: color, width: width.toDouble().clamp(0.001, 0.05).toDouble(), points: points),
            from: from);
      case MeetProtocol.workUndo:
        final id = m['strokeId'];
        return id is String && id.isNotEmpty ? UndoStroke(shareId, id) : null;
      case MeetProtocol.workClear:
        final page = m['page'];
        return page is int && page >= 0 && page <= maxPage ? ClearPage(shareId, page) : null;
      case MeetProtocol.workStop:
        return StopWork(shareId);
    }
    return null;
  }

  /// Only https links to Firebase / Google Cloud Storage (where submissions live).
  static bool isAllowedUrl(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null || uri.scheme != 'https') return false;
    return uri.host == 'firebasestorage.googleapis.com' || uri.host == 'storage.googleapis.com';
  }

  static String _text(Object? v, int max) {
    final s = v is String ? v.trim() : '';
    return s.length > max ? s.substring(0, max) : s;
  }
}

class ShowWork extends SharedWorkMessage {
  final String url;
  final SharedWorkKind kind;
  final String studentName;
  final String assignmentTitle;
  const ShowWork(super.shareId, {required this.url, required this.kind, required this.studentName, required this.assignmentTitle});
}

class SetPage extends SharedWorkMessage {
  final int page;
  const SetPage(super.shareId, this.page);
}

class SetView extends SharedWorkMessage {
  final SharedView view;
  const SetView(super.shareId, this.view);
}

/// Points of [stroke] starting at index [from] (live drawing arrives in pieces).
class DrawStroke extends SharedWorkMessage {
  final SharedStroke stroke;
  final int from;
  const DrawStroke(super.shareId, this.stroke, {this.from = 0});
}

class UndoStroke extends SharedWorkMessage {
  final String strokeId;
  const UndoStroke(super.shareId, this.strokeId);
}

class ClearPage extends SharedWorkMessage {
  final int page;
  const ClearPage(super.shareId, this.page);
}

class StopWork extends SharedWorkMessage {
  const StopWork(super.shareId);
}

// ─────────────────────────────────────────────────────────────────────────────
// Applying messages (the same on every screen; resends are harmless)
// ─────────────────────────────────────────────────────────────────────────────

class SharedWorkReducer {
  SharedWorkReducer._();

  static SharedWork? apply(SharedWork? current, SharedWorkMessage m) {
    if (m is ShowWork) {
      if (current != null && current.shareId == m.shareId) {
        return current.copyWith(studentName: m.studentName, assignmentTitle: m.assignmentTitle);
      }
      return SharedWork(
          shareId: m.shareId, url: m.url, kind: m.kind, studentName: m.studentName, assignmentTitle: m.assignmentTitle);
    }
    if (current == null || current.shareId != m.shareId) return current;
    switch (m) {
      case ShowWork():
        return current;
      case SetPage(:final page):
        return page == current.page ? current : current.copyWith(page: page, view: SharedView.identity);
      case SetView(:final view):
        return current.copyWith(view: view);
      case DrawStroke(:final stroke, :final from):
        final strokes = [...current.strokes];
        final i = strokes.indexWhere((s) => s.id == stroke.id);
        if (i < 0) {
          strokes.add(stroke.withPoints(stroke.points));
        } else {
          final existing = strokes[i].points;
          final keep = existing.take(math.min(from, existing.length));
          strokes[i] = strokes[i].withPoints([...keep, ...stroke.points]);
        }
        return current.copyWith(strokes: strokes);
      case UndoStroke(:final strokeId):
        return current.copyWith(strokes: current.strokes.where((s) => s.id != strokeId).toList());
      case ClearPage(:final page):
        return current.copyWith(strokes: current.strokes.where((s) => s.page != page).toList());
      case StopWork():
        return null;
    }
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Building the messages the teacher sends
// ─────────────────────────────────────────────────────────────────────────────

class SharedWorkProtocol {
  SharedWorkProtocol._();

  /// Points per message: keeps every packet well under LiveKit's data limit.
  static const pointsPerMessage = 400;

  static Map<String, dynamic> show({
    required String shareId,
    required String url,
    required SharedWorkKind kind,
    required String studentName,
    required String assignmentTitle,
  }) =>
      {
        'type': MeetProtocol.workShow,
        'shareId': shareId,
        'url': url,
        'kind': kind.name,
        'studentName': studentName,
        'assignmentTitle': assignmentTitle,
      };

  static Map<String, dynamic> page(String shareId, int page) =>
      {'type': MeetProtocol.workPage, 'shareId': shareId, 'page': page};

  static Map<String, dynamic> view(String shareId, SharedView v) =>
      {'type': MeetProtocol.workView, 'shareId': shareId, 'scale': _r(v.scale), 'dx': _r(v.dx), 'dy': _r(v.dy)};

  /// The points of [stroke] (they start at index [from] of the whole stroke).
  static Map<String, dynamic> stroke(String shareId, SharedStroke stroke, {int from = 0}) => {
        'type': MeetProtocol.workStroke,
        'shareId': shareId,
        'strokeId': stroke.id,
        'page': stroke.page,
        'color': stroke.color,
        'width': _r(stroke.width),
        'from': from,
        'points': [for (final p in stroke.points) ...[_r(p.x), _r(p.y)]],
      };

  /// A whole stroke, split into pieces that each fit in one message.
  static List<Map<String, dynamic>> strokePieces(String shareId, SharedStroke s) {
    if (s.points.length <= pointsPerMessage) return [stroke(shareId, s)];
    return [
      for (var from = 0; from < s.points.length; from += pointsPerMessage)
        stroke(shareId, s.withPoints(s.points.sublist(from, math.min(from + pointsPerMessage, s.points.length))), from: from),
    ];
  }

  static Map<String, dynamic> undo(String shareId, String strokeId) =>
      {'type': MeetProtocol.workUndo, 'shareId': shareId, 'strokeId': strokeId};

  static Map<String, dynamic> clear(String shareId, int page) =>
      {'type': MeetProtocol.workClear, 'shareId': shareId, 'page': page};

  static Map<String, dynamic> stop(String shareId) => {'type': MeetProtocol.workStop, 'shareId': shareId};

  /// Everything needed to rebuild [w] on a screen that joined late.
  static List<Map<String, dynamic>> snapshot(SharedWork w) => [
        show(shareId: w.shareId, url: w.url, kind: w.kind, studentName: w.studentName, assignmentTitle: w.assignmentTitle),
        if (w.page != 0) page(w.shareId, w.page),
        if (w.view != SharedView.identity) view(w.shareId, w.view),
        for (final s in w.strokes) ...strokePieces(w.shareId, s),
      ];

  static double _r(double v) => (v * 10000).roundToDouble() / 10000;
}

bool _listEq<T>(List<T> a, List<T> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
