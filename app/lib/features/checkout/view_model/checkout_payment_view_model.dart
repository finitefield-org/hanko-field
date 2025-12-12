// ignore_for_file: public_member_api_docs

import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class PaymentMethodDraft {
  const PaymentMethodDraft({
    this.provider = PaymentProvider.stripe,
    this.methodType = PaymentMethodType.card,
    this.brand,
    this.last4,
    this.expMonth,
    this.expYear,
    this.billingName,
  });

  final PaymentProvider provider;
  final PaymentMethodType methodType;
  final String? brand;
  final String? last4;
  final int? expMonth;
  final int? expYear;
  final String? billingName;
}

class PaymentValidationResult {
  const PaymentValidationResult({this.fieldErrors = const {}, this.message});

  final Map<String, String> fieldErrors;
  final String? message;

  bool get isValid => fieldErrors.isEmpty && message == null;
}

class PaymentSaveResult {
  const PaymentSaveResult({required this.validation, this.saved});

  final PaymentValidationResult validation;
  final PaymentMethod? saved;

  bool get isSuccess => validation.isValid && saved != null;
}

class CheckoutPaymentState {
  const CheckoutPaymentState({
    required this.methods,
    this.selectedId,
    this.lastError,
    this.canAddMethods = false,
  });

  final List<PaymentMethod> methods;
  final String? selectedId;
  final String? lastError;
  final bool canAddMethods;

  PaymentMethod? get selectedMethod {
    final id = selectedId;
    if (id != null) {
      return methods.firstWhereOrNull((item) => item.id == id);
    }
    return methods.firstOrNull;
  }

  CheckoutPaymentState copyWith({
    List<PaymentMethod>? methods,
    String? selectedId,
    String? lastError,
    bool? canAddMethods,
    bool clearError = false,
  }) {
    return CheckoutPaymentState(
      methods: methods ?? this.methods,
      selectedId: selectedId ?? this.selectedId,
      lastError: clearError ? null : (lastError ?? this.lastError),
      canAddMethods: canAddMethods ?? this.canAddMethods,
    );
  }
}

final _paymentLogger = Logger('CheckoutPaymentViewModel');

class CheckoutPaymentViewModel extends AsyncProvider<CheckoutPaymentState> {
  CheckoutPaymentViewModel() : super.args(null, autoDispose: true);

  late final selectPaymentMut = mutation<String?>(#selectPayment);
  late final addPaymentMut = mutation<PaymentSaveResult>(#addPaymentMethod);

  @override
  Future<CheckoutPaymentState> build(Ref ref) async {
    final repository = ref.watch(userRepositoryProvider);
    final flow = ref.watch(checkoutFlowProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final methods = await repository.listPaymentMethods();
    final sorted = _sort(methods);
    final flowId = flow.paymentMethodId;
    final selectedId =
        (flowId != null && sorted.any((item) => item.id == flowId))
        ? flowId
        : sorted.firstOrNull?.id;

    return CheckoutPaymentState(
      methods: sorted,
      selectedId: selectedId,
      canAddMethods: gates.isAuthenticated && !gates.isGuest,
    );
  }

  Call<String?> selectPayment(String? methodId) =>
      mutate(selectPaymentMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return methodId;
        final selection =
            current.methods.firstWhereOrNull((item) => item.id == methodId) ??
            current.selectedMethod;
        ref.state = AsyncData(
          current.copyWith(selectedId: methodId, clearError: true),
        );
        if (selection != null) {
          await ref.invoke(
            checkoutFlowProvider.setPayment(
              paymentMethodId: selection.id,
              paymentProviderRef: selection.providerRef,
            ),
          );
        }
        return methodId;
      }, concurrency: Concurrency.dropLatest);

  Call<PaymentSaveResult> addPaymentMethod(PaymentMethodDraft draft) =>
      mutate(addPaymentMut, (ref) async {
        final gates = ref.watch(appExperienceGatesProvider);
        final prefersEnglish = gates.prefersEnglish;
        final validation = _validateDraft(draft, prefersEnglish);
        final current = ref.watch(this).valueOrNull;

        if (!validation.isValid) {
          if (current != null) {
            ref.state = AsyncData(
              current.copyWith(lastError: validation.message),
            );
          }
          return PaymentSaveResult(validation: validation);
        }

        final repository = ref.watch(userRepositoryProvider);
        final now = DateTime.now().toUtc();
        final method = PaymentMethod(
          id: null,
          provider: draft.provider,
          methodType: draft.methodType,
          brand: draft.brand,
          last4: draft.last4,
          expMonth: draft.expMonth,
          expYear: draft.expYear,
          billingName: draft.billingName,
          providerRef: 'tok_${now.microsecondsSinceEpoch}',
          createdAt: now,
          updatedAt: now,
        );

        try {
          final saved = await repository.addPaymentMethod(method);
          final next = _sort([saved, ...(current?.methods ?? const [])]);
          ref.state = AsyncData(
            current?.copyWith(
                  methods: next,
                  selectedId: saved.id,
                  clearError: true,
                ) ??
                CheckoutPaymentState(
                  methods: next,
                  selectedId: saved.id,
                  canAddMethods: current?.canAddMethods ?? true,
                ),
          );
          await ref.invoke(
            checkoutFlowProvider.setPayment(
              paymentMethodId: saved.id,
              paymentProviderRef: saved.providerRef,
            ),
          );
          return PaymentSaveResult(validation: validation, saved: saved);
        } catch (e, stack) {
          _paymentLogger.warning('Failed to add payment method', e, stack);
          final message = prefersEnglish
              ? 'Could not add payment method'
              : '支払い方法を追加できません';
          if (current != null) {
            ref.state = AsyncData(current.copyWith(lastError: message));
          }
          return PaymentSaveResult(
            validation: PaymentValidationResult(message: message),
          );
        }
      }, concurrency: Concurrency.queue);

  List<PaymentMethod> _sort(List<PaymentMethod> methods) {
    final sorted = [...methods];
    sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return sorted;
  }

  PaymentValidationResult _validateDraft(
    PaymentMethodDraft draft,
    bool prefersEnglish,
  ) {
    final errors = <String, String>{};
    final last4 = draft.last4?.trim();
    if (draft.methodType == PaymentMethodType.card) {
      if (last4 == null || last4.length != 4) {
        errors['last4'] = prefersEnglish
            ? 'Enter last 4 digits'
            : '下4桁を入力してください';
      }
      if (draft.expMonth == null ||
          draft.expMonth! < 1 ||
          draft.expMonth! > 12) {
        errors['expMonth'] = prefersEnglish
            ? 'Enter expiry month'
            : '有効期限(月)を入力してください';
      }
      if (draft.expYear == null || draft.expYear! < DateTime.now().year) {
        errors['expYear'] = prefersEnglish
            ? 'Enter expiry year'
            : '有効期限(年)を入力してください';
      }
    }

    return PaymentValidationResult(
      fieldErrors: errors,
      message: errors.isEmpty
          ? null
          : (prefersEnglish ? 'Fix the highlighted fields' : '入力内容を確認してください'),
    );
  }
}

final checkoutPaymentViewModel = CheckoutPaymentViewModel();
