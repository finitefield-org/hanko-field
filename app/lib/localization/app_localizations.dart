// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application localization without ARB for type safety.
class AppLocalizations {
  AppLocalizations(this.locale) : _strings = _resolveStrings(locale);

  final Locale locale;
  final AppLocalizationsStrings _strings;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ja')];

  static const supportedLanguageCodes = <String>{'en', 'ja'};

  static AppLocalizations of(BuildContext context) {
    final localizations = maybeOf(context);
    assert(localizations != null, 'AppLocalizations not found in context');
    return localizations!;
  }

  static AppLocalizations? maybeOf(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static Locale resolveLocale(Locale? locale, Iterable<Locale> supported) {
    if (locale == null) {
      return supported.first;
    }

    for (final supportedLocale in supported) {
      if (supportedLocale.languageCode == locale.languageCode) {
        return supportedLocale;
      }
    }
    return supported.first;
  }

  static AppLocalizationsStrings _resolveStrings(Locale locale) {
    switch (locale.languageCode) {
      case 'ja':
        return const AppLocalizationsJa();
      case 'en':
      default:
        return const AppLocalizationsEn();
    }
  }

  String get appTitle => _strings.appTitle;
  String get welcomeHeadline => _strings.welcomeHeadline;
  String get welcomeBody => _strings.welcomeBody;
  String get primaryAction => _strings.primaryAction;
  String get secondaryAction => _strings.secondaryAction;
  String get onboardingTitle => _strings.onboardingTitle;
  String get onboardingSkip => _strings.onboardingSkip;
  String get onboardingNext => _strings.onboardingNext;
  String get onboardingBack => _strings.onboardingBack;
  String get onboardingFinish => _strings.onboardingFinish;
  String get onboardingRetry => _strings.onboardingRetry;
  String get onboardingErrorTitle => _strings.onboardingErrorTitle;
  String get onboardingSlideCreateTitle => _strings.onboardingSlideCreateTitle;
  String get onboardingSlideCreateBody => _strings.onboardingSlideCreateBody;
  String get onboardingSlideCreateTagline =>
      _strings.onboardingSlideCreateTagline;
  String get onboardingSlideMaterialsTitle =>
      _strings.onboardingSlideMaterialsTitle;
  String get onboardingSlideMaterialsBody =>
      _strings.onboardingSlideMaterialsBody;
  String get onboardingSlideMaterialsTagline =>
      _strings.onboardingSlideMaterialsTagline;
  String get onboardingSlideSupportTitle =>
      _strings.onboardingSlideSupportTitle;
  String get onboardingSlideSupportBody => _strings.onboardingSlideSupportBody;
  String get onboardingSlideSupportTagline =>
      _strings.onboardingSlideSupportTagline;
  String get localeTitle => _strings.localeTitle;
  String get localeSave => _strings.localeSave;
  String get localeSubtitle => _strings.localeSubtitle;
  String get localeContinue => _strings.localeContinue;
  String get localeUseDevice => _strings.localeUseDevice;
  String get personaTitle => _strings.personaTitle;
  String get personaSave => _strings.personaSave;
  String get personaSubtitle => _strings.personaSubtitle;
  String get personaDescription => _strings.personaDescription;
  String get personaContinue => _strings.personaContinue;
  String get personaUseSelected => _strings.personaUseSelected;
  String get authTitle => _strings.authTitle;
  String get authSubtitle => _strings.authSubtitle;
  String get authBody => _strings.authBody;
  String get authEmailLabel => _strings.authEmailLabel;
  String get authEmailHelper => _strings.authEmailHelper;
  String get authEmailRequired => _strings.authEmailRequired;
  String get authEmailInvalid => _strings.authEmailInvalid;
  String get authPasswordLabel => _strings.authPasswordLabel;
  String get authPasswordHelper => _strings.authPasswordHelper;
  String get authPasswordTooShort => _strings.authPasswordTooShort;
  String get authEmailCta => _strings.authEmailCta;
  String get authAppleButton => _strings.authAppleButton;
  String get authGoogleButton => _strings.authGoogleButton;
  String get authGuestCta => _strings.authGuestCta;
  String get authGuestNote => _strings.authGuestNote;
  String get authHelpTooltip => _strings.authHelpTooltip;
  String get authHelpTitle => _strings.authHelpTitle;
  String get authHelpBody => _strings.authHelpBody;
  String get authErrorCancelled => _strings.authErrorCancelled;
  String get authErrorNetwork => _strings.authErrorNetwork;
  String get authErrorInvalid => _strings.authErrorInvalid;
  String get authErrorWrongPassword => _strings.authErrorWrongPassword;
  String get authErrorWeakPassword => _strings.authErrorWeakPassword;
  String get authErrorAppleUnavailable => _strings.authErrorAppleUnavailable;
  String get authErrorUnknown => _strings.authErrorUnknown;
  String get authLinkingTitle => _strings.authLinkingTitle;
  String get authProviderUnknown => _strings.authProviderUnknown;
  String get authProviderGoogle => _strings.authProviderGoogle;
  String get authProviderApple => _strings.authProviderApple;
  String get authProviderEmail => _strings.authProviderEmail;
  String get profileTitle => _strings.profileTitle;
  String get profileAvatarUpdateTooltip => _strings.profileAvatarUpdateTooltip;
  String get profileAvatarUpdateTitle => _strings.profileAvatarUpdateTitle;
  String get profileAvatarUpdateBody => _strings.profileAvatarUpdateBody;
  String get profileAvatarUpdateOk => _strings.profileAvatarUpdateOk;
  String get profileLoadFailedTitle => _strings.profileLoadFailedTitle;
  String get profileLoadFailedMessage => _strings.profileLoadFailedMessage;
  String get profileRetry => _strings.profileRetry;
  String get profileStatusSignedOut => _strings.profileStatusSignedOut;
  String get profileStatusGuest => _strings.profileStatusGuest;
  String get profileStatusMember => _strings.profileStatusMember;
  String get profileFallbackGuestName => _strings.profileFallbackGuestName;
  String get profileFallbackProfileName => _strings.profileFallbackProfileName;
  String get profilePersonaTitle => _strings.profilePersonaTitle;
  String get profilePersonaSubtitle => _strings.profilePersonaSubtitle;
  String get profilePersonaJapanese => _strings.profilePersonaJapanese;
  String get profilePersonaForeigner => _strings.profilePersonaForeigner;
  String get profileQuickLinksTitle => _strings.profileQuickLinksTitle;
  String get profileQuickOrdersTitle => _strings.profileQuickOrdersTitle;
  String get profileQuickOrdersSubtitle => _strings.profileQuickOrdersSubtitle;
  String get profileQuickLibraryTitle => _strings.profileQuickLibraryTitle;
  String get profileQuickLibrarySubtitle =>
      _strings.profileQuickLibrarySubtitle;
  String get profileSettingsTitle => _strings.profileSettingsTitle;
  String get profileAddressesTitle => _strings.profileAddressesTitle;
  String get profileAddressesSubtitle => _strings.profileAddressesSubtitle;
  String get profilePaymentsTitle => _strings.profilePaymentsTitle;
  String get profilePaymentsSubtitle => _strings.profilePaymentsSubtitle;
  String get paymentMethodErrorLast4 => _strings.paymentMethodErrorLast4;
  String get paymentMethodErrorExpMonth => _strings.paymentMethodErrorExpMonth;
  String get paymentMethodErrorExpYear => _strings.paymentMethodErrorExpYear;
  String get paymentMethodErrorFixFields =>
      _strings.paymentMethodErrorFixFields;
  String get paymentMethodAddFailed => _strings.paymentMethodAddFailed;
  String get paymentMethodSheetTitle => _strings.paymentMethodSheetTitle;
  String get paymentMethodSheetCard => _strings.paymentMethodSheetCard;
  String get paymentMethodSheetWallet => _strings.paymentMethodSheetWallet;
  String get paymentMethodSheetBrandLabel =>
      _strings.paymentMethodSheetBrandLabel;
  String get paymentMethodSheetLast4Label =>
      _strings.paymentMethodSheetLast4Label;
  String get paymentMethodSheetExpMonthLabel =>
      _strings.paymentMethodSheetExpMonthLabel;
  String get paymentMethodSheetExpYearLabel =>
      _strings.paymentMethodSheetExpYearLabel;
  String get paymentMethodSheetBillingNameLabel =>
      _strings.paymentMethodSheetBillingNameLabel;
  String get paymentMethodSheetSave => _strings.paymentMethodSheetSave;
  String get profileNotificationsTitle => _strings.profileNotificationsTitle;
  String get profileNotificationsSubtitle =>
      _strings.profileNotificationsSubtitle;
  String get profileNotificationsHeader => _strings.profileNotificationsHeader;
  String get profileNotificationsPushHeader =>
      _strings.profileNotificationsPushHeader;
  String get profileNotificationsEmailHeader =>
      _strings.profileNotificationsEmailHeader;
  String get profileNotificationsDigestHeader =>
      _strings.profileNotificationsDigestHeader;
  String get profileNotificationsDigestHelper =>
      _strings.profileNotificationsDigestHelper;
  String get profileNotificationsDigestDaily =>
      _strings.profileNotificationsDigestDaily;
  String get profileNotificationsDigestWeekly =>
      _strings.profileNotificationsDigestWeekly;
  String get profileNotificationsDigestMonthly =>
      _strings.profileNotificationsDigestMonthly;
  String get profileNotificationsSave => _strings.profileNotificationsSave;
  String get profileNotificationsReset => _strings.profileNotificationsReset;
  String get profileNotificationsSaved => _strings.profileNotificationsSaved;
  String get profileNotificationsSaveFailed =>
      _strings.profileNotificationsSaveFailed;
  String get profileNotificationsLoadFailedTitle =>
      _strings.profileNotificationsLoadFailedTitle;
  String get profileNotificationsCategoryOrdersTitle =>
      _strings.profileNotificationsCategoryOrdersTitle;
  String get profileNotificationsCategoryOrdersBody =>
      _strings.profileNotificationsCategoryOrdersBody;
  String get profileNotificationsCategoryDesignsTitle =>
      _strings.profileNotificationsCategoryDesignsTitle;
  String get profileNotificationsCategoryDesignsBody =>
      _strings.profileNotificationsCategoryDesignsBody;
  String get profileNotificationsCategoryPromosTitle =>
      _strings.profileNotificationsCategoryPromosTitle;
  String get profileNotificationsCategoryPromosBody =>
      _strings.profileNotificationsCategoryPromosBody;
  String get profileNotificationsCategoryGuidesTitle =>
      _strings.profileNotificationsCategoryGuidesTitle;
  String get profileNotificationsCategoryGuidesBody =>
      _strings.profileNotificationsCategoryGuidesBody;
  String get profileLocaleTitle => _strings.profileLocaleTitle;
  String get profileLocaleSubtitle => _strings.profileLocaleSubtitle;
  String get profileLocaleLanguageHeader =>
      _strings.profileLocaleLanguageHeader;
  String get profileLocaleLanguageHelper =>
      _strings.profileLocaleLanguageHelper;
  String get profileLocaleCurrencyHeader =>
      _strings.profileLocaleCurrencyHeader;
  String get profileLocaleCurrencyHelper =>
      _strings.profileLocaleCurrencyHelper;
  String get profileLocaleCurrencyAuto => _strings.profileLocaleCurrencyAuto;
  String get profileLocaleCurrencyJpy => _strings.profileLocaleCurrencyJpy;
  String get profileLocaleCurrencyUsd => _strings.profileLocaleCurrencyUsd;
  String get profileLocaleSave => _strings.profileLocaleSave;
  String get profileLocaleSaved => _strings.profileLocaleSaved;
  String get profileLocaleSaveFailed => _strings.profileLocaleSaveFailed;
  String get profileLocaleUseDevice => _strings.profileLocaleUseDevice;
  String get profileLegalTitle => _strings.profileLegalTitle;
  String get profileLegalSubtitle => _strings.profileLegalSubtitle;
  String get profileLegalDownloadTooltip =>
      _strings.profileLegalDownloadTooltip;
  String get profileLegalDownloadComplete =>
      _strings.profileLegalDownloadComplete;
  String get profileLegalDownloadFailed => _strings.profileLegalDownloadFailed;
  String get profileLegalLoadFailedTitle =>
      _strings.profileLegalLoadFailedTitle;
  String get profileLegalDocumentsTitle => _strings.profileLegalDocumentsTitle;
  String get profileLegalContentTitle => _strings.profileLegalContentTitle;
  String get profileLegalOpenInBrowser => _strings.profileLegalOpenInBrowser;
  String get profileLegalVersionUnknown => _strings.profileLegalVersionUnknown;
  String get profileLegalNoDocument => _strings.profileLegalNoDocument;
  String get profileLegalUnavailable => _strings.profileLegalUnavailable;
  String get profileLegalNoContent => _strings.profileLegalNoContent;
  String get profileSupportTitle => _strings.profileSupportTitle;
  String get profileSupportSubtitle => _strings.profileSupportSubtitle;
  String get supportChatConnectedAgent => _strings.supportChatConnectedAgent;
  String get supportChatAgentGreeting => _strings.supportChatAgentGreeting;
  String get supportChatBotHandoff => _strings.supportChatBotHandoff;
  String get supportChatBotDelivery => _strings.supportChatBotDelivery;
  String get supportChatBotOrderStatus => _strings.supportChatBotOrderStatus;
  String get supportChatBotFallback => _strings.supportChatBotFallback;
  String get supportChatAgentRefund => _strings.supportChatAgentRefund;
  String get supportChatAgentAddress => _strings.supportChatAgentAddress;
  String get supportChatAgentFallback => _strings.supportChatAgentFallback;
  String get profileGuidesTitle => _strings.profileGuidesTitle;
  String get profileGuidesSubtitle => _strings.profileGuidesSubtitle;
  String get profileHowtoTitle => _strings.profileHowtoTitle;
  String get profileHowtoSubtitle => _strings.profileHowtoSubtitle;
  String get profileLinkedAccountsTitle => _strings.profileLinkedAccountsTitle;
  String get profileLinkedAccountsSubtitle =>
      _strings.profileLinkedAccountsSubtitle;
  String get profileLinkedAccountsHeader =>
      _strings.profileLinkedAccountsHeader;
  String get profileLinkedAccountsAddTooltip =>
      _strings.profileLinkedAccountsAddTooltip;
  String get profileLinkedAccountsLoadFailedTitle =>
      _strings.profileLinkedAccountsLoadFailedTitle;
  String get profileLinkedAccountsSignedOutTitle =>
      _strings.profileLinkedAccountsSignedOutTitle;
  String get profileLinkedAccountsSignedOutBody =>
      _strings.profileLinkedAccountsSignedOutBody;
  String get profileLinkedAccountsSignIn =>
      _strings.profileLinkedAccountsSignIn;
  String get profileLinkedAccountsBannerTitle =>
      _strings.profileLinkedAccountsBannerTitle;
  String get profileLinkedAccountsBannerBody =>
      _strings.profileLinkedAccountsBannerBody;
  String get profileLinkedAccountsBannerBodyLong =>
      _strings.profileLinkedAccountsBannerBodyLong;
  String get profileLinkedAccountsBannerAction =>
      _strings.profileLinkedAccountsBannerAction;
  String get profileLinkedAccountsConnected =>
      _strings.profileLinkedAccountsConnected;
  String get profileLinkedAccountsNotConnected =>
      _strings.profileLinkedAccountsNotConnected;
  String get profileLinkedAccountsProviderFallback =>
      _strings.profileLinkedAccountsProviderFallback;
  String get profileLinkedAccountsAutoSignIn =>
      _strings.profileLinkedAccountsAutoSignIn;
  String get profileLinkedAccountsNotConnectedHelper =>
      _strings.profileLinkedAccountsNotConnectedHelper;
  String get profileLinkedAccountsUnlink =>
      _strings.profileLinkedAccountsUnlink;
  String get profileLinkedAccountsUnlinkTitle =>
      _strings.profileLinkedAccountsUnlinkTitle;
  String get profileLinkedAccountsUnlinkBody =>
      _strings.profileLinkedAccountsUnlinkBody;
  String get profileLinkedAccountsUnlinkConfirm =>
      _strings.profileLinkedAccountsUnlinkConfirm;
  String get profileLinkedAccountsCancel =>
      _strings.profileLinkedAccountsCancel;
  String get profileLinkedAccountsUnlinkDisabled =>
      _strings.profileLinkedAccountsUnlinkDisabled;
  String get profileLinkedAccountsSave => _strings.profileLinkedAccountsSave;
  String get profileLinkedAccountsSaved => _strings.profileLinkedAccountsSaved;
  String get profileLinkedAccountsSaveFailed =>
      _strings.profileLinkedAccountsSaveFailed;
  String get profileLinkedAccountsLinked =>
      _strings.profileLinkedAccountsLinked;
  String get profileLinkedAccountsLinkFailed =>
      _strings.profileLinkedAccountsLinkFailed;
  String get profileLinkedAccountsUnlinked =>
      _strings.profileLinkedAccountsUnlinked;
  String get profileLinkedAccountsUnlinkFailed =>
      _strings.profileLinkedAccountsUnlinkFailed;
  String get profileLinkedAccountsLinkTitle =>
      _strings.profileLinkedAccountsLinkTitle;
  String get profileLinkedAccountsLinkSubtitle =>
      _strings.profileLinkedAccountsLinkSubtitle;
  String get profileLinkedAccountsAlreadyLinked =>
      _strings.profileLinkedAccountsAlreadyLinked;
  String get profileLinkedAccountsFooter =>
      _strings.profileLinkedAccountsFooter;
  String get profileLinkedAccountsOk => _strings.profileLinkedAccountsOk;
  String get profileExportTitle => _strings.profileExportTitle;
  String get profileExportSubtitle => _strings.profileExportSubtitle;
  String get profileExportAppBarSubtitle =>
      _strings.profileExportAppBarSubtitle;
  String get profileExportSummaryTitle => _strings.profileExportSummaryTitle;
  String get profileExportSummaryBody => _strings.profileExportSummaryBody;
  String get profileExportIncludeAssetsTitle =>
      _strings.profileExportIncludeAssetsTitle;
  String get profileExportIncludeAssetsSubtitle =>
      _strings.profileExportIncludeAssetsSubtitle;
  String get profileExportIncludeOrdersTitle =>
      _strings.profileExportIncludeOrdersTitle;
  String get profileExportIncludeOrdersSubtitle =>
      _strings.profileExportIncludeOrdersSubtitle;
  String get profileExportIncludeHistoryTitle =>
      _strings.profileExportIncludeHistoryTitle;
  String get profileExportIncludeHistorySubtitle =>
      _strings.profileExportIncludeHistorySubtitle;
  String get profileExportPermissionTitle =>
      _strings.profileExportPermissionTitle;
  String get profileExportPermissionBody =>
      _strings.profileExportPermissionBody;
  String get profileExportPermissionCta => _strings.profileExportPermissionCta;
  String get permissionsTitle => _strings.permissionsTitle;
  String get permissionsSubtitle => _strings.permissionsSubtitle;
  String get permissionsHeroTitle => _strings.permissionsHeroTitle;
  String get permissionsHeroBody => _strings.permissionsHeroBody;
  String get permissionsPersonaDomestic => _strings.permissionsPersonaDomestic;
  String get permissionsPersonaInternational =>
      _strings.permissionsPersonaInternational;
  String get permissionsPhotosTitle => _strings.permissionsPhotosTitle;
  String get permissionsPhotosBody => _strings.permissionsPhotosBody;
  String get permissionsPhotosAssist1 => _strings.permissionsPhotosAssist1;
  String get permissionsPhotosAssist2 => _strings.permissionsPhotosAssist2;
  String get permissionsStorageTitle => _strings.permissionsStorageTitle;
  String get permissionsStorageBody => _strings.permissionsStorageBody;
  String get permissionsStorageAssist1 => _strings.permissionsStorageAssist1;
  String get permissionsStorageAssist2 => _strings.permissionsStorageAssist2;
  String get permissionsNotificationsTitle =>
      _strings.permissionsNotificationsTitle;
  String get permissionsNotificationsBody =>
      _strings.permissionsNotificationsBody;
  String get permissionsNotificationsAssist1 =>
      _strings.permissionsNotificationsAssist1;
  String get permissionsNotificationsAssist2 =>
      _strings.permissionsNotificationsAssist2;
  String get permissionsStatusGranted => _strings.permissionsStatusGranted;
  String get permissionsStatusDenied => _strings.permissionsStatusDenied;
  String get permissionsStatusRestricted =>
      _strings.permissionsStatusRestricted;
  String get permissionsStatusUnknown => _strings.permissionsStatusUnknown;
  String get permissionsFallbackPhotos => _strings.permissionsFallbackPhotos;
  String get permissionsFallbackStorage => _strings.permissionsFallbackStorage;
  String get permissionsFallbackNotifications =>
      _strings.permissionsFallbackNotifications;
  String get permissionsCtaGrantAll => _strings.permissionsCtaGrantAll;
  String get permissionsCtaNotNow => _strings.permissionsCtaNotNow;
  String get permissionsFooterPolicy => _strings.permissionsFooterPolicy;
  String get permissionsItemActionAllow => _strings.permissionsItemActionAllow;
  String get profileExportStatusReadyTitle =>
      _strings.profileExportStatusReadyTitle;
  String get profileExportStatusReadyBody =>
      _strings.profileExportStatusReadyBody;
  String get profileExportStatusInProgressTitle =>
      _strings.profileExportStatusInProgressTitle;
  String get profileExportStatusInProgressBody =>
      _strings.profileExportStatusInProgressBody;
  String get profileExportStatusDoneTitle =>
      _strings.profileExportStatusDoneTitle;
  String get profileExportStatusDoneBody =>
      _strings.profileExportStatusDoneBody;
  String get profileExportCtaStart => _strings.profileExportCtaStart;
  String get profileExportCtaHistory => _strings.profileExportCtaHistory;
  String get profileExportHistoryTitle => _strings.profileExportHistoryTitle;
  String get profileExportHistoryEmptyTitle =>
      _strings.profileExportHistoryEmptyTitle;
  String get profileExportHistoryEmptyBody =>
      _strings.profileExportHistoryEmptyBody;
  String get profileExportHistoryDownload =>
      _strings.profileExportHistoryDownload;
  String get profileExportErrorTitle => _strings.profileExportErrorTitle;
  String get profileExportErrorBody => _strings.profileExportErrorBody;
  String get profileExportRetry => _strings.profileExportRetry;
  String get profileExportTimeJustNow => _strings.profileExportTimeJustNow;
  String get profileExportTimeCompactNow =>
      _strings.profileExportTimeCompactNow;
  String get profileDeleteTitle => _strings.profileDeleteTitle;
  String get profileDeleteSubtitle => _strings.profileDeleteSubtitle;
  String get profileDeleteWarningTitle => _strings.profileDeleteWarningTitle;
  String get profileDeleteWarningBody => _strings.profileDeleteWarningBody;
  String get profileDeleteAcknowledgementTitle =>
      _strings.profileDeleteAcknowledgementTitle;
  String get profileDeleteAckDataLossTitle =>
      _strings.profileDeleteAckDataLossTitle;
  String get profileDeleteAckDataLossBody =>
      _strings.profileDeleteAckDataLossBody;
  String get profileDeleteAckOrdersTitle =>
      _strings.profileDeleteAckOrdersTitle;
  String get profileDeleteAckOrdersBody => _strings.profileDeleteAckOrdersBody;
  String get profileDeleteAckIrreversibleTitle =>
      _strings.profileDeleteAckIrreversibleTitle;
  String get profileDeleteAckIrreversibleBody =>
      _strings.profileDeleteAckIrreversibleBody;
  String get profileDeleteFooterNote => _strings.profileDeleteFooterNote;
  String get profileDeleteCta => _strings.profileDeleteCta;
  String get profileDeleteCancelCta => _strings.profileDeleteCancelCta;
  String get profileDeleteConfirmTitle => _strings.profileDeleteConfirmTitle;
  String get profileDeleteConfirmBody => _strings.profileDeleteConfirmBody;
  String get profileDeleteConfirmAction => _strings.profileDeleteConfirmAction;
  String get profileDeleteConfirmCancel => _strings.profileDeleteConfirmCancel;
  String get profileDeleteSuccess => _strings.profileDeleteSuccess;
  String get profileDeleteError => _strings.profileDeleteError;
  String get profileDeleteErrorTitle => _strings.profileDeleteErrorTitle;
  String get profileDeleteErrorBody => _strings.profileDeleteErrorBody;
  String get profileDeleteRetry => _strings.profileDeleteRetry;
  String get profileSignInCta => _strings.profileSignInCta;
  String get profileAccountSecurityTitle =>
      _strings.profileAccountSecurityTitle;
  String get profileAccountSecuritySubtitle =>
      _strings.profileAccountSecuritySubtitle;
  String get profileAccountSecurityBody => _strings.profileAccountSecurityBody;
  String get appUpdateTitle => _strings.appUpdateTitle;
  String get appUpdateCheckAgain => _strings.appUpdateCheckAgain;
  String get appUpdateChecking => _strings.appUpdateChecking;
  String get appUpdateVerifyFailedTitle => _strings.appUpdateVerifyFailedTitle;
  String get appUpdateRetry => _strings.appUpdateRetry;
  String get appUpdateBannerRequired => _strings.appUpdateBannerRequired;
  String get appUpdateBannerOptional => _strings.appUpdateBannerOptional;
  String get appUpdateBannerAction => _strings.appUpdateBannerAction;
  String get appUpdateCardRequiredTitle => _strings.appUpdateCardRequiredTitle;
  String get appUpdateCardOptionalTitle => _strings.appUpdateCardOptionalTitle;
  String get appUpdateNow => _strings.appUpdateNow;
  String get appUpdateOpenStore => _strings.appUpdateOpenStore;
  String get appUpdateContinue => _strings.appUpdateContinue;
  String get appUpdateStoreUnavailable => _strings.appUpdateStoreUnavailable;
  String get appUpdateStoreOpenFailed => _strings.appUpdateStoreOpenFailed;
  String get appUpdateLater => _strings.appUpdateLater;
  String get commonBack => _strings.commonBack;
  String get commonRetry => _strings.commonRetry;
  String get commonClose => _strings.commonClose;
  String get commonCancel => _strings.commonCancel;
  String get commonSave => _strings.commonSave;
  String get commonLearnMore => _strings.commonLearnMore;
  String get commonLoadMore => _strings.commonLoadMore;
  String get commonClear => _strings.commonClear;
  String get commonLoadFailed => _strings.commonLoadFailed;
  String get commonUnknown => _strings.commonUnknown;
  String get commonPlaceholder => _strings.commonPlaceholder;
  String get offlineTitle => _strings.offlineTitle;
  String get offlineMessage => _strings.offlineMessage;
  String get offlineRetry => _strings.offlineRetry;
  String get offlineOpenCachedLibrary => _strings.offlineOpenCachedLibrary;
  String get offlineCacheHint => _strings.offlineCacheHint;
  String get offlineLastSyncUnavailable => _strings.offlineLastSyncUnavailable;
  String get changelogTitle => _strings.changelogTitle;
  String get changelogLatestReleaseTooltip =>
      _strings.changelogLatestReleaseTooltip;
  String get changelogHighlightsTitle => _strings.changelogHighlightsTitle;
  String get changelogAllUpdates => _strings.changelogAllUpdates;
  String get changelogMajorOnly => _strings.changelogMajorOnly;
  String get changelogUnableToLoad => _strings.changelogUnableToLoad;
  String get changelogNoUpdatesTitle => _strings.changelogNoUpdatesTitle;
  String get changelogNoUpdatesMessage => _strings.changelogNoUpdatesMessage;
  String get changelogVersionHistoryTitle =>
      _strings.changelogVersionHistoryTitle;
  String get changelogVersionHistorySubtitle =>
      _strings.changelogVersionHistorySubtitle;
  String get searchHintText => _strings.searchHintText;
  String get searchVoiceTooltip => _strings.searchVoiceTooltip;
  String get searchVoiceComingSoon => _strings.searchVoiceComingSoon;
  String get searchRecentTitle => _strings.searchRecentTitle;
  String get searchSuggestionsTitle => _strings.searchSuggestionsTitle;
  String get searchSuggestionsLoadFailed =>
      _strings.searchSuggestionsLoadFailed;
  String get searchResultsErrorTitle => _strings.searchResultsErrorTitle;
  String get searchResultsEmptyTitle => _strings.searchResultsEmptyTitle;
  String get searchResultsEmptyMessage => _strings.searchResultsEmptyMessage;
  String get homeTitle => _strings.homeTitle;
  String get homeSearchTooltip => _strings.homeSearchTooltip;
  String get homeNotificationsTooltip => _strings.homeNotificationsTooltip;
  String get homeFeaturedTitle => _strings.homeFeaturedTitle;
  String get homeFeaturedSubtitle => _strings.homeFeaturedSubtitle;
  String get homeFeaturedEmpty => _strings.homeFeaturedEmpty;
  String get homeRecentTitle => _strings.homeRecentTitle;
  String get homeRecentSubtitle => _strings.homeRecentSubtitle;
  String get homeRecentActionLabel => _strings.homeRecentActionLabel;
  String get homeRecentEmpty => _strings.homeRecentEmpty;
  String get homeRecommendedTitle => _strings.homeRecommendedTitle;
  String get homeRecommendedSubtitle => _strings.homeRecommendedSubtitle;
  String get homeRecommendedLoading => _strings.homeRecommendedLoading;
  String get homeStatusDraft => _strings.homeStatusDraft;
  String get homeStatusReady => _strings.homeStatusReady;
  String get homeStatusOrdered => _strings.homeStatusOrdered;
  String get homeStatusLocked => _strings.homeStatusLocked;
  String get homeShapeRound => _strings.homeShapeRound;
  String get homeShapeSquare => _strings.homeShapeSquare;
  String get homeWritingTensho => _strings.homeWritingTensho;
  String get homeWritingReisho => _strings.homeWritingReisho;
  String get homeWritingKaisho => _strings.homeWritingKaisho;
  String get homeWritingGyosho => _strings.homeWritingGyosho;
  String get homeWritingKoentai => _strings.homeWritingKoentai;
  String get homeWritingCustom => _strings.homeWritingCustom;
  String get homeNameUnset => _strings.homeNameUnset;
  String get homeDesignAiCheckDone => _strings.homeDesignAiCheckDone;
  String get homeDesignAiCheckNotRun => _strings.homeDesignAiCheckNotRun;
  String get homeTemplateApply => _strings.homeTemplateApply;
  String get homeLoadFailed => _strings.homeLoadFailed;
  String get topBarSearchLabel => _strings.topBarSearchLabel;
  String get topBarSearchHint => _strings.topBarSearchHint;
  String get topBarSearchTooltip => _strings.topBarSearchTooltip;
  String get topBarHelpLabel => _strings.topBarHelpLabel;
  String get topBarHelpHint => _strings.topBarHelpHint;
  String get topBarHelpTooltip => _strings.topBarHelpTooltip;
  String get topBarNotificationsLabel => _strings.topBarNotificationsLabel;
  String get topBarNotificationsTooltip => _strings.topBarNotificationsTooltip;
  String get topBarHelpOverlayTitle => _strings.topBarHelpOverlayTitle;
  String get topBarHelpOverlayPrimaryAction =>
      _strings.topBarHelpOverlayPrimaryAction;
  String get topBarHelpOverlaySecondaryAction =>
      _strings.topBarHelpOverlaySecondaryAction;
  String get topBarHelpOverlayBody => _strings.topBarHelpOverlayBody;
  String get topBarShortcutSearchLabel => _strings.topBarShortcutSearchLabel;
  String get topBarShortcutHelpLabel => _strings.topBarShortcutHelpLabel;
  String get topBarShortcutNotificationsLabel =>
      _strings.topBarShortcutNotificationsLabel;
  String get topBarHelpLinkFaqTitle => _strings.topBarHelpLinkFaqTitle;
  String get topBarHelpLinkFaqSubtitle => _strings.topBarHelpLinkFaqSubtitle;
  String get topBarHelpLinkChatTitle => _strings.topBarHelpLinkChatTitle;
  String get topBarHelpLinkChatSubtitle => _strings.topBarHelpLinkChatSubtitle;
  String get topBarHelpLinkContactTitle => _strings.topBarHelpLinkContactTitle;
  String get topBarHelpLinkContactSubtitle =>
      _strings.topBarHelpLinkContactSubtitle;
  String get splashLoading => _strings.splashLoading;
  String get splashFailedTitle => _strings.splashFailedTitle;
  String get splashFailedMessage => _strings.splashFailedMessage;
  String get designVersionsTitle => _strings.designVersionsTitle;
  String get designVersionsShowDiffTooltip =>
      _strings.designVersionsShowDiffTooltip;
  String get designVersionsSecondaryDuplicate =>
      _strings.designVersionsSecondaryDuplicate;
  String get designVersionsTimelineTitle =>
      _strings.designVersionsTimelineTitle;
  String get designVersionsRefreshTooltip =>
      _strings.designVersionsRefreshTooltip;
  String get designVersionsAuditLogTitle =>
      _strings.designVersionsAuditLogTitle;
  String get designVersionsNoAuditTitle => _strings.designVersionsNoAuditTitle;
  String get designVersionsNoAuditMessage =>
      _strings.designVersionsNoAuditMessage;
  String get designVersionsRollbackAction =>
      _strings.designVersionsRollbackAction;
  String get designVersionsRollbackCancel =>
      _strings.designVersionsRollbackCancel;
  String get designVersionsNoDiffSummary =>
      _strings.designVersionsNoDiffSummary;
  String get designVersionsLatestLabel => _strings.designVersionsLatestLabel;
  String get designVersionsRollbackButton =>
      _strings.designVersionsRollbackButton;
  String get designVersionsPreviewCurrent =>
      _strings.designVersionsPreviewCurrent;
  String get designVersionsPreviewTarget =>
      _strings.designVersionsPreviewTarget;
  String get designVersionsInitialFallback =>
      _strings.designVersionsInitialFallback;
  String get designVersionsUnset => _strings.designVersionsUnset;
  String get designVersionsAutoLayout => _strings.designVersionsAutoLayout;
  String get designVersionsNoDiffTitle => _strings.designVersionsNoDiffTitle;
  String get designVersionsNoDiffMessage =>
      _strings.designVersionsNoDiffMessage;
  String get designVersionsChangeHistoryEmpty =>
      _strings.designVersionsChangeHistoryEmpty;
  String get designVersionsStatusCurrent =>
      _strings.designVersionsStatusCurrent;
  String get designVersionsStatusComparing =>
      _strings.designVersionsStatusComparing;
  String get designVersionsStatusHistory =>
      _strings.designVersionsStatusHistory;
  String get designVersionsLoadFailedTitle =>
      _strings.designVersionsLoadFailedTitle;
  String get designVersionsSimilarityLabel =>
      _strings.designVersionsSimilarityLabel;
  String get checkoutPaymentTitle => _strings.checkoutPaymentTitle;
  String get checkoutPaymentAddTooltip => _strings.checkoutPaymentAddTooltip;
  String get checkoutPaymentLoadFailedTitle =>
      _strings.checkoutPaymentLoadFailedTitle;
  String get checkoutPaymentEmptyTitle => _strings.checkoutPaymentEmptyTitle;
  String get checkoutPaymentEmptyBody => _strings.checkoutPaymentEmptyBody;
  String get checkoutPaymentSignInHint => _strings.checkoutPaymentSignInHint;
  String get checkoutPaymentAddMethod => _strings.checkoutPaymentAddMethod;
  String get checkoutPaymentChooseSaved => _strings.checkoutPaymentChooseSaved;
  String get checkoutPaymentAddAnother => _strings.checkoutPaymentAddAnother;
  String get checkoutPaymentContinueReview =>
      _strings.checkoutPaymentContinueReview;
  String get checkoutPaymentAddFailed => _strings.checkoutPaymentAddFailed;
  String get checkoutPaymentMethodCard => _strings.checkoutPaymentMethodCard;
  String get checkoutPaymentMethodWallet =>
      _strings.checkoutPaymentMethodWallet;
  String get checkoutPaymentMethodBank => _strings.checkoutPaymentMethodBank;
  String get checkoutPaymentMethodFallback =>
      _strings.checkoutPaymentMethodFallback;
  String get cartPromoEnterCode => _strings.cartPromoEnterCode;
  String get cartPromoAddItemsRequired => _strings.cartPromoAddItemsRequired;
  String get cartPromoField10Label => _strings.cartPromoField10Label;
  String get cartPromoField10Description =>
      _strings.cartPromoField10Description;
  String get cartPromoShipfreeLabel => _strings.cartPromoShipfreeLabel;
  String get cartPromoInkLabel => _strings.cartPromoInkLabel;
  String get cartPromoInkDescription => _strings.cartPromoInkDescription;
  String get cartPromoInvalid => _strings.cartPromoInvalid;
  String get cartLineTitaniumTitle => _strings.cartLineTitaniumTitle;
  String get cartLineTitaniumVariant => _strings.cartLineTitaniumVariant;
  String get cartLineTitaniumDesign => _strings.cartLineTitaniumDesign;
  String get cartLineTitaniumAddonSleeveLabel =>
      _strings.cartLineTitaniumAddonSleeveLabel;
  String get cartLineTitaniumAddonSleeveDescription =>
      _strings.cartLineTitaniumAddonSleeveDescription;
  String get cartLineTitaniumAddonSleeveBadge =>
      _strings.cartLineTitaniumAddonSleeveBadge;
  String get cartLineTitaniumAddonDeepLabel =>
      _strings.cartLineTitaniumAddonDeepLabel;
  String get cartLineTitaniumAddonDeepDescription =>
      _strings.cartLineTitaniumAddonDeepDescription;
  String get cartLineTitaniumAddonWrapLabel =>
      _strings.cartLineTitaniumAddonWrapLabel;
  String get cartLineTitaniumAddonWrapDescription =>
      _strings.cartLineTitaniumAddonWrapDescription;
  String get cartLineTitaniumNoteIntl => _strings.cartLineTitaniumNoteIntl;
  String get cartLineTitaniumNoteDomestic =>
      _strings.cartLineTitaniumNoteDomestic;
  String get cartLineTitaniumRibbon => _strings.cartLineTitaniumRibbon;
  String get cartLineAcrylicTitle => _strings.cartLineAcrylicTitle;
  String get cartLineAcrylicVariant => _strings.cartLineAcrylicVariant;
  String get cartLineAcrylicDesign => _strings.cartLineAcrylicDesign;
  String get cartLineAcrylicAddonUvLabel =>
      _strings.cartLineAcrylicAddonUvLabel;
  String get cartLineAcrylicAddonUvDescription =>
      _strings.cartLineAcrylicAddonUvDescription;
  String get cartLineAcrylicAddonUvBadge =>
      _strings.cartLineAcrylicAddonUvBadge;
  String get cartLineAcrylicAddonInkLabel =>
      _strings.cartLineAcrylicAddonInkLabel;
  String get cartLineAcrylicAddonInkDescription =>
      _strings.cartLineAcrylicAddonInkDescription;
  String get cartLineAcrylicAddonPouchLabel =>
      _strings.cartLineAcrylicAddonPouchLabel;
  String get cartLineAcrylicAddonPouchDescription =>
      _strings.cartLineAcrylicAddonPouchDescription;
  String get cartLineAcrylicNote => _strings.cartLineAcrylicNote;
  String get cartLineAcrylicRibbonIntl => _strings.cartLineAcrylicRibbonIntl;
  String get cartLineAcrylicRibbon => _strings.cartLineAcrylicRibbon;
  String get cartLineBoxTitle => _strings.cartLineBoxTitle;
  String get cartLineBoxVariant => _strings.cartLineBoxVariant;
  String get cartLineBoxDesign => _strings.cartLineBoxDesign;
  String get cartLineBoxAddonFoamLabel => _strings.cartLineBoxAddonFoamLabel;
  String get cartLineBoxAddonFoamDescription =>
      _strings.cartLineBoxAddonFoamDescription;
  String get cartLineBoxAddonCardLabel => _strings.cartLineBoxAddonCardLabel;
  String get cartLineBoxAddonCardDescription =>
      _strings.cartLineBoxAddonCardDescription;
  String get cartLineBoxAddonWrapLabel => _strings.cartLineBoxAddonWrapLabel;
  String get cartLineBoxAddonWrapDescription =>
      _strings.cartLineBoxAddonWrapDescription;
  String get cartLineBoxNoteIntl => _strings.cartLineBoxNoteIntl;
  String get cartLineBoxNoteDomestic => _strings.cartLineBoxNoteDomestic;
  String get cartLineBoxRibbon => _strings.cartLineBoxRibbon;
  String get cartEstimateMethodIntl => _strings.cartEstimateMethodIntl;
  String get cartEstimateMethodDomestic => _strings.cartEstimateMethodDomestic;
  String get cartEstimateMethodIntlPriority =>
      _strings.cartEstimateMethodIntlPriority;
  String get cartEstimateMethodStandard => _strings.cartEstimateMethodStandard;
  String get cartTitle => _strings.cartTitle;
  String get cartBulkEditTooltip => _strings.cartBulkEditTooltip;
  String get cartLoadFailedTitle => _strings.cartLoadFailedTitle;
  String get cartEmptyTitle => _strings.cartEmptyTitle;
  String get cartEmptyMessage => _strings.cartEmptyMessage;
  String get cartEmptyAction => _strings.cartEmptyAction;
  String get cartUndo => _strings.cartUndo;
  String get cartEditOptionsTitle => _strings.cartEditOptionsTitle;
  String get cartAddonIncluded => _strings.cartAddonIncluded;
  String get cartReset => _strings.cartReset;
  String get cartSave => _strings.cartSave;
  String get cartBulkActionsTitle => _strings.cartBulkActionsTitle;
  String get cartBulkActionsBody => _strings.cartBulkActionsBody;
  String get cartBulkActionApplyField10 => _strings.cartBulkActionApplyField10;
  String get cartBulkActionShipfree => _strings.cartBulkActionShipfree;
  String get cartBulkActionClearSelections =>
      _strings.cartBulkActionClearSelections;
  String get cartUnitPerItem => _strings.cartUnitPerItem;
  String get cartEditOptionsAction => _strings.cartEditOptionsAction;
  String get cartRemoveAction => _strings.cartRemoveAction;
  String get cartLineTotalLabel => _strings.cartLineTotalLabel;
  String get cartPromoTitle => _strings.cartPromoTitle;
  String get cartPromoFieldLabel => _strings.cartPromoFieldLabel;
  String get cartPromoApplyLabel => _strings.cartPromoApplyLabel;
  String get cartPromoAppliedFallback => _strings.cartPromoAppliedFallback;
  String get cartPromoMockHint => _strings.cartPromoMockHint;
  String get cartSummaryTitle => _strings.cartSummaryTitle;
  String get cartSummarySubtotal => _strings.cartSummarySubtotal;
  String get cartSummaryDiscount => _strings.cartSummaryDiscount;
  String get cartSummaryShipping => _strings.cartSummaryShipping;
  String get cartSummaryFree => _strings.cartSummaryFree;
  String get cartSummaryTax => _strings.cartSummaryTax;
  String get cartSummaryTotal => _strings.cartSummaryTotal;
  String get cartProceedCheckout => _strings.cartProceedCheckout;
  String get checkoutAddressTitle => _strings.checkoutAddressTitle;
  String get checkoutAddressAddTooltip => _strings.checkoutAddressAddTooltip;
  String get checkoutAddressLoadFailedTitle =>
      _strings.checkoutAddressLoadFailedTitle;
  String get checkoutAddressEmptyTitle => _strings.checkoutAddressEmptyTitle;
  String get checkoutAddressEmptyMessage =>
      _strings.checkoutAddressEmptyMessage;
  String get checkoutAddressAddAction => _strings.checkoutAddressAddAction;
  String get checkoutAddressChooseHint => _strings.checkoutAddressChooseHint;
  String get checkoutAddressAddAnother => _strings.checkoutAddressAddAnother;
  String get checkoutAddressContinueShipping =>
      _strings.checkoutAddressContinueShipping;
  String get checkoutAddressSelectRequired =>
      _strings.checkoutAddressSelectRequired;
  String get checkoutAddressSavedCreated =>
      _strings.checkoutAddressSavedCreated;
  String get checkoutAddressSavedUpdated =>
      _strings.checkoutAddressSavedUpdated;
  String get checkoutAddressChipShipping =>
      _strings.checkoutAddressChipShipping;
  String get checkoutAddressChipDefault => _strings.checkoutAddressChipDefault;
  String get checkoutAddressChipBilling => _strings.checkoutAddressChipBilling;
  String get checkoutAddressChipInternational =>
      _strings.checkoutAddressChipInternational;
  String get checkoutAddressLabelFallback =>
      _strings.checkoutAddressLabelFallback;
  String get checkoutAddressEditAction => _strings.checkoutAddressEditAction;
  String get checkoutAddressPersonaDomesticHint =>
      _strings.checkoutAddressPersonaDomesticHint;
  String get checkoutAddressPersonaInternationalHint =>
      _strings.checkoutAddressPersonaInternationalHint;
  String get checkoutAddressFormAddTitle =>
      _strings.checkoutAddressFormAddTitle;
  String get checkoutAddressFormEditTitle =>
      _strings.checkoutAddressFormEditTitle;
  String get checkoutAddressFormDomesticLabel =>
      _strings.checkoutAddressFormDomesticLabel;
  String get checkoutAddressFormInternationalLabel =>
      _strings.checkoutAddressFormInternationalLabel;
  String get checkoutAddressFormLabelOptional =>
      _strings.checkoutAddressFormLabelOptional;
  String get checkoutAddressFormRecipient =>
      _strings.checkoutAddressFormRecipient;
  String get checkoutAddressFormCompanyOptional =>
      _strings.checkoutAddressFormCompanyOptional;
  String get checkoutAddressFormPostalCode =>
      _strings.checkoutAddressFormPostalCode;
  String get checkoutAddressFormLookup => _strings.checkoutAddressFormLookup;
  String get checkoutAddressFormState => _strings.checkoutAddressFormState;
  String get checkoutAddressFormCity => _strings.checkoutAddressFormCity;
  String get checkoutAddressFormLine1 => _strings.checkoutAddressFormLine1;
  String get checkoutAddressFormLine2Optional =>
      _strings.checkoutAddressFormLine2Optional;
  String get checkoutAddressFormCountry => _strings.checkoutAddressFormCountry;
  String get checkoutAddressFormPhone => _strings.checkoutAddressFormPhone;
  String get checkoutAddressFormDefaultTitle =>
      _strings.checkoutAddressFormDefaultTitle;
  String get checkoutAddressFormDefaultSubtitle =>
      _strings.checkoutAddressFormDefaultSubtitle;
  String get checkoutAddressFormSave => _strings.checkoutAddressFormSave;
  String get checkoutAddressFormFixErrors =>
      _strings.checkoutAddressFormFixErrors;
  String get checkoutAddressRequired => _strings.checkoutAddressRequired;
  String get checkoutAddressRecipientRequired =>
      _strings.checkoutAddressRecipientRequired;
  String get checkoutAddressLine1Required =>
      _strings.checkoutAddressLine1Required;
  String get checkoutAddressCityRequired =>
      _strings.checkoutAddressCityRequired;
  String get checkoutAddressPostalFormat =>
      _strings.checkoutAddressPostalFormat;
  String get checkoutAddressStateRequired =>
      _strings.checkoutAddressStateRequired;
  String get checkoutAddressCountryJapanRequired =>
      _strings.checkoutAddressCountryJapanRequired;
  String get checkoutAddressPhoneDomestic =>
      _strings.checkoutAddressPhoneDomestic;
  String get checkoutAddressPostalShort => _strings.checkoutAddressPostalShort;
  String get checkoutAddressCountryRequired =>
      _strings.checkoutAddressCountryRequired;
  String get checkoutAddressPhoneInternational =>
      _strings.checkoutAddressPhoneInternational;
  String get checkoutShippingMissingState =>
      _strings.checkoutShippingMissingState;
  String get checkoutShippingSelectAddress =>
      _strings.checkoutShippingSelectAddress;
  String get checkoutShippingOptionUnavailable =>
      _strings.checkoutShippingOptionUnavailable;
  String get checkoutShippingPromoRequiresExpress =>
      _strings.checkoutShippingPromoRequiresExpress;
  String get checkoutShippingBadgePopular =>
      _strings.checkoutShippingBadgePopular;
  String get checkoutShippingBadgeFastest =>
      _strings.checkoutShippingBadgeFastest;
  String get checkoutShippingBadgeTracked =>
      _strings.checkoutShippingBadgeTracked;
  String get checkoutShippingOptionDomStandardLabel =>
      _strings.checkoutShippingOptionDomStandardLabel;
  String get checkoutShippingOptionDomStandardCarrier =>
      _strings.checkoutShippingOptionDomStandardCarrier;
  String get checkoutShippingOptionDomStandardNote =>
      _strings.checkoutShippingOptionDomStandardNote;
  String get checkoutShippingOptionDomExpressLabel =>
      _strings.checkoutShippingOptionDomExpressLabel;
  String get checkoutShippingOptionDomExpressCarrier =>
      _strings.checkoutShippingOptionDomExpressCarrier;
  String get checkoutShippingOptionDomExpressNote =>
      _strings.checkoutShippingOptionDomExpressNote;
  String get checkoutShippingOptionDomPickupLabel =>
      _strings.checkoutShippingOptionDomPickupLabel;
  String get checkoutShippingOptionDomPickupCarrier =>
      _strings.checkoutShippingOptionDomPickupCarrier;
  String get checkoutShippingOptionDomPickupNote =>
      _strings.checkoutShippingOptionDomPickupNote;
  String get checkoutShippingOptionIntlExpressLabel =>
      _strings.checkoutShippingOptionIntlExpressLabel;
  String get checkoutShippingOptionIntlExpressCarrier =>
      _strings.checkoutShippingOptionIntlExpressCarrier;
  String get checkoutShippingOptionIntlExpressNote =>
      _strings.checkoutShippingOptionIntlExpressNote;
  String get checkoutShippingOptionIntlPriorityLabel =>
      _strings.checkoutShippingOptionIntlPriorityLabel;
  String get checkoutShippingOptionIntlPriorityCarrier =>
      _strings.checkoutShippingOptionIntlPriorityCarrier;
  String get checkoutShippingOptionIntlPriorityNote =>
      _strings.checkoutShippingOptionIntlPriorityNote;
  String get checkoutShippingOptionIntlEconomyLabel =>
      _strings.checkoutShippingOptionIntlEconomyLabel;
  String get checkoutShippingOptionIntlEconomyCarrier =>
      _strings.checkoutShippingOptionIntlEconomyCarrier;
  String get checkoutShippingOptionIntlEconomyNote =>
      _strings.checkoutShippingOptionIntlEconomyNote;
  String get checkoutShippingBannerInternationalDelay =>
      _strings.checkoutShippingBannerInternationalDelay;
  String get checkoutShippingBannerKyushuDelay =>
      _strings.checkoutShippingBannerKyushuDelay;
  String get shopTitle => _strings.shopTitle;
  String get shopSearchTooltip => _strings.shopSearchTooltip;
  String get shopCartTooltip => _strings.shopCartTooltip;
  String get shopAppBarSubtitle => _strings.shopAppBarSubtitle;
  String get shopActionPromotions => _strings.shopActionPromotions;
  String get shopActionGuides => _strings.shopActionGuides;
  String get shopQuickGuidesTitle => _strings.shopQuickGuidesTitle;
  String get shopQuickGuidesSubtitle => _strings.shopQuickGuidesSubtitle;
  String get shopBrowseByMaterialTitle => _strings.shopBrowseByMaterialTitle;
  String get shopBrowseByMaterialSubtitle =>
      _strings.shopBrowseByMaterialSubtitle;
  String get shopPromotionsTitle => _strings.shopPromotionsTitle;
  String get shopPromotionsSubtitle => _strings.shopPromotionsSubtitle;
  String get shopPromotionsEmpty => _strings.shopPromotionsEmpty;
  String get shopRecommendedMaterialsTitle =>
      _strings.shopRecommendedMaterialsTitle;
  String get shopRecommendedMaterialsSubtitle =>
      _strings.shopRecommendedMaterialsSubtitle;
  String get shopRecommendedMaterialsEmpty =>
      _strings.shopRecommendedMaterialsEmpty;
  String get shopHeroBadge => _strings.shopHeroBadge;
  String get shopHeroTitle => _strings.shopHeroTitle;
  String get shopHeroBody => _strings.shopHeroBody;
  String get shopHeroAction => _strings.shopHeroAction;
  String get libraryDesignDetailTitle => _strings.libraryDesignDetailTitle;
  String get libraryDesignDetailSubtitle =>
      _strings.libraryDesignDetailSubtitle;
  String get libraryDesignDetailEditTooltip =>
      _strings.libraryDesignDetailEditTooltip;
  String get libraryDesignDetailExportTooltip =>
      _strings.libraryDesignDetailExportTooltip;
  String get libraryDesignDetailTabDetails =>
      _strings.libraryDesignDetailTabDetails;
  String get libraryDesignDetailTabActivity =>
      _strings.libraryDesignDetailTabActivity;
  String get libraryDesignDetailTabFiles =>
      _strings.libraryDesignDetailTabFiles;
  String get libraryDesignDetailMetadataTitle =>
      _strings.libraryDesignDetailMetadataTitle;
  String get libraryDesignDetailUsageHistoryTitle =>
      _strings.libraryDesignDetailUsageHistoryTitle;
  String get libraryDesignDetailNoActivity =>
      _strings.libraryDesignDetailNoActivity;
  String get libraryDesignDetailFilesTitle =>
      _strings.libraryDesignDetailFilesTitle;
  String get libraryDesignDetailPreviewPngLabel =>
      _strings.libraryDesignDetailPreviewPngLabel;
  String get libraryDesignDetailVectorSvgLabel =>
      _strings.libraryDesignDetailVectorSvgLabel;
  String get libraryDesignDetailExportAction =>
      _strings.libraryDesignDetailExportAction;
  String get libraryDesignDetailUntitled =>
      _strings.libraryDesignDetailUntitled;
  String get libraryDesignDetailAiScoreUnknown =>
      _strings.libraryDesignDetailAiScoreUnknown;
  String get libraryDesignDetailRegistrabilityUnknown =>
      _strings.libraryDesignDetailRegistrabilityUnknown;
  String get libraryDesignDetailRegistrable =>
      _strings.libraryDesignDetailRegistrable;
  String get libraryDesignDetailNotRegistrable =>
      _strings.libraryDesignDetailNotRegistrable;
  String get libraryDesignDetailActionVersions =>
      _strings.libraryDesignDetailActionVersions;
  String get libraryDesignDetailActionShare =>
      _strings.libraryDesignDetailActionShare;
  String get libraryDesignDetailActionLinks =>
      _strings.libraryDesignDetailActionLinks;
  String get libraryDesignDetailActionDuplicate =>
      _strings.libraryDesignDetailActionDuplicate;
  String get libraryDesignDetailActionReorder =>
      _strings.libraryDesignDetailActionReorder;
  String get libraryDesignDetailActionArchive =>
      _strings.libraryDesignDetailActionArchive;
  String get libraryDesignDetailArchiveTitle =>
      _strings.libraryDesignDetailArchiveTitle;
  String get libraryDesignDetailArchiveBody =>
      _strings.libraryDesignDetailArchiveBody;
  String get libraryDesignDetailArchiveCancel =>
      _strings.libraryDesignDetailArchiveCancel;
  String get libraryDesignDetailArchiveConfirm =>
      _strings.libraryDesignDetailArchiveConfirm;
  String get libraryDesignDetailArchived =>
      _strings.libraryDesignDetailArchived;
  String get libraryDesignDetailReorderHint =>
      _strings.libraryDesignDetailReorderHint;
  String get libraryDesignDetailFileNotAvailable =>
      _strings.libraryDesignDetailFileNotAvailable;
  String get libraryDesignDetailMetadataDesignId =>
      _strings.libraryDesignDetailMetadataDesignId;
  String get libraryDesignDetailMetadataStatus =>
      _strings.libraryDesignDetailMetadataStatus;
  String get libraryDesignDetailMetadataAiScore =>
      _strings.libraryDesignDetailMetadataAiScore;
  String get libraryDesignDetailMetadataRegistrability =>
      _strings.libraryDesignDetailMetadataRegistrability;
  String get libraryDesignDetailMetadataCreated =>
      _strings.libraryDesignDetailMetadataCreated;
  String get libraryDesignDetailMetadataUpdated =>
      _strings.libraryDesignDetailMetadataUpdated;
  String get libraryDesignDetailMetadataLastUsed =>
      _strings.libraryDesignDetailMetadataLastUsed;
  String get libraryDesignDetailMetadataVersion =>
      _strings.libraryDesignDetailMetadataVersion;
  String get libraryDesignDetailActivityCreatedTitle =>
      _strings.libraryDesignDetailActivityCreatedTitle;
  String get libraryDesignDetailActivityUpdatedTitle =>
      _strings.libraryDesignDetailActivityUpdatedTitle;
  String get libraryDesignDetailActivityOrderedTitle =>
      _strings.libraryDesignDetailActivityOrderedTitle;
  String get libraryDesignDetailActivityCreatedDetail =>
      _strings.libraryDesignDetailActivityCreatedDetail;
  String get libraryDesignDetailActivityUpdatedDetail =>
      _strings.libraryDesignDetailActivityUpdatedDetail;
  String get libraryDesignDetailActivityOrderedDetail =>
      _strings.libraryDesignDetailActivityOrderedDetail;
  String get orderDetailTitleFallback => _strings.orderDetailTitleFallback;
  String get orderDetailTooltipReorder => _strings.orderDetailTooltipReorder;
  String get orderDetailTooltipShare => _strings.orderDetailTooltipShare;
  String get orderDetailTooltipMore => _strings.orderDetailTooltipMore;
  String get orderDetailMenuContactSupport =>
      _strings.orderDetailMenuContactSupport;
  String get orderDetailMenuCancelOrder => _strings.orderDetailMenuCancelOrder;
  String get orderDetailTabSummary => _strings.orderDetailTabSummary;
  String get orderDetailTabTimeline => _strings.orderDetailTabTimeline;
  String get orderDetailTabFiles => _strings.orderDetailTabFiles;
  String get orderDetailInvoiceRequestSent =>
      _strings.orderDetailInvoiceRequestSent;
  String get orderDetailInvoiceRequestFailed =>
      _strings.orderDetailInvoiceRequestFailed;
  String get orderDetailCancelTitle => _strings.orderDetailCancelTitle;
  String get orderDetailCancelBody => _strings.orderDetailCancelBody;
  String get orderDetailCancelConfirm => _strings.orderDetailCancelConfirm;
  String get orderDetailCancelKeep => _strings.orderDetailCancelKeep;
  String get orderDetailCancelSuccess => _strings.orderDetailCancelSuccess;
  String get orderDetailCancelFailed => _strings.orderDetailCancelFailed;
  String get orderDetailDesignPreviewOk => _strings.orderDetailDesignPreviewOk;
  String get orderDetailBannerInProgress =>
      _strings.orderDetailBannerInProgress;
  String get orderDetailBannerProduction =>
      _strings.orderDetailBannerProduction;
  String get orderDetailBannerTracking => _strings.orderDetailBannerTracking;
  String get orderDetailSectionOrder => _strings.orderDetailSectionOrder;
  String get orderDetailSectionItems => _strings.orderDetailSectionItems;
  String get orderDetailSectionTotal => _strings.orderDetailSectionTotal;
  String get orderDetailSubtotal => _strings.orderDetailSubtotal;
  String get orderDetailDiscount => _strings.orderDetailDiscount;
  String get orderDetailShipping => _strings.orderDetailShipping;
  String get orderDetailShippingFree => _strings.orderDetailShippingFree;
  String get orderDetailTax => _strings.orderDetailTax;
  String get orderDetailTotal => _strings.orderDetailTotal;
  String get orderDetailShippingAddress => _strings.orderDetailShippingAddress;
  String get orderDetailBillingAddress => _strings.orderDetailBillingAddress;
  String get orderDetailPayment => _strings.orderDetailPayment;
  String get orderDetailDesignSnapshots => _strings.orderDetailDesignSnapshots;
  String get orderDetailQuickActions => _strings.orderDetailQuickActions;
  String get orderDetailRequestInvoice => _strings.orderDetailRequestInvoice;
  String get orderDetailContactSupport => _strings.orderDetailContactSupport;
  String get orderDetailTimelineTitle => _strings.orderDetailTimelineTitle;
  String get orderDetailProductionEvents =>
      _strings.orderDetailProductionEvents;
  String get orderDetailInvoiceTitle => _strings.orderDetailInvoiceTitle;
  String get orderDetailInvoiceHint => _strings.orderDetailInvoiceHint;
  String get orderDetailInvoiceRequest => _strings.orderDetailInvoiceRequest;
  String get orderDetailInvoiceView => _strings.orderDetailInvoiceView;
  String get orderDetailPaymentPending => _strings.orderDetailPaymentPending;
  String get orderDetailPaymentPaid => _strings.orderDetailPaymentPaid;
  String get orderDetailPaymentCanceled => _strings.orderDetailPaymentCanceled;
  String get orderDetailPaymentProcessing =>
      _strings.orderDetailPaymentProcessing;
  String get orderDetailPaymentNoInfo => _strings.orderDetailPaymentNoInfo;
  String get orderDetailPaymentMethodCard =>
      _strings.orderDetailPaymentMethodCard;
  String get orderDetailPaymentMethodWallet =>
      _strings.orderDetailPaymentMethodWallet;
  String get orderDetailPaymentMethodBank =>
      _strings.orderDetailPaymentMethodBank;
  String get orderDetailPaymentMethodOther =>
      _strings.orderDetailPaymentMethodOther;
  String get orderDetailPaymentSeparator =>
      _strings.orderDetailPaymentSeparator;
  String get orderDetailStatusPending => _strings.orderDetailStatusPending;
  String get orderDetailStatusPaid => _strings.orderDetailStatusPaid;
  String get orderDetailStatusInProduction =>
      _strings.orderDetailStatusInProduction;
  String get orderDetailStatusReadyToShip =>
      _strings.orderDetailStatusReadyToShip;
  String get orderDetailStatusShipped => _strings.orderDetailStatusShipped;
  String get orderDetailStatusDelivered => _strings.orderDetailStatusDelivered;
  String get orderDetailStatusCanceled => _strings.orderDetailStatusCanceled;
  String get orderDetailStatusProcessing =>
      _strings.orderDetailStatusProcessing;
  String get orderDetailMilestonePlaced => _strings.orderDetailMilestonePlaced;
  String get orderDetailMilestonePaid => _strings.orderDetailMilestonePaid;
  String get orderDetailMilestoneProduction =>
      _strings.orderDetailMilestoneProduction;
  String get orderDetailMilestoneShipped =>
      _strings.orderDetailMilestoneShipped;
  String get orderDetailMilestoneDelivered =>
      _strings.orderDetailMilestoneDelivered;
  String get orderDetailMilestoneCanceled =>
      _strings.orderDetailMilestoneCanceled;
  String get notificationsEmptyUnreadMessage =>
      _strings.notificationsEmptyUnreadMessage;
  String get notificationsEmptyAllMessage =>
      _strings.notificationsEmptyAllMessage;
  String get notificationsEmptyTitle => _strings.notificationsEmptyTitle;
  String get notificationsRefresh => _strings.notificationsRefresh;
  String get notificationsLoadMoreHint => _strings.notificationsLoadMoreHint;
  String get notificationsMarkedRead => _strings.notificationsMarkedRead;
  String get notificationsMarkedUnread => _strings.notificationsMarkedUnread;
  String get notificationsUndo => _strings.notificationsUndo;
  String get notificationsAllCaughtUp => _strings.notificationsAllCaughtUp;
  String get notificationsMoreTooltip => _strings.notificationsMoreTooltip;
  String get notificationsMarkAllRead => _strings.notificationsMarkAllRead;
  String get notificationsFilterAll => _strings.notificationsFilterAll;
  String get notificationsFilterUnread => _strings.notificationsFilterUnread;
  String get notificationsMarkRead => _strings.notificationsMarkRead;
  String get notificationsMarkUnread => _strings.notificationsMarkUnread;
  String get notificationsToday => _strings.notificationsToday;
  String get notificationsYesterday => _strings.notificationsYesterday;
  String get notificationsCategoryOrder => _strings.notificationsCategoryOrder;
  String get notificationsCategoryDesign =>
      _strings.notificationsCategoryDesign;
  String get notificationsCategoryPromo => _strings.notificationsCategoryPromo;
  String get notificationsCategorySupport =>
      _strings.notificationsCategorySupport;
  String get notificationsCategoryStatus =>
      _strings.notificationsCategoryStatus;
  String get notificationsCategorySecurity =>
      _strings.notificationsCategorySecurity;
  String get orderReorderTitle => _strings.orderReorderTitle;
  String get orderReorderSelectItem => _strings.orderReorderSelectItem;
  String get orderReorderCartRebuilt => _strings.orderReorderCartRebuilt;
  String get orderReorderRebuildCart => _strings.orderReorderRebuildCart;
  String get orderReorderBannerOutOfStockAndPrice =>
      _strings.orderReorderBannerOutOfStockAndPrice;
  String get orderReorderBannerOutOfStock =>
      _strings.orderReorderBannerOutOfStock;
  String get orderReorderBannerPriceChanged =>
      _strings.orderReorderBannerPriceChanged;
  String get orderReorderBannerUpdates => _strings.orderReorderBannerUpdates;
  String get orderReorderDismiss => _strings.orderReorderDismiss;
  String get orderReorderItemFallback => _strings.orderReorderItemFallback;
  String get orderReorderOutOfStock => _strings.orderReorderOutOfStock;
  String get orderReorderPriceUpdated => _strings.orderReorderPriceUpdated;
  String get orderReorderLoadFailed => _strings.orderReorderLoadFailed;
  String get nameValidationSurnameRequired =>
      _strings.nameValidationSurnameRequired;
  String get nameValidationSurnameFullWidth =>
      _strings.nameValidationSurnameFullWidth;
  String get nameValidationGivenRequired =>
      _strings.nameValidationGivenRequired;
  String get nameValidationGivenFullWidth =>
      _strings.nameValidationGivenFullWidth;
  String get nameValidationSurnameKanaRequired =>
      _strings.nameValidationSurnameKanaRequired;
  String get nameValidationKanaFullWidth =>
      _strings.nameValidationKanaFullWidth;
  String get nameValidationGivenKanaRequired =>
      _strings.nameValidationGivenKanaRequired;
  String get nameValidationKanaFullWidthRecommended =>
      _strings.nameValidationKanaFullWidthRecommended;
  String get supportChatSeedGreeting => _strings.supportChatSeedGreeting;
  String get kanjiDictionaryTitle => _strings.kanjiDictionaryTitle;
  String get kanjiDictionaryToggleShowAll =>
      _strings.kanjiDictionaryToggleShowAll;
  String get kanjiDictionaryToggleShowFavorites =>
      _strings.kanjiDictionaryToggleShowFavorites;
  String get kanjiDictionaryOpenGuides => _strings.kanjiDictionaryOpenGuides;
  String get kanjiDictionarySearchHint => _strings.kanjiDictionarySearchHint;
  String get kanjiDictionaryHistoryHint => _strings.kanjiDictionaryHistoryHint;
  String get kanjiDictionaryHistoryTitle =>
      _strings.kanjiDictionaryHistoryTitle;
  String get kanjiDictionaryFiltersTitle =>
      _strings.kanjiDictionaryFiltersTitle;
  String get kanjiDictionaryGradesAll => _strings.kanjiDictionaryGradesAll;
  String get kanjiDictionaryGrade1 => _strings.kanjiDictionaryGrade1;
  String get kanjiDictionaryGrade2 => _strings.kanjiDictionaryGrade2;
  String get kanjiDictionaryGrade3 => _strings.kanjiDictionaryGrade3;
  String get kanjiDictionaryGrade4 => _strings.kanjiDictionaryGrade4;
  String get kanjiDictionaryGrade5 => _strings.kanjiDictionaryGrade5;
  String get kanjiDictionaryGrade6 => _strings.kanjiDictionaryGrade6;
  String get kanjiDictionaryStrokesAll => _strings.kanjiDictionaryStrokesAll;
  String get kanjiDictionaryRadicalAny => _strings.kanjiDictionaryRadicalAny;
  String get kanjiDictionaryRadicalWater =>
      _strings.kanjiDictionaryRadicalWater;
  String get kanjiDictionaryRadicalSun => _strings.kanjiDictionaryRadicalSun;
  String get kanjiDictionaryRadicalPlant =>
      _strings.kanjiDictionaryRadicalPlant;
  String get kanjiDictionaryRadicalHeart =>
      _strings.kanjiDictionaryRadicalHeart;
  String get kanjiDictionaryRadicalEarth =>
      _strings.kanjiDictionaryRadicalEarth;
  String get kanjiDictionaryFavorite => _strings.kanjiDictionaryFavorite;
  String get kanjiDictionaryUnfavorite => _strings.kanjiDictionaryUnfavorite;
  String get kanjiDictionaryDetails => _strings.kanjiDictionaryDetails;
  String get kanjiDictionaryStrokeOrderTitle =>
      _strings.kanjiDictionaryStrokeOrderTitle;
  String get kanjiDictionaryExamplesTitle =>
      _strings.kanjiDictionaryExamplesTitle;
  String get kanjiDictionaryInsertIntoNameInput =>
      _strings.kanjiDictionaryInsertIntoNameInput;
  String get kanjiDictionaryDone => _strings.kanjiDictionaryDone;
  String get kanjiDictionaryExampleUsage =>
      _strings.kanjiDictionaryExampleUsage;
  String get kanjiDictionaryNoStrokeData =>
      _strings.kanjiDictionaryNoStrokeData;
  String get orderInvoiceTitle => _strings.orderInvoiceTitle;
  String get orderInvoiceShareTooltip => _strings.orderInvoiceShareTooltip;
  String get orderInvoiceLoadFailed => _strings.orderInvoiceLoadFailed;
  String get orderInvoiceDownloadPdf => _strings.orderInvoiceDownloadPdf;
  String get orderInvoiceSendEmail => _strings.orderInvoiceSendEmail;
  String get orderInvoiceContactSupport => _strings.orderInvoiceContactSupport;
  String get orderInvoiceTotalLabel => _strings.orderInvoiceTotalLabel;
  String get orderInvoiceStatusAvailable =>
      _strings.orderInvoiceStatusAvailable;
  String get orderInvoiceStatusPending => _strings.orderInvoiceStatusPending;
  String get orderInvoiceTaxable => _strings.orderInvoiceTaxable;
  String get orderInvoiceTaxExempt => _strings.orderInvoiceTaxExempt;
  String get orderInvoicePreviewTitle => _strings.orderInvoicePreviewTitle;
  String get orderInvoiceRefreshTooltip => _strings.orderInvoiceRefreshTooltip;
  String get orderInvoicePendingBody => _strings.orderInvoicePendingBody;
  String get orderInvoiceUnavailableBody =>
      _strings.orderInvoiceUnavailableBody;
  String get orderInvoiceRequestAction => _strings.orderInvoiceRequestAction;
  String get orderInvoiceSaveFailed => _strings.orderInvoiceSaveFailed;
  String get designVersionsRollbackBody => _strings.designVersionsRollbackBody;
  String get orderProductionTitle => _strings.orderProductionTitle;
  String get orderProductionRefreshTooltip =>
      _strings.orderProductionRefreshTooltip;
  String get orderProductionDelayedMessage =>
      _strings.orderProductionDelayedMessage;
  String get orderProductionTimelineTitle =>
      _strings.orderProductionTimelineTitle;
  String get orderProductionNoEventsTitle =>
      _strings.orderProductionNoEventsTitle;
  String get orderProductionNoEventsMessage =>
      _strings.orderProductionNoEventsMessage;
  String get orderProductionNoEventsAction =>
      _strings.orderProductionNoEventsAction;
  String get orderProductionHealthOnTrack =>
      _strings.orderProductionHealthOnTrack;
  String get orderProductionHealthAttention =>
      _strings.orderProductionHealthAttention;
  String get orderProductionHealthDelayed =>
      _strings.orderProductionHealthDelayed;
  String get orderProductionEventQueued => _strings.orderProductionEventQueued;
  String get orderProductionEventEngraving =>
      _strings.orderProductionEventEngraving;
  String get orderProductionEventPolishing =>
      _strings.orderProductionEventPolishing;
  String get orderProductionEventQualityCheck =>
      _strings.orderProductionEventQualityCheck;
  String get orderProductionEventPacked => _strings.orderProductionEventPacked;
  String get orderProductionEventOnHold => _strings.orderProductionEventOnHold;
  String get orderProductionEventRework => _strings.orderProductionEventRework;
  String get orderProductionEventCanceled =>
      _strings.orderProductionEventCanceled;

  String commonVersionLabel(String version) {
    final template = _strings.commonVersionLabel;
    return template.replaceAll('{version}', version);
  }

  String commonSizeMillimeters(String size) {
    final template = _strings.commonSizeMillimeters;
    return template.replaceAll('{size}', size);
  }

  String commonPercentLabel(String percent) {
    final template = _strings.commonPercentLabel;
    return template.replaceAll('{percent}', percent);
  }

  String commonPercentDiscountLabel(String percent) {
    final template = _strings.commonPercentDiscountLabel;
    return template.replaceAll('{percent}', percent);
  }

  String notificationsUnreadCount(int count) {
    final template = _strings.notificationsUnreadCount;
    return template.replaceAll('{count}', '$count');
  }

  String orderReorderFromOrder(String orderNumber) {
    final template = _strings.orderReorderFromOrder;
    return template.replaceAll('{order}', orderNumber);
  }

  String orderReorderSelectedCount(int selected, int total) {
    final template = _strings.orderReorderSelectedCount;
    return template
        .replaceAll('{selected}', selected.toString())
        .replaceAll('{total}', total.toString());
  }

  String orderReorderDesignLabel(String label) {
    final template = _strings.orderReorderDesignLabel;
    return template.replaceAll('{label}', label);
  }

  String profileExportTimeMinutes(int count) {
    final template = count == 1
        ? _strings.profileExportTimeMinute
        : _strings.profileExportTimeMinutes;
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeHours(int count) {
    final template = count == 1
        ? _strings.profileExportTimeHour
        : _strings.profileExportTimeHours;
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeDays(int count) {
    final template = count == 1
        ? _strings.profileExportTimeDay
        : _strings.profileExportTimeDays;
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeDate(DateTime dateTime) {
    final template = _strings.profileExportTimeDate;
    final isJa = _strings is AppLocalizationsJa;
    String two(int value) => value.toString().padLeft(2, '0');
    final date = isJa
        ? '${dateTime.year}/${two(dateTime.month)}/${two(dateTime.day)}'
        : '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
    return template.replaceAll('{date}', date);
  }

  String profileExportTimeCompactMinutes(int count) {
    final template = count == 1
        ? _strings.profileExportTimeCompactMinute
        : _strings.profileExportTimeCompactMinutes;
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeCompactHours(int count) {
    final template = count == 1
        ? _strings.profileExportTimeCompactHour
        : _strings.profileExportTimeCompactHours;
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeCompactDays(int count) {
    final template = count == 1
        ? _strings.profileExportTimeCompactDay
        : _strings.profileExportTimeCompactDays;
    return template.replaceAll('{count}', '$count');
  }

  String offlineLastSyncLabel(String date, String time) {
    final template = _strings.offlineLastSyncLabel;
    return template.replaceAll('{date}', date).replaceAll('{time}', time);
  }

  String homeDesignSummary({
    required String shape,
    required String size,
    required String style,
  }) {
    final template = _strings.homeDesignSummary;
    return template
        .replaceAll('{shape}', shape)
        .replaceAll('{size}', size)
        .replaceAll('{style}', style);
  }

  String homeDesignAiCheckLabel(String diagnostic) {
    final template = _strings.homeDesignAiCheckLabel;
    return template.replaceAll('{diagnostic}', diagnostic);
  }

  String homeTemplateLabel({required String shape, required String style}) {
    final template = _strings.homeTemplateLabel;
    return template.replaceAll('{shape}', shape).replaceAll('{style}', style);
  }

  String homeTemplateRecommendedSize(String size) {
    final template = _strings.homeTemplateRecommendedSize;
    return template.replaceAll('{size}', size);
  }

  String topBarNotificationsLabelWithUnread(int count) {
    final template = _strings.topBarNotificationsLabelWithUnread;
    return template.replaceAll('{count}', '$count');
  }

  String topBarNotificationsTooltipWithUnread(int count) {
    final template = _strings.topBarNotificationsTooltipWithUnread;
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRollbackTitle(String version) {
    final template = _strings.designVersionsRollbackTitle;
    return template.replaceAll('{version}', version);
  }

  String designVersionsCurrentLabel(String version) {
    final template = _strings.designVersionsCurrentLabel;
    return template.replaceAll('{version}', version);
  }

  String designVersionsCompareTargetLabel(String version) {
    final template = _strings.designVersionsCompareTargetLabel;
    return template.replaceAll('{version}', version);
  }

  String designVersionsTemplateLabel(String templateValue) {
    final template = _strings.designVersionsTemplateLabel;
    return template.replaceAll('{template}', templateValue);
  }

  String designVersionsRelativeMinutes(int count) {
    final template = count == 1
        ? _strings.designVersionsRelativeMinute
        : _strings.designVersionsRelativeMinutes;
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeHours(int count) {
    final template = count == 1
        ? _strings.designVersionsRelativeHour
        : _strings.designVersionsRelativeHours;
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeDays(int count) {
    final template = count == 1
        ? _strings.designVersionsRelativeDay
        : _strings.designVersionsRelativeDays;
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return _strings.designVersionsRelativeNow;
    if (diff.inMinutes < 60) {
      return designVersionsRelativeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) return designVersionsRelativeHours(diff.inHours);
    return designVersionsRelativeDays(diff.inDays);
  }

  String libraryDesignDetailAiScoreLabel(String score) {
    final template = _strings.libraryDesignDetailAiScoreLabel;
    return template.replaceAll('{score}', score);
  }

  String libraryDesignDetailHydrateFailed(String error) {
    final template = _strings.libraryDesignDetailHydrateFailed;
    return template.replaceAll('{error}', error);
  }

  String orderDetailShareText(String number) {
    final template = _strings.orderDetailShareText;
    return template.replaceAll('{number}', number);
  }

  String orderDetailItemQtyLabel(int quantity) {
    final template = _strings.orderDetailItemQtyLabel;
    return template.replaceAll('{quantity}', '$quantity');
  }

  String orderDetailPaymentPaidAt(String date) {
    final template = _strings.orderDetailPaymentPaidAt;
    return template.replaceAll('{date}', date);
  }

  String orderDetailMeta(String id, String date) {
    final template = _strings.orderDetailMeta;
    return template.replaceAll('{id}', id).replaceAll('{date}', date);
  }

  String kanjiDictionaryStrokeCount(int count) {
    final template = count == 1
        ? _strings.kanjiDictionaryStrokeCountOne
        : _strings.kanjiDictionaryStrokeCount;
    return template.replaceAll('{count}', '$count');
  }

  String kanjiDictionaryRadicalLabel(String radical) {
    final template = _strings.kanjiDictionaryRadicalLabel;
    return template.replaceAll('{radical}', radical);
  }

  String kanjiDictionaryChipStrokes(int count) {
    final template = count == 1
        ? _strings.kanjiDictionaryChipStrokesOne
        : _strings.kanjiDictionaryChipStrokes;
    return template.replaceAll('{count}', '$count');
  }

  String kanjiDictionaryChipRadical(String radical) {
    final template = _strings.kanjiDictionaryChipRadical;
    return template.replaceAll('{radical}', radical);
  }

  String kanjiDictionaryStrokeOrderPrefix(String steps) {
    final template = _strings.kanjiDictionaryStrokeOrderPrefix;
    return template.replaceAll('{steps}', steps);
  }

  String orderInvoiceSavedTo(String path) {
    final template = _strings.orderInvoiceSavedTo;
    return template.replaceAll('{path}', path);
  }

  String orderInvoiceShareText({required String app, required String number}) {
    final template = _strings.orderInvoiceShareText;
    return template.replaceAll('{app}', app).replaceAll('{number}', number);
  }

  String orderInvoiceOrderLabel(String number) {
    final template = _strings.orderInvoiceOrderLabel;
    return template.replaceAll('{number}', number);
  }

  String orderInvoiceIssuedLabel(String date) {
    final template = _strings.orderInvoiceIssuedLabel;
    return template.replaceAll('{date}', date);
  }

  String checkoutPaymentExpires(int month, int year) {
    final template = _strings.checkoutPaymentExpires;
    return template
        .replaceAll('{month}', '$month')
        .replaceAll('{year}', '$year');
  }

  String cartPromoShipfreeShortfall(int amount) {
    final template = _strings.cartPromoShipfreeShortfall;
    return template.replaceAll('{amount}', amount.toString());
  }

  String cartRemovedItem(String item) {
    final template = _strings.cartRemovedItem;
    return template.replaceAll('{item}', item);
  }

  String cartPromoApplied(String label) {
    final template = _strings.cartPromoApplied;
    return template.replaceAll('{label}', label);
  }

  String cartLeadTimeLabel(int minDays, int maxDays) {
    final template = _strings.cartLeadTimeLabel;
    return template
        .replaceAll('{min}', minDays.toString())
        .replaceAll('{max}', maxDays.toString());
  }

  String cartSummaryItems(int count) {
    final template = count == 1
        ? _strings.cartSummaryItem
        : _strings.cartSummaryItems;
    return template.replaceAll('{count}', count.toString());
  }

  String cartSummaryEstimate(int minDays, int maxDays, String method) {
    final template = _strings.cartSummaryEstimate;
    return template
        .replaceAll('{min}', minDays.toString())
        .replaceAll('{max}', maxDays.toString())
        .replaceAll('{method}', method);
  }

  String orderProductionStatusLabel(String status) {
    final template = _strings.orderProductionStatusLabel;
    return template.replaceAll('{status}', status);
  }

  String orderProductionEtaLabel(String date) {
    final template = _strings.orderProductionEtaLabel;
    return template.replaceAll('{date}', date);
  }

  String orderProductionEventStation(String station) {
    final template = _strings.orderProductionEventStation;
    return template.replaceAll('{station}', station);
  }

  String orderProductionEventQc(String details) {
    final template = _strings.orderProductionEventQc;
    return template.replaceAll('{details}', details);
  }

  String appUpdateCurrentVersion(String version) {
    final template = _strings.appUpdateCurrentVersion;
    return template.replaceAll('{version}', version);
  }

  String appUpdateMinimumVersion(String version) {
    final template = _strings.appUpdateMinimumVersion;
    return template.replaceAll('{version}', version);
  }

  String appUpdateLatestVersion(String version) {
    final template = _strings.appUpdateLatestVersion;
    return template.replaceAll('{version}', version);
  }

  String appUpdateReminder(String version) {
    final template = _strings.appUpdateReminder;
    return template.replaceAll('{version}', version);
  }

  String onboardingStepCount(int current, int total) {
    final template = _strings.onboardingStepCount;
    return template
        .replaceAll('{current}', '$current')
        .replaceAll('{total}', '$total');
  }

  String profileLocaleCurrencyAutoHint(String currency) {
    final template = _strings.profileLocaleCurrencyAutoHint;
    return template.replaceAll('{currency}', currency);
  }

  String authErrorLink(String providers) {
    final template = _strings.authErrorLink;
    return template.replaceAll('{providers}', providers);
  }

  String authLinkPrompt(String providers) {
    final template = _strings.authLinkPrompt;
    return template.replaceAll('{providers}', providers);
  }

  String localeDescription(String deviceTag) {
    final template = _strings.localeDescription;
    return template.replaceAll('{device}', deviceTag);
  }
}

abstract class AppLocalizationsStrings {
  const AppLocalizationsStrings();

  String get appTitle;

  String get welcomeHeadline;

  String get welcomeBody;

  String get primaryAction;

  String get secondaryAction;

  String get onboardingTitle;

  String get onboardingSkip;

  String get onboardingNext;

  String get onboardingBack;

  String get onboardingFinish;

  String get onboardingRetry;

  String get onboardingErrorTitle;

  String get onboardingStepCount;

  String get onboardingSlideCreateTitle;

  String get onboardingSlideCreateBody;

  String get onboardingSlideCreateTagline;

  String get onboardingSlideMaterialsTitle;

  String get onboardingSlideMaterialsBody;

  String get onboardingSlideMaterialsTagline;

  String get onboardingSlideSupportTitle;

  String get onboardingSlideSupportBody;

  String get onboardingSlideSupportTagline;

  String get localeTitle;

  String get localeSave;

  String get localeSubtitle;

  String get localeDescription;

  String get localeContinue;

  String get localeUseDevice;

  String get personaTitle;

  String get personaSave;

  String get personaSubtitle;

  String get personaDescription;

  String get personaContinue;

  String get personaUseSelected;

  String get authTitle;

  String get authSubtitle;

  String get authBody;

  String get authEmailLabel;

  String get authEmailHelper;

  String get authEmailRequired;

  String get authEmailInvalid;

  String get authPasswordLabel;

  String get authPasswordHelper;

  String get authPasswordTooShort;

  String get authEmailCta;

  String get authAppleButton;

  String get authGoogleButton;

  String get authGuestCta;

  String get authGuestNote;

  String get authHelpTooltip;

  String get authHelpTitle;

  String get authHelpBody;

  String get authErrorCancelled;

  String get authErrorNetwork;

  String get authErrorInvalid;

  String get authErrorWrongPassword;

  String get authErrorWeakPassword;

  String get authErrorAppleUnavailable;

  String get authErrorLink;

  String get authErrorUnknown;

  String get authLinkingTitle;

  String get authLinkPrompt;

  String get authProviderUnknown;

  String get authProviderGoogle;

  String get authProviderApple;

  String get authProviderEmail;

  String get profileTitle;

  String get profileAvatarUpdateTooltip;

  String get profileAvatarUpdateTitle;

  String get profileAvatarUpdateBody;

  String get profileAvatarUpdateOk;

  String get profileLoadFailedTitle;

  String get profileLoadFailedMessage;

  String get profileRetry;

  String get profileStatusSignedOut;

  String get profileStatusGuest;

  String get profileStatusMember;

  String get profileFallbackGuestName;

  String get profileFallbackProfileName;

  String get profilePersonaTitle;

  String get profilePersonaSubtitle;

  String get profilePersonaJapanese;

  String get profilePersonaForeigner;

  String get profileQuickLinksTitle;

  String get profileQuickOrdersTitle;

  String get profileQuickOrdersSubtitle;

  String get profileQuickLibraryTitle;

  String get profileQuickLibrarySubtitle;

  String get profileSettingsTitle;

  String get profileAddressesTitle;

  String get profileAddressesSubtitle;

  String get profilePaymentsTitle;

  String get profilePaymentsSubtitle;

  String get paymentMethodErrorLast4;

  String get paymentMethodErrorExpMonth;

  String get paymentMethodErrorExpYear;

  String get paymentMethodErrorFixFields;

  String get paymentMethodAddFailed;

  String get paymentMethodSheetTitle;

  String get paymentMethodSheetCard;

  String get paymentMethodSheetWallet;

  String get paymentMethodSheetBrandLabel;

  String get paymentMethodSheetLast4Label;

  String get paymentMethodSheetExpMonthLabel;

  String get paymentMethodSheetExpYearLabel;

  String get paymentMethodSheetBillingNameLabel;

  String get paymentMethodSheetSave;

  String get profileNotificationsTitle;

  String get profileNotificationsSubtitle;

  String get profileNotificationsHeader;

  String get profileNotificationsPushHeader;

  String get profileNotificationsEmailHeader;

  String get profileNotificationsDigestHeader;

  String get profileNotificationsDigestHelper;

  String get profileNotificationsDigestDaily;

  String get profileNotificationsDigestWeekly;

  String get profileNotificationsDigestMonthly;

  String get profileNotificationsSave;

  String get profileNotificationsReset;

  String get profileNotificationsSaved;

  String get profileNotificationsSaveFailed;

  String get profileNotificationsLoadFailedTitle;

  String get profileNotificationsCategoryOrdersTitle;

  String get profileNotificationsCategoryOrdersBody;

  String get profileNotificationsCategoryDesignsTitle;

  String get profileNotificationsCategoryDesignsBody;

  String get profileNotificationsCategoryPromosTitle;

  String get profileNotificationsCategoryPromosBody;

  String get profileNotificationsCategoryGuidesTitle;

  String get profileNotificationsCategoryGuidesBody;

  String get profileLocaleTitle;

  String get profileLocaleSubtitle;

  String get profileLocaleLanguageHeader;

  String get profileLocaleLanguageHelper;

  String get profileLocaleCurrencyHeader;

  String get profileLocaleCurrencyHelper;

  String get profileLocaleCurrencyAuto;

  String get profileLocaleCurrencyAutoHint;

  String get profileLocaleCurrencyJpy;

  String get profileLocaleCurrencyUsd;

  String get profileLocaleSave;

  String get profileLocaleSaved;

  String get profileLocaleSaveFailed;

  String get profileLocaleUseDevice;

  String get profileLegalTitle;

  String get profileLegalSubtitle;

  String get profileLegalDownloadTooltip;

  String get profileLegalDownloadComplete;

  String get profileLegalDownloadFailed;

  String get profileLegalLoadFailedTitle;

  String get profileLegalDocumentsTitle;

  String get profileLegalContentTitle;

  String get profileLegalOpenInBrowser;

  String get profileLegalVersionUnknown;

  String get profileLegalNoDocument;

  String get profileLegalUnavailable;

  String get profileLegalNoContent;

  String get profileSupportTitle;

  String get profileSupportSubtitle;

  String get supportChatConnectedAgent;

  String get supportChatAgentGreeting;

  String get supportChatBotHandoff;

  String get supportChatBotDelivery;

  String get supportChatBotOrderStatus;

  String get supportChatBotFallback;

  String get supportChatAgentRefund;

  String get supportChatAgentAddress;

  String get supportChatAgentFallback;

  String get profileGuidesTitle;

  String get profileGuidesSubtitle;

  String get profileHowtoTitle;

  String get profileHowtoSubtitle;

  String get profileLinkedAccountsTitle;

  String get profileLinkedAccountsSubtitle;

  String get profileLinkedAccountsHeader;

  String get profileLinkedAccountsAddTooltip;

  String get profileLinkedAccountsLoadFailedTitle;

  String get profileLinkedAccountsSignedOutTitle;

  String get profileLinkedAccountsSignedOutBody;

  String get profileLinkedAccountsSignIn;

  String get profileLinkedAccountsBannerTitle;

  String get profileLinkedAccountsBannerBody;

  String get profileLinkedAccountsBannerBodyLong;

  String get profileLinkedAccountsBannerAction;

  String get profileLinkedAccountsConnected;

  String get profileLinkedAccountsNotConnected;

  String get profileLinkedAccountsProviderFallback;

  String get profileLinkedAccountsAutoSignIn;

  String get profileLinkedAccountsNotConnectedHelper;

  String get profileLinkedAccountsUnlink;

  String get profileLinkedAccountsUnlinkTitle;

  String get profileLinkedAccountsUnlinkBody;

  String get profileLinkedAccountsUnlinkConfirm;

  String get profileLinkedAccountsCancel;

  String get profileLinkedAccountsUnlinkDisabled;

  String get profileLinkedAccountsSave;

  String get profileLinkedAccountsSaved;

  String get profileLinkedAccountsSaveFailed;

  String get profileLinkedAccountsLinked;

  String get profileLinkedAccountsLinkFailed;

  String get profileLinkedAccountsUnlinked;

  String get profileLinkedAccountsUnlinkFailed;

  String get profileLinkedAccountsLinkTitle;

  String get profileLinkedAccountsLinkSubtitle;

  String get profileLinkedAccountsAlreadyLinked;

  String get profileLinkedAccountsFooter;

  String get profileLinkedAccountsOk;

  String get profileExportTitle;

  String get profileExportSubtitle;

  String get profileExportAppBarSubtitle;

  String get profileExportSummaryTitle;

  String get profileExportSummaryBody;

  String get profileExportIncludeAssetsTitle;

  String get profileExportIncludeAssetsSubtitle;

  String get profileExportIncludeOrdersTitle;

  String get profileExportIncludeOrdersSubtitle;

  String get profileExportIncludeHistoryTitle;

  String get profileExportIncludeHistorySubtitle;

  String get profileExportPermissionTitle;

  String get profileExportPermissionBody;

  String get profileExportPermissionCta;

  String get permissionsTitle;

  String get permissionsSubtitle;

  String get permissionsHeroTitle;

  String get permissionsHeroBody;

  String get permissionsPersonaDomestic;

  String get permissionsPersonaInternational;

  String get permissionsPhotosTitle;

  String get permissionsPhotosBody;

  String get permissionsPhotosAssist1;

  String get permissionsPhotosAssist2;

  String get permissionsStorageTitle;

  String get permissionsStorageBody;

  String get permissionsStorageAssist1;

  String get permissionsStorageAssist2;

  String get permissionsNotificationsTitle;

  String get permissionsNotificationsBody;

  String get permissionsNotificationsAssist1;

  String get permissionsNotificationsAssist2;

  String get permissionsStatusGranted;

  String get permissionsStatusDenied;

  String get permissionsStatusRestricted;

  String get permissionsStatusUnknown;

  String get permissionsFallbackPhotos;

  String get permissionsFallbackStorage;

  String get permissionsFallbackNotifications;

  String get permissionsCtaGrantAll;

  String get permissionsCtaNotNow;

  String get permissionsFooterPolicy;

  String get permissionsItemActionAllow;

  String get profileExportStatusReadyTitle;

  String get profileExportStatusReadyBody;

  String get profileExportStatusInProgressTitle;

  String get profileExportStatusInProgressBody;

  String get profileExportStatusDoneTitle;

  String get profileExportStatusDoneBody;

  String get profileExportCtaStart;

  String get profileExportCtaHistory;

  String get profileExportHistoryTitle;

  String get profileExportHistoryEmptyTitle;

  String get profileExportHistoryEmptyBody;

  String get profileExportHistoryDownload;

  String get profileExportErrorTitle;

  String get profileExportErrorBody;

  String get profileExportRetry;

  String get profileExportTimeJustNow;

  String get profileExportTimeMinutes;

  String get profileExportTimeHours;

  String get profileExportTimeDays;

  String get profileExportTimeDate;

  String get profileExportTimeCompactNow;

  String get profileExportTimeCompactMinutes;

  String get profileExportTimeCompactHours;

  String get profileExportTimeCompactDays;

  String get profileDeleteTitle;

  String get profileDeleteSubtitle;

  String get profileDeleteWarningTitle;

  String get profileDeleteWarningBody;

  String get profileDeleteAcknowledgementTitle;

  String get profileDeleteAckDataLossTitle;

  String get profileDeleteAckDataLossBody;

  String get profileDeleteAckOrdersTitle;

  String get profileDeleteAckOrdersBody;

  String get profileDeleteAckIrreversibleTitle;

  String get profileDeleteAckIrreversibleBody;

  String get profileDeleteFooterNote;

  String get profileDeleteCta;

  String get profileDeleteCancelCta;

  String get profileDeleteConfirmTitle;

  String get profileDeleteConfirmBody;

  String get profileDeleteConfirmAction;

  String get profileDeleteConfirmCancel;

  String get profileDeleteSuccess;

  String get profileDeleteError;

  String get profileDeleteErrorTitle;

  String get profileDeleteErrorBody;

  String get profileDeleteRetry;

  String get profileSignInCta;

  String get profileAccountSecurityTitle;

  String get profileAccountSecuritySubtitle;

  String get profileAccountSecurityBody;

  String get appUpdateTitle;

  String get appUpdateCheckAgain;

  String get appUpdateChecking;

  String get appUpdateVerifyFailedTitle;

  String get appUpdateRetry;

  String get appUpdateBannerRequired;

  String get appUpdateBannerOptional;

  String get appUpdateBannerAction;

  String get appUpdateCardRequiredTitle;

  String get appUpdateCardOptionalTitle;

  String get appUpdateCurrentVersion;

  String get appUpdateMinimumVersion;

  String get appUpdateLatestVersion;

  String get appUpdateNow;

  String get appUpdateOpenStore;

  String get appUpdateContinue;

  String get appUpdateStoreUnavailable;

  String get appUpdateStoreOpenFailed;

  String get appUpdateReminder;

  String get appUpdateLater;

  String get commonBack;

  String get commonRetry;

  String get commonClose;

  String get commonSave;

  String get commonLearnMore;

  String get commonLoadMore;

  String get commonClear;

  String get commonLoadFailed;

  String get commonUnknown;

  String get offlineTitle;

  String get offlineMessage;

  String get offlineRetry;

  String get offlineOpenCachedLibrary;

  String get offlineCacheHint;

  String get offlineLastSyncUnavailable;

  String get offlineLastSyncLabel;

  String get changelogTitle;

  String get changelogLatestReleaseTooltip;

  String get changelogHighlightsTitle;

  String get changelogAllUpdates;

  String get changelogMajorOnly;

  String get changelogUnableToLoad;

  String get changelogNoUpdatesTitle;

  String get changelogNoUpdatesMessage;

  String get changelogVersionHistoryTitle;

  String get changelogVersionHistorySubtitle;

  String get searchHintText;

  String get searchVoiceTooltip;

  String get searchVoiceComingSoon;

  String get searchRecentTitle;

  String get searchSuggestionsTitle;

  String get searchSuggestionsLoadFailed;

  String get searchResultsErrorTitle;

  String get searchResultsEmptyTitle;

  String get searchResultsEmptyMessage;

  String get homeTitle;

  String get homeSearchTooltip;

  String get homeNotificationsTooltip;

  String get homeFeaturedTitle;

  String get homeFeaturedSubtitle;

  String get homeFeaturedEmpty;

  String get homeRecentTitle;

  String get homeRecentSubtitle;

  String get homeRecentActionLabel;

  String get homeRecentEmpty;

  String get homeRecommendedTitle;

  String get homeRecommendedSubtitle;

  String get homeRecommendedLoading;

  String get homeStatusDraft;

  String get homeStatusReady;

  String get homeStatusOrdered;

  String get homeStatusLocked;

  String get homeShapeRound;

  String get homeShapeSquare;

  String get homeWritingTensho;

  String get homeWritingReisho;

  String get homeWritingKaisho;

  String get homeWritingGyosho;

  String get homeWritingKoentai;

  String get homeWritingCustom;

  String get homeNameUnset;

  String get homeDesignSummary;

  String get homeDesignAiCheckDone;

  String get homeDesignAiCheckLabel;

  String get homeDesignAiCheckNotRun;

  String get homeTemplateLabel;

  String get homeTemplateRecommendedSize;

  String get homeTemplateApply;

  String get homeLoadFailed;

  String get topBarSearchLabel;

  String get topBarSearchHint;

  String get topBarSearchTooltip;

  String get topBarHelpLabel;

  String get topBarHelpHint;

  String get topBarHelpTooltip;

  String get topBarNotificationsLabel;

  String get topBarNotificationsLabelWithUnread;

  String get topBarNotificationsTooltip;

  String get topBarNotificationsTooltipWithUnread;

  String get topBarHelpOverlayTitle;

  String get topBarHelpOverlayPrimaryAction;

  String get topBarHelpOverlaySecondaryAction;

  String get topBarHelpOverlayBody;

  String get topBarShortcutSearchLabel;

  String get topBarShortcutHelpLabel;

  String get topBarShortcutNotificationsLabel;

  String get topBarHelpLinkFaqTitle;

  String get topBarHelpLinkFaqSubtitle;

  String get topBarHelpLinkChatTitle;

  String get topBarHelpLinkChatSubtitle;

  String get topBarHelpLinkContactTitle;

  String get topBarHelpLinkContactSubtitle;

  String get splashLoading;

  String get splashFailedTitle;

  String get splashFailedMessage;

  String get designVersionsTitle;

  String get designVersionsShowDiffTooltip;

  String get designVersionsSecondaryDuplicate;

  String get designVersionsTimelineTitle;

  String get designVersionsRefreshTooltip;

  String get designVersionsAuditLogTitle;

  String get designVersionsNoAuditTitle;

  String get designVersionsNoAuditMessage;

  String get designVersionsRollbackTitle;

  String get designVersionsRollbackBody;

  String get designVersionsRollbackAction;

  String get designVersionsRollbackCancel;

  String get designVersionsCurrentLabel;

  String get designVersionsNoDiffSummary;

  String get designVersionsCompareTargetLabel;

  String get designVersionsLatestLabel;

  String get designVersionsRollbackButton;

  String get designVersionsPreviewCurrent;

  String get designVersionsPreviewTarget;

  String get designVersionsInitialFallback;

  String get designVersionsUnset;

  String get designVersionsAutoLayout;

  String get designVersionsNoDiffTitle;

  String get designVersionsNoDiffMessage;

  String get designVersionsChangeHistoryEmpty;

  String get designVersionsTemplateLabel;

  String get designVersionsStatusCurrent;

  String get designVersionsStatusComparing;

  String get designVersionsStatusHistory;

  String get designVersionsLoadFailedTitle;

  String get designVersionsSimilarityLabel;

  String get designVersionsRelativeNow;

  String get designVersionsRelativeMinutes;

  String get designVersionsRelativeHours;

  String get designVersionsRelativeDays;

  String get checkoutPaymentTitle;

  String get checkoutPaymentAddTooltip;

  String get checkoutPaymentLoadFailedTitle;

  String get checkoutPaymentEmptyTitle;

  String get checkoutPaymentEmptyBody;

  String get checkoutPaymentSignInHint;

  String get checkoutPaymentAddMethod;

  String get checkoutPaymentChooseSaved;

  String get checkoutPaymentAddAnother;

  String get checkoutPaymentContinueReview;

  String get checkoutPaymentAddFailed;

  String get checkoutPaymentMethodCard;

  String get checkoutPaymentMethodWallet;

  String get checkoutPaymentMethodBank;

  String get checkoutPaymentMethodFallback;

  String get checkoutPaymentExpires;

  String get cartPromoEnterCode;

  String get cartPromoAddItemsRequired;

  String get cartPromoField10Label;

  String get cartPromoField10Description;

  String get cartPromoShipfreeShortfall;

  String get cartPromoShipfreeLabel;

  String get cartPromoInkLabel;

  String get cartPromoInkDescription;

  String get cartPromoInvalid;

  String get cartLineTitaniumTitle;

  String get cartLineTitaniumVariant;

  String get cartLineTitaniumDesign;

  String get cartLineTitaniumAddonSleeveLabel;

  String get cartLineTitaniumAddonSleeveDescription;

  String get cartLineTitaniumAddonSleeveBadge;

  String get cartLineTitaniumAddonDeepLabel;

  String get cartLineTitaniumAddonDeepDescription;

  String get cartLineTitaniumAddonWrapLabel;

  String get cartLineTitaniumAddonWrapDescription;

  String get cartLineTitaniumNoteIntl;

  String get cartLineTitaniumNoteDomestic;

  String get cartLineTitaniumRibbon;

  String get cartLineAcrylicTitle;

  String get cartLineAcrylicVariant;

  String get cartLineAcrylicDesign;

  String get cartLineAcrylicAddonUvLabel;

  String get cartLineAcrylicAddonUvDescription;

  String get cartLineAcrylicAddonUvBadge;

  String get cartLineAcrylicAddonInkLabel;

  String get cartLineAcrylicAddonInkDescription;

  String get cartLineAcrylicAddonPouchLabel;

  String get cartLineAcrylicAddonPouchDescription;

  String get cartLineAcrylicNote;

  String get cartLineAcrylicRibbonIntl;

  String get cartLineAcrylicRibbon;

  String get cartLineBoxTitle;

  String get cartLineBoxVariant;

  String get cartLineBoxDesign;

  String get cartLineBoxAddonFoamLabel;

  String get cartLineBoxAddonFoamDescription;

  String get cartLineBoxAddonCardLabel;

  String get cartLineBoxAddonCardDescription;

  String get cartLineBoxAddonWrapLabel;

  String get cartLineBoxAddonWrapDescription;

  String get cartLineBoxNoteIntl;

  String get cartLineBoxNoteDomestic;

  String get cartLineBoxRibbon;

  String get cartEstimateMethodIntl;

  String get cartEstimateMethodDomestic;

  String get cartEstimateMethodIntlPriority;

  String get cartEstimateMethodStandard;

  String get cartTitle;

  String get cartBulkEditTooltip;

  String get cartLoadFailedTitle;

  String get cartEmptyTitle;

  String get cartEmptyMessage;

  String get cartEmptyAction;

  String get cartRemovedItem;

  String get cartUndo;

  String get cartPromoApplied;

  String get cartEditOptionsTitle;

  String get cartAddonIncluded;

  String get cartReset;

  String get cartSave;

  String get cartBulkActionsTitle;

  String get cartBulkActionsBody;

  String get cartBulkActionApplyField10;

  String get cartBulkActionShipfree;

  String get cartBulkActionClearSelections;

  String get cartUnitPerItem;

  String get cartEditOptionsAction;

  String get cartRemoveAction;

  String get cartLeadTimeLabel;

  String get cartLineTotalLabel;

  String get cartPromoTitle;

  String get cartPromoFieldLabel;

  String get cartPromoApplyLabel;

  String get cartPromoAppliedFallback;

  String get cartPromoMockHint;

  String get cartSummaryTitle;

  String get cartSummaryItems;

  String get cartSummarySubtotal;

  String get cartSummaryDiscount;

  String get cartSummaryShipping;

  String get cartSummaryFree;

  String get cartSummaryTax;

  String get cartSummaryTotal;

  String get cartSummaryEstimate;

  String get cartProceedCheckout;

  String get checkoutAddressTitle;

  String get checkoutAddressAddTooltip;

  String get checkoutAddressLoadFailedTitle;

  String get checkoutAddressEmptyTitle;

  String get checkoutAddressEmptyMessage;

  String get checkoutAddressAddAction;

  String get checkoutAddressChooseHint;

  String get checkoutAddressAddAnother;

  String get checkoutAddressContinueShipping;

  String get checkoutAddressSelectRequired;

  String get checkoutAddressSavedCreated;

  String get checkoutAddressSavedUpdated;

  String get checkoutAddressChipShipping;

  String get checkoutAddressChipDefault;

  String get checkoutAddressChipBilling;

  String get checkoutAddressChipInternational;

  String get checkoutAddressLabelFallback;

  String get checkoutAddressEditAction;

  String get checkoutAddressPersonaDomesticHint;

  String get checkoutAddressPersonaInternationalHint;

  String get checkoutAddressFormAddTitle;

  String get checkoutAddressFormEditTitle;

  String get checkoutAddressFormDomesticLabel;

  String get checkoutAddressFormInternationalLabel;

  String get checkoutAddressFormLabelOptional;

  String get checkoutAddressFormRecipient;

  String get checkoutAddressFormCompanyOptional;

  String get checkoutAddressFormPostalCode;

  String get checkoutAddressFormLookup;

  String get checkoutAddressFormState;

  String get checkoutAddressFormCity;

  String get checkoutAddressFormLine1;

  String get checkoutAddressFormLine2Optional;

  String get checkoutAddressFormCountry;

  String get checkoutAddressFormPhone;

  String get checkoutAddressFormDefaultTitle;

  String get checkoutAddressFormDefaultSubtitle;

  String get checkoutAddressFormSave;

  String get checkoutAddressFormFixErrors;

  String get checkoutAddressRequired;

  String get checkoutAddressRecipientRequired;

  String get checkoutAddressLine1Required;

  String get checkoutAddressCityRequired;

  String get checkoutAddressPostalFormat;

  String get checkoutAddressStateRequired;

  String get checkoutAddressCountryJapanRequired;

  String get checkoutAddressPhoneDomestic;

  String get checkoutAddressPostalShort;

  String get checkoutAddressCountryRequired;

  String get checkoutAddressPhoneInternational;

  String get checkoutShippingMissingState;

  String get checkoutShippingSelectAddress;

  String get checkoutShippingOptionUnavailable;

  String get checkoutShippingPromoRequiresExpress;

  String get checkoutShippingBadgePopular;

  String get checkoutShippingBadgeFastest;

  String get checkoutShippingBadgeTracked;

  String get checkoutShippingOptionDomStandardLabel;

  String get checkoutShippingOptionDomStandardCarrier;

  String get checkoutShippingOptionDomStandardNote;

  String get checkoutShippingOptionDomExpressLabel;

  String get checkoutShippingOptionDomExpressCarrier;

  String get checkoutShippingOptionDomExpressNote;

  String get checkoutShippingOptionDomPickupLabel;

  String get checkoutShippingOptionDomPickupCarrier;

  String get checkoutShippingOptionDomPickupNote;

  String get checkoutShippingOptionIntlExpressLabel;

  String get checkoutShippingOptionIntlExpressCarrier;

  String get checkoutShippingOptionIntlExpressNote;

  String get checkoutShippingOptionIntlPriorityLabel;

  String get checkoutShippingOptionIntlPriorityCarrier;

  String get checkoutShippingOptionIntlPriorityNote;

  String get checkoutShippingOptionIntlEconomyLabel;

  String get checkoutShippingOptionIntlEconomyCarrier;

  String get checkoutShippingOptionIntlEconomyNote;

  String get checkoutShippingBannerInternationalDelay;

  String get checkoutShippingBannerKyushuDelay;

  String get shopTitle;

  String get shopSearchTooltip;

  String get shopCartTooltip;

  String get shopAppBarSubtitle;

  String get shopActionPromotions;

  String get shopActionGuides;

  String get shopQuickGuidesTitle;

  String get shopQuickGuidesSubtitle;

  String get shopBrowseByMaterialTitle;

  String get shopBrowseByMaterialSubtitle;

  String get shopPromotionsTitle;

  String get shopPromotionsSubtitle;

  String get shopPromotionsEmpty;

  String get shopRecommendedMaterialsTitle;

  String get shopRecommendedMaterialsSubtitle;

  String get shopRecommendedMaterialsEmpty;

  String get shopHeroBadge;

  String get shopHeroTitle;

  String get shopHeroBody;

  String get shopHeroAction;

  String get libraryDesignDetailTitle;

  String get libraryDesignDetailSubtitle;

  String get libraryDesignDetailEditTooltip;

  String get libraryDesignDetailExportTooltip;

  String get libraryDesignDetailTabDetails;

  String get libraryDesignDetailTabActivity;

  String get libraryDesignDetailTabFiles;

  String get libraryDesignDetailMetadataTitle;

  String get libraryDesignDetailUsageHistoryTitle;

  String get libraryDesignDetailNoActivity;

  String get libraryDesignDetailFilesTitle;

  String get libraryDesignDetailPreviewPngLabel;

  String get libraryDesignDetailVectorSvgLabel;

  String get libraryDesignDetailExportAction;

  String get libraryDesignDetailUntitled;

  String get libraryDesignDetailAiScoreUnknown;

  String get libraryDesignDetailAiScoreLabel;

  String get libraryDesignDetailRegistrabilityUnknown;

  String get libraryDesignDetailRegistrable;

  String get libraryDesignDetailNotRegistrable;

  String get libraryDesignDetailActionVersions;

  String get libraryDesignDetailActionShare;

  String get libraryDesignDetailActionLinks;

  String get libraryDesignDetailActionDuplicate;

  String get libraryDesignDetailActionReorder;

  String get libraryDesignDetailActionArchive;

  String get libraryDesignDetailArchiveTitle;

  String get libraryDesignDetailArchiveBody;

  String get libraryDesignDetailArchiveCancel;

  String get libraryDesignDetailArchiveConfirm;

  String get libraryDesignDetailArchived;

  String get libraryDesignDetailReorderHint;

  String get libraryDesignDetailHydrateFailed;

  String get libraryDesignDetailFileNotAvailable;

  String get libraryDesignDetailMetadataDesignId;

  String get libraryDesignDetailMetadataStatus;

  String get libraryDesignDetailMetadataAiScore;

  String get libraryDesignDetailMetadataRegistrability;

  String get libraryDesignDetailMetadataCreated;

  String get libraryDesignDetailMetadataUpdated;

  String get libraryDesignDetailMetadataLastUsed;

  String get libraryDesignDetailMetadataVersion;

  String get libraryDesignDetailActivityCreatedTitle;

  String get libraryDesignDetailActivityUpdatedTitle;

  String get libraryDesignDetailActivityOrderedTitle;

  String get libraryDesignDetailActivityCreatedDetail;

  String get libraryDesignDetailActivityUpdatedDetail;

  String get libraryDesignDetailActivityOrderedDetail;

  String get orderDetailTitleFallback;

  String get orderDetailTooltipReorder;

  String get orderDetailTooltipShare;

  String get orderDetailTooltipMore;

  String get orderDetailMenuContactSupport;

  String get orderDetailMenuCancelOrder;

  String get orderDetailTabSummary;

  String get orderDetailTabTimeline;

  String get orderDetailTabFiles;

  String get orderDetailShareText;

  String get orderDetailInvoiceRequestSent;

  String get orderDetailInvoiceRequestFailed;

  String get orderDetailCancelTitle;

  String get orderDetailCancelBody;

  String get orderDetailCancelConfirm;

  String get orderDetailCancelKeep;

  String get orderDetailCancelSuccess;

  String get orderDetailCancelFailed;

  String get orderDetailDesignPreviewOk;

  String get orderDetailBannerInProgress;

  String get orderDetailBannerProduction;

  String get orderDetailBannerTracking;

  String get orderDetailSectionOrder;

  String get orderDetailSectionItems;

  String get orderDetailSectionTotal;

  String get orderDetailSubtotal;

  String get orderDetailDiscount;

  String get orderDetailShipping;

  String get orderDetailShippingFree;

  String get orderDetailTax;

  String get orderDetailTotal;

  String get orderDetailShippingAddress;

  String get orderDetailBillingAddress;

  String get orderDetailPayment;

  String get orderDetailDesignSnapshots;

  String get orderDetailQuickActions;

  String get orderDetailRequestInvoice;

  String get orderDetailContactSupport;

  String get orderDetailTimelineTitle;

  String get orderDetailProductionEvents;

  String get orderDetailInvoiceTitle;

  String get orderDetailInvoiceHint;

  String get orderDetailInvoiceRequest;

  String get orderDetailInvoiceView;

  String get orderDetailItemQtyLabel;

  String get orderDetailPaymentPending;

  String get orderDetailPaymentPaid;

  String get orderDetailPaymentCanceled;

  String get orderDetailPaymentProcessing;

  String get orderDetailPaymentNoInfo;

  String get orderDetailPaymentPaidAt;

  String get orderDetailPaymentMethodCard;

  String get orderDetailPaymentMethodWallet;

  String get orderDetailPaymentMethodBank;

  String get orderDetailPaymentMethodOther;

  String get orderDetailPaymentSeparator;

  String get orderDetailMeta;

  String get orderDetailStatusPending;

  String get orderDetailStatusPaid;

  String get orderDetailStatusInProduction;

  String get orderDetailStatusReadyToShip;

  String get orderDetailStatusShipped;

  String get orderDetailStatusDelivered;

  String get orderDetailStatusCanceled;

  String get orderDetailStatusProcessing;

  String get orderDetailMilestonePlaced;

  String get orderDetailMilestonePaid;

  String get orderDetailMilestoneProduction;

  String get orderDetailMilestoneShipped;

  String get orderDetailMilestoneDelivered;

  String get orderDetailMilestoneCanceled;

  String get kanjiDictionaryTitle;

  String get kanjiDictionaryToggleShowAll;

  String get kanjiDictionaryToggleShowFavorites;

  String get kanjiDictionaryOpenGuides;

  String get kanjiDictionarySearchHint;

  String get kanjiDictionaryHistoryHint;

  String get kanjiDictionaryHistoryTitle;

  String get kanjiDictionaryFiltersTitle;

  String get kanjiDictionaryGradesAll;

  String get kanjiDictionaryGrade1;

  String get kanjiDictionaryGrade2;

  String get kanjiDictionaryGrade3;

  String get kanjiDictionaryGrade4;

  String get kanjiDictionaryGrade5;

  String get kanjiDictionaryGrade6;

  String get kanjiDictionaryStrokesAll;

  String get kanjiDictionaryRadicalAny;

  String get kanjiDictionaryRadicalWater;

  String get kanjiDictionaryRadicalSun;

  String get kanjiDictionaryRadicalPlant;

  String get kanjiDictionaryRadicalHeart;

  String get kanjiDictionaryRadicalEarth;

  String get kanjiDictionaryStrokeCount;

  String get kanjiDictionaryRadicalLabel;

  String get kanjiDictionaryFavorite;

  String get kanjiDictionaryUnfavorite;

  String get kanjiDictionaryDetails;

  String get kanjiDictionaryChipStrokes;

  String get kanjiDictionaryChipRadical;

  String get kanjiDictionaryStrokeOrderTitle;

  String get kanjiDictionaryExamplesTitle;

  String get kanjiDictionaryInsertIntoNameInput;

  String get kanjiDictionaryDone;

  String get kanjiDictionaryExampleUsage;

  String get kanjiDictionaryNoStrokeData;

  String get kanjiDictionaryStrokeOrderPrefix;

  String get orderInvoiceTitle;

  String get orderInvoiceShareTooltip;

  String get orderInvoiceLoadFailed;

  String get orderInvoiceDownloadPdf;

  String get orderInvoiceSendEmail;

  String get orderInvoiceContactSupport;

  String get orderInvoiceTotalLabel;

  String get orderInvoiceStatusAvailable;

  String get orderInvoiceStatusPending;

  String get orderInvoiceTaxable;

  String get orderInvoiceTaxExempt;

  String get orderInvoicePreviewTitle;

  String get orderInvoiceRefreshTooltip;

  String get orderInvoicePendingBody;

  String get orderInvoiceUnavailableBody;

  String get orderInvoiceRequestAction;

  String get orderInvoiceSavedTo;

  String get orderInvoiceSaveFailed;

  String get orderInvoiceShareText;

  String get orderInvoiceOrderLabel;

  String get orderInvoiceIssuedLabel;

  String get orderProductionTitle;

  String get orderProductionRefreshTooltip;

  String get orderProductionStatusLabel;

  String get orderProductionEtaLabel;

  String get orderProductionDelayedMessage;

  String get orderProductionTimelineTitle;

  String get orderProductionNoEventsTitle;

  String get orderProductionNoEventsMessage;

  String get orderProductionNoEventsAction;

  String get orderProductionHealthOnTrack;

  String get orderProductionHealthAttention;

  String get orderProductionHealthDelayed;

  String get orderProductionEventStation;

  String get orderProductionEventQc;

  String get orderProductionEventQueued;

  String get orderProductionEventEngraving;

  String get orderProductionEventPolishing;

  String get orderProductionEventQualityCheck;

  String get orderProductionEventPacked;

  String get orderProductionEventOnHold;

  String get orderProductionEventRework;

  String get orderProductionEventCanceled;

  String get commonCancel;

  String get commonPlaceholder;

  String get commonVersionLabel;

  String get commonSizeMillimeters;

  String get commonPercentLabel;

  String get commonPercentDiscountLabel;

  String get cartSummaryItem;

  String get profileExportTimeMinute;

  String get profileExportTimeHour;

  String get profileExportTimeDay;

  String get profileExportTimeCompactMinute;

  String get profileExportTimeCompactHour;

  String get profileExportTimeCompactDay;

  String get designVersionsRelativeMinute;

  String get designVersionsRelativeHour;

  String get designVersionsRelativeDay;

  String get kanjiDictionaryStrokeCountOne;

  String get kanjiDictionaryChipStrokesOne;

  String get notificationsEmptyUnreadMessage;

  String get notificationsEmptyAllMessage;

  String get notificationsEmptyTitle;

  String get notificationsRefresh;

  String get notificationsLoadMoreHint;

  String get notificationsMarkedRead;

  String get notificationsMarkedUnread;

  String get notificationsUndo;

  String get notificationsAllCaughtUp;

  String get notificationsUnreadCount;

  String get notificationsMoreTooltip;

  String get notificationsMarkAllRead;

  String get notificationsFilterAll;

  String get notificationsFilterUnread;

  String get notificationsMarkRead;

  String get notificationsMarkUnread;

  String get notificationsToday;

  String get notificationsYesterday;

  String get notificationsCategoryOrder;

  String get notificationsCategoryDesign;

  String get notificationsCategoryPromo;

  String get notificationsCategorySupport;

  String get notificationsCategoryStatus;

  String get notificationsCategorySecurity;

  String get orderReorderTitle;

  String get orderReorderSelectItem;

  String get orderReorderCartRebuilt;

  String get orderReorderFromOrder;

  String get orderReorderSelectedCount;

  String get orderReorderRebuildCart;

  String get orderReorderBannerOutOfStockAndPrice;

  String get orderReorderBannerOutOfStock;

  String get orderReorderBannerPriceChanged;

  String get orderReorderBannerUpdates;

  String get orderReorderDismiss;

  String get orderReorderItemFallback;

  String get orderReorderDesignLabel;

  String get orderReorderOutOfStock;

  String get orderReorderPriceUpdated;

  String get orderReorderLoadFailed;

  String get nameValidationSurnameRequired;

  String get nameValidationSurnameFullWidth;

  String get nameValidationGivenRequired;

  String get nameValidationGivenFullWidth;

  String get nameValidationSurnameKanaRequired;

  String get nameValidationKanaFullWidth;

  String get nameValidationGivenKanaRequired;

  String get nameValidationKanaFullWidthRecommended;

  String get supportChatSeedGreeting;
}

class AppLocalizationsEn implements AppLocalizationsStrings {
  const AppLocalizationsEn();

  @override
  String get appTitle => 'Hanko Field';

  @override
  String get welcomeHeadline => 'Craft your seal, your way';

  @override
  String get welcomeBody =>
      'Localization, theming, and tokens are ready to power every screen.';

  @override
  String get primaryAction => 'Get started';

  @override
  String get secondaryAction => 'Browse designs';

  @override
  String get onboardingTitle => 'Welcome tour';

  @override
  String get onboardingSkip => 'Skip';

  @override
  String get onboardingNext => 'Next';

  @override
  String get onboardingBack => 'Back';

  @override
  String get onboardingFinish => 'Start setup';

  @override
  String get onboardingRetry => 'Try again';

  @override
  String get onboardingErrorTitle => 'Could not load onboarding';

  @override
  String get onboardingStepCount => 'Step {current} of {total}';

  @override
  String get onboardingSlideCreateTitle => 'Design without guesswork';

  @override
  String get onboardingSlideCreateBody =>
      'Preview scripts, spacing, and layout with guided templates built for hanko.';

  @override
  String get onboardingSlideCreateTagline => 'Create';

  @override
  String get onboardingSlideMaterialsTitle => 'Pick the right materials';

  @override
  String get onboardingSlideMaterialsBody =>
      'Compare woods, stones, and metals with availability and recommendations.';

  @override
  String get onboardingSlideMaterialsTagline => 'Shop';

  @override
  String get onboardingSlideSupportTitle => 'Guided all the way';

  @override
  String get onboardingSlideSupportBody =>
      'Save progress, resume on web, and reach support if you get stuck.';

  @override
  String get onboardingSlideSupportTagline => 'Assist';

  @override
  String get localeTitle => 'Choose language & region';

  @override
  String get localeSave => 'Save';

  @override
  String get localeSubtitle => 'Set your preferred language';

  @override
  String get localeDescription => 'Device locale: {device}';

  @override
  String get localeContinue => 'Save and continue';

  @override
  String get localeUseDevice => 'Use device locale';

  @override
  String get personaTitle => 'Choose your persona';

  @override
  String get personaSave => 'Save';

  @override
  String get personaSubtitle => 'Tailor guidance to your needs';

  @override
  String get personaDescription =>
      'Pick the journey that best matches how you will use Hanko Field.';

  @override
  String get personaContinue => 'Continue';

  @override
  String get personaUseSelected => 'Save persona';

  @override
  String get authTitle => 'Sign in or continue';

  @override
  String get authSubtitle => 'Choose how you\'d like to continue';

  @override
  String get authBody =>
      'Sign in to sync designs and orders, or continue as a guest with limited features.';

  @override
  String get authEmailLabel => 'Email';

  @override
  String get authEmailHelper => 'Used for receipts and account recovery.';

  @override
  String get authEmailRequired => 'Email is required.';

  @override
  String get authEmailInvalid => 'Enter a valid email address.';

  @override
  String get authPasswordLabel => 'Password';

  @override
  String get authPasswordHelper => 'At least 8 characters.';

  @override
  String get authPasswordTooShort => 'Password is too short.';

  @override
  String get authEmailCta => 'Continue with email';

  @override
  String get authAppleButton => 'Continue with Apple';

  @override
  String get authGoogleButton => 'Continue with Google';

  @override
  String get authGuestCta => 'Continue as guest';

  @override
  String get authGuestNote =>
      'Guest mode lets you browse with limited saving and checkout.';

  @override
  String get authHelpTooltip => 'Need help?';

  @override
  String get authHelpTitle => 'About signing in';

  @override
  String get authHelpBody =>
      'Use your account to keep designs and orders in sync. You can link Apple or Google later from settings.';

  @override
  String get authErrorCancelled => 'Sign-in was cancelled.';

  @override
  String get authErrorNetwork =>
      'Network unavailable. Please check your connection.';

  @override
  String get authErrorInvalid =>
      'Credentials are invalid or expired. Try again.';

  @override
  String get authErrorWrongPassword => 'Email or password is incorrect.';

  @override
  String get authErrorWeakPassword =>
      'Password is too weak; try 8+ characters.';

  @override
  String get authErrorAppleUnavailable =>
      'Apple Sign-In is not available on this device.';

  @override
  String get authErrorLink =>
      'This email is already linked with {providers}. Sign in with that option to connect.';

  @override
  String get authErrorUnknown => 'Could not sign in. Please try again.';

  @override
  String get authLinkingTitle => 'Link your account';

  @override
  String get authLinkPrompt =>
      'Sign in with {providers} to link and keep your data together.';

  @override
  String get authProviderUnknown => 'your account';

  @override
  String get authProviderGoogle => 'Google';

  @override
  String get authProviderApple => 'Apple';

  @override
  String get authProviderEmail => 'Email';

  @override
  String get profileTitle => 'Profile';

  @override
  String get profileAvatarUpdateTooltip => 'Update profile photo';

  @override
  String get profileAvatarUpdateTitle => 'Update profile photo';

  @override
  String get profileAvatarUpdateBody =>
      'Photo updates are coming soon. For now, you can still change your persona and manage settings here.';

  @override
  String get profileAvatarUpdateOk => 'OK';

  @override
  String get profileLoadFailedTitle => 'Could not load profile';

  @override
  String get profileLoadFailedMessage =>
      'Something went wrong while loading your profile. Please try again.';

  @override
  String get profileRetry => 'Retry';

  @override
  String get profileStatusSignedOut => 'Signed out';

  @override
  String get profileStatusGuest => 'Guest';

  @override
  String get profileStatusMember => 'Signed in';

  @override
  String get profileFallbackGuestName => 'Guest';

  @override
  String get profileFallbackProfileName => 'Profile';

  @override
  String get profilePersonaTitle => 'Persona';

  @override
  String get profilePersonaSubtitle => 'Switch guidance and recommendations.';

  @override
  String get profilePersonaJapanese => 'Japan';

  @override
  String get profilePersonaForeigner => 'Global';

  @override
  String get profileQuickLinksTitle => 'Quick links';

  @override
  String get profileQuickOrdersTitle => 'Orders';

  @override
  String get profileQuickOrdersSubtitle => 'View order history';

  @override
  String get profileQuickLibraryTitle => 'My seals';

  @override
  String get profileQuickLibrarySubtitle => 'Saved designs';

  @override
  String get profileSettingsTitle => 'Settings';

  @override
  String get profileAddressesTitle => 'Addresses';

  @override
  String get profileAddressesSubtitle => 'Manage shipping destinations';

  @override
  String get profilePaymentsTitle => 'Payments';

  @override
  String get profilePaymentsSubtitle => 'Manage saved payment methods';

  @override
  String get paymentMethodErrorLast4 => 'Enter last 4 digits';

  @override
  String get paymentMethodErrorExpMonth => 'Enter expiry month';

  @override
  String get paymentMethodErrorExpYear => 'Enter expiry year';

  @override
  String get paymentMethodErrorFixFields => 'Fix the highlighted fields';

  @override
  String get paymentMethodAddFailed => 'Could not add payment method';

  @override
  String get paymentMethodSheetTitle => 'Add payment method';

  @override
  String get paymentMethodSheetCard => 'Card';

  @override
  String get paymentMethodSheetWallet => 'Wallet';

  @override
  String get paymentMethodSheetBrandLabel => 'Brand (e.g. Visa)';

  @override
  String get paymentMethodSheetLast4Label => 'Last 4 digits';

  @override
  String get paymentMethodSheetExpMonthLabel => 'Exp. month';

  @override
  String get paymentMethodSheetExpYearLabel => 'Exp. year';

  @override
  String get paymentMethodSheetBillingNameLabel => 'Billing name (optional)';

  @override
  String get paymentMethodSheetSave => 'Save';

  @override
  String get profileNotificationsTitle => 'Notifications';

  @override
  String get profileNotificationsSubtitle => 'Update notification preferences';

  @override
  String get profileNotificationsHeader =>
      'Choose how you want to hear from Hanko Field.';

  @override
  String get profileNotificationsPushHeader => 'Push notifications';

  @override
  String get profileNotificationsEmailHeader => 'Email notifications';

  @override
  String get profileNotificationsDigestHeader => 'Digest frequency';

  @override
  String get profileNotificationsDigestHelper =>
      'How often should we send summary emails?';

  @override
  String get profileNotificationsDigestDaily => 'Daily';

  @override
  String get profileNotificationsDigestWeekly => 'Weekly';

  @override
  String get profileNotificationsDigestMonthly => 'Monthly';

  @override
  String get profileNotificationsSave => 'Save preferences';

  @override
  String get profileNotificationsReset => 'Reset';

  @override
  String get profileNotificationsSaved => 'Notification preferences saved.';

  @override
  String get profileNotificationsSaveFailed => 'Could not save preferences.';

  @override
  String get profileNotificationsLoadFailedTitle =>
      'Could not load notification settings';

  @override
  String get profileNotificationsCategoryOrdersTitle => 'Order updates';

  @override
  String get profileNotificationsCategoryOrdersBody =>
      'Shipping, production, and delivery status.';

  @override
  String get profileNotificationsCategoryDesignsTitle => 'Design activity';

  @override
  String get profileNotificationsCategoryDesignsBody =>
      'AI suggestions, edits, and approvals.';

  @override
  String get profileNotificationsCategoryPromosTitle => 'Promotions';

  @override
  String get profileNotificationsCategoryPromosBody =>
      'New drops, seasonal releases, and offers.';

  @override
  String get profileNotificationsCategoryGuidesTitle => 'Guides & tips';

  @override
  String get profileNotificationsCategoryGuidesBody =>
      'How-to content and cultural insights.';

  @override
  String get profileLocaleTitle => 'Language & currency';

  @override
  String get profileLocaleSubtitle => 'Change language and region';

  @override
  String get profileLocaleLanguageHeader => 'App language';

  @override
  String get profileLocaleLanguageHelper =>
      'Choose the language used across menus and content.';

  @override
  String get profileLocaleCurrencyHeader => 'Currency';

  @override
  String get profileLocaleCurrencyHelper =>
      'Override the currency used for prices and totals.';

  @override
  String get profileLocaleCurrencyAuto => 'Auto';

  @override
  String get profileLocaleCurrencyAutoHint =>
      'Auto will use {currency} based on your language/region.';

  @override
  String get profileLocaleCurrencyJpy => 'JPY';

  @override
  String get profileLocaleCurrencyUsd => 'USD';

  @override
  String get profileLocaleSave => 'Save changes';

  @override
  String get profileLocaleSaved => 'Locale preferences updated.';

  @override
  String get profileLocaleSaveFailed => 'Could not save locale preferences.';

  @override
  String get profileLocaleUseDevice => 'Use device language';

  @override
  String get profileLegalTitle => 'Legal';

  @override
  String get profileLegalSubtitle => 'Terms, privacy, and disclosures';

  @override
  String get profileLegalDownloadTooltip => 'Download for offline';

  @override
  String get profileLegalDownloadComplete =>
      'Legal documents saved for offline use.';

  @override
  String get profileLegalDownloadFailed =>
      'Could not save documents. Try again.';

  @override
  String get profileLegalLoadFailedTitle => 'Could not load legal documents';

  @override
  String get profileLegalDocumentsTitle => 'Documents';

  @override
  String get profileLegalContentTitle => 'Document';

  @override
  String get profileLegalOpenInBrowser => 'Open in browser';

  @override
  String get profileLegalVersionUnknown => 'Latest';

  @override
  String get profileLegalNoDocument => 'Select a document to view details.';

  @override
  String get profileLegalUnavailable =>
      'This document is not available right now.';

  @override
  String get profileLegalNoContent => 'No content available for this document.';

  @override
  String get profileSupportTitle => 'Support';

  @override
  String get profileSupportSubtitle => 'FAQ and contact options';

  @override
  String get supportChatConnectedAgent =>
      'You are now connected with Rina (Support Agent).';

  @override
  String get supportChatAgentGreeting =>
      "Hi, I'm Rina. I can take it from here. Could you share an order ID?";

  @override
  String get supportChatBotHandoff =>
      'Got it. I am connecting you to a specialist.';

  @override
  String get supportChatBotDelivery =>
      'Delivery usually takes 3-5 business days. Do you have an order ID?';

  @override
  String get supportChatBotOrderStatus =>
      'I can check order status. Please share the order ID if you have it.';

  @override
  String get supportChatBotFallback =>
      'I can help with orders, delivery, or seal specs. What do you need?';

  @override
  String get supportChatAgentRefund =>
      'I can help with refunds. Which order should we review?';

  @override
  String get supportChatAgentAddress =>
      'I can update the delivery address if production has not started.';

  @override
  String get supportChatAgentFallback =>
      'Thanks, I am checking now. I will update you shortly.';

  @override
  String get profileGuidesTitle => 'Guides';

  @override
  String get profileGuidesSubtitle => 'Culture and how-to guides';

  @override
  String get profileHowtoTitle => 'How to';

  @override
  String get profileHowtoSubtitle => 'Tutorials and videos';

  @override
  String get profileLinkedAccountsTitle => 'Linked accounts';

  @override
  String get profileLinkedAccountsSubtitle => 'Connect Apple and Google';

  @override
  String get profileLinkedAccountsHeader =>
      'Manage the sign-in methods connected to your account.';

  @override
  String get profileLinkedAccountsAddTooltip => 'Link account';

  @override
  String get profileLinkedAccountsLoadFailedTitle =>
      'Could not load linked accounts';

  @override
  String get profileLinkedAccountsSignedOutTitle =>
      'Sign in to manage linked accounts';

  @override
  String get profileLinkedAccountsSignedOutBody =>
      'Sign in to connect Apple or Google.';

  @override
  String get profileLinkedAccountsSignIn => 'Sign in';

  @override
  String get profileLinkedAccountsBannerTitle => 'Security reminder';

  @override
  String get profileLinkedAccountsBannerBody =>
      'Use a unique password and keep recovery options updated.';

  @override
  String get profileLinkedAccountsBannerBodyLong =>
      'Use a unique password, keep recovery options updated, and review connected providers regularly.';

  @override
  String get profileLinkedAccountsBannerAction => 'Review tips';

  @override
  String get profileLinkedAccountsConnected => 'Connected';

  @override
  String get profileLinkedAccountsNotConnected => 'Not connected';

  @override
  String get profileLinkedAccountsProviderFallback => 'No display name';

  @override
  String get profileLinkedAccountsAutoSignIn => 'Auto sign-in';

  @override
  String get profileLinkedAccountsNotConnectedHelper =>
      'Link this provider to enable auto sign-in.';

  @override
  String get profileLinkedAccountsUnlink => 'Unlink';

  @override
  String get profileLinkedAccountsUnlinkTitle => 'Unlink account?';

  @override
  String get profileLinkedAccountsUnlinkBody =>
      'You will no longer be able to sign in with this provider.';

  @override
  String get profileLinkedAccountsUnlinkConfirm => 'Unlink';

  @override
  String get profileLinkedAccountsCancel => 'Cancel';

  @override
  String get profileLinkedAccountsUnlinkDisabled =>
      'Link another account before unlinking.';

  @override
  String get profileLinkedAccountsSave => 'Save changes';

  @override
  String get profileLinkedAccountsSaved => 'Linked account settings saved.';

  @override
  String get profileLinkedAccountsSaveFailed => 'Could not save changes.';

  @override
  String get profileLinkedAccountsLinked => 'Account linked.';

  @override
  String get profileLinkedAccountsLinkFailed => 'Could not link account.';

  @override
  String get profileLinkedAccountsUnlinked => 'Account unlinked.';

  @override
  String get profileLinkedAccountsUnlinkFailed => 'Could not unlink account.';

  @override
  String get profileLinkedAccountsLinkTitle => 'Link another account';

  @override
  String get profileLinkedAccountsLinkSubtitle => 'Continue to connect.';

  @override
  String get profileLinkedAccountsAlreadyLinked => 'Already linked.';

  @override
  String get profileLinkedAccountsFooter =>
      'Tip: Linking more than one provider helps you recover access.';

  @override
  String get profileLinkedAccountsOk => 'OK';

  @override
  String get profileExportTitle => 'Export data';

  @override
  String get profileExportSubtitle => 'Download your account data';

  @override
  String get profileExportAppBarSubtitle => 'Create a secure account archive';

  @override
  String get profileExportSummaryTitle => 'What we export';

  @override
  String get profileExportSummaryBody =>
      'Your profile, saved seals, orders, and activity are bundled into a single ZIP archive.';

  @override
  String get profileExportIncludeAssetsTitle => 'Design assets';

  @override
  String get profileExportIncludeAssetsSubtitle =>
      'Saved seals, templates, and previews';

  @override
  String get profileExportIncludeOrdersTitle => 'Orders & invoices';

  @override
  String get profileExportIncludeOrdersSubtitle =>
      'Order history, shipments, receipts';

  @override
  String get profileExportIncludeHistoryTitle => 'Usage history';

  @override
  String get profileExportIncludeHistorySubtitle =>
      'Searches, edits, and activity log';

  @override
  String get profileExportPermissionTitle => 'Storage access needed';

  @override
  String get profileExportPermissionBody =>
      'Allow access to download the archive to your device.';

  @override
  String get profileExportPermissionCta => 'Allow access';

  @override
  String get permissionsTitle => 'Permissions';

  @override
  String get permissionsSubtitle => 'Give Hanko Field the access it needs.';

  @override
  String get permissionsHeroTitle => 'Stay ready to create';

  @override
  String get permissionsHeroBody =>
      'We only request access when it helps you build, export, and stay updated.';

  @override
  String get permissionsPersonaDomestic =>
      'Optimized for official Japanese hanko workflows.';

  @override
  String get permissionsPersonaInternational =>
      'Guidance-first setup for global users.';

  @override
  String get permissionsPhotosTitle => 'Photos';

  @override
  String get permissionsPhotosBody =>
      'Import a stamp scan or photo to begin a new design.';

  @override
  String get permissionsPhotosAssist1 => 'Scan an existing seal';

  @override
  String get permissionsPhotosAssist2 => 'Use camera roll';

  @override
  String get permissionsStorageTitle => 'Files & storage';

  @override
  String get permissionsStorageBody =>
      'Save exports, receipts, and design proofs to your device.';

  @override
  String get permissionsStorageAssist1 => 'Download exports';

  @override
  String get permissionsStorageAssist2 => 'Attach files';

  @override
  String get permissionsNotificationsTitle => 'Notifications';

  @override
  String get permissionsNotificationsBody =>
      'Get updates on production, delivery, and approvals.';

  @override
  String get permissionsNotificationsAssist1 => 'Production alerts';

  @override
  String get permissionsNotificationsAssist2 => 'Delivery updates';

  @override
  String get permissionsStatusGranted => 'Granted';

  @override
  String get permissionsStatusDenied => 'Not allowed';

  @override
  String get permissionsStatusRestricted => 'Restricted';

  @override
  String get permissionsStatusUnknown => 'Not decided';

  @override
  String get permissionsFallbackPhotos =>
      'To enable photo access, open system Settings and allow Photos.';

  @override
  String get permissionsFallbackStorage =>
      'To enable file access, open system Settings and allow Files & Storage.';

  @override
  String get permissionsFallbackNotifications =>
      'To enable alerts, open system Settings and allow Notifications.';

  @override
  String get permissionsCtaGrantAll => 'Grant access';

  @override
  String get permissionsCtaNotNow => 'Not now';

  @override
  String get permissionsFooterPolicy => 'Review data policy';

  @override
  String get permissionsItemActionAllow => 'Allow';

  @override
  String get profileExportStatusReadyTitle => 'Ready to export';

  @override
  String get profileExportStatusReadyBody =>
      'We will package your data as a ZIP archive.';

  @override
  String get profileExportStatusInProgressTitle => 'Preparing archive';

  @override
  String get profileExportStatusInProgressBody =>
      'This may take a moment. Keep the app open.';

  @override
  String get profileExportStatusDoneTitle => 'Export ready';

  @override
  String get profileExportStatusDoneBody =>
      'Saved to secure storage. You can download again anytime.';

  @override
  String get profileExportCtaStart => 'Create export';

  @override
  String get profileExportCtaHistory => 'View previous exports';

  @override
  String get profileExportHistoryTitle => 'Previous exports';

  @override
  String get profileExportHistoryEmptyTitle => 'No exports yet';

  @override
  String get profileExportHistoryEmptyBody =>
      'Create an export to see it here.';

  @override
  String get profileExportHistoryDownload => 'Download archive';

  @override
  String get profileExportErrorTitle => 'Could not load export';

  @override
  String get profileExportErrorBody =>
      'Something went wrong while loading export settings.';

  @override
  String get profileExportRetry => 'Retry';

  @override
  String get profileExportTimeJustNow => 'Just now';

  @override
  String get profileExportTimeMinutes => '{count} min ago';

  @override
  String get profileExportTimeHours => '{count} hr ago';

  @override
  String get profileExportTimeDays => '{count} days ago';

  @override
  String get profileExportTimeDate => '{date}';

  @override
  String get profileExportTimeCompactNow => 'now';

  @override
  String get profileExportTimeCompactMinutes => '{count}m';

  @override
  String get profileExportTimeCompactHours => '{count}h';

  @override
  String get profileExportTimeCompactDays => '{count}d';

  @override
  String get profileDeleteTitle => 'Delete account';

  @override
  String get profileDeleteSubtitle => 'Permanently delete your account';

  @override
  String get profileDeleteWarningTitle => 'Account deletion is permanent';

  @override
  String get profileDeleteWarningBody =>
      'Your profile, saved seals, and order history will be removed. '
      'Some transactional records may be retained for legal reasons.';

  @override
  String get profileDeleteAcknowledgementTitle =>
      'Please confirm before continuing';

  @override
  String get profileDeleteAckDataLossTitle =>
      'Delete my saved designs and profile';

  @override
  String get profileDeleteAckDataLossBody =>
      'This removes your profile, saved seals, and preferences.';

  @override
  String get profileDeleteAckOrdersTitle =>
      'I understand active orders continue';

  @override
  String get profileDeleteAckOrdersBody =>
      'Open orders, refunds, or support cases may continue after deletion.';

  @override
  String get profileDeleteAckIrreversibleTitle =>
      'This action cannot be undone';

  @override
  String get profileDeleteAckIrreversibleBody =>
      'I will need to create a new account to return.';

  @override
  String get profileDeleteFooterNote =>
      'You will be signed out immediately after the deletion request is processed.';

  @override
  String get profileDeleteCta => 'Delete account';

  @override
  String get profileDeleteCancelCta => 'Cancel';

  @override
  String get profileDeleteConfirmTitle => 'Delete your account?';

  @override
  String get profileDeleteConfirmBody =>
      'We will deactivate your account and remove personal data. This cannot be undone.';

  @override
  String get profileDeleteConfirmAction => 'Delete';

  @override
  String get profileDeleteConfirmCancel => 'Keep account';

  @override
  String get profileDeleteSuccess =>
      'Account deletion requested. You have been signed out.';

  @override
  String get profileDeleteError => 'Account deletion failed. Please try again.';

  @override
  String get profileDeleteErrorTitle => 'Unable to load delete settings';

  @override
  String get profileDeleteErrorBody => 'Please try again.';

  @override
  String get profileDeleteRetry => 'Retry';

  @override
  String get profileSignInCta => 'Sign in';

  @override
  String get profileAccountSecurityTitle => 'Account security';

  @override
  String get profileAccountSecuritySubtitle =>
      'Passwords, 2FA, and linked providers';

  @override
  String get profileAccountSecurityBody =>
      'Security settings will appear here in a future update.';

  @override
  String get appUpdateTitle => 'App update';

  @override
  String get appUpdateCheckAgain => 'Check again';

  @override
  String get appUpdateChecking => 'Checking version...';

  @override
  String get appUpdateVerifyFailedTitle => 'Unable to verify version';

  @override
  String get appUpdateRetry => 'Retry';

  @override
  String get appUpdateBannerRequired =>
      'You must update to keep using the app.';

  @override
  String get appUpdateBannerOptional =>
      'A new version is ready. Update when convenient.';

  @override
  String get appUpdateBannerAction => 'Update';

  @override
  String get appUpdateCardRequiredTitle => 'Update required';

  @override
  String get appUpdateCardOptionalTitle => 'Update available';

  @override
  String get appUpdateCurrentVersion => 'Current version: {version}';

  @override
  String get appUpdateMinimumVersion => 'Minimum required: {version}';

  @override
  String get appUpdateLatestVersion => 'Latest version: {version}';

  @override
  String get appUpdateNow => 'Update now';

  @override
  String get appUpdateOpenStore => 'Open store listing';

  @override
  String get appUpdateContinue => 'Continue without updating';

  @override
  String get appUpdateStoreUnavailable =>
      'Store link is unavailable. Please update from the app store.';

  @override
  String get appUpdateStoreOpenFailed =>
      'Unable to open the store. Please update from the store app.';

  @override
  String get appUpdateReminder => 'Update available (v{version}).';

  @override
  String get appUpdateLater => 'Later';

  @override
  String get commonBack => 'Back';

  @override
  String get commonRetry => 'Retry';

  @override
  String get commonClose => 'Close';

  @override
  String get commonSave => 'Save';

  @override
  String get commonLearnMore => 'Learn more';

  @override
  String get commonLoadMore => 'Load more';

  @override
  String get commonClear => 'Clear';

  @override
  String get commonLoadFailed => 'Failed to load';

  @override
  String get commonUnknown => 'Unknown';

  @override
  String get offlineTitle => 'You are offline';

  @override
  String get offlineMessage =>
      'Reconnect to sync your data and keep everything up to date.';

  @override
  String get offlineRetry => 'Retry connection';

  @override
  String get offlineOpenCachedLibrary => 'Open cached library';

  @override
  String get offlineCacheHint => 'Cached items are limited until you sync.';

  @override
  String get offlineLastSyncUnavailable => 'Last sync unavailable';

  @override
  String get offlineLastSyncLabel => 'Last sync {date} {time}';

  @override
  String get changelogTitle => 'Changelog';

  @override
  String get changelogLatestReleaseTooltip => 'Latest release';

  @override
  String get changelogHighlightsTitle => 'Highlights';

  @override
  String get changelogAllUpdates => 'All updates';

  @override
  String get changelogMajorOnly => 'Major only';

  @override
  String get changelogUnableToLoad => 'Unable to load updates';

  @override
  String get changelogNoUpdatesTitle => 'No updates yet';

  @override
  String get changelogNoUpdatesMessage =>
      'We will post release notes here as soon as they are ready.';

  @override
  String get changelogVersionHistoryTitle => 'Version history';

  @override
  String get changelogVersionHistorySubtitle =>
      'Tap a release to see details and fixes.';

  @override
  String get searchHintText => 'Search templates, materials, articles';

  @override
  String get searchVoiceTooltip => 'Voice search';

  @override
  String get searchVoiceComingSoon =>
      'Voice search and barcode scan coming soon';

  @override
  String get searchRecentTitle => 'Recent searches';

  @override
  String get searchSuggestionsTitle => 'Suggestions';

  @override
  String get searchSuggestionsLoadFailed => 'Failed to load suggestions';

  @override
  String get searchResultsErrorTitle => 'Could not search';

  @override
  String get searchResultsEmptyTitle => 'No results';

  @override
  String get searchResultsEmptyMessage =>
      'Try adjusting keywords or switching a segment.';

  @override
  String get homeTitle => 'Home';

  @override
  String get homeSearchTooltip => 'Search';

  @override
  String get homeNotificationsTooltip => 'Notifications';

  @override
  String get homeFeaturedTitle => 'Featured highlights';

  @override
  String get homeFeaturedSubtitle =>
      'Campaigns and recommended flows, curated for you';

  @override
  String get homeFeaturedEmpty =>
      'No featured highlights right now. Please check back later.';

  @override
  String get homeRecentTitle => 'Recent designs';

  @override
  String get homeRecentSubtitle => 'Resume drafts or orders quickly';

  @override
  String get homeRecentActionLabel => 'See all';

  @override
  String get homeRecentEmpty => 'No designs yet. Start a new one.';

  @override
  String get homeRecommendedTitle => 'Recommended templates';

  @override
  String get homeRecommendedSubtitle =>
      'Suggestions tailored to your activity and region';

  @override
  String get homeRecommendedLoading => 'Preparing recommended templates...';

  @override
  String get homeStatusDraft => 'Draft';

  @override
  String get homeStatusReady => 'Ready';

  @override
  String get homeStatusOrdered => 'Ordered';

  @override
  String get homeStatusLocked => 'Locked';

  @override
  String get homeShapeRound => 'Round';

  @override
  String get homeShapeSquare => 'Square';

  @override
  String get homeWritingTensho => 'Tensho';

  @override
  String get homeWritingReisho => 'Reisho';

  @override
  String get homeWritingKaisho => 'Kaisho';

  @override
  String get homeWritingGyosho => 'Gyosho';

  @override
  String get homeWritingKoentai => 'Koentai';

  @override
  String get homeWritingCustom => 'Custom';

  @override
  String get homeNameUnset => 'Unnamed';

  @override
  String get homeDesignSummary => '{shape} {size}mm · {style}';

  @override
  String get homeDesignAiCheckDone => 'Official seal check complete';

  @override
  String get homeDesignAiCheckLabel => 'AI check: {diagnostic}';

  @override
  String get homeDesignAiCheckNotRun => 'Not run';

  @override
  String get homeTemplateLabel => '{shape}・{style}';

  @override
  String get homeTemplateRecommendedSize => 'Recommended {size}mm';

  @override
  String get homeTemplateApply => 'Apply';

  @override
  String get homeLoadFailed => 'Failed to load';

  @override
  String get topBarSearchLabel => 'Search';

  @override
  String get topBarSearchHint => 'Supports ⌘K / Ctrl+K shortcuts';

  @override
  String get topBarSearchTooltip => 'Search (⌘K / Ctrl+K)';

  @override
  String get topBarHelpLabel => 'Help';

  @override
  String get topBarHelpHint => 'Open with Shift + /';

  @override
  String get topBarHelpTooltip => 'Help & FAQ (Shift + /)';

  @override
  String get topBarNotificationsLabel => 'Notifications';

  @override
  String get topBarNotificationsLabelWithUnread =>
      'Notifications ({count} unread)';

  @override
  String get topBarNotificationsTooltip => 'Notifications (Alt + N)';

  @override
  String get topBarNotificationsTooltipWithUnread =>
      'Notifications ({count} unread) (Alt + N)';

  @override
  String get topBarHelpOverlayTitle => 'Help & shortcuts';

  @override
  String get topBarHelpOverlayPrimaryAction => 'Browse FAQ';

  @override
  String get topBarHelpOverlaySecondaryAction => 'Contact support';

  @override
  String get topBarHelpOverlayBody =>
      'Shortcuts and support entry points. Jump to FAQ or chat when you\'re stuck.';

  @override
  String get topBarShortcutSearchLabel => 'Search';

  @override
  String get topBarShortcutHelpLabel => 'Help';

  @override
  String get topBarShortcutNotificationsLabel => 'Notifications';

  @override
  String get topBarHelpLinkFaqTitle => 'Find answers in FAQ';

  @override
  String get topBarHelpLinkFaqSubtitle => 'Troubleshooting and top questions';

  @override
  String get topBarHelpLinkChatTitle => 'Chat with us';

  @override
  String get topBarHelpLinkChatSubtitle => 'Get quick answers';

  @override
  String get topBarHelpLinkContactTitle => 'Contact form';

  @override
  String get topBarHelpLinkContactSubtitle => 'For detailed support requests';

  @override
  String get splashLoading => 'Starting up…';

  @override
  String get splashFailedTitle => 'Startup failed';

  @override
  String get splashFailedMessage => 'Check your network and try again.';

  @override
  String get designVersionsTitle => 'Version history';

  @override
  String get designVersionsShowDiffTooltip => 'Show diff';

  @override
  String get designVersionsSecondaryDuplicate => 'Create copy';

  @override
  String get designVersionsTimelineTitle => 'Timeline';

  @override
  String get designVersionsRefreshTooltip => 'Refresh history';

  @override
  String get designVersionsAuditLogTitle => 'Audit log';

  @override
  String get designVersionsNoAuditTitle => 'No history';

  @override
  String get designVersionsNoAuditMessage =>
      'No action log yet for this design.';

  @override
  String get designVersionsRollbackTitle => 'Rollback to v{version}?';

  @override
  String get designVersionsRollbackBody =>
      'This will replace the current working version. The diff will remain in history.';

  @override
  String get designVersionsRollbackAction => 'Restore';

  @override
  String get designVersionsRollbackCancel => 'Cancel';

  @override
  String get designVersionsCurrentLabel => 'Current: v{version}';

  @override
  String get designVersionsNoDiffSummary => 'No changes';

  @override
  String get designVersionsCompareTargetLabel => 'Compare v{version}';

  @override
  String get designVersionsLatestLabel => 'Latest';

  @override
  String get designVersionsRollbackButton => 'Rollback';

  @override
  String get designVersionsPreviewCurrent => 'Current';

  @override
  String get designVersionsPreviewTarget => 'Compare';

  @override
  String get designVersionsInitialFallback => 'Seal';

  @override
  String get designVersionsUnset => 'Unset';

  @override
  String get designVersionsAutoLayout => 'Auto';

  @override
  String get designVersionsNoDiffTitle => 'No changes';

  @override
  String get designVersionsNoDiffMessage =>
      'No differences between latest and comparison version.';

  @override
  String get designVersionsChangeHistoryEmpty => 'No change note';

  @override
  String get designVersionsTemplateLabel => 'Template: {template}';

  @override
  String get designVersionsStatusCurrent => 'Current';

  @override
  String get designVersionsStatusComparing => 'Comparing';

  @override
  String get designVersionsStatusHistory => 'History';

  @override
  String get designVersionsLoadFailedTitle => 'Couldn\'t load history';

  @override
  String get designVersionsSimilarityLabel => 'Similarity';

  @override
  String get designVersionsRelativeNow => 'Just now';

  @override
  String get designVersionsRelativeMinutes => '{count}m ago';

  @override
  String get designVersionsRelativeHours => '{count}h ago';

  @override
  String get designVersionsRelativeDays => '{count}d ago';

  @override
  String get checkoutPaymentTitle => 'Payment method';

  @override
  String get checkoutPaymentAddTooltip => 'Add payment method';

  @override
  String get checkoutPaymentLoadFailedTitle => 'Could not load payments';

  @override
  String get checkoutPaymentEmptyTitle => 'Add a payment method';

  @override
  String get checkoutPaymentEmptyBody =>
      'Save a card or wallet to continue checkout.';

  @override
  String get checkoutPaymentSignInHint => 'Sign in to add methods.';

  @override
  String get checkoutPaymentAddMethod => 'Add method';

  @override
  String get checkoutPaymentChooseSaved => 'Choose a saved payment method.';

  @override
  String get checkoutPaymentAddAnother => 'Add another method';

  @override
  String get checkoutPaymentContinueReview => 'Continue to review';

  @override
  String get checkoutPaymentAddFailed => 'Could not add payment method';

  @override
  String get checkoutPaymentMethodCard => 'Card';

  @override
  String get checkoutPaymentMethodWallet => 'Wallet';

  @override
  String get checkoutPaymentMethodBank => 'Bank transfer';

  @override
  String get checkoutPaymentMethodFallback => 'Payment method';

  @override
  String get checkoutPaymentExpires => 'Expires {month}/{year}';

  @override
  String get cartPromoEnterCode => 'Enter a promo code';

  @override
  String get cartPromoAddItemsRequired =>
      'Add items before applying discounts.';

  @override
  String get cartPromoField10Label => '10% off';

  @override
  String get cartPromoField10Description => 'Applies to merchandise subtotal.';

  @override
  String get cartPromoShipfreeShortfall =>
      'Add ¥{amount} more to unlock free shipping.';

  @override
  String get cartPromoShipfreeLabel => 'Free shipping';

  @override
  String get cartPromoInkLabel => 'Ink set bonus';

  @override
  String get cartPromoInkDescription => '¥200 off for ink/accessory bundles.';

  @override
  String get cartPromoInvalid => 'Invalid or expired code.';

  @override
  String get cartLineTitaniumTitle => 'Titanium round seal';

  @override
  String get cartLineTitaniumVariant => '15mm · Deep engraving';

  @override
  String get cartLineTitaniumDesign => 'Design: Akiyama (篤山)';

  @override
  String get cartLineTitaniumAddonSleeveLabel => 'Microfiber sleeve';

  @override
  String get cartLineTitaniumAddonSleeveDescription =>
      'Slim case with scratch guard.';

  @override
  String get cartLineTitaniumAddonSleeveBadge => 'Popular';

  @override
  String get cartLineTitaniumAddonDeepLabel => 'Deep engraving';

  @override
  String get cartLineTitaniumAddonDeepDescription =>
      'Sharper edges for crisp stamps.';

  @override
  String get cartLineTitaniumAddonWrapLabel => 'Gift wrap';

  @override
  String get cartLineTitaniumAddonWrapDescription =>
      'Adds washi band and message card.';

  @override
  String get cartLineTitaniumNoteIntl => 'Customs-friendly material';

  @override
  String get cartLineTitaniumNoteDomestic => 'Rush-ready, personalized';

  @override
  String get cartLineTitaniumRibbon => 'Bestseller';

  @override
  String get cartLineAcrylicTitle => 'Color acrylic seal';

  @override
  String get cartLineAcrylicVariant => '12mm · Mint / Script';

  @override
  String get cartLineAcrylicDesign => 'Design: Upload later';

  @override
  String get cartLineAcrylicAddonUvLabel => 'UV finish';

  @override
  String get cartLineAcrylicAddonUvDescription =>
      'Protects from fading and scratches.';

  @override
  String get cartLineAcrylicAddonUvBadge => 'Limited';

  @override
  String get cartLineAcrylicAddonInkLabel => 'Ink pad set';

  @override
  String get cartLineAcrylicAddonInkDescription =>
      'Compact pad with replaceable insert.';

  @override
  String get cartLineAcrylicAddonPouchLabel => 'Soft pouch';

  @override
  String get cartLineAcrylicAddonPouchDescription =>
      'Keeps acrylic surface clean.';

  @override
  String get cartLineAcrylicNote => 'Ships with add-on recommendations.';

  @override
  String get cartLineAcrylicRibbonIntl => 'Intl friendly';

  @override
  String get cartLineAcrylicRibbon => 'Recommended';

  @override
  String get cartLineBoxTitle => 'Keepsake box';

  @override
  String get cartLineBoxVariant => 'Engraved lid · Natural';

  @override
  String get cartLineBoxDesign => 'Name: Hanko Field';

  @override
  String get cartLineBoxAddonFoamLabel => 'Foam insert';

  @override
  String get cartLineBoxAddonFoamDescription => 'Secures seal and accessories.';

  @override
  String get cartLineBoxAddonCardLabel => 'Care card';

  @override
  String get cartLineBoxAddonCardDescription =>
      'Printed care instructions in JP/EN.';

  @override
  String get cartLineBoxAddonWrapLabel => 'Wrapping bundle';

  @override
  String get cartLineBoxAddonWrapDescription =>
      'Ribbon, sticker, and spare tissue.';

  @override
  String get cartLineBoxNoteIntl => 'Includes bilingual insert.';

  @override
  String get cartLineBoxNoteDomestic => 'Message engraving included.';

  @override
  String get cartLineBoxRibbon => 'Gift';

  @override
  String get cartEstimateMethodIntl => 'Intl';

  @override
  String get cartEstimateMethodDomestic => 'Domestic';

  @override
  String get cartEstimateMethodIntlPriority => 'Intl priority';

  @override
  String get cartEstimateMethodStandard => 'Standard';

  @override
  String get cartTitle => 'Cart';

  @override
  String get cartBulkEditTooltip => 'Bulk edit';

  @override
  String get cartLoadFailedTitle => 'Could not load cart';

  @override
  String get cartEmptyTitle => 'Cart is empty';

  @override
  String get cartEmptyMessage => 'Add items from the shop to see an estimate.';

  @override
  String get cartEmptyAction => 'Back to shop';

  @override
  String get cartRemovedItem => 'Removed {item}';

  @override
  String get cartUndo => 'Undo';

  @override
  String get cartPromoApplied => 'Applied {label}';

  @override
  String get cartEditOptionsTitle => 'Edit options';

  @override
  String get cartAddonIncluded => 'Included';

  @override
  String get cartReset => 'Reset';

  @override
  String get cartSave => 'Save';

  @override
  String get cartBulkActionsTitle => 'Bulk actions';

  @override
  String get cartBulkActionsBody =>
      'Apply promo, adjust quantities, or clear selections for all lines.';

  @override
  String get cartBulkActionApplyField10 => 'Apply FIELD10';

  @override
  String get cartBulkActionShipfree => 'Free shipping';

  @override
  String get cartBulkActionClearSelections => 'Clear selections';

  @override
  String get cartUnitPerItem => 'per item';

  @override
  String get cartEditOptionsAction => 'Edit options';

  @override
  String get cartRemoveAction => 'Remove';

  @override
  String get cartLeadTimeLabel => 'Est. {min}-{max} days';

  @override
  String get cartLineTotalLabel => 'Line total';

  @override
  String get cartPromoTitle => 'Promo code';

  @override
  String get cartPromoFieldLabel => 'Enter code';

  @override
  String get cartPromoApplyLabel => 'Apply';

  @override
  String get cartPromoAppliedFallback => 'Promo applied.';

  @override
  String get cartPromoMockHint => 'Promo codes are simulated for this mock.';

  @override
  String get cartSummaryTitle => 'Estimate summary';

  @override
  String get cartSummaryItems => '{count} items';

  @override
  String get cartSummarySubtotal => 'Subtotal';

  @override
  String get cartSummaryDiscount => 'Discount';

  @override
  String get cartSummaryShipping => 'Shipping';

  @override
  String get cartSummaryFree => 'Free';

  @override
  String get cartSummaryTax => 'Estimated tax';

  @override
  String get cartSummaryTotal => 'Total (est.)';

  @override
  String get cartSummaryEstimate => 'Est. {min}-{max} days · {method}';

  @override
  String get cartProceedCheckout => 'Proceed to checkout';

  @override
  String get checkoutAddressTitle => 'Shipping address';

  @override
  String get checkoutAddressAddTooltip => 'Add address';

  @override
  String get checkoutAddressLoadFailedTitle => 'Could not load addresses';

  @override
  String get checkoutAddressEmptyTitle => 'Add your first address';

  @override
  String get checkoutAddressEmptyMessage =>
      'Save a shipping address to continue checkout.';

  @override
  String get checkoutAddressAddAction => 'Add address';

  @override
  String get checkoutAddressChooseHint => 'Choose where to ship your order.';

  @override
  String get checkoutAddressAddAnother => 'Add another address';

  @override
  String get checkoutAddressContinueShipping => 'Continue to shipping';

  @override
  String get checkoutAddressSelectRequired => 'Select an address to continue';

  @override
  String get checkoutAddressSavedCreated => 'Address added';

  @override
  String get checkoutAddressSavedUpdated => 'Address updated';

  @override
  String get checkoutAddressChipShipping => 'Shipping';

  @override
  String get checkoutAddressChipDefault => 'Default';

  @override
  String get checkoutAddressChipBilling => 'Billing';

  @override
  String get checkoutAddressChipInternational => 'International';

  @override
  String get checkoutAddressLabelFallback => 'Shipping address';

  @override
  String get checkoutAddressEditAction => 'Edit';

  @override
  String get checkoutAddressPersonaDomesticHint =>
      'Use postal lookup for Japanese addresses; include building name.';

  @override
  String get checkoutAddressPersonaInternationalHint =>
      'For international shipping, enter romanized names and a phone with country code.';

  @override
  String get checkoutAddressFormAddTitle => 'Add address';

  @override
  String get checkoutAddressFormEditTitle => 'Edit address';

  @override
  String get checkoutAddressFormDomesticLabel => 'Domestic (JP)';

  @override
  String get checkoutAddressFormInternationalLabel => 'International';

  @override
  String get checkoutAddressFormLabelOptional => 'Label (optional)';

  @override
  String get checkoutAddressFormRecipient => 'Recipient';

  @override
  String get checkoutAddressFormCompanyOptional => 'Company (optional)';

  @override
  String get checkoutAddressFormPostalCode => 'Postal code';

  @override
  String get checkoutAddressFormLookup => 'Lookup';

  @override
  String get checkoutAddressFormState => 'Prefecture/State';

  @override
  String get checkoutAddressFormCity => 'City/Ward';

  @override
  String get checkoutAddressFormLine1 => 'Address line 1';

  @override
  String get checkoutAddressFormLine2Optional => 'Address line 2 (optional)';

  @override
  String get checkoutAddressFormCountry => 'Country/Region';

  @override
  String get checkoutAddressFormPhone => 'Phone (with country code)';

  @override
  String get checkoutAddressFormDefaultTitle => 'Use as default';

  @override
  String get checkoutAddressFormDefaultSubtitle =>
      'Default address is pre-selected in checkout.';

  @override
  String get checkoutAddressFormSave => 'Save address';

  @override
  String get checkoutAddressFormFixErrors =>
      'Please correct the highlighted fields.';

  @override
  String get checkoutAddressRequired => 'Required';

  @override
  String get checkoutAddressRecipientRequired => 'Recipient is required';

  @override
  String get checkoutAddressLine1Required => 'Address line is required';

  @override
  String get checkoutAddressCityRequired => 'City/Ward is required';

  @override
  String get checkoutAddressPostalFormat => 'Use 123-4567 format';

  @override
  String get checkoutAddressStateRequired => 'Prefecture is required';

  @override
  String get checkoutAddressCountryJapanRequired => 'Set country to Japan (JP)';

  @override
  String get checkoutAddressPhoneDomestic => 'Include area code (10+ digits)';

  @override
  String get checkoutAddressPostalShort => 'Postal/ZIP is too short';

  @override
  String get checkoutAddressCountryRequired => 'Country/region is required';

  @override
  String get checkoutAddressPhoneInternational => 'Add country code (e.g., +1)';

  @override
  String get checkoutShippingMissingState => 'Missing state';

  @override
  String get checkoutShippingSelectAddress => 'Select an address first.';

  @override
  String get checkoutShippingOptionUnavailable =>
      'Option unavailable for this address.';

  @override
  String get checkoutShippingPromoRequiresExpress =>
      'Promotion requires express shipping.';

  @override
  String get checkoutShippingBadgePopular => 'Popular';

  @override
  String get checkoutShippingBadgeFastest => 'Fastest';

  @override
  String get checkoutShippingBadgeTracked => 'Tracked';

  @override
  String get checkoutShippingOptionDomStandardLabel => 'Yamato standard';

  @override
  String get checkoutShippingOptionDomStandardCarrier => 'Yamato';

  @override
  String get checkoutShippingOptionDomStandardNote => 'Weekends + tracking';

  @override
  String get checkoutShippingOptionDomExpressLabel => 'Express next-day';

  @override
  String get checkoutShippingOptionDomExpressCarrier => 'Yamato/JP Post';

  @override
  String get checkoutShippingOptionDomExpressNote =>
      'Best for promo codes requiring express.';

  @override
  String get checkoutShippingOptionDomPickupLabel => 'Convenience store pickup';

  @override
  String get checkoutShippingOptionDomPickupCarrier => 'Lawson/FamilyMart';

  @override
  String get checkoutShippingOptionDomPickupNote => 'Held for 7 days at store.';

  @override
  String get checkoutShippingOptionIntlExpressLabel => 'Express courier';

  @override
  String get checkoutShippingOptionIntlExpressCarrier => 'DHL / Yamato Global';

  @override
  String get checkoutShippingOptionIntlExpressNote =>
      'Includes customs pre-clearance.';

  @override
  String get checkoutShippingOptionIntlPriorityLabel => 'Priority air';

  @override
  String get checkoutShippingOptionIntlPriorityCarrier => 'EMS';

  @override
  String get checkoutShippingOptionIntlPriorityNote =>
      'Hands-on support for customs forms.';

  @override
  String get checkoutShippingOptionIntlEconomyLabel => 'Economy air';

  @override
  String get checkoutShippingOptionIntlEconomyCarrier => 'JP Post Air';

  @override
  String get checkoutShippingOptionIntlEconomyNote =>
      'Best for budget-friendly delivery.';

  @override
  String get checkoutShippingBannerInternationalDelay =>
      'Customs screening is adding 1–2 days to some international deliveries.';

  @override
  String get checkoutShippingBannerKyushuDelay =>
      'Seasonal weather may delay Kyushu deliveries by half a day.';

  @override
  String get shopTitle => 'Shop';

  @override
  String get shopSearchTooltip => 'Search';

  @override
  String get shopCartTooltip => 'Cart';

  @override
  String get shopAppBarSubtitle => 'Pick materials, bundles, and add-ons';

  @override
  String get shopActionPromotions => 'See promotions';

  @override
  String get shopActionGuides => 'Guides';

  @override
  String get shopQuickGuidesTitle => 'Quick guides';

  @override
  String get shopQuickGuidesSubtitle =>
      'Size, care, and cultural tips in one place';

  @override
  String get shopBrowseByMaterialTitle => 'Browse by material';

  @override
  String get shopBrowseByMaterialSubtitle =>
      'Find a feel that matches your use case';

  @override
  String get shopPromotionsTitle => 'Promotions';

  @override
  String get shopPromotionsSubtitle => 'Bundles and fast track slots';

  @override
  String get shopPromotionsEmpty => 'No promotions available right now.';

  @override
  String get shopRecommendedMaterialsTitle => 'Recommended materials';

  @override
  String get shopRecommendedMaterialsSubtitle =>
      'Based on persona and delivery needs';

  @override
  String get shopRecommendedMaterialsEmpty =>
      'Materials are being prepared. Please check back soon.';

  @override
  String get shopHeroBadge => 'Seasonal pick';

  @override
  String get shopHeroTitle => 'Spring starter bundle with engraving tweaks';

  @override
  String get shopHeroBody =>
      'Case, ink, and DHL-friendly templates in one tap.';

  @override
  String get shopHeroAction => 'Open bundle';

  @override
  String get libraryDesignDetailTitle => 'Design detail';

  @override
  String get libraryDesignDetailSubtitle => 'Library';

  @override
  String get libraryDesignDetailEditTooltip => 'Edit';

  @override
  String get libraryDesignDetailExportTooltip => 'Export';

  @override
  String get libraryDesignDetailTabDetails => 'Details';

  @override
  String get libraryDesignDetailTabActivity => 'Activity';

  @override
  String get libraryDesignDetailTabFiles => 'Files';

  @override
  String get libraryDesignDetailMetadataTitle => 'Metadata';

  @override
  String get libraryDesignDetailUsageHistoryTitle => 'Usage history';

  @override
  String get libraryDesignDetailNoActivity => 'No activity yet.';

  @override
  String get libraryDesignDetailFilesTitle => 'Files';

  @override
  String get libraryDesignDetailPreviewPngLabel => 'Preview PNG';

  @override
  String get libraryDesignDetailVectorSvgLabel => 'Vector SVG';

  @override
  String get libraryDesignDetailExportAction => 'Export';

  @override
  String get libraryDesignDetailUntitled => 'Untitled';

  @override
  String get libraryDesignDetailAiScoreUnknown => 'AI score: -';

  @override
  String get libraryDesignDetailAiScoreLabel => 'AI score: {score}';

  @override
  String get libraryDesignDetailRegistrabilityUnknown => 'Registrability: -';

  @override
  String get libraryDesignDetailRegistrable => 'Registrable';

  @override
  String get libraryDesignDetailNotRegistrable => 'Not registrable';

  @override
  String get libraryDesignDetailActionVersions => 'Versions';

  @override
  String get libraryDesignDetailActionShare => 'Share';

  @override
  String get libraryDesignDetailActionLinks => 'Links';

  @override
  String get libraryDesignDetailActionDuplicate => 'Duplicate';

  @override
  String get libraryDesignDetailActionReorder => 'Reorder';

  @override
  String get libraryDesignDetailActionArchive => 'Archive';

  @override
  String get libraryDesignDetailArchiveTitle => 'Archive design?';

  @override
  String get libraryDesignDetailArchiveBody =>
      'This removes the design from your library (mocked local data).';

  @override
  String get libraryDesignDetailArchiveCancel => 'Cancel';

  @override
  String get libraryDesignDetailArchiveConfirm => 'Archive';

  @override
  String get libraryDesignDetailArchived => 'Archived';

  @override
  String get libraryDesignDetailReorderHint =>
      'Pick a product, then attach this design (mock)';

  @override
  String get libraryDesignDetailHydrateFailed =>
      'Failed to prepare editor: {error}';

  @override
  String get libraryDesignDetailFileNotAvailable => 'Not available';

  @override
  String get libraryDesignDetailMetadataDesignId => 'Design ID';

  @override
  String get libraryDesignDetailMetadataStatus => 'Status';

  @override
  String get libraryDesignDetailMetadataAiScore => 'AI score';

  @override
  String get libraryDesignDetailMetadataRegistrability => 'Registrability';

  @override
  String get libraryDesignDetailMetadataCreated => 'Created';

  @override
  String get libraryDesignDetailMetadataUpdated => 'Updated';

  @override
  String get libraryDesignDetailMetadataLastUsed => 'Last used';

  @override
  String get libraryDesignDetailMetadataVersion => 'Version';

  @override
  String get libraryDesignDetailActivityCreatedTitle => 'Created';

  @override
  String get libraryDesignDetailActivityUpdatedTitle => 'Updated';

  @override
  String get libraryDesignDetailActivityOrderedTitle => 'Ordered';

  @override
  String get libraryDesignDetailActivityCreatedDetail => 'Saved';

  @override
  String get libraryDesignDetailActivityUpdatedDetail => 'Applied updates';

  @override
  String get libraryDesignDetailActivityOrderedDetail => 'Ready to reorder';

  @override
  String get orderDetailTitleFallback => 'Order';

  @override
  String get orderDetailTooltipReorder => 'Reorder';

  @override
  String get orderDetailTooltipShare => 'Share';

  @override
  String get orderDetailTooltipMore => 'More';

  @override
  String get orderDetailMenuContactSupport => 'Contact support';

  @override
  String get orderDetailMenuCancelOrder => 'Cancel order';

  @override
  String get orderDetailTabSummary => 'Summary';

  @override
  String get orderDetailTabTimeline => 'Timeline';

  @override
  String get orderDetailTabFiles => 'Files';

  @override
  String get orderDetailShareText => 'Order {number}';

  @override
  String get orderDetailInvoiceRequestSent => 'Invoice request sent (mock)';

  @override
  String get orderDetailInvoiceRequestFailed => 'Could not request invoice';

  @override
  String get orderDetailCancelTitle => 'Cancel this order?';

  @override
  String get orderDetailCancelBody =>
      'If production already started, cancellation may not be possible.';

  @override
  String get orderDetailCancelConfirm => 'Cancel order';

  @override
  String get orderDetailCancelKeep => 'Keep';

  @override
  String get orderDetailCancelSuccess => 'Order canceled';

  @override
  String get orderDetailCancelFailed => 'Could not cancel';

  @override
  String get orderDetailDesignPreviewOk => 'OK';

  @override
  String get orderDetailBannerInProgress =>
      'Your order is in progress. You can check production and tracking here.';

  @override
  String get orderDetailBannerProduction => 'Production';

  @override
  String get orderDetailBannerTracking => 'Tracking';

  @override
  String get orderDetailSectionOrder => 'Order';

  @override
  String get orderDetailSectionItems => 'Items';

  @override
  String get orderDetailSectionTotal => 'Total';

  @override
  String get orderDetailSubtotal => 'Subtotal';

  @override
  String get orderDetailDiscount => 'Discount';

  @override
  String get orderDetailShipping => 'Shipping';

  @override
  String get orderDetailShippingFree => 'Free';

  @override
  String get orderDetailTax => 'Tax';

  @override
  String get orderDetailTotal => 'Total';

  @override
  String get orderDetailShippingAddress => 'Shipping address';

  @override
  String get orderDetailBillingAddress => 'Billing address';

  @override
  String get orderDetailPayment => 'Payment';

  @override
  String get orderDetailDesignSnapshots => 'Design snapshots';

  @override
  String get orderDetailQuickActions => 'Quick actions';

  @override
  String get orderDetailRequestInvoice => 'Request invoice';

  @override
  String get orderDetailContactSupport => 'Contact support';

  @override
  String get orderDetailTimelineTitle => 'Timeline';

  @override
  String get orderDetailProductionEvents => 'Production events';

  @override
  String get orderDetailInvoiceTitle => 'Invoice';

  @override
  String get orderDetailInvoiceHint =>
      'You can request and view invoices here.';

  @override
  String get orderDetailInvoiceRequest => 'Request';

  @override
  String get orderDetailInvoiceView => 'View';

  @override
  String get orderDetailItemQtyLabel => 'Qty {quantity}';

  @override
  String get orderDetailPaymentPending => 'Pending';

  @override
  String get orderDetailPaymentPaid => 'Paid';

  @override
  String get orderDetailPaymentCanceled => 'Canceled';

  @override
  String get orderDetailPaymentProcessing => 'Processing';

  @override
  String get orderDetailPaymentNoInfo => 'No payment information';

  @override
  String get orderDetailPaymentPaidAt => 'Paid at {date}';

  @override
  String get orderDetailPaymentMethodCard => 'Card';

  @override
  String get orderDetailPaymentMethodWallet => 'Wallet';

  @override
  String get orderDetailPaymentMethodBank => 'Bank';

  @override
  String get orderDetailPaymentMethodOther => 'Other';

  @override
  String get orderDetailPaymentSeparator => ' · ';

  @override
  String get orderDetailMeta => 'ID {id} · {date}';

  @override
  String get orderDetailStatusPending => 'Pending';

  @override
  String get orderDetailStatusPaid => 'Paid';

  @override
  String get orderDetailStatusInProduction => 'In production';

  @override
  String get orderDetailStatusReadyToShip => 'Ready to ship';

  @override
  String get orderDetailStatusShipped => 'Shipped';

  @override
  String get orderDetailStatusDelivered => 'Delivered';

  @override
  String get orderDetailStatusCanceled => 'Canceled';

  @override
  String get orderDetailStatusProcessing => 'Processing';

  @override
  String get orderDetailMilestonePlaced => 'Placed';

  @override
  String get orderDetailMilestonePaid => 'Paid';

  @override
  String get orderDetailMilestoneProduction => 'Production';

  @override
  String get orderDetailMilestoneShipped => 'Shipped';

  @override
  String get orderDetailMilestoneDelivered => 'Delivered';

  @override
  String get orderDetailMilestoneCanceled => 'Canceled';

  @override
  String get kanjiDictionaryTitle => 'Kanji dictionary';

  @override
  String get kanjiDictionaryToggleShowAll => 'Show all';

  @override
  String get kanjiDictionaryToggleShowFavorites => 'Show favorites';

  @override
  String get kanjiDictionaryOpenGuides => 'Open guides';

  @override
  String get kanjiDictionarySearchHint => 'Search kanji';

  @override
  String get kanjiDictionaryHistoryHint =>
      'Search for meanings, readings, or sample names.';

  @override
  String get kanjiDictionaryHistoryTitle => 'History';

  @override
  String get kanjiDictionaryFiltersTitle => 'Filters';

  @override
  String get kanjiDictionaryGradesAll => 'All grades';

  @override
  String get kanjiDictionaryGrade1 => 'Grade 1';

  @override
  String get kanjiDictionaryGrade2 => 'Grade 2';

  @override
  String get kanjiDictionaryGrade3 => 'Grade 3';

  @override
  String get kanjiDictionaryGrade4 => 'Grade 4';

  @override
  String get kanjiDictionaryGrade5 => 'Grade 5';

  @override
  String get kanjiDictionaryGrade6 => 'Grade 6+';

  @override
  String get kanjiDictionaryStrokesAll => 'All strokes';

  @override
  String get kanjiDictionaryRadicalAny => 'Any radical';

  @override
  String get kanjiDictionaryRadicalWater => 'Water';

  @override
  String get kanjiDictionaryRadicalSun => 'Sun';

  @override
  String get kanjiDictionaryRadicalPlant => 'Plant';

  @override
  String get kanjiDictionaryRadicalHeart => 'Heart';

  @override
  String get kanjiDictionaryRadicalEarth => 'Earth';

  @override
  String get kanjiDictionaryStrokeCount => '{count} strokes';

  @override
  String get kanjiDictionaryRadicalLabel => 'Radical: {radical}';

  @override
  String get kanjiDictionaryFavorite => 'Favorite';

  @override
  String get kanjiDictionaryUnfavorite => 'Unfavorite';

  @override
  String get kanjiDictionaryDetails => 'Details';

  @override
  String get kanjiDictionaryChipStrokes => 'Strokes: {count}';

  @override
  String get kanjiDictionaryChipRadical => 'Radical: {radical}';

  @override
  String get kanjiDictionaryStrokeOrderTitle => 'Stroke order';

  @override
  String get kanjiDictionaryExamplesTitle => 'Examples';

  @override
  String get kanjiDictionaryInsertIntoNameInput => 'Insert into name input';

  @override
  String get kanjiDictionaryDone => 'Done';

  @override
  String get kanjiDictionaryExampleUsage => 'Used in names and seals';

  @override
  String get kanjiDictionaryNoStrokeData => 'No stroke data.';

  @override
  String get kanjiDictionaryStrokeOrderPrefix => 'Order: {steps}';

  @override
  String get orderInvoiceTitle => 'Invoice';

  @override
  String get orderInvoiceShareTooltip => 'Share';

  @override
  String get orderInvoiceLoadFailed => 'Could not load invoice';

  @override
  String get orderInvoiceDownloadPdf => 'Download PDF';

  @override
  String get orderInvoiceSendEmail => 'Send by email';

  @override
  String get orderInvoiceContactSupport => 'Contact support';

  @override
  String get orderInvoiceTotalLabel => 'Total';

  @override
  String get orderInvoiceStatusAvailable => 'Available';

  @override
  String get orderInvoiceStatusPending => 'Pending';

  @override
  String get orderInvoiceTaxable => 'Taxable';

  @override
  String get orderInvoiceTaxExempt => 'Tax exempt';

  @override
  String get orderInvoicePreviewTitle => 'Preview';

  @override
  String get orderInvoiceRefreshTooltip => 'Refresh';

  @override
  String get orderInvoicePendingBody => 'Invoice is being prepared.';

  @override
  String get orderInvoiceUnavailableBody => 'Invoice preview is not available.';

  @override
  String get orderInvoiceRequestAction => 'Request invoice';

  @override
  String get orderInvoiceSavedTo => 'Saved to {path}';

  @override
  String get orderInvoiceSaveFailed => 'Could not save PDF';

  @override
  String get orderInvoiceShareText => '{app} • {number}';

  @override
  String get orderInvoiceOrderLabel => 'Order {number}';

  @override
  String get orderInvoiceIssuedLabel => 'Issued: {date}';

  @override
  String get orderProductionTitle => 'Production';

  @override
  String get orderProductionRefreshTooltip => 'Refresh';

  @override
  String get orderProductionStatusLabel => 'Status: {status}';

  @override
  String get orderProductionEtaLabel => 'Estimated completion: {date}';

  @override
  String get orderProductionDelayedMessage =>
      'This order is past the estimated completion date.';

  @override
  String get orderProductionTimelineTitle => 'Timeline';

  @override
  String get orderProductionNoEventsTitle => 'No events yet';

  @override
  String get orderProductionNoEventsMessage =>
      'Production updates will appear here when available.';

  @override
  String get orderProductionNoEventsAction => 'Refresh';

  @override
  String get orderProductionHealthOnTrack => 'On track';

  @override
  String get orderProductionHealthAttention => 'Attention';

  @override
  String get orderProductionHealthDelayed => 'Delayed';

  @override
  String get orderProductionEventStation => 'Station: {station}';

  @override
  String get orderProductionEventQc => 'QC: {details}';

  @override
  String get orderProductionEventQueued => 'Queued';

  @override
  String get orderProductionEventEngraving => 'Engraving';

  @override
  String get orderProductionEventPolishing => 'Polishing';

  @override
  String get orderProductionEventQualityCheck => 'Quality check';

  @override
  String get orderProductionEventPacked => 'Packed';

  @override
  String get orderProductionEventOnHold => 'On hold';

  @override
  String get orderProductionEventRework => 'Rework';

  @override
  String get orderProductionEventCanceled => 'Canceled';

  @override
  String get commonCancel => 'Cancel';

  @override
  String get commonPlaceholder => '—';

  @override
  String get commonVersionLabel => 'v{version}';

  @override
  String get commonSizeMillimeters => '{size}mm';

  @override
  String get commonPercentLabel => '{percent}%';

  @override
  String get commonPercentDiscountLabel => '-{percent}%';

  @override
  String get cartSummaryItem => '{count} item';

  @override
  String get profileExportTimeMinute => '{count} min ago';

  @override
  String get profileExportTimeHour => '{count} hr ago';

  @override
  String get profileExportTimeDay => '{count} day ago';

  @override
  String get profileExportTimeCompactMinute => '{count}m';

  @override
  String get profileExportTimeCompactHour => '{count}h';

  @override
  String get profileExportTimeCompactDay => '{count}d';

  @override
  String get designVersionsRelativeMinute => '{count}m ago';

  @override
  String get designVersionsRelativeHour => '{count}h ago';

  @override
  String get designVersionsRelativeDay => '{count}d ago';

  @override
  String get kanjiDictionaryStrokeCountOne => '{count} stroke';

  @override
  String get kanjiDictionaryChipStrokesOne => 'Stroke: {count}';

  @override
  String get notificationsEmptyUnreadMessage => 'You are all caught up.';

  @override
  String get notificationsEmptyAllMessage => 'No notifications yet.';

  @override
  String get notificationsEmptyTitle => 'Inbox is clear';

  @override
  String get notificationsRefresh => 'Refresh';

  @override
  String get notificationsLoadMoreHint => 'Pull to load more';

  @override
  String get notificationsMarkedRead => 'Marked as read';

  @override
  String get notificationsMarkedUnread => 'Moved back to unread';

  @override
  String get notificationsUndo => 'Undo';

  @override
  String get notificationsAllCaughtUp => 'All caught up';

  @override
  String get notificationsUnreadCount => '{count} unread';

  @override
  String get notificationsMoreTooltip => 'More';

  @override
  String get notificationsMarkAllRead => 'Mark all read';

  @override
  String get notificationsFilterAll => 'All';

  @override
  String get notificationsFilterUnread => 'Unread';

  @override
  String get notificationsMarkRead => 'Mark read';

  @override
  String get notificationsMarkUnread => 'Mark unread';

  @override
  String get notificationsToday => 'Today';

  @override
  String get notificationsYesterday => 'Yesterday';

  @override
  String get notificationsCategoryOrder => 'Order';

  @override
  String get notificationsCategoryDesign => 'Design';

  @override
  String get notificationsCategoryPromo => 'Promo';

  @override
  String get notificationsCategorySupport => 'Support';

  @override
  String get notificationsCategoryStatus => 'Status';

  @override
  String get notificationsCategorySecurity => 'Security';

  @override
  String get orderReorderTitle => 'Reorder';

  @override
  String get orderReorderSelectItem => 'Select at least one item to reorder';

  @override
  String get orderReorderCartRebuilt => 'Cart rebuilt for checkout';

  @override
  String get orderReorderFromOrder => 'From {order}';

  @override
  String get orderReorderSelectedCount => '{selected}/{total} selected';

  @override
  String get orderReorderRebuildCart => 'Rebuild cart';

  @override
  String get orderReorderBannerOutOfStockAndPrice =>
      'Some items are out of stock and some prices have changed.';

  @override
  String get orderReorderBannerOutOfStock => 'Some items are out of stock.';

  @override
  String get orderReorderBannerPriceChanged =>
      'Some prices have changed since your last order.';

  @override
  String get orderReorderBannerUpdates => 'Updates available.';

  @override
  String get orderReorderDismiss => 'Dismiss';

  @override
  String get orderReorderItemFallback => 'Item';

  @override
  String get orderReorderDesignLabel => 'Design: {label}';

  @override
  String get orderReorderOutOfStock => 'Out of stock';

  @override
  String get orderReorderPriceUpdated => 'Price updated';

  @override
  String get orderReorderLoadFailed => 'Could not load reorder data.';

  @override
  String get nameValidationSurnameRequired => 'Enter surname';

  @override
  String get nameValidationSurnameFullWidth => 'Use full width';

  @override
  String get nameValidationGivenRequired => 'Enter given name';

  @override
  String get nameValidationGivenFullWidth => 'Use full width';

  @override
  String get nameValidationSurnameKanaRequired => 'Enter surname kana';

  @override
  String get nameValidationKanaFullWidth => 'Use full-width kana';

  @override
  String get nameValidationGivenKanaRequired => 'Enter given name kana';

  @override
  String get nameValidationKanaFullWidthRecommended =>
      'Use kana in full width for engraving accuracy';

  @override
  String get supportChatSeedGreeting =>
      "Hi! I'm Hana, your support bot. How can I help today?";
}

class AppLocalizationsJa implements AppLocalizationsStrings {
  const AppLocalizationsJa();

  @override
  String get appTitle => 'ハンコフィールド';

  @override
  String get welcomeHeadline => 'あなたらしい印鑑をつくる';

  @override
  String get welcomeBody => 'ローカライズ、テーマ、デザイントークンの準備ができました。';

  @override
  String get primaryAction => 'はじめる';

  @override
  String get secondaryAction => 'デザインを見る';

  @override
  String get onboardingTitle => 'チュートリアル';

  @override
  String get onboardingSkip => 'スキップ';

  @override
  String get onboardingNext => '次へ';

  @override
  String get onboardingBack => '戻る';

  @override
  String get onboardingFinish => '設定を進める';

  @override
  String get onboardingRetry => '再読み込み';

  @override
  String get onboardingErrorTitle => 'チュートリアルを読み込めませんでした';

  @override
  String get onboardingStepCount => '{total} ステップ中 {current} ステップ目';

  @override
  String get onboardingSlideCreateTitle => '迷わずつくれるデザイン';

  @override
  String get onboardingSlideCreateBody => '書体・バランスをプレビューしながら、印鑑に合うテンプレを提案します。';

  @override
  String get onboardingSlideCreateTagline => '作成';

  @override
  String get onboardingSlideMaterialsTitle => '素材選びもかんたん';

  @override
  String get onboardingSlideMaterialsBody => '木・石・金属の特徴や在庫状況を比較し、おすすめを提示します。';

  @override
  String get onboardingSlideMaterialsTagline => 'ショップ';

  @override
  String get onboardingSlideSupportTitle => 'サポート付きで安心';

  @override
  String get onboardingSlideSupportBody => '途中保存やWebとの連携ができ、困ったらすぐに相談できます。';

  @override
  String get onboardingSlideSupportTagline => 'サポート';

  @override
  String get localeTitle => '言語・地域の設定';

  @override
  String get localeSave => '保存';

  @override
  String get localeSubtitle => '表示言語を選択してください';

  @override
  String get localeDescription => '端末の言語設定: {device}';

  @override
  String get localeContinue => '保存して進む';

  @override
  String get localeUseDevice => '端末の設定を使う';

  @override
  String get personaTitle => 'ペルソナを選択';

  @override
  String get personaSave => '保存';

  @override
  String get personaSubtitle => 'あなたに合わせた案内に切り替えます';

  @override
  String get personaDescription => '利用シーンに近いスタイルを選ぶと、最適なガイドを表示します。';

  @override
  String get personaContinue => '次へ進む';

  @override
  String get personaUseSelected => 'この設定で進む';

  @override
  String get authTitle => 'ログインまたは続行';

  @override
  String get authSubtitle => '利用方法を選んでください';

  @override
  String get authBody => 'デザインの保存や注文にはログインが必要です。ゲストでも閲覧できます。';

  @override
  String get authEmailLabel => 'メールアドレス';

  @override
  String get authEmailHelper => '領収書やアカウント復旧に使用します。';

  @override
  String get authEmailRequired => 'メールアドレスを入力してください。';

  @override
  String get authEmailInvalid => '有効なメールアドレスを入力してください。';

  @override
  String get authPasswordLabel => 'パスワード';

  @override
  String get authPasswordHelper => '8文字以上で入力してください。';

  @override
  String get authPasswordTooShort => 'パスワードが短すぎます。';

  @override
  String get authEmailCta => 'メールで続ける';

  @override
  String get authAppleButton => 'Appleで続ける';

  @override
  String get authGoogleButton => 'Googleで続ける';

  @override
  String get authGuestCta => 'ゲストとして続行';

  @override
  String get authGuestNote => 'ゲストは閲覧のみ、保存や購入は制限されます。';

  @override
  String get authHelpTooltip => 'ヘルプ';

  @override
  String get authHelpTitle => 'サインインについて';

  @override
  String get authHelpBody =>
      'アカウントでデザインや注文を安全に同期します。後から設定でApple/Googleを連携できます。';

  @override
  String get authErrorCancelled => 'サインインをキャンセルしました。';

  @override
  String get authErrorNetwork => 'ネットワークに接続できません。';

  @override
  String get authErrorInvalid => '認証情報が無効です。もう一度お試しください。';

  @override
  String get authErrorWrongPassword => 'メールアドレスまたはパスワードが正しくありません。';

  @override
  String get authErrorWeakPassword => 'パスワードが弱すぎます（8文字以上推奨）。';

  @override
  String get authErrorAppleUnavailable => 'この端末ではAppleでのサインインは利用できません。';

  @override
  String get authErrorLink => '{providers}ですでに登録済みです。その方法でサインインして連携してください。';

  @override
  String get authErrorUnknown => 'サインインできませんでした。再度お試しください。';

  @override
  String get authLinkingTitle => 'アカウントを連携';

  @override
  String get authLinkPrompt => '{providers}でサインインするとアカウントをまとめられます。';

  @override
  String get authProviderUnknown => '既存の方法';

  @override
  String get authProviderGoogle => 'Google';

  @override
  String get authProviderApple => 'Apple';

  @override
  String get authProviderEmail => 'メール';

  @override
  String get profileTitle => 'プロフィール';

  @override
  String get profileAvatarUpdateTooltip => 'プロフィール写真を変更';

  @override
  String get profileAvatarUpdateTitle => 'プロフィール写真の変更';

  @override
  String get profileAvatarUpdateBody =>
      'プロフィール写真の更新は準備中です。現在はペルソナ切替と各種設定の確認ができます。';

  @override
  String get profileAvatarUpdateOk => 'OK';

  @override
  String get profileLoadFailedTitle => 'プロフィールを読み込めませんでした';

  @override
  String get profileLoadFailedMessage => 'プロフィールの読み込みに失敗しました。再度お試しください。';

  @override
  String get profileRetry => '再試行';

  @override
  String get profileStatusSignedOut => '未ログイン';

  @override
  String get profileStatusGuest => 'ゲスト';

  @override
  String get profileStatusMember => 'ログイン済み';

  @override
  String get profileFallbackGuestName => 'ゲスト';

  @override
  String get profileFallbackProfileName => 'プロフィール';

  @override
  String get profilePersonaTitle => 'ペルソナ';

  @override
  String get profilePersonaSubtitle => 'ガイドやおすすめ表示を切り替えます。';

  @override
  String get profilePersonaJapanese => '日本向け';

  @override
  String get profilePersonaForeigner => '海外向け';

  @override
  String get profileQuickLinksTitle => 'クイックリンク';

  @override
  String get profileQuickOrdersTitle => '注文';

  @override
  String get profileQuickOrdersSubtitle => '注文履歴を確認';

  @override
  String get profileQuickLibraryTitle => 'マイ印鑑';

  @override
  String get profileQuickLibrarySubtitle => '保存したデザイン';

  @override
  String get profileSettingsTitle => '設定';

  @override
  String get profileAddressesTitle => '住所帳';

  @override
  String get profileAddressesSubtitle => '配送先を管理';

  @override
  String get profilePaymentsTitle => '支払い方法';

  @override
  String get profilePaymentsSubtitle => '支払い手段を管理';

  @override
  String get paymentMethodErrorLast4 => '下4桁を入力してください';

  @override
  String get paymentMethodErrorExpMonth => '有効期限(月)を入力してください';

  @override
  String get paymentMethodErrorExpYear => '有効期限(年)を入力してください';

  @override
  String get paymentMethodErrorFixFields => '入力内容を確認してください';

  @override
  String get paymentMethodAddFailed => '支払い方法を追加できません';

  @override
  String get paymentMethodSheetTitle => '支払い方法を追加';

  @override
  String get paymentMethodSheetCard => 'カード';

  @override
  String get paymentMethodSheetWallet => 'ウォレット';

  @override
  String get paymentMethodSheetBrandLabel => 'ブランド (例: Visa)';

  @override
  String get paymentMethodSheetLast4Label => 'カード下4桁';

  @override
  String get paymentMethodSheetExpMonthLabel => '有効期限(月)';

  @override
  String get paymentMethodSheetExpYearLabel => '有効期限(年)';

  @override
  String get paymentMethodSheetBillingNameLabel => '請求先名 (任意)';

  @override
  String get paymentMethodSheetSave => '保存';

  @override
  String get profileNotificationsTitle => '通知設定';

  @override
  String get profileNotificationsSubtitle => '通知の受け取りを設定';

  @override
  String get profileNotificationsHeader => 'ハンコフィールドからの通知方法を選択します。';

  @override
  String get profileNotificationsPushHeader => 'プッシュ通知';

  @override
  String get profileNotificationsEmailHeader => 'メール通知';

  @override
  String get profileNotificationsDigestHeader => 'まとめ通知の頻度';

  @override
  String get profileNotificationsDigestHelper => 'メールの配信頻度を選択してください。';

  @override
  String get profileNotificationsDigestDaily => '毎日';

  @override
  String get profileNotificationsDigestWeekly => '毎週';

  @override
  String get profileNotificationsDigestMonthly => '毎月';

  @override
  String get profileNotificationsSave => '設定を保存';

  @override
  String get profileNotificationsReset => 'リセット';

  @override
  String get profileNotificationsSaved => '通知設定を保存しました。';

  @override
  String get profileNotificationsSaveFailed => '通知設定を保存できませんでした。';

  @override
  String get profileNotificationsLoadFailedTitle => '通知設定を読み込めません';

  @override
  String get profileNotificationsCategoryOrdersTitle => '注文状況';

  @override
  String get profileNotificationsCategoryOrdersBody => '発送、製作、配達のステータス更新。';

  @override
  String get profileNotificationsCategoryDesignsTitle => 'デザインの進捗';

  @override
  String get profileNotificationsCategoryDesignsBody => 'AI提案や修正、承認の通知。';

  @override
  String get profileNotificationsCategoryPromosTitle => 'キャンペーン';

  @override
  String get profileNotificationsCategoryPromosBody => '新作や季節限定、特別オファー。';

  @override
  String get profileNotificationsCategoryGuidesTitle => 'ガイドとヒント';

  @override
  String get profileNotificationsCategoryGuidesBody => '使い方コンテンツや文化的なヒント。';

  @override
  String get profileLocaleTitle => '言語と通貨';

  @override
  String get profileLocaleSubtitle => '表示言語と地域設定';

  @override
  String get profileLocaleLanguageHeader => '表示言語';

  @override
  String get profileLocaleLanguageHelper => 'メニューやコンテンツの表示言語を選択します。';

  @override
  String get profileLocaleCurrencyHeader => '通貨';

  @override
  String get profileLocaleCurrencyHelper => '価格表示の通貨を上書きします。';

  @override
  String get profileLocaleCurrencyAuto => '自動';

  @override
  String get profileLocaleCurrencyAutoHint => '言語・地域に合わせて {currency} を使います。';

  @override
  String get profileLocaleCurrencyJpy => 'JPY';

  @override
  String get profileLocaleCurrencyUsd => 'USD';

  @override
  String get profileLocaleSave => '保存';

  @override
  String get profileLocaleSaved => '言語と通貨の設定を保存しました。';

  @override
  String get profileLocaleSaveFailed => '設定を保存できませんでした。';

  @override
  String get profileLocaleUseDevice => '端末の言語に合わせる';

  @override
  String get profileLegalTitle => '規約・法務';

  @override
  String get profileLegalSubtitle => '利用規約やプライバシー';

  @override
  String get profileLegalDownloadTooltip => 'オフライン用に保存';

  @override
  String get profileLegalDownloadComplete => '法務文書をオフライン用に保存しました。';

  @override
  String get profileLegalDownloadFailed => '保存できませんでした。再試行してください。';

  @override
  String get profileLegalLoadFailedTitle => '法務文書を読み込めませんでした';

  @override
  String get profileLegalDocumentsTitle => '文書一覧';

  @override
  String get profileLegalContentTitle => '文書';

  @override
  String get profileLegalOpenInBrowser => 'ブラウザで開く';

  @override
  String get profileLegalVersionUnknown => '最新';

  @override
  String get profileLegalNoDocument => '表示する文書を選択してください。';

  @override
  String get profileLegalUnavailable => '現在この文書を利用できません。';

  @override
  String get profileLegalNoContent => '文書の内容がありません。';

  @override
  String get profileSupportTitle => 'サポート';

  @override
  String get profileSupportSubtitle => 'FAQ・問い合わせ';

  @override
  String get supportChatConnectedAgent => 'サポート担当の理奈が参加しました。';

  @override
  String get supportChatAgentGreeting => '理奈です。こちらで対応します。注文IDがあれば教えてください。';

  @override
  String get supportChatBotHandoff => '承知しました。担当者におつなぎします。';

  @override
  String get supportChatBotDelivery => '通常は3〜5営業日でお届けします。注文IDはお持ちですか？';

  @override
  String get supportChatBotOrderStatus => '注文状況を確認できます。注文IDを教えてください。';

  @override
  String get supportChatBotFallback => '注文状況、配送、印面についてお手伝いできます。ご用件を教えてください。';

  @override
  String get supportChatAgentRefund => '返金の件ですね。対象の注文IDを教えてください。';

  @override
  String get supportChatAgentAddress => '制作前であれば配送先の変更が可能です。注文IDを教えてください。';

  @override
  String get supportChatAgentFallback => '確認しますので少々お待ちください。';

  @override
  String get profileGuidesTitle => 'ガイド';

  @override
  String get profileGuidesSubtitle => '文化と使い方の案内';

  @override
  String get profileHowtoTitle => '使い方';

  @override
  String get profileHowtoSubtitle => 'チュートリアルと動画';

  @override
  String get profileLinkedAccountsTitle => '連携アカウント';

  @override
  String get profileLinkedAccountsSubtitle => 'Apple/Google 連携';

  @override
  String get profileLinkedAccountsHeader => '連携済みのサインイン方法を管理します。';

  @override
  String get profileLinkedAccountsAddTooltip => 'アカウントを追加';

  @override
  String get profileLinkedAccountsLoadFailedTitle => '連携アカウントを読み込めません';

  @override
  String get profileLinkedAccountsSignedOutTitle => 'サインインして連携を管理';

  @override
  String get profileLinkedAccountsSignedOutBody =>
      'サインイン後にApple/Googleを連携できます。';

  @override
  String get profileLinkedAccountsSignIn => 'サインイン';

  @override
  String get profileLinkedAccountsBannerTitle => 'セキュリティのヒント';

  @override
  String get profileLinkedAccountsBannerBody => '強固なパスワードと復旧手段を最新に保ちましょう。';

  @override
  String get profileLinkedAccountsBannerBodyLong =>
      '強固なパスワードを使い、復旧手段を最新に保ち、連携済みのプロバイダを定期的に確認しましょう。';

  @override
  String get profileLinkedAccountsBannerAction => '確認する';

  @override
  String get profileLinkedAccountsConnected => '接続済み';

  @override
  String get profileLinkedAccountsNotConnected => '未接続';

  @override
  String get profileLinkedAccountsProviderFallback => '表示名なし';

  @override
  String get profileLinkedAccountsAutoSignIn => '自動サインイン';

  @override
  String get profileLinkedAccountsNotConnectedHelper => '連携すると自動サインインが有効になります。';

  @override
  String get profileLinkedAccountsUnlink => '解除';

  @override
  String get profileLinkedAccountsUnlinkTitle => '連携を解除しますか？';

  @override
  String get profileLinkedAccountsUnlinkBody => 'このプロバイダでのサインインができなくなります。';

  @override
  String get profileLinkedAccountsUnlinkConfirm => '解除する';

  @override
  String get profileLinkedAccountsCancel => 'キャンセル';

  @override
  String get profileLinkedAccountsUnlinkDisabled => '解除するには別の連携を追加してください。';

  @override
  String get profileLinkedAccountsSave => '変更を保存';

  @override
  String get profileLinkedAccountsSaved => '連携設定を保存しました。';

  @override
  String get profileLinkedAccountsSaveFailed => '変更を保存できませんでした。';

  @override
  String get profileLinkedAccountsLinked => '連携しました。';

  @override
  String get profileLinkedAccountsLinkFailed => '連携できませんでした。';

  @override
  String get profileLinkedAccountsUnlinked => '解除しました。';

  @override
  String get profileLinkedAccountsUnlinkFailed => '解除できませんでした。';

  @override
  String get profileLinkedAccountsLinkTitle => '連携するアカウント';

  @override
  String get profileLinkedAccountsLinkSubtitle => '続けて連携します。';

  @override
  String get profileLinkedAccountsAlreadyLinked => '連携済み';

  @override
  String get profileLinkedAccountsFooter => 'ヒント: 複数のプロバイダを連携すると復旧が容易です。';

  @override
  String get profileLinkedAccountsOk => 'OK';

  @override
  String get profileExportTitle => 'データ出力';

  @override
  String get profileExportSubtitle => 'アカウントデータをDL';

  @override
  String get profileExportAppBarSubtitle => 'アカウントの安全なアーカイブを作成';

  @override
  String get profileExportSummaryTitle => '含まれる内容';

  @override
  String get profileExportSummaryBody => 'プロフィール、保存済み印影、注文履歴、利用履歴をZIPにまとめます。';

  @override
  String get profileExportIncludeAssetsTitle => 'デザイン素材';

  @override
  String get profileExportIncludeAssetsSubtitle => '保存済み印影・テンプレ・プレビュー';

  @override
  String get profileExportIncludeOrdersTitle => '注文・請求書';

  @override
  String get profileExportIncludeOrdersSubtitle => '注文履歴、配送状況、領収書';

  @override
  String get profileExportIncludeHistoryTitle => '利用履歴';

  @override
  String get profileExportIncludeHistorySubtitle => '検索、編集、アクティビティログ';

  @override
  String get profileExportPermissionTitle => 'ストレージ権限が必要です';

  @override
  String get profileExportPermissionBody => 'アーカイブを端末に保存するため許可してください。';

  @override
  String get profileExportPermissionCta => '許可する';

  @override
  String get permissionsTitle => '権限';

  @override
  String get permissionsSubtitle => 'Hanko Fieldを快適に使うための権限です。';

  @override
  String get permissionsHeroTitle => '作業をスムーズに';

  @override
  String get permissionsHeroBody => '作成・書き出し・更新通知に必要なときだけ確認します。';

  @override
  String get permissionsPersonaDomestic => '実印・銀行印の運用を意識した設定です。';

  @override
  String get permissionsPersonaInternational => '海外ユーザー向けのガイド重視設定です。';

  @override
  String get permissionsPhotosTitle => '写真';

  @override
  String get permissionsPhotosBody => '印影の写真やスキャンを取り込み、新規デザインに使います。';

  @override
  String get permissionsPhotosAssist1 => '印影をスキャン';

  @override
  String get permissionsPhotosAssist2 => 'カメラロールから';

  @override
  String get permissionsStorageTitle => 'ファイルとストレージ';

  @override
  String get permissionsStorageBody => '書き出しデータや領収書を端末に保存します。';

  @override
  String get permissionsStorageAssist1 => '書き出しを保存';

  @override
  String get permissionsStorageAssist2 => 'ファイルを添付';

  @override
  String get permissionsNotificationsTitle => '通知';

  @override
  String get permissionsNotificationsBody => '制作・発送・承認の最新情報を受け取ります。';

  @override
  String get permissionsNotificationsAssist1 => '制作アラート';

  @override
  String get permissionsNotificationsAssist2 => '配送状況';

  @override
  String get permissionsStatusGranted => '許可済み';

  @override
  String get permissionsStatusDenied => '未許可';

  @override
  String get permissionsStatusRestricted => '制限中';

  @override
  String get permissionsStatusUnknown => '未選択';

  @override
  String get permissionsFallbackPhotos => '写真へのアクセスは設定アプリで「写真」を許可してください。';

  @override
  String get permissionsFallbackStorage =>
      'ファイルへのアクセスは設定アプリで「ファイル/ストレージ」を許可してください。';

  @override
  String get permissionsFallbackNotifications =>
      '通知を受け取るには設定アプリで「通知」を許可してください。';

  @override
  String get permissionsCtaGrantAll => 'まとめて許可';

  @override
  String get permissionsCtaNotNow => '後で';

  @override
  String get permissionsFooterPolicy => 'データポリシーを見る';

  @override
  String get permissionsItemActionAllow => '許可する';

  @override
  String get profileExportStatusReadyTitle => '準備完了';

  @override
  String get profileExportStatusReadyBody => 'データをZIPアーカイブにまとめます。';

  @override
  String get profileExportStatusInProgressTitle => 'アーカイブ作成中';

  @override
  String get profileExportStatusInProgressBody => 'しばらくお待ちください。アプリを閉じないでください。';

  @override
  String get profileExportStatusDoneTitle => 'エクスポート完了';

  @override
  String get profileExportStatusDoneBody => '安全な領域に保存しました。いつでも再ダウンロードできます。';

  @override
  String get profileExportCtaStart => 'エクスポートを作成';

  @override
  String get profileExportCtaHistory => '過去のエクスポートを見る';

  @override
  String get profileExportHistoryTitle => '過去のエクスポート';

  @override
  String get profileExportHistoryEmptyTitle => 'まだありません';

  @override
  String get profileExportHistoryEmptyBody => 'エクスポートを作成するとここに表示されます。';

  @override
  String get profileExportHistoryDownload => 'アーカイブをダウンロード';

  @override
  String get profileExportErrorTitle => 'データ出力を読み込めませんでした';

  @override
  String get profileExportErrorBody => 'エクスポート設定の読み込みに失敗しました。';

  @override
  String get profileExportRetry => '再試行';

  @override
  String get profileExportTimeJustNow => 'たった今';

  @override
  String get profileExportTimeMinutes => '{count}分前';

  @override
  String get profileExportTimeHours => '{count}時間前';

  @override
  String get profileExportTimeDays => '{count}日前';

  @override
  String get profileExportTimeDate => '{date}';

  @override
  String get profileExportTimeCompactNow => '今';

  @override
  String get profileExportTimeCompactMinutes => '{count}分';

  @override
  String get profileExportTimeCompactHours => '{count}時間';

  @override
  String get profileExportTimeCompactDays => '{count}日';

  @override
  String get profileDeleteTitle => 'アカウント削除';

  @override
  String get profileDeleteSubtitle => '削除手続きを進める';

  @override
  String get profileDeleteWarningTitle => 'アカウント削除は取り消せません';

  @override
  String get profileDeleteWarningBody =>
      'プロフィール、保存した印影、注文履歴は削除されます。'
      '法令上必要な記録は保持される場合があります。';

  @override
  String get profileDeleteAcknowledgementTitle => '確認事項';

  @override
  String get profileDeleteAckDataLossTitle => '保存した印影とプロフィールを削除';

  @override
  String get profileDeleteAckDataLossBody => 'プロフィール、保存デザイン、設定が削除されます。';

  @override
  String get profileDeleteAckOrdersTitle => '進行中の注文は継続';

  @override
  String get profileDeleteAckOrdersBody => '未完了の注文や返金、サポート対応は削除後も処理されます。';

  @override
  String get profileDeleteAckIrreversibleTitle => '取り消し不可';

  @override
  String get profileDeleteAckIrreversibleBody => '再利用するには新規登録が必要です。';

  @override
  String get profileDeleteFooterNote => '削除処理が完了すると自動的にサインアウトします。';

  @override
  String get profileDeleteCta => 'アカウントを削除';

  @override
  String get profileDeleteCancelCta => 'キャンセル';

  @override
  String get profileDeleteConfirmTitle => 'アカウントを削除しますか？';

  @override
  String get profileDeleteConfirmBody => 'アカウントを無効化し、個人データを削除します。元に戻せません。';

  @override
  String get profileDeleteConfirmAction => '削除する';

  @override
  String get profileDeleteConfirmCancel => '残しておく';

  @override
  String get profileDeleteSuccess => '削除を受け付けました。サインアウトしました。';

  @override
  String get profileDeleteError => '削除に失敗しました。もう一度お試しください。';

  @override
  String get profileDeleteErrorTitle => '削除画面を読み込めません';

  @override
  String get profileDeleteErrorBody => '時間をおいて再度お試しください。';

  @override
  String get profileDeleteRetry => '再試行';

  @override
  String get profileSignInCta => 'ログインする';

  @override
  String get profileAccountSecurityTitle => 'アカウント保護';

  @override
  String get profileAccountSecuritySubtitle => 'パスワードや2FA、連携の管理';

  @override
  String get profileAccountSecurityBody => 'セキュリティ設定は今後追加予定です。';

  @override
  String get appUpdateTitle => 'アップデート';

  @override
  String get appUpdateCheckAgain => '再確認';

  @override
  String get appUpdateChecking => 'バージョンを確認中...';

  @override
  String get appUpdateVerifyFailedTitle => 'バージョンを確認できませんでした';

  @override
  String get appUpdateRetry => '再試行';

  @override
  String get appUpdateBannerRequired => '最新バージョンへの更新が必要です。';

  @override
  String get appUpdateBannerOptional => '新しいバージョンが利用可能です。';

  @override
  String get appUpdateBannerAction => '更新する';

  @override
  String get appUpdateCardRequiredTitle => '更新が必要です';

  @override
  String get appUpdateCardOptionalTitle => 'アップデートがあります';

  @override
  String get appUpdateCurrentVersion => '現在のバージョン: {version}';

  @override
  String get appUpdateMinimumVersion => '必須バージョン: {version}';

  @override
  String get appUpdateLatestVersion => '最新バージョン: {version}';

  @override
  String get appUpdateNow => '今すぐ更新';

  @override
  String get appUpdateOpenStore => 'ストアを開く';

  @override
  String get appUpdateContinue => '後で行う';

  @override
  String get appUpdateStoreUnavailable => 'ストアのリンクを取得できませんでした。ストアから更新してください。';

  @override
  String get appUpdateStoreOpenFailed => 'ストアを開けませんでした。ストアアプリから更新してください。';

  @override
  String get appUpdateReminder => '新しいバージョンがあります (v{version})。';

  @override
  String get appUpdateLater => '後で';

  @override
  String get commonBack => '戻る';

  @override
  String get commonRetry => '再試行';

  @override
  String get commonClose => '閉じる';

  @override
  String get commonSave => '保存';

  @override
  String get commonLearnMore => '詳しく見る';

  @override
  String get commonLoadMore => 'もっと見る';

  @override
  String get commonClear => 'クリア';

  @override
  String get commonLoadFailed => '読み込みに失敗しました';

  @override
  String get commonUnknown => '不明';

  @override
  String get offlineTitle => 'オフラインです';

  @override
  String get offlineMessage => 'インターネットに接続してデータを同期してください。';

  @override
  String get offlineRetry => '再試行';

  @override
  String get offlineOpenCachedLibrary => 'キャッシュ済みライブラリを開く';

  @override
  String get offlineCacheHint => 'キャッシュされた項目のみ閲覧できます。';

  @override
  String get offlineLastSyncUnavailable => '最終同期はまだありません';

  @override
  String get offlineLastSyncLabel => '最終同期 {date} {time}';

  @override
  String get changelogTitle => '変更履歴';

  @override
  String get changelogLatestReleaseTooltip => '最新リリース';

  @override
  String get changelogHighlightsTitle => 'ハイライト';

  @override
  String get changelogAllUpdates => 'すべて';

  @override
  String get changelogMajorOnly => '主要のみ';

  @override
  String get changelogUnableToLoad => '更新履歴を読み込めませんでした';

  @override
  String get changelogNoUpdatesTitle => '更新履歴はまだありません';

  @override
  String get changelogNoUpdatesMessage => 'リリースノートが準備でき次第こちらに掲載します。';

  @override
  String get changelogVersionHistoryTitle => 'バージョン履歴';

  @override
  String get changelogVersionHistorySubtitle => 'リリースをタップして詳細を確認できます。';

  @override
  String get searchHintText => 'テンプレート、素材、記事を検索';

  @override
  String get searchVoiceTooltip => '音声検索';

  @override
  String get searchVoiceComingSoon => '音声検索とバーコード検索は近日対応';

  @override
  String get searchRecentTitle => '検索履歴';

  @override
  String get searchSuggestionsTitle => 'サジェスト';

  @override
  String get searchSuggestionsLoadFailed => '候補を取得できませんでした';

  @override
  String get searchResultsErrorTitle => '検索できませんでした';

  @override
  String get searchResultsEmptyTitle => '結果がありません';

  @override
  String get searchResultsEmptyMessage => 'キーワードやセグメントを変えてみてください。';

  @override
  String get homeTitle => 'ホーム';

  @override
  String get homeSearchTooltip => '検索';

  @override
  String get homeNotificationsTooltip => '通知';

  @override
  String get homeFeaturedTitle => '注目の特集';

  @override
  String get homeFeaturedSubtitle => 'キャンペーンやおすすめの流れをピックアップ';

  @override
  String get homeFeaturedEmpty => '今は表示できる特集がありません。後でもう一度お試しください。';

  @override
  String get homeRecentTitle => '最近のデザイン';

  @override
  String get homeRecentSubtitle => '下書きや発注済みをすぐ再開';

  @override
  String get homeRecentActionLabel => '一覧';

  @override
  String get homeRecentEmpty => 'まだデザインがありません。新しく作成してみましょう。';

  @override
  String get homeRecommendedTitle => 'おすすめテンプレート';

  @override
  String get homeRecommendedSubtitle => '利用履歴と地域に合わせて提案';

  @override
  String get homeRecommendedLoading => 'おすすめテンプレートを準備しています…';

  @override
  String get homeStatusDraft => '下書き';

  @override
  String get homeStatusReady => '準備完了';

  @override
  String get homeStatusOrdered => '注文済み';

  @override
  String get homeStatusLocked => 'ロック';

  @override
  String get homeShapeRound => '丸';

  @override
  String get homeShapeSquare => '角';

  @override
  String get homeWritingTensho => '篆書';

  @override
  String get homeWritingReisho => '隷書';

  @override
  String get homeWritingKaisho => '楷書';

  @override
  String get homeWritingGyosho => '行書';

  @override
  String get homeWritingKoentai => '古印体';

  @override
  String get homeWritingCustom => 'カスタム';

  @override
  String get homeNameUnset => '名称未設定';

  @override
  String get homeDesignSummary => '{shape} {size}mm ・ {style}';

  @override
  String get homeDesignAiCheckDone => '実印チェック済み';

  @override
  String get homeDesignAiCheckLabel => 'AI診断: {diagnostic}';

  @override
  String get homeDesignAiCheckNotRun => '未実行';

  @override
  String get homeTemplateLabel => '{shape}・{style}';

  @override
  String get homeTemplateRecommendedSize => '{size}mm 推奨';

  @override
  String get homeTemplateApply => '適用';

  @override
  String get homeLoadFailed => '読み込みに失敗しました';

  @override
  String get topBarSearchLabel => '検索';

  @override
  String get topBarSearchHint => '⌘K / Ctrl+K のショートカットに対応';

  @override
  String get topBarSearchTooltip => '検索 (⌘K / Ctrl+K)';

  @override
  String get topBarHelpLabel => 'ヘルプ';

  @override
  String get topBarHelpHint => 'Shift + / でも開けます';

  @override
  String get topBarHelpTooltip => 'ヘルプ・FAQ (Shift + /)';

  @override
  String get topBarNotificationsLabel => '通知';

  @override
  String get topBarNotificationsLabelWithUnread => '通知 ({count} 件の未読)';

  @override
  String get topBarNotificationsTooltip => '通知 (Alt + N)';

  @override
  String get topBarNotificationsTooltipWithUnread =>
      '通知 ({count} 件の未読) (Alt + N)';

  @override
  String get topBarHelpOverlayTitle => 'ヘルプとショートカット';

  @override
  String get topBarHelpOverlayPrimaryAction => 'FAQを見る';

  @override
  String get topBarHelpOverlaySecondaryAction => '問い合わせる';

  @override
  String get topBarHelpOverlayBody =>
      'ショートカットとサポートへの入り口です。困ったときはFAQやチャットにすぐ移動できます。';

  @override
  String get topBarShortcutSearchLabel => '検索';

  @override
  String get topBarShortcutHelpLabel => 'ヘルプ';

  @override
  String get topBarShortcutNotificationsLabel => '通知';

  @override
  String get topBarHelpLinkFaqTitle => 'FAQで調べる';

  @override
  String get topBarHelpLinkFaqSubtitle => 'よくある質問とトラブルシューティング';

  @override
  String get topBarHelpLinkChatTitle => 'チャットで相談';

  @override
  String get topBarHelpLinkChatSubtitle => 'すぐ聞きたいときはこちら';

  @override
  String get topBarHelpLinkContactTitle => '問い合わせフォーム';

  @override
  String get topBarHelpLinkContactSubtitle => '詳細なサポートが必要な場合';

  @override
  String get splashLoading => '起動しています…';

  @override
  String get splashFailedTitle => '起動に失敗しました';

  @override
  String get splashFailedMessage => 'ネットワーク状況を確認して、もう一度お試しください。';

  @override
  String get designVersionsTitle => 'バージョン履歴';

  @override
  String get designVersionsShowDiffTooltip => '差分を表示';

  @override
  String get designVersionsSecondaryDuplicate => 'コピーを作成';

  @override
  String get designVersionsTimelineTitle => 'タイムライン';

  @override
  String get designVersionsRefreshTooltip => '履歴をリフレッシュ';

  @override
  String get designVersionsAuditLogTitle => '監査ログ';

  @override
  String get designVersionsNoAuditTitle => '履歴はありません';

  @override
  String get designVersionsNoAuditMessage => 'このデザインのアクションログがまだありません。';

  @override
  String get designVersionsRollbackTitle => 'v{version} にロールバックしますか？';

  @override
  String get designVersionsRollbackBody =>
      'この操作で現在の編集中バージョンを置き換えます。差分は履歴に残ります。';

  @override
  String get designVersionsRollbackAction => '復元';

  @override
  String get designVersionsRollbackCancel => 'キャンセル';

  @override
  String get designVersionsCurrentLabel => '現在: v{version}';

  @override
  String get designVersionsNoDiffSummary => '差分はありません';

  @override
  String get designVersionsCompareTargetLabel => '比較対象 v{version}';

  @override
  String get designVersionsLatestLabel => '最新版';

  @override
  String get designVersionsRollbackButton => 'ロールバック';

  @override
  String get designVersionsPreviewCurrent => '現在';

  @override
  String get designVersionsPreviewTarget => '比較対象';

  @override
  String get designVersionsInitialFallback => '印';

  @override
  String get designVersionsUnset => '未設定';

  @override
  String get designVersionsAutoLayout => '自動';

  @override
  String get designVersionsNoDiffTitle => '差分はありません';

  @override
  String get designVersionsNoDiffMessage => '最新のバージョンと比較対象に違いはありません。';

  @override
  String get designVersionsChangeHistoryEmpty => '変更履歴なし';

  @override
  String get designVersionsTemplateLabel => 'テンプレート: {template}';

  @override
  String get designVersionsStatusCurrent => '現在';

  @override
  String get designVersionsStatusComparing => '比較中';

  @override
  String get designVersionsStatusHistory => '履歴';

  @override
  String get designVersionsLoadFailedTitle => '履歴の読み込みに失敗しました';

  @override
  String get designVersionsSimilarityLabel => '類似度';

  @override
  String get designVersionsRelativeNow => 'たった今';

  @override
  String get designVersionsRelativeMinutes => '{count}分前';

  @override
  String get designVersionsRelativeHours => '{count}時間前';

  @override
  String get designVersionsRelativeDays => '{count}日前';

  @override
  String get checkoutPaymentTitle => '支払い方法';

  @override
  String get checkoutPaymentAddTooltip => '支払い方法を追加';

  @override
  String get checkoutPaymentLoadFailedTitle => '支払い方法を読み込めません';

  @override
  String get checkoutPaymentEmptyTitle => '支払い方法を追加してください';

  @override
  String get checkoutPaymentEmptyBody => 'カードやウォレットを登録すると、次のステップに進めます。';

  @override
  String get checkoutPaymentSignInHint => '支払い方法の追加にはログインが必要です。';

  @override
  String get checkoutPaymentAddMethod => '支払い方法を追加';

  @override
  String get checkoutPaymentChooseSaved => '保存済みの支払い方法を選択してください。';

  @override
  String get checkoutPaymentAddAnother => '支払い方法を追加';

  @override
  String get checkoutPaymentContinueReview => '注文確認へ進む';

  @override
  String get checkoutPaymentAddFailed => '支払い方法を追加できません';

  @override
  String get checkoutPaymentMethodCard => 'カード';

  @override
  String get checkoutPaymentMethodWallet => 'ウォレット';

  @override
  String get checkoutPaymentMethodBank => '銀行振込';

  @override
  String get checkoutPaymentMethodFallback => '支払い方法';

  @override
  String get checkoutPaymentExpires => '有効期限 {month}/{year}';

  @override
  String get cartPromoEnterCode => 'クーポンコードを入力してください';

  @override
  String get cartPromoAddItemsRequired => '商品を追加すると割引を適用できます。';

  @override
  String get cartPromoField10Label => '10%オフ';

  @override
  String get cartPromoField10Description => '商品小計に適用されます。';

  @override
  String get cartPromoShipfreeShortfall => 'あと¥{amount}で送料無料になります。';

  @override
  String get cartPromoShipfreeLabel => '送料無料';

  @override
  String get cartPromoInkLabel => '朱肉セット優待';

  @override
  String get cartPromoInkDescription => 'インクやアクセサリーの同梱で¥200オフ。';

  @override
  String get cartPromoInvalid => 'コードが無効か期限切れです。';

  @override
  String get cartLineTitaniumTitle => 'チタン丸印';

  @override
  String get cartLineTitaniumVariant => '15mm・深彫り調整';

  @override
  String get cartLineTitaniumDesign => 'デザイン：篤山（Akiyama）';

  @override
  String get cartLineTitaniumAddonSleeveLabel => 'マイクロファイバーケース';

  @override
  String get cartLineTitaniumAddonSleeveDescription => '薄型の起毛ケース。';

  @override
  String get cartLineTitaniumAddonSleeveBadge => '人気';

  @override
  String get cartLineTitaniumAddonDeepLabel => '深彫り仕上げ';

  @override
  String get cartLineTitaniumAddonDeepDescription => 'くっきり押せる深彫り仕上げ。';

  @override
  String get cartLineTitaniumAddonWrapLabel => 'ギフトラッピング';

  @override
  String get cartLineTitaniumAddonWrapDescription => '和紙帯とメッセージカード付き。';

  @override
  String get cartLineTitaniumNoteIntl => '通関に配慮した素材';

  @override
  String get cartLineTitaniumNoteDomestic => 'お急ぎ対応・名入れ済み';

  @override
  String get cartLineTitaniumRibbon => '人気';

  @override
  String get cartLineAcrylicTitle => 'カラーアクリル印';

  @override
  String get cartLineAcrylicVariant => '12mm・ミント / 筆記体';

  @override
  String get cartLineAcrylicDesign => 'デザイン：後でアップロード';

  @override
  String get cartLineAcrylicAddonUvLabel => 'UVコート';

  @override
  String get cartLineAcrylicAddonUvDescription => '色あせ・キズ防止コーティング。';

  @override
  String get cartLineAcrylicAddonUvBadge => '期間限定';

  @override
  String get cartLineAcrylicAddonInkLabel => '朱肉セット';

  @override
  String get cartLineAcrylicAddonInkDescription => '交換式のコンパクト朱肉。';

  @override
  String get cartLineAcrylicAddonPouchLabel => 'ソフトポーチ';

  @override
  String get cartLineAcrylicAddonPouchDescription => 'アクリル面を保護するポーチ。';

  @override
  String get cartLineAcrylicNote => 'オプション同梱で発送。';

  @override
  String get cartLineAcrylicRibbonIntl => '海外向け';

  @override
  String get cartLineAcrylicRibbon => 'おすすめ';

  @override
  String get cartLineBoxTitle => '桐箱・刻印入り';

  @override
  String get cartLineBoxVariant => '蓋刻印・ナチュラル';

  @override
  String get cartLineBoxDesign => '名入れ：はんこフィールド';

  @override
  String get cartLineBoxAddonFoamLabel => 'クッション内装';

  @override
  String get cartLineBoxAddonFoamDescription => '印鑑と付属品を固定するクッション。';

  @override
  String get cartLineBoxAddonCardLabel => 'お手入れカード';

  @override
  String get cartLineBoxAddonCardDescription => '日英併記のお手入れガイド。';

  @override
  String get cartLineBoxAddonWrapLabel => 'ラッピングセット';

  @override
  String get cartLineBoxAddonWrapDescription => 'リボン・シール・替え紙付き。';

  @override
  String get cartLineBoxNoteIntl => '日英の案内カード付き。';

  @override
  String get cartLineBoxNoteDomestic => 'メッセージ刻印済み。';

  @override
  String get cartLineBoxRibbon => 'ギフト';

  @override
  String get cartEstimateMethodIntl => '海外配送';

  @override
  String get cartEstimateMethodDomestic => '国内配送';

  @override
  String get cartEstimateMethodIntlPriority => '海外優先便';

  @override
  String get cartEstimateMethodStandard => '標準';

  @override
  String get cartTitle => 'カート';

  @override
  String get cartBulkEditTooltip => 'まとめて編集';

  @override
  String get cartLoadFailedTitle => 'カートを読み込めません';

  @override
  String get cartEmptyTitle => 'カートは空です';

  @override
  String get cartEmptyMessage => 'ショップから商品を追加すると、見積もりが表示されます。';

  @override
  String get cartEmptyAction => 'ショップへ戻る';

  @override
  String get cartRemovedItem => '{item} を削除しました';

  @override
  String get cartUndo => '元に戻す';

  @override
  String get cartPromoApplied => '{label} を適用しました';

  @override
  String get cartEditOptionsTitle => 'オプションを編集';

  @override
  String get cartAddonIncluded => '無料';

  @override
  String get cartReset => '元に戻す';

  @override
  String get cartSave => '保存';

  @override
  String get cartBulkActionsTitle => 'まとめて操作';

  @override
  String get cartBulkActionsBody => '全ての行にクーポン適用、数量調整、選択解除をまとめて行えます（モック）。';

  @override
  String get cartBulkActionApplyField10 => 'FIELD10 を適用';

  @override
  String get cartBulkActionShipfree => '送料無料コード';

  @override
  String get cartBulkActionClearSelections => '選択をクリア';

  @override
  String get cartUnitPerItem => '1点あたり';

  @override
  String get cartEditOptionsAction => 'オプション編集';

  @override
  String get cartRemoveAction => '削除';

  @override
  String get cartLeadTimeLabel => 'お届け目安 {min}〜{max}日';

  @override
  String get cartLineTotalLabel => '小計';

  @override
  String get cartPromoTitle => 'クーポンコード';

  @override
  String get cartPromoFieldLabel => 'コードを入力';

  @override
  String get cartPromoApplyLabel => '適用';

  @override
  String get cartPromoAppliedFallback => 'クーポンを適用しました。';

  @override
  String get cartPromoMockHint => 'クーポン入力はモックです。';

  @override
  String get cartSummaryTitle => '概算サマリー';

  @override
  String get cartSummaryItems => '{count}点';

  @override
  String get cartSummarySubtotal => '商品小計';

  @override
  String get cartSummaryDiscount => '割引';

  @override
  String get cartSummaryShipping => '送料';

  @override
  String get cartSummaryFree => '無料';

  @override
  String get cartSummaryTax => '推定税';

  @override
  String get cartSummaryTotal => '合計（概算）';

  @override
  String get cartSummaryEstimate => '目安 {min}〜{max}日・{method}';

  @override
  String get cartProceedCheckout => '購入手続きへ';

  @override
  String get checkoutAddressTitle => '配送先';

  @override
  String get checkoutAddressAddTooltip => '住所を追加';

  @override
  String get checkoutAddressLoadFailedTitle => '住所を読み込めません';

  @override
  String get checkoutAddressEmptyTitle => '住所を追加してください';

  @override
  String get checkoutAddressEmptyMessage => '配送先を登録すると、次のステップに進めます。';

  @override
  String get checkoutAddressAddAction => '住所を追加';

  @override
  String get checkoutAddressChooseHint => '配送先を選択し、必要に応じて編集してください。';

  @override
  String get checkoutAddressAddAnother => '住所を追加';

  @override
  String get checkoutAddressContinueShipping => '配送方法へ進む';

  @override
  String get checkoutAddressSelectRequired => '配送先を選択してください';

  @override
  String get checkoutAddressSavedCreated => '住所を追加しました';

  @override
  String get checkoutAddressSavedUpdated => '住所を更新しました';

  @override
  String get checkoutAddressChipShipping => '配送先';

  @override
  String get checkoutAddressChipDefault => '既定';

  @override
  String get checkoutAddressChipBilling => '請求先';

  @override
  String get checkoutAddressChipInternational => '海外配送';

  @override
  String get checkoutAddressLabelFallback => '配送先';

  @override
  String get checkoutAddressEditAction => '編集';

  @override
  String get checkoutAddressPersonaDomesticHint =>
      '郵便番号から住所を補完できます。建物名・部屋番号まで入力してください。';

  @override
  String get checkoutAddressPersonaInternationalHint =>
      '海外配送の場合はローマ字表記と国番号付き電話を入力してください。';

  @override
  String get checkoutAddressFormAddTitle => '住所を追加';

  @override
  String get checkoutAddressFormEditTitle => '住所を編集';

  @override
  String get checkoutAddressFormDomesticLabel => '国内';

  @override
  String get checkoutAddressFormInternationalLabel => '海外';

  @override
  String get checkoutAddressFormLabelOptional => 'ラベル（任意）';

  @override
  String get checkoutAddressFormRecipient => '受取人';

  @override
  String get checkoutAddressFormCompanyOptional => '会社名（任意）';

  @override
  String get checkoutAddressFormPostalCode => '郵便番号';

  @override
  String get checkoutAddressFormLookup => '住所補完';

  @override
  String get checkoutAddressFormState => '都道府県・州';

  @override
  String get checkoutAddressFormCity => '市区町村';

  @override
  String get checkoutAddressFormLine1 => '番地・町名';

  @override
  String get checkoutAddressFormLine2Optional => '建物名・部屋番号（任意）';

  @override
  String get checkoutAddressFormCountry => '国・地域';

  @override
  String get checkoutAddressFormPhone => '電話番号（国番号付き推奨）';

  @override
  String get checkoutAddressFormDefaultTitle => '既定の住所にする';

  @override
  String get checkoutAddressFormDefaultSubtitle => '既定の住所はチェックアウトで自動選択されます。';

  @override
  String get checkoutAddressFormSave => '保存する';

  @override
  String get checkoutAddressFormFixErrors => 'エラーを修正してください。';

  @override
  String get checkoutAddressRequired => '必須項目です';

  @override
  String get checkoutAddressRecipientRequired => '受取人を入力してください';

  @override
  String get checkoutAddressLine1Required => '住所（番地）を入力してください';

  @override
  String get checkoutAddressCityRequired => '市区町村を入力してください';

  @override
  String get checkoutAddressPostalFormat => '郵便番号は123-4567の形式で入力してください';

  @override
  String get checkoutAddressStateRequired => '都道府県を入力してください';

  @override
  String get checkoutAddressCountryJapanRequired => '国内配送は国をJPにしてください';

  @override
  String get checkoutAddressPhoneDomestic => '市外局番を含めて10桁以上で入力してください';

  @override
  String get checkoutAddressPostalShort => '郵便番号を正しく入力してください';

  @override
  String get checkoutAddressCountryRequired => '国・地域を入力してください';

  @override
  String get checkoutAddressPhoneInternational => '国番号付きで入力してください（例: +81）';

  @override
  String get checkoutShippingMissingState => '状態を読み込めませんでした';

  @override
  String get checkoutShippingSelectAddress => '先に配送先を選択してください。';

  @override
  String get checkoutShippingOptionUnavailable => 'この住所では利用できません。';

  @override
  String get checkoutShippingPromoRequiresExpress => 'クーポン適用には速達が必要です。';

  @override
  String get checkoutShippingBadgePopular => '人気';

  @override
  String get checkoutShippingBadgeFastest => '最短';

  @override
  String get checkoutShippingBadgeTracked => '追跡';

  @override
  String get checkoutShippingOptionDomStandardLabel => 'ヤマト通常便';

  @override
  String get checkoutShippingOptionDomStandardCarrier => 'ヤマト運輸';

  @override
  String get checkoutShippingOptionDomStandardNote => '土日配達・追跡付き';

  @override
  String get checkoutShippingOptionDomExpressLabel => '翌日お届け（速達）';

  @override
  String get checkoutShippingOptionDomExpressCarrier => 'ヤマト / 日本郵便';

  @override
  String get checkoutShippingOptionDomExpressNote => 'クーポン適用条件の速達はこちら。';

  @override
  String get checkoutShippingOptionDomPickupLabel => 'コンビニ受け取り';

  @override
  String get checkoutShippingOptionDomPickupCarrier => 'ローソン/ファミマ';

  @override
  String get checkoutShippingOptionDomPickupNote => '店舗で7日間保管。';

  @override
  String get checkoutShippingOptionIntlExpressLabel => '国際エクスプレス';

  @override
  String get checkoutShippingOptionIntlExpressCarrier => 'DHL・ヤマト国際';

  @override
  String get checkoutShippingOptionIntlExpressNote => '通関前処理込み、追跡可。';

  @override
  String get checkoutShippingOptionIntlPriorityLabel => '優先航空便';

  @override
  String get checkoutShippingOptionIntlPriorityCarrier => 'EMS';

  @override
  String get checkoutShippingOptionIntlPriorityNote => '通関書類をサポート。';

  @override
  String get checkoutShippingOptionIntlEconomyLabel => 'エコノミー航空便';

  @override
  String get checkoutShippingOptionIntlEconomyCarrier => '日本郵便航空';

  @override
  String get checkoutShippingOptionIntlEconomyNote => 'コスト重視の方向け。';

  @override
  String get checkoutShippingBannerInternationalDelay =>
      '通関強化により国際便で+1〜2日の遅延が発生しています。';

  @override
  String get checkoutShippingBannerKyushuDelay => '季節要因で九州方面は半日程度遅れる場合があります。';

  @override
  String get shopTitle => 'ショップ';

  @override
  String get shopSearchTooltip => '検索';

  @override
  String get shopCartTooltip => 'カート';

  @override
  String get shopAppBarSubtitle => '素材やセット、オプションをまとめて選ぶ';

  @override
  String get shopActionPromotions => 'キャンペーンを見る';

  @override
  String get shopActionGuides => 'ガイド';

  @override
  String get shopQuickGuidesTitle => 'クイックガイド';

  @override
  String get shopQuickGuidesSubtitle => 'サイズ・お手入れ・文化のポイント';

  @override
  String get shopBrowseByMaterialTitle => '素材から探す';

  @override
  String get shopBrowseByMaterialSubtitle => '用途に合う質感を選びましょう';

  @override
  String get shopPromotionsTitle => 'キャンペーン';

  @override
  String get shopPromotionsSubtitle => 'まとめ買い割引や特急枠';

  @override
  String get shopPromotionsEmpty => '現在ご利用いただけるキャンペーンはありません。';

  @override
  String get shopRecommendedMaterialsTitle => 'おすすめ素材';

  @override
  String get shopRecommendedMaterialsSubtitle => 'ペルソナと配送希望に合わせて提案';

  @override
  String get shopRecommendedMaterialsEmpty => 'おすすめ素材を準備中です。またのぞいてみてください。';

  @override
  String get shopHeroBadge => '季節のおすすめ';

  @override
  String get shopHeroTitle => '彫り深さ調整付き 春のスターターセット';

  @override
  String get shopHeroBody => 'ケース・朱肉・DHL対応テンプレが1タップで揃います。';

  @override
  String get shopHeroAction => 'セットを見る';

  @override
  String get libraryDesignDetailTitle => '印鑑詳細';

  @override
  String get libraryDesignDetailSubtitle => 'マイ印鑑';

  @override
  String get libraryDesignDetailEditTooltip => '編集';

  @override
  String get libraryDesignDetailExportTooltip => '出力';

  @override
  String get libraryDesignDetailTabDetails => '詳細';

  @override
  String get libraryDesignDetailTabActivity => '履歴';

  @override
  String get libraryDesignDetailTabFiles => 'ファイル';

  @override
  String get libraryDesignDetailMetadataTitle => 'メタデータ';

  @override
  String get libraryDesignDetailUsageHistoryTitle => '使用履歴';

  @override
  String get libraryDesignDetailNoActivity => 'まだ履歴がありません。';

  @override
  String get libraryDesignDetailFilesTitle => 'ファイル';

  @override
  String get libraryDesignDetailPreviewPngLabel => 'プレビューPNG';

  @override
  String get libraryDesignDetailVectorSvgLabel => 'ベクターSVG';

  @override
  String get libraryDesignDetailExportAction => '出力';

  @override
  String get libraryDesignDetailUntitled => '名称未設定';

  @override
  String get libraryDesignDetailAiScoreUnknown => 'AIスコア: -';

  @override
  String get libraryDesignDetailAiScoreLabel => 'AIスコア: {score}';

  @override
  String get libraryDesignDetailRegistrabilityUnknown => '登録可否: -';

  @override
  String get libraryDesignDetailRegistrable => '登録可';

  @override
  String get libraryDesignDetailNotRegistrable => '登録不可';

  @override
  String get libraryDesignDetailActionVersions => 'バージョン';

  @override
  String get libraryDesignDetailActionShare => '共有';

  @override
  String get libraryDesignDetailActionLinks => 'リンク';

  @override
  String get libraryDesignDetailActionDuplicate => '複製';

  @override
  String get libraryDesignDetailActionReorder => '再注文';

  @override
  String get libraryDesignDetailActionArchive => 'アーカイブ';

  @override
  String get libraryDesignDetailArchiveTitle => 'アーカイブしますか？';

  @override
  String get libraryDesignDetailArchiveBody => 'この印鑑をライブラリから削除します（ローカルモック）。';

  @override
  String get libraryDesignDetailArchiveCancel => 'キャンセル';

  @override
  String get libraryDesignDetailArchiveConfirm => 'アーカイブ';

  @override
  String get libraryDesignDetailArchived => 'アーカイブしました';

  @override
  String get libraryDesignDetailReorderHint => '商品を選んで、この印鑑を選択してください（モック）';

  @override
  String get libraryDesignDetailHydrateFailed => '編集の準備に失敗しました: {error}';

  @override
  String get libraryDesignDetailFileNotAvailable => '未生成';

  @override
  String get libraryDesignDetailMetadataDesignId => 'デザインID';

  @override
  String get libraryDesignDetailMetadataStatus => 'ステータス';

  @override
  String get libraryDesignDetailMetadataAiScore => 'AIスコア';

  @override
  String get libraryDesignDetailMetadataRegistrability => '登録可否';

  @override
  String get libraryDesignDetailMetadataCreated => '作成日';

  @override
  String get libraryDesignDetailMetadataUpdated => '更新日';

  @override
  String get libraryDesignDetailMetadataLastUsed => '最終使用';

  @override
  String get libraryDesignDetailMetadataVersion => 'バージョン';

  @override
  String get libraryDesignDetailActivityCreatedTitle => '作成';

  @override
  String get libraryDesignDetailActivityUpdatedTitle => '更新';

  @override
  String get libraryDesignDetailActivityOrderedTitle => '注文で使用';

  @override
  String get libraryDesignDetailActivityCreatedDetail => '保存しました';

  @override
  String get libraryDesignDetailActivityUpdatedDetail => '編集内容を反映しました';

  @override
  String get libraryDesignDetailActivityOrderedDetail => '再注文できます';

  @override
  String get orderDetailTitleFallback => '注文';

  @override
  String get orderDetailTooltipReorder => '再注文';

  @override
  String get orderDetailTooltipShare => '共有';

  @override
  String get orderDetailTooltipMore => 'その他';

  @override
  String get orderDetailMenuContactSupport => '問い合わせ';

  @override
  String get orderDetailMenuCancelOrder => '注文をキャンセル';

  @override
  String get orderDetailTabSummary => '概要';

  @override
  String get orderDetailTabTimeline => '履歴';

  @override
  String get orderDetailTabFiles => 'ファイル';

  @override
  String get orderDetailShareText => '注文番号：{number}';

  @override
  String get orderDetailInvoiceRequestSent => '領収書のリクエストを送信しました（モック）';

  @override
  String get orderDetailInvoiceRequestFailed => '領収書のリクエストに失敗しました';

  @override
  String get orderDetailCancelTitle => 'この注文をキャンセルしますか？';

  @override
  String get orderDetailCancelBody => '制作が開始している場合、キャンセルできないことがあります。';

  @override
  String get orderDetailCancelConfirm => 'キャンセルする';

  @override
  String get orderDetailCancelKeep => '戻る';

  @override
  String get orderDetailCancelSuccess => '注文をキャンセルしました';

  @override
  String get orderDetailCancelFailed => 'キャンセルに失敗しました';

  @override
  String get orderDetailDesignPreviewOk => 'OK';

  @override
  String get orderDetailBannerInProgress => '注文は進行中です。制作状況や配送状況を確認できます。';

  @override
  String get orderDetailBannerProduction => '制作';

  @override
  String get orderDetailBannerTracking => '配送';

  @override
  String get orderDetailSectionOrder => '注文';

  @override
  String get orderDetailSectionItems => '明細';

  @override
  String get orderDetailSectionTotal => '合計';

  @override
  String get orderDetailSubtotal => '小計';

  @override
  String get orderDetailDiscount => '割引';

  @override
  String get orderDetailShipping => '送料';

  @override
  String get orderDetailShippingFree => '無料';

  @override
  String get orderDetailTax => '税';

  @override
  String get orderDetailTotal => '合計';

  @override
  String get orderDetailShippingAddress => '配送先';

  @override
  String get orderDetailBillingAddress => '請求先';

  @override
  String get orderDetailPayment => '支払い';

  @override
  String get orderDetailDesignSnapshots => 'デザインスナップショット';

  @override
  String get orderDetailQuickActions => '操作';

  @override
  String get orderDetailRequestInvoice => '領収書を依頼';

  @override
  String get orderDetailContactSupport => '問い合わせ';

  @override
  String get orderDetailTimelineTitle => '履歴';

  @override
  String get orderDetailProductionEvents => '制作イベント';

  @override
  String get orderDetailInvoiceTitle => '領収書';

  @override
  String get orderDetailInvoiceHint => '領収書の依頼・表示ができます。';

  @override
  String get orderDetailInvoiceRequest => '依頼する';

  @override
  String get orderDetailInvoiceView => '表示する';

  @override
  String get orderDetailItemQtyLabel => '数量 {quantity}';

  @override
  String get orderDetailPaymentPending => '未払い';

  @override
  String get orderDetailPaymentPaid => '支払い済み';

  @override
  String get orderDetailPaymentCanceled => 'キャンセル';

  @override
  String get orderDetailPaymentProcessing => '処理中';

  @override
  String get orderDetailPaymentNoInfo => '支払い情報はありません';

  @override
  String get orderDetailPaymentPaidAt => '{date} に支払い';

  @override
  String get orderDetailPaymentMethodCard => 'カード';

  @override
  String get orderDetailPaymentMethodWallet => 'ウォレット';

  @override
  String get orderDetailPaymentMethodBank => '銀行';

  @override
  String get orderDetailPaymentMethodOther => 'その他';

  @override
  String get orderDetailPaymentSeparator => '・';

  @override
  String get orderDetailMeta => 'ID {id}・{date}';

  @override
  String get orderDetailStatusPending => '未払い';

  @override
  String get orderDetailStatusPaid => '支払い済み';

  @override
  String get orderDetailStatusInProduction => '制作中';

  @override
  String get orderDetailStatusReadyToShip => '発送準備中';

  @override
  String get orderDetailStatusShipped => '発送済み';

  @override
  String get orderDetailStatusDelivered => '配達済み';

  @override
  String get orderDetailStatusCanceled => 'キャンセル';

  @override
  String get orderDetailStatusProcessing => '処理中';

  @override
  String get orderDetailMilestonePlaced => '注文';

  @override
  String get orderDetailMilestonePaid => '支払い';

  @override
  String get orderDetailMilestoneProduction => '制作';

  @override
  String get orderDetailMilestoneShipped => '発送';

  @override
  String get orderDetailMilestoneDelivered => '配達';

  @override
  String get orderDetailMilestoneCanceled => 'キャンセル';

  @override
  String get kanjiDictionaryTitle => '漢字辞典';

  @override
  String get kanjiDictionaryToggleShowAll => 'すべて表示';

  @override
  String get kanjiDictionaryToggleShowFavorites => 'お気に入り';

  @override
  String get kanjiDictionaryOpenGuides => 'ガイドへ';

  @override
  String get kanjiDictionarySearchHint => '漢字を検索';

  @override
  String get kanjiDictionaryHistoryHint => '意味・読み・名前の例で検索できます。';

  @override
  String get kanjiDictionaryHistoryTitle => '履歴';

  @override
  String get kanjiDictionaryFiltersTitle => '絞り込み';

  @override
  String get kanjiDictionaryGradesAll => '学年';

  @override
  String get kanjiDictionaryGrade1 => '1年';

  @override
  String get kanjiDictionaryGrade2 => '2年';

  @override
  String get kanjiDictionaryGrade3 => '3年';

  @override
  String get kanjiDictionaryGrade4 => '4年';

  @override
  String get kanjiDictionaryGrade5 => '5年';

  @override
  String get kanjiDictionaryGrade6 => '6年+';

  @override
  String get kanjiDictionaryStrokesAll => '画数';

  @override
  String get kanjiDictionaryRadicalAny => '部首';

  @override
  String get kanjiDictionaryRadicalWater => '水';

  @override
  String get kanjiDictionaryRadicalSun => '日';

  @override
  String get kanjiDictionaryRadicalPlant => '草';

  @override
  String get kanjiDictionaryRadicalHeart => '心';

  @override
  String get kanjiDictionaryRadicalEarth => '土';

  @override
  String get kanjiDictionaryStrokeCount => '{count}画';

  @override
  String get kanjiDictionaryRadicalLabel => '部首: {radical}';

  @override
  String get kanjiDictionaryFavorite => 'お気に入り';

  @override
  String get kanjiDictionaryUnfavorite => '解除';

  @override
  String get kanjiDictionaryDetails => '詳細';

  @override
  String get kanjiDictionaryChipStrokes => '画数: {count}';

  @override
  String get kanjiDictionaryChipRadical => '部首: {radical}';

  @override
  String get kanjiDictionaryStrokeOrderTitle => '筆順';

  @override
  String get kanjiDictionaryExamplesTitle => '用例';

  @override
  String get kanjiDictionaryInsertIntoNameInput => '名前入力に追加';

  @override
  String get kanjiDictionaryDone => '閉じる';

  @override
  String get kanjiDictionaryExampleUsage => '氏名や印影で使われます';

  @override
  String get kanjiDictionaryNoStrokeData => '画数情報がありません。';

  @override
  String get kanjiDictionaryStrokeOrderPrefix => '順: {steps}';

  @override
  String get orderInvoiceTitle => '領収書';

  @override
  String get orderInvoiceShareTooltip => '共有';

  @override
  String get orderInvoiceLoadFailed => '領収書を読み込めませんでした';

  @override
  String get orderInvoiceDownloadPdf => 'PDFを保存';

  @override
  String get orderInvoiceSendEmail => 'メールで送る';

  @override
  String get orderInvoiceContactSupport => '問い合わせ';

  @override
  String get orderInvoiceTotalLabel => '合計';

  @override
  String get orderInvoiceStatusAvailable => '利用可能';

  @override
  String get orderInvoiceStatusPending => '準備中';

  @override
  String get orderInvoiceTaxable => '課税';

  @override
  String get orderInvoiceTaxExempt => '非課税';

  @override
  String get orderInvoicePreviewTitle => 'プレビュー';

  @override
  String get orderInvoiceRefreshTooltip => '更新';

  @override
  String get orderInvoicePendingBody => '領収書を準備しています。';

  @override
  String get orderInvoiceUnavailableBody => '領収書を表示できません。';

  @override
  String get orderInvoiceRequestAction => '領収書をリクエスト';

  @override
  String get orderInvoiceSavedTo => '保存しました: {path}';

  @override
  String get orderInvoiceSaveFailed => 'PDFを保存できませんでした';

  @override
  String get orderInvoiceShareText => '{app} • {number}';

  @override
  String get orderInvoiceOrderLabel => '注文番号：{number}';

  @override
  String get orderInvoiceIssuedLabel => '発行日：{date}';

  @override
  String get orderProductionTitle => '制作進捗';

  @override
  String get orderProductionRefreshTooltip => '更新';

  @override
  String get orderProductionStatusLabel => 'ステータス：{status}';

  @override
  String get orderProductionEtaLabel => '完了予定：{date}';

  @override
  String get orderProductionDelayedMessage => 'この注文は完了予定日を過ぎています。';

  @override
  String get orderProductionTimelineTitle => 'タイムライン';

  @override
  String get orderProductionNoEventsTitle => 'まだ履歴がありません';

  @override
  String get orderProductionNoEventsMessage => '制作状況が更新されると、ここに表示されます。';

  @override
  String get orderProductionNoEventsAction => '更新する';

  @override
  String get orderProductionHealthOnTrack => '順調';

  @override
  String get orderProductionHealthAttention => '注意';

  @override
  String get orderProductionHealthDelayed => '遅延';

  @override
  String get orderProductionEventStation => '工程：{station}';

  @override
  String get orderProductionEventQc => '検品：{details}';

  @override
  String get orderProductionEventQueued => '受付';

  @override
  String get orderProductionEventEngraving => '彫刻';

  @override
  String get orderProductionEventPolishing => '研磨';

  @override
  String get orderProductionEventQualityCheck => '検品';

  @override
  String get orderProductionEventPacked => '梱包';

  @override
  String get orderProductionEventOnHold => '保留';

  @override
  String get orderProductionEventRework => '再加工';

  @override
  String get orderProductionEventCanceled => 'キャンセル';

  @override
  String get commonCancel => 'キャンセル';

  @override
  String get commonPlaceholder => '—';

  @override
  String get commonVersionLabel => 'v{version}';

  @override
  String get commonSizeMillimeters => '{size}mm';

  @override
  String get commonPercentLabel => '{percent}%';

  @override
  String get commonPercentDiscountLabel => '-{percent}%';

  @override
  String get cartSummaryItem => '{count}点';

  @override
  String get profileExportTimeMinute => '{count}分前';

  @override
  String get profileExportTimeHour => '{count}時間前';

  @override
  String get profileExportTimeDay => '{count}日前';

  @override
  String get profileExportTimeCompactMinute => '{count}分';

  @override
  String get profileExportTimeCompactHour => '{count}時間';

  @override
  String get profileExportTimeCompactDay => '{count}日';

  @override
  String get designVersionsRelativeMinute => '{count}分前';

  @override
  String get designVersionsRelativeHour => '{count}時間前';

  @override
  String get designVersionsRelativeDay => '{count}日前';

  @override
  String get kanjiDictionaryStrokeCountOne => '{count}画';

  @override
  String get kanjiDictionaryChipStrokesOne => '画数: {count}';

  @override
  String get notificationsEmptyUnreadMessage => '未読はありません。';

  @override
  String get notificationsEmptyAllMessage => '通知はまだありません。';

  @override
  String get notificationsEmptyTitle => 'お知らせはありません';

  @override
  String get notificationsRefresh => '更新する';

  @override
  String get notificationsLoadMoreHint => '引っ張って続きを読み込む';

  @override
  String get notificationsMarkedRead => '既読にしました';

  @override
  String get notificationsMarkedUnread => '未読に戻しました';

  @override
  String get notificationsUndo => '元に戻す';

  @override
  String get notificationsAllCaughtUp => 'すべて既読にしました';

  @override
  String get notificationsUnreadCount => '未読 {count} 件';

  @override
  String get notificationsMoreTooltip => 'その他の操作';

  @override
  String get notificationsMarkAllRead => 'すべて既読にする';

  @override
  String get notificationsFilterAll => 'すべて';

  @override
  String get notificationsFilterUnread => '未読';

  @override
  String get notificationsMarkRead => '既読にする';

  @override
  String get notificationsMarkUnread => '未読に戻す';

  @override
  String get notificationsToday => '今日';

  @override
  String get notificationsYesterday => '昨日';

  @override
  String get notificationsCategoryOrder => '注文';

  @override
  String get notificationsCategoryDesign => 'デザイン';

  @override
  String get notificationsCategoryPromo => 'お得情報';

  @override
  String get notificationsCategorySupport => 'サポート';

  @override
  String get notificationsCategoryStatus => 'お知らせ';

  @override
  String get notificationsCategorySecurity => 'セキュリティ';

  @override
  String get orderReorderTitle => '再注文';

  @override
  String get orderReorderSelectItem => '再注文する商品を選択してください';

  @override
  String get orderReorderCartRebuilt => 'カートを再作成してチェックアウトへ進みます';

  @override
  String get orderReorderFromOrder => '{order} の内容から再注文';

  @override
  String get orderReorderSelectedCount => '{selected}/{total} 件選択';

  @override
  String get orderReorderRebuildCart => 'カートを再作成';

  @override
  String get orderReorderBannerOutOfStockAndPrice => '在庫切れの商品、価格変更の商品があります。';

  @override
  String get orderReorderBannerOutOfStock => '在庫切れの商品があります。';

  @override
  String get orderReorderBannerPriceChanged => '前回注文時から価格が変更されています。';

  @override
  String get orderReorderBannerUpdates => '更新があります。';

  @override
  String get orderReorderDismiss => '閉じる';

  @override
  String get orderReorderItemFallback => '商品';

  @override
  String get orderReorderDesignLabel => 'デザイン：{label}';

  @override
  String get orderReorderOutOfStock => '在庫切れ';

  @override
  String get orderReorderPriceUpdated => '価格変更';

  @override
  String get orderReorderLoadFailed => '再注文情報の取得に失敗しました。';

  @override
  String get nameValidationSurnameRequired => '姓を入力してください';

  @override
  String get nameValidationSurnameFullWidth => '全角で入力してください (姓)';

  @override
  String get nameValidationGivenRequired => '名を入力してください';

  @override
  String get nameValidationGivenFullWidth => '全角で入力してください (名)';

  @override
  String get nameValidationSurnameKanaRequired => 'セイを入力してください';

  @override
  String get nameValidationKanaFullWidth => '全角カナで入力してください';

  @override
  String get nameValidationGivenKanaRequired => 'メイを入力してください';

  @override
  String get nameValidationKanaFullWidthRecommended => 'フリガナは全角が推奨です';

  @override
  String get supportChatSeedGreeting => 'こんにちは。サポートボットのハナです。ご用件を教えてください。';
}

class AppLocalizationsDelegate extends LocalizationsDelegate<AppLocalizations> {
  const AppLocalizationsDelegate();

  @override
  bool isSupported(Locale locale) =>
      AppLocalizations.supportedLanguageCodes.contains(locale.languageCode);

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(AppLocalizations(locale));
  }

  @override
  bool shouldReload(covariant LocalizationsDelegate<AppLocalizations> old) {
    return false;
  }
}
