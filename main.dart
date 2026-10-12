import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:gal/gal.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

void main() => runApp(const StudioApp());

// ───────────────────────── التطبيق ─────────────────────────
class StudioApp extends StatelessWidget {
  const StudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      title: 'ستوديو',
      theme: ThemeData(
        useMaterial3: true,
        brightness: Brightness.dark,
        colorScheme: ColorScheme.fromSeed(
            seedColor: const Color(0xFF7C4DFF), brightness: Brightness.dark),
        scaffoldBackgroundColor: const Color(0xFF0E0E14),
      ),
      builder: (c, child) =>
          Directionality(textDirection: TextDirection.rtl, child: child!),
      home: const HomePage(),
    );
  }
}

// ───────────────────────── الطبقات ─────────────────────────
abstract class Layer {
  Offset pos = Offset.zero;
  double scale = 1;
  double rotation = 0;
  bool visible = true;
  String get label;
}

class TextLayer extends Layer {
  String text;
  String font = 'Cairo';
  double size = 40;
  Color color = Colors.white;
  Color strokeColor = Colors.black;
  double strokeWidth = 0;
  bool shadow = false;
  bool gradient = false;
  Color color2 = Colors.pinkAccent;
  bool bold = true;
  double opacity = 1;
  TextLayer(this.text);
  @override
  String get label => text.replaceAll('\n', ' ');
}

class EmojiLayer extends Layer {
  String emoji;
  EmojiLayer(this.emoji);
  @override
  String get label => emoji;
}

class ImageLayer extends Layer {
  Uint8List bytes;
  ImageLayer(this.bytes);
  @override
  String get label => 'صورة';
}

// ───────────────────────── مصفوفات الألوان ─────────────────────────
const List<double> _identity = [
  1, 0, 0, 0, 0, //
  0, 1, 0, 0, 0,
  0, 0, 1, 0, 0,
  0, 0, 0, 1, 0,
];

List<double> _mul(List<double> a, List<double> b) {
  final r = List<double>.filled(20, 0);
  for (var i = 0; i < 4; i++) {
    for (var j = 0; j < 5; j++) {
      var s = 0.0;
      for (var k = 0; k < 4; k++) {
        s += a[i * 5 + k] * b[k * 5 + j];
      }
      if (j == 4) s += a[i * 5 + 4];
      r[i * 5 + j] = s;
    }
  }
  return r;
}

List<double> _sat(double s) {
  const lr = 0.2126, lg = 0.7152, lb = 0.0722;
  final a = lr * (1 - s), b = lg * (1 - s), c = lb * (1 - s);
  return [
    a + s, b, c, 0, 0, //
    a, b + s, c, 0, 0,
    a, b, c + s, 0, 0,
    0, 0, 0, 1, 0,
  ];
}

List<double> _contrast(double c) {
  final t = 128 * (1 - c);
  return [
    c, 0, 0, 0, t, //
    0, c, 0, 0, t,
    0, 0, c, 0, t,
    0, 0, 0, 1, 0,
  ];
}

List<double> _bright(double b) {
  final t = b * 255;
  return [
    1, 0, 0, 0, t, //
    0, 1, 0, 0, t,
    0, 0, 1, 0, t,
    0, 0, 0, 1, 0,
  ];
}

const List<double> _sepia = [
  0.393, 0.769, 0.189, 0, 0, //
  0.349, 0.686, 0.168, 0, 0,
  0.272, 0.534, 0.131, 0, 0,
  0, 0, 0, 1, 0,
];

final Map<String, List<double>> _presets = {
  'أصلي': _identity,
  'أبيض وأسود': _sat(0),
  'سيبيا': _sepia,
  'دافئ': [1.1, 0, 0, 0, 10, 0, 1, 0, 0, 0, 0, 0, 0.9, 0, -10, 0, 0, 0, 1, 0],
  'بارد': [0.9, 0, 0, 0, -10, 0, 1, 0, 0, 0, 0, 0, 1.1, 0, 10, 0, 0, 0, 1, 0],
  'نابض': _mul(_sat(1.6), _contrast(1.1)),
  'باهت': _mul(_contrast(0.8), _bright(0.08)),
  'قديم': _mul(_sepia, _contrast(0.9)),
  'درامي': _mul(_contrast(1.4), _sat(0.8)),
};

// ───────────────────────── ثوابت ─────────────────────────
const List<Color> _colors = [
  Colors.white,
  Colors.black,
  Color(0xFFFF1744),
  Color(0xFFFF9100),
  Color(0xFFFFEA00),
  Color(0xFF00E676),
  Color(0xFF00E5FF),
  Color(0xFF2979FF),
  Color(0xFF7C4DFF),
  Color(0xFFF50057),
  Color(0xFF795548),
  Color(0xFF9E9E9E),
];

const List<String> _fonts = [
  'Cairo',
  'Tajawal',
  'Almarai',
  'Amiri',
  'Lalezar',
  'Changa',
  'Reem Kufi',
  'El Messiri',
  'Mada',
  'Harmattan',
  'Pacifico',
  'Lobster',
  'Bebas Neue',
  'Oswald',
  'Permanent Marker',
  'Dancing Script',
];

const List<String> _emojis = [
  '😀', '😍', '😎', '🤩', '😂', '🥳', '😈', '🤯',
  '👑', '🔥', '✨', '💫', '⭐', '🌟', '💥', '⚡',
  '❤️', '💜', '💙', '🖤', '💔', '💯', '🎉', '🎈',
  '🌹', '🌸', '🌙', '☀️', '🌈', '🦋', '🎵', '💎',
  '🏆', '🚀', '👍', '🙏', '👌', '✌️', '🕌', '☕',
];

bool _isRtl(String s) => RegExp(r'[\u0600-\u06FF]').hasMatch(s);

// ───────────────────────── الشاشة الرئيسية ─────────────────────────
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  Future<void> _pick(BuildContext ctx) async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 3000);
    if (x == null) return;
    final bytes = await x.readAsBytes();
    final img = await decodeImageFromList(bytes);
    if (!ctx.mounted) return;
    Navigator.push(
      ctx,
      MaterialPageRoute(
        builder: (_) => EditorPage(
            bytes: bytes, w: img.width.toDouble(), h: img.height.toDouble()),
      ),
    );
  }

  void _blank(BuildContext ctx, double w, double h) {
    Navigator.push(
      ctx,
      MaterialPageRoute(builder: (_) => EditorPage(bytes: null, w: w, h: h)),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topRight,
            end: Alignment.bottomLeft,
            colors: [Color(0xFF2A1B5E), Color(0xFF0E0E14)],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Icon(Icons.auto_awesome, size: 72, color: Colors.white),
                const SizedBox(height: 16),
                Text('ستوديو',
                    textAlign: TextAlign.center,
                    style: GoogleFonts.lalezar(fontSize: 52)),
                const Text('اكتب، زخرف، وعدّل صورك بسهولة',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70)),
                const SizedBox(height: 48),
                FilledButton.icon(
                  onPressed: () => _pick(context),
                  icon: const Icon(Icons.photo_library),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('اختر صورة من المعرض',
                        style: TextStyle(fontSize: 16)),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _blank(context, 1080, 1080),
                  icon: const Icon(Icons.crop_square),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('لوحة فارغة 1:1'),
                  ),
                ),
                const SizedBox(height: 12),
                OutlinedButton.icon(
                  onPressed: () => _blank(context, 1080, 1920),
                  icon: const Icon(Icons.stay_current_portrait),
                  label: const Padding(
                    padding: EdgeInsets.all(14),
                    child: Text('لوحة ستوري 9:16'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ───────────────────────── المحرر ─────────────────────────
class EditorPage extends StatefulWidget {
  final Uint8List? bytes;
  final double w, h;
  const EditorPage({super.key, required this.bytes, required this.w, required this.h});

  @override
  State<EditorPage> createState() => _EditorPageState();
}

class _EditorPageState extends State<EditorPage> {
  final GlobalKey _key = GlobalKey();
  final List<Layer> _layers = [];
  final TextEditingController _tc = TextEditingController();
  Layer? _sel;
  int _tab = -1;
  bool _exporting = false;

  String _preset = 'أصلي';
  double _brightness = 0;
  double _contr = 1;
  double _saturation = 1;
  Color _bg = Colors.white;

  double _bs = 1, _br = 0;

  @override
  void dispose() {
    _tc.dispose();
    super.dispose();
  }

  // ── منطق ──
  List<double> _matrix() {
    final adj = _mul(_bright(_brightness), _mul(_contrast(_contr), _sat(_saturation)));
    return _mul(adj, _presets[_preset]!);
  }

  void _select(Layer? l) {
    setState(() {
      _sel = l;
      if (l is TextLayer) _tc.text = l.text;
    });
  }

  void _add(Layer l) {
    _layers.add(l);
    _select(l);
  }

  void _addText() {
    final l = TextLayer('اكتب هنا');
    _add(l);
    setState(() => _tab = 0);
  }

  Future<void> _addImage() async {
    final x = await ImagePicker()
        .pickImage(source: ImageSource.gallery, maxWidth: 1500);
    if (x == null) return;
    _add(ImageLayer(await x.readAsBytes()));
  }

  void _deleteSelected() {
    if (_sel == null) return;
    setState(() {
      _layers.remove(_sel);
      _sel = null;
    });
  }

  void _duplicate() {
    final s = _sel;
    if (s == null) return;
    Layer? c;
    if (s is TextLayer) {
      c = TextLayer(s.text)
        ..font = s.font
        ..size = s.size
        ..color = s.color
        ..strokeColor = s.strokeColor
        ..strokeWidth = s.strokeWidth
        ..shadow = s.shadow
        ..gradient = s.gradient
        ..color2 = s.color2
        ..bold = s.bold
        ..opacity = s.opacity;
    } else if (s is EmojiLayer) {
      c = EmojiLayer(s.emoji);
    } else if (s is ImageLayer) {
      c = ImageLayer(s.bytes);
    }
    if (c == null) return;
    c.pos = s.pos + const Offset(20, 20);
    c.scale = s.scale;
    c.rotation = s.rotation;
    _add(c);
  }

  Future<String> _render() async {
    setState(() {
      _exporting = true;
      _sel = null;
    });
    await Future.delayed(const Duration(milliseconds: 120));
    final boundary =
        _key.currentContext!.findRenderObject() as RenderRepaintBoundary;
    final ratio = (widget.w / boundary.size.width).clamp(1.0, 5.0);
    final img = await boundary.toImage(pixelRatio: ratio);
    final data = await img.toByteData(format: ui.ImageByteFormat.png);
    if (mounted) setState(() => _exporting = false);
    final dir = await getTemporaryDirectory();
    final f = File(
        '${dir.path}/studio_${DateTime.now().millisecondsSinceEpoch}.png');
    await f.writeAsBytes(data!.buffer.asUint8List());
    return f.path;
  }

  void _toast(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _save() async {
    try {
      final p = await _render();
      await Gal.putImage(p, album: 'Studio');
      _toast('تم الحفظ في المعرض ✓');
    } catch (e) {
      _toast('تعذر الحفظ: $e');
    }
  }

  Future<void> _share() async {
    try {
      final p = await _render();
      await Share.shareXFiles([XFile(p)]);
    } catch (e) {
      _toast('تعذرت المشاركة: $e');
    }
  }

  // ── عرض الطبقات ──
  Widget _textWidget(TextLayer l) {
    final base = GoogleFonts.getFont(
      l.font,
      fontSize: l.size,
      fontWeight: l.bold ? FontWeight.w700 : FontWeight.w400,
      height: 1.25,
    );
    final dir = _isRtl(l.text) ? TextDirection.rtl : TextDirection.ltr;
    Text mk(TextStyle s) =>
        Text(l.text, style: s, textAlign: TextAlign.center, textDirection: dir);

    final kids = <Widget>[];
    if (l.shadow) {
      kids.add(mk(base.copyWith(
        color: Colors.black87,
        shadows: const [
          Shadow(color: Colors.black87, blurRadius: 10, offset: Offset(3, 4))
        ],
      )));
    }
    if (l.strokeWidth > 0) {
      kids.add(mk(base.copyWith(
        foreground: Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = l.strokeWidth
          ..strokeJoin = StrokeJoin.round
          ..color = l.strokeColor,
      )));
    }
    if (l.gradient) {
      kids.add(ShaderMask(
        blendMode: BlendMode.srcIn,
        shaderCallback: (r) =>
            LinearGradient(colors: [l.color, l.color2]).createShader(r),
        child: mk(base.copyWith(color: Colors.white)),
      ));
    } else {
      kids.add(mk(base.copyWith(color: l.color)));
    }
    return Opacity(
      opacity: l.opacity,
      child: Stack(alignment: Alignment.center, children: kids),
    );
  }

  Widget _content(Layer l) {
    if (l is TextLayer) return _textWidget(l);
    if (l is EmojiLayer) {
      return Text(l.emoji, style: const TextStyle(fontSize: 64));
    }
    if (l is ImageLayer) return Image.memory(l.bytes, width: 160);
    return const SizedBox();
  }

  Widget _layerWidget(Layer l) {
    final selected = identical(l, _sel) && !_exporting;
    return Positioned.fill(
      child: Center(
        child: Transform.translate(
          offset: l.pos,
          child: Transform.rotate(
            angle: l.rotation,
            child: Transform.scale(
              scale: l.scale,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  _select(l);
                  if (l is TextLayer) setState(() => _tab = 0);
                },
                onScaleStart: (d) {
                  if (!identical(_sel, l)) _select(l);
                  _bs = l.scale;
                  _br = l.rotation;
                },
                onScaleUpdate: (d) {
                  setState(() {
                    l.pos += d.focalPointDelta;
                    l.scale = (_bs * d.scale).clamp(0.2, 8.0);
                    l.rotation = _br + d.rotation;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: BoxDecoration(
                    border: selected
                        ? Border.all(color: Colors.cyanAccent, width: 1.2)
                        : null,
                  ),
                  child: _content(l),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _canvasArea() {
    return LayoutBuilder(builder: (c, bc) {
      final ar = widget.w / widget.h;
      var cw = bc.maxWidth - 16;
      var ch = cw / ar;
      if (ch > bc.maxHeight - 16) {
        ch = bc.maxHeight - 16;
        cw = ch * ar;
      }
      return Center(
        child: SizedBox(
          width: cw,
          height: ch,
          child: RepaintBoundary(
            key: _key,
            child: ClipRect(
              child: Stack(
                children: [
                  Positioned.fill(
                    child: GestureDetector(
                      onTap: () => setState(() => _sel = null),
                      child: widget.bytes == null
                          ? ColoredBox(color: _bg)
                          : ColorFiltered(
                              colorFilter: ColorFilter.matrix(_matrix()),
                              child: Image.memory(widget.bytes!,
                                  fit: BoxFit.fill, gaplessPlayback: true),
                            ),
                    ),
                  ),
                  for (final l in _layers)
                    if (l.visible) _layerWidget(l),
                ],
              ),
            ),
          ),
        ),
      );
    });
  }

  // ── أدوات مساعدة للواجهة ──
  Widget _sl(String t, double v, double min, double max, ValueChanged<double> f) {
    return Row(children: [
      SizedBox(width: 78, child: Text(t, style: const TextStyle(fontSize: 12))),
      Expanded(
        child: Slider(value: v.clamp(min, max), min: min, max: max, onChanged: f),
      ),
    ]);
  }

  Widget _pal(Color cur, ValueChanged<Color> f) {
    return SizedBox(
      height: 38,
      child: ListView(
        scrollDirection: Axis.horizontal,
        children: [
          for (final c in _colors)
            GestureDetector(
              onTap: () => f(c),
              child: Container(
                width: 30,
                height: 30,
                margin: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: c,
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: c == cur ? Colors.cyanAccent : Colors.white24,
                    width: c == cur ? 3 : 1,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _sw(String t, bool v, ValueChanged<bool> f) {
    return Row(children: [
      Expanded(child: Text(t)),
      Switch(value: v, onChanged: f),
    ]);
  }

  Widget _label(String t) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 2),
        child: Text(t, style: const TextStyle(color: Colors.white60, fontSize: 12)),
      );

  // ── اللوحات ──
  Widget _textPanel() {
    final s = _sel;
    final l = s is TextLayer ? s : null;
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        FilledButton.icon(
          onPressed: _addText,
          icon: const Icon(Icons.add),
          label: const Text('إضافة نص جديد'),
        ),
        if (l == null)
          const Padding(
            padding: EdgeInsets.all(16),
            child: Text('اضغط على نص في الصورة لتعديله',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white54)),
          )
        else ...[
          const SizedBox(height: 8),
          TextField(
            controller: _tc,
            maxLines: null,
            decoration: const InputDecoration(
                border: OutlineInputBorder(), isDense: true, labelText: 'النص'),
            onChanged: (v) => setState(() => l.text = v),
          ),
          _label('الخط'),
          SizedBox(
            height: 46,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: [
                for (final f in _fonts)
                  Padding(
                    padding: const EdgeInsets.only(left: 6),
                    child: ChoiceChip(
                      label: Text(f, style: GoogleFonts.getFont(f)),
                      selected: l.font == f,
                      onSelected: (_) => setState(() => l.font = f),
                    ),
                  ),
              ],
            ),
          ),
          _label('اللون'),
          _pal(l.color, (c) => setState(() => l.color = c)),
          _sw('تدرج لوني', l.gradient, (v) => setState(() => l.gradient = v)),
          if (l.gradient) _pal(l.color2, (c) => setState(() => l.color2 = c)),
          _sl('الحجم', l.size, 14, 140, (v) => setState(() => l.size = v)),
          _sl('الشفافية', l.opacity, 0.1, 1, (v) => setState(() => l.opacity = v)),
          _sw('خط عريض', l.bold, (v) => setState(() => l.bold = v)),
          _sw('ظل', l.shadow, (v) => setState(() => l.shadow = v)),
          _sl('الحدود', l.strokeWidth, 0, 14, (v) => setState(() => l.strokeWidth = v)),
          if (l.strokeWidth > 0)
            _pal(l.strokeColor, (c) => setState(() => l.strokeColor = c)),
        ],
      ],
    );
  }

  Widget _stickerPanel() {
    return Column(children: [
      Padding(
        padding: const EdgeInsets.all(8),
        child: OutlinedButton.icon(
          onPressed: _addImage,
          icon: const Icon(Icons.add_photo_alternate),
          label: const Text('إضافة صورة / لوقو فوق الصورة'),
        ),
      ),
      Expanded(
        child: GridView.count(
          crossAxisCount: 8,
          padding: const EdgeInsets.symmetric(horizontal: 8),
          children: [
            for (final e in _emojis)
              InkWell(
                onTap: () => _add(EmojiLayer(e)),
                child: Center(child: Text(e, style: const TextStyle(fontSize: 26))),
              ),
          ],
        ),
      ),
    ]);
  }

  Widget _filtersPanel() {
    if (widget.bytes == null) {
      return const Center(child: Text('الفلاتر تعمل مع الصور فقط'));
    }
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        SizedBox(
          height: 112,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              for (final e in _presets.entries)
                GestureDetector(
                  onTap: () => setState(() => _preset = e.key),
                  child: Container(
                    width: 74,
                    margin: const EdgeInsets.only(left: 8),
                    child: Column(children: [
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(10),
                          child: Container(
                            foregroundDecoration: e.key == _preset
                                ? BoxDecoration(
                                    border: Border.all(
                                        color: Colors.cyanAccent, width: 3),
                                    borderRadius: BorderRadius.circular(10))
                                : null,
                            child: SizedBox.expand(
                              child: ColorFiltered(
                                colorFilter: ColorFilter.matrix(e.value),
                                child: Image.memory(widget.bytes!,
                                    fit: BoxFit.cover, cacheWidth: 150),
                              ),
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(e.key, style: const TextStyle(fontSize: 11)),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _adjustPanel() {
    return ListView(
      padding: const EdgeInsets.all(12),
      children: [
        if (widget.bytes == null) ...[
          _label('لون الخلفية'),
          _pal(_bg, (c) => setState(() => _bg = c)),
        ] else ...[
          _sl('السطوع', _brightness, -0.5, 0.5, (v) => setState(() => _brightness = v)),
          _sl('التباين', _contr, 0.5, 1.6, (v) => setState(() => _contr = v)),
          _sl('الإشباع', _saturation, 0, 2, (v) => setState(() => _saturation = v)),
          TextButton(
            onPressed: () => setState(() {
              _brightness = 0;
              _contr = 1;
              _saturation = 1;
              _preset = 'أصلي';
            }),
            child: const Text('إعادة الضبط'),
          ),
        ],
      ],
    );
  }

  Widget _layersPanel() {
    if (_layers.isEmpty) {
      return const Center(child: Text('ما فيه طبقات بعد'));
    }
    final rev = _layers.reversed.toList();
    return ListView(
      children: [
        for (final l in rev)
          ListTile(
            dense: true,
            selected: identical(l, _sel),
            leading: Icon(l is TextLayer
                ? Icons.title
                : l is EmojiLayer
                    ? Icons.emoji_emotions
                    : Icons.image),
            title: Text(l.label, maxLines: 1, overflow: TextOverflow.ellipsis),
            onTap: () => _select(l),
            trailing: Row(mainAxisSize: MainAxisSize.min, children: [
              IconButton(
                icon: const Icon(Icons.arrow_upward, size: 20),
                onPressed: () {
                  final i = _layers.indexOf(l);
                  if (i < _layers.length - 1) {
                    setState(() {
                      _layers.removeAt(i);
                      _layers.insert(i + 1, l);
                    });
                  }
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward, size: 20),
                onPressed: () {
                  final i = _layers.indexOf(l);
                  if (i > 0) {
                    setState(() {
                      _layers.removeAt(i);
                      _layers.insert(i - 1, l);
                    });
                  }
                },
              ),
              IconButton(
                icon: Icon(l.visible ? Icons.visibility : Icons.visibility_off,
                    size: 20),
                onPressed: () => setState(() => l.visible = !l.visible),
              ),
            ]),
          ),
      ],
    );
  }

  Widget _panel() {
    switch (_tab) {
      case 0:
        return _textPanel();
      case 1:
        return _stickerPanel();
      case 2:
        return _filtersPanel();
      case 3:
        return _adjustPanel();
      default:
        return _layersPanel();
    }
  }

  Widget _bottomBar() {
    const items = [
      (Icons.text_fields, 'نص'),
      (Icons.emoji_emotions_outlined, 'ملصقات'),
      (Icons.filter_vintage_outlined, 'فلاتر'),
      (Icons.tune, 'تعديل'),
      (Icons.layers_outlined, 'طبقات'),
    ];
    return SafeArea(
      top: false,
      child: Row(
        children: [
          for (var i = 0; i < items.length; i++)
            Expanded(
              child: InkWell(
                onTap: () => setState(() => _tab = _tab == i ? -1 : i),
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Icon(items[i].$1,
                        color: _tab == i ? Colors.cyanAccent : Colors.white70),
                    Text(items[i].$2,
                        style: TextStyle(
                            fontSize: 11,
                            color: _tab == i ? Colors.cyanAccent : Colors.white70)),
                  ]),
                ),
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        actions: [
          if (_sel != null) ...[
            IconButton(onPressed: _duplicate, icon: const Icon(Icons.copy)),
            IconButton(
                onPressed: _deleteSelected,
                icon: const Icon(Icons.delete_outline, color: Colors.redAccent)),
          ],
          IconButton(onPressed: _share, icon: const Icon(Icons.share)),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: FilledButton(onPressed: _save, child: const Text('حفظ')),
          ),
        ],
      ),
      body: Column(
        children: [
          Expanded(child: _canvasArea()),
          if (_tab >= 0)
            Container(
              height: 280,
              width: double.infinity,
              color: const Color(0xFF181822),
              child: _panel(),
            ),
          Container(color: const Color(0xFF12121A), child: _bottomBar()),
        ],
      ),
    );
  }
}
