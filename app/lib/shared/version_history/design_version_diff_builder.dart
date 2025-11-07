import 'package:app/core/domain/entities/design.dart';
import 'package:app/shared/version_history/design_version_history_state.dart';

List<DesignVersionDiffEntry> buildVersionDiffEntries({
  required DesignVersion current,
  required DesignVersion compared,
}) {
  String formatDouble(double? value) {
    if (value == null) {
      return '—';
    }
    return value.toStringAsFixed(value.truncateToDouble() == value ? 0 : 1);
  }

  String formatInput(Design design) {
    return design.input?.kanji?.value ?? design.input?.rawName ?? '—';
  }

  String formatDate(DateTime value) {
    return '${value.year}-${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')} '
        '${value.hour.toString().padLeft(2, '0')}:'
        '${value.minute.toString().padLeft(2, '0')}';
  }

  String formatTemplate(Design design) {
    final template = design.style.templateRef ?? '—';
    final font = design.style.fontRef ?? '—';
    return '$template · $font';
  }

  return <DesignVersionDiffEntry>[
    DesignVersionDiffEntry(
      label: 'Version',
      currentValue: 'v${current.version}',
      comparedValue: 'v${compared.version}',
    ),
    DesignVersionDiffEntry(
      label: 'Updated',
      currentValue: formatDate(current.snapshot.updatedAt),
      comparedValue: formatDate(compared.snapshot.updatedAt),
    ),
    DesignVersionDiffEntry(
      label: 'Shape',
      currentValue: current.snapshot.shape.name,
      comparedValue: compared.snapshot.shape.name,
    ),
    DesignVersionDiffEntry(
      label: 'Writing Style',
      currentValue: current.snapshot.style.writing.name,
      comparedValue: compared.snapshot.style.writing.name,
    ),
    DesignVersionDiffEntry(
      label: 'Template · Font',
      currentValue: formatTemplate(current.snapshot),
      comparedValue: formatTemplate(compared.snapshot),
    ),
    DesignVersionDiffEntry(
      label: 'Stroke Weight',
      currentValue: formatDouble(current.snapshot.style.stroke?.weight),
      comparedValue: formatDouble(compared.snapshot.style.stroke?.weight),
    ),
    DesignVersionDiffEntry(
      label: 'Margin (mm)',
      currentValue: formatDouble(current.snapshot.style.layout?.margin),
      comparedValue: formatDouble(compared.snapshot.style.layout?.margin),
    ),
    DesignVersionDiffEntry(
      label: 'Rotation (°)',
      currentValue: formatDouble(current.snapshot.style.layout?.rotation),
      comparedValue: formatDouble(compared.snapshot.style.layout?.rotation),
    ),
    DesignVersionDiffEntry(
      label: 'Alignment',
      currentValue: current.snapshot.style.layout?.alignment?.name ?? 'center',
      comparedValue:
          compared.snapshot.style.layout?.alignment?.name ?? 'center',
    ),
    DesignVersionDiffEntry(
      label: 'Grid',
      currentValue: current.snapshot.style.layout?.grid ?? '—',
      comparedValue: compared.snapshot.style.layout?.grid ?? '—',
    ),
    DesignVersionDiffEntry(
      label: 'Input Text',
      currentValue: formatInput(current.snapshot),
      comparedValue: formatInput(compared.snapshot),
    ),
  ];
}
