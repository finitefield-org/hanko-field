// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:app/localization/app_localizations_en.dart';
import 'package:app/localization/app_localizations_ja.dart';
import 'package:app/localization/app_localizations_strings.dart';
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
