import 'cal_event_source.dart';

/// A calendar the user can show/hide (virtual for manual/extension; real for Google).
class CalSource {
  const CalSource({
    required this.id,
    required this.name,
    required this.color,
    required this.source,
    this.visible = true,
    this.primary = false,
  });

  final String id;
  final String name;
  final String color;
  final CalEventSource source;
  final bool visible;
  final bool primary;

  CalSource copyWith({bool? visible}) {
    return CalSource(
      id: id,
      name: name,
      color: color,
      source: source,
      visible: visible ?? this.visible,
      primary: primary,
    );
  }

  static const manual = CalSource(
    id: 'manual',
    name: 'Manual',
    color: '#2563EB',
    source: CalEventSource.manual,
    primary: true,
  );

  static const extension = CalSource(
    id: 'extension',
    name: 'Extension',
    color: '#7C3AED',
    source: CalEventSource.extension,
  );
}
