enum CervicalMucusType {
  dryOrNone,
  sticky,
  creamy,
  watery,
  clearSlipperyStretchy,
  unsure,
}

extension CervicalMucusTypeLabel on CervicalMucusType {
  String get label {
    switch (this) {
      case CervicalMucusType.dryOrNone:
        return 'Dry or none';
      case CervicalMucusType.sticky:
        return 'Sticky';
      case CervicalMucusType.creamy:
        return 'Creamy';
      case CervicalMucusType.watery:
        return 'Watery';
      case CervicalMucusType.clearSlipperyStretchy:
        return 'Clear, slippery or stretchy';
      case CervicalMucusType.unsure:
        return 'Unsure';
    }
  }

  bool get isFertileQuality {
    return this == CervicalMucusType.watery ||
        this == CervicalMucusType.clearSlipperyStretchy;
  }
}

class CervicalMucusEntry {
  final DateTime date;
  final CervicalMucusType type;
  final String? notes;

  const CervicalMucusEntry({
    required this.date,
    required this.type,
    this.notes,
  });
}
