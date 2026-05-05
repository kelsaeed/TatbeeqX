import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'app_localizations_ar.dart';
import 'app_localizations_en.dart';
import 'app_localizations_fr.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'gen/app_localizations.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
      : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations)!;
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
    delegate,
    GlobalMaterialLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
  ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('ar'),
    Locale('en'),
    Locale('fr')
  ];

  /// Application name as shown in titles
  ///
  /// In en, this message translates to:
  /// **'TatbeeqX'**
  String get appName;

  /// No description provided for @signIn.
  ///
  /// In en, this message translates to:
  /// **'Sign in'**
  String get signIn;

  /// No description provided for @signInToContinue.
  ///
  /// In en, this message translates to:
  /// **'Sign in to continue'**
  String get signInToContinue;

  /// No description provided for @usernameOrEmail.
  ///
  /// In en, this message translates to:
  /// **'Username or email'**
  String get usernameOrEmail;

  /// No description provided for @password.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get password;

  /// No description provided for @signOut.
  ///
  /// In en, this message translates to:
  /// **'Sign out'**
  String get signOut;

  /// No description provided for @loginTagline.
  ///
  /// In en, this message translates to:
  /// **'LAN-ready • secured by JWT'**
  String get loginTagline;

  /// No description provided for @manageEveryBusiness.
  ///
  /// In en, this message translates to:
  /// **'Manage every business,'**
  String get manageEveryBusiness;

  /// No description provided for @inOnePlace.
  ///
  /// In en, this message translates to:
  /// **'in one place.'**
  String get inOnePlace;

  /// No description provided for @loginHeroSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Multi-company, multi-branch, role-based, fully customizable.'**
  String get loginHeroSubtitle;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @create.
  ///
  /// In en, this message translates to:
  /// **'Create'**
  String get create;

  /// No description provided for @newItem.
  ///
  /// In en, this message translates to:
  /// **'New'**
  String get newItem;

  /// No description provided for @search.
  ///
  /// In en, this message translates to:
  /// **'Search'**
  String get search;

  /// No description provided for @loading.
  ///
  /// In en, this message translates to:
  /// **'Loading…'**
  String get loading;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @noData.
  ///
  /// In en, this message translates to:
  /// **'No data'**
  String get noData;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @yes.
  ///
  /// In en, this message translates to:
  /// **'Yes'**
  String get yes;

  /// No description provided for @no.
  ///
  /// In en, this message translates to:
  /// **'No'**
  String get no;

  /// No description provided for @refresh.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refresh;

  /// No description provided for @saving.
  ///
  /// In en, this message translates to:
  /// **'Saving…'**
  String get saving;

  /// No description provided for @required.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get required;

  /// No description provided for @company.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get company;

  /// No description provided for @noCompany.
  ///
  /// In en, this message translates to:
  /// **'No company'**
  String get noCompany;

  /// No description provided for @globalTheme.
  ///
  /// In en, this message translates to:
  /// **'— Global theme —'**
  String get globalTheme;

  /// No description provided for @switchCompany.
  ///
  /// In en, this message translates to:
  /// **'Switch company'**
  String get switchCompany;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @account.
  ///
  /// In en, this message translates to:
  /// **'Account'**
  String get account;

  /// No description provided for @superAdmin.
  ///
  /// In en, this message translates to:
  /// **'Super Admin'**
  String get superAdmin;

  /// No description provided for @user.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get user;

  /// No description provided for @dashboard.
  ///
  /// In en, this message translates to:
  /// **'Dashboard'**
  String get dashboard;

  /// No description provided for @users.
  ///
  /// In en, this message translates to:
  /// **'Users'**
  String get users;

  /// No description provided for @roles.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get roles;

  /// No description provided for @companies.
  ///
  /// In en, this message translates to:
  /// **'Companies'**
  String get companies;

  /// No description provided for @branches.
  ///
  /// In en, this message translates to:
  /// **'Branches'**
  String get branches;

  /// No description provided for @audit.
  ///
  /// In en, this message translates to:
  /// **'Audit Logs'**
  String get audit;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @reports.
  ///
  /// In en, this message translates to:
  /// **'Reports'**
  String get reports;

  /// No description provided for @database.
  ///
  /// In en, this message translates to:
  /// **'Database'**
  String get database;

  /// No description provided for @customEntities.
  ///
  /// In en, this message translates to:
  /// **'Custom entities'**
  String get customEntities;

  /// No description provided for @templates.
  ///
  /// In en, this message translates to:
  /// **'Templates'**
  String get templates;

  /// No description provided for @pages.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pages;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @systemLogs.
  ///
  /// In en, this message translates to:
  /// **'System Logs'**
  String get systemLogs;

  /// No description provided for @loginActivity.
  ///
  /// In en, this message translates to:
  /// **'Login Activity'**
  String get loginActivity;

  /// No description provided for @approvals.
  ///
  /// In en, this message translates to:
  /// **'Approvals'**
  String get approvals;

  /// No description provided for @reportSchedules.
  ///
  /// In en, this message translates to:
  /// **'Report Schedules'**
  String get reportSchedules;

  /// No description provided for @webhooks.
  ///
  /// In en, this message translates to:
  /// **'Webhooks'**
  String get webhooks;

  /// No description provided for @backups.
  ///
  /// In en, this message translates to:
  /// **'Backups'**
  String get backups;

  /// Generic delete-confirmation dialog content
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"?'**
  String deleteConfirm(String name);

  /// No description provided for @loadFailed.
  ///
  /// In en, this message translates to:
  /// **'Load failed: {error}'**
  String loadFailed(String error);

  /// No description provided for @saveFailed.
  ///
  /// In en, this message translates to:
  /// **'Save failed: {error}'**
  String saveFailed(String error);

  /// No description provided for @deleteFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailedMsg(String error);

  /// No description provided for @createFailed.
  ///
  /// In en, this message translates to:
  /// **'Create failed: {error}'**
  String createFailed(String error);

  /// No description provided for @adminRestricted.
  ///
  /// In en, this message translates to:
  /// **'{feature} is restricted to Super Admin'**
  String adminRestricted(String feature);

  /// No description provided for @apply.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get apply;

  /// No description provided for @activate.
  ///
  /// In en, this message translates to:
  /// **'Activate'**
  String get activate;

  /// No description provided for @duplicate.
  ///
  /// In en, this message translates to:
  /// **'Duplicate'**
  String get duplicate;

  /// No description provided for @resetLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset'**
  String get resetLabel;

  /// No description provided for @run.
  ///
  /// In en, this message translates to:
  /// **'Run'**
  String get run;

  /// No description provided for @importLabel.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importLabel;

  /// No description provided for @exportLabel.
  ///
  /// In en, this message translates to:
  /// **'Export'**
  String get exportLabel;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @remove.
  ///
  /// In en, this message translates to:
  /// **'Remove'**
  String get remove;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @back.
  ///
  /// In en, this message translates to:
  /// **'Back'**
  String get back;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @code.
  ///
  /// In en, this message translates to:
  /// **'Code'**
  String get code;

  /// No description provided for @email.
  ///
  /// In en, this message translates to:
  /// **'Email'**
  String get email;

  /// No description provided for @statusLabel.
  ///
  /// In en, this message translates to:
  /// **'Status'**
  String get statusLabel;

  /// No description provided for @typeLabel.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeLabel;

  /// No description provided for @defaultLabel.
  ///
  /// In en, this message translates to:
  /// **'Default'**
  String get defaultLabel;

  /// No description provided for @actionsLabel.
  ///
  /// In en, this message translates to:
  /// **'Actions'**
  String get actionsLabel;

  /// No description provided for @descriptionLabel.
  ///
  /// In en, this message translates to:
  /// **'Description'**
  String get descriptionLabel;

  /// No description provided for @systemChip.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemChip;

  /// No description provided for @enabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get enabledLabel;

  /// No description provided for @disabledLabel.
  ///
  /// In en, this message translates to:
  /// **'Disabled'**
  String get disabledLabel;

  /// No description provided for @active.
  ///
  /// In en, this message translates to:
  /// **'Active'**
  String get active;

  /// No description provided for @inactive.
  ///
  /// In en, this message translates to:
  /// **'Inactive'**
  String get inactive;

  /// No description provided for @all.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get all;

  /// No description provided for @noneLabel.
  ///
  /// In en, this message translates to:
  /// **'None'**
  String get noneLabel;

  /// No description provided for @pageOfTotal.
  ///
  /// In en, this message translates to:
  /// **'Page {page} of {total}'**
  String pageOfTotal(int page, int total);

  /// No description provided for @permissionsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No permissions} =1{1 permission} other{{count} permissions}}'**
  String permissionsCount(int count);

  /// No description provided for @usersCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No users} =1{1 user} other{{count} users}}'**
  String usersCount(int count);

  /// No description provided for @rolesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Define roles and assign granular permissions.'**
  String get rolesSubtitle;

  /// No description provided for @auditSubtitle.
  ///
  /// In en, this message translates to:
  /// **'A timeline of every important system action.'**
  String get auditSubtitle;

  /// No description provided for @backupsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Snapshots of the primary database. Restore overwrites the current DB and requires a restart.'**
  String get backupsSubtitle;

  /// No description provided for @reportsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pre-built reports. Run them to view fresh data.'**
  String get reportsSubtitle;

  /// No description provided for @dashboardSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Here is a quick overview of your system.'**
  String get dashboardSubtitle;

  /// No description provided for @loginFailed.
  ///
  /// In en, this message translates to:
  /// **'Login failed'**
  String get loginFailed;

  /// No description provided for @searchHint.
  ///
  /// In en, this message translates to:
  /// **'Search…'**
  String get searchHint;

  /// No description provided for @totalLabel.
  ///
  /// In en, this message translates to:
  /// **'{count} total'**
  String totalLabel(int count);

  /// No description provided for @fileNotFound.
  ///
  /// In en, this message translates to:
  /// **'File not found: {path}'**
  String fileNotFound(String path);

  /// No description provided for @uploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get uploaded;

  /// No description provided for @uploadFailed.
  ///
  /// In en, this message translates to:
  /// **'Upload failed: {error}'**
  String uploadFailed(String error);

  /// No description provided for @upload.
  ///
  /// In en, this message translates to:
  /// **'Upload'**
  String get upload;

  /// No description provided for @uploading.
  ///
  /// In en, this message translates to:
  /// **'Uploading…'**
  String get uploading;

  /// No description provided for @uploadHint.
  ///
  /// In en, this message translates to:
  /// **'…or paste a local file path (e.g. C:\\images\\logo.png) and press Upload'**
  String get uploadHint;

  /// No description provided for @urlHint.
  ///
  /// In en, this message translates to:
  /// **'URL'**
  String get urlHint;

  /// No description provided for @restore.
  ///
  /// In en, this message translates to:
  /// **'Restore'**
  String get restore;

  /// No description provided for @auditWhen.
  ///
  /// In en, this message translates to:
  /// **'When'**
  String get auditWhen;

  /// No description provided for @auditUser.
  ///
  /// In en, this message translates to:
  /// **'User'**
  String get auditUser;

  /// No description provided for @auditAction.
  ///
  /// In en, this message translates to:
  /// **'Action'**
  String get auditAction;

  /// No description provided for @auditEntity.
  ///
  /// In en, this message translates to:
  /// **'Entity'**
  String get auditEntity;

  /// No description provided for @auditId.
  ///
  /// In en, this message translates to:
  /// **'ID'**
  String get auditId;

  /// No description provided for @auditIp.
  ///
  /// In en, this message translates to:
  /// **'IP'**
  String get auditIp;

  /// No description provided for @systemUserLabel.
  ///
  /// In en, this message translates to:
  /// **'system'**
  String get systemUserLabel;

  /// No description provided for @createBackup.
  ///
  /// In en, this message translates to:
  /// **'Create backup'**
  String get createBackup;

  /// No description provided for @backupLabelField.
  ///
  /// In en, this message translates to:
  /// **'Label (optional, lowercase + dashes)'**
  String get backupLabelField;

  /// No description provided for @backupLabelExample.
  ///
  /// In en, this message translates to:
  /// **'e.g. before-month-end'**
  String get backupLabelExample;

  /// No description provided for @deleteBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete backup?'**
  String get deleteBackupTitle;

  /// No description provided for @deleteBackupWarn.
  ///
  /// In en, this message translates to:
  /// **'This permanently removes \"{name}\" from disk.'**
  String deleteBackupWarn(String name);

  /// No description provided for @restoreBackupTitle.
  ///
  /// In en, this message translates to:
  /// **'Restore backup?'**
  String get restoreBackupTitle;

  /// No description provided for @restoreBackupWarn.
  ///
  /// In en, this message translates to:
  /// **'This overwrites the current database with \"{name}\". After restore, the API process must be restarted before changes take effect.\n\nData created since this backup will be lost.'**
  String restoreBackupWarn(String name);

  /// No description provided for @restoreCompleteRestart.
  ///
  /// In en, this message translates to:
  /// **'Restore complete. Restart required.'**
  String get restoreCompleteRestart;

  /// No description provided for @noBackupsYet.
  ///
  /// In en, this message translates to:
  /// **'No backups yet. Click \"New backup\".'**
  String get noBackupsYet;

  /// No description provided for @noReportsDefined.
  ///
  /// In en, this message translates to:
  /// **'No reports defined'**
  String get noReportsDefined;

  /// No description provided for @noPermissionReports.
  ///
  /// In en, this message translates to:
  /// **'You do not have permission to view reports.'**
  String get noPermissionReports;

  /// No description provided for @auditEventsLast14.
  ///
  /// In en, this message translates to:
  /// **'Audit events — last 14 days'**
  String get auditEventsLast14;

  /// No description provided for @auditByEntityLast30.
  ///
  /// In en, this message translates to:
  /// **'Audit by entity — last 30 days'**
  String get auditByEntityLast30;

  /// No description provided for @recentLogins.
  ///
  /// In en, this message translates to:
  /// **'Recent logins'**
  String get recentLogins;

  /// No description provided for @recentAuditEvents.
  ///
  /// In en, this message translates to:
  /// **'Recent audit events'**
  String get recentAuditEvents;

  /// No description provided for @noActivityYet.
  ///
  /// In en, this message translates to:
  /// **'No activity yet'**
  String get noActivityYet;

  /// No description provided for @noDataYet.
  ///
  /// In en, this message translates to:
  /// **'No data yet'**
  String get noDataYet;

  /// No description provided for @noAuditEntriesYet.
  ///
  /// In en, this message translates to:
  /// **'No audit entries yet'**
  String get noAuditEntriesYet;

  /// No description provided for @auditEventsCount.
  ///
  /// In en, this message translates to:
  /// **'Audit events'**
  String get auditEventsCount;

  /// No description provided for @failedShort.
  ///
  /// In en, this message translates to:
  /// **'Failed: {error}'**
  String failedShort(String error);

  /// No description provided for @username.
  ///
  /// In en, this message translates to:
  /// **'Username'**
  String get username;

  /// No description provided for @fullName.
  ///
  /// In en, this message translates to:
  /// **'Full name'**
  String get fullName;

  /// No description provided for @phoneOptional.
  ///
  /// In en, this message translates to:
  /// **'Phone (optional)'**
  String get phoneOptional;

  /// No description provided for @phone.
  ///
  /// In en, this message translates to:
  /// **'Phone'**
  String get phone;

  /// No description provided for @address.
  ///
  /// In en, this message translates to:
  /// **'Address'**
  String get address;

  /// No description provided for @legalName.
  ///
  /// In en, this message translates to:
  /// **'Legal name'**
  String get legalName;

  /// No description provided for @taxNumber.
  ///
  /// In en, this message translates to:
  /// **'Tax number'**
  String get taxNumber;

  /// No description provided for @logoUrl.
  ///
  /// In en, this message translates to:
  /// **'Logo URL'**
  String get logoUrl;

  /// No description provided for @passwordField.
  ///
  /// In en, this message translates to:
  /// **'Password'**
  String get passwordField;

  /// No description provided for @newPasswordKeepBlank.
  ///
  /// In en, this message translates to:
  /// **'New password (leave blank to keep)'**
  String get newPasswordKeepBlank;

  /// No description provided for @min8Chars.
  ///
  /// In en, this message translates to:
  /// **'Min 8 characters'**
  String get min8Chars;

  /// No description provided for @invalidEmail.
  ///
  /// In en, this message translates to:
  /// **'Invalid email'**
  String get invalidEmail;

  /// No description provided for @noneOption.
  ///
  /// In en, this message translates to:
  /// **'— None —'**
  String get noneOption;

  /// No description provided for @branchField.
  ///
  /// In en, this message translates to:
  /// **'Branch'**
  String get branchField;

  /// No description provided for @companyField.
  ///
  /// In en, this message translates to:
  /// **'Company'**
  String get companyField;

  /// No description provided for @rolesField.
  ///
  /// In en, this message translates to:
  /// **'Roles'**
  String get rolesField;

  /// No description provided for @deleteCannotBeUndone.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? This cannot be undone.'**
  String deleteCannotBeUndone(String name);

  /// No description provided for @deleteCascadeWarn.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{name}\"? Branches and related data will cascade.'**
  String deleteCascadeWarn(String name);

  /// No description provided for @selectCompany.
  ///
  /// In en, this message translates to:
  /// **'Select a company'**
  String get selectCompany;

  /// No description provided for @noBranches.
  ///
  /// In en, this message translates to:
  /// **'No branches'**
  String get noBranches;

  /// No description provided for @branchesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No branches} =1{1 branch} other{{count} branches}}'**
  String branchesCount(int count);

  /// No description provided for @usersSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Create and manage system users.'**
  String get usersSubtitle;

  /// No description provided for @newUser.
  ///
  /// In en, this message translates to:
  /// **'New user'**
  String get newUser;

  /// No description provided for @editUser.
  ///
  /// In en, this message translates to:
  /// **'Edit user'**
  String get editUser;

  /// No description provided for @deleteUser.
  ///
  /// In en, this message translates to:
  /// **'Delete user'**
  String get deleteUser;

  /// No description provided for @searchUsers.
  ///
  /// In en, this message translates to:
  /// **'Search users…'**
  String get searchUsers;

  /// No description provided for @companiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Each company can have its own branches, users, and theme.'**
  String get companiesSubtitle;

  /// No description provided for @newCompany.
  ///
  /// In en, this message translates to:
  /// **'New company'**
  String get newCompany;

  /// No description provided for @editCompany.
  ///
  /// In en, this message translates to:
  /// **'Edit company'**
  String get editCompany;

  /// No description provided for @deleteCompany.
  ///
  /// In en, this message translates to:
  /// **'Delete company'**
  String get deleteCompany;

  /// No description provided for @codeColon.
  ///
  /// In en, this message translates to:
  /// **'Code: {code}'**
  String codeColon(String code);

  /// No description provided for @branchesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Branches belong to companies.'**
  String get branchesSubtitle;

  /// No description provided for @newBranch.
  ///
  /// In en, this message translates to:
  /// **'New branch'**
  String get newBranch;

  /// No description provided for @editBranch.
  ///
  /// In en, this message translates to:
  /// **'Edit branch'**
  String get editBranch;

  /// No description provided for @deleteBranch.
  ///
  /// In en, this message translates to:
  /// **'Delete branch'**
  String get deleteBranch;

  /// No description provided for @settingsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'System-wide key/value settings. Anything marked \"public\" is visible without auth.'**
  String get settingsSubtitle;

  /// No description provided for @addRow.
  ///
  /// In en, this message translates to:
  /// **'Add row'**
  String get addRow;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @keyField.
  ///
  /// In en, this message translates to:
  /// **'Key'**
  String get keyField;

  /// No description provided for @valueField.
  ///
  /// In en, this message translates to:
  /// **'Value'**
  String get valueField;

  /// No description provided for @typeField.
  ///
  /// In en, this message translates to:
  /// **'Type'**
  String get typeField;

  /// No description provided for @publicLabel.
  ///
  /// In en, this message translates to:
  /// **'Public'**
  String get publicLabel;

  /// No description provided for @noSettingsYet.
  ///
  /// In en, this message translates to:
  /// **'No settings yet'**
  String get noSettingsYet;

  /// No description provided for @loginActivitySubtitle.
  ///
  /// In en, this message translates to:
  /// **'Every login, refresh, logout, and failed attempt.'**
  String get loginActivitySubtitle;

  /// No description provided for @eventField.
  ///
  /// In en, this message translates to:
  /// **'Event'**
  String get eventField;

  /// No description provided for @allEvents.
  ///
  /// In en, this message translates to:
  /// **'All events'**
  String get allEvents;

  /// No description provided for @loginEvent.
  ///
  /// In en, this message translates to:
  /// **'Login'**
  String get loginEvent;

  /// No description provided for @logoutEvent.
  ///
  /// In en, this message translates to:
  /// **'Logout'**
  String get logoutEvent;

  /// No description provided for @refreshEvent.
  ///
  /// In en, this message translates to:
  /// **'Refresh'**
  String get refreshEvent;

  /// No description provided for @successField.
  ///
  /// In en, this message translates to:
  /// **'Success'**
  String get successField;

  /// No description provided for @successfulOption.
  ///
  /// In en, this message translates to:
  /// **'Successful'**
  String get successfulOption;

  /// No description provided for @failedOption.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failedOption;

  /// No description provided for @searchLoginEvents.
  ///
  /// In en, this message translates to:
  /// **'Search by username, IP, or user agent…'**
  String get searchLoginEvents;

  /// No description provided for @resultColumn.
  ///
  /// In en, this message translates to:
  /// **'Result'**
  String get resultColumn;

  /// No description provided for @okShort.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get okShort;

  /// No description provided for @failShort.
  ///
  /// In en, this message translates to:
  /// **'FAIL'**
  String get failShort;

  /// No description provided for @reasonColumn.
  ///
  /// In en, this message translates to:
  /// **'Reason'**
  String get reasonColumn;

  /// No description provided for @systemLogsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server-side events: startup, errors, warnings, info.'**
  String get systemLogsSubtitle;

  /// No description provided for @clearOlderThan30.
  ///
  /// In en, this message translates to:
  /// **'Clear older than 30 days'**
  String get clearOlderThan30;

  /// No description provided for @clearOldLogsTitle.
  ///
  /// In en, this message translates to:
  /// **'Clear old logs?'**
  String get clearOldLogsTitle;

  /// No description provided for @clearOldLogsBody.
  ///
  /// In en, this message translates to:
  /// **'Delete every system log older than 30 days. This cannot be undone.'**
  String get clearOldLogsBody;

  /// No description provided for @levelField.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get levelField;

  /// No description provided for @allLevels.
  ///
  /// In en, this message translates to:
  /// **'All levels'**
  String get allLevels;

  /// No description provided for @levelDebug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get levelDebug;

  /// No description provided for @levelInfo.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get levelInfo;

  /// No description provided for @levelWarn.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get levelWarn;

  /// No description provided for @levelError.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get levelError;

  /// No description provided for @sourceField.
  ///
  /// In en, this message translates to:
  /// **'Source'**
  String get sourceField;

  /// No description provided for @searchMessageContext.
  ///
  /// In en, this message translates to:
  /// **'Search message or context…'**
  String get searchMessageContext;

  /// No description provided for @messageField.
  ///
  /// In en, this message translates to:
  /// **'Message'**
  String get messageField;

  /// No description provided for @webhooksSubtitle.
  ///
  /// In en, this message translates to:
  /// **'POST notifications to external URLs when system events fire. HMAC-signed.'**
  String get webhooksSubtitle;

  /// No description provided for @newWebhook.
  ///
  /// In en, this message translates to:
  /// **'New webhook'**
  String get newWebhook;

  /// No description provided for @noSubscriptionsYet.
  ///
  /// In en, this message translates to:
  /// **'No subscriptions yet.'**
  String get noSubscriptionsYet;

  /// No description provided for @enableLabel.
  ///
  /// In en, this message translates to:
  /// **'Enable'**
  String get enableLabel;

  /// No description provided for @disableLabel.
  ///
  /// In en, this message translates to:
  /// **'Disable'**
  String get disableLabel;

  /// No description provided for @sendTestEvent.
  ///
  /// In en, this message translates to:
  /// **'Send test event'**
  String get sendTestEvent;

  /// No description provided for @recentDeliveries.
  ///
  /// In en, this message translates to:
  /// **'Recent deliveries'**
  String get recentDeliveries;

  /// No description provided for @testEventDispatched.
  ///
  /// In en, this message translates to:
  /// **'Test event dispatched'**
  String get testEventDispatched;

  /// No description provided for @deleteSubscriptionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete subscription?'**
  String get deleteSubscriptionTitle;

  /// No description provided for @deleteSubscriptionBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the subscription and all delivery history.'**
  String get deleteSubscriptionBody;

  /// No description provided for @recentDeliveriesFor.
  ///
  /// In en, this message translates to:
  /// **'Recent deliveries — {name}'**
  String recentDeliveriesFor(String name);

  /// No description provided for @noDeliveriesYet.
  ///
  /// In en, this message translates to:
  /// **'No deliveries yet.'**
  String get noDeliveriesYet;

  /// No description provided for @newWebhookSubscription.
  ///
  /// In en, this message translates to:
  /// **'New webhook subscription'**
  String get newWebhookSubscription;

  /// No description provided for @codeLowerSnake.
  ///
  /// In en, this message translates to:
  /// **'Code (lowercase, snake_case)'**
  String get codeLowerSnake;

  /// No description provided for @urlHttps.
  ///
  /// In en, this message translates to:
  /// **'URL (https://...)'**
  String get urlHttps;

  /// No description provided for @secretOptionalAuto.
  ///
  /// In en, this message translates to:
  /// **'Secret (optional — auto-generated if blank)'**
  String get secretOptionalAuto;

  /// No description provided for @eventsLabel.
  ///
  /// In en, this message translates to:
  /// **'Events'**
  String get eventsLabel;

  /// No description provided for @pickAtLeastOneEvent.
  ///
  /// In en, this message translates to:
  /// **'Pick at least one event'**
  String get pickAtLeastOneEvent;

  /// No description provided for @webhookSecretTitle.
  ///
  /// In en, this message translates to:
  /// **'Webhook secret'**
  String get webhookSecretTitle;

  /// No description provided for @webhookSecretSaveWarn.
  ///
  /// In en, this message translates to:
  /// **'Save this secret somewhere safe — it will not be shown again:\n\n{secret}'**
  String webhookSecretSaveWarn(String secret);

  /// No description provided for @approvalsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Pending requests waiting for someone with <entity>.approve.'**
  String get approvalsSubtitle;

  /// No description provided for @newRequest.
  ///
  /// In en, this message translates to:
  /// **'New request'**
  String get newRequest;

  /// No description provided for @statusPending.
  ///
  /// In en, this message translates to:
  /// **'Pending'**
  String get statusPending;

  /// No description provided for @statusApproved.
  ///
  /// In en, this message translates to:
  /// **'Approved'**
  String get statusApproved;

  /// No description provided for @statusRejected.
  ///
  /// In en, this message translates to:
  /// **'Rejected'**
  String get statusRejected;

  /// No description provided for @statusCancelled.
  ///
  /// In en, this message translates to:
  /// **'Cancelled'**
  String get statusCancelled;

  /// No description provided for @approveLabel.
  ///
  /// In en, this message translates to:
  /// **'Approve'**
  String get approveLabel;

  /// No description provided for @rejectLabel.
  ///
  /// In en, this message translates to:
  /// **'Reject'**
  String get rejectLabel;

  /// No description provided for @approveTitle.
  ///
  /// In en, this message translates to:
  /// **'Approve request?'**
  String get approveTitle;

  /// No description provided for @rejectTitle.
  ///
  /// In en, this message translates to:
  /// **'Reject request?'**
  String get rejectTitle;

  /// No description provided for @noteOptional.
  ///
  /// In en, this message translates to:
  /// **'Note (optional)'**
  String get noteOptional;

  /// No description provided for @requestApproval.
  ///
  /// In en, this message translates to:
  /// **'Request approval'**
  String get requestApproval;

  /// No description provided for @entityProductsHint.
  ///
  /// In en, this message translates to:
  /// **'Entity (e.g. products)'**
  String get entityProductsHint;

  /// No description provided for @titleField.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get titleField;

  /// No description provided for @submitLabel.
  ///
  /// In en, this message translates to:
  /// **'Submit'**
  String get submitLabel;

  /// No description provided for @approvalsRequestedBy.
  ///
  /// In en, this message translates to:
  /// **'Requested by'**
  String get approvalsRequestedBy;

  /// No description provided for @approvalsTitleColumn.
  ///
  /// In en, this message translates to:
  /// **'Title'**
  String get approvalsTitleColumn;

  /// No description provided for @setupLocked.
  ///
  /// In en, this message translates to:
  /// **'Setup is locked. Ask the Super Admin to choose a business type.'**
  String get setupLocked;

  /// No description provided for @welcomePickBusinessType.
  ///
  /// In en, this message translates to:
  /// **'Welcome — pick a business type'**
  String get welcomePickBusinessType;

  /// No description provided for @setupExplain.
  ///
  /// In en, this message translates to:
  /// **'This decides the starter modules, tables and menus. You can always change everything later, add new tables and run SQL from the Database admin page.'**
  String get setupExplain;

  /// No description provided for @alreadyConfiguredHint.
  ///
  /// In en, this message translates to:
  /// **'Already configured? Visit the Custom Entities and Database pages to add new tables, edit columns or run SQL.'**
  String get alreadyConfiguredHint;

  /// No description provided for @skipAndContinue.
  ///
  /// In en, this message translates to:
  /// **'Skip and continue'**
  String get skipAndContinue;

  /// No description provided for @useThis.
  ///
  /// In en, this message translates to:
  /// **'Use this'**
  String get useThis;

  /// No description provided for @applyFailed.
  ///
  /// In en, this message translates to:
  /// **'Apply failed: {error}'**
  String applyFailed(String error);

  /// No description provided for @deleteRowTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete row'**
  String get deleteRowTitle;

  /// No description provided for @newEntitySingular.
  ///
  /// In en, this message translates to:
  /// **'New {singular}'**
  String newEntitySingular(String singular);

  /// No description provided for @editEntitySingular.
  ///
  /// In en, this message translates to:
  /// **'Edit {singular}'**
  String editEntitySingular(String singular);

  /// No description provided for @tableLabel.
  ///
  /// In en, this message translates to:
  /// **'Table: {tableName}'**
  String tableLabel(String tableName);

  /// No description provided for @searchEntityHint.
  ///
  /// In en, this message translates to:
  /// **'Search {label}…'**
  String searchEntityHint(String label);

  /// No description provided for @customEntitiesAdminRestricted.
  ///
  /// In en, this message translates to:
  /// **'Custom Entities admin is restricted to Super Admin.'**
  String get customEntitiesAdminRestricted;

  /// No description provided for @customEntitiesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Tables tailored to your business. Each entity gets its own permissions, menu item and CRUD page.'**
  String get customEntitiesSubtitle;

  /// No description provided for @newEntity.
  ///
  /// In en, this message translates to:
  /// **'New entity'**
  String get newEntity;

  /// No description provided for @editEntity.
  ///
  /// In en, this message translates to:
  /// **'Edit entity'**
  String get editEntity;

  /// No description provided for @noCustomEntitiesYet.
  ///
  /// In en, this message translates to:
  /// **'No custom entities yet.'**
  String get noCustomEntitiesYet;

  /// No description provided for @deleteEntityTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete \"{label}\"'**
  String deleteEntityTitle(String label);

  /// No description provided for @deleteEntityBody.
  ///
  /// In en, this message translates to:
  /// **'You can either keep the underlying table (data preserved, only the registration is removed) or drop it (irreversible).'**
  String get deleteEntityBody;

  /// No description provided for @unregisterOnly.
  ///
  /// In en, this message translates to:
  /// **'Unregister only'**
  String get unregisterOnly;

  /// No description provided for @dropTable.
  ///
  /// In en, this message translates to:
  /// **'Drop table'**
  String get dropTable;

  /// No description provided for @addColumn.
  ///
  /// In en, this message translates to:
  /// **'Add column'**
  String get addColumn;

  /// No description provided for @addAtLeastOneColumn.
  ///
  /// In en, this message translates to:
  /// **'Add at least one column'**
  String get addAtLeastOneColumn;

  /// No description provided for @codeUsedInUrl.
  ///
  /// In en, this message translates to:
  /// **'Code (used in URL & API)'**
  String get codeUsedInUrl;

  /// No description provided for @sqlTableName.
  ///
  /// In en, this message translates to:
  /// **'SQL table name'**
  String get sqlTableName;

  /// No description provided for @displayLabelPlural.
  ///
  /// In en, this message translates to:
  /// **'Display label (plural)'**
  String get displayLabelPlural;

  /// No description provided for @singularName.
  ///
  /// In en, this message translates to:
  /// **'Singular name'**
  String get singularName;

  /// No description provided for @categoryField.
  ///
  /// In en, this message translates to:
  /// **'Category'**
  String get categoryField;

  /// No description provided for @iconNameField.
  ///
  /// In en, this message translates to:
  /// **'Icon name'**
  String get iconNameField;

  /// No description provided for @iconNameHint.
  ///
  /// In en, this message translates to:
  /// **'reports, business, store, …'**
  String get iconNameHint;

  /// No description provided for @columnsLabel.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columnsLabel;

  /// No description provided for @systemEntitiesAlterWarn.
  ///
  /// In en, this message translates to:
  /// **'System entities — column edits are not yet propagated to the SQL table. Use the Database admin to ALTER manually.'**
  String get systemEntitiesAlterWarn;

  /// No description provided for @updateLabel.
  ///
  /// In en, this message translates to:
  /// **'Update'**
  String get updateLabel;

  /// No description provided for @fieldNameSnakeCase.
  ///
  /// In en, this message translates to:
  /// **'Field name (snake_case)'**
  String get fieldNameSnakeCase;

  /// No description provided for @labelField.
  ///
  /// In en, this message translates to:
  /// **'Label'**
  String get labelField;

  /// No description provided for @requiredLabel.
  ///
  /// In en, this message translates to:
  /// **'Required'**
  String get requiredLabel;

  /// No description provided for @uniqueLabel.
  ///
  /// In en, this message translates to:
  /// **'Unique'**
  String get uniqueLabel;

  /// No description provided for @searchableLabel.
  ///
  /// In en, this message translates to:
  /// **'Searchable'**
  String get searchableLabel;

  /// No description provided for @showInList.
  ///
  /// In en, this message translates to:
  /// **'Show in list'**
  String get showInList;

  /// No description provided for @starterTablesCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No starter tables} =1{1 starter table} other{{count} starter tables}}'**
  String starterTablesCount(int count);

  /// No description provided for @columnsCount.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{No columns} =1{1 column} other{{count} columns}}'**
  String columnsCount(int count);

  /// No description provided for @reportSchedulesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Run any report on a recurring cadence. Results are stored on each schedule.'**
  String get reportSchedulesSubtitle;

  /// No description provided for @newSchedule.
  ///
  /// In en, this message translates to:
  /// **'New schedule'**
  String get newSchedule;

  /// No description provided for @noSchedulesYet.
  ///
  /// In en, this message translates to:
  /// **'No schedules yet. Click \"New schedule\".'**
  String get noSchedulesYet;

  /// No description provided for @runNow.
  ///
  /// In en, this message translates to:
  /// **'Run now'**
  String get runNow;

  /// No description provided for @recentRuns.
  ///
  /// In en, this message translates to:
  /// **'Recent runs'**
  String get recentRuns;

  /// No description provided for @runSucceeded.
  ///
  /// In en, this message translates to:
  /// **'Run succeeded'**
  String get runSucceeded;

  /// No description provided for @runFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Run failed: {error}'**
  String runFailedMsg(String error);

  /// No description provided for @deleteScheduleTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete schedule?'**
  String get deleteScheduleTitle;

  /// No description provided for @deleteScheduleBody.
  ///
  /// In en, this message translates to:
  /// **'This stops future runs and removes the schedule + its run history.'**
  String get deleteScheduleBody;

  /// No description provided for @recentRunsFor.
  ///
  /// In en, this message translates to:
  /// **'Recent runs — {name}'**
  String recentRunsFor(String name);

  /// No description provided for @noRunsYet.
  ///
  /// In en, this message translates to:
  /// **'No runs yet.'**
  String get noRunsYet;

  /// No description provided for @noReportsDefinedYet.
  ///
  /// In en, this message translates to:
  /// **'No reports defined yet.'**
  String get noReportsDefinedYet;

  /// No description provided for @templatesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Snapshot the current theme + custom tables. Re-apply later or share between installs.'**
  String get templatesSubtitle;

  /// No description provided for @templatesRestricted.
  ///
  /// In en, this message translates to:
  /// **'Templates are restricted to Super Admin.'**
  String get templatesRestricted;

  /// No description provided for @saveCurrentSetup.
  ///
  /// In en, this message translates to:
  /// **'Save current setup as template'**
  String get saveCurrentSetup;

  /// No description provided for @saveCurrent.
  ///
  /// In en, this message translates to:
  /// **'Save current'**
  String get saveCurrent;

  /// No description provided for @importJson.
  ///
  /// In en, this message translates to:
  /// **'Import JSON'**
  String get importJson;

  /// No description provided for @noTemplatesYet.
  ///
  /// In en, this message translates to:
  /// **'No templates yet.'**
  String get noTemplatesYet;

  /// No description provided for @applyTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Apply \"{name}\"?'**
  String applyTemplateTitle(String name);

  /// No description provided for @applyTemplateBody.
  ///
  /// In en, this message translates to:
  /// **'This will register all custom tables and activate the theme from the template. Existing tables with the same name are kept (only the registration is updated).'**
  String get applyTemplateBody;

  /// No description provided for @templateSaved.
  ///
  /// In en, this message translates to:
  /// **'Template saved'**
  String get templateSaved;

  /// No description provided for @templateApplied.
  ///
  /// In en, this message translates to:
  /// **'Template applied'**
  String get templateApplied;

  /// No description provided for @copiedJsonToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied JSON to clipboard'**
  String get copiedJsonToClipboard;

  /// No description provided for @exportFailed.
  ///
  /// In en, this message translates to:
  /// **'Export failed: {error}'**
  String exportFailed(String error);

  /// No description provided for @importTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Import template'**
  String get importTemplateTitle;

  /// No description provided for @templateImported.
  ///
  /// In en, this message translates to:
  /// **'Template imported'**
  String get templateImported;

  /// No description provided for @importFailed.
  ///
  /// In en, this message translates to:
  /// **'Import failed: {error}'**
  String importFailed(String error);

  /// No description provided for @invalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String invalidJson(String error);

  /// No description provided for @deleteTemplateTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete template'**
  String get deleteTemplateTitle;

  /// No description provided for @copyJson.
  ///
  /// In en, this message translates to:
  /// **'Copy JSON'**
  String get copyJson;

  /// No description provided for @applyAction.
  ///
  /// In en, this message translates to:
  /// **'Apply'**
  String get applyAction;

  /// No description provided for @pagesSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Custom pages composed from blocks. Designed in the page builder.'**
  String get pagesSubtitle;

  /// No description provided for @newPage.
  ///
  /// In en, this message translates to:
  /// **'New page'**
  String get newPage;

  /// No description provided for @noPagesYet.
  ///
  /// In en, this message translates to:
  /// **'No custom pages yet. Click \"New page\" to design one.'**
  String get noPagesYet;

  /// No description provided for @deletePageTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete page?'**
  String get deletePageTitle;

  /// No description provided for @deletePageBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the page and all its blocks.'**
  String get deletePageBody;

  /// No description provided for @openInBuilder.
  ///
  /// In en, this message translates to:
  /// **'Open in builder'**
  String get openInBuilder;

  /// No description provided for @openPage.
  ///
  /// In en, this message translates to:
  /// **'Open page'**
  String get openPage;

  /// No description provided for @pagesStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Pages'**
  String get pagesStatLabel;

  /// No description provided for @blocksStatLabel.
  ///
  /// In en, this message translates to:
  /// **'Blocks'**
  String get blocksStatLabel;

  /// No description provided for @avgBlocksPerPage.
  ///
  /// In en, this message translates to:
  /// **'Avg blocks / page'**
  String get avgBlocksPerPage;

  /// No description provided for @blockUsage.
  ///
  /// In en, this message translates to:
  /// **'Block usage'**
  String get blockUsage;

  /// No description provided for @addBlock.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get addBlock;

  /// No description provided for @emptyPageHint.
  ///
  /// In en, this message translates to:
  /// **'Empty page. Add blocks from the right panel.'**
  String get emptyPageHint;

  /// No description provided for @themeBuilderRestricted.
  ///
  /// In en, this message translates to:
  /// **'Theme Builder is restricted to Super Admin.'**
  String get themeBuilderRestricted;

  /// No description provided for @themeBuilderTitle.
  ///
  /// In en, this message translates to:
  /// **'Theme Builder'**
  String get themeBuilderTitle;

  /// No description provided for @themeBuilderEditing.
  ///
  /// In en, this message translates to:
  /// **'Editing \"{name}\"'**
  String themeBuilderEditing(String name);

  /// No description provided for @saveAndActivate.
  ///
  /// In en, this message translates to:
  /// **'Save & activate'**
  String get saveAndActivate;

  /// No description provided for @themeActivated.
  ///
  /// In en, this message translates to:
  /// **'Theme activated'**
  String get themeActivated;

  /// No description provided for @themeSavedMsg.
  ///
  /// In en, this message translates to:
  /// **'Theme saved'**
  String get themeSavedMsg;

  /// No description provided for @systemSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Server information, database connections, and configuration.'**
  String get systemSubtitle;

  /// No description provided for @databaseConnectionsHeader.
  ///
  /// In en, this message translates to:
  /// **'Database connections'**
  String get databaseConnectionsHeader;

  /// No description provided for @addConnectionLabel.
  ///
  /// In en, this message translates to:
  /// **'Add connection'**
  String get addConnectionLabel;

  /// No description provided for @noConnectionsYet.
  ///
  /// In en, this message translates to:
  /// **'No connections yet. Add one to switch the database from the UI.'**
  String get noConnectionsYet;

  /// No description provided for @primaryChip.
  ///
  /// In en, this message translates to:
  /// **'PRIMARY'**
  String get primaryChip;

  /// No description provided for @promoteToPrimary.
  ///
  /// In en, this message translates to:
  /// **'Promote to primary'**
  String get promoteToPrimary;

  /// No description provided for @promoteToPrimaryTitle.
  ///
  /// In en, this message translates to:
  /// **'Promote to primary?'**
  String get promoteToPrimaryTitle;

  /// No description provided for @promoteWarn.
  ///
  /// In en, this message translates to:
  /// **'This rewrites DATABASE_URL in .env. The server must be restarted before changes take effect, and the new database must already have the schema. A backup of the previous .env is kept under .env-backups/.'**
  String get promoteWarn;

  /// No description provided for @promoteAction.
  ///
  /// In en, this message translates to:
  /// **'Promote'**
  String get promoteAction;

  /// No description provided for @updatedRestartRequired.
  ///
  /// In en, this message translates to:
  /// **'Updated. Restart required.'**
  String get updatedRestartRequired;

  /// No description provided for @deleteConnectionTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete connection?'**
  String get deleteConnectionTitle;

  /// No description provided for @deleteConnectionBody.
  ///
  /// In en, this message translates to:
  /// **'Removes the saved connection from the registry. Does not affect the database itself.'**
  String get deleteConnectionBody;

  /// No description provided for @initDatabaseHeader.
  ///
  /// In en, this message translates to:
  /// **'Initialize database with SQL'**
  String get initDatabaseHeader;

  /// No description provided for @initDatabaseHint.
  ///
  /// In en, this message translates to:
  /// **'Paste CREATE TABLE / ALTER TABLE / INSERT statements separated by semicolons. Statements run in order.'**
  String get initDatabaseHint;

  /// No description provided for @runStatements.
  ///
  /// In en, this message translates to:
  /// **'Run statements'**
  String get runStatements;

  /// No description provided for @running.
  ///
  /// In en, this message translates to:
  /// **'Running…'**
  String get running;

  /// No description provided for @addDatabaseConnection.
  ///
  /// In en, this message translates to:
  /// **'Add database connection'**
  String get addDatabaseConnection;

  /// No description provided for @databaseSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Inspect tables, preview rows, run SQL. All queries are audited.'**
  String get databaseSubtitle;

  /// No description provided for @databaseRestricted.
  ///
  /// In en, this message translates to:
  /// **'Database admin is restricted to Super Admin.'**
  String get databaseRestricted;

  /// No description provided for @describeFailed.
  ///
  /// In en, this message translates to:
  /// **'Describe failed: {error}'**
  String describeFailed(String error);

  /// No description provided for @runWriteQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Run write query?'**
  String get runWriteQueryTitle;

  /// No description provided for @runWriteQueryBody.
  ///
  /// In en, this message translates to:
  /// **'You are about to run SQL with write mode enabled. Make sure you know what this does. Core auth tables are still protected.'**
  String get runWriteQueryBody;

  /// No description provided for @saveQueryTitle.
  ///
  /// In en, this message translates to:
  /// **'Save query'**
  String get saveQueryTitle;

  /// No description provided for @querySavedMsg.
  ///
  /// In en, this message translates to:
  /// **'Query saved'**
  String get querySavedMsg;

  /// No description provided for @sqlRunner.
  ///
  /// In en, this message translates to:
  /// **'SQL runner'**
  String get sqlRunner;

  /// No description provided for @writeMode.
  ///
  /// In en, this message translates to:
  /// **'Write mode'**
  String get writeMode;

  /// No description provided for @savedQueriesHeader.
  ///
  /// In en, this message translates to:
  /// **'Saved queries'**
  String get savedQueriesHeader;

  /// No description provided for @nothingSavedYet.
  ///
  /// In en, this message translates to:
  /// **'Nothing saved yet.'**
  String get nothingSavedYet;

  /// No description provided for @loadAction.
  ///
  /// In en, this message translates to:
  /// **'Load'**
  String get loadAction;

  /// No description provided for @noRowsReturnedMsg.
  ///
  /// In en, this message translates to:
  /// **'No rows returned ({count}).'**
  String noRowsReturnedMsg(String count);

  /// No description provided for @columnsHeader.
  ///
  /// In en, this message translates to:
  /// **'Columns'**
  String get columnsHeader;

  /// No description provided for @foreignKeysHeader.
  ///
  /// In en, this message translates to:
  /// **'Foreign keys'**
  String get foreignKeysHeader;

  /// No description provided for @previewHeader.
  ///
  /// In en, this message translates to:
  /// **'Preview (first {count} rows)'**
  String previewHeader(int count);

  /// No description provided for @editSubsystemTooltip.
  ///
  /// In en, this message translates to:
  /// **'Edit branding & modules'**
  String get editSubsystemTooltip;

  /// No description provided for @editSubsystemTitle.
  ///
  /// In en, this message translates to:
  /// **'Branding & modules — {name}'**
  String editSubsystemTitle(String name);

  /// No description provided for @brandingSection.
  ///
  /// In en, this message translates to:
  /// **'Branding'**
  String get brandingSection;

  /// No description provided for @modulesSection.
  ///
  /// In en, this message translates to:
  /// **'Modules'**
  String get modulesSection;

  /// No description provided for @modulesHelp.
  ///
  /// In en, this message translates to:
  /// **'Core modules (dashboard, users, etc.) are merged in automatically — list only the additional sidebar items this subsystem should expose.'**
  String get modulesHelp;

  /// No description provided for @subsystemSaved.
  ///
  /// In en, this message translates to:
  /// **'Subsystem settings saved'**
  String get subsystemSaved;

  /// No description provided for @appNameLabel.
  ///
  /// In en, this message translates to:
  /// **'App name'**
  String get appNameLabel;

  /// No description provided for @logoUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Logo URL'**
  String get logoUrlLabel;

  /// No description provided for @primaryColorLabel.
  ///
  /// In en, this message translates to:
  /// **'Primary color'**
  String get primaryColorLabel;

  /// No description provided for @iconPathLabel.
  ///
  /// In en, this message translates to:
  /// **'Icon path (.ico)'**
  String get iconPathLabel;

  /// No description provided for @addModuleLabel.
  ///
  /// In en, this message translates to:
  /// **'Add module code'**
  String get addModuleLabel;

  /// No description provided for @addBlockHeader.
  ///
  /// In en, this message translates to:
  /// **'Add block'**
  String get addBlockHeader;

  /// No description provided for @blockTypeText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get blockTypeText;

  /// No description provided for @blockTypeHeading.
  ///
  /// In en, this message translates to:
  /// **'Heading'**
  String get blockTypeHeading;

  /// No description provided for @blockTypeImage.
  ///
  /// In en, this message translates to:
  /// **'Image'**
  String get blockTypeImage;

  /// No description provided for @blockTypeButton.
  ///
  /// In en, this message translates to:
  /// **'Button'**
  String get blockTypeButton;

  /// No description provided for @blockTypeCard.
  ///
  /// In en, this message translates to:
  /// **'Card'**
  String get blockTypeCard;

  /// No description provided for @blockTypeContainer.
  ///
  /// In en, this message translates to:
  /// **'Container'**
  String get blockTypeContainer;

  /// No description provided for @blockTypeDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get blockTypeDivider;

  /// No description provided for @blockTypeSpacer.
  ///
  /// In en, this message translates to:
  /// **'Spacer'**
  String get blockTypeSpacer;

  /// No description provided for @blockTypeList.
  ///
  /// In en, this message translates to:
  /// **'List'**
  String get blockTypeList;

  /// No description provided for @blockTypeTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get blockTypeTable;

  /// No description provided for @blockTypeChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get blockTypeChart;

  /// No description provided for @blockTypeIframe.
  ///
  /// In en, this message translates to:
  /// **'Embed (iframe)'**
  String get blockTypeIframe;

  /// No description provided for @blockTypeHtml.
  ///
  /// In en, this message translates to:
  /// **'Raw HTML'**
  String get blockTypeHtml;

  /// No description provided for @blockTypeCustomEntityList.
  ///
  /// In en, this message translates to:
  /// **'Custom entity list'**
  String get blockTypeCustomEntityList;

  /// No description provided for @blockTypeReport.
  ///
  /// In en, this message translates to:
  /// **'Report'**
  String get blockTypeReport;

  /// No description provided for @inspectorEditTitle.
  ///
  /// In en, this message translates to:
  /// **'Edit {label}'**
  String inspectorEditTitle(String label);

  /// No description provided for @inspectorTitleText.
  ///
  /// In en, this message translates to:
  /// **'Edit Text'**
  String get inspectorTitleText;

  /// No description provided for @inspectorTitleHeading.
  ///
  /// In en, this message translates to:
  /// **'Edit Heading'**
  String get inspectorTitleHeading;

  /// No description provided for @inspectorTitleImage.
  ///
  /// In en, this message translates to:
  /// **'Edit Image'**
  String get inspectorTitleImage;

  /// No description provided for @inspectorTitleButton.
  ///
  /// In en, this message translates to:
  /// **'Edit Button'**
  String get inspectorTitleButton;

  /// No description provided for @inspectorTitleCard.
  ///
  /// In en, this message translates to:
  /// **'Edit Card'**
  String get inspectorTitleCard;

  /// No description provided for @inspectorTitleSpacer.
  ///
  /// In en, this message translates to:
  /// **'Edit Spacer'**
  String get inspectorTitleSpacer;

  /// No description provided for @inspectorTitleIframe.
  ///
  /// In en, this message translates to:
  /// **'Edit Iframe'**
  String get inspectorTitleIframe;

  /// No description provided for @inspectorTitleHtml.
  ///
  /// In en, this message translates to:
  /// **'Edit HTML'**
  String get inspectorTitleHtml;

  /// No description provided for @inspectorTitleReport.
  ///
  /// In en, this message translates to:
  /// **'Edit Report block'**
  String get inspectorTitleReport;

  /// No description provided for @inspectorTitleEntityList.
  ///
  /// In en, this message translates to:
  /// **'Edit Custom-entity list'**
  String get inspectorTitleEntityList;

  /// No description provided for @inspectorTitleDivider.
  ///
  /// In en, this message translates to:
  /// **'Divider'**
  String get inspectorTitleDivider;

  /// No description provided for @inspectorNoOptions.
  ///
  /// In en, this message translates to:
  /// **'No options to configure.'**
  String get inspectorNoOptions;

  /// No description provided for @inspectorLevelLabel.
  ///
  /// In en, this message translates to:
  /// **'Level'**
  String get inspectorLevelLabel;

  /// No description provided for @inspectorH1.
  ///
  /// In en, this message translates to:
  /// **'H1 — display'**
  String get inspectorH1;

  /// No description provided for @inspectorH2.
  ///
  /// In en, this message translates to:
  /// **'H2 — headline'**
  String get inspectorH2;

  /// No description provided for @inspectorH3.
  ///
  /// In en, this message translates to:
  /// **'H3 — title'**
  String get inspectorH3;

  /// No description provided for @inspectorH4.
  ///
  /// In en, this message translates to:
  /// **'H4 — subtitle'**
  String get inspectorH4;

  /// No description provided for @inspectorImageUrlHint.
  ///
  /// In en, this message translates to:
  /// **'https://example.com/photo.jpg or /uploads/x.png'**
  String get inspectorImageUrlHint;

  /// No description provided for @inspectorFitLabel.
  ///
  /// In en, this message translates to:
  /// **'Fit'**
  String get inspectorFitLabel;

  /// No description provided for @inspectorFitCover.
  ///
  /// In en, this message translates to:
  /// **'Cover'**
  String get inspectorFitCover;

  /// No description provided for @inspectorFitContain.
  ///
  /// In en, this message translates to:
  /// **'Contain'**
  String get inspectorFitContain;

  /// No description provided for @inspectorFitFill.
  ///
  /// In en, this message translates to:
  /// **'Fill'**
  String get inspectorFitFill;

  /// No description provided for @inspectorRouteLabel.
  ///
  /// In en, this message translates to:
  /// **'Route (e.g. /products)'**
  String get inspectorRouteLabel;

  /// No description provided for @inspectorStyleLabel.
  ///
  /// In en, this message translates to:
  /// **'Style'**
  String get inspectorStyleLabel;

  /// No description provided for @inspectorVariantFilled.
  ///
  /// In en, this message translates to:
  /// **'Filled'**
  String get inspectorVariantFilled;

  /// No description provided for @inspectorVariantOutlined.
  ///
  /// In en, this message translates to:
  /// **'Outlined'**
  String get inspectorVariantOutlined;

  /// No description provided for @inspectorVariantText.
  ///
  /// In en, this message translates to:
  /// **'Text'**
  String get inspectorVariantText;

  /// No description provided for @inspectorBodyLabel.
  ///
  /// In en, this message translates to:
  /// **'Body'**
  String get inspectorBodyLabel;

  /// No description provided for @inspectorHeightPxLabel.
  ///
  /// In en, this message translates to:
  /// **'Height (logical pixels)'**
  String get inspectorHeightPxLabel;

  /// No description provided for @inspectorHtmlNotice.
  ///
  /// In en, this message translates to:
  /// **'HTML is sanitized server-side. Scripts, on* handlers, and javascript: URLs are stripped.'**
  String get inspectorHtmlNotice;

  /// No description provided for @inspectorReportCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Report code (e.g. users.by_role)'**
  String get inspectorReportCodeLabel;

  /// No description provided for @inspectorRenderAsLabel.
  ///
  /// In en, this message translates to:
  /// **'Render as'**
  String get inspectorRenderAsLabel;

  /// No description provided for @inspectorRenderAsTable.
  ///
  /// In en, this message translates to:
  /// **'Table'**
  String get inspectorRenderAsTable;

  /// No description provided for @inspectorRenderAsChart.
  ///
  /// In en, this message translates to:
  /// **'Chart'**
  String get inspectorRenderAsChart;

  /// No description provided for @inspectorEntityCodeLabel.
  ///
  /// In en, this message translates to:
  /// **'Entity code (e.g. products)'**
  String get inspectorEntityCodeLabel;

  /// No description provided for @inspectorPageSizeLabel.
  ///
  /// In en, this message translates to:
  /// **'Page size'**
  String get inspectorPageSizeLabel;

  /// No description provided for @inspectorInvalidJson.
  ///
  /// In en, this message translates to:
  /// **'Invalid JSON: {error}'**
  String inspectorInvalidJson(String error);

  /// No description provided for @targetEntityLabel.
  ///
  /// In en, this message translates to:
  /// **'Target entity code'**
  String get targetEntityLabel;

  /// No description provided for @relationsAddLabel.
  ///
  /// In en, this message translates to:
  /// **'Add {target}'**
  String relationsAddLabel(String target);

  /// No description provided for @relationsLoadFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t load options'**
  String get relationsLoadFailed;

  /// No description provided for @relationsNoTarget.
  ///
  /// In en, this message translates to:
  /// **'No target entity configured'**
  String get relationsNoTarget;

  /// No description provided for @relationsEmpty.
  ///
  /// In en, this message translates to:
  /// **'—'**
  String get relationsEmpty;

  /// No description provided for @exportCsv.
  ///
  /// In en, this message translates to:
  /// **'Export CSV'**
  String get exportCsv;

  /// No description provided for @csvExportedTo.
  ///
  /// In en, this message translates to:
  /// **'Saved to {path}'**
  String csvExportedTo(String path);

  /// No description provided for @logoutEverywhereMenu.
  ///
  /// In en, this message translates to:
  /// **'Log out from all devices'**
  String get logoutEverywhereMenu;

  /// No description provided for @logoutEverywhereTitle.
  ///
  /// In en, this message translates to:
  /// **'Log out from all devices?'**
  String get logoutEverywhereTitle;

  /// No description provided for @logoutEverywhereBody.
  ///
  /// In en, this message translates to:
  /// **'This will end every active session for your account, on every device. You\'ll need to log in again on each one.'**
  String get logoutEverywhereBody;

  /// No description provided for @logoutEverywhereConfirm.
  ///
  /// In en, this message translates to:
  /// **'Log out everywhere'**
  String get logoutEverywhereConfirm;

  /// No description provided for @recordHistory.
  ///
  /// In en, this message translates to:
  /// **'History'**
  String get recordHistory;

  /// No description provided for @noHistoryYet.
  ///
  /// In en, this message translates to:
  /// **'No history yet for this record.'**
  String get noHistoryYet;

  /// No description provided for @systemActor.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get systemActor;

  /// No description provided for @formulaLabel.
  ///
  /// In en, this message translates to:
  /// **'Formula'**
  String get formulaLabel;

  /// No description provided for @formulaHelp.
  ///
  /// In en, this message translates to:
  /// **'Numeric expression. Use field names (qty, price) and operators + - * / ( ).'**
  String get formulaHelp;

  /// No description provided for @computedField.
  ///
  /// In en, this message translates to:
  /// **'Computed'**
  String get computedField;

  /// No description provided for @computedHelp.
  ///
  /// In en, this message translates to:
  /// **'This value is calculated automatically from other fields.'**
  String get computedHelp;

  /// No description provided for @importCsv.
  ///
  /// In en, this message translates to:
  /// **'Import CSV'**
  String get importCsv;

  /// No description provided for @importCsvHelp.
  ///
  /// In en, this message translates to:
  /// **'Paste CSV content. The first line must be a header row matching the entity\'s column names. Unknown columns are ignored. Run Preview first to see what would happen without writing anything.'**
  String get importCsvHelp;

  /// No description provided for @previewAction.
  ///
  /// In en, this message translates to:
  /// **'Preview'**
  String get previewAction;

  /// No description provided for @importAction.
  ///
  /// In en, this message translates to:
  /// **'Import'**
  String get importAction;

  /// No description provided for @previewBadge.
  ///
  /// In en, this message translates to:
  /// **'PREVIEW'**
  String get previewBadge;

  /// No description provided for @importSummary.
  ///
  /// In en, this message translates to:
  /// **'{total} rows • {created} created • {skipped} skipped • {errCount} errors'**
  String importSummary(int total, int created, int skipped, int errCount);

  /// No description provided for @bulkDeleteButton.
  ///
  /// In en, this message translates to:
  /// **'Delete {count}'**
  String bulkDeleteButton(int count);

  /// No description provided for @bulkDeleteTitle.
  ///
  /// In en, this message translates to:
  /// **'Delete selected rows?'**
  String get bulkDeleteTitle;

  /// No description provided for @bulkDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =1{Delete 1 row?} other{Delete {count} rows?}} This cannot be undone.'**
  String bulkDeleteConfirm(int count);

  /// No description provided for @bulkDeleteResult.
  ///
  /// In en, this message translates to:
  /// **'{count, plural, =0{Nothing deleted} =1{Deleted 1 row} other{Deleted {count} rows}}'**
  String bulkDeleteResult(int count);

  /// No description provided for @sessionsTitle.
  ///
  /// In en, this message translates to:
  /// **'Active devices'**
  String get sessionsTitle;

  /// No description provided for @sessionsSubtitle.
  ///
  /// In en, this message translates to:
  /// **'Sessions currently signed in to your account. Revoke any you don\'t recognize.'**
  String get sessionsSubtitle;

  /// No description provided for @noActiveSessions.
  ///
  /// In en, this message translates to:
  /// **'No active sessions.'**
  String get noActiveSessions;

  /// No description provided for @currentSessionBadge.
  ///
  /// In en, this message translates to:
  /// **'THIS DEVICE'**
  String get currentSessionBadge;

  /// No description provided for @sessionMeta.
  ///
  /// In en, this message translates to:
  /// **'Signed in {issuedAt} • Expires {expiresAt}'**
  String sessionMeta(String issuedAt, String expiresAt);

  /// No description provided for @revokeAction.
  ///
  /// In en, this message translates to:
  /// **'Revoke'**
  String get revokeAction;

  /// No description provided for @revokeSessionTitle.
  ///
  /// In en, this message translates to:
  /// **'Revoke this session?'**
  String get revokeSessionTitle;

  /// No description provided for @revokeSessionConfirm.
  ///
  /// In en, this message translates to:
  /// **'The device using this session will be signed out the next time it tries to refresh its access token.'**
  String get revokeSessionConfirm;

  /// No description provided for @revokeCurrentSessionWarn.
  ///
  /// In en, this message translates to:
  /// **'This is your current session. Revoking it will sign you out of this device immediately.'**
  String get revokeCurrentSessionWarn;

  /// No description provided for @sessionRevoked.
  ///
  /// In en, this message translates to:
  /// **'Session revoked.'**
  String get sessionRevoked;

  /// No description provided for @revokeFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t revoke: {error}'**
  String revokeFailed(String error);

  /// No description provided for @unknownDevice.
  ///
  /// In en, this message translates to:
  /// **'Unknown device'**
  String get unknownDevice;

  /// No description provided for @viewPermissionLabel.
  ///
  /// In en, this message translates to:
  /// **'View permission'**
  String get viewPermissionLabel;

  /// No description provided for @editPermissionLabel.
  ///
  /// In en, this message translates to:
  /// **'Edit permission'**
  String get editPermissionLabel;

  /// No description provided for @fieldPermissionHelp.
  ///
  /// In en, this message translates to:
  /// **'Optional permission code. Leave blank to inherit the entity\'s permissions.'**
  String get fieldPermissionHelp;

  /// No description provided for @generateResetToken.
  ///
  /// In en, this message translates to:
  /// **'Generate password reset token'**
  String get generateResetToken;

  /// No description provided for @generateResetTokenTitle.
  ///
  /// In en, this message translates to:
  /// **'Generate reset token?'**
  String get generateResetTokenTitle;

  /// No description provided for @generateResetTokenConfirm.
  ///
  /// In en, this message translates to:
  /// **'Generate a one-time password-reset token for \"{username}\"? The token is shown only once — copy it and share it with the user out-of-band.'**
  String generateResetTokenConfirm(String username);

  /// No description provided for @generate.
  ///
  /// In en, this message translates to:
  /// **'Generate'**
  String get generate;

  /// No description provided for @resetTokenFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t generate token: {error}'**
  String resetTokenFailed(String error);

  /// No description provided for @resetTokenDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset token for {username}'**
  String resetTokenDialogTitle(String username);

  /// No description provided for @resetTokenWarning.
  ///
  /// In en, this message translates to:
  /// **'Save this token now. It is shown only once and cannot be retrieved later.'**
  String get resetTokenWarning;

  /// No description provided for @resetTokenExpires.
  ///
  /// In en, this message translates to:
  /// **'Expires {when}'**
  String resetTokenExpires(String when);

  /// No description provided for @resetTokenLabel.
  ///
  /// In en, this message translates to:
  /// **'Token'**
  String get resetTokenLabel;

  /// No description provided for @resetUrlLabel.
  ///
  /// In en, this message translates to:
  /// **'Reset URL'**
  String get resetUrlLabel;

  /// No description provided for @copyToken.
  ///
  /// In en, this message translates to:
  /// **'Copy token'**
  String get copyToken;

  /// No description provided for @copyResetUrl.
  ///
  /// In en, this message translates to:
  /// **'Copy reset URL'**
  String get copyResetUrl;

  /// No description provided for @copiedToClipboard.
  ///
  /// In en, this message translates to:
  /// **'Copied to clipboard'**
  String get copiedToClipboard;

  /// No description provided for @resetPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Reset your password'**
  String get resetPasswordTitle;

  /// No description provided for @resetPasswordBody.
  ///
  /// In en, this message translates to:
  /// **'Enter the reset token your administrator gave you, then choose a new password.'**
  String get resetPasswordBody;

  /// No description provided for @resetTokenField.
  ///
  /// In en, this message translates to:
  /// **'Reset token'**
  String get resetTokenField;

  /// No description provided for @newPasswordField.
  ///
  /// In en, this message translates to:
  /// **'New password'**
  String get newPasswordField;

  /// No description provided for @confirmPasswordField.
  ///
  /// In en, this message translates to:
  /// **'Confirm password'**
  String get confirmPasswordField;

  /// No description provided for @passwordsMustMatch.
  ///
  /// In en, this message translates to:
  /// **'Passwords don\'t match'**
  String get passwordsMustMatch;

  /// No description provided for @resetPasswordAction.
  ///
  /// In en, this message translates to:
  /// **'Reset password'**
  String get resetPasswordAction;

  /// No description provided for @resetPasswordSuccess.
  ///
  /// In en, this message translates to:
  /// **'Password reset. Sign in with your new password.'**
  String get resetPasswordSuccess;

  /// No description provided for @resetPasswordFailedMsg.
  ///
  /// In en, this message translates to:
  /// **'Reset failed: {error}'**
  String resetPasswordFailedMsg(String error);

  /// No description provided for @twoFactorTitle.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication'**
  String get twoFactorTitle;

  /// No description provided for @twoFactorCodeHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the 6-digit code from your authenticator app.'**
  String get twoFactorCodeHint;

  /// No description provided for @twoFactorRecoveryHint.
  ///
  /// In en, this message translates to:
  /// **'Enter one of your recovery codes (10 hex chars, dashes optional).'**
  String get twoFactorRecoveryHint;

  /// No description provided for @twoFactorCodeField.
  ///
  /// In en, this message translates to:
  /// **'Authentication code'**
  String get twoFactorCodeField;

  /// No description provided for @recoveryCodeField.
  ///
  /// In en, this message translates to:
  /// **'Recovery code'**
  String get recoveryCodeField;

  /// No description provided for @useRecoveryInstead.
  ///
  /// In en, this message translates to:
  /// **'Use recovery code instead'**
  String get useRecoveryInstead;

  /// No description provided for @useTotpInstead.
  ///
  /// In en, this message translates to:
  /// **'Use authenticator code instead'**
  String get useTotpInstead;

  /// No description provided for @twoFactorEnabled.
  ///
  /// In en, this message translates to:
  /// **'Enabled'**
  String get twoFactorEnabled;

  /// No description provided for @twoFactorNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'Not enabled'**
  String get twoFactorNotEnabled;

  /// No description provided for @twoFactorEnabledOn.
  ///
  /// In en, this message translates to:
  /// **'Enabled on {when}'**
  String twoFactorEnabledOn(String when);

  /// No description provided for @enable2FA.
  ///
  /// In en, this message translates to:
  /// **'Enable 2FA'**
  String get enable2FA;

  /// No description provided for @disable2FA.
  ///
  /// In en, this message translates to:
  /// **'Disable 2FA'**
  String get disable2FA;

  /// No description provided for @enable2FAStep1.
  ///
  /// In en, this message translates to:
  /// **'Step 1: scan this QR with your authenticator app (or paste the secret manually).'**
  String get enable2FAStep1;

  /// No description provided for @enable2FAStep2.
  ///
  /// In en, this message translates to:
  /// **'Step 2: enter the 6-digit code your app shows to confirm.'**
  String get enable2FAStep2;

  /// No description provided for @secretLabel.
  ///
  /// In en, this message translates to:
  /// **'Secret'**
  String get secretLabel;

  /// No description provided for @copySecret.
  ///
  /// In en, this message translates to:
  /// **'Copy secret'**
  String get copySecret;

  /// No description provided for @recoveryCodesTitle.
  ///
  /// In en, this message translates to:
  /// **'Save your recovery codes'**
  String get recoveryCodesTitle;

  /// No description provided for @recoveryCodesBody.
  ///
  /// In en, this message translates to:
  /// **'Each code can be used once if you lose access to your authenticator. Save them somewhere safe — they won\'t be shown again.'**
  String get recoveryCodesBody;

  /// No description provided for @copyRecoveryCodes.
  ///
  /// In en, this message translates to:
  /// **'Copy all codes'**
  String get copyRecoveryCodes;

  /// No description provided for @twoFactorEnableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication is now enabled.'**
  String get twoFactorEnableSuccess;

  /// No description provided for @twoFactorDisableSuccess.
  ///
  /// In en, this message translates to:
  /// **'Two-factor authentication has been disabled.'**
  String get twoFactorDisableSuccess;

  /// No description provided for @twoFactorEnableFailed.
  ///
  /// In en, this message translates to:
  /// **'Verification failed. Try again with a fresh code from your authenticator.'**
  String get twoFactorEnableFailed;

  /// No description provided for @twoFactorDisableFailed.
  ///
  /// In en, this message translates to:
  /// **'Couldn\'t disable: {error}'**
  String twoFactorDisableFailed(String error);

  /// No description provided for @disable2FATitle.
  ///
  /// In en, this message translates to:
  /// **'Disable two-factor authentication?'**
  String get disable2FATitle;

  /// No description provided for @disable2FABody.
  ///
  /// In en, this message translates to:
  /// **'Enter your current authenticator code (or a recovery code) to confirm.'**
  String get disable2FABody;

  /// No description provided for @reset2FA.
  ///
  /// In en, this message translates to:
  /// **'Reset 2FA'**
  String get reset2FA;

  /// No description provided for @reset2FAConfirm.
  ///
  /// In en, this message translates to:
  /// **'Reset 2FA for \"{username}\"? This disables their two-factor authentication and removes their recovery codes. Use this when a user has lost their authenticator AND all recovery codes.'**
  String reset2FAConfirm(String username);

  /// No description provided for @reset2FASuccess.
  ///
  /// In en, this message translates to:
  /// **'2FA reset for {username}'**
  String reset2FASuccess(String username);

  /// No description provided for @reset2FAWasNotEnabled.
  ///
  /// In en, this message translates to:
  /// **'{username} did not have 2FA enabled — nothing to reset.'**
  String reset2FAWasNotEnabled(String username);

  /// No description provided for @forgotPasswordTitle.
  ///
  /// In en, this message translates to:
  /// **'Forgot password'**
  String get forgotPasswordTitle;

  /// No description provided for @forgotPasswordLink.
  ///
  /// In en, this message translates to:
  /// **'Forgot password?'**
  String get forgotPasswordLink;

  /// No description provided for @forgotPasswordPrompt.
  ///
  /// In en, this message translates to:
  /// **'Enter your username or email. If the account exists, we\'ll send a one-time reset link.'**
  String get forgotPasswordPrompt;

  /// No description provided for @sending.
  ///
  /// In en, this message translates to:
  /// **'Sending…'**
  String get sending;

  /// No description provided for @sendResetLink.
  ///
  /// In en, this message translates to:
  /// **'Send reset link'**
  String get sendResetLink;

  /// No description provided for @backToSignIn.
  ///
  /// In en, this message translates to:
  /// **'Back to sign in'**
  String get backToSignIn;

  /// No description provided for @checkYourEmail.
  ///
  /// In en, this message translates to:
  /// **'Check your email'**
  String get checkYourEmail;

  /// No description provided for @resetLinkSentMessage.
  ///
  /// In en, this message translates to:
  /// **'If an account exists for that username or email, a reset link has been sent. The link is valid for the next hour and can only be used once.'**
  String get resetLinkSentMessage;

  /// No description provided for @emailNotConfiguredOnServer.
  ///
  /// In en, this message translates to:
  /// **'Email isn\'t configured on this server. Ask an admin to reset your password manually.'**
  String get emailNotConfiguredOnServer;

  /// No description provided for @somethingWentWrongDetail.
  ///
  /// In en, this message translates to:
  /// **'Something went wrong: {error}'**
  String somethingWentWrongDetail(String error);
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['ar', 'en', 'fr'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'ar':
      return AppLocalizationsAr();
    case 'en':
      return AppLocalizationsEn();
    case 'fr':
      return AppLocalizationsFr();
  }

  throw FlutterError(
      'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
      'an issue with the localizations generation tool. Please file an issue '
      'on GitHub with a reproducible sample app and the gen-l10n configuration '
      'that was used.');
}
