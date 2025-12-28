// ignore_for_file: public_member_api_docs

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

/// Application localization without ARB for type safety.
class AppLocalizations {
  AppLocalizations(this.locale);

  final Locale locale;

  static const supportedLocales = <Locale>[Locale('en'), Locale('ja')];

  static const supportedLanguageCodes = <String>{'en', 'ja'};

  static const _localizedValues = <String, Map<String, String>>{
    'en': {
      'appTitle': 'Hanko Field',
      'welcomeHeadline': 'Craft your seal, your way',
      'welcomeBody':
          'Localization, theming, and tokens are ready to power every screen.',
      'primaryAction': 'Get started',
      'secondaryAction': 'Browse designs',
      'onboardingTitle': 'Welcome tour',
      'onboardingSkip': 'Skip',
      'onboardingNext': 'Next',
      'onboardingBack': 'Back',
      'onboardingFinish': 'Start setup',
      'onboardingRetry': 'Try again',
      'onboardingErrorTitle': 'Could not load onboarding',
      'onboardingStepCount': 'Step {current} of {total}',
      'onboardingSlideCreateTitle': 'Design without guesswork',
      'onboardingSlideCreateBody':
          'Preview scripts, spacing, and layout with guided templates built for hanko.',
      'onboardingSlideCreateTagline': 'Create',
      'onboardingSlideMaterialsTitle': 'Pick the right materials',
      'onboardingSlideMaterialsBody':
          'Compare woods, stones, and metals with availability and recommendations.',
      'onboardingSlideMaterialsTagline': 'Shop',
      'onboardingSlideSupportTitle': 'Guided all the way',
      'onboardingSlideSupportBody':
          'Save progress, resume on web, and reach support if you get stuck.',
      'onboardingSlideSupportTagline': 'Assist',
      'localeTitle': 'Choose language & region',
      'localeSave': 'Save',
      'localeSubtitle': 'Set your preferred language',
      'localeDescription': 'Device locale: {device}',
      'localeContinue': 'Save and continue',
      'localeUseDevice': 'Use device locale',
      'personaTitle': 'Choose your persona',
      'personaSave': 'Save',
      'personaSubtitle': 'Tailor guidance to your needs',
      'personaDescription':
          'Pick the journey that best matches how you will use Hanko Field.',
      'personaContinue': 'Continue',
      'personaUseSelected': 'Save persona',
      'authTitle': 'Sign in or continue',
      'authSubtitle': 'Choose how you\'d like to continue',
      'authBody':
          'Sign in to sync designs and orders, or continue as a guest with limited features.',
      'authEmailLabel': 'Email',
      'authEmailHelper': 'Used for receipts and account recovery.',
      'authEmailRequired': 'Email is required.',
      'authEmailInvalid': 'Enter a valid email address.',
      'authPasswordLabel': 'Password',
      'authPasswordHelper': 'At least 8 characters.',
      'authPasswordTooShort': 'Password is too short.',
      'authEmailCta': 'Continue with email',
      'authAppleButton': 'Continue with Apple',
      'authGoogleButton': 'Continue with Google',
      'authGuestCta': 'Continue as guest',
      'authGuestNote':
          'Guest mode lets you browse with limited saving and checkout.',
      'authHelpTooltip': 'Need help?',
      'authHelpTitle': 'About signing in',
      'authHelpBody':
          'Use your account to keep designs and orders in sync. You can link Apple or Google later from settings.',
      'authErrorCancelled': 'Sign-in was cancelled.',
      'authErrorNetwork': 'Network unavailable. Please check your connection.',
      'authErrorInvalid': 'Credentials are invalid or expired. Try again.',
      'authErrorWrongPassword': 'Email or password is incorrect.',
      'authErrorWeakPassword': 'Password is too weak; try 8+ characters.',
      'authErrorAppleUnavailable':
          'Apple Sign-In is not available on this device.',
      'authErrorLink':
          'This email is already linked with {providers}. Sign in with that option to connect.',
      'authErrorUnknown': 'Could not sign in. Please try again.',
      'authLinkingTitle': 'Link your account',
      'authLinkPrompt':
          'Sign in with {providers} to link and keep your data together.',
      'authProviderUnknown': 'your account',
      'authProviderGoogle': 'Google',
      'authProviderApple': 'Apple',
      'authProviderEmail': 'Email',
      'profileTitle': 'Profile',
      'profileAvatarUpdateTooltip': 'Update profile photo',
      'profileAvatarUpdateTitle': 'Update profile photo',
      'profileAvatarUpdateBody':
          'Photo updates are coming soon. For now, you can still change your persona and manage settings here.',
      'profileAvatarUpdateOk': 'OK',
      'profileLoadFailedTitle': 'Could not load profile',
      'profileLoadFailedMessage':
          'Something went wrong while loading your profile. Please try again.',
      'profileRetry': 'Retry',
      'profileStatusSignedOut': 'Signed out',
      'profileStatusGuest': 'Guest',
      'profileStatusMember': 'Signed in',
      'profileFallbackGuestName': 'Guest',
      'profileFallbackProfileName': 'Profile',
      'profilePersonaTitle': 'Persona',
      'profilePersonaSubtitle': 'Switch guidance and recommendations.',
      'profilePersonaJapanese': 'Japan',
      'profilePersonaForeigner': 'Global',
      'profileQuickLinksTitle': 'Quick links',
      'profileQuickOrdersTitle': 'Orders',
      'profileQuickOrdersSubtitle': 'View order history',
      'profileQuickLibraryTitle': 'My seals',
      'profileQuickLibrarySubtitle': 'Saved designs',
      'profileSettingsTitle': 'Settings',
      'profileAddressesTitle': 'Addresses',
      'profileAddressesSubtitle': 'Manage shipping destinations',
      'profilePaymentsTitle': 'Payments',
      'profilePaymentsSubtitle': 'Manage saved payment methods',
      'paymentMethodErrorLast4': 'Enter last 4 digits',
      'paymentMethodErrorExpMonth': 'Enter expiry month',
      'paymentMethodErrorExpYear': 'Enter expiry year',
      'paymentMethodErrorFixFields': 'Fix the highlighted fields',
      'paymentMethodAddFailed': 'Could not add payment method',
      'paymentMethodSheetTitle': 'Add payment method',
      'paymentMethodSheetCard': 'Card',
      'paymentMethodSheetWallet': 'Wallet',
      'paymentMethodSheetBrandLabel': 'Brand (e.g. Visa)',
      'paymentMethodSheetLast4Label': 'Last 4 digits',
      'paymentMethodSheetExpMonthLabel': 'Exp. month',
      'paymentMethodSheetExpYearLabel': 'Exp. year',
      'paymentMethodSheetBillingNameLabel': 'Billing name (optional)',
      'paymentMethodSheetSave': 'Save',
      'profileNotificationsTitle': 'Notifications',
      'profileNotificationsSubtitle': 'Update notification preferences',
      'profileNotificationsHeader':
          'Choose how you want to hear from Hanko Field.',
      'profileNotificationsPushHeader': 'Push notifications',
      'profileNotificationsEmailHeader': 'Email notifications',
      'profileNotificationsDigestHeader': 'Digest frequency',
      'profileNotificationsDigestHelper':
          'How often should we send summary emails?',
      'profileNotificationsDigestDaily': 'Daily',
      'profileNotificationsDigestWeekly': 'Weekly',
      'profileNotificationsDigestMonthly': 'Monthly',
      'profileNotificationsSave': 'Save preferences',
      'profileNotificationsReset': 'Reset',
      'profileNotificationsSaved': 'Notification preferences saved.',
      'profileNotificationsSaveFailed': 'Could not save preferences.',
      'profileNotificationsLoadFailedTitle':
          'Could not load notification settings',
      'profileNotificationsCategoryOrdersTitle': 'Order updates',
      'profileNotificationsCategoryOrdersBody':
          'Shipping, production, and delivery status.',
      'profileNotificationsCategoryDesignsTitle': 'Design activity',
      'profileNotificationsCategoryDesignsBody':
          'AI suggestions, edits, and approvals.',
      'profileNotificationsCategoryPromosTitle': 'Promotions',
      'profileNotificationsCategoryPromosBody':
          'New drops, seasonal releases, and offers.',
      'profileNotificationsCategoryGuidesTitle': 'Guides & tips',
      'profileNotificationsCategoryGuidesBody':
          'How-to content and cultural insights.',
      'profileLocaleTitle': 'Language & currency',
      'profileLocaleSubtitle': 'Change language and region',
      'profileLocaleLanguageHeader': 'App language',
      'profileLocaleLanguageHelper':
          'Choose the language used across menus and content.',
      'profileLocaleCurrencyHeader': 'Currency',
      'profileLocaleCurrencyHelper':
          'Override the currency used for prices and totals.',
      'profileLocaleCurrencyAuto': 'Auto',
      'profileLocaleCurrencyAutoHint':
          'Auto will use {currency} based on your language/region.',
      'profileLocaleCurrencyJpy': 'JPY',
      'profileLocaleCurrencyUsd': 'USD',
      'profileLocaleSave': 'Save changes',
      'profileLocaleSaved': 'Locale preferences updated.',
      'profileLocaleSaveFailed': 'Could not save locale preferences.',
      'profileLocaleUseDevice': 'Use device language',
      'profileLegalTitle': 'Legal',
      'profileLegalSubtitle': 'Terms, privacy, and disclosures',
      'profileLegalDownloadTooltip': 'Download for offline',
      'profileLegalDownloadComplete': 'Legal documents saved for offline use.',
      'profileLegalDownloadFailed': 'Could not save documents. Try again.',
      'profileLegalLoadFailedTitle': 'Could not load legal documents',
      'profileLegalDocumentsTitle': 'Documents',
      'profileLegalContentTitle': 'Document',
      'profileLegalOpenInBrowser': 'Open in browser',
      'profileLegalVersionUnknown': 'Latest',
      'profileLegalNoDocument': 'Select a document to view details.',
      'profileLegalUnavailable': 'This document is not available right now.',
      'profileLegalNoContent': 'No content available for this document.',
      'profileSupportTitle': 'Support',
      'profileSupportSubtitle': 'FAQ and contact options',
      'supportChatConnectedAgent':
          'You are now connected with Rina (Support Agent).',
      'supportChatAgentGreeting':
          "Hi, I'm Rina. I can take it from here. Could you share an order ID?",
      'supportChatBotHandoff': 'Got it. I am connecting you to a specialist.',
      'supportChatBotDelivery':
          'Delivery usually takes 3-5 business days. Do you have an order ID?',
      'supportChatBotOrderStatus':
          'I can check order status. Please share the order ID if you have it.',
      'supportChatBotFallback':
          'I can help with orders, delivery, or seal specs. What do you need?',
      'supportChatAgentRefund':
          'I can help with refunds. Which order should we review?',
      'supportChatAgentAddress':
          'I can update the delivery address if production has not started.',
      'supportChatAgentFallback':
          'Thanks, I am checking now. I will update you shortly.',
      'profileGuidesTitle': 'Guides',
      'profileGuidesSubtitle': 'Culture and how-to guides',
      'profileHowtoTitle': 'How to',
      'profileHowtoSubtitle': 'Tutorials and videos',
      'profileLinkedAccountsTitle': 'Linked accounts',
      'profileLinkedAccountsSubtitle': 'Connect Apple and Google',
      'profileLinkedAccountsHeader':
          'Manage the sign-in methods connected to your account.',
      'profileLinkedAccountsAddTooltip': 'Link account',
      'profileLinkedAccountsLoadFailedTitle': 'Could not load linked accounts',
      'profileLinkedAccountsSignedOutTitle':
          'Sign in to manage linked accounts',
      'profileLinkedAccountsSignedOutBody':
          'Sign in to connect Apple or Google.',
      'profileLinkedAccountsSignIn': 'Sign in',
      'profileLinkedAccountsBannerTitle': 'Security reminder',
      'profileLinkedAccountsBannerBody':
          'Use a unique password and keep recovery options updated.',
      'profileLinkedAccountsBannerBodyLong':
          'Use a unique password, keep recovery options updated, and review connected providers regularly.',
      'profileLinkedAccountsBannerAction': 'Review tips',
      'profileLinkedAccountsConnected': 'Connected',
      'profileLinkedAccountsNotConnected': 'Not connected',
      'profileLinkedAccountsProviderFallback': 'No display name',
      'profileLinkedAccountsAutoSignIn': 'Auto sign-in',
      'profileLinkedAccountsNotConnectedHelper':
          'Link this provider to enable auto sign-in.',
      'profileLinkedAccountsUnlink': 'Unlink',
      'profileLinkedAccountsUnlinkTitle': 'Unlink account?',
      'profileLinkedAccountsUnlinkBody':
          'You will no longer be able to sign in with this provider.',
      'profileLinkedAccountsUnlinkConfirm': 'Unlink',
      'profileLinkedAccountsCancel': 'Cancel',
      'profileLinkedAccountsUnlinkDisabled':
          'Link another account before unlinking.',
      'profileLinkedAccountsSave': 'Save changes',
      'profileLinkedAccountsSaved': 'Linked account settings saved.',
      'profileLinkedAccountsSaveFailed': 'Could not save changes.',
      'profileLinkedAccountsLinked': 'Account linked.',
      'profileLinkedAccountsLinkFailed': 'Could not link account.',
      'profileLinkedAccountsUnlinked': 'Account unlinked.',
      'profileLinkedAccountsUnlinkFailed': 'Could not unlink account.',
      'profileLinkedAccountsLinkTitle': 'Link another account',
      'profileLinkedAccountsLinkSubtitle': 'Continue to connect.',
      'profileLinkedAccountsAlreadyLinked': 'Already linked.',
      'profileLinkedAccountsFooter':
          'Tip: Linking more than one provider helps you recover access.',
      'profileLinkedAccountsOk': 'OK',
      'profileExportTitle': 'Export data',
      'profileExportSubtitle': 'Download your account data',
      'profileExportAppBarSubtitle': 'Create a secure account archive',
      'profileExportSummaryTitle': 'What we export',
      'profileExportSummaryBody':
          'Your profile, saved seals, orders, and activity are bundled into a single ZIP archive.',
      'profileExportIncludeAssetsTitle': 'Design assets',
      'profileExportIncludeAssetsSubtitle':
          'Saved seals, templates, and previews',
      'profileExportIncludeOrdersTitle': 'Orders & invoices',
      'profileExportIncludeOrdersSubtitle':
          'Order history, shipments, receipts',
      'profileExportIncludeHistoryTitle': 'Usage history',
      'profileExportIncludeHistorySubtitle':
          'Searches, edits, and activity log',
      'profileExportPermissionTitle': 'Storage access needed',
      'profileExportPermissionBody':
          'Allow access to download the archive to your device.',
      'profileExportPermissionCta': 'Allow access',
      'permissionsTitle': 'Permissions',
      'permissionsSubtitle': 'Give Hanko Field the access it needs.',
      'permissionsHeroTitle': 'Stay ready to create',
      'permissionsHeroBody':
          'We only request access when it helps you build, export, and stay updated.',
      'permissionsPersonaDomestic':
          'Optimized for official Japanese hanko workflows.',
      'permissionsPersonaInternational':
          'Guidance-first setup for global users.',
      'permissionsPhotosTitle': 'Photos',
      'permissionsPhotosBody':
          'Import a stamp scan or photo to begin a new design.',
      'permissionsPhotosAssist1': 'Scan an existing seal',
      'permissionsPhotosAssist2': 'Use camera roll',
      'permissionsStorageTitle': 'Files & storage',
      'permissionsStorageBody':
          'Save exports, receipts, and design proofs to your device.',
      'permissionsStorageAssist1': 'Download exports',
      'permissionsStorageAssist2': 'Attach files',
      'permissionsNotificationsTitle': 'Notifications',
      'permissionsNotificationsBody':
          'Get updates on production, delivery, and approvals.',
      'permissionsNotificationsAssist1': 'Production alerts',
      'permissionsNotificationsAssist2': 'Delivery updates',
      'permissionsStatusGranted': 'Granted',
      'permissionsStatusDenied': 'Not allowed',
      'permissionsStatusRestricted': 'Restricted',
      'permissionsStatusUnknown': 'Not decided',
      'permissionsFallbackPhotos':
          'To enable photo access, open system Settings and allow Photos.',
      'permissionsFallbackStorage':
          'To enable file access, open system Settings and allow Files & Storage.',
      'permissionsFallbackNotifications':
          'To enable alerts, open system Settings and allow Notifications.',
      'permissionsCtaGrantAll': 'Grant access',
      'permissionsCtaNotNow': 'Not now',
      'permissionsFooterPolicy': 'Review data policy',
      'permissionsItemActionAllow': 'Allow',
      'profileExportStatusReadyTitle': 'Ready to export',
      'profileExportStatusReadyBody':
          'We will package your data as a ZIP archive.',
      'profileExportStatusInProgressTitle': 'Preparing archive',
      'profileExportStatusInProgressBody':
          'This may take a moment. Keep the app open.',
      'profileExportStatusDoneTitle': 'Export ready',
      'profileExportStatusDoneBody':
          'Saved to secure storage. You can download again anytime.',
      'profileExportCtaStart': 'Create export',
      'profileExportCtaHistory': 'View previous exports',
      'profileExportHistoryTitle': 'Previous exports',
      'profileExportHistoryEmptyTitle': 'No exports yet',
      'profileExportHistoryEmptyBody': 'Create an export to see it here.',
      'profileExportHistoryDownload': 'Download archive',
      'profileExportErrorTitle': 'Could not load export',
      'profileExportErrorBody':
          'Something went wrong while loading export settings.',
      'profileExportRetry': 'Retry',
      'profileExportTimeJustNow': 'Just now',
      'profileExportTimeMinutes': '{count} min ago',
      'profileExportTimeHours': '{count} hr ago',
      'profileExportTimeDays': '{count} days ago',
      'profileExportTimeDate': '{date}',
      'profileExportTimeCompactNow': 'now',
      'profileExportTimeCompactMinutes': '{count}m',
      'profileExportTimeCompactHours': '{count}h',
      'profileExportTimeCompactDays': '{count}d',
      'profileDeleteTitle': 'Delete account',
      'profileDeleteSubtitle': 'Permanently delete your account',
      'profileDeleteWarningTitle': 'Account deletion is permanent',
      'profileDeleteWarningBody':
          'Your profile, saved seals, and order history will be removed. '
          'Some transactional records may be retained for legal reasons.',
      'profileDeleteAcknowledgementTitle': 'Please confirm before continuing',
      'profileDeleteAckDataLossTitle': 'Delete my saved designs and profile',
      'profileDeleteAckDataLossBody':
          'This removes your profile, saved seals, and preferences.',
      'profileDeleteAckOrdersTitle': 'I understand active orders continue',
      'profileDeleteAckOrdersBody':
          'Open orders, refunds, or support cases may continue after deletion.',
      'profileDeleteAckIrreversibleTitle': 'This action cannot be undone',
      'profileDeleteAckIrreversibleBody':
          'I will need to create a new account to return.',
      'profileDeleteFooterNote':
          'You will be signed out immediately after the deletion request is processed.',
      'profileDeleteCta': 'Delete account',
      'profileDeleteCancelCta': 'Cancel',
      'profileDeleteConfirmTitle': 'Delete your account?',
      'profileDeleteConfirmBody':
          'We will deactivate your account and remove personal data. This cannot be undone.',
      'profileDeleteConfirmAction': 'Delete',
      'profileDeleteConfirmCancel': 'Keep account',
      'profileDeleteSuccess':
          'Account deletion requested. You have been signed out.',
      'profileDeleteError': 'Account deletion failed. Please try again.',
      'profileDeleteErrorTitle': 'Unable to load delete settings',
      'profileDeleteErrorBody': 'Please try again.',
      'profileDeleteRetry': 'Retry',
      'profileSignInCta': 'Sign in',
      'profileAccountSecurityTitle': 'Account security',
      'profileAccountSecuritySubtitle': 'Passwords, 2FA, and linked providers',
      'profileAccountSecurityBody':
          'Security settings will appear here in a future update.',
      'appUpdateTitle': 'App update',
      'appUpdateCheckAgain': 'Check again',
      'appUpdateChecking': 'Checking version...',
      'appUpdateVerifyFailedTitle': 'Unable to verify version',
      'appUpdateRetry': 'Retry',
      'appUpdateBannerRequired': 'You must update to keep using the app.',
      'appUpdateBannerOptional':
          'A new version is ready. Update when convenient.',
      'appUpdateBannerAction': 'Update',
      'appUpdateCardRequiredTitle': 'Update required',
      'appUpdateCardOptionalTitle': 'Update available',
      'appUpdateCurrentVersion': 'Current version: {version}',
      'appUpdateMinimumVersion': 'Minimum required: {version}',
      'appUpdateLatestVersion': 'Latest version: {version}',
      'appUpdateNow': 'Update now',
      'appUpdateOpenStore': 'Open store listing',
      'appUpdateContinue': 'Continue without updating',
      'appUpdateStoreUnavailable':
          'Store link is unavailable. Please update from the app store.',
      'appUpdateStoreOpenFailed':
          'Unable to open the store. Please update from the store app.',
      'appUpdateReminder': 'Update available (v{version}).',
      'appUpdateLater': 'Later',
      'commonBack': 'Back',
      'commonRetry': 'Retry',
      'commonClose': 'Close',
      'commonSave': 'Save',
      'commonLearnMore': 'Learn more',
      'commonLoadMore': 'Load more',
      'commonClear': 'Clear',
      'commonLoadFailed': 'Failed to load',
      'commonUnknown': 'Unknown',
      'offlineTitle': 'You are offline',
      'offlineMessage':
          'Reconnect to sync your data and keep everything up to date.',
      'offlineRetry': 'Retry connection',
      'offlineOpenCachedLibrary': 'Open cached library',
      'offlineCacheHint': 'Cached items are limited until you sync.',
      'offlineLastSyncUnavailable': 'Last sync unavailable',
      'offlineLastSyncLabel': 'Last sync {date} {time}',
      'changelogTitle': 'Changelog',
      'changelogLatestReleaseTooltip': 'Latest release',
      'changelogHighlightsTitle': 'Highlights',
      'changelogAllUpdates': 'All updates',
      'changelogMajorOnly': 'Major only',
      'changelogUnableToLoad': 'Unable to load updates',
      'changelogNoUpdatesTitle': 'No updates yet',
      'changelogNoUpdatesMessage':
          'We will post release notes here as soon as they are ready.',
      'changelogVersionHistoryTitle': 'Version history',
      'changelogVersionHistorySubtitle':
          'Tap a release to see details and fixes.',
      'searchHintText': 'Search templates, materials, articles',
      'searchVoiceTooltip': 'Voice search',
      'searchVoiceComingSoon': 'Voice search and barcode scan coming soon',
      'searchRecentTitle': 'Recent searches',
      'searchSuggestionsTitle': 'Suggestions',
      'searchSuggestionsLoadFailed': 'Failed to load suggestions',
      'searchResultsErrorTitle': 'Could not search',
      'searchResultsEmptyTitle': 'No results',
      'searchResultsEmptyMessage':
          'Try adjusting keywords or switching a segment.',
      'homeTitle': 'Home',
      'homeSearchTooltip': 'Search',
      'homeNotificationsTooltip': 'Notifications',
      'homeFeaturedTitle': 'Featured highlights',
      'homeFeaturedSubtitle':
          'Campaigns and recommended flows, curated for you',
      'homeFeaturedEmpty':
          'No featured highlights right now. Please check back later.',
      'homeRecentTitle': 'Recent designs',
      'homeRecentSubtitle': 'Resume drafts or orders quickly',
      'homeRecentActionLabel': 'See all',
      'homeRecentEmpty': 'No designs yet. Start a new one.',
      'homeRecommendedTitle': 'Recommended templates',
      'homeRecommendedSubtitle':
          'Suggestions tailored to your activity and region',
      'homeRecommendedLoading': 'Preparing recommended templates...',
      'homeStatusDraft': 'Draft',
      'homeStatusReady': 'Ready',
      'homeStatusOrdered': 'Ordered',
      'homeStatusLocked': 'Locked',
      'homeShapeRound': 'Round',
      'homeShapeSquare': 'Square',
      'homeWritingTensho': 'Tensho',
      'homeWritingReisho': 'Reisho',
      'homeWritingKaisho': 'Kaisho',
      'homeWritingGyosho': 'Gyosho',
      'homeWritingKoentai': 'Koentai',
      'homeWritingCustom': 'Custom',
      'homeNameUnset': 'Unnamed',
      'homeDesignSummary': '{shape} {size}mm · {style}',
      'homeDesignAiCheckDone': 'Official seal check complete',
      'homeDesignAiCheckLabel': 'AI check: {diagnostic}',
      'homeDesignAiCheckNotRun': 'Not run',
      'homeTemplateLabel': '{shape}・{style}',
      'homeTemplateRecommendedSize': 'Recommended {size}mm',
      'homeTemplateApply': 'Apply',
      'homeLoadFailed': 'Failed to load',
      'topBarSearchLabel': 'Search',
      'topBarSearchHint': 'Supports ⌘K / Ctrl+K shortcuts',
      'topBarSearchTooltip': 'Search (⌘K / Ctrl+K)',
      'topBarHelpLabel': 'Help',
      'topBarHelpHint': 'Open with Shift + /',
      'topBarHelpTooltip': 'Help & FAQ (Shift + /)',
      'topBarNotificationsLabel': 'Notifications',
      'topBarNotificationsLabelWithUnread': 'Notifications ({count} unread)',
      'topBarNotificationsTooltip': 'Notifications (Alt + N)',
      'topBarNotificationsTooltipWithUnread':
          'Notifications ({count} unread) (Alt + N)',
      'topBarHelpOverlayTitle': 'Help & shortcuts',
      'topBarHelpOverlayPrimaryAction': 'Browse FAQ',
      'topBarHelpOverlaySecondaryAction': 'Contact support',
      'topBarHelpOverlayBody':
          'Shortcuts and support entry points. Jump to FAQ or chat when you\'re stuck.',
      'topBarShortcutSearchLabel': 'Search',
      'topBarShortcutHelpLabel': 'Help',
      'topBarShortcutNotificationsLabel': 'Notifications',
      'topBarHelpLinkFaqTitle': 'Find answers in FAQ',
      'topBarHelpLinkFaqSubtitle': 'Troubleshooting and top questions',
      'topBarHelpLinkChatTitle': 'Chat with us',
      'topBarHelpLinkChatSubtitle': 'Get quick answers',
      'topBarHelpLinkContactTitle': 'Contact form',
      'topBarHelpLinkContactSubtitle': 'For detailed support requests',
      'splashLoading': 'Starting up…',
      'splashFailedTitle': 'Startup failed',
      'splashFailedMessage': 'Check your network and try again.',
      'designVersionsTitle': 'Version history',
      'designVersionsShowDiffTooltip': 'Show diff',
      'designVersionsSecondaryDuplicate': 'Create copy',
      'designVersionsTimelineTitle': 'Timeline',
      'designVersionsRefreshTooltip': 'Refresh history',
      'designVersionsAuditLogTitle': 'Audit log',
      'designVersionsNoAuditTitle': 'No history',
      'designVersionsNoAuditMessage': 'No action log yet for this design.',
      'designVersionsRollbackTitle': 'Rollback to v{version}?',
      'designVersionsRollbackBody':
          'This will replace the current working version. The diff will remain in history.',
      'designVersionsRollbackAction': 'Restore',
      'designVersionsRollbackCancel': 'Cancel',
      'designVersionsCurrentLabel': 'Current: v{version}',
      'designVersionsNoDiffSummary': 'No changes',
      'designVersionsCompareTargetLabel': 'Compare v{version}',
      'designVersionsLatestLabel': 'Latest',
      'designVersionsRollbackButton': 'Rollback',
      'designVersionsPreviewCurrent': 'Current',
      'designVersionsPreviewTarget': 'Compare',
      'designVersionsInitialFallback': 'Seal',
      'designVersionsUnset': 'Unset',
      'designVersionsAutoLayout': 'Auto',
      'designVersionsNoDiffTitle': 'No changes',
      'designVersionsNoDiffMessage':
          'No differences between latest and comparison version.',
      'designVersionsChangeHistoryEmpty': 'No change note',
      'designVersionsTemplateLabel': 'Template: {template}',
      'designVersionsStatusCurrent': 'Current',
      'designVersionsStatusComparing': 'Comparing',
      'designVersionsStatusHistory': 'History',
      'designVersionsLoadFailedTitle': 'Couldn\'t load history',
      'designVersionsSimilarityLabel': 'Similarity',
      'designVersionsRelativeNow': 'Just now',
      'designVersionsRelativeMinutes': '{count}m ago',
      'designVersionsRelativeHours': '{count}h ago',
      'designVersionsRelativeDays': '{count}d ago',
      'checkoutPaymentTitle': 'Payment method',
      'checkoutPaymentAddTooltip': 'Add payment method',
      'checkoutPaymentLoadFailedTitle': 'Could not load payments',
      'checkoutPaymentEmptyTitle': 'Add a payment method',
      'checkoutPaymentEmptyBody': 'Save a card or wallet to continue checkout.',
      'checkoutPaymentSignInHint': 'Sign in to add methods.',
      'checkoutPaymentAddMethod': 'Add method',
      'checkoutPaymentChooseSaved': 'Choose a saved payment method.',
      'checkoutPaymentAddAnother': 'Add another method',
      'checkoutPaymentContinueReview': 'Continue to review',
      'checkoutPaymentAddFailed': 'Could not add payment method',
      'checkoutPaymentMethodCard': 'Card',
      'checkoutPaymentMethodWallet': 'Wallet',
      'checkoutPaymentMethodBank': 'Bank transfer',
      'checkoutPaymentMethodFallback': 'Payment method',
      'checkoutPaymentExpires': 'Expires {month}/{year}',
      'cartPromoEnterCode': 'Enter a promo code',
      'cartPromoAddItemsRequired': 'Add items before applying discounts.',
      'cartPromoField10Label': '10% off',
      'cartPromoField10Description': 'Applies to merchandise subtotal.',
      'cartPromoShipfreeShortfall':
          'Add ¥{amount} more to unlock free shipping.',
      'cartPromoShipfreeLabel': 'Free shipping',
      'cartPromoInkLabel': 'Ink set bonus',
      'cartPromoInkDescription': '¥200 off for ink/accessory bundles.',
      'cartPromoInvalid': 'Invalid or expired code.',
      'cartLineTitaniumTitle': 'Titanium round seal',
      'cartLineTitaniumVariant': '15mm · Deep engraving',
      'cartLineTitaniumDesign': 'Design: Akiyama (篤山)',
      'cartLineTitaniumAddonSleeveLabel': 'Microfiber sleeve',
      'cartLineTitaniumAddonSleeveDescription': 'Slim case with scratch guard.',
      'cartLineTitaniumAddonSleeveBadge': 'Popular',
      'cartLineTitaniumAddonDeepLabel': 'Deep engraving',
      'cartLineTitaniumAddonDeepDescription': 'Sharper edges for crisp stamps.',
      'cartLineTitaniumAddonWrapLabel': 'Gift wrap',
      'cartLineTitaniumAddonWrapDescription':
          'Adds washi band and message card.',
      'cartLineTitaniumNoteIntl': 'Customs-friendly material',
      'cartLineTitaniumNoteDomestic': 'Rush-ready, personalized',
      'cartLineTitaniumRibbon': 'Bestseller',
      'cartLineAcrylicTitle': 'Color acrylic seal',
      'cartLineAcrylicVariant': '12mm · Mint / Script',
      'cartLineAcrylicDesign': 'Design: Upload later',
      'cartLineAcrylicAddonUvLabel': 'UV finish',
      'cartLineAcrylicAddonUvDescription':
          'Protects from fading and scratches.',
      'cartLineAcrylicAddonUvBadge': 'Limited',
      'cartLineAcrylicAddonInkLabel': 'Ink pad set',
      'cartLineAcrylicAddonInkDescription':
          'Compact pad with replaceable insert.',
      'cartLineAcrylicAddonPouchLabel': 'Soft pouch',
      'cartLineAcrylicAddonPouchDescription': 'Keeps acrylic surface clean.',
      'cartLineAcrylicNote': 'Ships with add-on recommendations.',
      'cartLineAcrylicRibbonIntl': 'Intl friendly',
      'cartLineAcrylicRibbon': 'Recommended',
      'cartLineBoxTitle': 'Keepsake box',
      'cartLineBoxVariant': 'Engraved lid · Natural',
      'cartLineBoxDesign': 'Name: Hanko Field',
      'cartLineBoxAddonFoamLabel': 'Foam insert',
      'cartLineBoxAddonFoamDescription': 'Secures seal and accessories.',
      'cartLineBoxAddonCardLabel': 'Care card',
      'cartLineBoxAddonCardDescription': 'Printed care instructions in JP/EN.',
      'cartLineBoxAddonWrapLabel': 'Wrapping bundle',
      'cartLineBoxAddonWrapDescription': 'Ribbon, sticker, and spare tissue.',
      'cartLineBoxNoteIntl': 'Includes bilingual insert.',
      'cartLineBoxNoteDomestic': 'Message engraving included.',
      'cartLineBoxRibbon': 'Gift',
      'cartEstimateMethodIntl': 'Intl',
      'cartEstimateMethodDomestic': 'Domestic',
      'cartEstimateMethodIntlPriority': 'Intl priority',
      'cartEstimateMethodStandard': 'Standard',
      'cartTitle': 'Cart',
      'cartBulkEditTooltip': 'Bulk edit',
      'cartLoadFailedTitle': 'Could not load cart',
      'cartEmptyTitle': 'Cart is empty',
      'cartEmptyMessage': 'Add items from the shop to see an estimate.',
      'cartEmptyAction': 'Back to shop',
      'cartRemovedItem': 'Removed {item}',
      'cartUndo': 'Undo',
      'cartPromoApplied': 'Applied {label}',
      'cartEditOptionsTitle': 'Edit options',
      'cartAddonIncluded': 'Included',
      'cartReset': 'Reset',
      'cartSave': 'Save',
      'cartBulkActionsTitle': 'Bulk actions',
      'cartBulkActionsBody':
          'Apply promo, adjust quantities, or clear selections for all lines.',
      'cartBulkActionApplyField10': 'Apply FIELD10',
      'cartBulkActionShipfree': 'Free shipping',
      'cartBulkActionClearSelections': 'Clear selections',
      'cartUnitPerItem': 'per item',
      'cartEditOptionsAction': 'Edit options',
      'cartRemoveAction': 'Remove',
      'cartLeadTimeLabel': 'Est. {min}-{max} days',
      'cartLineTotalLabel': 'Line total',
      'cartPromoTitle': 'Promo code',
      'cartPromoFieldLabel': 'Enter code',
      'cartPromoApplyLabel': 'Apply',
      'cartPromoAppliedFallback': 'Promo applied.',
      'cartPromoMockHint': 'Promo codes are simulated for this mock.',
      'cartSummaryTitle': 'Estimate summary',
      'cartSummaryItems': '{count} items',
      'cartSummarySubtotal': 'Subtotal',
      'cartSummaryDiscount': 'Discount',
      'cartSummaryShipping': 'Shipping',
      'cartSummaryFree': 'Free',
      'cartSummaryTax': 'Estimated tax',
      'cartSummaryTotal': 'Total (est.)',
      'cartSummaryEstimate': 'Est. {min}-{max} days · {method}',
      'cartProceedCheckout': 'Proceed to checkout',
      'checkoutAddressTitle': 'Shipping address',
      'checkoutAddressAddTooltip': 'Add address',
      'checkoutAddressLoadFailedTitle': 'Could not load addresses',
      'checkoutAddressEmptyTitle': 'Add your first address',
      'checkoutAddressEmptyMessage':
          'Save a shipping address to continue checkout.',
      'checkoutAddressAddAction': 'Add address',
      'checkoutAddressChooseHint': 'Choose where to ship your order.',
      'checkoutAddressAddAnother': 'Add another address',
      'checkoutAddressContinueShipping': 'Continue to shipping',
      'checkoutAddressSelectRequired': 'Select an address to continue',
      'checkoutAddressSavedCreated': 'Address added',
      'checkoutAddressSavedUpdated': 'Address updated',
      'checkoutAddressChipShipping': 'Shipping',
      'checkoutAddressChipDefault': 'Default',
      'checkoutAddressChipBilling': 'Billing',
      'checkoutAddressChipInternational': 'International',
      'checkoutAddressLabelFallback': 'Shipping address',
      'checkoutAddressEditAction': 'Edit',
      'checkoutAddressPersonaDomesticHint':
          'Use postal lookup for Japanese addresses; include building name.',
      'checkoutAddressPersonaInternationalHint':
          'For international shipping, enter romanized names and a phone with country code.',
      'checkoutAddressFormAddTitle': 'Add address',
      'checkoutAddressFormEditTitle': 'Edit address',
      'checkoutAddressFormDomesticLabel': 'Domestic (JP)',
      'checkoutAddressFormInternationalLabel': 'International',
      'checkoutAddressFormLabelOptional': 'Label (optional)',
      'checkoutAddressFormRecipient': 'Recipient',
      'checkoutAddressFormCompanyOptional': 'Company (optional)',
      'checkoutAddressFormPostalCode': 'Postal code',
      'checkoutAddressFormLookup': 'Lookup',
      'checkoutAddressFormState': 'Prefecture/State',
      'checkoutAddressFormCity': 'City/Ward',
      'checkoutAddressFormLine1': 'Address line 1',
      'checkoutAddressFormLine2Optional': 'Address line 2 (optional)',
      'checkoutAddressFormCountry': 'Country/Region',
      'checkoutAddressFormPhone': 'Phone (with country code)',
      'checkoutAddressFormDefaultTitle': 'Use as default',
      'checkoutAddressFormDefaultSubtitle':
          'Default address is pre-selected in checkout.',
      'checkoutAddressFormSave': 'Save address',
      'checkoutAddressFormFixErrors': 'Please correct the highlighted fields.',
      'checkoutAddressRequired': 'Required',
      'checkoutAddressRecipientRequired': 'Recipient is required',
      'checkoutAddressLine1Required': 'Address line is required',
      'checkoutAddressCityRequired': 'City/Ward is required',
      'checkoutAddressPostalFormat': 'Use 123-4567 format',
      'checkoutAddressStateRequired': 'Prefecture is required',
      'checkoutAddressCountryJapanRequired': 'Set country to Japan (JP)',
      'checkoutAddressPhoneDomestic': 'Include area code (10+ digits)',
      'checkoutAddressPostalShort': 'Postal/ZIP is too short',
      'checkoutAddressCountryRequired': 'Country/region is required',
      'checkoutAddressPhoneInternational': 'Add country code (e.g., +1)',
      'checkoutShippingMissingState': 'Missing state',
      'checkoutShippingSelectAddress': 'Select an address first.',
      'checkoutShippingOptionUnavailable':
          'Option unavailable for this address.',
      'checkoutShippingPromoRequiresExpress':
          'Promotion requires express shipping.',
      'checkoutShippingBadgePopular': 'Popular',
      'checkoutShippingBadgeFastest': 'Fastest',
      'checkoutShippingBadgeTracked': 'Tracked',
      'checkoutShippingOptionDomStandardLabel': 'Yamato standard',
      'checkoutShippingOptionDomStandardCarrier': 'Yamato',
      'checkoutShippingOptionDomStandardNote': 'Weekends + tracking',
      'checkoutShippingOptionDomExpressLabel': 'Express next-day',
      'checkoutShippingOptionDomExpressCarrier': 'Yamato/JP Post',
      'checkoutShippingOptionDomExpressNote':
          'Best for promo codes requiring express.',
      'checkoutShippingOptionDomPickupLabel': 'Convenience store pickup',
      'checkoutShippingOptionDomPickupCarrier': 'Lawson/FamilyMart',
      'checkoutShippingOptionDomPickupNote': 'Held for 7 days at store.',
      'checkoutShippingOptionIntlExpressLabel': 'Express courier',
      'checkoutShippingOptionIntlExpressCarrier': 'DHL / Yamato Global',
      'checkoutShippingOptionIntlExpressNote':
          'Includes customs pre-clearance.',
      'checkoutShippingOptionIntlPriorityLabel': 'Priority air',
      'checkoutShippingOptionIntlPriorityCarrier': 'EMS',
      'checkoutShippingOptionIntlPriorityNote':
          'Hands-on support for customs forms.',
      'checkoutShippingOptionIntlEconomyLabel': 'Economy air',
      'checkoutShippingOptionIntlEconomyCarrier': 'JP Post Air',
      'checkoutShippingOptionIntlEconomyNote':
          'Best for budget-friendly delivery.',
      'checkoutShippingBannerInternationalDelay':
          'Customs screening is adding 1–2 days to some international deliveries.',
      'checkoutShippingBannerKyushuDelay':
          'Seasonal weather may delay Kyushu deliveries by half a day.',
      'shopTitle': 'Shop',
      'shopSearchTooltip': 'Search',
      'shopCartTooltip': 'Cart',
      'shopAppBarSubtitle': 'Pick materials, bundles, and add-ons',
      'shopActionPromotions': 'See promotions',
      'shopActionGuides': 'Guides',
      'shopQuickGuidesTitle': 'Quick guides',
      'shopQuickGuidesSubtitle': 'Size, care, and cultural tips in one place',
      'shopBrowseByMaterialTitle': 'Browse by material',
      'shopBrowseByMaterialSubtitle': 'Find a feel that matches your use case',
      'shopPromotionsTitle': 'Promotions',
      'shopPromotionsSubtitle': 'Bundles and fast track slots',
      'shopPromotionsEmpty': 'No promotions available right now.',
      'shopRecommendedMaterialsTitle': 'Recommended materials',
      'shopRecommendedMaterialsSubtitle': 'Based on persona and delivery needs',
      'shopRecommendedMaterialsEmpty':
          'Materials are being prepared. Please check back soon.',
      'shopHeroBadge': 'Seasonal pick',
      'shopHeroTitle': 'Spring starter bundle with engraving tweaks',
      'shopHeroBody': 'Case, ink, and DHL-friendly templates in one tap.',
      'shopHeroAction': 'Open bundle',
      'libraryDesignDetailTitle': 'Design detail',
      'libraryDesignDetailSubtitle': 'Library',
      'libraryDesignDetailEditTooltip': 'Edit',
      'libraryDesignDetailExportTooltip': 'Export',
      'libraryDesignDetailTabDetails': 'Details',
      'libraryDesignDetailTabActivity': 'Activity',
      'libraryDesignDetailTabFiles': 'Files',
      'libraryDesignDetailMetadataTitle': 'Metadata',
      'libraryDesignDetailUsageHistoryTitle': 'Usage history',
      'libraryDesignDetailNoActivity': 'No activity yet.',
      'libraryDesignDetailFilesTitle': 'Files',
      'libraryDesignDetailPreviewPngLabel': 'Preview PNG',
      'libraryDesignDetailVectorSvgLabel': 'Vector SVG',
      'libraryDesignDetailExportAction': 'Export',
      'libraryDesignDetailUntitled': 'Untitled',
      'libraryDesignDetailAiScoreUnknown': 'AI score: -',
      'libraryDesignDetailAiScoreLabel': 'AI score: {score}',
      'libraryDesignDetailRegistrabilityUnknown': 'Registrability: -',
      'libraryDesignDetailRegistrable': 'Registrable',
      'libraryDesignDetailNotRegistrable': 'Not registrable',
      'libraryDesignDetailActionVersions': 'Versions',
      'libraryDesignDetailActionShare': 'Share',
      'libraryDesignDetailActionLinks': 'Links',
      'libraryDesignDetailActionDuplicate': 'Duplicate',
      'libraryDesignDetailActionReorder': 'Reorder',
      'libraryDesignDetailActionArchive': 'Archive',
      'libraryDesignDetailArchiveTitle': 'Archive design?',
      'libraryDesignDetailArchiveBody':
          'This removes the design from your library (mocked local data).',
      'libraryDesignDetailArchiveCancel': 'Cancel',
      'libraryDesignDetailArchiveConfirm': 'Archive',
      'libraryDesignDetailArchived': 'Archived',
      'libraryDesignDetailReorderHint':
          'Pick a product, then attach this design (mock)',
      'libraryDesignDetailHydrateFailed': 'Failed to prepare editor: {error}',
      'libraryDesignDetailFileNotAvailable': 'Not available',
      'libraryDesignDetailMetadataDesignId': 'Design ID',
      'libraryDesignDetailMetadataStatus': 'Status',
      'libraryDesignDetailMetadataAiScore': 'AI score',
      'libraryDesignDetailMetadataRegistrability': 'Registrability',
      'libraryDesignDetailMetadataCreated': 'Created',
      'libraryDesignDetailMetadataUpdated': 'Updated',
      'libraryDesignDetailMetadataLastUsed': 'Last used',
      'libraryDesignDetailMetadataVersion': 'Version',
      'libraryDesignDetailActivityCreatedTitle': 'Created',
      'libraryDesignDetailActivityUpdatedTitle': 'Updated',
      'libraryDesignDetailActivityOrderedTitle': 'Ordered',
      'libraryDesignDetailActivityCreatedDetail': 'Saved',
      'libraryDesignDetailActivityUpdatedDetail': 'Applied updates',
      'libraryDesignDetailActivityOrderedDetail': 'Ready to reorder',
      'orderDetailTitleFallback': 'Order',
      'orderDetailTooltipReorder': 'Reorder',
      'orderDetailTooltipShare': 'Share',
      'orderDetailTooltipMore': 'More',
      'orderDetailMenuContactSupport': 'Contact support',
      'orderDetailMenuCancelOrder': 'Cancel order',
      'orderDetailTabSummary': 'Summary',
      'orderDetailTabTimeline': 'Timeline',
      'orderDetailTabFiles': 'Files',
      'orderDetailShareText': 'Order {number}',
      'orderDetailInvoiceRequestSent': 'Invoice request sent (mock)',
      'orderDetailInvoiceRequestFailed': 'Could not request invoice',
      'orderDetailCancelTitle': 'Cancel this order?',
      'orderDetailCancelBody':
          'If production already started, cancellation may not be possible.',
      'orderDetailCancelConfirm': 'Cancel order',
      'orderDetailCancelKeep': 'Keep',
      'orderDetailCancelSuccess': 'Order canceled',
      'orderDetailCancelFailed': 'Could not cancel',
      'orderDetailDesignPreviewOk': 'OK',
      'orderDetailBannerInProgress':
          'Your order is in progress. You can check production and tracking here.',
      'orderDetailBannerProduction': 'Production',
      'orderDetailBannerTracking': 'Tracking',
      'orderDetailSectionOrder': 'Order',
      'orderDetailSectionItems': 'Items',
      'orderDetailSectionTotal': 'Total',
      'orderDetailSubtotal': 'Subtotal',
      'orderDetailDiscount': 'Discount',
      'orderDetailShipping': 'Shipping',
      'orderDetailShippingFree': 'Free',
      'orderDetailTax': 'Tax',
      'orderDetailTotal': 'Total',
      'orderDetailShippingAddress': 'Shipping address',
      'orderDetailBillingAddress': 'Billing address',
      'orderDetailPayment': 'Payment',
      'orderDetailDesignSnapshots': 'Design snapshots',
      'orderDetailQuickActions': 'Quick actions',
      'orderDetailRequestInvoice': 'Request invoice',
      'orderDetailContactSupport': 'Contact support',
      'orderDetailTimelineTitle': 'Timeline',
      'orderDetailProductionEvents': 'Production events',
      'orderDetailInvoiceTitle': 'Invoice',
      'orderDetailInvoiceHint': 'You can request and view invoices here.',
      'orderDetailInvoiceRequest': 'Request',
      'orderDetailInvoiceView': 'View',
      'orderDetailItemQtyLabel': 'Qty {quantity}',
      'orderDetailPaymentPending': 'Pending',
      'orderDetailPaymentPaid': 'Paid',
      'orderDetailPaymentCanceled': 'Canceled',
      'orderDetailPaymentProcessing': 'Processing',
      'orderDetailPaymentNoInfo': 'No payment information',
      'orderDetailPaymentPaidAt': 'Paid at {date}',
      'orderDetailPaymentMethodCard': 'Card',
      'orderDetailPaymentMethodWallet': 'Wallet',
      'orderDetailPaymentMethodBank': 'Bank',
      'orderDetailPaymentMethodOther': 'Other',
      'orderDetailPaymentSeparator': ' · ',
      'orderDetailMeta': 'ID {id} · {date}',
      'orderDetailStatusPending': 'Pending',
      'orderDetailStatusPaid': 'Paid',
      'orderDetailStatusInProduction': 'In production',
      'orderDetailStatusReadyToShip': 'Ready to ship',
      'orderDetailStatusShipped': 'Shipped',
      'orderDetailStatusDelivered': 'Delivered',
      'orderDetailStatusCanceled': 'Canceled',
      'orderDetailStatusProcessing': 'Processing',
      'orderDetailMilestonePlaced': 'Placed',
      'orderDetailMilestonePaid': 'Paid',
      'orderDetailMilestoneProduction': 'Production',
      'orderDetailMilestoneShipped': 'Shipped',
      'orderDetailMilestoneDelivered': 'Delivered',
      'orderDetailMilestoneCanceled': 'Canceled',
      'kanjiDictionaryTitle': 'Kanji dictionary',
      'kanjiDictionaryToggleShowAll': 'Show all',
      'kanjiDictionaryToggleShowFavorites': 'Show favorites',
      'kanjiDictionaryOpenGuides': 'Open guides',
      'kanjiDictionarySearchHint': 'Search kanji',
      'kanjiDictionaryHistoryHint':
          'Search for meanings, readings, or sample names.',
      'kanjiDictionaryHistoryTitle': 'History',
      'kanjiDictionaryFiltersTitle': 'Filters',
      'kanjiDictionaryGradesAll': 'All grades',
      'kanjiDictionaryGrade1': 'Grade 1',
      'kanjiDictionaryGrade2': 'Grade 2',
      'kanjiDictionaryGrade3': 'Grade 3',
      'kanjiDictionaryGrade4': 'Grade 4',
      'kanjiDictionaryGrade5': 'Grade 5',
      'kanjiDictionaryGrade6': 'Grade 6+',
      'kanjiDictionaryStrokesAll': 'All strokes',
      'kanjiDictionaryRadicalAny': 'Any radical',
      'kanjiDictionaryRadicalWater': 'Water',
      'kanjiDictionaryRadicalSun': 'Sun',
      'kanjiDictionaryRadicalPlant': 'Plant',
      'kanjiDictionaryRadicalHeart': 'Heart',
      'kanjiDictionaryRadicalEarth': 'Earth',
      'kanjiDictionaryStrokeCount': '{count} strokes',
      'kanjiDictionaryRadicalLabel': 'Radical: {radical}',
      'kanjiDictionaryFavorite': 'Favorite',
      'kanjiDictionaryUnfavorite': 'Unfavorite',
      'kanjiDictionaryDetails': 'Details',
      'kanjiDictionaryChipStrokes': 'Strokes: {count}',
      'kanjiDictionaryChipRadical': 'Radical: {radical}',
      'kanjiDictionaryStrokeOrderTitle': 'Stroke order',
      'kanjiDictionaryExamplesTitle': 'Examples',
      'kanjiDictionaryInsertIntoNameInput': 'Insert into name input',
      'kanjiDictionaryDone': 'Done',
      'kanjiDictionaryExampleUsage': 'Used in names and seals',
      'kanjiDictionaryNoStrokeData': 'No stroke data.',
      'kanjiDictionaryStrokeOrderPrefix': 'Order: {steps}',
      'orderInvoiceTitle': 'Invoice',
      'orderInvoiceShareTooltip': 'Share',
      'orderInvoiceLoadFailed': 'Could not load invoice',
      'orderInvoiceDownloadPdf': 'Download PDF',
      'orderInvoiceSendEmail': 'Send by email',
      'orderInvoiceContactSupport': 'Contact support',
      'orderInvoiceTotalLabel': 'Total',
      'orderInvoiceStatusAvailable': 'Available',
      'orderInvoiceStatusPending': 'Pending',
      'orderInvoiceTaxable': 'Taxable',
      'orderInvoiceTaxExempt': 'Tax exempt',
      'orderInvoicePreviewTitle': 'Preview',
      'orderInvoiceRefreshTooltip': 'Refresh',
      'orderInvoicePendingBody': 'Invoice is being prepared.',
      'orderInvoiceUnavailableBody': 'Invoice preview is not available.',
      'orderInvoiceRequestAction': 'Request invoice',
      'orderInvoiceSavedTo': 'Saved to {path}',
      'orderInvoiceSaveFailed': 'Could not save PDF',
      'orderInvoiceShareText': '{app} • {number}',
      'orderInvoiceOrderLabel': 'Order {number}',
      'orderInvoiceIssuedLabel': 'Issued: {date}',
      'orderProductionTitle': 'Production',
      'orderProductionRefreshTooltip': 'Refresh',
      'orderProductionStatusLabel': 'Status: {status}',
      'orderProductionEtaLabel': 'Estimated completion: {date}',
      'orderProductionDelayedMessage':
          'This order is past the estimated completion date.',
      'orderProductionTimelineTitle': 'Timeline',
      'orderProductionNoEventsTitle': 'No events yet',
      'orderProductionNoEventsMessage':
          'Production updates will appear here when available.',
      'orderProductionNoEventsAction': 'Refresh',
      'orderProductionHealthOnTrack': 'On track',
      'orderProductionHealthAttention': 'Attention',
      'orderProductionHealthDelayed': 'Delayed',
      'orderProductionEventStation': 'Station: {station}',
      'orderProductionEventQc': 'QC: {details}',
      'orderProductionEventQueued': 'Queued',
      'orderProductionEventEngraving': 'Engraving',
      'orderProductionEventPolishing': 'Polishing',
      'orderProductionEventQualityCheck': 'Quality check',
      'orderProductionEventPacked': 'Packed',
      'orderProductionEventOnHold': 'On hold',
      'orderProductionEventRework': 'Rework',
      'orderProductionEventCanceled': 'Canceled',
    },
    'ja': {
      'appTitle': 'ハンコフィールド',
      'welcomeHeadline': 'あなたらしい印鑑をつくる',
      'welcomeBody': 'ローカライズ、テーマ、デザイントークンの準備ができました。',
      'primaryAction': 'はじめる',
      'secondaryAction': 'デザインを見る',
      'onboardingTitle': 'チュートリアル',
      'onboardingSkip': 'スキップ',
      'onboardingNext': '次へ',
      'onboardingBack': '戻る',
      'onboardingFinish': '設定を進める',
      'onboardingRetry': '再読み込み',
      'onboardingErrorTitle': 'チュートリアルを読み込めませんでした',
      'onboardingStepCount': '{total} ステップ中 {current} ステップ目',
      'onboardingSlideCreateTitle': '迷わずつくれるデザイン',
      'onboardingSlideCreateBody': '書体・バランスをプレビューしながら、印鑑に合うテンプレを提案します。',
      'onboardingSlideCreateTagline': '作成',
      'onboardingSlideMaterialsTitle': '素材選びもかんたん',
      'onboardingSlideMaterialsBody': '木・石・金属の特徴や在庫状況を比較し、おすすめを提示します。',
      'onboardingSlideMaterialsTagline': 'ショップ',
      'onboardingSlideSupportTitle': 'サポート付きで安心',
      'onboardingSlideSupportBody': '途中保存やWebとの連携ができ、困ったらすぐに相談できます。',
      'onboardingSlideSupportTagline': 'サポート',
      'localeTitle': '言語・地域の設定',
      'localeSave': '保存',
      'localeSubtitle': '表示言語を選択してください',
      'localeDescription': '端末の言語設定: {device}',
      'localeContinue': '保存して進む',
      'localeUseDevice': '端末の設定を使う',
      'personaTitle': 'ペルソナを選択',
      'personaSave': '保存',
      'personaSubtitle': 'あなたに合わせた案内に切り替えます',
      'personaDescription': '利用シーンに近いスタイルを選ぶと、最適なガイドを表示します。',
      'personaContinue': '次へ進む',
      'personaUseSelected': 'この設定で進む',
      'authTitle': 'ログインまたは続行',
      'authSubtitle': '利用方法を選んでください',
      'authBody': 'デザインの保存や注文にはログインが必要です。ゲストでも閲覧できます。',
      'authEmailLabel': 'メールアドレス',
      'authEmailHelper': '領収書やアカウント復旧に使用します。',
      'authEmailRequired': 'メールアドレスを入力してください。',
      'authEmailInvalid': '有効なメールアドレスを入力してください。',
      'authPasswordLabel': 'パスワード',
      'authPasswordHelper': '8文字以上で入力してください。',
      'authPasswordTooShort': 'パスワードが短すぎます。',
      'authEmailCta': 'メールで続ける',
      'authAppleButton': 'Appleで続ける',
      'authGoogleButton': 'Googleで続ける',
      'authGuestCta': 'ゲストとして続行',
      'authGuestNote': 'ゲストは閲覧のみ、保存や購入は制限されます。',
      'authHelpTooltip': 'ヘルプ',
      'authHelpTitle': 'サインインについて',
      'authHelpBody': 'アカウントでデザインや注文を安全に同期します。後から設定でApple/Googleを連携できます。',
      'authErrorCancelled': 'サインインをキャンセルしました。',
      'authErrorNetwork': 'ネットワークに接続できません。',
      'authErrorInvalid': '認証情報が無効です。もう一度お試しください。',
      'authErrorWrongPassword': 'メールアドレスまたはパスワードが正しくありません。',
      'authErrorWeakPassword': 'パスワードが弱すぎます（8文字以上推奨）。',
      'authErrorAppleUnavailable': 'この端末ではAppleでのサインインは利用できません。',
      'authErrorLink': '{providers}ですでに登録済みです。その方法でサインインして連携してください。',
      'authErrorUnknown': 'サインインできませんでした。再度お試しください。',
      'authLinkingTitle': 'アカウントを連携',
      'authLinkPrompt': '{providers}でサインインするとアカウントをまとめられます。',
      'authProviderUnknown': '既存の方法',
      'authProviderGoogle': 'Google',
      'authProviderApple': 'Apple',
      'authProviderEmail': 'メール',
      'profileTitle': 'プロフィール',
      'profileAvatarUpdateTooltip': 'プロフィール写真を変更',
      'profileAvatarUpdateTitle': 'プロフィール写真の変更',
      'profileAvatarUpdateBody': 'プロフィール写真の更新は準備中です。現在はペルソナ切替と各種設定の確認ができます。',
      'profileAvatarUpdateOk': 'OK',
      'profileLoadFailedTitle': 'プロフィールを読み込めませんでした',
      'profileLoadFailedMessage': 'プロフィールの読み込みに失敗しました。再度お試しください。',
      'profileRetry': '再試行',
      'profileStatusSignedOut': '未ログイン',
      'profileStatusGuest': 'ゲスト',
      'profileStatusMember': 'ログイン済み',
      'profileFallbackGuestName': 'ゲスト',
      'profileFallbackProfileName': 'プロフィール',
      'profilePersonaTitle': 'ペルソナ',
      'profilePersonaSubtitle': 'ガイドやおすすめ表示を切り替えます。',
      'profilePersonaJapanese': '日本向け',
      'profilePersonaForeigner': '海外向け',
      'profileQuickLinksTitle': 'クイックリンク',
      'profileQuickOrdersTitle': '注文',
      'profileQuickOrdersSubtitle': '注文履歴を確認',
      'profileQuickLibraryTitle': 'マイ印鑑',
      'profileQuickLibrarySubtitle': '保存したデザイン',
      'profileSettingsTitle': '設定',
      'profileAddressesTitle': '住所帳',
      'profileAddressesSubtitle': '配送先を管理',
      'profilePaymentsTitle': '支払い方法',
      'profilePaymentsSubtitle': '支払い手段を管理',
      'paymentMethodErrorLast4': '下4桁を入力してください',
      'paymentMethodErrorExpMonth': '有効期限(月)を入力してください',
      'paymentMethodErrorExpYear': '有効期限(年)を入力してください',
      'paymentMethodErrorFixFields': '入力内容を確認してください',
      'paymentMethodAddFailed': '支払い方法を追加できません',
      'paymentMethodSheetTitle': '支払い方法を追加',
      'paymentMethodSheetCard': 'カード',
      'paymentMethodSheetWallet': 'ウォレット',
      'paymentMethodSheetBrandLabel': 'ブランド (例: Visa)',
      'paymentMethodSheetLast4Label': 'カード下4桁',
      'paymentMethodSheetExpMonthLabel': '有効期限(月)',
      'paymentMethodSheetExpYearLabel': '有効期限(年)',
      'paymentMethodSheetBillingNameLabel': '請求先名 (任意)',
      'paymentMethodSheetSave': '保存',
      'profileNotificationsTitle': '通知設定',
      'profileNotificationsSubtitle': '通知の受け取りを設定',
      'profileNotificationsHeader': 'ハンコフィールドからの通知方法を選択します。',
      'profileNotificationsPushHeader': 'プッシュ通知',
      'profileNotificationsEmailHeader': 'メール通知',
      'profileNotificationsDigestHeader': 'まとめ通知の頻度',
      'profileNotificationsDigestHelper': 'メールの配信頻度を選択してください。',
      'profileNotificationsDigestDaily': '毎日',
      'profileNotificationsDigestWeekly': '毎週',
      'profileNotificationsDigestMonthly': '毎月',
      'profileNotificationsSave': '設定を保存',
      'profileNotificationsReset': 'リセット',
      'profileNotificationsSaved': '通知設定を保存しました。',
      'profileNotificationsSaveFailed': '通知設定を保存できませんでした。',
      'profileNotificationsLoadFailedTitle': '通知設定を読み込めません',
      'profileNotificationsCategoryOrdersTitle': '注文状況',
      'profileNotificationsCategoryOrdersBody': '発送、製作、配達のステータス更新。',
      'profileNotificationsCategoryDesignsTitle': 'デザインの進捗',
      'profileNotificationsCategoryDesignsBody': 'AI提案や修正、承認の通知。',
      'profileNotificationsCategoryPromosTitle': 'キャンペーン',
      'profileNotificationsCategoryPromosBody': '新作や季節限定、特別オファー。',
      'profileNotificationsCategoryGuidesTitle': 'ガイドとヒント',
      'profileNotificationsCategoryGuidesBody': '使い方コンテンツや文化的なヒント。',
      'profileLocaleTitle': '言語と通貨',
      'profileLocaleSubtitle': '表示言語と地域設定',
      'profileLocaleLanguageHeader': '表示言語',
      'profileLocaleLanguageHelper': 'メニューやコンテンツの表示言語を選択します。',
      'profileLocaleCurrencyHeader': '通貨',
      'profileLocaleCurrencyHelper': '価格表示の通貨を上書きします。',
      'profileLocaleCurrencyAuto': '自動',
      'profileLocaleCurrencyAutoHint': '言語・地域に合わせて {currency} を使います。',
      'profileLocaleCurrencyJpy': 'JPY',
      'profileLocaleCurrencyUsd': 'USD',
      'profileLocaleSave': '保存',
      'profileLocaleSaved': '言語と通貨の設定を保存しました。',
      'profileLocaleSaveFailed': '設定を保存できませんでした。',
      'profileLocaleUseDevice': '端末の言語に合わせる',
      'profileLegalTitle': '規約・法務',
      'profileLegalSubtitle': '利用規約やプライバシー',
      'profileLegalDownloadTooltip': 'オフライン用に保存',
      'profileLegalDownloadComplete': '法務文書をオフライン用に保存しました。',
      'profileLegalDownloadFailed': '保存できませんでした。再試行してください。',
      'profileLegalLoadFailedTitle': '法務文書を読み込めませんでした',
      'profileLegalDocumentsTitle': '文書一覧',
      'profileLegalContentTitle': '文書',
      'profileLegalOpenInBrowser': 'ブラウザで開く',
      'profileLegalVersionUnknown': '最新',
      'profileLegalNoDocument': '表示する文書を選択してください。',
      'profileLegalUnavailable': '現在この文書を利用できません。',
      'profileLegalNoContent': '文書の内容がありません。',
      'profileSupportTitle': 'サポート',
      'profileSupportSubtitle': 'FAQ・問い合わせ',
      'supportChatConnectedAgent': 'サポート担当の理奈が参加しました。',
      'supportChatAgentGreeting': '理奈です。こちらで対応します。注文IDがあれば教えてください。',
      'supportChatBotHandoff': '承知しました。担当者におつなぎします。',
      'supportChatBotDelivery': '通常は3〜5営業日でお届けします。注文IDはお持ちですか？',
      'supportChatBotOrderStatus': '注文状況を確認できます。注文IDを教えてください。',
      'supportChatBotFallback': '注文状況、配送、印面についてお手伝いできます。ご用件を教えてください。',
      'supportChatAgentRefund': '返金の件ですね。対象の注文IDを教えてください。',
      'supportChatAgentAddress': '制作前であれば配送先の変更が可能です。注文IDを教えてください。',
      'supportChatAgentFallback': '確認しますので少々お待ちください。',
      'profileGuidesTitle': 'ガイド',
      'profileGuidesSubtitle': '文化と使い方の案内',
      'profileHowtoTitle': '使い方',
      'profileHowtoSubtitle': 'チュートリアルと動画',
      'profileLinkedAccountsTitle': '連携アカウント',
      'profileLinkedAccountsSubtitle': 'Apple/Google 連携',
      'profileLinkedAccountsHeader': '連携済みのサインイン方法を管理します。',
      'profileLinkedAccountsAddTooltip': 'アカウントを追加',
      'profileLinkedAccountsLoadFailedTitle': '連携アカウントを読み込めません',
      'profileLinkedAccountsSignedOutTitle': 'サインインして連携を管理',
      'profileLinkedAccountsSignedOutBody': 'サインイン後にApple/Googleを連携できます。',
      'profileLinkedAccountsSignIn': 'サインイン',
      'profileLinkedAccountsBannerTitle': 'セキュリティのヒント',
      'profileLinkedAccountsBannerBody': '強固なパスワードと復旧手段を最新に保ちましょう。',
      'profileLinkedAccountsBannerBodyLong':
          '強固なパスワードを使い、復旧手段を最新に保ち、連携済みのプロバイダを定期的に確認しましょう。',
      'profileLinkedAccountsBannerAction': '確認する',
      'profileLinkedAccountsConnected': '接続済み',
      'profileLinkedAccountsNotConnected': '未接続',
      'profileLinkedAccountsProviderFallback': '表示名なし',
      'profileLinkedAccountsAutoSignIn': '自動サインイン',
      'profileLinkedAccountsNotConnectedHelper': '連携すると自動サインインが有効になります。',
      'profileLinkedAccountsUnlink': '解除',
      'profileLinkedAccountsUnlinkTitle': '連携を解除しますか？',
      'profileLinkedAccountsUnlinkBody': 'このプロバイダでのサインインができなくなります。',
      'profileLinkedAccountsUnlinkConfirm': '解除する',
      'profileLinkedAccountsCancel': 'キャンセル',
      'profileLinkedAccountsUnlinkDisabled': '解除するには別の連携を追加してください。',
      'profileLinkedAccountsSave': '変更を保存',
      'profileLinkedAccountsSaved': '連携設定を保存しました。',
      'profileLinkedAccountsSaveFailed': '変更を保存できませんでした。',
      'profileLinkedAccountsLinked': '連携しました。',
      'profileLinkedAccountsLinkFailed': '連携できませんでした。',
      'profileLinkedAccountsUnlinked': '解除しました。',
      'profileLinkedAccountsUnlinkFailed': '解除できませんでした。',
      'profileLinkedAccountsLinkTitle': '連携するアカウント',
      'profileLinkedAccountsLinkSubtitle': '続けて連携します。',
      'profileLinkedAccountsAlreadyLinked': '連携済み',
      'profileLinkedAccountsFooter': 'ヒント: 複数のプロバイダを連携すると復旧が容易です。',
      'profileLinkedAccountsOk': 'OK',
      'profileExportTitle': 'データ出力',
      'profileExportSubtitle': 'アカウントデータをDL',
      'profileExportAppBarSubtitle': 'アカウントの安全なアーカイブを作成',
      'profileExportSummaryTitle': '含まれる内容',
      'profileExportSummaryBody': 'プロフィール、保存済み印影、注文履歴、利用履歴をZIPにまとめます。',
      'profileExportIncludeAssetsTitle': 'デザイン素材',
      'profileExportIncludeAssetsSubtitle': '保存済み印影・テンプレ・プレビュー',
      'profileExportIncludeOrdersTitle': '注文・請求書',
      'profileExportIncludeOrdersSubtitle': '注文履歴、配送状況、領収書',
      'profileExportIncludeHistoryTitle': '利用履歴',
      'profileExportIncludeHistorySubtitle': '検索、編集、アクティビティログ',
      'profileExportPermissionTitle': 'ストレージ権限が必要です',
      'profileExportPermissionBody': 'アーカイブを端末に保存するため許可してください。',
      'profileExportPermissionCta': '許可する',
      'permissionsTitle': '権限',
      'permissionsSubtitle': 'Hanko Fieldを快適に使うための権限です。',
      'permissionsHeroTitle': '作業をスムーズに',
      'permissionsHeroBody': '作成・書き出し・更新通知に必要なときだけ確認します。',
      'permissionsPersonaDomestic': '実印・銀行印の運用を意識した設定です。',
      'permissionsPersonaInternational': '海外ユーザー向けのガイド重視設定です。',
      'permissionsPhotosTitle': '写真',
      'permissionsPhotosBody': '印影の写真やスキャンを取り込み、新規デザインに使います。',
      'permissionsPhotosAssist1': '印影をスキャン',
      'permissionsPhotosAssist2': 'カメラロールから',
      'permissionsStorageTitle': 'ファイルとストレージ',
      'permissionsStorageBody': '書き出しデータや領収書を端末に保存します。',
      'permissionsStorageAssist1': '書き出しを保存',
      'permissionsStorageAssist2': 'ファイルを添付',
      'permissionsNotificationsTitle': '通知',
      'permissionsNotificationsBody': '制作・発送・承認の最新情報を受け取ります。',
      'permissionsNotificationsAssist1': '制作アラート',
      'permissionsNotificationsAssist2': '配送状況',
      'permissionsStatusGranted': '許可済み',
      'permissionsStatusDenied': '未許可',
      'permissionsStatusRestricted': '制限中',
      'permissionsStatusUnknown': '未選択',
      'permissionsFallbackPhotos': '写真へのアクセスは設定アプリで「写真」を許可してください。',
      'permissionsFallbackStorage': 'ファイルへのアクセスは設定アプリで「ファイル/ストレージ」を許可してください。',
      'permissionsFallbackNotifications': '通知を受け取るには設定アプリで「通知」を許可してください。',
      'permissionsCtaGrantAll': 'まとめて許可',
      'permissionsCtaNotNow': '後で',
      'permissionsFooterPolicy': 'データポリシーを見る',
      'permissionsItemActionAllow': '許可する',
      'profileExportStatusReadyTitle': '準備完了',
      'profileExportStatusReadyBody': 'データをZIPアーカイブにまとめます。',
      'profileExportStatusInProgressTitle': 'アーカイブ作成中',
      'profileExportStatusInProgressBody': 'しばらくお待ちください。アプリを閉じないでください。',
      'profileExportStatusDoneTitle': 'エクスポート完了',
      'profileExportStatusDoneBody': '安全な領域に保存しました。いつでも再ダウンロードできます。',
      'profileExportCtaStart': 'エクスポートを作成',
      'profileExportCtaHistory': '過去のエクスポートを見る',
      'profileExportHistoryTitle': '過去のエクスポート',
      'profileExportHistoryEmptyTitle': 'まだありません',
      'profileExportHistoryEmptyBody': 'エクスポートを作成するとここに表示されます。',
      'profileExportHistoryDownload': 'アーカイブをダウンロード',
      'profileExportErrorTitle': 'データ出力を読み込めませんでした',
      'profileExportErrorBody': 'エクスポート設定の読み込みに失敗しました。',
      'profileExportRetry': '再試行',
      'profileExportTimeJustNow': 'たった今',
      'profileExportTimeMinutes': '{count}分前',
      'profileExportTimeHours': '{count}時間前',
      'profileExportTimeDays': '{count}日前',
      'profileExportTimeDate': '{date}',
      'profileExportTimeCompactNow': '今',
      'profileExportTimeCompactMinutes': '{count}分',
      'profileExportTimeCompactHours': '{count}時間',
      'profileExportTimeCompactDays': '{count}日',
      'profileDeleteTitle': 'アカウント削除',
      'profileDeleteSubtitle': '削除手続きを進める',
      'profileDeleteWarningTitle': 'アカウント削除は取り消せません',
      'profileDeleteWarningBody':
          'プロフィール、保存した印影、注文履歴は削除されます。'
          '法令上必要な記録は保持される場合があります。',
      'profileDeleteAcknowledgementTitle': '確認事項',
      'profileDeleteAckDataLossTitle': '保存した印影とプロフィールを削除',
      'profileDeleteAckDataLossBody': 'プロフィール、保存デザイン、設定が削除されます。',
      'profileDeleteAckOrdersTitle': '進行中の注文は継続',
      'profileDeleteAckOrdersBody': '未完了の注文や返金、サポート対応は削除後も処理されます。',
      'profileDeleteAckIrreversibleTitle': '取り消し不可',
      'profileDeleteAckIrreversibleBody': '再利用するには新規登録が必要です。',
      'profileDeleteFooterNote': '削除処理が完了すると自動的にサインアウトします。',
      'profileDeleteCta': 'アカウントを削除',
      'profileDeleteCancelCta': 'キャンセル',
      'profileDeleteConfirmTitle': 'アカウントを削除しますか？',
      'profileDeleteConfirmBody': 'アカウントを無効化し、個人データを削除します。元に戻せません。',
      'profileDeleteConfirmAction': '削除する',
      'profileDeleteConfirmCancel': '残しておく',
      'profileDeleteSuccess': '削除を受け付けました。サインアウトしました。',
      'profileDeleteError': '削除に失敗しました。もう一度お試しください。',
      'profileDeleteErrorTitle': '削除画面を読み込めません',
      'profileDeleteErrorBody': '時間をおいて再度お試しください。',
      'profileDeleteRetry': '再試行',
      'profileSignInCta': 'ログインする',
      'profileAccountSecurityTitle': 'アカウント保護',
      'profileAccountSecuritySubtitle': 'パスワードや2FA、連携の管理',
      'profileAccountSecurityBody': 'セキュリティ設定は今後追加予定です。',
      'appUpdateTitle': 'アップデート',
      'appUpdateCheckAgain': '再確認',
      'appUpdateChecking': 'バージョンを確認中...',
      'appUpdateVerifyFailedTitle': 'バージョンを確認できませんでした',
      'appUpdateRetry': '再試行',
      'appUpdateBannerRequired': '最新バージョンへの更新が必要です。',
      'appUpdateBannerOptional': '新しいバージョンが利用可能です。',
      'appUpdateBannerAction': '更新する',
      'appUpdateCardRequiredTitle': '更新が必要です',
      'appUpdateCardOptionalTitle': 'アップデートがあります',
      'appUpdateCurrentVersion': '現在のバージョン: {version}',
      'appUpdateMinimumVersion': '必須バージョン: {version}',
      'appUpdateLatestVersion': '最新バージョン: {version}',
      'appUpdateNow': '今すぐ更新',
      'appUpdateOpenStore': 'ストアを開く',
      'appUpdateContinue': '後で行う',
      'appUpdateStoreUnavailable': 'ストアのリンクを取得できませんでした。ストアから更新してください。',
      'appUpdateStoreOpenFailed': 'ストアを開けませんでした。ストアアプリから更新してください。',
      'appUpdateReminder': '新しいバージョンがあります (v{version})。',
      'appUpdateLater': '後で',
      'commonBack': '戻る',
      'commonRetry': '再試行',
      'commonClose': '閉じる',
      'commonSave': '保存',
      'commonLearnMore': '詳しく見る',
      'commonLoadMore': 'もっと見る',
      'commonClear': 'クリア',
      'commonLoadFailed': '読み込みに失敗しました',
      'commonUnknown': '不明',
      'offlineTitle': 'オフラインです',
      'offlineMessage': 'インターネットに接続してデータを同期してください。',
      'offlineRetry': '再試行',
      'offlineOpenCachedLibrary': 'キャッシュ済みライブラリを開く',
      'offlineCacheHint': 'キャッシュされた項目のみ閲覧できます。',
      'offlineLastSyncUnavailable': '最終同期はまだありません',
      'offlineLastSyncLabel': '最終同期 {date} {time}',
      'changelogTitle': '変更履歴',
      'changelogLatestReleaseTooltip': '最新リリース',
      'changelogHighlightsTitle': 'ハイライト',
      'changelogAllUpdates': 'すべて',
      'changelogMajorOnly': '主要のみ',
      'changelogUnableToLoad': '更新履歴を読み込めませんでした',
      'changelogNoUpdatesTitle': '更新履歴はまだありません',
      'changelogNoUpdatesMessage': 'リリースノートが準備でき次第こちらに掲載します。',
      'changelogVersionHistoryTitle': 'バージョン履歴',
      'changelogVersionHistorySubtitle': 'リリースをタップして詳細を確認できます。',
      'searchHintText': 'テンプレート、素材、記事を検索',
      'searchVoiceTooltip': '音声検索',
      'searchVoiceComingSoon': '音声検索とバーコード検索は近日対応',
      'searchRecentTitle': '検索履歴',
      'searchSuggestionsTitle': 'サジェスト',
      'searchSuggestionsLoadFailed': '候補を取得できませんでした',
      'searchResultsErrorTitle': '検索できませんでした',
      'searchResultsEmptyTitle': '結果がありません',
      'searchResultsEmptyMessage': 'キーワードやセグメントを変えてみてください。',
      'homeTitle': 'ホーム',
      'homeSearchTooltip': '検索',
      'homeNotificationsTooltip': '通知',
      'homeFeaturedTitle': '注目の特集',
      'homeFeaturedSubtitle': 'キャンペーンやおすすめの流れをピックアップ',
      'homeFeaturedEmpty': '今は表示できる特集がありません。後でもう一度お試しください。',
      'homeRecentTitle': '最近のデザイン',
      'homeRecentSubtitle': '下書きや発注済みをすぐ再開',
      'homeRecentActionLabel': '一覧',
      'homeRecentEmpty': 'まだデザインがありません。新しく作成してみましょう。',
      'homeRecommendedTitle': 'おすすめテンプレート',
      'homeRecommendedSubtitle': '利用履歴と地域に合わせて提案',
      'homeRecommendedLoading': 'おすすめテンプレートを準備しています…',
      'homeStatusDraft': '下書き',
      'homeStatusReady': '準備完了',
      'homeStatusOrdered': '注文済み',
      'homeStatusLocked': 'ロック',
      'homeShapeRound': '丸',
      'homeShapeSquare': '角',
      'homeWritingTensho': '篆書',
      'homeWritingReisho': '隷書',
      'homeWritingKaisho': '楷書',
      'homeWritingGyosho': '行書',
      'homeWritingKoentai': '古印体',
      'homeWritingCustom': 'カスタム',
      'homeNameUnset': '名称未設定',
      'homeDesignSummary': '{shape} {size}mm ・ {style}',
      'homeDesignAiCheckDone': '実印チェック済み',
      'homeDesignAiCheckLabel': 'AI診断: {diagnostic}',
      'homeDesignAiCheckNotRun': '未実行',
      'homeTemplateLabel': '{shape}・{style}',
      'homeTemplateRecommendedSize': '{size}mm 推奨',
      'homeTemplateApply': '適用',
      'homeLoadFailed': '読み込みに失敗しました',
      'topBarSearchLabel': '検索',
      'topBarSearchHint': '⌘K / Ctrl+K のショートカットに対応',
      'topBarSearchTooltip': '検索 (⌘K / Ctrl+K)',
      'topBarHelpLabel': 'ヘルプ',
      'topBarHelpHint': 'Shift + / でも開けます',
      'topBarHelpTooltip': 'ヘルプ・FAQ (Shift + /)',
      'topBarNotificationsLabel': '通知',
      'topBarNotificationsLabelWithUnread': '通知 ({count} 件の未読)',
      'topBarNotificationsTooltip': '通知 (Alt + N)',
      'topBarNotificationsTooltipWithUnread': '通知 ({count} 件の未読) (Alt + N)',
      'topBarHelpOverlayTitle': 'ヘルプとショートカット',
      'topBarHelpOverlayPrimaryAction': 'FAQを見る',
      'topBarHelpOverlaySecondaryAction': '問い合わせる',
      'topBarHelpOverlayBody': 'ショートカットとサポートへの入り口です。困ったときはFAQやチャットにすぐ移動できます。',
      'topBarShortcutSearchLabel': '検索',
      'topBarShortcutHelpLabel': 'ヘルプ',
      'topBarShortcutNotificationsLabel': '通知',
      'topBarHelpLinkFaqTitle': 'FAQで調べる',
      'topBarHelpLinkFaqSubtitle': 'よくある質問とトラブルシューティング',
      'topBarHelpLinkChatTitle': 'チャットで相談',
      'topBarHelpLinkChatSubtitle': 'すぐ聞きたいときはこちら',
      'topBarHelpLinkContactTitle': '問い合わせフォーム',
      'topBarHelpLinkContactSubtitle': '詳細なサポートが必要な場合',
      'splashLoading': '起動しています…',
      'splashFailedTitle': '起動に失敗しました',
      'splashFailedMessage': 'ネットワーク状況を確認して、もう一度お試しください。',
      'designVersionsTitle': 'バージョン履歴',
      'designVersionsShowDiffTooltip': '差分を表示',
      'designVersionsSecondaryDuplicate': 'コピーを作成',
      'designVersionsTimelineTitle': 'タイムライン',
      'designVersionsRefreshTooltip': '履歴をリフレッシュ',
      'designVersionsAuditLogTitle': '監査ログ',
      'designVersionsNoAuditTitle': '履歴はありません',
      'designVersionsNoAuditMessage': 'このデザインのアクションログがまだありません。',
      'designVersionsRollbackTitle': 'v{version} にロールバックしますか？',
      'designVersionsRollbackBody': 'この操作で現在の編集中バージョンを置き換えます。差分は履歴に残ります。',
      'designVersionsRollbackAction': '復元',
      'designVersionsRollbackCancel': 'キャンセル',
      'designVersionsCurrentLabel': '現在: v{version}',
      'designVersionsNoDiffSummary': '差分はありません',
      'designVersionsCompareTargetLabel': '比較対象 v{version}',
      'designVersionsLatestLabel': '最新版',
      'designVersionsRollbackButton': 'ロールバック',
      'designVersionsPreviewCurrent': '現在',
      'designVersionsPreviewTarget': '比較対象',
      'designVersionsInitialFallback': '印',
      'designVersionsUnset': '未設定',
      'designVersionsAutoLayout': '自動',
      'designVersionsNoDiffTitle': '差分はありません',
      'designVersionsNoDiffMessage': '最新のバージョンと比較対象に違いはありません。',
      'designVersionsChangeHistoryEmpty': '変更履歴なし',
      'designVersionsTemplateLabel': 'テンプレート: {template}',
      'designVersionsStatusCurrent': '現在',
      'designVersionsStatusComparing': '比較中',
      'designVersionsStatusHistory': '履歴',
      'designVersionsLoadFailedTitle': '履歴の読み込みに失敗しました',
      'designVersionsSimilarityLabel': '類似度',
      'designVersionsRelativeNow': 'たった今',
      'designVersionsRelativeMinutes': '{count}分前',
      'designVersionsRelativeHours': '{count}時間前',
      'designVersionsRelativeDays': '{count}日前',
      'checkoutPaymentTitle': '支払い方法',
      'checkoutPaymentAddTooltip': '支払い方法を追加',
      'checkoutPaymentLoadFailedTitle': '支払い方法を読み込めません',
      'checkoutPaymentEmptyTitle': '支払い方法を追加してください',
      'checkoutPaymentEmptyBody': 'カードやウォレットを登録すると、次のステップに進めます。',
      'checkoutPaymentSignInHint': '支払い方法の追加にはログインが必要です。',
      'checkoutPaymentAddMethod': '支払い方法を追加',
      'checkoutPaymentChooseSaved': '保存済みの支払い方法を選択してください。',
      'checkoutPaymentAddAnother': '支払い方法を追加',
      'checkoutPaymentContinueReview': '注文確認へ進む',
      'checkoutPaymentAddFailed': '支払い方法を追加できません',
      'checkoutPaymentMethodCard': 'カード',
      'checkoutPaymentMethodWallet': 'ウォレット',
      'checkoutPaymentMethodBank': '銀行振込',
      'checkoutPaymentMethodFallback': '支払い方法',
      'checkoutPaymentExpires': '有効期限 {month}/{year}',
      'cartPromoEnterCode': 'クーポンコードを入力してください',
      'cartPromoAddItemsRequired': '商品を追加すると割引を適用できます。',
      'cartPromoField10Label': '10%オフ',
      'cartPromoField10Description': '商品小計に適用されます。',
      'cartPromoShipfreeShortfall': 'あと¥{amount}で送料無料になります。',
      'cartPromoShipfreeLabel': '送料無料',
      'cartPromoInkLabel': '朱肉セット優待',
      'cartPromoInkDescription': 'インクやアクセサリーの同梱で¥200オフ。',
      'cartPromoInvalid': 'コードが無効か期限切れです。',
      'cartLineTitaniumTitle': 'チタン丸印',
      'cartLineTitaniumVariant': '15mm・深彫り調整',
      'cartLineTitaniumDesign': 'デザイン：篤山（Akiyama）',
      'cartLineTitaniumAddonSleeveLabel': 'マイクロファイバーケース',
      'cartLineTitaniumAddonSleeveDescription': '薄型の起毛ケース。',
      'cartLineTitaniumAddonSleeveBadge': '人気',
      'cartLineTitaniumAddonDeepLabel': '深彫り仕上げ',
      'cartLineTitaniumAddonDeepDescription': 'くっきり押せる深彫り仕上げ。',
      'cartLineTitaniumAddonWrapLabel': 'ギフトラッピング',
      'cartLineTitaniumAddonWrapDescription': '和紙帯とメッセージカード付き。',
      'cartLineTitaniumNoteIntl': '通関に配慮した素材',
      'cartLineTitaniumNoteDomestic': 'お急ぎ対応・名入れ済み',
      'cartLineTitaniumRibbon': '人気',
      'cartLineAcrylicTitle': 'カラーアクリル印',
      'cartLineAcrylicVariant': '12mm・ミント / 筆記体',
      'cartLineAcrylicDesign': 'デザイン：後でアップロード',
      'cartLineAcrylicAddonUvLabel': 'UVコート',
      'cartLineAcrylicAddonUvDescription': '色あせ・キズ防止コーティング。',
      'cartLineAcrylicAddonUvBadge': '期間限定',
      'cartLineAcrylicAddonInkLabel': '朱肉セット',
      'cartLineAcrylicAddonInkDescription': '交換式のコンパクト朱肉。',
      'cartLineAcrylicAddonPouchLabel': 'ソフトポーチ',
      'cartLineAcrylicAddonPouchDescription': 'アクリル面を保護するポーチ。',
      'cartLineAcrylicNote': 'オプション同梱で発送。',
      'cartLineAcrylicRibbonIntl': '海外向け',
      'cartLineAcrylicRibbon': 'おすすめ',
      'cartLineBoxTitle': '桐箱・刻印入り',
      'cartLineBoxVariant': '蓋刻印・ナチュラル',
      'cartLineBoxDesign': '名入れ：はんこフィールド',
      'cartLineBoxAddonFoamLabel': 'クッション内装',
      'cartLineBoxAddonFoamDescription': '印鑑と付属品を固定するクッション。',
      'cartLineBoxAddonCardLabel': 'お手入れカード',
      'cartLineBoxAddonCardDescription': '日英併記のお手入れガイド。',
      'cartLineBoxAddonWrapLabel': 'ラッピングセット',
      'cartLineBoxAddonWrapDescription': 'リボン・シール・替え紙付き。',
      'cartLineBoxNoteIntl': '日英の案内カード付き。',
      'cartLineBoxNoteDomestic': 'メッセージ刻印済み。',
      'cartLineBoxRibbon': 'ギフト',
      'cartEstimateMethodIntl': '海外配送',
      'cartEstimateMethodDomestic': '国内配送',
      'cartEstimateMethodIntlPriority': '海外優先便',
      'cartEstimateMethodStandard': '標準',
      'cartTitle': 'カート',
      'cartBulkEditTooltip': 'まとめて編集',
      'cartLoadFailedTitle': 'カートを読み込めません',
      'cartEmptyTitle': 'カートは空です',
      'cartEmptyMessage': 'ショップから商品を追加すると、見積もりが表示されます。',
      'cartEmptyAction': 'ショップへ戻る',
      'cartRemovedItem': '{item} を削除しました',
      'cartUndo': '元に戻す',
      'cartPromoApplied': '{label} を適用しました',
      'cartEditOptionsTitle': 'オプションを編集',
      'cartAddonIncluded': '無料',
      'cartReset': '元に戻す',
      'cartSave': '保存',
      'cartBulkActionsTitle': 'まとめて操作',
      'cartBulkActionsBody': '全ての行にクーポン適用、数量調整、選択解除をまとめて行えます（モック）。',
      'cartBulkActionApplyField10': 'FIELD10 を適用',
      'cartBulkActionShipfree': '送料無料コード',
      'cartBulkActionClearSelections': '選択をクリア',
      'cartUnitPerItem': '1点あたり',
      'cartEditOptionsAction': 'オプション編集',
      'cartRemoveAction': '削除',
      'cartLeadTimeLabel': 'お届け目安 {min}〜{max}日',
      'cartLineTotalLabel': '小計',
      'cartPromoTitle': 'クーポンコード',
      'cartPromoFieldLabel': 'コードを入力',
      'cartPromoApplyLabel': '適用',
      'cartPromoAppliedFallback': 'クーポンを適用しました。',
      'cartPromoMockHint': 'クーポン入力はモックです。',
      'cartSummaryTitle': '概算サマリー',
      'cartSummaryItems': '{count}点',
      'cartSummarySubtotal': '商品小計',
      'cartSummaryDiscount': '割引',
      'cartSummaryShipping': '送料',
      'cartSummaryFree': '無料',
      'cartSummaryTax': '推定税',
      'cartSummaryTotal': '合計（概算）',
      'cartSummaryEstimate': '目安 {min}〜{max}日・{method}',
      'cartProceedCheckout': '購入手続きへ',
      'checkoutAddressTitle': '配送先',
      'checkoutAddressAddTooltip': '住所を追加',
      'checkoutAddressLoadFailedTitle': '住所を読み込めません',
      'checkoutAddressEmptyTitle': '住所を追加してください',
      'checkoutAddressEmptyMessage': '配送先を登録すると、次のステップに進めます。',
      'checkoutAddressAddAction': '住所を追加',
      'checkoutAddressChooseHint': '配送先を選択し、必要に応じて編集してください。',
      'checkoutAddressAddAnother': '住所を追加',
      'checkoutAddressContinueShipping': '配送方法へ進む',
      'checkoutAddressSelectRequired': '配送先を選択してください',
      'checkoutAddressSavedCreated': '住所を追加しました',
      'checkoutAddressSavedUpdated': '住所を更新しました',
      'checkoutAddressChipShipping': '配送先',
      'checkoutAddressChipDefault': '既定',
      'checkoutAddressChipBilling': '請求先',
      'checkoutAddressChipInternational': '海外配送',
      'checkoutAddressLabelFallback': '配送先',
      'checkoutAddressEditAction': '編集',
      'checkoutAddressPersonaDomesticHint':
          '郵便番号から住所を補完できます。建物名・部屋番号まで入力してください。',
      'checkoutAddressPersonaInternationalHint':
          '海外配送の場合はローマ字表記と国番号付き電話を入力してください。',
      'checkoutAddressFormAddTitle': '住所を追加',
      'checkoutAddressFormEditTitle': '住所を編集',
      'checkoutAddressFormDomesticLabel': '国内',
      'checkoutAddressFormInternationalLabel': '海外',
      'checkoutAddressFormLabelOptional': 'ラベル（任意）',
      'checkoutAddressFormRecipient': '受取人',
      'checkoutAddressFormCompanyOptional': '会社名（任意）',
      'checkoutAddressFormPostalCode': '郵便番号',
      'checkoutAddressFormLookup': '住所補完',
      'checkoutAddressFormState': '都道府県・州',
      'checkoutAddressFormCity': '市区町村',
      'checkoutAddressFormLine1': '番地・町名',
      'checkoutAddressFormLine2Optional': '建物名・部屋番号（任意）',
      'checkoutAddressFormCountry': '国・地域',
      'checkoutAddressFormPhone': '電話番号（国番号付き推奨）',
      'checkoutAddressFormDefaultTitle': '既定の住所にする',
      'checkoutAddressFormDefaultSubtitle': '既定の住所はチェックアウトで自動選択されます。',
      'checkoutAddressFormSave': '保存する',
      'checkoutAddressFormFixErrors': 'エラーを修正してください。',
      'checkoutAddressRequired': '必須項目です',
      'checkoutAddressRecipientRequired': '受取人を入力してください',
      'checkoutAddressLine1Required': '住所（番地）を入力してください',
      'checkoutAddressCityRequired': '市区町村を入力してください',
      'checkoutAddressPostalFormat': '郵便番号は123-4567の形式で入力してください',
      'checkoutAddressStateRequired': '都道府県を入力してください',
      'checkoutAddressCountryJapanRequired': '国内配送は国をJPにしてください',
      'checkoutAddressPhoneDomestic': '市外局番を含めて10桁以上で入力してください',
      'checkoutAddressPostalShort': '郵便番号を正しく入力してください',
      'checkoutAddressCountryRequired': '国・地域を入力してください',
      'checkoutAddressPhoneInternational': '国番号付きで入力してください（例: +81）',
      'checkoutShippingMissingState': '状態を読み込めませんでした',
      'checkoutShippingSelectAddress': '先に配送先を選択してください。',
      'checkoutShippingOptionUnavailable': 'この住所では利用できません。',
      'checkoutShippingPromoRequiresExpress': 'クーポン適用には速達が必要です。',
      'checkoutShippingBadgePopular': '人気',
      'checkoutShippingBadgeFastest': '最短',
      'checkoutShippingBadgeTracked': '追跡',
      'checkoutShippingOptionDomStandardLabel': 'ヤマト通常便',
      'checkoutShippingOptionDomStandardCarrier': 'ヤマト運輸',
      'checkoutShippingOptionDomStandardNote': '土日配達・追跡付き',
      'checkoutShippingOptionDomExpressLabel': '翌日お届け（速達）',
      'checkoutShippingOptionDomExpressCarrier': 'ヤマト / 日本郵便',
      'checkoutShippingOptionDomExpressNote': 'クーポン適用条件の速達はこちら。',
      'checkoutShippingOptionDomPickupLabel': 'コンビニ受け取り',
      'checkoutShippingOptionDomPickupCarrier': 'ローソン/ファミマ',
      'checkoutShippingOptionDomPickupNote': '店舗で7日間保管。',
      'checkoutShippingOptionIntlExpressLabel': '国際エクスプレス',
      'checkoutShippingOptionIntlExpressCarrier': 'DHL・ヤマト国際',
      'checkoutShippingOptionIntlExpressNote': '通関前処理込み、追跡可。',
      'checkoutShippingOptionIntlPriorityLabel': '優先航空便',
      'checkoutShippingOptionIntlPriorityCarrier': 'EMS',
      'checkoutShippingOptionIntlPriorityNote': '通関書類をサポート。',
      'checkoutShippingOptionIntlEconomyLabel': 'エコノミー航空便',
      'checkoutShippingOptionIntlEconomyCarrier': '日本郵便航空',
      'checkoutShippingOptionIntlEconomyNote': 'コスト重視の方向け。',
      'checkoutShippingBannerInternationalDelay':
          '通関強化により国際便で+1〜2日の遅延が発生しています。',
      'checkoutShippingBannerKyushuDelay': '季節要因で九州方面は半日程度遅れる場合があります。',
      'shopTitle': 'ショップ',
      'shopSearchTooltip': '検索',
      'shopCartTooltip': 'カート',
      'shopAppBarSubtitle': '素材やセット、オプションをまとめて選ぶ',
      'shopActionPromotions': 'キャンペーンを見る',
      'shopActionGuides': 'ガイド',
      'shopQuickGuidesTitle': 'クイックガイド',
      'shopQuickGuidesSubtitle': 'サイズ・お手入れ・文化のポイント',
      'shopBrowseByMaterialTitle': '素材から探す',
      'shopBrowseByMaterialSubtitle': '用途に合う質感を選びましょう',
      'shopPromotionsTitle': 'キャンペーン',
      'shopPromotionsSubtitle': 'まとめ買い割引や特急枠',
      'shopPromotionsEmpty': '現在ご利用いただけるキャンペーンはありません。',
      'shopRecommendedMaterialsTitle': 'おすすめ素材',
      'shopRecommendedMaterialsSubtitle': 'ペルソナと配送希望に合わせて提案',
      'shopRecommendedMaterialsEmpty': 'おすすめ素材を準備中です。またのぞいてみてください。',
      'shopHeroBadge': '季節のおすすめ',
      'shopHeroTitle': '彫り深さ調整付き 春のスターターセット',
      'shopHeroBody': 'ケース・朱肉・DHL対応テンプレが1タップで揃います。',
      'shopHeroAction': 'セットを見る',
      'libraryDesignDetailTitle': '印鑑詳細',
      'libraryDesignDetailSubtitle': 'マイ印鑑',
      'libraryDesignDetailEditTooltip': '編集',
      'libraryDesignDetailExportTooltip': '出力',
      'libraryDesignDetailTabDetails': '詳細',
      'libraryDesignDetailTabActivity': '履歴',
      'libraryDesignDetailTabFiles': 'ファイル',
      'libraryDesignDetailMetadataTitle': 'メタデータ',
      'libraryDesignDetailUsageHistoryTitle': '使用履歴',
      'libraryDesignDetailNoActivity': 'まだ履歴がありません。',
      'libraryDesignDetailFilesTitle': 'ファイル',
      'libraryDesignDetailPreviewPngLabel': 'プレビューPNG',
      'libraryDesignDetailVectorSvgLabel': 'ベクターSVG',
      'libraryDesignDetailExportAction': '出力',
      'libraryDesignDetailUntitled': '名称未設定',
      'libraryDesignDetailAiScoreUnknown': 'AIスコア: -',
      'libraryDesignDetailAiScoreLabel': 'AIスコア: {score}',
      'libraryDesignDetailRegistrabilityUnknown': '登録可否: -',
      'libraryDesignDetailRegistrable': '登録可',
      'libraryDesignDetailNotRegistrable': '登録不可',
      'libraryDesignDetailActionVersions': 'バージョン',
      'libraryDesignDetailActionShare': '共有',
      'libraryDesignDetailActionLinks': 'リンク',
      'libraryDesignDetailActionDuplicate': '複製',
      'libraryDesignDetailActionReorder': '再注文',
      'libraryDesignDetailActionArchive': 'アーカイブ',
      'libraryDesignDetailArchiveTitle': 'アーカイブしますか？',
      'libraryDesignDetailArchiveBody': 'この印鑑をライブラリから削除します（ローカルモック）。',
      'libraryDesignDetailArchiveCancel': 'キャンセル',
      'libraryDesignDetailArchiveConfirm': 'アーカイブ',
      'libraryDesignDetailArchived': 'アーカイブしました',
      'libraryDesignDetailReorderHint': '商品を選んで、この印鑑を選択してください（モック）',
      'libraryDesignDetailHydrateFailed': '編集の準備に失敗しました: {error}',
      'libraryDesignDetailFileNotAvailable': '未生成',
      'libraryDesignDetailMetadataDesignId': 'デザインID',
      'libraryDesignDetailMetadataStatus': 'ステータス',
      'libraryDesignDetailMetadataAiScore': 'AIスコア',
      'libraryDesignDetailMetadataRegistrability': '登録可否',
      'libraryDesignDetailMetadataCreated': '作成日',
      'libraryDesignDetailMetadataUpdated': '更新日',
      'libraryDesignDetailMetadataLastUsed': '最終使用',
      'libraryDesignDetailMetadataVersion': 'バージョン',
      'libraryDesignDetailActivityCreatedTitle': '作成',
      'libraryDesignDetailActivityUpdatedTitle': '更新',
      'libraryDesignDetailActivityOrderedTitle': '注文で使用',
      'libraryDesignDetailActivityCreatedDetail': '保存しました',
      'libraryDesignDetailActivityUpdatedDetail': '編集内容を反映しました',
      'libraryDesignDetailActivityOrderedDetail': '再注文できます',
      'orderDetailTitleFallback': '注文',
      'orderDetailTooltipReorder': '再注文',
      'orderDetailTooltipShare': '共有',
      'orderDetailTooltipMore': 'その他',
      'orderDetailMenuContactSupport': '問い合わせ',
      'orderDetailMenuCancelOrder': '注文をキャンセル',
      'orderDetailTabSummary': '概要',
      'orderDetailTabTimeline': '履歴',
      'orderDetailTabFiles': 'ファイル',
      'orderDetailShareText': '注文番号：{number}',
      'orderDetailInvoiceRequestSent': '領収書のリクエストを送信しました（モック）',
      'orderDetailInvoiceRequestFailed': '領収書のリクエストに失敗しました',
      'orderDetailCancelTitle': 'この注文をキャンセルしますか？',
      'orderDetailCancelBody': '制作が開始している場合、キャンセルできないことがあります。',
      'orderDetailCancelConfirm': 'キャンセルする',
      'orderDetailCancelKeep': '戻る',
      'orderDetailCancelSuccess': '注文をキャンセルしました',
      'orderDetailCancelFailed': 'キャンセルに失敗しました',
      'orderDetailDesignPreviewOk': 'OK',
      'orderDetailBannerInProgress': '注文は進行中です。制作状況や配送状況を確認できます。',
      'orderDetailBannerProduction': '制作',
      'orderDetailBannerTracking': '配送',
      'orderDetailSectionOrder': '注文',
      'orderDetailSectionItems': '明細',
      'orderDetailSectionTotal': '合計',
      'orderDetailSubtotal': '小計',
      'orderDetailDiscount': '割引',
      'orderDetailShipping': '送料',
      'orderDetailShippingFree': '無料',
      'orderDetailTax': '税',
      'orderDetailTotal': '合計',
      'orderDetailShippingAddress': '配送先',
      'orderDetailBillingAddress': '請求先',
      'orderDetailPayment': '支払い',
      'orderDetailDesignSnapshots': 'デザインスナップショット',
      'orderDetailQuickActions': '操作',
      'orderDetailRequestInvoice': '領収書を依頼',
      'orderDetailContactSupport': '問い合わせ',
      'orderDetailTimelineTitle': '履歴',
      'orderDetailProductionEvents': '制作イベント',
      'orderDetailInvoiceTitle': '領収書',
      'orderDetailInvoiceHint': '領収書の依頼・表示ができます。',
      'orderDetailInvoiceRequest': '依頼する',
      'orderDetailInvoiceView': '表示する',
      'orderDetailItemQtyLabel': '数量 {quantity}',
      'orderDetailPaymentPending': '未払い',
      'orderDetailPaymentPaid': '支払い済み',
      'orderDetailPaymentCanceled': 'キャンセル',
      'orderDetailPaymentProcessing': '処理中',
      'orderDetailPaymentNoInfo': '支払い情報はありません',
      'orderDetailPaymentPaidAt': '{date} に支払い',
      'orderDetailPaymentMethodCard': 'カード',
      'orderDetailPaymentMethodWallet': 'ウォレット',
      'orderDetailPaymentMethodBank': '銀行',
      'orderDetailPaymentMethodOther': 'その他',
      'orderDetailPaymentSeparator': '・',
      'orderDetailMeta': 'ID {id}・{date}',
      'orderDetailStatusPending': '未払い',
      'orderDetailStatusPaid': '支払い済み',
      'orderDetailStatusInProduction': '制作中',
      'orderDetailStatusReadyToShip': '発送準備中',
      'orderDetailStatusShipped': '発送済み',
      'orderDetailStatusDelivered': '配達済み',
      'orderDetailStatusCanceled': 'キャンセル',
      'orderDetailStatusProcessing': '処理中',
      'orderDetailMilestonePlaced': '注文',
      'orderDetailMilestonePaid': '支払い',
      'orderDetailMilestoneProduction': '制作',
      'orderDetailMilestoneShipped': '発送',
      'orderDetailMilestoneDelivered': '配達',
      'orderDetailMilestoneCanceled': 'キャンセル',
      'kanjiDictionaryTitle': '漢字辞典',
      'kanjiDictionaryToggleShowAll': 'すべて表示',
      'kanjiDictionaryToggleShowFavorites': 'お気に入り',
      'kanjiDictionaryOpenGuides': 'ガイドへ',
      'kanjiDictionarySearchHint': '漢字を検索',
      'kanjiDictionaryHistoryHint': '意味・読み・名前の例で検索できます。',
      'kanjiDictionaryHistoryTitle': '履歴',
      'kanjiDictionaryFiltersTitle': '絞り込み',
      'kanjiDictionaryGradesAll': '学年',
      'kanjiDictionaryGrade1': '1年',
      'kanjiDictionaryGrade2': '2年',
      'kanjiDictionaryGrade3': '3年',
      'kanjiDictionaryGrade4': '4年',
      'kanjiDictionaryGrade5': '5年',
      'kanjiDictionaryGrade6': '6年+',
      'kanjiDictionaryStrokesAll': '画数',
      'kanjiDictionaryRadicalAny': '部首',
      'kanjiDictionaryRadicalWater': '水',
      'kanjiDictionaryRadicalSun': '日',
      'kanjiDictionaryRadicalPlant': '草',
      'kanjiDictionaryRadicalHeart': '心',
      'kanjiDictionaryRadicalEarth': '土',
      'kanjiDictionaryStrokeCount': '{count}画',
      'kanjiDictionaryRadicalLabel': '部首: {radical}',
      'kanjiDictionaryFavorite': 'お気に入り',
      'kanjiDictionaryUnfavorite': '解除',
      'kanjiDictionaryDetails': '詳細',
      'kanjiDictionaryChipStrokes': '画数: {count}',
      'kanjiDictionaryChipRadical': '部首: {radical}',
      'kanjiDictionaryStrokeOrderTitle': '筆順',
      'kanjiDictionaryExamplesTitle': '用例',
      'kanjiDictionaryInsertIntoNameInput': '名前入力に追加',
      'kanjiDictionaryDone': '閉じる',
      'kanjiDictionaryExampleUsage': '氏名や印影で使われます',
      'kanjiDictionaryNoStrokeData': '画数情報がありません。',
      'kanjiDictionaryStrokeOrderPrefix': '順: {steps}',
      'orderInvoiceTitle': '領収書',
      'orderInvoiceShareTooltip': '共有',
      'orderInvoiceLoadFailed': '領収書を読み込めませんでした',
      'orderInvoiceDownloadPdf': 'PDFを保存',
      'orderInvoiceSendEmail': 'メールで送る',
      'orderInvoiceContactSupport': '問い合わせ',
      'orderInvoiceTotalLabel': '合計',
      'orderInvoiceStatusAvailable': '利用可能',
      'orderInvoiceStatusPending': '準備中',
      'orderInvoiceTaxable': '課税',
      'orderInvoiceTaxExempt': '非課税',
      'orderInvoicePreviewTitle': 'プレビュー',
      'orderInvoiceRefreshTooltip': '更新',
      'orderInvoicePendingBody': '領収書を準備しています。',
      'orderInvoiceUnavailableBody': '領収書を表示できません。',
      'orderInvoiceRequestAction': '領収書をリクエスト',
      'orderInvoiceSavedTo': '保存しました: {path}',
      'orderInvoiceSaveFailed': 'PDFを保存できませんでした',
      'orderInvoiceShareText': '{app} • {number}',
      'orderInvoiceOrderLabel': '注文番号：{number}',
      'orderInvoiceIssuedLabel': '発行日：{date}',
      'orderProductionTitle': '制作進捗',
      'orderProductionRefreshTooltip': '更新',
      'orderProductionStatusLabel': 'ステータス：{status}',
      'orderProductionEtaLabel': '完了予定：{date}',
      'orderProductionDelayedMessage': 'この注文は完了予定日を過ぎています。',
      'orderProductionTimelineTitle': 'タイムライン',
      'orderProductionNoEventsTitle': 'まだ履歴がありません',
      'orderProductionNoEventsMessage': '制作状況が更新されると、ここに表示されます。',
      'orderProductionNoEventsAction': '更新する',
      'orderProductionHealthOnTrack': '順調',
      'orderProductionHealthAttention': '注意',
      'orderProductionHealthDelayed': '遅延',
      'orderProductionEventStation': '工程：{station}',
      'orderProductionEventQc': '検品：{details}',
      'orderProductionEventQueued': '受付',
      'orderProductionEventEngraving': '彫刻',
      'orderProductionEventPolishing': '研磨',
      'orderProductionEventQualityCheck': '検品',
      'orderProductionEventPacked': '梱包',
      'orderProductionEventOnHold': '保留',
      'orderProductionEventRework': '再加工',
      'orderProductionEventCanceled': 'キャンセル',
    },
  };

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

  String get appTitle => _string('appTitle');
  String get welcomeHeadline => _string('welcomeHeadline');
  String get welcomeBody => _string('welcomeBody');
  String get primaryAction => _string('primaryAction');
  String get secondaryAction => _string('secondaryAction');
  String get onboardingTitle => _string('onboardingTitle');
  String get onboardingSkip => _string('onboardingSkip');
  String get onboardingNext => _string('onboardingNext');
  String get onboardingBack => _string('onboardingBack');
  String get onboardingFinish => _string('onboardingFinish');
  String get onboardingRetry => _string('onboardingRetry');
  String get onboardingErrorTitle => _string('onboardingErrorTitle');
  String get onboardingSlideCreateTitle =>
      _string('onboardingSlideCreateTitle');
  String get onboardingSlideCreateBody => _string('onboardingSlideCreateBody');
  String get onboardingSlideCreateTagline =>
      _string('onboardingSlideCreateTagline');
  String get onboardingSlideMaterialsTitle =>
      _string('onboardingSlideMaterialsTitle');
  String get onboardingSlideMaterialsBody =>
      _string('onboardingSlideMaterialsBody');
  String get onboardingSlideMaterialsTagline =>
      _string('onboardingSlideMaterialsTagline');
  String get onboardingSlideSupportTitle =>
      _string('onboardingSlideSupportTitle');
  String get onboardingSlideSupportBody =>
      _string('onboardingSlideSupportBody');
  String get onboardingSlideSupportTagline =>
      _string('onboardingSlideSupportTagline');
  String get localeTitle => _string('localeTitle');
  String get localeSave => _string('localeSave');
  String get localeSubtitle => _string('localeSubtitle');
  String get localeContinue => _string('localeContinue');
  String get localeUseDevice => _string('localeUseDevice');
  String get personaTitle => _string('personaTitle');
  String get personaSave => _string('personaSave');
  String get personaSubtitle => _string('personaSubtitle');
  String get personaDescription => _string('personaDescription');
  String get personaContinue => _string('personaContinue');
  String get personaUseSelected => _string('personaUseSelected');
  String get authTitle => _string('authTitle');
  String get authSubtitle => _string('authSubtitle');
  String get authBody => _string('authBody');
  String get authEmailLabel => _string('authEmailLabel');
  String get authEmailHelper => _string('authEmailHelper');
  String get authEmailRequired => _string('authEmailRequired');
  String get authEmailInvalid => _string('authEmailInvalid');
  String get authPasswordLabel => _string('authPasswordLabel');
  String get authPasswordHelper => _string('authPasswordHelper');
  String get authPasswordTooShort => _string('authPasswordTooShort');
  String get authEmailCta => _string('authEmailCta');
  String get authAppleButton => _string('authAppleButton');
  String get authGoogleButton => _string('authGoogleButton');
  String get authGuestCta => _string('authGuestCta');
  String get authGuestNote => _string('authGuestNote');
  String get authHelpTooltip => _string('authHelpTooltip');
  String get authHelpTitle => _string('authHelpTitle');
  String get authHelpBody => _string('authHelpBody');
  String get authErrorCancelled => _string('authErrorCancelled');
  String get authErrorNetwork => _string('authErrorNetwork');
  String get authErrorInvalid => _string('authErrorInvalid');
  String get authErrorWrongPassword => _string('authErrorWrongPassword');
  String get authErrorWeakPassword => _string('authErrorWeakPassword');
  String get authErrorAppleUnavailable => _string('authErrorAppleUnavailable');
  String get authErrorUnknown => _string('authErrorUnknown');
  String get authLinkingTitle => _string('authLinkingTitle');
  String get authProviderUnknown => _string('authProviderUnknown');
  String get authProviderGoogle => _string('authProviderGoogle');
  String get authProviderApple => _string('authProviderApple');
  String get authProviderEmail => _string('authProviderEmail');
  String get profileTitle => _string('profileTitle');
  String get profileAvatarUpdateTooltip =>
      _string('profileAvatarUpdateTooltip');
  String get profileAvatarUpdateTitle => _string('profileAvatarUpdateTitle');
  String get profileAvatarUpdateBody => _string('profileAvatarUpdateBody');
  String get profileAvatarUpdateOk => _string('profileAvatarUpdateOk');
  String get profileLoadFailedTitle => _string('profileLoadFailedTitle');
  String get profileLoadFailedMessage => _string('profileLoadFailedMessage');
  String get profileRetry => _string('profileRetry');
  String get profileStatusSignedOut => _string('profileStatusSignedOut');
  String get profileStatusGuest => _string('profileStatusGuest');
  String get profileStatusMember => _string('profileStatusMember');
  String get profileFallbackGuestName => _string('profileFallbackGuestName');
  String get profileFallbackProfileName =>
      _string('profileFallbackProfileName');
  String get profilePersonaTitle => _string('profilePersonaTitle');
  String get profilePersonaSubtitle => _string('profilePersonaSubtitle');
  String get profilePersonaJapanese => _string('profilePersonaJapanese');
  String get profilePersonaForeigner => _string('profilePersonaForeigner');
  String get profileQuickLinksTitle => _string('profileQuickLinksTitle');
  String get profileQuickOrdersTitle => _string('profileQuickOrdersTitle');
  String get profileQuickOrdersSubtitle =>
      _string('profileQuickOrdersSubtitle');
  String get profileQuickLibraryTitle => _string('profileQuickLibraryTitle');
  String get profileQuickLibrarySubtitle =>
      _string('profileQuickLibrarySubtitle');
  String get profileSettingsTitle => _string('profileSettingsTitle');
  String get profileAddressesTitle => _string('profileAddressesTitle');
  String get profileAddressesSubtitle => _string('profileAddressesSubtitle');
  String get profilePaymentsTitle => _string('profilePaymentsTitle');
  String get profilePaymentsSubtitle => _string('profilePaymentsSubtitle');
  String get paymentMethodErrorLast4 => _string('paymentMethodErrorLast4');
  String get paymentMethodErrorExpMonth =>
      _string('paymentMethodErrorExpMonth');
  String get paymentMethodErrorExpYear => _string('paymentMethodErrorExpYear');
  String get paymentMethodErrorFixFields =>
      _string('paymentMethodErrorFixFields');
  String get paymentMethodAddFailed => _string('paymentMethodAddFailed');
  String get paymentMethodSheetTitle => _string('paymentMethodSheetTitle');
  String get paymentMethodSheetCard => _string('paymentMethodSheetCard');
  String get paymentMethodSheetWallet => _string('paymentMethodSheetWallet');
  String get paymentMethodSheetBrandLabel =>
      _string('paymentMethodSheetBrandLabel');
  String get paymentMethodSheetLast4Label =>
      _string('paymentMethodSheetLast4Label');
  String get paymentMethodSheetExpMonthLabel =>
      _string('paymentMethodSheetExpMonthLabel');
  String get paymentMethodSheetExpYearLabel =>
      _string('paymentMethodSheetExpYearLabel');
  String get paymentMethodSheetBillingNameLabel =>
      _string('paymentMethodSheetBillingNameLabel');
  String get paymentMethodSheetSave => _string('paymentMethodSheetSave');
  String get profileNotificationsTitle => _string('profileNotificationsTitle');
  String get profileNotificationsSubtitle =>
      _string('profileNotificationsSubtitle');
  String get profileNotificationsHeader =>
      _string('profileNotificationsHeader');
  String get profileNotificationsPushHeader =>
      _string('profileNotificationsPushHeader');
  String get profileNotificationsEmailHeader =>
      _string('profileNotificationsEmailHeader');
  String get profileNotificationsDigestHeader =>
      _string('profileNotificationsDigestHeader');
  String get profileNotificationsDigestHelper =>
      _string('profileNotificationsDigestHelper');
  String get profileNotificationsDigestDaily =>
      _string('profileNotificationsDigestDaily');
  String get profileNotificationsDigestWeekly =>
      _string('profileNotificationsDigestWeekly');
  String get profileNotificationsDigestMonthly =>
      _string('profileNotificationsDigestMonthly');
  String get profileNotificationsSave => _string('profileNotificationsSave');
  String get profileNotificationsReset => _string('profileNotificationsReset');
  String get profileNotificationsSaved => _string('profileNotificationsSaved');
  String get profileNotificationsSaveFailed =>
      _string('profileNotificationsSaveFailed');
  String get profileNotificationsLoadFailedTitle =>
      _string('profileNotificationsLoadFailedTitle');
  String get profileNotificationsCategoryOrdersTitle =>
      _string('profileNotificationsCategoryOrdersTitle');
  String get profileNotificationsCategoryOrdersBody =>
      _string('profileNotificationsCategoryOrdersBody');
  String get profileNotificationsCategoryDesignsTitle =>
      _string('profileNotificationsCategoryDesignsTitle');
  String get profileNotificationsCategoryDesignsBody =>
      _string('profileNotificationsCategoryDesignsBody');
  String get profileNotificationsCategoryPromosTitle =>
      _string('profileNotificationsCategoryPromosTitle');
  String get profileNotificationsCategoryPromosBody =>
      _string('profileNotificationsCategoryPromosBody');
  String get profileNotificationsCategoryGuidesTitle =>
      _string('profileNotificationsCategoryGuidesTitle');
  String get profileNotificationsCategoryGuidesBody =>
      _string('profileNotificationsCategoryGuidesBody');
  String get profileLocaleTitle => _string('profileLocaleTitle');
  String get profileLocaleSubtitle => _string('profileLocaleSubtitle');
  String get profileLocaleLanguageHeader =>
      _string('profileLocaleLanguageHeader');
  String get profileLocaleLanguageHelper =>
      _string('profileLocaleLanguageHelper');
  String get profileLocaleCurrencyHeader =>
      _string('profileLocaleCurrencyHeader');
  String get profileLocaleCurrencyHelper =>
      _string('profileLocaleCurrencyHelper');
  String get profileLocaleCurrencyAuto => _string('profileLocaleCurrencyAuto');
  String get profileLocaleCurrencyJpy => _string('profileLocaleCurrencyJpy');
  String get profileLocaleCurrencyUsd => _string('profileLocaleCurrencyUsd');
  String get profileLocaleSave => _string('profileLocaleSave');
  String get profileLocaleSaved => _string('profileLocaleSaved');
  String get profileLocaleSaveFailed => _string('profileLocaleSaveFailed');
  String get profileLocaleUseDevice => _string('profileLocaleUseDevice');
  String get profileLegalTitle => _string('profileLegalTitle');
  String get profileLegalSubtitle => _string('profileLegalSubtitle');
  String get profileLegalDownloadTooltip =>
      _string('profileLegalDownloadTooltip');
  String get profileLegalDownloadComplete =>
      _string('profileLegalDownloadComplete');
  String get profileLegalDownloadFailed =>
      _string('profileLegalDownloadFailed');
  String get profileLegalLoadFailedTitle =>
      _string('profileLegalLoadFailedTitle');
  String get profileLegalDocumentsTitle =>
      _string('profileLegalDocumentsTitle');
  String get profileLegalContentTitle => _string('profileLegalContentTitle');
  String get profileLegalOpenInBrowser => _string('profileLegalOpenInBrowser');
  String get profileLegalVersionUnknown =>
      _string('profileLegalVersionUnknown');
  String get profileLegalNoDocument => _string('profileLegalNoDocument');
  String get profileLegalUnavailable => _string('profileLegalUnavailable');
  String get profileLegalNoContent => _string('profileLegalNoContent');
  String get profileSupportTitle => _string('profileSupportTitle');
  String get profileSupportSubtitle => _string('profileSupportSubtitle');
  String get supportChatConnectedAgent => _string('supportChatConnectedAgent');
  String get supportChatAgentGreeting => _string('supportChatAgentGreeting');
  String get supportChatBotHandoff => _string('supportChatBotHandoff');
  String get supportChatBotDelivery => _string('supportChatBotDelivery');
  String get supportChatBotOrderStatus => _string('supportChatBotOrderStatus');
  String get supportChatBotFallback => _string('supportChatBotFallback');
  String get supportChatAgentRefund => _string('supportChatAgentRefund');
  String get supportChatAgentAddress => _string('supportChatAgentAddress');
  String get supportChatAgentFallback => _string('supportChatAgentFallback');
  String get profileGuidesTitle => _string('profileGuidesTitle');
  String get profileGuidesSubtitle => _string('profileGuidesSubtitle');
  String get profileHowtoTitle => _string('profileHowtoTitle');
  String get profileHowtoSubtitle => _string('profileHowtoSubtitle');
  String get profileLinkedAccountsTitle =>
      _string('profileLinkedAccountsTitle');
  String get profileLinkedAccountsSubtitle =>
      _string('profileLinkedAccountsSubtitle');
  String get profileLinkedAccountsHeader =>
      _string('profileLinkedAccountsHeader');
  String get profileLinkedAccountsAddTooltip =>
      _string('profileLinkedAccountsAddTooltip');
  String get profileLinkedAccountsLoadFailedTitle =>
      _string('profileLinkedAccountsLoadFailedTitle');
  String get profileLinkedAccountsSignedOutTitle =>
      _string('profileLinkedAccountsSignedOutTitle');
  String get profileLinkedAccountsSignedOutBody =>
      _string('profileLinkedAccountsSignedOutBody');
  String get profileLinkedAccountsSignIn =>
      _string('profileLinkedAccountsSignIn');
  String get profileLinkedAccountsBannerTitle =>
      _string('profileLinkedAccountsBannerTitle');
  String get profileLinkedAccountsBannerBody =>
      _string('profileLinkedAccountsBannerBody');
  String get profileLinkedAccountsBannerBodyLong =>
      _string('profileLinkedAccountsBannerBodyLong');
  String get profileLinkedAccountsBannerAction =>
      _string('profileLinkedAccountsBannerAction');
  String get profileLinkedAccountsConnected =>
      _string('profileLinkedAccountsConnected');
  String get profileLinkedAccountsNotConnected =>
      _string('profileLinkedAccountsNotConnected');
  String get profileLinkedAccountsProviderFallback =>
      _string('profileLinkedAccountsProviderFallback');
  String get profileLinkedAccountsAutoSignIn =>
      _string('profileLinkedAccountsAutoSignIn');
  String get profileLinkedAccountsNotConnectedHelper =>
      _string('profileLinkedAccountsNotConnectedHelper');
  String get profileLinkedAccountsUnlink =>
      _string('profileLinkedAccountsUnlink');
  String get profileLinkedAccountsUnlinkTitle =>
      _string('profileLinkedAccountsUnlinkTitle');
  String get profileLinkedAccountsUnlinkBody =>
      _string('profileLinkedAccountsUnlinkBody');
  String get profileLinkedAccountsUnlinkConfirm =>
      _string('profileLinkedAccountsUnlinkConfirm');
  String get profileLinkedAccountsCancel =>
      _string('profileLinkedAccountsCancel');
  String get profileLinkedAccountsUnlinkDisabled =>
      _string('profileLinkedAccountsUnlinkDisabled');
  String get profileLinkedAccountsSave => _string('profileLinkedAccountsSave');
  String get profileLinkedAccountsSaved =>
      _string('profileLinkedAccountsSaved');
  String get profileLinkedAccountsSaveFailed =>
      _string('profileLinkedAccountsSaveFailed');
  String get profileLinkedAccountsLinked =>
      _string('profileLinkedAccountsLinked');
  String get profileLinkedAccountsLinkFailed =>
      _string('profileLinkedAccountsLinkFailed');
  String get profileLinkedAccountsUnlinked =>
      _string('profileLinkedAccountsUnlinked');
  String get profileLinkedAccountsUnlinkFailed =>
      _string('profileLinkedAccountsUnlinkFailed');
  String get profileLinkedAccountsLinkTitle =>
      _string('profileLinkedAccountsLinkTitle');
  String get profileLinkedAccountsLinkSubtitle =>
      _string('profileLinkedAccountsLinkSubtitle');
  String get profileLinkedAccountsAlreadyLinked =>
      _string('profileLinkedAccountsAlreadyLinked');
  String get profileLinkedAccountsFooter =>
      _string('profileLinkedAccountsFooter');
  String get profileLinkedAccountsOk => _string('profileLinkedAccountsOk');
  String get profileExportTitle => _string('profileExportTitle');
  String get profileExportSubtitle => _string('profileExportSubtitle');
  String get profileExportAppBarSubtitle =>
      _string('profileExportAppBarSubtitle');
  String get profileExportSummaryTitle => _string('profileExportSummaryTitle');
  String get profileExportSummaryBody => _string('profileExportSummaryBody');
  String get profileExportIncludeAssetsTitle =>
      _string('profileExportIncludeAssetsTitle');
  String get profileExportIncludeAssetsSubtitle =>
      _string('profileExportIncludeAssetsSubtitle');
  String get profileExportIncludeOrdersTitle =>
      _string('profileExportIncludeOrdersTitle');
  String get profileExportIncludeOrdersSubtitle =>
      _string('profileExportIncludeOrdersSubtitle');
  String get profileExportIncludeHistoryTitle =>
      _string('profileExportIncludeHistoryTitle');
  String get profileExportIncludeHistorySubtitle =>
      _string('profileExportIncludeHistorySubtitle');
  String get profileExportPermissionTitle =>
      _string('profileExportPermissionTitle');
  String get profileExportPermissionBody =>
      _string('profileExportPermissionBody');
  String get profileExportPermissionCta =>
      _string('profileExportPermissionCta');
  String get permissionsTitle => _string('permissionsTitle');
  String get permissionsSubtitle => _string('permissionsSubtitle');
  String get permissionsHeroTitle => _string('permissionsHeroTitle');
  String get permissionsHeroBody => _string('permissionsHeroBody');
  String get permissionsPersonaDomestic =>
      _string('permissionsPersonaDomestic');
  String get permissionsPersonaInternational =>
      _string('permissionsPersonaInternational');
  String get permissionsPhotosTitle => _string('permissionsPhotosTitle');
  String get permissionsPhotosBody => _string('permissionsPhotosBody');
  String get permissionsPhotosAssist1 => _string('permissionsPhotosAssist1');
  String get permissionsPhotosAssist2 => _string('permissionsPhotosAssist2');
  String get permissionsStorageTitle => _string('permissionsStorageTitle');
  String get permissionsStorageBody => _string('permissionsStorageBody');
  String get permissionsStorageAssist1 => _string('permissionsStorageAssist1');
  String get permissionsStorageAssist2 => _string('permissionsStorageAssist2');
  String get permissionsNotificationsTitle =>
      _string('permissionsNotificationsTitle');
  String get permissionsNotificationsBody =>
      _string('permissionsNotificationsBody');
  String get permissionsNotificationsAssist1 =>
      _string('permissionsNotificationsAssist1');
  String get permissionsNotificationsAssist2 =>
      _string('permissionsNotificationsAssist2');
  String get permissionsStatusGranted => _string('permissionsStatusGranted');
  String get permissionsStatusDenied => _string('permissionsStatusDenied');
  String get permissionsStatusRestricted =>
      _string('permissionsStatusRestricted');
  String get permissionsStatusUnknown => _string('permissionsStatusUnknown');
  String get permissionsFallbackPhotos => _string('permissionsFallbackPhotos');
  String get permissionsFallbackStorage =>
      _string('permissionsFallbackStorage');
  String get permissionsFallbackNotifications =>
      _string('permissionsFallbackNotifications');
  String get permissionsCtaGrantAll => _string('permissionsCtaGrantAll');
  String get permissionsCtaNotNow => _string('permissionsCtaNotNow');
  String get permissionsFooterPolicy => _string('permissionsFooterPolicy');
  String get permissionsItemActionAllow =>
      _string('permissionsItemActionAllow');
  String get profileExportStatusReadyTitle =>
      _string('profileExportStatusReadyTitle');
  String get profileExportStatusReadyBody =>
      _string('profileExportStatusReadyBody');
  String get profileExportStatusInProgressTitle =>
      _string('profileExportStatusInProgressTitle');
  String get profileExportStatusInProgressBody =>
      _string('profileExportStatusInProgressBody');
  String get profileExportStatusDoneTitle =>
      _string('profileExportStatusDoneTitle');
  String get profileExportStatusDoneBody =>
      _string('profileExportStatusDoneBody');
  String get profileExportCtaStart => _string('profileExportCtaStart');
  String get profileExportCtaHistory => _string('profileExportCtaHistory');
  String get profileExportHistoryTitle => _string('profileExportHistoryTitle');
  String get profileExportHistoryEmptyTitle =>
      _string('profileExportHistoryEmptyTitle');
  String get profileExportHistoryEmptyBody =>
      _string('profileExportHistoryEmptyBody');
  String get profileExportHistoryDownload =>
      _string('profileExportHistoryDownload');
  String get profileExportErrorTitle => _string('profileExportErrorTitle');
  String get profileExportErrorBody => _string('profileExportErrorBody');
  String get profileExportRetry => _string('profileExportRetry');
  String get profileExportTimeJustNow => _string('profileExportTimeJustNow');
  String get profileExportTimeCompactNow =>
      _string('profileExportTimeCompactNow');
  String get profileDeleteTitle => _string('profileDeleteTitle');
  String get profileDeleteSubtitle => _string('profileDeleteSubtitle');
  String get profileDeleteWarningTitle => _string('profileDeleteWarningTitle');
  String get profileDeleteWarningBody => _string('profileDeleteWarningBody');
  String get profileDeleteAcknowledgementTitle =>
      _string('profileDeleteAcknowledgementTitle');
  String get profileDeleteAckDataLossTitle =>
      _string('profileDeleteAckDataLossTitle');
  String get profileDeleteAckDataLossBody =>
      _string('profileDeleteAckDataLossBody');
  String get profileDeleteAckOrdersTitle =>
      _string('profileDeleteAckOrdersTitle');
  String get profileDeleteAckOrdersBody =>
      _string('profileDeleteAckOrdersBody');
  String get profileDeleteAckIrreversibleTitle =>
      _string('profileDeleteAckIrreversibleTitle');
  String get profileDeleteAckIrreversibleBody =>
      _string('profileDeleteAckIrreversibleBody');
  String get profileDeleteFooterNote => _string('profileDeleteFooterNote');
  String get profileDeleteCta => _string('profileDeleteCta');
  String get profileDeleteCancelCta => _string('profileDeleteCancelCta');
  String get profileDeleteConfirmTitle => _string('profileDeleteConfirmTitle');
  String get profileDeleteConfirmBody => _string('profileDeleteConfirmBody');
  String get profileDeleteConfirmAction =>
      _string('profileDeleteConfirmAction');
  String get profileDeleteConfirmCancel =>
      _string('profileDeleteConfirmCancel');
  String get profileDeleteSuccess => _string('profileDeleteSuccess');
  String get profileDeleteError => _string('profileDeleteError');
  String get profileDeleteErrorTitle => _string('profileDeleteErrorTitle');
  String get profileDeleteErrorBody => _string('profileDeleteErrorBody');
  String get profileDeleteRetry => _string('profileDeleteRetry');
  String get profileSignInCta => _string('profileSignInCta');
  String get profileAccountSecurityTitle =>
      _string('profileAccountSecurityTitle');
  String get profileAccountSecuritySubtitle =>
      _string('profileAccountSecuritySubtitle');
  String get profileAccountSecurityBody =>
      _string('profileAccountSecurityBody');
  String get appUpdateTitle => _string('appUpdateTitle');
  String get appUpdateCheckAgain => _string('appUpdateCheckAgain');
  String get appUpdateChecking => _string('appUpdateChecking');
  String get appUpdateVerifyFailedTitle =>
      _string('appUpdateVerifyFailedTitle');
  String get appUpdateRetry => _string('appUpdateRetry');
  String get appUpdateBannerRequired => _string('appUpdateBannerRequired');
  String get appUpdateBannerOptional => _string('appUpdateBannerOptional');
  String get appUpdateBannerAction => _string('appUpdateBannerAction');
  String get appUpdateCardRequiredTitle =>
      _string('appUpdateCardRequiredTitle');
  String get appUpdateCardOptionalTitle =>
      _string('appUpdateCardOptionalTitle');
  String get appUpdateNow => _string('appUpdateNow');
  String get appUpdateOpenStore => _string('appUpdateOpenStore');
  String get appUpdateContinue => _string('appUpdateContinue');
  String get appUpdateStoreUnavailable => _string('appUpdateStoreUnavailable');
  String get appUpdateStoreOpenFailed => _string('appUpdateStoreOpenFailed');
  String get appUpdateLater => _string('appUpdateLater');
  String get commonBack => _string('commonBack');
  String get commonRetry => _string('commonRetry');
  String get commonClose => _string('commonClose');
  String get commonSave => _string('commonSave');
  String get commonLearnMore => _string('commonLearnMore');
  String get commonLoadMore => _string('commonLoadMore');
  String get commonClear => _string('commonClear');
  String get commonLoadFailed => _string('commonLoadFailed');
  String get commonUnknown => _string('commonUnknown');
  String get offlineTitle => _string('offlineTitle');
  String get offlineMessage => _string('offlineMessage');
  String get offlineRetry => _string('offlineRetry');
  String get offlineOpenCachedLibrary => _string('offlineOpenCachedLibrary');
  String get offlineCacheHint => _string('offlineCacheHint');
  String get offlineLastSyncUnavailable =>
      _string('offlineLastSyncUnavailable');
  String get changelogTitle => _string('changelogTitle');
  String get changelogLatestReleaseTooltip =>
      _string('changelogLatestReleaseTooltip');
  String get changelogHighlightsTitle => _string('changelogHighlightsTitle');
  String get changelogAllUpdates => _string('changelogAllUpdates');
  String get changelogMajorOnly => _string('changelogMajorOnly');
  String get changelogUnableToLoad => _string('changelogUnableToLoad');
  String get changelogNoUpdatesTitle => _string('changelogNoUpdatesTitle');
  String get changelogNoUpdatesMessage => _string('changelogNoUpdatesMessage');
  String get changelogVersionHistoryTitle =>
      _string('changelogVersionHistoryTitle');
  String get changelogVersionHistorySubtitle =>
      _string('changelogVersionHistorySubtitle');
  String get searchHintText => _string('searchHintText');
  String get searchVoiceTooltip => _string('searchVoiceTooltip');
  String get searchVoiceComingSoon => _string('searchVoiceComingSoon');
  String get searchRecentTitle => _string('searchRecentTitle');
  String get searchSuggestionsTitle => _string('searchSuggestionsTitle');
  String get searchSuggestionsLoadFailed =>
      _string('searchSuggestionsLoadFailed');
  String get searchResultsErrorTitle => _string('searchResultsErrorTitle');
  String get searchResultsEmptyTitle => _string('searchResultsEmptyTitle');
  String get searchResultsEmptyMessage => _string('searchResultsEmptyMessage');
  String get homeTitle => _string('homeTitle');
  String get homeSearchTooltip => _string('homeSearchTooltip');
  String get homeNotificationsTooltip => _string('homeNotificationsTooltip');
  String get homeFeaturedTitle => _string('homeFeaturedTitle');
  String get homeFeaturedSubtitle => _string('homeFeaturedSubtitle');
  String get homeFeaturedEmpty => _string('homeFeaturedEmpty');
  String get homeRecentTitle => _string('homeRecentTitle');
  String get homeRecentSubtitle => _string('homeRecentSubtitle');
  String get homeRecentActionLabel => _string('homeRecentActionLabel');
  String get homeRecentEmpty => _string('homeRecentEmpty');
  String get homeRecommendedTitle => _string('homeRecommendedTitle');
  String get homeRecommendedSubtitle => _string('homeRecommendedSubtitle');
  String get homeRecommendedLoading => _string('homeRecommendedLoading');
  String get homeStatusDraft => _string('homeStatusDraft');
  String get homeStatusReady => _string('homeStatusReady');
  String get homeStatusOrdered => _string('homeStatusOrdered');
  String get homeStatusLocked => _string('homeStatusLocked');
  String get homeShapeRound => _string('homeShapeRound');
  String get homeShapeSquare => _string('homeShapeSquare');
  String get homeWritingTensho => _string('homeWritingTensho');
  String get homeWritingReisho => _string('homeWritingReisho');
  String get homeWritingKaisho => _string('homeWritingKaisho');
  String get homeWritingGyosho => _string('homeWritingGyosho');
  String get homeWritingKoentai => _string('homeWritingKoentai');
  String get homeWritingCustom => _string('homeWritingCustom');
  String get homeNameUnset => _string('homeNameUnset');
  String get homeDesignAiCheckDone => _string('homeDesignAiCheckDone');
  String get homeDesignAiCheckNotRun => _string('homeDesignAiCheckNotRun');
  String get homeTemplateApply => _string('homeTemplateApply');
  String get homeLoadFailed => _string('homeLoadFailed');
  String get topBarSearchLabel => _string('topBarSearchLabel');
  String get topBarSearchHint => _string('topBarSearchHint');
  String get topBarSearchTooltip => _string('topBarSearchTooltip');
  String get topBarHelpLabel => _string('topBarHelpLabel');
  String get topBarHelpHint => _string('topBarHelpHint');
  String get topBarHelpTooltip => _string('topBarHelpTooltip');
  String get topBarNotificationsLabel => _string('topBarNotificationsLabel');
  String get topBarNotificationsTooltip =>
      _string('topBarNotificationsTooltip');
  String get topBarHelpOverlayTitle => _string('topBarHelpOverlayTitle');
  String get topBarHelpOverlayPrimaryAction =>
      _string('topBarHelpOverlayPrimaryAction');
  String get topBarHelpOverlaySecondaryAction =>
      _string('topBarHelpOverlaySecondaryAction');
  String get topBarHelpOverlayBody => _string('topBarHelpOverlayBody');
  String get topBarShortcutSearchLabel => _string('topBarShortcutSearchLabel');
  String get topBarShortcutHelpLabel => _string('topBarShortcutHelpLabel');
  String get topBarShortcutNotificationsLabel =>
      _string('topBarShortcutNotificationsLabel');
  String get topBarHelpLinkFaqTitle => _string('topBarHelpLinkFaqTitle');
  String get topBarHelpLinkFaqSubtitle => _string('topBarHelpLinkFaqSubtitle');
  String get topBarHelpLinkChatTitle => _string('topBarHelpLinkChatTitle');
  String get topBarHelpLinkChatSubtitle =>
      _string('topBarHelpLinkChatSubtitle');
  String get topBarHelpLinkContactTitle =>
      _string('topBarHelpLinkContactTitle');
  String get topBarHelpLinkContactSubtitle =>
      _string('topBarHelpLinkContactSubtitle');
  String get splashLoading => _string('splashLoading');
  String get splashFailedTitle => _string('splashFailedTitle');
  String get splashFailedMessage => _string('splashFailedMessage');
  String get designVersionsTitle => _string('designVersionsTitle');
  String get designVersionsShowDiffTooltip =>
      _string('designVersionsShowDiffTooltip');
  String get designVersionsSecondaryDuplicate =>
      _string('designVersionsSecondaryDuplicate');
  String get designVersionsTimelineTitle =>
      _string('designVersionsTimelineTitle');
  String get designVersionsRefreshTooltip =>
      _string('designVersionsRefreshTooltip');
  String get designVersionsAuditLogTitle =>
      _string('designVersionsAuditLogTitle');
  String get designVersionsNoAuditTitle =>
      _string('designVersionsNoAuditTitle');
  String get designVersionsNoAuditMessage =>
      _string('designVersionsNoAuditMessage');
  String get designVersionsRollbackAction =>
      _string('designVersionsRollbackAction');
  String get designVersionsRollbackCancel =>
      _string('designVersionsRollbackCancel');
  String get designVersionsNoDiffSummary =>
      _string('designVersionsNoDiffSummary');
  String get designVersionsLatestLabel => _string('designVersionsLatestLabel');
  String get designVersionsRollbackButton =>
      _string('designVersionsRollbackButton');
  String get designVersionsPreviewCurrent =>
      _string('designVersionsPreviewCurrent');
  String get designVersionsPreviewTarget =>
      _string('designVersionsPreviewTarget');
  String get designVersionsInitialFallback =>
      _string('designVersionsInitialFallback');
  String get designVersionsUnset => _string('designVersionsUnset');
  String get designVersionsAutoLayout => _string('designVersionsAutoLayout');
  String get designVersionsNoDiffTitle => _string('designVersionsNoDiffTitle');
  String get designVersionsNoDiffMessage =>
      _string('designVersionsNoDiffMessage');
  String get designVersionsChangeHistoryEmpty =>
      _string('designVersionsChangeHistoryEmpty');
  String get designVersionsStatusCurrent =>
      _string('designVersionsStatusCurrent');
  String get designVersionsStatusComparing =>
      _string('designVersionsStatusComparing');
  String get designVersionsStatusHistory =>
      _string('designVersionsStatusHistory');
  String get designVersionsLoadFailedTitle =>
      _string('designVersionsLoadFailedTitle');
  String get designVersionsSimilarityLabel =>
      _string('designVersionsSimilarityLabel');
  String get checkoutPaymentTitle => _string('checkoutPaymentTitle');
  String get checkoutPaymentAddTooltip => _string('checkoutPaymentAddTooltip');
  String get checkoutPaymentLoadFailedTitle =>
      _string('checkoutPaymentLoadFailedTitle');
  String get checkoutPaymentEmptyTitle => _string('checkoutPaymentEmptyTitle');
  String get checkoutPaymentEmptyBody => _string('checkoutPaymentEmptyBody');
  String get checkoutPaymentSignInHint => _string('checkoutPaymentSignInHint');
  String get checkoutPaymentAddMethod => _string('checkoutPaymentAddMethod');
  String get checkoutPaymentChooseSaved =>
      _string('checkoutPaymentChooseSaved');
  String get checkoutPaymentAddAnother => _string('checkoutPaymentAddAnother');
  String get checkoutPaymentContinueReview =>
      _string('checkoutPaymentContinueReview');
  String get checkoutPaymentAddFailed => _string('checkoutPaymentAddFailed');
  String get checkoutPaymentMethodCard => _string('checkoutPaymentMethodCard');
  String get checkoutPaymentMethodWallet =>
      _string('checkoutPaymentMethodWallet');
  String get checkoutPaymentMethodBank => _string('checkoutPaymentMethodBank');
  String get checkoutPaymentMethodFallback =>
      _string('checkoutPaymentMethodFallback');
  String get cartPromoEnterCode => _string('cartPromoEnterCode');
  String get cartPromoAddItemsRequired => _string('cartPromoAddItemsRequired');
  String get cartPromoField10Label => _string('cartPromoField10Label');
  String get cartPromoField10Description =>
      _string('cartPromoField10Description');
  String get cartPromoShipfreeLabel => _string('cartPromoShipfreeLabel');
  String get cartPromoInkLabel => _string('cartPromoInkLabel');
  String get cartPromoInkDescription => _string('cartPromoInkDescription');
  String get cartPromoInvalid => _string('cartPromoInvalid');
  String get cartLineTitaniumTitle => _string('cartLineTitaniumTitle');
  String get cartLineTitaniumVariant => _string('cartLineTitaniumVariant');
  String get cartLineTitaniumDesign => _string('cartLineTitaniumDesign');
  String get cartLineTitaniumAddonSleeveLabel =>
      _string('cartLineTitaniumAddonSleeveLabel');
  String get cartLineTitaniumAddonSleeveDescription =>
      _string('cartLineTitaniumAddonSleeveDescription');
  String get cartLineTitaniumAddonSleeveBadge =>
      _string('cartLineTitaniumAddonSleeveBadge');
  String get cartLineTitaniumAddonDeepLabel =>
      _string('cartLineTitaniumAddonDeepLabel');
  String get cartLineTitaniumAddonDeepDescription =>
      _string('cartLineTitaniumAddonDeepDescription');
  String get cartLineTitaniumAddonWrapLabel =>
      _string('cartLineTitaniumAddonWrapLabel');
  String get cartLineTitaniumAddonWrapDescription =>
      _string('cartLineTitaniumAddonWrapDescription');
  String get cartLineTitaniumNoteIntl => _string('cartLineTitaniumNoteIntl');
  String get cartLineTitaniumNoteDomestic =>
      _string('cartLineTitaniumNoteDomestic');
  String get cartLineTitaniumRibbon => _string('cartLineTitaniumRibbon');
  String get cartLineAcrylicTitle => _string('cartLineAcrylicTitle');
  String get cartLineAcrylicVariant => _string('cartLineAcrylicVariant');
  String get cartLineAcrylicDesign => _string('cartLineAcrylicDesign');
  String get cartLineAcrylicAddonUvLabel =>
      _string('cartLineAcrylicAddonUvLabel');
  String get cartLineAcrylicAddonUvDescription =>
      _string('cartLineAcrylicAddonUvDescription');
  String get cartLineAcrylicAddonUvBadge =>
      _string('cartLineAcrylicAddonUvBadge');
  String get cartLineAcrylicAddonInkLabel =>
      _string('cartLineAcrylicAddonInkLabel');
  String get cartLineAcrylicAddonInkDescription =>
      _string('cartLineAcrylicAddonInkDescription');
  String get cartLineAcrylicAddonPouchLabel =>
      _string('cartLineAcrylicAddonPouchLabel');
  String get cartLineAcrylicAddonPouchDescription =>
      _string('cartLineAcrylicAddonPouchDescription');
  String get cartLineAcrylicNote => _string('cartLineAcrylicNote');
  String get cartLineAcrylicRibbonIntl => _string('cartLineAcrylicRibbonIntl');
  String get cartLineAcrylicRibbon => _string('cartLineAcrylicRibbon');
  String get cartLineBoxTitle => _string('cartLineBoxTitle');
  String get cartLineBoxVariant => _string('cartLineBoxVariant');
  String get cartLineBoxDesign => _string('cartLineBoxDesign');
  String get cartLineBoxAddonFoamLabel => _string('cartLineBoxAddonFoamLabel');
  String get cartLineBoxAddonFoamDescription =>
      _string('cartLineBoxAddonFoamDescription');
  String get cartLineBoxAddonCardLabel => _string('cartLineBoxAddonCardLabel');
  String get cartLineBoxAddonCardDescription =>
      _string('cartLineBoxAddonCardDescription');
  String get cartLineBoxAddonWrapLabel => _string('cartLineBoxAddonWrapLabel');
  String get cartLineBoxAddonWrapDescription =>
      _string('cartLineBoxAddonWrapDescription');
  String get cartLineBoxNoteIntl => _string('cartLineBoxNoteIntl');
  String get cartLineBoxNoteDomestic => _string('cartLineBoxNoteDomestic');
  String get cartLineBoxRibbon => _string('cartLineBoxRibbon');
  String get cartEstimateMethodIntl => _string('cartEstimateMethodIntl');
  String get cartEstimateMethodDomestic =>
      _string('cartEstimateMethodDomestic');
  String get cartEstimateMethodIntlPriority =>
      _string('cartEstimateMethodIntlPriority');
  String get cartEstimateMethodStandard =>
      _string('cartEstimateMethodStandard');
  String get cartTitle => _string('cartTitle');
  String get cartBulkEditTooltip => _string('cartBulkEditTooltip');
  String get cartLoadFailedTitle => _string('cartLoadFailedTitle');
  String get cartEmptyTitle => _string('cartEmptyTitle');
  String get cartEmptyMessage => _string('cartEmptyMessage');
  String get cartEmptyAction => _string('cartEmptyAction');
  String get cartUndo => _string('cartUndo');
  String get cartEditOptionsTitle => _string('cartEditOptionsTitle');
  String get cartAddonIncluded => _string('cartAddonIncluded');
  String get cartReset => _string('cartReset');
  String get cartSave => _string('cartSave');
  String get cartBulkActionsTitle => _string('cartBulkActionsTitle');
  String get cartBulkActionsBody => _string('cartBulkActionsBody');
  String get cartBulkActionApplyField10 =>
      _string('cartBulkActionApplyField10');
  String get cartBulkActionShipfree => _string('cartBulkActionShipfree');
  String get cartBulkActionClearSelections =>
      _string('cartBulkActionClearSelections');
  String get cartUnitPerItem => _string('cartUnitPerItem');
  String get cartEditOptionsAction => _string('cartEditOptionsAction');
  String get cartRemoveAction => _string('cartRemoveAction');
  String get cartLineTotalLabel => _string('cartLineTotalLabel');
  String get cartPromoTitle => _string('cartPromoTitle');
  String get cartPromoFieldLabel => _string('cartPromoFieldLabel');
  String get cartPromoApplyLabel => _string('cartPromoApplyLabel');
  String get cartPromoAppliedFallback => _string('cartPromoAppliedFallback');
  String get cartPromoMockHint => _string('cartPromoMockHint');
  String get cartSummaryTitle => _string('cartSummaryTitle');
  String get cartSummarySubtotal => _string('cartSummarySubtotal');
  String get cartSummaryDiscount => _string('cartSummaryDiscount');
  String get cartSummaryShipping => _string('cartSummaryShipping');
  String get cartSummaryFree => _string('cartSummaryFree');
  String get cartSummaryTax => _string('cartSummaryTax');
  String get cartSummaryTotal => _string('cartSummaryTotal');
  String get cartProceedCheckout => _string('cartProceedCheckout');
  String get checkoutAddressTitle => _string('checkoutAddressTitle');
  String get checkoutAddressAddTooltip => _string('checkoutAddressAddTooltip');
  String get checkoutAddressLoadFailedTitle =>
      _string('checkoutAddressLoadFailedTitle');
  String get checkoutAddressEmptyTitle => _string('checkoutAddressEmptyTitle');
  String get checkoutAddressEmptyMessage =>
      _string('checkoutAddressEmptyMessage');
  String get checkoutAddressAddAction => _string('checkoutAddressAddAction');
  String get checkoutAddressChooseHint => _string('checkoutAddressChooseHint');
  String get checkoutAddressAddAnother => _string('checkoutAddressAddAnother');
  String get checkoutAddressContinueShipping =>
      _string('checkoutAddressContinueShipping');
  String get checkoutAddressSelectRequired =>
      _string('checkoutAddressSelectRequired');
  String get checkoutAddressSavedCreated =>
      _string('checkoutAddressSavedCreated');
  String get checkoutAddressSavedUpdated =>
      _string('checkoutAddressSavedUpdated');
  String get checkoutAddressChipShipping =>
      _string('checkoutAddressChipShipping');
  String get checkoutAddressChipDefault =>
      _string('checkoutAddressChipDefault');
  String get checkoutAddressChipBilling =>
      _string('checkoutAddressChipBilling');
  String get checkoutAddressChipInternational =>
      _string('checkoutAddressChipInternational');
  String get checkoutAddressLabelFallback =>
      _string('checkoutAddressLabelFallback');
  String get checkoutAddressEditAction => _string('checkoutAddressEditAction');
  String get checkoutAddressPersonaDomesticHint =>
      _string('checkoutAddressPersonaDomesticHint');
  String get checkoutAddressPersonaInternationalHint =>
      _string('checkoutAddressPersonaInternationalHint');
  String get checkoutAddressFormAddTitle =>
      _string('checkoutAddressFormAddTitle');
  String get checkoutAddressFormEditTitle =>
      _string('checkoutAddressFormEditTitle');
  String get checkoutAddressFormDomesticLabel =>
      _string('checkoutAddressFormDomesticLabel');
  String get checkoutAddressFormInternationalLabel =>
      _string('checkoutAddressFormInternationalLabel');
  String get checkoutAddressFormLabelOptional =>
      _string('checkoutAddressFormLabelOptional');
  String get checkoutAddressFormRecipient =>
      _string('checkoutAddressFormRecipient');
  String get checkoutAddressFormCompanyOptional =>
      _string('checkoutAddressFormCompanyOptional');
  String get checkoutAddressFormPostalCode =>
      _string('checkoutAddressFormPostalCode');
  String get checkoutAddressFormLookup => _string('checkoutAddressFormLookup');
  String get checkoutAddressFormState => _string('checkoutAddressFormState');
  String get checkoutAddressFormCity => _string('checkoutAddressFormCity');
  String get checkoutAddressFormLine1 => _string('checkoutAddressFormLine1');
  String get checkoutAddressFormLine2Optional =>
      _string('checkoutAddressFormLine2Optional');
  String get checkoutAddressFormCountry =>
      _string('checkoutAddressFormCountry');
  String get checkoutAddressFormPhone => _string('checkoutAddressFormPhone');
  String get checkoutAddressFormDefaultTitle =>
      _string('checkoutAddressFormDefaultTitle');
  String get checkoutAddressFormDefaultSubtitle =>
      _string('checkoutAddressFormDefaultSubtitle');
  String get checkoutAddressFormSave => _string('checkoutAddressFormSave');
  String get checkoutAddressFormFixErrors =>
      _string('checkoutAddressFormFixErrors');
  String get checkoutAddressRequired => _string('checkoutAddressRequired');
  String get checkoutAddressRecipientRequired =>
      _string('checkoutAddressRecipientRequired');
  String get checkoutAddressLine1Required =>
      _string('checkoutAddressLine1Required');
  String get checkoutAddressCityRequired =>
      _string('checkoutAddressCityRequired');
  String get checkoutAddressPostalFormat =>
      _string('checkoutAddressPostalFormat');
  String get checkoutAddressStateRequired =>
      _string('checkoutAddressStateRequired');
  String get checkoutAddressCountryJapanRequired =>
      _string('checkoutAddressCountryJapanRequired');
  String get checkoutAddressPhoneDomestic =>
      _string('checkoutAddressPhoneDomestic');
  String get checkoutAddressPostalShort =>
      _string('checkoutAddressPostalShort');
  String get checkoutAddressCountryRequired =>
      _string('checkoutAddressCountryRequired');
  String get checkoutAddressPhoneInternational =>
      _string('checkoutAddressPhoneInternational');
  String get checkoutShippingMissingState =>
      _string('checkoutShippingMissingState');
  String get checkoutShippingSelectAddress =>
      _string('checkoutShippingSelectAddress');
  String get checkoutShippingOptionUnavailable =>
      _string('checkoutShippingOptionUnavailable');
  String get checkoutShippingPromoRequiresExpress =>
      _string('checkoutShippingPromoRequiresExpress');
  String get checkoutShippingBadgePopular =>
      _string('checkoutShippingBadgePopular');
  String get checkoutShippingBadgeFastest =>
      _string('checkoutShippingBadgeFastest');
  String get checkoutShippingBadgeTracked =>
      _string('checkoutShippingBadgeTracked');
  String get checkoutShippingOptionDomStandardLabel =>
      _string('checkoutShippingOptionDomStandardLabel');
  String get checkoutShippingOptionDomStandardCarrier =>
      _string('checkoutShippingOptionDomStandardCarrier');
  String get checkoutShippingOptionDomStandardNote =>
      _string('checkoutShippingOptionDomStandardNote');
  String get checkoutShippingOptionDomExpressLabel =>
      _string('checkoutShippingOptionDomExpressLabel');
  String get checkoutShippingOptionDomExpressCarrier =>
      _string('checkoutShippingOptionDomExpressCarrier');
  String get checkoutShippingOptionDomExpressNote =>
      _string('checkoutShippingOptionDomExpressNote');
  String get checkoutShippingOptionDomPickupLabel =>
      _string('checkoutShippingOptionDomPickupLabel');
  String get checkoutShippingOptionDomPickupCarrier =>
      _string('checkoutShippingOptionDomPickupCarrier');
  String get checkoutShippingOptionDomPickupNote =>
      _string('checkoutShippingOptionDomPickupNote');
  String get checkoutShippingOptionIntlExpressLabel =>
      _string('checkoutShippingOptionIntlExpressLabel');
  String get checkoutShippingOptionIntlExpressCarrier =>
      _string('checkoutShippingOptionIntlExpressCarrier');
  String get checkoutShippingOptionIntlExpressNote =>
      _string('checkoutShippingOptionIntlExpressNote');
  String get checkoutShippingOptionIntlPriorityLabel =>
      _string('checkoutShippingOptionIntlPriorityLabel');
  String get checkoutShippingOptionIntlPriorityCarrier =>
      _string('checkoutShippingOptionIntlPriorityCarrier');
  String get checkoutShippingOptionIntlPriorityNote =>
      _string('checkoutShippingOptionIntlPriorityNote');
  String get checkoutShippingOptionIntlEconomyLabel =>
      _string('checkoutShippingOptionIntlEconomyLabel');
  String get checkoutShippingOptionIntlEconomyCarrier =>
      _string('checkoutShippingOptionIntlEconomyCarrier');
  String get checkoutShippingOptionIntlEconomyNote =>
      _string('checkoutShippingOptionIntlEconomyNote');
  String get checkoutShippingBannerInternationalDelay =>
      _string('checkoutShippingBannerInternationalDelay');
  String get checkoutShippingBannerKyushuDelay =>
      _string('checkoutShippingBannerKyushuDelay');
  String get shopTitle => _string('shopTitle');
  String get shopSearchTooltip => _string('shopSearchTooltip');
  String get shopCartTooltip => _string('shopCartTooltip');
  String get shopAppBarSubtitle => _string('shopAppBarSubtitle');
  String get shopActionPromotions => _string('shopActionPromotions');
  String get shopActionGuides => _string('shopActionGuides');
  String get shopQuickGuidesTitle => _string('shopQuickGuidesTitle');
  String get shopQuickGuidesSubtitle => _string('shopQuickGuidesSubtitle');
  String get shopBrowseByMaterialTitle => _string('shopBrowseByMaterialTitle');
  String get shopBrowseByMaterialSubtitle =>
      _string('shopBrowseByMaterialSubtitle');
  String get shopPromotionsTitle => _string('shopPromotionsTitle');
  String get shopPromotionsSubtitle => _string('shopPromotionsSubtitle');
  String get shopPromotionsEmpty => _string('shopPromotionsEmpty');
  String get shopRecommendedMaterialsTitle =>
      _string('shopRecommendedMaterialsTitle');
  String get shopRecommendedMaterialsSubtitle =>
      _string('shopRecommendedMaterialsSubtitle');
  String get shopRecommendedMaterialsEmpty =>
      _string('shopRecommendedMaterialsEmpty');
  String get shopHeroBadge => _string('shopHeroBadge');
  String get shopHeroTitle => _string('shopHeroTitle');
  String get shopHeroBody => _string('shopHeroBody');
  String get shopHeroAction => _string('shopHeroAction');
  String get libraryDesignDetailTitle => _string('libraryDesignDetailTitle');
  String get libraryDesignDetailSubtitle =>
      _string('libraryDesignDetailSubtitle');
  String get libraryDesignDetailEditTooltip =>
      _string('libraryDesignDetailEditTooltip');
  String get libraryDesignDetailExportTooltip =>
      _string('libraryDesignDetailExportTooltip');
  String get libraryDesignDetailTabDetails =>
      _string('libraryDesignDetailTabDetails');
  String get libraryDesignDetailTabActivity =>
      _string('libraryDesignDetailTabActivity');
  String get libraryDesignDetailTabFiles =>
      _string('libraryDesignDetailTabFiles');
  String get libraryDesignDetailMetadataTitle =>
      _string('libraryDesignDetailMetadataTitle');
  String get libraryDesignDetailUsageHistoryTitle =>
      _string('libraryDesignDetailUsageHistoryTitle');
  String get libraryDesignDetailNoActivity =>
      _string('libraryDesignDetailNoActivity');
  String get libraryDesignDetailFilesTitle =>
      _string('libraryDesignDetailFilesTitle');
  String get libraryDesignDetailPreviewPngLabel =>
      _string('libraryDesignDetailPreviewPngLabel');
  String get libraryDesignDetailVectorSvgLabel =>
      _string('libraryDesignDetailVectorSvgLabel');
  String get libraryDesignDetailExportAction =>
      _string('libraryDesignDetailExportAction');
  String get libraryDesignDetailUntitled =>
      _string('libraryDesignDetailUntitled');
  String get libraryDesignDetailAiScoreUnknown =>
      _string('libraryDesignDetailAiScoreUnknown');
  String get libraryDesignDetailRegistrabilityUnknown =>
      _string('libraryDesignDetailRegistrabilityUnknown');
  String get libraryDesignDetailRegistrable =>
      _string('libraryDesignDetailRegistrable');
  String get libraryDesignDetailNotRegistrable =>
      _string('libraryDesignDetailNotRegistrable');
  String get libraryDesignDetailActionVersions =>
      _string('libraryDesignDetailActionVersions');
  String get libraryDesignDetailActionShare =>
      _string('libraryDesignDetailActionShare');
  String get libraryDesignDetailActionLinks =>
      _string('libraryDesignDetailActionLinks');
  String get libraryDesignDetailActionDuplicate =>
      _string('libraryDesignDetailActionDuplicate');
  String get libraryDesignDetailActionReorder =>
      _string('libraryDesignDetailActionReorder');
  String get libraryDesignDetailActionArchive =>
      _string('libraryDesignDetailActionArchive');
  String get libraryDesignDetailArchiveTitle =>
      _string('libraryDesignDetailArchiveTitle');
  String get libraryDesignDetailArchiveBody =>
      _string('libraryDesignDetailArchiveBody');
  String get libraryDesignDetailArchiveCancel =>
      _string('libraryDesignDetailArchiveCancel');
  String get libraryDesignDetailArchiveConfirm =>
      _string('libraryDesignDetailArchiveConfirm');
  String get libraryDesignDetailArchived =>
      _string('libraryDesignDetailArchived');
  String get libraryDesignDetailReorderHint =>
      _string('libraryDesignDetailReorderHint');
  String get libraryDesignDetailFileNotAvailable =>
      _string('libraryDesignDetailFileNotAvailable');
  String get libraryDesignDetailMetadataDesignId =>
      _string('libraryDesignDetailMetadataDesignId');
  String get libraryDesignDetailMetadataStatus =>
      _string('libraryDesignDetailMetadataStatus');
  String get libraryDesignDetailMetadataAiScore =>
      _string('libraryDesignDetailMetadataAiScore');
  String get libraryDesignDetailMetadataRegistrability =>
      _string('libraryDesignDetailMetadataRegistrability');
  String get libraryDesignDetailMetadataCreated =>
      _string('libraryDesignDetailMetadataCreated');
  String get libraryDesignDetailMetadataUpdated =>
      _string('libraryDesignDetailMetadataUpdated');
  String get libraryDesignDetailMetadataLastUsed =>
      _string('libraryDesignDetailMetadataLastUsed');
  String get libraryDesignDetailMetadataVersion =>
      _string('libraryDesignDetailMetadataVersion');
  String get libraryDesignDetailActivityCreatedTitle =>
      _string('libraryDesignDetailActivityCreatedTitle');
  String get libraryDesignDetailActivityUpdatedTitle =>
      _string('libraryDesignDetailActivityUpdatedTitle');
  String get libraryDesignDetailActivityOrderedTitle =>
      _string('libraryDesignDetailActivityOrderedTitle');
  String get libraryDesignDetailActivityCreatedDetail =>
      _string('libraryDesignDetailActivityCreatedDetail');
  String get libraryDesignDetailActivityUpdatedDetail =>
      _string('libraryDesignDetailActivityUpdatedDetail');
  String get libraryDesignDetailActivityOrderedDetail =>
      _string('libraryDesignDetailActivityOrderedDetail');
  String get orderDetailTitleFallback => _string('orderDetailTitleFallback');
  String get orderDetailTooltipReorder => _string('orderDetailTooltipReorder');
  String get orderDetailTooltipShare => _string('orderDetailTooltipShare');
  String get orderDetailTooltipMore => _string('orderDetailTooltipMore');
  String get orderDetailMenuContactSupport =>
      _string('orderDetailMenuContactSupport');
  String get orderDetailMenuCancelOrder =>
      _string('orderDetailMenuCancelOrder');
  String get orderDetailTabSummary => _string('orderDetailTabSummary');
  String get orderDetailTabTimeline => _string('orderDetailTabTimeline');
  String get orderDetailTabFiles => _string('orderDetailTabFiles');
  String get orderDetailInvoiceRequestSent =>
      _string('orderDetailInvoiceRequestSent');
  String get orderDetailInvoiceRequestFailed =>
      _string('orderDetailInvoiceRequestFailed');
  String get orderDetailCancelTitle => _string('orderDetailCancelTitle');
  String get orderDetailCancelBody => _string('orderDetailCancelBody');
  String get orderDetailCancelConfirm => _string('orderDetailCancelConfirm');
  String get orderDetailCancelKeep => _string('orderDetailCancelKeep');
  String get orderDetailCancelSuccess => _string('orderDetailCancelSuccess');
  String get orderDetailCancelFailed => _string('orderDetailCancelFailed');
  String get orderDetailDesignPreviewOk =>
      _string('orderDetailDesignPreviewOk');
  String get orderDetailBannerInProgress =>
      _string('orderDetailBannerInProgress');
  String get orderDetailBannerProduction =>
      _string('orderDetailBannerProduction');
  String get orderDetailBannerTracking => _string('orderDetailBannerTracking');
  String get orderDetailSectionOrder => _string('orderDetailSectionOrder');
  String get orderDetailSectionItems => _string('orderDetailSectionItems');
  String get orderDetailSectionTotal => _string('orderDetailSectionTotal');
  String get orderDetailSubtotal => _string('orderDetailSubtotal');
  String get orderDetailDiscount => _string('orderDetailDiscount');
  String get orderDetailShipping => _string('orderDetailShipping');
  String get orderDetailShippingFree => _string('orderDetailShippingFree');
  String get orderDetailTax => _string('orderDetailTax');
  String get orderDetailTotal => _string('orderDetailTotal');
  String get orderDetailShippingAddress =>
      _string('orderDetailShippingAddress');
  String get orderDetailBillingAddress => _string('orderDetailBillingAddress');
  String get orderDetailPayment => _string('orderDetailPayment');
  String get orderDetailDesignSnapshots =>
      _string('orderDetailDesignSnapshots');
  String get orderDetailQuickActions => _string('orderDetailQuickActions');
  String get orderDetailRequestInvoice => _string('orderDetailRequestInvoice');
  String get orderDetailContactSupport => _string('orderDetailContactSupport');
  String get orderDetailTimelineTitle => _string('orderDetailTimelineTitle');
  String get orderDetailProductionEvents =>
      _string('orderDetailProductionEvents');
  String get orderDetailInvoiceTitle => _string('orderDetailInvoiceTitle');
  String get orderDetailInvoiceHint => _string('orderDetailInvoiceHint');
  String get orderDetailInvoiceRequest => _string('orderDetailInvoiceRequest');
  String get orderDetailInvoiceView => _string('orderDetailInvoiceView');
  String get orderDetailPaymentPending => _string('orderDetailPaymentPending');
  String get orderDetailPaymentPaid => _string('orderDetailPaymentPaid');
  String get orderDetailPaymentCanceled =>
      _string('orderDetailPaymentCanceled');
  String get orderDetailPaymentProcessing =>
      _string('orderDetailPaymentProcessing');
  String get orderDetailPaymentNoInfo => _string('orderDetailPaymentNoInfo');
  String get orderDetailPaymentMethodCard =>
      _string('orderDetailPaymentMethodCard');
  String get orderDetailPaymentMethodWallet =>
      _string('orderDetailPaymentMethodWallet');
  String get orderDetailPaymentMethodBank =>
      _string('orderDetailPaymentMethodBank');
  String get orderDetailPaymentMethodOther =>
      _string('orderDetailPaymentMethodOther');
  String get orderDetailPaymentSeparator =>
      _string('orderDetailPaymentSeparator');
  String get orderDetailStatusPending => _string('orderDetailStatusPending');
  String get orderDetailStatusPaid => _string('orderDetailStatusPaid');
  String get orderDetailStatusInProduction =>
      _string('orderDetailStatusInProduction');
  String get orderDetailStatusReadyToShip =>
      _string('orderDetailStatusReadyToShip');
  String get orderDetailStatusShipped => _string('orderDetailStatusShipped');
  String get orderDetailStatusDelivered =>
      _string('orderDetailStatusDelivered');
  String get orderDetailStatusCanceled => _string('orderDetailStatusCanceled');
  String get orderDetailStatusProcessing =>
      _string('orderDetailStatusProcessing');
  String get orderDetailMilestonePlaced =>
      _string('orderDetailMilestonePlaced');
  String get orderDetailMilestonePaid => _string('orderDetailMilestonePaid');
  String get orderDetailMilestoneProduction =>
      _string('orderDetailMilestoneProduction');
  String get orderDetailMilestoneShipped =>
      _string('orderDetailMilestoneShipped');
  String get orderDetailMilestoneDelivered =>
      _string('orderDetailMilestoneDelivered');
  String get orderDetailMilestoneCanceled =>
      _string('orderDetailMilestoneCanceled');
  String get kanjiDictionaryTitle => _string('kanjiDictionaryTitle');
  String get kanjiDictionaryToggleShowAll =>
      _string('kanjiDictionaryToggleShowAll');
  String get kanjiDictionaryToggleShowFavorites =>
      _string('kanjiDictionaryToggleShowFavorites');
  String get kanjiDictionaryOpenGuides => _string('kanjiDictionaryOpenGuides');
  String get kanjiDictionarySearchHint => _string('kanjiDictionarySearchHint');
  String get kanjiDictionaryHistoryHint =>
      _string('kanjiDictionaryHistoryHint');
  String get kanjiDictionaryHistoryTitle =>
      _string('kanjiDictionaryHistoryTitle');
  String get kanjiDictionaryFiltersTitle =>
      _string('kanjiDictionaryFiltersTitle');
  String get kanjiDictionaryGradesAll => _string('kanjiDictionaryGradesAll');
  String get kanjiDictionaryGrade1 => _string('kanjiDictionaryGrade1');
  String get kanjiDictionaryGrade2 => _string('kanjiDictionaryGrade2');
  String get kanjiDictionaryGrade3 => _string('kanjiDictionaryGrade3');
  String get kanjiDictionaryGrade4 => _string('kanjiDictionaryGrade4');
  String get kanjiDictionaryGrade5 => _string('kanjiDictionaryGrade5');
  String get kanjiDictionaryGrade6 => _string('kanjiDictionaryGrade6');
  String get kanjiDictionaryStrokesAll => _string('kanjiDictionaryStrokesAll');
  String get kanjiDictionaryRadicalAny => _string('kanjiDictionaryRadicalAny');
  String get kanjiDictionaryRadicalWater =>
      _string('kanjiDictionaryRadicalWater');
  String get kanjiDictionaryRadicalSun => _string('kanjiDictionaryRadicalSun');
  String get kanjiDictionaryRadicalPlant =>
      _string('kanjiDictionaryRadicalPlant');
  String get kanjiDictionaryRadicalHeart =>
      _string('kanjiDictionaryRadicalHeart');
  String get kanjiDictionaryRadicalEarth =>
      _string('kanjiDictionaryRadicalEarth');
  String get kanjiDictionaryFavorite => _string('kanjiDictionaryFavorite');
  String get kanjiDictionaryUnfavorite => _string('kanjiDictionaryUnfavorite');
  String get kanjiDictionaryDetails => _string('kanjiDictionaryDetails');
  String get kanjiDictionaryStrokeOrderTitle =>
      _string('kanjiDictionaryStrokeOrderTitle');
  String get kanjiDictionaryExamplesTitle =>
      _string('kanjiDictionaryExamplesTitle');
  String get kanjiDictionaryInsertIntoNameInput =>
      _string('kanjiDictionaryInsertIntoNameInput');
  String get kanjiDictionaryDone => _string('kanjiDictionaryDone');
  String get kanjiDictionaryExampleUsage =>
      _string('kanjiDictionaryExampleUsage');
  String get kanjiDictionaryNoStrokeData =>
      _string('kanjiDictionaryNoStrokeData');
  String get orderInvoiceTitle => _string('orderInvoiceTitle');
  String get orderInvoiceShareTooltip => _string('orderInvoiceShareTooltip');
  String get orderInvoiceLoadFailed => _string('orderInvoiceLoadFailed');
  String get orderInvoiceDownloadPdf => _string('orderInvoiceDownloadPdf');
  String get orderInvoiceSendEmail => _string('orderInvoiceSendEmail');
  String get orderInvoiceContactSupport =>
      _string('orderInvoiceContactSupport');
  String get orderInvoiceTotalLabel => _string('orderInvoiceTotalLabel');
  String get orderInvoiceStatusAvailable =>
      _string('orderInvoiceStatusAvailable');
  String get orderInvoiceStatusPending => _string('orderInvoiceStatusPending');
  String get orderInvoiceTaxable => _string('orderInvoiceTaxable');
  String get orderInvoiceTaxExempt => _string('orderInvoiceTaxExempt');
  String get orderInvoicePreviewTitle => _string('orderInvoicePreviewTitle');
  String get orderInvoiceRefreshTooltip =>
      _string('orderInvoiceRefreshTooltip');
  String get orderInvoicePendingBody => _string('orderInvoicePendingBody');
  String get orderInvoiceUnavailableBody =>
      _string('orderInvoiceUnavailableBody');
  String get orderInvoiceRequestAction => _string('orderInvoiceRequestAction');
  String get orderInvoiceSaveFailed => _string('orderInvoiceSaveFailed');
  String get designVersionsRollbackBody =>
      _string('designVersionsRollbackBody');
  String get orderProductionTitle => _string('orderProductionTitle');
  String get orderProductionRefreshTooltip =>
      _string('orderProductionRefreshTooltip');
  String get orderProductionDelayedMessage =>
      _string('orderProductionDelayedMessage');
  String get orderProductionTimelineTitle =>
      _string('orderProductionTimelineTitle');
  String get orderProductionNoEventsTitle =>
      _string('orderProductionNoEventsTitle');
  String get orderProductionNoEventsMessage =>
      _string('orderProductionNoEventsMessage');
  String get orderProductionNoEventsAction =>
      _string('orderProductionNoEventsAction');
  String get orderProductionHealthOnTrack =>
      _string('orderProductionHealthOnTrack');
  String get orderProductionHealthAttention =>
      _string('orderProductionHealthAttention');
  String get orderProductionHealthDelayed =>
      _string('orderProductionHealthDelayed');
  String get orderProductionEventQueued =>
      _string('orderProductionEventQueued');
  String get orderProductionEventEngraving =>
      _string('orderProductionEventEngraving');
  String get orderProductionEventPolishing =>
      _string('orderProductionEventPolishing');
  String get orderProductionEventQualityCheck =>
      _string('orderProductionEventQualityCheck');
  String get orderProductionEventPacked =>
      _string('orderProductionEventPacked');
  String get orderProductionEventOnHold =>
      _string('orderProductionEventOnHold');
  String get orderProductionEventRework =>
      _string('orderProductionEventRework');
  String get orderProductionEventCanceled =>
      _string('orderProductionEventCanceled');

  String profileExportTimeMinutes(int count) {
    final template = _string('profileExportTimeMinutes');
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeHours(int count) {
    final template = _string('profileExportTimeHours');
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeDays(int count) {
    final template = _string('profileExportTimeDays');
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeDate(DateTime dateTime) {
    final template = _string('profileExportTimeDate');
    final isJa = _resolveLanguageCode(locale) == 'ja';
    String two(int value) => value.toString().padLeft(2, '0');
    final date = isJa
        ? '${dateTime.year}/${two(dateTime.month)}/${two(dateTime.day)}'
        : '${dateTime.year}-${two(dateTime.month)}-${two(dateTime.day)}';
    return template.replaceAll('{date}', date);
  }

  String profileExportTimeCompactMinutes(int count) {
    final template = _string('profileExportTimeCompactMinutes');
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeCompactHours(int count) {
    final template = _string('profileExportTimeCompactHours');
    return template.replaceAll('{count}', '$count');
  }

  String profileExportTimeCompactDays(int count) {
    final template = _string('profileExportTimeCompactDays');
    return template.replaceAll('{count}', '$count');
  }

  String offlineLastSyncLabel(String date, String time) {
    final template = _string('offlineLastSyncLabel');
    return template.replaceAll('{date}', date).replaceAll('{time}', time);
  }

  String homeDesignSummary({
    required String shape,
    required String size,
    required String style,
  }) {
    final template = _string('homeDesignSummary');
    return template
        .replaceAll('{shape}', shape)
        .replaceAll('{size}', size)
        .replaceAll('{style}', style);
  }

  String homeDesignAiCheckLabel(String diagnostic) {
    final template = _string('homeDesignAiCheckLabel');
    return template.replaceAll('{diagnostic}', diagnostic);
  }

  String homeTemplateLabel({required String shape, required String style}) {
    final template = _string('homeTemplateLabel');
    return template.replaceAll('{shape}', shape).replaceAll('{style}', style);
  }

  String homeTemplateRecommendedSize(String size) {
    final template = _string('homeTemplateRecommendedSize');
    return template.replaceAll('{size}', size);
  }

  String topBarNotificationsLabelWithUnread(int count) {
    final template = _string('topBarNotificationsLabelWithUnread');
    return template.replaceAll('{count}', '$count');
  }

  String topBarNotificationsTooltipWithUnread(int count) {
    final template = _string('topBarNotificationsTooltipWithUnread');
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRollbackTitle(String version) {
    final template = _string('designVersionsRollbackTitle');
    return template.replaceAll('{version}', version);
  }

  String designVersionsCurrentLabel(String version) {
    final template = _string('designVersionsCurrentLabel');
    return template.replaceAll('{version}', version);
  }

  String designVersionsCompareTargetLabel(String version) {
    final template = _string('designVersionsCompareTargetLabel');
    return template.replaceAll('{version}', version);
  }

  String designVersionsTemplateLabel(String templateValue) {
    final template = _string('designVersionsTemplateLabel');
    return template.replaceAll('{template}', templateValue);
  }

  String designVersionsRelativeMinutes(int count) {
    final template = _string('designVersionsRelativeMinutes');
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeHours(int count) {
    final template = _string('designVersionsRelativeHours');
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeDays(int count) {
    final template = _string('designVersionsRelativeDays');
    return template.replaceAll('{count}', '$count');
  }

  String designVersionsRelativeTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return _string('designVersionsRelativeNow');
    if (diff.inMinutes < 60) {
      return designVersionsRelativeMinutes(diff.inMinutes);
    }
    if (diff.inHours < 24) return designVersionsRelativeHours(diff.inHours);
    return designVersionsRelativeDays(diff.inDays);
  }

  String libraryDesignDetailAiScoreLabel(String score) {
    final template = _string('libraryDesignDetailAiScoreLabel');
    return template.replaceAll('{score}', score);
  }

  String libraryDesignDetailHydrateFailed(String error) {
    final template = _string('libraryDesignDetailHydrateFailed');
    return template.replaceAll('{error}', error);
  }

  String orderDetailShareText(String number) {
    final template = _string('orderDetailShareText');
    return template.replaceAll('{number}', number);
  }

  String orderDetailItemQtyLabel(String quantity) {
    final template = _string('orderDetailItemQtyLabel');
    return template.replaceAll('{quantity}', quantity);
  }

  String orderDetailPaymentPaidAt(String date) {
    final template = _string('orderDetailPaymentPaidAt');
    return template.replaceAll('{date}', date);
  }

  String orderDetailMeta(String id, String date) {
    final template = _string('orderDetailMeta');
    return template.replaceAll('{id}', id).replaceAll('{date}', date);
  }

  String kanjiDictionaryStrokeCount(String count) {
    final template = _string('kanjiDictionaryStrokeCount');
    return template.replaceAll('{count}', count);
  }

  String kanjiDictionaryRadicalLabel(String radical) {
    final template = _string('kanjiDictionaryRadicalLabel');
    return template.replaceAll('{radical}', radical);
  }

  String kanjiDictionaryChipStrokes(String count) {
    final template = _string('kanjiDictionaryChipStrokes');
    return template.replaceAll('{count}', count);
  }

  String kanjiDictionaryChipRadical(String radical) {
    final template = _string('kanjiDictionaryChipRadical');
    return template.replaceAll('{radical}', radical);
  }

  String kanjiDictionaryStrokeOrderPrefix(String steps) {
    final template = _string('kanjiDictionaryStrokeOrderPrefix');
    return template.replaceAll('{steps}', steps);
  }

  String orderInvoiceSavedTo(String path) {
    final template = _string('orderInvoiceSavedTo');
    return template.replaceAll('{path}', path);
  }

  String orderInvoiceShareText({required String app, required String number}) {
    final template = _string('orderInvoiceShareText');
    return template.replaceAll('{app}', app).replaceAll('{number}', number);
  }

  String orderInvoiceOrderLabel(String number) {
    final template = _string('orderInvoiceOrderLabel');
    return template.replaceAll('{number}', number);
  }

  String orderInvoiceIssuedLabel(String date) {
    final template = _string('orderInvoiceIssuedLabel');
    return template.replaceAll('{date}', date);
  }

  String checkoutPaymentExpires(int month, int year) {
    final template = _string('checkoutPaymentExpires');
    return template
        .replaceAll('{month}', '$month')
        .replaceAll('{year}', '$year');
  }

  String cartPromoShipfreeShortfall(int amount) {
    final template = _string('cartPromoShipfreeShortfall');
    return template.replaceAll('{amount}', amount.toString());
  }

  String cartRemovedItem(String item) {
    final template = _string('cartRemovedItem');
    return template.replaceAll('{item}', item);
  }

  String cartPromoApplied(String label) {
    final template = _string('cartPromoApplied');
    return template.replaceAll('{label}', label);
  }

  String cartLeadTimeLabel(int minDays, int maxDays) {
    final template = _string('cartLeadTimeLabel');
    return template
        .replaceAll('{min}', minDays.toString())
        .replaceAll('{max}', maxDays.toString());
  }

  String cartSummaryItems(int count) {
    final template = _string('cartSummaryItems');
    return template.replaceAll('{count}', count.toString());
  }

  String cartSummaryEstimate(int minDays, int maxDays, String method) {
    final template = _string('cartSummaryEstimate');
    return template
        .replaceAll('{min}', minDays.toString())
        .replaceAll('{max}', maxDays.toString())
        .replaceAll('{method}', method);
  }

  String orderProductionStatusLabel(String status) {
    final template = _string('orderProductionStatusLabel');
    return template.replaceAll('{status}', status);
  }

  String orderProductionEtaLabel(String date) {
    final template = _string('orderProductionEtaLabel');
    return template.replaceAll('{date}', date);
  }

  String orderProductionEventStation(String station) {
    final template = _string('orderProductionEventStation');
    return template.replaceAll('{station}', station);
  }

  String orderProductionEventQc(String details) {
    final template = _string('orderProductionEventQc');
    return template.replaceAll('{details}', details);
  }

  String appUpdateCurrentVersion(String version) {
    final template = _string('appUpdateCurrentVersion');
    return template.replaceAll('{version}', version);
  }

  String appUpdateMinimumVersion(String version) {
    final template = _string('appUpdateMinimumVersion');
    return template.replaceAll('{version}', version);
  }

  String appUpdateLatestVersion(String version) {
    final template = _string('appUpdateLatestVersion');
    return template.replaceAll('{version}', version);
  }

  String appUpdateReminder(String version) {
    final template = _string('appUpdateReminder');
    return template.replaceAll('{version}', version);
  }

  String onboardingStepCount(int current, int total) {
    final template = _string('onboardingStepCount');
    return template
        .replaceAll('{current}', '$current')
        .replaceAll('{total}', '$total');
  }

  String profileLocaleCurrencyAutoHint(String currency) {
    final template = _string('profileLocaleCurrencyAutoHint');
    return template.replaceAll('{currency}', currency);
  }

  String authErrorLink(String providers) {
    final template = _string('authErrorLink');
    return template.replaceAll('{providers}', providers);
  }

  String authLinkPrompt(String providers) {
    final template = _string('authLinkPrompt');
    return template.replaceAll('{providers}', providers);
  }

  String localeDescription(String deviceTag) {
    final template = _string('localeDescription');
    return template.replaceAll('{device}', deviceTag);
  }

  String _string(String key) {
    final language = _resolveLanguageCode(locale);
    final table = _localizedValues[language] ?? _localizedValues['en']!;
    return table[key] ?? _localizedValues['en']![key]!;
  }

  String _resolveLanguageCode(Locale locale) {
    if (supportedLanguageCodes.contains(locale.languageCode)) {
      return locale.languageCode;
    }
    return 'en';
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
