// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get appName => 'TatbeeqX';

  @override
  String get signIn => 'Sign in';

  @override
  String get signInToContinue => 'Sign in to continue';

  @override
  String get usernameOrEmail => 'Username or email';

  @override
  String get password => 'Password';

  @override
  String get signOut => 'Sign out';

  @override
  String get loginTagline => 'LAN-ready • secured by JWT';

  @override
  String get manageEveryBusiness => 'Manage every business,';

  @override
  String get inOnePlace => 'in one place.';

  @override
  String get loginHeroSubtitle =>
      'Multi-company, multi-branch, role-based, fully customizable.';

  @override
  String get save => 'Save';

  @override
  String get cancel => 'Cancel';

  @override
  String get delete => 'Delete';

  @override
  String get edit => 'Edit';

  @override
  String get create => 'Create';

  @override
  String get newItem => 'New';

  @override
  String get search => 'Search';

  @override
  String get loading => 'Loading…';

  @override
  String get error => 'Error';

  @override
  String get noData => 'No data';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Yes';

  @override
  String get no => 'No';

  @override
  String get refresh => 'Refresh';

  @override
  String get saving => 'Saving…';

  @override
  String get required => 'Required';

  @override
  String get company => 'Company';

  @override
  String get noCompany => 'No company';

  @override
  String get globalTheme => '— Global theme —';

  @override
  String get switchCompany => 'Switch company';

  @override
  String get language => 'Language';

  @override
  String get account => 'Account';

  @override
  String get superAdmin => 'Super Admin';

  @override
  String get user => 'User';

  @override
  String get dashboard => 'Dashboard';

  @override
  String get users => 'Users';

  @override
  String get roles => 'Roles';

  @override
  String get companies => 'Companies';

  @override
  String get branches => 'Branches';

  @override
  String get audit => 'Audit Logs';

  @override
  String get settings => 'Settings';

  @override
  String get appearance => 'Appearance';

  @override
  String get reports => 'Reports';

  @override
  String get database => 'Database';

  @override
  String get customEntities => 'Custom entities';

  @override
  String get templates => 'Templates';

  @override
  String get pages => 'Pages';

  @override
  String get system => 'System';

  @override
  String get systemLogs => 'System Logs';

  @override
  String get loginActivity => 'Login Activity';

  @override
  String get approvals => 'Approvals';

  @override
  String get reportSchedules => 'Report Schedules';

  @override
  String get webhooks => 'Webhooks';

  @override
  String get backups => 'Backups';

  @override
  String deleteConfirm(String name) {
    return 'Delete \"$name\"?';
  }

  @override
  String loadFailed(String error) {
    return 'Load failed: $error';
  }

  @override
  String saveFailed(String error) {
    return 'Save failed: $error';
  }

  @override
  String deleteFailedMsg(String error) {
    return 'Delete failed: $error';
  }

  @override
  String createFailed(String error) {
    return 'Create failed: $error';
  }

  @override
  String adminRestricted(String feature) {
    return '$feature is restricted to Super Admin';
  }

  @override
  String get apply => 'Apply';

  @override
  String get activate => 'Activate';

  @override
  String get duplicate => 'Duplicate';

  @override
  String get resetLabel => 'Reset';

  @override
  String get run => 'Run';

  @override
  String get importLabel => 'Import';

  @override
  String get exportLabel => 'Export';

  @override
  String get add => 'Add';

  @override
  String get remove => 'Remove';

  @override
  String get close => 'Close';

  @override
  String get back => 'Back';

  @override
  String get name => 'Name';

  @override
  String get code => 'Code';

  @override
  String get email => 'Email';

  @override
  String get statusLabel => 'Status';

  @override
  String get typeLabel => 'Type';

  @override
  String get defaultLabel => 'Default';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get systemChip => 'System';

  @override
  String get enabledLabel => 'Enabled';

  @override
  String get disabledLabel => 'Disabled';

  @override
  String get active => 'Active';

  @override
  String get inactive => 'Inactive';

  @override
  String get all => 'All';

  @override
  String get noneLabel => 'None';

  @override
  String pageOfTotal(int page, int total) {
    return 'Page $page of $total';
  }

  @override
  String permissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
      zero: 'No permissions',
    );
    return '$_temp0';
  }

  @override
  String usersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count users',
      one: '1 user',
      zero: 'No users',
    );
    return '$_temp0';
  }

  @override
  String get rolesSubtitle => 'Define roles and assign granular permissions.';

  @override
  String get auditSubtitle => 'A timeline of every important system action.';

  @override
  String get backupsSubtitle =>
      'Snapshots of the primary database. Restore overwrites the current DB and requires a restart.';

  @override
  String get reportsSubtitle =>
      'Pre-built reports. Run them to view fresh data.';

  @override
  String get dashboardSubtitle => 'Here is a quick overview of your system.';

  @override
  String get loginFailed => 'Login failed';

  @override
  String get searchHint => 'Search…';

  @override
  String totalLabel(int count) {
    return '$count total';
  }

  @override
  String fileNotFound(String path) {
    return 'File not found: $path';
  }

  @override
  String get uploaded => 'Uploaded';

  @override
  String uploadFailed(String error) {
    return 'Upload failed: $error';
  }

  @override
  String get upload => 'Upload';

  @override
  String get uploading => 'Uploading…';

  @override
  String get uploadHint =>
      '…or paste a local file path (e.g. C:\\images\\logo.png) and press Upload';

  @override
  String get urlHint => 'URL';

  @override
  String get restore => 'Restore';

  @override
  String get auditWhen => 'When';

  @override
  String get auditUser => 'User';

  @override
  String get auditAction => 'Action';

  @override
  String get auditEntity => 'Entity';

  @override
  String get auditId => 'ID';

  @override
  String get auditIp => 'IP';

  @override
  String get systemUserLabel => 'system';

  @override
  String get createBackup => 'Create backup';

  @override
  String get backupLabelField => 'Label (optional, lowercase + dashes)';

  @override
  String get backupLabelExample => 'e.g. before-month-end';

  @override
  String get deleteBackupTitle => 'Delete backup?';

  @override
  String deleteBackupWarn(String name) {
    return 'This permanently removes \"$name\" from disk.';
  }

  @override
  String get restoreBackupTitle => 'Restore backup?';

  @override
  String restoreBackupWarn(String name) {
    return 'This overwrites the current database with \"$name\". After restore, the API process must be restarted before changes take effect.\n\nData created since this backup will be lost.';
  }

  @override
  String get restoreCompleteRestart => 'Restore complete. Restart required.';

  @override
  String get noBackupsYet => 'No backups yet. Click \"New backup\".';

  @override
  String get noReportsDefined => 'No reports defined';

  @override
  String get noPermissionReports =>
      'You do not have permission to view reports.';

  @override
  String get auditEventsLast14 => 'Audit events — last 14 days';

  @override
  String get auditByEntityLast30 => 'Audit by entity — last 30 days';

  @override
  String get recentLogins => 'Recent logins';

  @override
  String get recentAuditEvents => 'Recent audit events';

  @override
  String get noActivityYet => 'No activity yet';

  @override
  String get noDataYet => 'No data yet';

  @override
  String get noAuditEntriesYet => 'No audit entries yet';

  @override
  String get auditEventsCount => 'Audit events';

  @override
  String failedShort(String error) {
    return 'Failed: $error';
  }

  @override
  String get username => 'Username';

  @override
  String get fullName => 'Full name';

  @override
  String get phoneOptional => 'Phone (optional)';

  @override
  String get phone => 'Phone';

  @override
  String get address => 'Address';

  @override
  String get legalName => 'Legal name';

  @override
  String get taxNumber => 'Tax number';

  @override
  String get logoUrl => 'Logo URL';

  @override
  String get passwordField => 'Password';

  @override
  String get newPasswordKeepBlank => 'New password (leave blank to keep)';

  @override
  String get min8Chars => 'Min 8 characters';

  @override
  String get invalidEmail => 'Invalid email';

  @override
  String get noneOption => '— None —';

  @override
  String get branchField => 'Branch';

  @override
  String get companyField => 'Company';

  @override
  String get rolesField => 'Roles';

  @override
  String deleteCannotBeUndone(String name) {
    return 'Delete \"$name\"? This cannot be undone.';
  }

  @override
  String deleteCascadeWarn(String name) {
    return 'Delete \"$name\"? Branches and related data will cascade.';
  }

  @override
  String get selectCompany => 'Select a company';

  @override
  String get noBranches => 'No branches';

  @override
  String branchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count branches',
      one: '1 branch',
      zero: 'No branches',
    );
    return '$_temp0';
  }

  @override
  String get usersSubtitle => 'Create and manage system users.';

  @override
  String get newUser => 'New user';

  @override
  String get editUser => 'Edit user';

  @override
  String get deleteUser => 'Delete user';

  @override
  String get searchUsers => 'Search users…';

  @override
  String get companiesSubtitle =>
      'Each company can have its own branches, users, and theme.';

  @override
  String get newCompany => 'New company';

  @override
  String get editCompany => 'Edit company';

  @override
  String get deleteCompany => 'Delete company';

  @override
  String codeColon(String code) {
    return 'Code: $code';
  }

  @override
  String get branchesSubtitle => 'Branches belong to companies.';

  @override
  String get newBranch => 'New branch';

  @override
  String get editBranch => 'Edit branch';

  @override
  String get deleteBranch => 'Delete branch';

  @override
  String get settingsSubtitle =>
      'System-wide key/value settings. Anything marked \"public\" is visible without auth.';

  @override
  String get addRow => 'Add row';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get keyField => 'Key';

  @override
  String get valueField => 'Value';

  @override
  String get typeField => 'Type';

  @override
  String get publicLabel => 'Public';

  @override
  String get noSettingsYet => 'No settings yet';

  @override
  String get loginActivitySubtitle =>
      'Every login, refresh, logout, and failed attempt.';

  @override
  String get eventField => 'Event';

  @override
  String get allEvents => 'All events';

  @override
  String get loginEvent => 'Login';

  @override
  String get logoutEvent => 'Logout';

  @override
  String get refreshEvent => 'Refresh';

  @override
  String get successField => 'Success';

  @override
  String get successfulOption => 'Successful';

  @override
  String get failedOption => 'Failed';

  @override
  String get searchLoginEvents => 'Search by username, IP, or user agent…';

  @override
  String get resultColumn => 'Result';

  @override
  String get okShort => 'OK';

  @override
  String get failShort => 'FAIL';

  @override
  String get reasonColumn => 'Reason';

  @override
  String get systemLogsSubtitle =>
      'Server-side events: startup, errors, warnings, info.';

  @override
  String get clearOlderThan30 => 'Clear older than 30 days';

  @override
  String get clearOldLogsTitle => 'Clear old logs?';

  @override
  String get clearOldLogsBody =>
      'Delete every system log older than 30 days. This cannot be undone.';

  @override
  String get levelField => 'Level';

  @override
  String get allLevels => 'All levels';

  @override
  String get levelDebug => 'Debug';

  @override
  String get levelInfo => 'Info';

  @override
  String get levelWarn => 'Warning';

  @override
  String get levelError => 'Error';

  @override
  String get sourceField => 'Source';

  @override
  String get searchMessageContext => 'Search message or context…';

  @override
  String get messageField => 'Message';

  @override
  String get webhooksSubtitle =>
      'POST notifications to external URLs when system events fire. HMAC-signed.';

  @override
  String get newWebhook => 'New webhook';

  @override
  String get noSubscriptionsYet => 'No subscriptions yet.';

  @override
  String get enableLabel => 'Enable';

  @override
  String get disableLabel => 'Disable';

  @override
  String get sendTestEvent => 'Send test event';

  @override
  String get recentDeliveries => 'Recent deliveries';

  @override
  String get testEventDispatched => 'Test event dispatched';

  @override
  String get deleteSubscriptionTitle => 'Delete subscription?';

  @override
  String get deleteSubscriptionBody =>
      'Removes the subscription and all delivery history.';

  @override
  String recentDeliveriesFor(String name) {
    return 'Recent deliveries — $name';
  }

  @override
  String get noDeliveriesYet => 'No deliveries yet.';

  @override
  String get newWebhookSubscription => 'New webhook subscription';

  @override
  String get codeLowerSnake => 'Code (lowercase, snake_case)';

  @override
  String get urlHttps => 'URL (https://...)';

  @override
  String get secretOptionalAuto =>
      'Secret (optional — auto-generated if blank)';

  @override
  String get eventsLabel => 'Events';

  @override
  String get pickAtLeastOneEvent => 'Pick at least one event';

  @override
  String get webhookSecretTitle => 'Webhook secret';

  @override
  String webhookSecretSaveWarn(String secret) {
    return 'Save this secret somewhere safe — it will not be shown again:\n\n$secret';
  }

  @override
  String get approvalsSubtitle =>
      'Pending requests waiting for someone with <entity>.approve.';

  @override
  String get newRequest => 'New request';

  @override
  String get statusPending => 'Pending';

  @override
  String get statusApproved => 'Approved';

  @override
  String get statusRejected => 'Rejected';

  @override
  String get statusCancelled => 'Cancelled';

  @override
  String get approveLabel => 'Approve';

  @override
  String get rejectLabel => 'Reject';

  @override
  String get approveTitle => 'Approve request?';

  @override
  String get rejectTitle => 'Reject request?';

  @override
  String get noteOptional => 'Note (optional)';

  @override
  String get requestApproval => 'Request approval';

  @override
  String get entityProductsHint => 'Entity (e.g. products)';

  @override
  String get titleField => 'Title';

  @override
  String get submitLabel => 'Submit';

  @override
  String get approvalsRequestedBy => 'Requested by';

  @override
  String get approvalsTitleColumn => 'Title';

  @override
  String get setupLocked =>
      'Setup is locked. Ask the Super Admin to choose a business type.';

  @override
  String get welcomePickBusinessType => 'Welcome — pick a business type';

  @override
  String get setupExplain =>
      'This decides the starter modules, tables and menus. You can always change everything later, add new tables and run SQL from the Database admin page.';

  @override
  String get alreadyConfiguredHint =>
      'Already configured? Visit the Custom Entities and Database pages to add new tables, edit columns or run SQL.';

  @override
  String get skipAndContinue => 'Skip and continue';

  @override
  String get useThis => 'Use this';

  @override
  String applyFailed(String error) {
    return 'Apply failed: $error';
  }

  @override
  String get deleteRowTitle => 'Delete row';

  @override
  String newEntitySingular(String singular) {
    return 'New $singular';
  }

  @override
  String editEntitySingular(String singular) {
    return 'Edit $singular';
  }

  @override
  String tableLabel(String tableName) {
    return 'Table: $tableName';
  }

  @override
  String searchEntityHint(String label) {
    return 'Search $label…';
  }

  @override
  String get customEntitiesAdminRestricted =>
      'Custom Entities admin is restricted to Super Admin.';

  @override
  String get customEntitiesSubtitle =>
      'Tables tailored to your business. Each entity gets its own permissions, menu item and CRUD page.';

  @override
  String get newEntity => 'New entity';

  @override
  String get editEntity => 'Edit entity';

  @override
  String get noCustomEntitiesYet => 'No custom entities yet.';

  @override
  String deleteEntityTitle(String label) {
    return 'Delete \"$label\"';
  }

  @override
  String get deleteEntityBody =>
      'You can either keep the underlying table (data preserved, only the registration is removed) or drop it (irreversible).';

  @override
  String get unregisterOnly => 'Unregister only';

  @override
  String get dropTable => 'Drop table';

  @override
  String get addColumn => 'Add column';

  @override
  String get addAtLeastOneColumn => 'Add at least one column';

  @override
  String get codeUsedInUrl => 'Code (used in URL & API)';

  @override
  String get sqlTableName => 'SQL table name';

  @override
  String get displayLabelPlural => 'Display label (plural)';

  @override
  String get singularName => 'Singular name';

  @override
  String get categoryField => 'Category';

  @override
  String get iconNameField => 'Icon name';

  @override
  String get iconNameHint => 'reports, business, store, …';

  @override
  String get columnsLabel => 'Columns';

  @override
  String get systemEntitiesAlterWarn =>
      'System entities — column edits are not yet propagated to the SQL table. Use the Database admin to ALTER manually.';

  @override
  String get updateLabel => 'Update';

  @override
  String get fieldNameSnakeCase => 'Field name (snake_case)';

  @override
  String get labelField => 'Label';

  @override
  String get requiredLabel => 'Required';

  @override
  String get uniqueLabel => 'Unique';

  @override
  String get searchableLabel => 'Searchable';

  @override
  String get showInList => 'Show in list';

  @override
  String starterTablesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count starter tables',
      one: '1 starter table',
      zero: 'No starter tables',
    );
    return '$_temp0';
  }

  @override
  String columnsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count columns',
      one: '1 column',
      zero: 'No columns',
    );
    return '$_temp0';
  }

  @override
  String get reportSchedulesSubtitle =>
      'Run any report on a recurring cadence. Results are stored on each schedule.';

  @override
  String get newSchedule => 'New schedule';

  @override
  String get noSchedulesYet => 'No schedules yet. Click \"New schedule\".';

  @override
  String get runNow => 'Run now';

  @override
  String get recentRuns => 'Recent runs';

  @override
  String get runSucceeded => 'Run succeeded';

  @override
  String runFailedMsg(String error) {
    return 'Run failed: $error';
  }

  @override
  String get deleteScheduleTitle => 'Delete schedule?';

  @override
  String get deleteScheduleBody =>
      'This stops future runs and removes the schedule + its run history.';

  @override
  String recentRunsFor(String name) {
    return 'Recent runs — $name';
  }

  @override
  String get noRunsYet => 'No runs yet.';

  @override
  String get noReportsDefinedYet => 'No reports defined yet.';

  @override
  String get templatesSubtitle =>
      'Snapshot the current theme + custom tables. Re-apply later or share between installs.';

  @override
  String get templatesRestricted => 'Templates are restricted to Super Admin.';

  @override
  String get saveCurrentSetup => 'Save current setup as template';

  @override
  String get saveCurrent => 'Save current';

  @override
  String get importJson => 'Import JSON';

  @override
  String get noTemplatesYet => 'No templates yet.';

  @override
  String applyTemplateTitle(String name) {
    return 'Apply \"$name\"?';
  }

  @override
  String get applyTemplateBody =>
      'This will register all custom tables and activate the theme from the template. Existing tables with the same name are kept (only the registration is updated).';

  @override
  String get templateSaved => 'Template saved';

  @override
  String get templateApplied => 'Template applied';

  @override
  String get copiedJsonToClipboard => 'Copied JSON to clipboard';

  @override
  String exportFailed(String error) {
    return 'Export failed: $error';
  }

  @override
  String get importTemplateTitle => 'Import template';

  @override
  String get templateImported => 'Template imported';

  @override
  String importFailed(String error) {
    return 'Import failed: $error';
  }

  @override
  String invalidJson(String error) {
    return 'Invalid JSON: $error';
  }

  @override
  String get deleteTemplateTitle => 'Delete template';

  @override
  String get copyJson => 'Copy JSON';

  @override
  String get applyAction => 'Apply';

  @override
  String get pagesSubtitle =>
      'Custom pages composed from blocks. Designed in the page builder.';

  @override
  String get newPage => 'New page';

  @override
  String get noPagesYet =>
      'No custom pages yet. Click \"New page\" to design one.';

  @override
  String get deletePageTitle => 'Delete page?';

  @override
  String get deletePageBody => 'Removes the page and all its blocks.';

  @override
  String get openInBuilder => 'Open in builder';

  @override
  String get openPage => 'Open page';

  @override
  String get pagesStatLabel => 'Pages';

  @override
  String get blocksStatLabel => 'Blocks';

  @override
  String get avgBlocksPerPage => 'Avg blocks / page';

  @override
  String get blockUsage => 'Block usage';

  @override
  String get addBlock => 'Add block';

  @override
  String get emptyPageHint => 'Empty page. Add blocks from the right panel.';

  @override
  String get themeBuilderRestricted =>
      'Theme Builder is restricted to Super Admin.';

  @override
  String get themeBuilderTitle => 'Theme Builder';

  @override
  String themeBuilderEditing(String name) {
    return 'Editing \"$name\"';
  }

  @override
  String get saveAndActivate => 'Save & activate';

  @override
  String get themeActivated => 'Theme activated';

  @override
  String get themeSavedMsg => 'Theme saved';

  @override
  String get systemSubtitle =>
      'Server information, database connections, and configuration.';

  @override
  String get databaseConnectionsHeader => 'Database connections';

  @override
  String get addConnectionLabel => 'Add connection';

  @override
  String get noConnectionsYet =>
      'No connections yet. Add one to switch the database from the UI.';

  @override
  String get primaryChip => 'PRIMARY';

  @override
  String get promoteToPrimary => 'Promote to primary';

  @override
  String get promoteToPrimaryTitle => 'Promote to primary?';

  @override
  String get promoteWarn =>
      'This rewrites DATABASE_URL in .env. The server must be restarted before changes take effect, and the new database must already have the schema. A backup of the previous .env is kept under .env-backups/.';

  @override
  String get promoteAction => 'Promote';

  @override
  String get updatedRestartRequired => 'Updated. Restart required.';

  @override
  String get deleteConnectionTitle => 'Delete connection?';

  @override
  String get deleteConnectionBody =>
      'Removes the saved connection from the registry. Does not affect the database itself.';

  @override
  String get initDatabaseHeader => 'Initialize database with SQL';

  @override
  String get initDatabaseHint =>
      'Paste CREATE TABLE / ALTER TABLE / INSERT statements separated by semicolons. Statements run in order.';

  @override
  String get runStatements => 'Run statements';

  @override
  String get running => 'Running…';

  @override
  String get addDatabaseConnection => 'Add database connection';

  @override
  String get databaseSubtitle =>
      'Inspect tables, preview rows, run SQL. All queries are audited.';

  @override
  String get databaseRestricted =>
      'Database admin is restricted to Super Admin.';

  @override
  String describeFailed(String error) {
    return 'Describe failed: $error';
  }

  @override
  String get runWriteQueryTitle => 'Run write query?';

  @override
  String get runWriteQueryBody =>
      'You are about to run SQL with write mode enabled. Make sure you know what this does. Core auth tables are still protected.';

  @override
  String get saveQueryTitle => 'Save query';

  @override
  String get querySavedMsg => 'Query saved';

  @override
  String get sqlRunner => 'SQL runner';

  @override
  String get writeMode => 'Write mode';

  @override
  String get savedQueriesHeader => 'Saved queries';

  @override
  String get nothingSavedYet => 'Nothing saved yet.';

  @override
  String get loadAction => 'Load';

  @override
  String noRowsReturnedMsg(String count) {
    return 'No rows returned ($count).';
  }

  @override
  String get columnsHeader => 'Columns';

  @override
  String get foreignKeysHeader => 'Foreign keys';

  @override
  String previewHeader(int count) {
    return 'Preview (first $count rows)';
  }

  @override
  String get editSubsystemTooltip => 'Edit branding & modules';

  @override
  String editSubsystemTitle(String name) {
    return 'Branding & modules — $name';
  }

  @override
  String get brandingSection => 'Branding';

  @override
  String get modulesSection => 'Modules';

  @override
  String get modulesHelp =>
      'Core modules (dashboard, users, etc.) are merged in automatically — list only the additional sidebar items this subsystem should expose.';

  @override
  String get subsystemSaved => 'Subsystem settings saved';

  @override
  String get appNameLabel => 'App name';

  @override
  String get logoUrlLabel => 'Logo URL';

  @override
  String get primaryColorLabel => 'Primary color';

  @override
  String get iconPathLabel => 'Icon path (.ico)';

  @override
  String get addModuleLabel => 'Add module code';

  @override
  String get addBlockHeader => 'Add block';

  @override
  String get blockTypeText => 'Text';

  @override
  String get blockTypeHeading => 'Heading';

  @override
  String get blockTypeImage => 'Image';

  @override
  String get blockTypeButton => 'Button';

  @override
  String get blockTypeCard => 'Card';

  @override
  String get blockTypeContainer => 'Container';

  @override
  String get blockTypeDivider => 'Divider';

  @override
  String get blockTypeSpacer => 'Spacer';

  @override
  String get blockTypeList => 'List';

  @override
  String get blockTypeTable => 'Table';

  @override
  String get blockTypeChart => 'Chart';

  @override
  String get blockTypeIframe => 'Embed (iframe)';

  @override
  String get blockTypeHtml => 'Raw HTML';

  @override
  String get blockTypeCustomEntityList => 'Custom entity list';

  @override
  String get blockTypeReport => 'Report';

  @override
  String inspectorEditTitle(String label) {
    return 'Edit $label';
  }

  @override
  String get inspectorTitleText => 'Edit Text';

  @override
  String get inspectorTitleHeading => 'Edit Heading';

  @override
  String get inspectorTitleImage => 'Edit Image';

  @override
  String get inspectorTitleButton => 'Edit Button';

  @override
  String get inspectorTitleCard => 'Edit Card';

  @override
  String get inspectorTitleSpacer => 'Edit Spacer';

  @override
  String get inspectorTitleIframe => 'Edit Iframe';

  @override
  String get inspectorTitleHtml => 'Edit HTML';

  @override
  String get inspectorTitleReport => 'Edit Report block';

  @override
  String get inspectorTitleEntityList => 'Edit Custom-entity list';

  @override
  String get inspectorTitleDivider => 'Divider';

  @override
  String get inspectorNoOptions => 'No options to configure.';

  @override
  String get inspectorLevelLabel => 'Level';

  @override
  String get inspectorH1 => 'H1 — display';

  @override
  String get inspectorH2 => 'H2 — headline';

  @override
  String get inspectorH3 => 'H3 — title';

  @override
  String get inspectorH4 => 'H4 — subtitle';

  @override
  String get inspectorImageUrlHint =>
      'https://example.com/photo.jpg or /uploads/x.png';

  @override
  String get inspectorFitLabel => 'Fit';

  @override
  String get inspectorFitCover => 'Cover';

  @override
  String get inspectorFitContain => 'Contain';

  @override
  String get inspectorFitFill => 'Fill';

  @override
  String get inspectorRouteLabel => 'Route (e.g. /products)';

  @override
  String get inspectorStyleLabel => 'Style';

  @override
  String get inspectorVariantFilled => 'Filled';

  @override
  String get inspectorVariantOutlined => 'Outlined';

  @override
  String get inspectorVariantText => 'Text';

  @override
  String get inspectorBodyLabel => 'Body';

  @override
  String get inspectorHeightPxLabel => 'Height (logical pixels)';

  @override
  String get inspectorHtmlNotice =>
      'HTML is sanitized server-side. Scripts, on* handlers, and javascript: URLs are stripped.';

  @override
  String get inspectorReportCodeLabel => 'Report code (e.g. users.by_role)';

  @override
  String get inspectorRenderAsLabel => 'Render as';

  @override
  String get inspectorRenderAsTable => 'Table';

  @override
  String get inspectorRenderAsChart => 'Chart';

  @override
  String get inspectorEntityCodeLabel => 'Entity code (e.g. products)';

  @override
  String get inspectorPageSizeLabel => 'Page size';

  @override
  String inspectorInvalidJson(String error) {
    return 'Invalid JSON: $error';
  }

  @override
  String get targetEntityLabel => 'Target entity code';

  @override
  String relationsAddLabel(String target) {
    return 'Add $target';
  }

  @override
  String get relationsLoadFailed => 'Couldn\'t load options';

  @override
  String get relationsNoTarget => 'No target entity configured';

  @override
  String get relationsEmpty => '—';

  @override
  String get exportCsv => 'Export CSV';

  @override
  String csvExportedTo(String path) {
    return 'Saved to $path';
  }

  @override
  String get logoutEverywhereMenu => 'Log out from all devices';

  @override
  String get logoutEverywhereTitle => 'Log out from all devices?';

  @override
  String get logoutEverywhereBody =>
      'This will end every active session for your account, on every device. You\'ll need to log in again on each one.';

  @override
  String get logoutEverywhereConfirm => 'Log out everywhere';

  @override
  String get recordHistory => 'History';

  @override
  String get noHistoryYet => 'No history yet for this record.';

  @override
  String get systemActor => 'System';

  @override
  String get formulaLabel => 'Formula';

  @override
  String get formulaHelp =>
      'Numeric expression. Use field names (qty, price) and operators + - * / ( ).';

  @override
  String get computedField => 'Computed';

  @override
  String get computedHelp =>
      'This value is calculated automatically from other fields.';

  @override
  String get importCsv => 'Import CSV';

  @override
  String get importCsvHelp =>
      'Paste CSV content. The first line must be a header row matching the entity\'s column names. Unknown columns are ignored. Run Preview first to see what would happen without writing anything.';

  @override
  String get previewAction => 'Preview';

  @override
  String get importAction => 'Import';

  @override
  String get previewBadge => 'PREVIEW';

  @override
  String importSummary(int total, int created, int skipped, int errCount) {
    return '$total rows • $created created • $skipped skipped • $errCount errors';
  }

  @override
  String bulkDeleteButton(int count) {
    return 'Delete $count';
  }

  @override
  String get bulkDeleteTitle => 'Delete selected rows?';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Delete $count rows?',
      one: 'Delete 1 row?',
    );
    return '$_temp0 This cannot be undone.';
  }

  @override
  String bulkDeleteResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Deleted $count rows',
      one: 'Deleted 1 row',
      zero: 'Nothing deleted',
    );
    return '$_temp0';
  }

  @override
  String get sessionsTitle => 'Active devices';

  @override
  String get sessionsSubtitle =>
      'Sessions currently signed in to your account. Revoke any you don\'t recognize.';

  @override
  String get noActiveSessions => 'No active sessions.';

  @override
  String get currentSessionBadge => 'THIS DEVICE';

  @override
  String sessionMeta(String issuedAt, String expiresAt) {
    return 'Signed in $issuedAt • Expires $expiresAt';
  }

  @override
  String get revokeAction => 'Revoke';

  @override
  String get revokeSessionTitle => 'Revoke this session?';

  @override
  String get revokeSessionConfirm =>
      'The device using this session will be signed out the next time it tries to refresh its access token.';

  @override
  String get revokeCurrentSessionWarn =>
      'This is your current session. Revoking it will sign you out of this device immediately.';

  @override
  String get sessionRevoked => 'Session revoked.';

  @override
  String revokeFailed(String error) {
    return 'Couldn\'t revoke: $error';
  }

  @override
  String get unknownDevice => 'Unknown device';

  @override
  String get viewPermissionLabel => 'View permission';

  @override
  String get editPermissionLabel => 'Edit permission';

  @override
  String get fieldPermissionHelp =>
      'Optional permission code. Leave blank to inherit the entity\'s permissions.';

  @override
  String get generateResetToken => 'Generate password reset token';

  @override
  String get generateResetTokenTitle => 'Generate reset token?';

  @override
  String generateResetTokenConfirm(String username) {
    return 'Generate a one-time password-reset token for \"$username\"? The token is shown only once — copy it and share it with the user out-of-band.';
  }

  @override
  String get generate => 'Generate';

  @override
  String resetTokenFailed(String error) {
    return 'Couldn\'t generate token: $error';
  }

  @override
  String resetTokenDialogTitle(String username) {
    return 'Reset token for $username';
  }

  @override
  String get resetTokenWarning =>
      'Save this token now. It is shown only once and cannot be retrieved later.';

  @override
  String resetTokenExpires(String when) {
    return 'Expires $when';
  }

  @override
  String get resetTokenLabel => 'Token';

  @override
  String get resetUrlLabel => 'Reset URL';

  @override
  String get copyToken => 'Copy token';

  @override
  String get copyResetUrl => 'Copy reset URL';

  @override
  String get copiedToClipboard => 'Copied to clipboard';

  @override
  String get resetPasswordTitle => 'Reset your password';

  @override
  String get resetPasswordBody =>
      'Enter the reset token your administrator gave you, then choose a new password.';

  @override
  String get resetTokenField => 'Reset token';

  @override
  String get newPasswordField => 'New password';

  @override
  String get confirmPasswordField => 'Confirm password';

  @override
  String get passwordsMustMatch => 'Passwords don\'t match';

  @override
  String get resetPasswordAction => 'Reset password';

  @override
  String get resetPasswordSuccess =>
      'Password reset. Sign in with your new password.';

  @override
  String resetPasswordFailedMsg(String error) {
    return 'Reset failed: $error';
  }

  @override
  String get twoFactorTitle => 'Two-factor authentication';

  @override
  String get twoFactorCodeHint =>
      'Enter the 6-digit code from your authenticator app.';

  @override
  String get twoFactorRecoveryHint =>
      'Enter one of your recovery codes (10 hex chars, dashes optional).';

  @override
  String get twoFactorCodeField => 'Authentication code';

  @override
  String get recoveryCodeField => 'Recovery code';

  @override
  String get useRecoveryInstead => 'Use recovery code instead';

  @override
  String get useTotpInstead => 'Use authenticator code instead';

  @override
  String get twoFactorEnabled => 'Enabled';

  @override
  String get twoFactorNotEnabled => 'Not enabled';

  @override
  String twoFactorEnabledOn(String when) {
    return 'Enabled on $when';
  }

  @override
  String get enable2FA => 'Enable 2FA';

  @override
  String get disable2FA => 'Disable 2FA';

  @override
  String get enable2FAStep1 =>
      'Step 1: scan this QR with your authenticator app (or paste the secret manually).';

  @override
  String get enable2FAStep2 =>
      'Step 2: enter the 6-digit code your app shows to confirm.';

  @override
  String get secretLabel => 'Secret';

  @override
  String get copySecret => 'Copy secret';

  @override
  String get recoveryCodesTitle => 'Save your recovery codes';

  @override
  String get recoveryCodesBody =>
      'Each code can be used once if you lose access to your authenticator. Save them somewhere safe — they won\'t be shown again.';

  @override
  String get copyRecoveryCodes => 'Copy all codes';

  @override
  String get twoFactorEnableSuccess =>
      'Two-factor authentication is now enabled.';

  @override
  String get twoFactorDisableSuccess =>
      'Two-factor authentication has been disabled.';

  @override
  String get twoFactorEnableFailed =>
      'Verification failed. Try again with a fresh code from your authenticator.';

  @override
  String twoFactorDisableFailed(String error) {
    return 'Couldn\'t disable: $error';
  }

  @override
  String get disable2FATitle => 'Disable two-factor authentication?';

  @override
  String get disable2FABody =>
      'Enter your current authenticator code (or a recovery code) to confirm.';

  @override
  String get reset2FA => 'Reset 2FA';

  @override
  String reset2FAConfirm(String username) {
    return 'Reset 2FA for \"$username\"? This disables their two-factor authentication and removes their recovery codes. Use this when a user has lost their authenticator AND all recovery codes.';
  }

  @override
  String reset2FASuccess(String username) {
    return '2FA reset for $username';
  }

  @override
  String reset2FAWasNotEnabled(String username) {
    return '$username did not have 2FA enabled — nothing to reset.';
  }
}
