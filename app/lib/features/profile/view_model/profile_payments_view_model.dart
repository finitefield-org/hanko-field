// ignore_for_file: public_member_api_docs

import 'package:app/features/checkout/view_model/checkout_flow_view_model.dart';
import 'package:app/features/payments/payment_method_form.dart';
import 'package:app/features/users/data/models/user_models.dart';
import 'package:app/features/users/data/repositories/local_user_repository.dart';
import 'package:app/localization/app_localizations.dart';
import 'package:app/shared/providers/app_locale_provider.dart';
import 'package:app/shared/providers/experience_gating_provider.dart';
import 'package:collection/collection.dart';
import 'package:logging/logging.dart';
import 'package:miniriverpod/miniriverpod.dart';

class ProfilePaymentsState {
  const ProfilePaymentsState({
    required this.methods,
    this.lastError,
    this.canAddMethods = false,
  });

  final List<PaymentMethod> methods;
  final String? lastError;
  final bool canAddMethods;

  PaymentMethod? get defaultMethod =>
      methods.firstWhereOrNull((item) => item.isDefault);

  ProfilePaymentsState copyWith({
    List<PaymentMethod>? methods,
    String? lastError,
    bool? canAddMethods,
    bool clearError = false,
  }) {
    return ProfilePaymentsState(
      methods: methods ?? this.methods,
      lastError: clearError ? null : (lastError ?? this.lastError),
      canAddMethods: canAddMethods ?? this.canAddMethods,
    );
  }
}

class PaymentSaveResult {
  const PaymentSaveResult({required this.validation, this.saved});

  final PaymentValidationResult validation;
  final PaymentMethod? saved;

  bool get isSuccess => validation.isValid && saved != null;
}

final _logger = Logger('ProfilePaymentsViewModel');

class ProfilePaymentsViewModel extends AsyncProvider<ProfilePaymentsState> {
  ProfilePaymentsViewModel() : super.args(null, autoDispose: true);

  late final setDefaultMut = mutation<void>(#setDefault);
  late final addPaymentMut = mutation<PaymentSaveResult>(#addPaymentMethod);
  late final deletePaymentMut = mutation<void>(#deletePaymentMethod);

  @override
  Future<ProfilePaymentsState> build(
    Ref<AsyncValue<ProfilePaymentsState>> ref,
  ) async {
    final repository = ref.watch(userRepositoryProvider);
    final gates = ref.watch(appExperienceGatesProvider);
    final methods = await repository.listPaymentMethods();
    return ProfilePaymentsState(
      methods: _sort(methods),
      canAddMethods: gates.isAuthenticated && !gates.isGuest,
    );
  }

  Call<void, AsyncValue<ProfilePaymentsState>> setDefault(String methodId) =>
      mutate(setDefaultMut, (ref) async {
        final current = ref.watch(this).valueOrNull;
        if (current == null) return;

        final previousDefaultId = current.defaultMethod?.id;
        final now = DateTime.now().toUtc();
        final next = current.methods.map((method) {
          final shouldDefault = method.id == methodId;
          if (method.isDefault == shouldDefault) return method;
          return method.copyWith(isDefault: shouldDefault, updatedAt: now);
        }).toList();
        ref.state = AsyncData(
          current.copyWith(methods: _sort(next), clearError: true),
        );

        final repository = ref.watch(userRepositoryProvider);
        final target = next.firstWhereOrNull((item) => item.id == methodId);
        if (target == null) return;
        await repository.updatePaymentMethod(target);

        final refreshed = _sort(await repository.listPaymentMethods());
        ref.state = AsyncData(
          current.copyWith(methods: refreshed, clearError: true),
        );

        await _syncCheckoutDefaultIfNeeded(
          ref,
          previousDefaultId: previousDefaultId,
          newDefaultId: methodId,
        );
      }, concurrency: Concurrency.dropLatest);

  Call<PaymentSaveResult, AsyncValue<ProfilePaymentsState>> addPaymentMethod(
    PaymentMethodDraft draft,
  ) => mutate(addPaymentMut, (ref) async {
    final l10n = AppLocalizations(ref.watch(appLocaleProvider));
    final validation = validatePaymentDraft(draft, l10n);
    final current = ref.watch(this).valueOrNull;

    if (!validation.isValid) {
      if (current != null) {
        ref.state = AsyncData(current.copyWith(lastError: validation.message));
      }
      return PaymentSaveResult(validation: validation);
    }

    final repository = ref.watch(userRepositoryProvider);
    final now = DateTime.now().toUtc();
    final hasDefault = (current?.methods ?? const []).any(
      (item) => item.isDefault,
    );
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
      isDefault: !hasDefault,
      createdAt: now,
      updatedAt: now,
    );

    try {
      final saved = await repository.addPaymentMethod(method);
      final refreshed = _sort(await repository.listPaymentMethods());
      ref.state = AsyncData(
        current?.copyWith(methods: refreshed, clearError: true) ??
            ProfilePaymentsState(
              methods: refreshed,
              canAddMethods: current?.canAddMethods ?? true,
            ),
      );

      await _syncCheckoutAfterAdd(ref, saved);
      return PaymentSaveResult(validation: validation, saved: saved);
    } catch (e, stack) {
      _logger.warning('Failed to add payment method', e, stack);
      final message = l10n.paymentMethodAddFailed;
      if (current != null) {
        ref.state = AsyncData(current.copyWith(lastError: message));
      }
      return PaymentSaveResult(
        validation: PaymentValidationResult(message: message),
      );
    }
  }, concurrency: Concurrency.queue);

  Call<void, AsyncValue<ProfilePaymentsState>> deletePaymentMethod(
    String methodId,
  ) => mutate(deletePaymentMut, (ref) async {
    final current = ref.watch(this).valueOrNull;
    if (current != null) {
      final wasDefault = current.defaultMethod?.id == methodId;
      final next = current.methods
          .where((item) => item.id != methodId)
          .toList();
      if (wasDefault &&
          next.isNotEmpty &&
          next.every((item) => !item.isDefault)) {
        final promoted = next.first.copyWith(
          isDefault: true,
          updatedAt: DateTime.now().toUtc(),
        );
        next
          ..removeAt(0)
          ..insert(0, promoted);
      }
      ref.state = AsyncData(current.copyWith(methods: _sort(next)));
    }

    final repository = ref.watch(userRepositoryProvider);
    await repository.removePaymentMethod(methodId);

    var refreshed = _sort(await repository.listPaymentMethods());
    if (refreshed.isNotEmpty && refreshed.every((item) => !item.isDefault)) {
      final fallback = refreshed.first;
      await repository.updatePaymentMethod(
        fallback.copyWith(isDefault: true, updatedAt: DateTime.now().toUtc()),
      );
      refreshed = _sort(await repository.listPaymentMethods());
    }

    ref.state = AsyncData(
      current?.copyWith(methods: refreshed, clearError: true) ??
          ProfilePaymentsState(
            methods: refreshed,
            canAddMethods: current?.canAddMethods ?? true,
          ),
    );

    await _syncCheckoutAfterDelete(
      ref,
      deletedId: methodId,
      methods: refreshed,
    );
  }, concurrency: Concurrency.queue);

  Future<void> _syncCheckoutDefaultIfNeeded(
    Ref<AsyncValue<ProfilePaymentsState>> ref, {
    required String? previousDefaultId,
    required String newDefaultId,
  }) async {
    final flow = ref.watch(checkoutFlowProvider);
    final currentPaymentId = flow.paymentMethodId;
    if (currentPaymentId != null && currentPaymentId != previousDefaultId) {
      return;
    }

    final state = ref.watch(this).valueOrNull;
    final defaultMethod = state?.methods.firstWhereOrNull(
      (item) => item.id == newDefaultId,
    );
    if (defaultMethod == null) return;

    try {
      await ref.invoke(
        checkoutFlowProvider.setPayment(
          paymentMethodId: defaultMethod.id,
          paymentProviderRef: defaultMethod.providerRef,
        ),
      );
    } catch (e, stack) {
      _logger.warning('Failed to sync checkout payment', e, stack);
    }
  }

  Future<void> _syncCheckoutAfterAdd(
    Ref<AsyncValue<ProfilePaymentsState>> ref,
    PaymentMethod method,
  ) async {
    final flow = ref.watch(checkoutFlowProvider);
    if (flow.paymentMethodId != null || !method.isDefault) return;

    try {
      await ref.invoke(
        checkoutFlowProvider.setPayment(
          paymentMethodId: method.id,
          paymentProviderRef: method.providerRef,
        ),
      );
    } catch (e, stack) {
      _logger.warning('Failed to sync checkout payment after add', e, stack);
    }
  }

  Future<void> _syncCheckoutAfterDelete(
    Ref<AsyncValue<ProfilePaymentsState>> ref, {
    required String deletedId,
    required List<PaymentMethod> methods,
  }) async {
    final flow = ref.watch(checkoutFlowProvider);
    if (flow.paymentMethodId != deletedId) return;

    final defaultMethod = methods.firstWhereOrNull((item) => item.isDefault);
    try {
      await ref.invoke(
        checkoutFlowProvider.setPayment(
          paymentMethodId: defaultMethod?.id,
          paymentProviderRef: defaultMethod?.providerRef,
        ),
      );
    } catch (e, stack) {
      _logger.warning('Failed to sync checkout after delete', e, stack);
    }
  }

  List<PaymentMethod> _sort(List<PaymentMethod> methods) {
    final sorted = [...methods];
    sorted.sort((a, b) {
      if (a.isDefault != b.isDefault) {
        return a.isDefault ? -1 : 1;
      }
      final aUpdated = a.updatedAt ?? a.createdAt;
      final bUpdated = b.updatedAt ?? b.createdAt;
      return bUpdated.compareTo(aUpdated);
    });
    return sorted;
  }
}

final profilePaymentsViewModel = ProfilePaymentsViewModel();
