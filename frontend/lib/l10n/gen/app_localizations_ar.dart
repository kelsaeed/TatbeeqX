// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for Arabic (`ar`).
class AppLocalizationsAr extends AppLocalizations {
  AppLocalizationsAr([String locale = 'ar']) : super(locale);

  @override
  String get appName => 'تطبيق';

  @override
  String get signIn => 'تسجيل الدخول';

  @override
  String get signInToContinue => 'سجّل الدخول للمتابعة';

  @override
  String get usernameOrEmail => 'اسم المستخدم أو البريد الإلكتروني';

  @override
  String get password => 'كلمة المرور';

  @override
  String get signOut => 'تسجيل الخروج';

  @override
  String get loginTagline => 'جاهز للشبكة المحلية • محمي بـ JWT';

  @override
  String get manageEveryBusiness => 'أدر كل أعمالك،';

  @override
  String get inOnePlace => 'في مكان واحد.';

  @override
  String get loginHeroSubtitle =>
      'متعدد الشركات، متعدد الفروع، مبني على الأدوار، قابل للتخصيص بالكامل.';

  @override
  String get save => 'حفظ';

  @override
  String get cancel => 'إلغاء';

  @override
  String get delete => 'حذف';

  @override
  String get edit => 'تعديل';

  @override
  String get create => 'إنشاء';

  @override
  String get newItem => 'جديد';

  @override
  String get search => 'بحث';

  @override
  String get loading => 'جارٍ التحميل…';

  @override
  String get error => 'خطأ';

  @override
  String get noData => 'لا توجد بيانات';

  @override
  String get ok => 'موافق';

  @override
  String get yes => 'نعم';

  @override
  String get no => 'لا';

  @override
  String get refresh => 'تحديث';

  @override
  String get saving => 'جارٍ الحفظ…';

  @override
  String get required => 'مطلوب';

  @override
  String get company => 'الشركة';

  @override
  String get noCompany => 'بدون شركة';

  @override
  String get globalTheme => '— السمة العامة —';

  @override
  String get switchCompany => 'تبديل الشركة';

  @override
  String get language => 'اللغة';

  @override
  String get account => 'الحساب';

  @override
  String get superAdmin => 'المدير العام';

  @override
  String get user => 'مستخدم';

  @override
  String get dashboard => 'لوحة التحكم';

  @override
  String get users => 'المستخدمون';

  @override
  String get roles => 'الأدوار';

  @override
  String get companies => 'الشركات';

  @override
  String get branches => 'الفروع';

  @override
  String get audit => 'سجلات التدقيق';

  @override
  String get settings => 'الإعدادات';

  @override
  String get appearance => 'المظهر';

  @override
  String get reports => 'التقارير';

  @override
  String get database => 'قاعدة البيانات';

  @override
  String get customEntities => 'الكيانات المخصصة';

  @override
  String get templates => 'القوالب';

  @override
  String get pages => 'الصفحات';

  @override
  String get system => 'النظام';

  @override
  String get systemLogs => 'سجلات النظام';

  @override
  String get loginActivity => 'نشاط تسجيل الدخول';

  @override
  String get approvals => 'الموافقات';

  @override
  String get reportSchedules => 'جداول التقارير';

  @override
  String get webhooks => 'Webhooks';

  @override
  String get backups => 'النسخ الاحتياطية';

  @override
  String deleteConfirm(String name) {
    return 'حذف \"$name\"؟';
  }

  @override
  String loadFailed(String error) {
    return 'فشل التحميل: $error';
  }

  @override
  String saveFailed(String error) {
    return 'فشل الحفظ: $error';
  }

  @override
  String deleteFailedMsg(String error) {
    return 'فشل الحذف: $error';
  }

  @override
  String createFailed(String error) {
    return 'فشل الإنشاء: $error';
  }

  @override
  String adminRestricted(String feature) {
    return '$feature مقتصر على المدير العام';
  }

  @override
  String get apply => 'تطبيق';

  @override
  String get activate => 'تفعيل';

  @override
  String get duplicate => 'تكرار';

  @override
  String get resetLabel => 'إعادة تعيين';

  @override
  String get run => 'تشغيل';

  @override
  String get importLabel => 'استيراد';

  @override
  String get exportLabel => 'تصدير';

  @override
  String get add => 'إضافة';

  @override
  String get remove => 'إزالة';

  @override
  String get close => 'إغلاق';

  @override
  String get back => 'رجوع';

  @override
  String get name => 'الاسم';

  @override
  String get code => 'الرمز';

  @override
  String get email => 'البريد الإلكتروني';

  @override
  String get statusLabel => 'الحالة';

  @override
  String get typeLabel => 'النوع';

  @override
  String get defaultLabel => 'افتراضي';

  @override
  String get actionsLabel => 'إجراءات';

  @override
  String get descriptionLabel => 'الوصف';

  @override
  String get systemChip => 'نظام';

  @override
  String get enabledLabel => 'مفعّل';

  @override
  String get disabledLabel => 'معطّل';

  @override
  String get active => 'نشط';

  @override
  String get inactive => 'غير نشط';

  @override
  String get all => 'الكل';

  @override
  String get noneLabel => 'لا شيء';

  @override
  String pageOfTotal(int page, int total) {
    return 'صفحة $page من $total';
  }

  @override
  String permissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count صلاحية',
      many: '$count صلاحية',
      few: '$count صلاحيات',
      two: 'صلاحيتان',
      one: 'صلاحية واحدة',
      zero: 'لا توجد صلاحيات',
    );
    return '$_temp0';
  }

  @override
  String usersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count مستخدم',
      many: '$count مستخدماً',
      few: '$count مستخدمين',
      two: 'مستخدمان',
      one: 'مستخدم واحد',
      zero: 'لا يوجد مستخدمون',
    );
    return '$_temp0';
  }

  @override
  String get rolesSubtitle => 'حدّد الأدوار وعيّن الصلاحيات بدقة.';

  @override
  String get auditSubtitle => 'تسلسل زمني لكل عملية مهمة في النظام.';

  @override
  String get backupsSubtitle =>
      'لقطات لقاعدة البيانات الأساسية. الاستعادة تستبدل القاعدة الحالية وتتطلب إعادة التشغيل.';

  @override
  String get reportsSubtitle => 'تقارير جاهزة. شغّلها لعرض بيانات حديثة.';

  @override
  String get dashboardSubtitle => 'نظرة سريعة على نظامك.';

  @override
  String get loginFailed => 'فشل تسجيل الدخول';

  @override
  String get searchHint => 'بحث…';

  @override
  String totalLabel(int count) {
    return '$count الإجمالي';
  }

  @override
  String fileNotFound(String path) {
    return 'الملف غير موجود: $path';
  }

  @override
  String get uploaded => 'تم الرفع';

  @override
  String uploadFailed(String error) {
    return 'فشل الرفع: $error';
  }

  @override
  String get upload => 'رفع';

  @override
  String get uploading => 'جارٍ الرفع…';

  @override
  String get uploadHint =>
      '…أو الصق مسار ملف محلي (مثل C:\\images\\logo.png) واضغط رفع';

  @override
  String get urlHint => 'رابط';

  @override
  String get restore => 'استعادة';

  @override
  String get auditWhen => 'متى';

  @override
  String get auditUser => 'المستخدم';

  @override
  String get auditAction => 'الإجراء';

  @override
  String get auditEntity => 'الكيان';

  @override
  String get auditId => 'المعرّف';

  @override
  String get auditIp => 'IP';

  @override
  String get systemUserLabel => 'النظام';

  @override
  String get createBackup => 'إنشاء نسخة احتياطية';

  @override
  String get backupLabelField => 'تسمية (اختياري، أحرف صغيرة وشُرَط)';

  @override
  String get backupLabelExample => 'مثلاً: before-month-end';

  @override
  String get deleteBackupTitle => 'حذف النسخة الاحتياطية؟';

  @override
  String deleteBackupWarn(String name) {
    return 'سيتم حذف \"$name\" من القرص بشكل نهائي.';
  }

  @override
  String get restoreBackupTitle => 'استعادة النسخة الاحتياطية؟';

  @override
  String restoreBackupWarn(String name) {
    return 'سيتم استبدال قاعدة البيانات الحالية بـ \"$name\". بعد الاستعادة، يجب إعادة تشغيل عملية الـ API قبل أن تأخذ التغييرات مفعولها.\n\nستُفقد البيانات المُنشأة بعد هذه النسخة الاحتياطية.';
  }

  @override
  String get restoreCompleteRestart => 'اكتملت الاستعادة. مطلوب إعادة التشغيل.';

  @override
  String get noBackupsYet => 'لا توجد نسخ احتياطية بعد. اضغط \"جديد\".';

  @override
  String get noReportsDefined => 'لا توجد تقارير معرّفة';

  @override
  String get noPermissionReports => 'ليس لديك صلاحية لعرض التقارير.';

  @override
  String get auditEventsLast14 => 'أحداث التدقيق — آخر 14 يوماً';

  @override
  String get auditByEntityLast30 => 'التدقيق حسب الكيان — آخر 30 يوماً';

  @override
  String get recentLogins => 'تسجيلات الدخول الأخيرة';

  @override
  String get recentAuditEvents => 'أحداث التدقيق الأخيرة';

  @override
  String get noActivityYet => 'لا يوجد نشاط بعد';

  @override
  String get noDataYet => 'لا توجد بيانات بعد';

  @override
  String get noAuditEntriesYet => 'لا توجد إدخالات تدقيق بعد';

  @override
  String get auditEventsCount => 'أحداث التدقيق';

  @override
  String failedShort(String error) {
    return 'فشل: $error';
  }

  @override
  String get username => 'اسم المستخدم';

  @override
  String get fullName => 'الاسم الكامل';

  @override
  String get phoneOptional => 'الهاتف (اختياري)';

  @override
  String get phone => 'الهاتف';

  @override
  String get address => 'العنوان';

  @override
  String get legalName => 'الاسم القانوني';

  @override
  String get taxNumber => 'الرقم الضريبي';

  @override
  String get logoUrl => 'رابط الشعار';

  @override
  String get passwordField => 'كلمة المرور';

  @override
  String get newPasswordKeepBlank => 'كلمة مرور جديدة (اتركها فارغة للإبقاء)';

  @override
  String get min8Chars => '8 أحرف على الأقل';

  @override
  String get invalidEmail => 'بريد إلكتروني غير صالح';

  @override
  String get noneOption => '— لا شيء —';

  @override
  String get branchField => 'الفرع';

  @override
  String get companyField => 'الشركة';

  @override
  String get rolesField => 'الأدوار';

  @override
  String deleteCannotBeUndone(String name) {
    return 'حذف \"$name\"؟ لا يمكن التراجع.';
  }

  @override
  String deleteCascadeWarn(String name) {
    return 'حذف \"$name\"؟ سيتم حذف الفروع والبيانات المرتبطة معها.';
  }

  @override
  String get selectCompany => 'اختر شركة';

  @override
  String get noBranches => 'لا توجد فروع';

  @override
  String branchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count فرع',
      many: '$count فرعاً',
      few: '$count فروع',
      two: 'فرعان',
      one: 'فرع واحد',
      zero: 'لا توجد فروع',
    );
    return '$_temp0';
  }

  @override
  String get usersSubtitle => 'إنشاء وإدارة مستخدمي النظام.';

  @override
  String get newUser => 'مستخدم جديد';

  @override
  String get editUser => 'تعديل المستخدم';

  @override
  String get deleteUser => 'حذف المستخدم';

  @override
  String get searchUsers => 'البحث عن مستخدمين…';

  @override
  String get companiesSubtitle =>
      'كل شركة يمكنها أن تمتلك فروعها ومستخدميها وسماتها الخاصة.';

  @override
  String get newCompany => 'شركة جديدة';

  @override
  String get editCompany => 'تعديل الشركة';

  @override
  String get deleteCompany => 'حذف الشركة';

  @override
  String codeColon(String code) {
    return 'الرمز: $code';
  }

  @override
  String get branchesSubtitle => 'الفروع تتبع الشركات.';

  @override
  String get newBranch => 'فرع جديد';

  @override
  String get editBranch => 'تعديل الفرع';

  @override
  String get deleteBranch => 'حذف الفرع';

  @override
  String get settingsSubtitle =>
      'إعدادات مفتاح/قيمة على مستوى النظام. كل ما هو مُعلَّم \"عام\" يكون مرئياً بدون مصادقة.';

  @override
  String get addRow => 'إضافة صف';

  @override
  String get settingsSaved => 'تم حفظ الإعدادات';

  @override
  String get keyField => 'المفتاح';

  @override
  String get valueField => 'القيمة';

  @override
  String get typeField => 'النوع';

  @override
  String get publicLabel => 'عام';

  @override
  String get noSettingsYet => 'لا توجد إعدادات بعد';

  @override
  String get loginActivitySubtitle =>
      'كل تسجيل دخول، تحديث، تسجيل خروج، ومحاولة فاشلة.';

  @override
  String get eventField => 'الحدث';

  @override
  String get allEvents => 'كل الأحداث';

  @override
  String get loginEvent => 'تسجيل دخول';

  @override
  String get logoutEvent => 'تسجيل خروج';

  @override
  String get refreshEvent => 'تحديث';

  @override
  String get successField => 'النجاح';

  @override
  String get successfulOption => 'ناجح';

  @override
  String get failedOption => 'فاشل';

  @override
  String get searchLoginEvents => 'البحث بالاسم أو IP أو user agent…';

  @override
  String get resultColumn => 'النتيجة';

  @override
  String get okShort => 'OK';

  @override
  String get failShort => 'FAIL';

  @override
  String get reasonColumn => 'السبب';

  @override
  String get systemLogsSubtitle =>
      'أحداث الخادم: التشغيل، الأخطاء، التحذيرات، المعلومات.';

  @override
  String get clearOlderThan30 => 'مسح الأقدم من 30 يوماً';

  @override
  String get clearOldLogsTitle => 'مسح السجلات القديمة؟';

  @override
  String get clearOldLogsBody =>
      'حذف كل سجل نظام أقدم من 30 يوماً. لا يمكن التراجع.';

  @override
  String get levelField => 'المستوى';

  @override
  String get allLevels => 'كل المستويات';

  @override
  String get levelDebug => 'تصحيح';

  @override
  String get levelInfo => 'معلومات';

  @override
  String get levelWarn => 'تحذير';

  @override
  String get levelError => 'خطأ';

  @override
  String get sourceField => 'المصدر';

  @override
  String get searchMessageContext => 'البحث في الرسالة أو السياق…';

  @override
  String get messageField => 'الرسالة';

  @override
  String get webhooksSubtitle =>
      'إرسال إشعارات POST إلى عناوين خارجية عند وقوع أحداث النظام. موقّعة بـ HMAC.';

  @override
  String get newWebhook => 'Webhook جديد';

  @override
  String get noSubscriptionsYet => 'لا توجد اشتراكات بعد.';

  @override
  String get enableLabel => 'تفعيل';

  @override
  String get disableLabel => 'تعطيل';

  @override
  String get sendTestEvent => 'إرسال حدث تجريبي';

  @override
  String get recentDeliveries => 'التسليمات الأخيرة';

  @override
  String get testEventDispatched => 'تم إرسال الحدث التجريبي';

  @override
  String get deleteSubscriptionTitle => 'حذف الاشتراك؟';

  @override
  String get deleteSubscriptionBody => 'سيُحذف الاشتراك وكل سجل التسليمات.';

  @override
  String recentDeliveriesFor(String name) {
    return 'التسليمات الأخيرة — $name';
  }

  @override
  String get noDeliveriesYet => 'لا توجد تسليمات بعد.';

  @override
  String get newWebhookSubscription => 'اشتراك Webhook جديد';

  @override
  String get codeLowerSnake => 'الرمز (أحرف صغيرة، snake_case)';

  @override
  String get urlHttps => 'الرابط (https://...)';

  @override
  String get secretOptionalAuto =>
      'السر (اختياري — يُولَّد تلقائياً إن تُرك فارغاً)';

  @override
  String get eventsLabel => 'الأحداث';

  @override
  String get pickAtLeastOneEvent => 'اختر حدثاً واحداً على الأقل';

  @override
  String get webhookSecretTitle => 'سر الـ Webhook';

  @override
  String webhookSecretSaveWarn(String secret) {
    return 'احفظ هذا السر في مكان آمن — لن يُعرض مجدداً:\n\n$secret';
  }

  @override
  String get approvalsSubtitle =>
      'طلبات معلّقة بانتظار شخص يملك <entity>.approve.';

  @override
  String get newRequest => 'طلب جديد';

  @override
  String get statusPending => 'معلّق';

  @override
  String get statusApproved => 'موافق عليه';

  @override
  String get statusRejected => 'مرفوض';

  @override
  String get statusCancelled => 'ملغى';

  @override
  String get approveLabel => 'الموافقة';

  @override
  String get rejectLabel => 'الرفض';

  @override
  String get approveTitle => 'الموافقة على الطلب؟';

  @override
  String get rejectTitle => 'رفض الطلب؟';

  @override
  String get noteOptional => 'ملاحظة (اختياري)';

  @override
  String get requestApproval => 'طلب موافقة';

  @override
  String get entityProductsHint => 'الكيان (مثلاً products)';

  @override
  String get titleField => 'العنوان';

  @override
  String get submitLabel => 'إرسال';

  @override
  String get approvalsRequestedBy => 'طلبه';

  @override
  String get approvalsTitleColumn => 'العنوان';

  @override
  String get setupLocked =>
      'الإعداد مغلق. اطلب من المدير العام اختيار نوع الأعمال.';

  @override
  String get welcomePickBusinessType => 'أهلاً — اختر نوع الأعمال';

  @override
  String get setupExplain =>
      'هذا يحدد الوحدات والجداول والقوائم الأولية. يمكنك تغيير كل شيء لاحقاً وإضافة جداول وتشغيل SQL من صفحة إدارة قاعدة البيانات.';

  @override
  String get alreadyConfiguredHint =>
      'مُعدّ مسبقاً؟ زُر صفحات الكيانات المخصصة وقاعدة البيانات لإضافة جداول وتعديل أعمدة وتشغيل SQL.';

  @override
  String get skipAndContinue => 'تخطّي ومتابعة';

  @override
  String get useThis => 'استخدم هذا';

  @override
  String applyFailed(String error) {
    return 'فشل التطبيق: $error';
  }

  @override
  String get deleteRowTitle => 'حذف الصف';

  @override
  String newEntitySingular(String singular) {
    return '$singular جديد';
  }

  @override
  String editEntitySingular(String singular) {
    return 'تعديل $singular';
  }

  @override
  String tableLabel(String tableName) {
    return 'الجدول: $tableName';
  }

  @override
  String searchEntityHint(String label) {
    return 'البحث في $label…';
  }

  @override
  String get customEntitiesAdminRestricted =>
      'إدارة الكيانات المخصصة مقتصرة على المدير العام.';

  @override
  String get customEntitiesSubtitle =>
      'جداول مخصصة لأعمالك. كل كيان يحصل على صلاحياته وعنصر قائمته وصفحة CRUD الخاصة به.';

  @override
  String get newEntity => 'كيان جديد';

  @override
  String get editEntity => 'تعديل الكيان';

  @override
  String get noCustomEntitiesYet => 'لا توجد كيانات مخصصة بعد.';

  @override
  String deleteEntityTitle(String label) {
    return 'حذف \"$label\"';
  }

  @override
  String get deleteEntityBody =>
      'يمكنك إما الإبقاء على الجدول الأساسي (تبقى البيانات، يُزال التسجيل فقط) أو إسقاطه (لا يمكن التراجع).';

  @override
  String get unregisterOnly => 'إلغاء التسجيل فقط';

  @override
  String get dropTable => 'إسقاط الجدول';

  @override
  String get addColumn => 'إضافة عمود';

  @override
  String get addAtLeastOneColumn => 'أضف عموداً واحداً على الأقل';

  @override
  String get codeUsedInUrl => 'الرمز (يُستخدم في الرابط وواجهة API)';

  @override
  String get sqlTableName => 'اسم جدول SQL';

  @override
  String get displayLabelPlural => 'تسمية العرض (الجمع)';

  @override
  String get singularName => 'الاسم المفرد';

  @override
  String get categoryField => 'الفئة';

  @override
  String get iconNameField => 'اسم الأيقونة';

  @override
  String get iconNameHint => 'reports, business, store, …';

  @override
  String get columnsLabel => 'الأعمدة';

  @override
  String get systemEntitiesAlterWarn =>
      'كيانات النظام — تعديلات الأعمدة لا تُطبَّق تلقائياً على جدول SQL. استخدم إدارة قاعدة البيانات لتنفيذ ALTER يدوياً.';

  @override
  String get updateLabel => 'تحديث';

  @override
  String get fieldNameSnakeCase => 'اسم الحقل (snake_case)';

  @override
  String get labelField => 'التسمية';

  @override
  String get requiredLabel => 'مطلوب';

  @override
  String get uniqueLabel => 'فريد';

  @override
  String get searchableLabel => 'قابل للبحث';

  @override
  String get showInList => 'إظهار في القائمة';

  @override
  String starterTablesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count جدول أولي',
      many: '$count جدولاً أولياً',
      few: '$count جداول أولية',
      two: 'جدولان أوليان',
      one: 'جدول أولي واحد',
      zero: 'لا توجد جداول أولية',
    );
    return '$_temp0';
  }

  @override
  String columnsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count عمود',
      many: '$count عموداً',
      few: '$count أعمدة',
      two: 'عمودان',
      one: 'عمود واحد',
      zero: 'لا توجد أعمدة',
    );
    return '$_temp0';
  }

  @override
  String get reportSchedulesSubtitle =>
      'شغّل أي تقرير بإيقاع متكرر. تُحفظ النتائج على كل جدول.';

  @override
  String get newSchedule => 'جدول جديد';

  @override
  String get noSchedulesYet => 'لا توجد جداول بعد. اضغط \"جدول جديد\".';

  @override
  String get runNow => 'تشغيل الآن';

  @override
  String get recentRuns => 'آخر التشغيلات';

  @override
  String get runSucceeded => 'نجح التشغيل';

  @override
  String runFailedMsg(String error) {
    return 'فشل التشغيل: $error';
  }

  @override
  String get deleteScheduleTitle => 'حذف الجدول؟';

  @override
  String get deleteScheduleBody =>
      'سيُوقف التشغيلات المستقبلية ويحذف الجدول وسجل تشغيلاته.';

  @override
  String recentRunsFor(String name) {
    return 'آخر التشغيلات — $name';
  }

  @override
  String get noRunsYet => 'لا توجد تشغيلات بعد.';

  @override
  String get noReportsDefinedYet => 'لم تُعرَّف تقارير بعد.';

  @override
  String get templatesSubtitle =>
      'خذ لقطة للسمة الحالية والجداول المخصصة. أعد تطبيقها لاحقاً أو شاركها بين عمليات التثبيت.';

  @override
  String get templatesRestricted => 'القوالب مقتصرة على المدير العام.';

  @override
  String get saveCurrentSetup => 'حفظ الإعداد الحالي كقالب';

  @override
  String get saveCurrent => 'حفظ الحالي';

  @override
  String get importJson => 'استيراد JSON';

  @override
  String get noTemplatesYet => 'لا توجد قوالب بعد.';

  @override
  String applyTemplateTitle(String name) {
    return 'تطبيق \"$name\"؟';
  }

  @override
  String get applyTemplateBody =>
      'سيتم تسجيل كل الجداول المخصصة وتفعيل السمة من القالب. الجداول الموجودة بنفس الاسم تبقى (يُحدَّث التسجيل فقط).';

  @override
  String get templateSaved => 'تم حفظ القالب';

  @override
  String get templateApplied => 'تم تطبيق القالب';

  @override
  String get copiedJsonToClipboard => 'تم نسخ JSON إلى الحافظة';

  @override
  String exportFailed(String error) {
    return 'فشل التصدير: $error';
  }

  @override
  String get importTemplateTitle => 'استيراد قالب';

  @override
  String get templateImported => 'تم استيراد القالب';

  @override
  String importFailed(String error) {
    return 'فشل الاستيراد: $error';
  }

  @override
  String invalidJson(String error) {
    return 'JSON غير صالح: $error';
  }

  @override
  String get deleteTemplateTitle => 'حذف القالب';

  @override
  String get copyJson => 'نسخ JSON';

  @override
  String get applyAction => 'تطبيق';

  @override
  String get pagesSubtitle =>
      'صفحات مخصصة مكوّنة من كتل. تُصمَّم في منشئ الصفحات.';

  @override
  String get newPage => 'صفحة جديدة';

  @override
  String get noPagesYet =>
      'لا توجد صفحات مخصصة بعد. اضغط \"صفحة جديدة\" لتصميم واحدة.';

  @override
  String get deletePageTitle => 'حذف الصفحة؟';

  @override
  String get deletePageBody => 'يحذف الصفحة وكل كتلها.';

  @override
  String get openInBuilder => 'فتح في المنشئ';

  @override
  String get openPage => 'فتح الصفحة';

  @override
  String get pagesStatLabel => 'الصفحات';

  @override
  String get blocksStatLabel => 'الكتل';

  @override
  String get avgBlocksPerPage => 'متوسط الكتل / الصفحة';

  @override
  String get blockUsage => 'استخدام الكتل';

  @override
  String get addBlock => 'إضافة كتلة';

  @override
  String get emptyPageHint => 'صفحة فارغة. أضف كتلاً من الجانب الأيمن.';

  @override
  String get themeBuilderRestricted => 'منشئ السمات مقتصر على المدير العام.';

  @override
  String get themeBuilderTitle => 'منشئ السمات';

  @override
  String themeBuilderEditing(String name) {
    return 'تعديل \"$name\"';
  }

  @override
  String get saveAndActivate => 'حفظ وتفعيل';

  @override
  String get themeActivated => 'تم تفعيل السمة';

  @override
  String get themeSavedMsg => 'تم حفظ السمة';

  @override
  String get systemSubtitle =>
      'معلومات الخادم، اتصالات قاعدة البيانات، والإعدادات.';

  @override
  String get databaseConnectionsHeader => 'اتصالات قاعدة البيانات';

  @override
  String get addConnectionLabel => 'إضافة اتصال';

  @override
  String get noConnectionsYet =>
      'لا توجد اتصالات بعد. أضف واحداً للتبديل بين قواعد البيانات من الواجهة.';

  @override
  String get primaryChip => 'أساسية';

  @override
  String get promoteToPrimary => 'ترقية لتكون الأساسية';

  @override
  String get promoteToPrimaryTitle => 'الترقية لتكون الأساسية؟';

  @override
  String get promoteWarn =>
      'سيُعاد كتابة DATABASE_URL في .env. يجب إعادة تشغيل الخادم قبل سريان التغييرات، ويجب أن تكون قاعدة البيانات الجديدة مُجهَّزة بالمخطط. تُحفظ نسخة من .env السابق في .env-backups/.';

  @override
  String get promoteAction => 'ترقية';

  @override
  String get updatedRestartRequired => 'تم التحديث. مطلوب إعادة التشغيل.';

  @override
  String get deleteConnectionTitle => 'حذف الاتصال؟';

  @override
  String get deleteConnectionBody =>
      'يُزيل الاتصال المحفوظ من السجل. لا يؤثر على قاعدة البيانات نفسها.';

  @override
  String get initDatabaseHeader => 'تهيئة قاعدة البيانات بـ SQL';

  @override
  String get initDatabaseHint =>
      'ألصق عبارات CREATE TABLE / ALTER TABLE / INSERT مفصولة بفواصل منقوطة. تُنفَّذ بالترتيب.';

  @override
  String get runStatements => 'تنفيذ العبارات';

  @override
  String get running => 'جارٍ التنفيذ…';

  @override
  String get addDatabaseConnection => 'إضافة اتصال قاعدة بيانات';

  @override
  String get databaseSubtitle =>
      'افحص الجداول، عاين الصفوف، شغّل SQL. كل الاستعلامات مُدقَّقة.';

  @override
  String get databaseRestricted =>
      'إدارة قاعدة البيانات مقتصرة على المدير العام.';

  @override
  String describeFailed(String error) {
    return 'فشل الوصف: $error';
  }

  @override
  String get runWriteQueryTitle => 'تشغيل استعلام كتابة؟';

  @override
  String get runWriteQueryBody =>
      'أنت على وشك تنفيذ SQL في وضع الكتابة. تأكد من معرفتك بما يفعله. جداول المصادقة الأساسية محمية.';

  @override
  String get saveQueryTitle => 'حفظ الاستعلام';

  @override
  String get querySavedMsg => 'تم حفظ الاستعلام';

  @override
  String get sqlRunner => 'منفّذ SQL';

  @override
  String get writeMode => 'وضع الكتابة';

  @override
  String get savedQueriesHeader => 'الاستعلامات المحفوظة';

  @override
  String get nothingSavedYet => 'لا شيء محفوظ بعد.';

  @override
  String get loadAction => 'تحميل';

  @override
  String noRowsReturnedMsg(String count) {
    return 'لم تُرجَع صفوف ($count).';
  }

  @override
  String get columnsHeader => 'الأعمدة';

  @override
  String get foreignKeysHeader => 'المفاتيح الخارجية';

  @override
  String previewHeader(int count) {
    return 'معاينة (أول $count صفوف)';
  }

  @override
  String get editSubsystemTooltip => 'تعديل العلامة التجارية والوحدات';

  @override
  String editSubsystemTitle(String name) {
    return 'العلامة التجارية والوحدات — $name';
  }

  @override
  String get brandingSection => 'العلامة التجارية';

  @override
  String get modulesSection => 'الوحدات';

  @override
  String get modulesHelp =>
      'تُدمج الوحدات الأساسية (لوحة التحكم، المستخدمون، إلخ) تلقائيًا — أدرج فقط عناصر الشريط الجانبي الإضافية التي يجب أن يكشفها هذا النظام الفرعي.';

  @override
  String get subsystemSaved => 'تم حفظ إعدادات النظام الفرعي';

  @override
  String get appNameLabel => 'اسم التطبيق';

  @override
  String get logoUrlLabel => 'رابط الشعار';

  @override
  String get primaryColorLabel => 'اللون الأساسي';

  @override
  String get iconPathLabel => 'مسار الأيقونة (.ico)';

  @override
  String get addModuleLabel => 'إضافة رمز وحدة';

  @override
  String get addBlockHeader => 'إضافة كتلة';

  @override
  String get blockTypeText => 'نص';

  @override
  String get blockTypeHeading => 'عنوان';

  @override
  String get blockTypeImage => 'صورة';

  @override
  String get blockTypeButton => 'زر';

  @override
  String get blockTypeCard => 'بطاقة';

  @override
  String get blockTypeContainer => 'حاوية';

  @override
  String get blockTypeDivider => 'فاصل';

  @override
  String get blockTypeSpacer => 'مساحة فارغة';

  @override
  String get blockTypeList => 'قائمة';

  @override
  String get blockTypeTable => 'جدول';

  @override
  String get blockTypeChart => 'رسم بياني';

  @override
  String get blockTypeIframe => 'تضمين (iframe)';

  @override
  String get blockTypeHtml => 'HTML خام';

  @override
  String get blockTypeCustomEntityList => 'قائمة كيان مخصص';

  @override
  String get blockTypeReport => 'تقرير';

  @override
  String inspectorEditTitle(String label) {
    return 'تعديل $label';
  }

  @override
  String get inspectorTitleText => 'تعديل النص';

  @override
  String get inspectorTitleHeading => 'تعديل العنوان';

  @override
  String get inspectorTitleImage => 'تعديل الصورة';

  @override
  String get inspectorTitleButton => 'تعديل الزر';

  @override
  String get inspectorTitleCard => 'تعديل البطاقة';

  @override
  String get inspectorTitleSpacer => 'تعديل المساحة';

  @override
  String get inspectorTitleIframe => 'تعديل الإطار المضمَّن';

  @override
  String get inspectorTitleHtml => 'تعديل HTML';

  @override
  String get inspectorTitleReport => 'تعديل كتلة التقرير';

  @override
  String get inspectorTitleEntityList => 'تعديل قائمة الكيان المخصص';

  @override
  String get inspectorTitleDivider => 'فاصل';

  @override
  String get inspectorNoOptions => 'لا توجد خيارات للضبط.';

  @override
  String get inspectorLevelLabel => 'المستوى';

  @override
  String get inspectorH1 => 'H1 — عرض';

  @override
  String get inspectorH2 => 'H2 — رئيسي';

  @override
  String get inspectorH3 => 'H3 — عنوان';

  @override
  String get inspectorH4 => 'H4 — عنوان فرعي';

  @override
  String get inspectorImageUrlHint =>
      'https://example.com/photo.jpg أو /uploads/x.png';

  @override
  String get inspectorFitLabel => 'الملاءمة';

  @override
  String get inspectorFitCover => 'تغطية';

  @override
  String get inspectorFitContain => 'احتواء';

  @override
  String get inspectorFitFill => 'تعبئة';

  @override
  String get inspectorRouteLabel => 'المسار (مثلاً /products)';

  @override
  String get inspectorStyleLabel => 'الأسلوب';

  @override
  String get inspectorVariantFilled => 'ممتلئ';

  @override
  String get inspectorVariantOutlined => 'محدَّد';

  @override
  String get inspectorVariantText => 'نصي';

  @override
  String get inspectorBodyLabel => 'المحتوى';

  @override
  String get inspectorHeightPxLabel => 'الارتفاع (بكسلات منطقية)';

  @override
  String get inspectorHtmlNotice =>
      'يتم تعقيم HTML على الخادم. تُجرَّد البرامج النصية ومعالِجات on* وعناوين javascript:.';

  @override
  String get inspectorReportCodeLabel => 'رمز التقرير (مثلاً users.by_role)';

  @override
  String get inspectorRenderAsLabel => 'العرض كـ';

  @override
  String get inspectorRenderAsTable => 'جدول';

  @override
  String get inspectorRenderAsChart => 'رسم بياني';

  @override
  String get inspectorEntityCodeLabel => 'رمز الكيان (مثلاً products)';

  @override
  String get inspectorPageSizeLabel => 'حجم الصفحة';

  @override
  String inspectorInvalidJson(String error) {
    return 'JSON غير صالح: $error';
  }

  @override
  String get targetEntityLabel => 'رمز الكيان المستهدف';

  @override
  String relationsAddLabel(String target) {
    return 'إضافة $target';
  }

  @override
  String get relationsLoadFailed => 'تعذّر تحميل الخيارات';

  @override
  String get relationsNoTarget => 'لم يُكوَّن كيان مستهدف';

  @override
  String get relationsEmpty => '—';

  @override
  String get exportCsv => 'تصدير CSV';

  @override
  String csvExportedTo(String path) {
    return 'تم الحفظ إلى $path';
  }

  @override
  String get logoutEverywhereMenu => 'تسجيل الخروج من جميع الأجهزة';

  @override
  String get logoutEverywhereTitle => 'تسجيل الخروج من جميع الأجهزة؟';

  @override
  String get logoutEverywhereBody =>
      'سيؤدي هذا إلى إنهاء كل الجلسات النشطة لحسابك على كل الأجهزة. ستحتاج إلى تسجيل الدخول مجددًا على كل منها.';

  @override
  String get logoutEverywhereConfirm => 'تسجيل الخروج من كل مكان';

  @override
  String get recordHistory => 'السجل';

  @override
  String get noHistoryYet => 'لا يوجد سجل بعد لهذا العنصر.';

  @override
  String get systemActor => 'النظام';

  @override
  String get formulaLabel => 'الصيغة';

  @override
  String get formulaHelp =>
      'تعبير رقمي. استخدم أسماء الحقول (qty, price) والعوامل + - * / ( ).';

  @override
  String get computedField => 'محسوب';

  @override
  String get computedHelp => 'تُحسب هذه القيمة تلقائيًا من حقول أخرى.';

  @override
  String get importCsv => 'استيراد CSV';

  @override
  String get importCsvHelp =>
      'ألصق محتوى CSV. يجب أن يكون السطر الأول صف رؤوس مطابق لأسماء أعمدة الكيان. تُتجاهل الأعمدة غير المعروفة. شغّل المعاينة أولاً لمعرفة ما سيحدث دون كتابة أي شيء.';

  @override
  String get previewAction => 'معاينة';

  @override
  String get importAction => 'استيراد';

  @override
  String get previewBadge => 'معاينة';

  @override
  String importSummary(int total, int created, int skipped, int errCount) {
    return '$total صفًا • $created منشأ • $skipped متخطى • $errCount أخطاء';
  }

  @override
  String bulkDeleteButton(int count) {
    return 'حذف $count';
  }

  @override
  String get bulkDeleteTitle => 'حذف الصفوف المحددة؟';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'حذف $count صف؟',
      many: 'حذف $count صفًا؟',
      few: 'حذف $count صفوف؟',
      two: 'حذف صفين؟',
      one: 'حذف صف واحد؟',
    );
    return '$_temp0 لا يمكن التراجع.';
  }

  @override
  String bulkDeleteResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'تم حذف $count صف',
      many: 'تم حذف $count صفًا',
      few: 'تم حذف $count صفوف',
      two: 'تم حذف صفين',
      one: 'تم حذف صف واحد',
      zero: 'لم يُحذف شيء',
    );
    return '$_temp0';
  }

  @override
  String get sessionsTitle => 'الأجهزة النشطة';

  @override
  String get sessionsSubtitle =>
      'الجلسات المسجَّلة دخولاً حاليًا في حسابك. ألغِ أي جلسة لا تعرفها.';

  @override
  String get noActiveSessions => 'لا توجد جلسات نشطة.';

  @override
  String get currentSessionBadge => 'هذا الجهاز';

  @override
  String sessionMeta(String issuedAt, String expiresAt) {
    return 'تم تسجيل الدخول $issuedAt • تنتهي $expiresAt';
  }

  @override
  String get revokeAction => 'إلغاء';

  @override
  String get revokeSessionTitle => 'إلغاء هذه الجلسة؟';

  @override
  String get revokeSessionConfirm =>
      'سيتم تسجيل خروج الجهاز الذي يستخدم هذه الجلسة في المرة التالية التي يحاول فيها تجديد رمز الوصول.';

  @override
  String get revokeCurrentSessionWarn =>
      'هذه جلستك الحالية. إلغاؤها سيسجّل خروجك من هذا الجهاز فورًا.';

  @override
  String get sessionRevoked => 'تم إلغاء الجلسة.';

  @override
  String revokeFailed(String error) {
    return 'تعذّر الإلغاء: $error';
  }

  @override
  String get unknownDevice => 'جهاز غير معروف';

  @override
  String get viewPermissionLabel => 'صلاحية العرض';

  @override
  String get editPermissionLabel => 'صلاحية التعديل';

  @override
  String get fieldPermissionHelp =>
      'رمز صلاحية اختياري. اتركه فارغًا ليرث صلاحيات الكيان.';

  @override
  String get generateResetToken => 'إنشاء رمز إعادة تعيين كلمة المرور';

  @override
  String get generateResetTokenTitle => 'إنشاء رمز إعادة التعيين؟';

  @override
  String generateResetTokenConfirm(String username) {
    return 'إنشاء رمز إعادة تعيين كلمة مرور لمرة واحدة للمستخدم \"$username\"؟ يُعرض الرمز مرة واحدة فقط — انسخه وشاركه مع المستخدم بطريقة خارج النظام.';
  }

  @override
  String get generate => 'إنشاء';

  @override
  String resetTokenFailed(String error) {
    return 'تعذّر إنشاء الرمز: $error';
  }

  @override
  String resetTokenDialogTitle(String username) {
    return 'رمز إعادة التعيين لـ $username';
  }

  @override
  String get resetTokenWarning =>
      'احفظ هذا الرمز الآن. يُعرض مرة واحدة فقط ولا يمكن استرجاعه لاحقًا.';

  @override
  String resetTokenExpires(String when) {
    return 'ينتهي $when';
  }

  @override
  String get resetTokenLabel => 'الرمز';

  @override
  String get resetUrlLabel => 'رابط إعادة التعيين';

  @override
  String get copyToken => 'نسخ الرمز';

  @override
  String get copyResetUrl => 'نسخ الرابط';

  @override
  String get copiedToClipboard => 'تم النسخ';

  @override
  String get resetPasswordTitle => 'إعادة تعيين كلمة المرور';

  @override
  String get resetPasswordBody =>
      'أدخل رمز إعادة التعيين الذي أعطاك إيّاه المسؤول، ثم اختر كلمة مرور جديدة.';

  @override
  String get resetTokenField => 'رمز إعادة التعيين';

  @override
  String get newPasswordField => 'كلمة المرور الجديدة';

  @override
  String get confirmPasswordField => 'تأكيد كلمة المرور';

  @override
  String get passwordsMustMatch => 'كلمتا المرور غير متطابقتين';

  @override
  String get resetPasswordAction => 'إعادة تعيين كلمة المرور';

  @override
  String get resetPasswordSuccess =>
      'تم إعادة تعيين كلمة المرور. سجّل الدخول بكلمة المرور الجديدة.';

  @override
  String resetPasswordFailedMsg(String error) {
    return 'فشلت إعادة التعيين: $error';
  }

  @override
  String get twoFactorTitle => 'المصادقة الثنائية';

  @override
  String get twoFactorCodeHint =>
      'أدخل الرمز المكوّن من 6 أرقام من تطبيق المصادقة.';

  @override
  String get twoFactorRecoveryHint =>
      'أدخل أحد رموز الاسترداد (10 أحرف ست عشرية، الشَرَطات اختيارية).';

  @override
  String get twoFactorCodeField => 'رمز المصادقة';

  @override
  String get recoveryCodeField => 'رمز الاسترداد';

  @override
  String get useRecoveryInstead => 'استخدم رمز استرداد بدلاً من ذلك';

  @override
  String get useTotpInstead => 'استخدم رمز التطبيق بدلاً من ذلك';

  @override
  String get twoFactorEnabled => 'مفعَّلة';

  @override
  String get twoFactorNotEnabled => 'غير مفعَّلة';

  @override
  String twoFactorEnabledOn(String when) {
    return 'مفعَّلة منذ $when';
  }

  @override
  String get enable2FA => 'تفعيل المصادقة الثنائية';

  @override
  String get disable2FA => 'تعطيل المصادقة الثنائية';

  @override
  String get enable2FAStep1 =>
      'الخطوة 1: امسح رمز QR هذا بتطبيق المصادقة (أو الصق الرمز السري يدويًا).';

  @override
  String get enable2FAStep2 =>
      'الخطوة 2: أدخل الرمز المكوّن من 6 أرقام الذي يعرضه التطبيق للتأكيد.';

  @override
  String get secretLabel => 'الرمز السري';

  @override
  String get copySecret => 'نسخ الرمز السري';

  @override
  String get recoveryCodesTitle => 'احفظ رموز الاسترداد';

  @override
  String get recoveryCodesBody =>
      'يمكن استخدام كل رمز مرة واحدة فقط في حال فقدان الوصول إلى تطبيق المصادقة. احفظها في مكان آمن — لن تُعرض مرة أخرى.';

  @override
  String get copyRecoveryCodes => 'نسخ جميع الرموز';

  @override
  String get twoFactorEnableSuccess => 'تم تفعيل المصادقة الثنائية.';

  @override
  String get twoFactorDisableSuccess => 'تم تعطيل المصادقة الثنائية.';

  @override
  String get twoFactorEnableFailed =>
      'فشل التحقق. حاول مجددًا برمز جديد من تطبيق المصادقة.';

  @override
  String twoFactorDisableFailed(String error) {
    return 'تعذّر التعطيل: $error';
  }

  @override
  String get disable2FATitle => 'تعطيل المصادقة الثنائية؟';

  @override
  String get disable2FABody =>
      'أدخل رمز المصادقة الحالي (أو رمز استرداد) للتأكيد.';

  @override
  String get reset2FA => 'إعادة تعيين المصادقة الثنائية';

  @override
  String reset2FAConfirm(String username) {
    return 'إعادة تعيين المصادقة الثنائية للمستخدم \"$username\"؟ سيؤدي هذا إلى تعطيل المصادقة الثنائية وإزالة رموز الاسترداد. استخدم هذا الخيار عند فقدان المستخدم لتطبيق المصادقة وجميع رموز الاسترداد.';
  }

  @override
  String reset2FASuccess(String username) {
    return 'تمت إعادة تعيين المصادقة الثنائية لـ $username';
  }

  @override
  String reset2FAWasNotEnabled(String username) {
    return 'لم تكن المصادقة الثنائية مفعَّلة لـ $username — لا شيء لإعادة تعيينه.';
  }

  @override
  String get forgotPasswordTitle => 'نسيت كلمة المرور';

  @override
  String get forgotPasswordLink => 'نسيت كلمة المرور؟';

  @override
  String get forgotPasswordPrompt =>
      'أدخل اسم المستخدم أو البريد الإلكتروني. إذا كان الحساب موجودًا، سنرسل لك رابط إعادة تعيين لمرة واحدة.';

  @override
  String get sending => 'جاري الإرسال…';

  @override
  String get sendResetLink => 'إرسال رابط إعادة التعيين';

  @override
  String get backToSignIn => 'العودة إلى تسجيل الدخول';

  @override
  String get checkYourEmail => 'تحقق من بريدك الإلكتروني';

  @override
  String get resetLinkSentMessage =>
      'إذا كان هناك حساب بهذا الاسم أو البريد الإلكتروني، فقد تم إرسال رابط إعادة التعيين. الرابط صالح لمدة ساعة ويمكن استخدامه مرة واحدة فقط.';

  @override
  String get emailNotConfiguredOnServer =>
      'البريد الإلكتروني غير مُهيأ على هذا الخادم. اطلب من المسؤول إعادة تعيين كلمة المرور يدويًا.';

  @override
  String somethingWentWrongDetail(String error) {
    return 'حدث خطأ ما: $error';
  }
}
