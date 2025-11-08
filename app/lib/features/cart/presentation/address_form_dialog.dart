import 'package:app/core/app_state/experience_gating.dart';
import 'package:app/core/domain/entities/user.dart';
import 'package:app/core/theme/tokens.dart';
import 'package:app/core/ui/widgets/app_text_field.dart';
import 'package:app/features/cart/application/checkout_address_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

enum AddressFormMode { domestic, international }

enum AddressFormPresentation { fullscreen, dialog }

class AddressFormDialog extends ConsumerStatefulWidget {
  const AddressFormDialog({
    this.initialAddress,
    this.experience,
    this.presentation = AddressFormPresentation.fullscreen,
    super.key,
  });

  final UserAddress? initialAddress;
  final ExperienceGate? experience;
  final AddressFormPresentation presentation;

  @override
  ConsumerState<AddressFormDialog> createState() => _AddressFormDialogState();
}

class _AddressFormDialogState extends ConsumerState<AddressFormDialog> {
  late final TextEditingController _labelController;
  late final TextEditingController _recipientController;
  late final TextEditingController _companyController;
  late final TextEditingController _postalController;
  late final TextEditingController _stateController;
  late final TextEditingController _cityController;
  late final TextEditingController _line1Controller;
  late final TextEditingController _line2Controller;
  late final TextEditingController _countryController;
  late final TextEditingController _phoneController;
  late AddressFormMode _mode;
  final _formKey = GlobalKey<FormState>();
  bool _submitting = false;

  CheckoutAddressController get _controller =>
      ref.read(checkoutAddressControllerProvider.notifier);

  ExperienceGate? get _experience => widget.experience;

  bool get _isEditing => widget.initialAddress != null;

  @override
  void initState() {
    super.initState();
    _labelController = TextEditingController();
    _recipientController = TextEditingController();
    _companyController = TextEditingController();
    _postalController = TextEditingController();
    _stateController = TextEditingController();
    _cityController = TextEditingController();
    _line1Controller = TextEditingController();
    _line2Controller = TextEditingController();
    _countryController = TextEditingController();
    _phoneController = TextEditingController();

    final initial = widget.initialAddress;
    if (initial != null) {
      _mode = initial.country.toUpperCase() == 'JP'
          ? AddressFormMode.domestic
          : AddressFormMode.international;
      _labelController.text = initial.label ?? '';
      _recipientController.text = initial.recipient;
      _companyController.text = initial.company ?? '';
      _postalController.text = initial.postalCode;
      _stateController.text = initial.state ?? '';
      _cityController.text = initial.city;
      _line1Controller.text = initial.line1;
      _line2Controller.text = initial.line2 ?? '';
      _countryController.text = initial.country;
      _phoneController.text = initial.phone ?? '';
    } else {
      _mode = (widget.experience?.isDomestic ?? true)
          ? AddressFormMode.domestic
          : AddressFormMode.international;
      _countryController.text = _mode == AddressFormMode.domestic ? 'JP' : '';
    }
  }

  @override
  void dispose() {
    _labelController.dispose();
    _recipientController.dispose();
    _companyController.dispose();
    _postalController.dispose();
    _stateController.dispose();
    _cityController.dispose();
    _line1Controller.dispose();
    _line2Controller.dispose();
    _countryController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isIntl = _experience?.isInternational ?? false;
    final appBarTitle = _isEditing
        ? (isIntl ? 'Edit address' : '住所を編集')
        : (isIntl ? 'Add address' : '住所を追加');
    final saveLabel = isIntl ? 'Save' : '保存';
    final cancelLabel = isIntl ? 'Cancel' : 'キャンセル';

    final form = _buildFormContent(isIntl);

    if (widget.presentation == AddressFormPresentation.fullscreen) {
      return Scaffold(
        appBar: AppBar(
          leading: IconButton(
            icon: const Icon(Icons.close),
            onPressed: () => Navigator.of(context).maybePop(),
          ),
          title: Text(appBarTitle),
          actions: [
            TextButton(
              onPressed: _submitting ? null : _handleSubmit,
              child: _submitting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : Text(saveLabel),
            ),
          ],
        ),
        body: SafeArea(child: form),
      );
    }

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: IntrinsicHeight(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceM,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      appBarTitle,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            Flexible(
              child: SizedBox(height: 520, width: double.infinity, child: form),
            ),
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppTokens.spaceL,
                vertical: AppTokens.spaceM,
              ),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _submitting
                        ? null
                        : () => Navigator.of(context).pop(),
                    child: Text(cancelLabel),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _submitting ? null : _handleSubmit,
                    child: _submitting
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(saveLabel),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFormContent(bool isIntl) {
    final segments = <ButtonSegment<AddressFormMode>>[
      ButtonSegment(
        value: AddressFormMode.domestic,
        label: Text(isIntl ? 'Japan' : '国内'),
        icon: const Icon(Icons.home_work_outlined),
      ),
      ButtonSegment(
        value: AddressFormMode.international,
        label: Text(isIntl ? 'International' : '海外'),
        icon: const Icon(Icons.flight_takeoff_outlined),
      ),
    ];

    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.all(AppTokens.spaceL),
        children: [
          SegmentedButton<AddressFormMode>(
            segments: segments,
            selected: {_mode},
            onSelectionChanged: (value) {
              if (value.isEmpty) {
                return;
              }
              final next = value.first;
              if (next == _mode) {
                return;
              }
              setState(() {
                _mode = next;
                if (_mode == AddressFormMode.domestic) {
                  _countryController.text = 'JP';
                }
              });
            },
          ),
          const SizedBox(height: AppTokens.spaceL),
          AddressFormInstructions(experience: _experience, mode: _mode),
          const SizedBox(height: AppTokens.spaceL),
          AppTextField(
            controller: _labelController,
            label: isIntl ? 'Label (optional)' : 'ラベル（任意）',
            hint: isIntl ? 'Home, Office, Billing…' : '自宅、オフィス、請求先など',
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _recipientController,
            label: isIntl ? 'Recipient' : '氏名',
            required: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isIntl ? 'Recipient name is required.' : '氏名を入力してください。';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _companyController,
            label: isIntl ? 'Company (optional)' : '会社名（任意）',
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: AppTokens.spaceL),
          Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(
                child: AppTextField(
                  controller: _postalController,
                  label: isIntl ? 'Postal code' : '郵便番号',
                  required: true,
                  keyboardType: TextInputType.text,
                  textInputAction: TextInputAction.next,
                  validator: _validatePostal,
                ),
              ),
              if (_mode == AddressFormMode.domestic) ...[
                const SizedBox(width: AppTokens.spaceS),
                TextButton.icon(
                  onPressed: _submitting ? null : _lookupPostalCode,
                  icon: const Icon(Icons.search),
                  label: Text(isIntl ? 'Lookup' : '住所検索'),
                ),
              ],
            ],
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _stateController,
            label: _mode == AddressFormMode.domestic
                ? (isIntl ? 'Prefecture' : '都道府県')
                : (isIntl ? 'State / Region (optional)' : '州・地域（任意）'),
            required: _mode == AddressFormMode.domestic,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (_mode == AddressFormMode.domestic &&
                  (value == null || value.trim().isEmpty)) {
                return isIntl ? 'Prefecture is required.' : '都道府県を入力してください。';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _cityController,
            label: _mode == AddressFormMode.domestic
                ? (isIntl ? 'City / Ward' : '市区町村')
                : (isIntl ? 'City' : '市区町村'),
            required: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isIntl ? 'City is required.' : '市区町村を入力してください。';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _line1Controller,
            label: isIntl ? 'Address line 1' : '番地・町名',
            required: true,
            textInputAction: TextInputAction.next,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return isIntl
                    ? 'Address line 1 is required.'
                    : '番地・町名を入力してください。';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _line2Controller,
            label: isIntl ? 'Address line 2 (optional)' : '建物名・部屋番号（任意）',
            textInputAction: TextInputAction.next,
          ),
          if (_mode == AddressFormMode.international) ...[
            const SizedBox(height: AppTokens.spaceM),
            AppTextField(
              controller: _countryController,
              label: isIntl ? 'Country' : '国',
              required: true,
              textInputAction: TextInputAction.next,
              validator: (value) {
                if (value == null || value.trim().isEmpty) {
                  return isIntl ? 'Country is required.' : '国名を入力してください。';
                }
                return null;
              },
            ),
          ],
          const SizedBox(height: AppTokens.spaceM),
          AppTextField(
            controller: _phoneController,
            label: isIntl ? 'Phone number (optional)' : '電話番号（任意）',
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.done,
            validator: (value) {
              if (value == null || value.trim().isEmpty) {
                return null;
              }
              final digits = value.replaceAll(RegExp(r'[^0-9+]'), '');
              if (digits.length < 5) {
                return isIntl
                    ? 'Enter a valid phone number.'
                    : '有効な電話番号を入力してください。';
              }
              return null;
            },
          ),
          const SizedBox(height: AppTokens.spaceXXL),
        ],
      ),
    );
  }

  String? _validatePostal(String? value) {
    final trimmed = value?.trim() ?? '';
    if (trimmed.isEmpty) {
      return _experience?.isInternational ?? false
          ? 'Postal code is required.'
          : '郵便番号を入力してください。';
    }
    if (_mode == AddressFormMode.domestic) {
      final normalized = trimmed.replaceAll(RegExp(r'[^0-9]'), '');
      if (normalized.length != 7) {
        return _experience?.isInternational ?? false
            ? 'Enter 7 digits for Japanese postal code.'
            : '郵便番号は7桁で入力してください。';
      }
    }
    return null;
  }

  Future<void> _lookupPostalCode() async {
    final postal = _postalController.text;
    if (postal.trim().isEmpty) {
      return;
    }
    setState(() => _submitting = true);
    final result = await _controller.lookupPostalCode(postal);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    final isIntl = _experience?.isInternational ?? false;
    final messenger = ScaffoldMessenger.of(context);
    if (result == null) {
      final message = isIntl
          ? 'No match found for this postal code.'
          : '郵便番号に該当する住所が見つかりませんでした。';
      messenger
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(message)));
      return;
    }
    _stateController.text = result.prefecture;
    _cityController.text = result.city;
    if (_line1Controller.text.trim().isEmpty) {
      _line1Controller.text = result.town;
    }
    final message = isIntl ? 'Address fields populated.' : '住所を補完しました。';
    messenger
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  CheckoutAddressDraft _buildDraft() {
    final country = _mode == AddressFormMode.domestic
        ? 'JP'
        : _countryController.text;
    return CheckoutAddressDraft(
      original: widget.initialAddress,
      label: _labelController.text,
      recipient: _recipientController.text,
      company: _companyController.text,
      line1: _line1Controller.text,
      line2: _line2Controller.text,
      city: _cityController.text,
      state: _stateController.text,
      postalCode: _postalController.text,
      country: country,
      phone: _phoneController.text,
      selectAfterSave: _isEditing ? null : true,
    );
  }

  Future<void> _handleSubmit() async {
    if (_submitting) {
      return;
    }
    final form = _formKey.currentState;
    if (form == null || !form.validate()) {
      return;
    }
    setState(() => _submitting = true);
    final draft = _buildDraft();
    final saved = await _controller.saveAddress(draft);
    if (!mounted) {
      return;
    }
    setState(() => _submitting = false);
    if (saved != null) {
      Navigator.of(context).pop(saved);
    }
  }
}

class AddressFormInstructions extends StatelessWidget {
  const AddressFormInstructions({
    super.key,
    required this.experience,
    required this.mode,
  });

  final ExperienceGate? experience;
  final AddressFormMode mode;

  @override
  Widget build(BuildContext context) {
    final isIntl = experience?.isInternational ?? false;
    final showKanjiAssist = experience?.showKanjiAssist ?? false;
    String message;
    if (mode == AddressFormMode.domestic) {
      message = isIntl
          ? 'Postal code lookup fills prefecture/city automatically. Please use full-width characters if you prefer.'
          : '郵便番号検索で都道府県・市区町村を自動補完できます。番地は漢字で入力してください。';
    } else if (showKanjiAssist) {
      message = isIntl
          ? 'Use Latin characters for international shipping labels so customs officers can read them easily.'
          : '海外配送ではローマ字表記が推奨されます。正しいスペルで入力してください。';
    } else {
      message = isIntl
          ? 'International addresses should include state, postal code, and country.'
          : '海外住所では州・国名を忘れずに入力してください。';
    }
    return AppValidationMessage(
      message: message,
      state: AppValidationState.info,
    );
  }
}
