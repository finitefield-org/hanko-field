import '../../../core/domain/money.dart';

class OrderDraft {
  OrderDraft({
    required this.sealSelection,
    required this.stoneSelection,
    required this.input,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  factory OrderDraft.empty({DateTime? updatedAt}) {
    return OrderDraft(
      sealSelection: null,
      stoneSelection: null,
      input: const OrderDraftInput.empty(),
      updatedAt: updatedAt,
    );
  }

  final OrderDraftSealSelection? sealSelection;
  final OrderDraftStoneSelection? stoneSelection;
  final OrderDraftInput input;
  final DateTime updatedAt;

  bool get hasSealSelection => sealSelection != null;
  bool get hasStoneSelection => stoneSelection != null;
  bool get hasCombinationSelections => hasSealSelection && hasStoneSelection;

  OrderDraft withSealSelection(
    OrderDraftSealSelection selection, {
    DateTime? updatedAt,
  }) {
    return OrderDraft(
      sealSelection: selection,
      stoneSelection: stoneSelection,
      input: input,
      updatedAt: updatedAt,
    );
  }

  OrderDraft withoutSealSelection({DateTime? updatedAt}) {
    return OrderDraft(
      sealSelection: null,
      stoneSelection: stoneSelection,
      input: input,
      updatedAt: updatedAt,
    );
  }

  OrderDraft withStoneSelection(
    OrderDraftStoneSelection selection, {
    DateTime? updatedAt,
  }) {
    return OrderDraft(
      sealSelection: sealSelection,
      stoneSelection: selection,
      input: input,
      updatedAt: updatedAt,
    );
  }

  OrderDraft withoutStoneSelection({DateTime? updatedAt}) {
    return OrderDraft(
      sealSelection: sealSelection,
      stoneSelection: null,
      input: input,
      updatedAt: updatedAt,
    );
  }

  OrderDraft withInput(OrderDraftInput input, {DateTime? updatedAt}) {
    return OrderDraft(
      sealSelection: sealSelection,
      stoneSelection: stoneSelection,
      input: input,
      updatedAt: updatedAt,
    );
  }
}

class OrderDraftSealSelection {
  const OrderDraftSealSelection({
    required this.localSealDesignId,
    required this.selectedKanji,
    required this.reading,
    required this.shape,
    required this.style,
    required this.strokeWeight,
    required this.balance,
    required this.aiGenerationId,
    required this.aiVariantId,
    required this.previewImageStoragePath,
    required this.previewImageDownloadUrl,
    required this.localImagePath,
  });

  final String localSealDesignId;
  final String selectedKanji;
  final String reading;
  final String shape;
  final String style;
  final String strokeWeight;
  final String balance;
  final String aiGenerationId;
  final String aiVariantId;
  final String previewImageStoragePath;
  final String previewImageDownloadUrl;
  final String localImagePath;
}

class OrderDraftStoneSelection {
  const OrderDraftStoneSelection({
    required this.listingId,
    required this.code,
    required this.materialKey,
    required this.materialLabel,
    required this.sizeLabel,
    required this.title,
    required this.price,
    required this.status,
    required this.isOrderable,
    required this.primaryPhotoUrl,
  });

  final String listingId;
  final String code;
  final String materialKey;
  final String materialLabel;
  final String sizeLabel;
  final String title;
  final Money price;
  final String status;
  final bool isOrderable;
  final String primaryPhotoUrl;
}

class OrderDraftInput {
  const OrderDraftInput({
    required this.contact,
    required this.shipping,
    required this.orderNote,
    required this.termsAgreed,
  });

  const OrderDraftInput.empty()
    : contact = const OrderDraftContactInput.empty(),
      shipping = const OrderDraftShippingInput.empty(),
      orderNote = '',
      termsAgreed = false;

  final OrderDraftContactInput contact;
  final OrderDraftShippingInput shipping;
  final String orderNote;
  final bool termsAgreed;

  OrderDraftInput copyWith({
    OrderDraftContactInput? contact,
    OrderDraftShippingInput? shipping,
    String? orderNote,
    bool? termsAgreed,
  }) {
    return OrderDraftInput(
      contact: contact ?? this.contact,
      shipping: shipping ?? this.shipping,
      orderNote: orderNote ?? this.orderNote,
      termsAgreed: termsAgreed ?? this.termsAgreed,
    );
  }
}

class OrderDraftContactInput {
  const OrderDraftContactInput({
    required this.email,
    required this.preferredLocale,
  });

  const OrderDraftContactInput.empty() : email = '', preferredLocale = '';

  final String email;
  final String preferredLocale;

  OrderDraftContactInput copyWith({String? email, String? preferredLocale}) {
    return OrderDraftContactInput(
      email: email ?? this.email,
      preferredLocale: preferredLocale ?? this.preferredLocale,
    );
  }
}

class OrderDraftShippingInput {
  const OrderDraftShippingInput({
    required this.countryCode,
    required this.recipientName,
    required this.phone,
    required this.postalCode,
    required this.state,
    required this.city,
    required this.addressLine1,
    required this.addressLine2,
  });

  const OrderDraftShippingInput.empty()
    : countryCode = '',
      recipientName = '',
      phone = '',
      postalCode = '',
      state = '',
      city = '',
      addressLine1 = '',
      addressLine2 = '';

  final String countryCode;
  final String recipientName;
  final String phone;
  final String postalCode;
  final String state;
  final String city;
  final String addressLine1;
  final String addressLine2;

  OrderDraftShippingInput copyWith({
    String? countryCode,
    String? recipientName,
    String? phone,
    String? postalCode,
    String? state,
    String? city,
    String? addressLine1,
    String? addressLine2,
  }) {
    return OrderDraftShippingInput(
      countryCode: countryCode ?? this.countryCode,
      recipientName: recipientName ?? this.recipientName,
      phone: phone ?? this.phone,
      postalCode: postalCode ?? this.postalCode,
      state: state ?? this.state,
      city: city ?? this.city,
      addressLine1: addressLine1 ?? this.addressLine1,
      addressLine2: addressLine2 ?? this.addressLine2,
    );
  }
}
