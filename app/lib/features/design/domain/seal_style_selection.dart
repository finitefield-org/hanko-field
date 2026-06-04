class SealStyleSelection {
  const SealStyleSelection({
    this.shape = SealShape.square,
    this.style = SealStyleName.elegant,
    this.strokeWeight = SealStrokeWeight.standard,
    this.balance = SealBalance.balanced,
  });

  final SealShape shape;
  final SealStyleName style;
  final SealStrokeWeight strokeWeight;
  final SealBalance balance;

  SealStyleSelection copyWith({
    SealShape? shape,
    SealStyleName? style,
    SealStrokeWeight? strokeWeight,
    SealBalance? balance,
  }) {
    return SealStyleSelection(
      shape: shape ?? this.shape,
      style: style ?? this.style,
      strokeWeight: strokeWeight ?? this.strokeWeight,
      balance: balance ?? this.balance,
    );
  }
}

enum SealShape {
  square,
  round;

  String get apiValue => name;
}

enum SealStyleName {
  traditional,
  elegant,
  soft,
  bold;

  String get apiValue => name;
}

enum SealStrokeWeight {
  standard,
  bold;

  String get apiValue => name;
}

enum SealBalance {
  airy,
  balanced,
  dense;

  String get apiValue => name;
}
