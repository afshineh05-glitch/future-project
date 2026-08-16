import 'package:flutter/material.dart';

class SmartBodyMap extends StatelessWidget {
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;

  const SmartBodyMap({
    super.key,
    required this.primaryMuscles,
    required this.secondaryMuscles,
  });

  static const Color _primary = Color(0xFF0B7A53);
  static const Color _secondary = Color(0xFF91C97B);
  static const Color _muted = Color(0xFFDCE2E6);
  static const Color _text = Color(0xFF182234);
  static const Color _subtext = Color(0xFF687386);
  static const Color _border = Color(0xFFE5EAED);

  static const Map<String, String> _labels = <String, String>{
    'chest': 'Chest',
    'front_delts': 'Front Delts',
    'side_delts': 'Side Delts',
    'rear_delts': 'Rear Delts',
    'biceps': 'Biceps',
    'triceps': 'Triceps',
    'forearms': 'Forearms',
    'lats': 'Lats',
    'upper_back': 'Upper Back',
    'traps': 'Traps',
    'lower_back': 'Lower Back',
    'core': 'Core',
    'obliques': 'Obliques',
    'glutes': 'Glutes',
    'quads': 'Quads',
    'hamstrings': 'Hamstrings',
    'adductors': 'Adductors',
    'hip_flexors': 'Hip Flexors',
    'calves': 'Calves',
  };

  static String _canonical(String raw) {
    String value = raw.trim().toLowerCase().replaceAll('-', '_').replaceAll(' ', '_');

    const Map<String, String> aliases = <String, String>{
      'quadriceps': 'quads',
      'quad': 'quads',
      'glute': 'glutes',
      'hamstring': 'hamstrings',
      'front_delt': 'front_delts',
      'side_delt': 'side_delts',
      'rear_delt': 'rear_delts',
      'lowerback': 'lower_back',
      'upperback': 'upper_back',
      'hip_flexor': 'hip_flexors',
      'calf': 'calves',
      'abs': 'core',
    };

    return aliases[value] ?? value;
  }

  static List<String> _clean(List<String> values) {
    final Set<String> seen = <String>{};
    return values
        .map(_canonical)
        .where((String value) => value.isNotEmpty && seen.add(value))
        .toList();
  }

  static String _label(String id) {
    return _labels[id] ??
        id
            .split('_')
            .map((String part) =>
                part.isEmpty ? part : '${part[0].toUpperCase()}${part.substring(1)}')
            .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    final List<String> primary = _clean(primaryMuscles);
    final List<String> secondary = _clean(secondaryMuscles)
        .where((String id) => !primary.contains(id))
        .toList();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _border),
        boxShadow: const <BoxShadow>[
          BoxShadow(
            color: Color(0x09000000),
            blurRadius: 18,
            offset: Offset(0, 7),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              const Icon(
                Icons.my_location_rounded,
                color: _primary,
                size: 24,
              ),
              const SizedBox(width: 9),
              const Text(
                'Target Muscles',
                style: TextStyle(
                  color: _text,
                  fontSize: 18,
                  fontWeight: FontWeight.w800,
                ),
              ),
              const Spacer(),
              const _LegendDot(color: _primary, label: 'Primary'),
              const SizedBox(width: 14),
              const _LegendDot(color: _secondary, label: 'Secondary'),
            ],
          ),
          const SizedBox(height: 20),
          LayoutBuilder(
            builder: (BuildContext context, BoxConstraints constraints) {
              final bool compact = constraints.maxWidth < 560;

              final Widget figures = Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(
                    child: _AnatomyFigure(
                      title: 'Front',
                      side: _BodySide.front,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: _AnatomyFigure(
                      title: 'Back',
                      side: _BodySide.back,
                      primary: primary,
                      secondary: secondary,
                    ),
                  ),
                ],
              );

              final Widget muscleInfo = _MuscleInfo(
                primary: primary,
                secondary: secondary,
              );

              if (compact) {
                return Column(
                  children: <Widget>[
                    figures,
                    const SizedBox(height: 20),
                    muscleInfo,
                  ],
                );
              }

              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Expanded(flex: 3, child: figures),
                  const SizedBox(width: 24),
                  Expanded(flex: 2, child: muscleInfo),
                ],
              );
            },
          ),
          const SizedBox(height: 18),
          const Divider(height: 1, color: _border),
          const SizedBox(height: 14),
          const Wrap(
            spacing: 22,
            runSpacing: 8,
            children: <Widget>[
              Text(
                'Muscle Activation Intensity',
                style: TextStyle(
                  color: _text,
                  fontSize: 12.5,
                  fontWeight: FontWeight.w800,
                ),
              ),
              _LegendDot(color: _primary, label: 'Primary (High)'),
              _LegendDot(color: _secondary, label: 'Secondary (Medium)'),
              _LegendDot(color: _muted, label: 'Minimal (Low)'),
            ],
          ),
        ],
      ),
    );
  }
}

enum _BodySide { front, back }

class _AnatomyFigure extends StatelessWidget {
  final String title;
  final _BodySide side;
  final List<String> primary;
  final List<String> secondary;

  const _AnatomyFigure({
    required this.title,
    required this.side,
    required this.primary,
    required this.secondary,
  });

  String get _suffix => side == _BodySide.front ? 'front' : 'back';

  bool _hasAsset(String id) {
    const Set<String> front = <String>{
      'chest','front_delts','side_delts','biceps','forearms','core',
      'obliques','quads','adductors','hip_flexors','calves',
    };
    const Set<String> back = <String>{
      'rear_delts','triceps','forearms','traps','upper_back','lats',
      'lower_back','glutes','hamstrings','calves','core','obliques',
    };
    return side == _BodySide.front ? front.contains(id) : back.contains(id);
  }

  Widget _layer(
    String id,
    Color color, {
    required double opacity,
  }) {
    return Positioned.fill(
      child: IgnorePointer(
        child: Opacity(
          opacity: opacity,
          child: ColorFiltered(
            // Multiply preserves the anatomical shading underneath instead of
            // painting a flat sticker-like color over the body.
            colorFilter: ColorFilter.mode(
              color,
              BlendMode.modulate,
            ),
            child: Image.asset(
              'assets/anatomy/${id}_$_suffix.png',
              fit: BoxFit.contain,
              filterQuality: FilterQuality.high,
              isAntiAlias: true,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: <Widget>[
        Text(
          title,
          style: const TextStyle(
            color: SmartBodyMap._subtext,
            fontSize: 12,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 8),
        Container(
          padding: const EdgeInsets.symmetric(
            horizontal: 10,
            vertical: 8,
          ),
          decoration: BoxDecoration(
            color: const Color(0xFFFBFCFC),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: const Color(0xFFF0F2F3),
            ),
          ),
          child: AspectRatio(
            aspectRatio: 0.47,
            child: Stack(
              fit: StackFit.expand,
              children: <Widget>[
                Image.asset(
                  'assets/anatomy/male_$_suffix.png',
                  fit: BoxFit.contain,
                  filterQuality: FilterQuality.high,
                  isAntiAlias: true,
                ),
                ...secondary.where(_hasAsset).map(
                      (String id) => _layer(
                        id,
                        SmartBodyMap._secondary,
                        opacity: 0.50,
                      ),
                    ),
                ...primary.where(_hasAsset).map(
                      (String id) => _layer(
                        id,
                        SmartBodyMap._primary,
                        opacity: 0.74,
                      ),
                    ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _MuscleInfo extends StatelessWidget {
  final List<String> primary;
  final List<String> secondary;

  const _MuscleInfo({
    required this.primary,
    required this.secondary,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        const Text(
          'Primary Muscles',
          style: TextStyle(
            color: SmartBodyMap._text,
            fontSize: 13,
            fontWeight: FontWeight.w800,
          ),
        ),
        const SizedBox(height: 9),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: primary
              .map<Widget>(
                (String id) => _MusclePill(
                  label: SmartBodyMap._label(id),
                  color: SmartBodyMap._primary,
                  fill: const Color(0xFFF3F8F5),
                ),
              )
              .toList(),
        ),
        if (secondary.isNotEmpty) ...<Widget>[
          const SizedBox(height: 18),
          const Text(
            'Secondary Muscles',
            style: TextStyle(
              color: SmartBodyMap._text,
              fontSize: 13,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: secondary
                .map<Widget>(
                  (String id) => _MusclePill(
                    label: SmartBodyMap._label(id),
                    color: const Color(0xFF5D943C),
                    fill: const Color(0xFFF5F9F2),
                  ),
                )
                .toList(),
          ),
        ],
      ],
    );
  }
}

class _MusclePill extends StatelessWidget {
  final String label;
  final Color color;
  final Color fill;

  const _MusclePill({
    required this.label,
    required this.color,
    required this.fill,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: fill,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.22)),
      ),
      child: Text(
        label,
        style: TextStyle(
          color: color,
          fontSize: 12.5,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _LegendDot extends StatelessWidget {
  final Color color;
  final String label;

  const _LegendDot({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        Container(
          width: 10,
          height: 10,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style: const TextStyle(
            color: SmartBodyMap._subtext,
            fontSize: 11.5,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
