import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import 'package:calligro_app/l10n/app_localizations.dart';

import '../../application/meet_controller.dart';
import '../../data/shared_work_pages.dart';
import '../../domain/shared_work.dart';

const _gold = Color(0xFFEBB937);

/// Pen colours the teacher can pick (ARGB).
const sharedWorkPenColors = [0xFFE53935, 0xFF1E88E5, 0xFF43A047, 0xFF111111];

/// Pen width as a fraction of the page width.
const _penWidth = 0.008;

/// The student work the teacher is showing, on everyone's screen.
///
/// Students only watch (the teacher's page, zoom and lines arrive as messages).
/// The teacher draws with one finger in pen mode, and moves / zooms with two
/// fingers (or one finger in move mode).
class SharedWorkStage extends StatefulWidget {
  final MeetController controller;
  final SharedWorkPageLoader loadPages;

  /// A tap on the work (move mode / students): show or hide the meeting controls.
  final VoidCallback onTap;

  const SharedWorkStage({
    super.key,
    required this.controller,
    required this.onTap,
    this.loadPages = loadSharedWorkPages,
  });

  @override
  State<SharedWorkStage> createState() => _SharedWorkStageState();
}

enum _Tool { pen, move }

class _SharedWorkStageState extends State<SharedWorkStage> {
  String? _loadedUrl;
  Future<List<ui.Image>>? _pages;

  _Tool _tool = _Tool.pen;
  int _color = sharedWorkPenColors.first;

  // Gesture state
  String? _strokeId;
  SharedView? _viewAtStart;
  Offset? _focalAtStart;
  bool _zooming = false;

  MeetController get _c => widget.controller;

  void _ensureLoaded(SharedWork work) {
    if (_loadedUrl == work.url) return;
    _loadedUrl = work.url;
    _pages = widget.loadPages(work.url, work.kind);
  }

  @override
  Widget build(BuildContext context) {
    final work = _c.sharedWork;
    if (work == null) return const SizedBox.shrink();
    _ensureLoaded(work);
    final l10n = AppLocalizations.of(context)!;

    return ColoredBox(
      color: const Color(0xFF0E0F12),
      child: Stack(
        fit: StackFit.expand,
        children: [
          FutureBuilder<List<ui.Image>>(
            future: _pages,
            builder: (context, snap) {
              if (snap.hasError) return _message(Icons.broken_image_outlined, l10n.meetSharedWorkError);
              final pages = snap.data;
              if (pages == null) return _loading(l10n.meetSharedWorkLoading);
              final index = work.page.clamp(0, pages.length - 1);
              return _document(work, pages[index], pages.length);
            },
          ),
          _label(work),
          if (_c.isTeacher) _toolbar(work, l10n),
        ],
      ),
    );
  }

  // ── The page, the teacher's lines, the shared zoom ─────────────────────
  Widget _document(SharedWork work, ui.Image image, int pageCount) {
    return LayoutBuilder(builder: (context, box) {
      final area = Size(box.maxWidth, box.maxHeight);
      final imageSize = Size(image.width.toDouble(), image.height.toDouble());
      final fitted = applyBoxFit(BoxFit.contain, imageSize, area).destination;
      final origin = Offset((area.width - fitted.width) / 2, (area.height - fitted.height) / 2);
      final docRect = origin & fitted;
      final view = work.view;
      final center = area.center(Offset.zero);
      final shift = Offset(view.dx * area.width, view.dy * area.height);

      final matrix = Matrix4.identity()
        ..translateByDouble(center.dx + shift.dx, center.dy + shift.dy, 0, 1)
        ..scaleByDouble(view.scale, view.scale, 1, 1)
        ..translateByDouble(-center.dx, -center.dy, 0, 1);

      // Screen point → fraction of the page (undoing the zoom first).
      SharedPoint toPage(Offset p) {
        final unzoomed = (p - center - shift) / view.scale + center;
        return SharedPoint(
          ((unzoomed.dx - docRect.left) / docRect.width).clamp(0.0, 1.0),
          ((unzoomed.dy - docRect.top) / docRect.height).clamp(0.0, 1.0),
        );
      }

      final content = Transform(
        transform: matrix,
        child: Stack(children: [
          Positioned.fromRect(rect: docRect, child: RawImage(image: image, fit: BoxFit.fill)),
          Positioned.fromRect(
            rect: docRect,
            child: CustomPaint(painter: SharedStrokesPainter(work.strokesOnPage)),
          ),
        ]),
      );

      if (!_c.isTeacher) {
        return GestureDetector(
          key: const Key('shared-work-student-tap'),
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          child: ClipRect(child: content),
        );
      }

      return GestureDetector(
        key: const Key('shared-work-canvas'),
        behavior: HitTestBehavior.opaque,
        onTap: _tool == _Tool.move ? widget.onTap : null,
        onScaleStart: (d) {
          _zooming = _tool == _Tool.move || d.pointerCount > 1;
          if (_zooming) {
            _viewAtStart = _c.sharedWork?.view;
            _focalAtStart = d.localFocalPoint;
          } else {
            _strokeId = _c.startStroke(color: _color, width: _penWidth, at: toPage(d.localFocalPoint));
          }
        },
        onScaleUpdate: (d) {
          if (d.pointerCount > 1 && !_zooming) {
            // A second finger arrived: finish the line, switch to zooming.
            _finishStroke();
            _zooming = true;
            _viewAtStart = _c.sharedWork?.view;
            _focalAtStart = d.localFocalPoint;
          }
          if (_zooming) {
            final start = _viewAtStart ?? SharedView.identity;
            final moved = d.localFocalPoint - (_focalAtStart ?? d.localFocalPoint);
            _c.setView(SharedView(
              scale: start.scale * d.scale,
              dx: start.dx + moved.dx / area.width,
              dy: start.dy + moved.dy / area.height,
            ));
          } else if (_strokeId != null) {
            _c.extendStroke(_strokeId!, toPage(d.localFocalPoint));
          }
        },
        onScaleEnd: (_) {
          if (_zooming) {
            _c.endViewChange();
            _zooming = false;
          }
          _finishStroke();
        },
        child: ClipRect(child: content),
      );
    });
  }

  void _finishStroke() {
    final id = _strokeId;
    if (id == null) return;
    _strokeId = null;
    _c.endStroke(id);
  }

  // ── Header: whose work this is ─────────────────────────────────────────
  Widget _label(SharedWork work) {
    final pages = work.kind == SharedWorkKind.pdf;
    return Positioned(
      top: 0,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 64, 16, 0),
          child: Align(
            alignment: AlignmentDirectional.topStart,
            child: IgnorePointer(
              child: Container(
                key: const Key('shared-work-label'),
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: _gold.withValues(alpha: 0.4)),
                ),
                child: Row(mainAxisSize: MainAxisSize.min, children: [
                  const Icon(Icons.co_present, color: _gold, size: 16),
                  const SizedBox(width: 8),
                  Flexible(
                    child: Text(
                      [work.studentName, work.assignmentTitle].where((s) => s.isNotEmpty).join(' · '),
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w700, fontSize: 13),
                    ),
                  ),
                  if (pages) ...[
                    const SizedBox(width: 10),
                    Text('${work.page + 1}', style: const TextStyle(color: _gold, fontWeight: FontWeight.w800, fontSize: 13)),
                  ],
                ]),
              ),
            ),
          ),
        ),
      ),
    );
  }

  // ── Teacher tools (right side) ─────────────────────────────────────────
  Widget _toolbar(SharedWork work, AppLocalizations l10n) {
    Widget tool(Key key, IconData icon, String tip, VoidCallback onTap, {bool active = false, Color? color}) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Tooltip(
            message: tip,
            child: InkWell(
              key: key,
              customBorder: const CircleBorder(),
              onTap: onTap,
              child: Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(color: active ? _gold : Colors.white12, shape: BoxShape.circle),
                child: Icon(icon, size: 20, color: color ?? (active ? Colors.black : Colors.white)),
              ),
            ),
          ),
        );

    // Inside the safe area: in landscape the iPhone's Dynamic Island / notch sits on a side
    // edge (either one, depending on how the phone is turned), and it hid these buttons.
    return PositionedDirectional(
      end: 10,
      top: 0,
      bottom: 0,
      child: SafeArea(
        key: const Key('shared-work-toolbar-safe-area'),
        child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 6),
          decoration: BoxDecoration(
            color: const Color(0xFF13151A).withValues(alpha: 0.88),
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: Colors.white.withValues(alpha: 0.12)),
          ),
          child: SingleChildScrollView(
            child: Column(mainAxisSize: MainAxisSize.min, children: [
              tool(const Key('shared-work-pen'), Icons.edit, l10n.meetDrawPen, () => setState(() => _tool = _Tool.pen),
                  active: _tool == _Tool.pen),
              tool(const Key('shared-work-move'), Icons.pan_tool_alt, l10n.meetDrawMove,
                  () => setState(() => _tool = _Tool.move),
                  active: _tool == _Tool.move),
              const SizedBox(height: 4),
              for (final c in sharedWorkPenColors)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 3),
                  child: GestureDetector(
                    key: Key('shared-work-color-$c'),
                    onTap: () => setState(() {
                      _color = c;
                      _tool = _Tool.pen;
                    }),
                    child: Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        color: Color(c),
                        shape: BoxShape.circle,
                        border: Border.all(color: _color == c ? _gold : Colors.white38, width: _color == c ? 3 : 1.5),
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              tool(const Key('shared-work-undo'), Icons.undo, l10n.meetDrawUndo, _c.undoStroke),
              tool(const Key('shared-work-clear'), Icons.layers_clear, l10n.meetDrawClear, _c.clearPage),
              if (work.kind == SharedWorkKind.pdf) ...[
                tool(const Key('shared-work-prev'), Icons.keyboard_arrow_up, l10n.meetPreviousPage,
                    () => _c.setPage(work.page - 1)),
                tool(const Key('shared-work-next'), Icons.keyboard_arrow_down, l10n.meetNextPage, () => _nextPage(work)),
              ],
              tool(const Key('shared-work-stop'), Icons.close, l10n.meetStopShowing, _c.stopSharing, color: Colors.redAccent),
            ]),
          ),
        ),
      ),
      ),
    );
  }

  Future<void> _nextPage(SharedWork work) async {
    final pages = await _pages;
    if (pages != null && work.page + 1 < pages.length) _c.setPage(work.page + 1);
  }

  // ── Loading / error ────────────────────────────────────────────────────
  Widget _loading(String text) => Center(
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const CircularProgressIndicator(color: _gold),
          const SizedBox(height: 14),
          Text(text, style: const TextStyle(color: Colors.white70)),
        ]),
      );

  Widget _message(IconData icon, String text) => GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            Icon(icon, color: Colors.white38, size: 48),
            const SizedBox(height: 12),
            Text(text, style: const TextStyle(color: Colors.white70)),
          ]),
        ),
      );
}

/// Paints the teacher's lines; coordinates are fractions of the page.
class SharedStrokesPainter extends CustomPainter {
  final List<SharedStroke> strokes;
  const SharedStrokesPainter(this.strokes);

  @override
  void paint(Canvas canvas, Size size) {
    for (final s in strokes) {
      if (s.points.isEmpty) continue;
      final paint = Paint()
        ..color = Color(s.color)
        ..strokeWidth = s.width * size.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;
      Offset at(SharedPoint p) => Offset(p.x * size.width, p.y * size.height);
      if (s.points.length == 1) {
        canvas.drawCircle(at(s.points.single), paint.strokeWidth / 2, paint..style = PaintingStyle.fill);
        continue;
      }
      final path = Path()..moveTo(at(s.points.first).dx, at(s.points.first).dy);
      for (final p in s.points.skip(1)) {
        path.lineTo(at(p).dx, at(p).dy);
      }
      canvas.drawPath(path, paint);
    }
  }

  @override
  bool shouldRepaint(SharedStrokesPainter old) => true;
}
