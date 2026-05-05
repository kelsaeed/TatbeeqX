// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'app_localizations.dart';

// ignore_for_file: type=lint

/// The translations for French (`fr`).
class AppLocalizationsFr extends AppLocalizations {
  AppLocalizationsFr([String locale = 'fr']) : super(locale);

  @override
  String get appName => 'TatbeeqX';

  @override
  String get signIn => 'Se connecter';

  @override
  String get signInToContinue => 'Connectez-vous pour continuer';

  @override
  String get usernameOrEmail => 'Nom d\'utilisateur ou e-mail';

  @override
  String get password => 'Mot de passe';

  @override
  String get signOut => 'Se déconnecter';

  @override
  String get loginTagline => 'Prêt pour le LAN • sécurisé par JWT';

  @override
  String get manageEveryBusiness => 'Gérez chaque entreprise,';

  @override
  String get inOnePlace => 'au même endroit.';

  @override
  String get loginHeroSubtitle =>
      'Multi-société, multi-succursale, basé sur les rôles, entièrement personnalisable.';

  @override
  String get save => 'Enregistrer';

  @override
  String get cancel => 'Annuler';

  @override
  String get delete => 'Supprimer';

  @override
  String get edit => 'Modifier';

  @override
  String get create => 'Créer';

  @override
  String get newItem => 'Nouveau';

  @override
  String get search => 'Rechercher';

  @override
  String get loading => 'Chargement…';

  @override
  String get error => 'Erreur';

  @override
  String get noData => 'Aucune donnée';

  @override
  String get ok => 'OK';

  @override
  String get yes => 'Oui';

  @override
  String get no => 'Non';

  @override
  String get refresh => 'Actualiser';

  @override
  String get saving => 'Enregistrement…';

  @override
  String get required => 'Requis';

  @override
  String get company => 'Société';

  @override
  String get noCompany => 'Aucune société';

  @override
  String get globalTheme => '— Thème global —';

  @override
  String get switchCompany => 'Changer de société';

  @override
  String get language => 'Langue';

  @override
  String get account => 'Compte';

  @override
  String get superAdmin => 'Super Administrateur';

  @override
  String get user => 'Utilisateur';

  @override
  String get dashboard => 'Tableau de bord';

  @override
  String get users => 'Utilisateurs';

  @override
  String get roles => 'Rôles';

  @override
  String get companies => 'Sociétés';

  @override
  String get branches => 'Succursales';

  @override
  String get audit => 'Journaux d\'audit';

  @override
  String get settings => 'Paramètres';

  @override
  String get appearance => 'Apparence';

  @override
  String get reports => 'Rapports';

  @override
  String get database => 'Base de données';

  @override
  String get customEntities => 'Entités personnalisées';

  @override
  String get templates => 'Modèles';

  @override
  String get pages => 'Pages';

  @override
  String get system => 'Système';

  @override
  String get systemLogs => 'Journaux système';

  @override
  String get loginActivity => 'Activité de connexion';

  @override
  String get approvals => 'Approbations';

  @override
  String get reportSchedules => 'Planifications de rapports';

  @override
  String get webhooks => 'Webhooks';

  @override
  String get backups => 'Sauvegardes';

  @override
  String deleteConfirm(String name) {
    return 'Supprimer « $name » ?';
  }

  @override
  String loadFailed(String error) {
    return 'Échec du chargement : $error';
  }

  @override
  String saveFailed(String error) {
    return 'Échec de l\'enregistrement : $error';
  }

  @override
  String deleteFailedMsg(String error) {
    return 'Échec de la suppression : $error';
  }

  @override
  String createFailed(String error) {
    return 'Échec de la création : $error';
  }

  @override
  String adminRestricted(String feature) {
    return '$feature est réservé au Super Administrateur';
  }

  @override
  String get apply => 'Appliquer';

  @override
  String get activate => 'Activer';

  @override
  String get duplicate => 'Dupliquer';

  @override
  String get resetLabel => 'Réinitialiser';

  @override
  String get run => 'Exécuter';

  @override
  String get importLabel => 'Importer';

  @override
  String get exportLabel => 'Exporter';

  @override
  String get add => 'Ajouter';

  @override
  String get remove => 'Retirer';

  @override
  String get close => 'Fermer';

  @override
  String get back => 'Retour';

  @override
  String get name => 'Nom';

  @override
  String get code => 'Code';

  @override
  String get email => 'E-mail';

  @override
  String get statusLabel => 'Statut';

  @override
  String get typeLabel => 'Type';

  @override
  String get defaultLabel => 'Par défaut';

  @override
  String get actionsLabel => 'Actions';

  @override
  String get descriptionLabel => 'Description';

  @override
  String get systemChip => 'Système';

  @override
  String get enabledLabel => 'Activé';

  @override
  String get disabledLabel => 'Désactivé';

  @override
  String get active => 'Actif';

  @override
  String get inactive => 'Inactif';

  @override
  String get all => 'Tout';

  @override
  String get noneLabel => 'Aucun';

  @override
  String pageOfTotal(int page, int total) {
    return 'Page $page sur $total';
  }

  @override
  String permissionsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count permissions',
      one: '1 permission',
      zero: 'Aucune permission',
    );
    return '$_temp0';
  }

  @override
  String usersCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count utilisateurs',
      one: '1 utilisateur',
      zero: 'Aucun utilisateur',
    );
    return '$_temp0';
  }

  @override
  String get rolesSubtitle =>
      'Définissez les rôles et attribuez des permissions granulaires.';

  @override
  String get auditSubtitle =>
      'Chronologie de chaque action importante du système.';

  @override
  String get backupsSubtitle =>
      'Instantanés de la base de données principale. La restauration écrase la base en cours et nécessite un redémarrage.';

  @override
  String get reportsSubtitle =>
      'Rapports pré-construits. Exécutez-les pour voir les données actualisées.';

  @override
  String get dashboardSubtitle => 'Voici un aperçu rapide de votre système.';

  @override
  String get loginFailed => 'Échec de la connexion';

  @override
  String get searchHint => 'Rechercher…';

  @override
  String totalLabel(int count) {
    return '$count au total';
  }

  @override
  String fileNotFound(String path) {
    return 'Fichier introuvable : $path';
  }

  @override
  String get uploaded => 'Téléversé';

  @override
  String uploadFailed(String error) {
    return 'Échec du téléversement : $error';
  }

  @override
  String get upload => 'Téléverser';

  @override
  String get uploading => 'Téléversement…';

  @override
  String get uploadHint =>
      '…ou collez un chemin de fichier local (ex. C:\\images\\logo.png) et appuyez sur Téléverser';

  @override
  String get urlHint => 'URL';

  @override
  String get restore => 'Restaurer';

  @override
  String get auditWhen => 'Quand';

  @override
  String get auditUser => 'Utilisateur';

  @override
  String get auditAction => 'Action';

  @override
  String get auditEntity => 'Entité';

  @override
  String get auditId => 'ID';

  @override
  String get auditIp => 'IP';

  @override
  String get systemUserLabel => 'système';

  @override
  String get createBackup => 'Créer une sauvegarde';

  @override
  String get backupLabelField => 'Étiquette (optionnelle, minuscules + tirets)';

  @override
  String get backupLabelExample => 'ex. before-month-end';

  @override
  String get deleteBackupTitle => 'Supprimer la sauvegarde ?';

  @override
  String deleteBackupWarn(String name) {
    return 'Ceci supprime définitivement « $name » du disque.';
  }

  @override
  String get restoreBackupTitle => 'Restaurer la sauvegarde ?';

  @override
  String restoreBackupWarn(String name) {
    return 'Ceci écrase la base de données actuelle avec « $name ». Après la restauration, le processus de l\'API doit être redémarré avant que les changements ne prennent effet.\n\nLes données créées depuis cette sauvegarde seront perdues.';
  }

  @override
  String get restoreCompleteRestart =>
      'Restauration terminée. Redémarrage requis.';

  @override
  String get noBackupsYet =>
      'Aucune sauvegarde pour l\'instant. Cliquez sur « Nouveau ».';

  @override
  String get noReportsDefined => 'Aucun rapport défini';

  @override
  String get noPermissionReports =>
      'Vous n\'avez pas la permission de voir les rapports.';

  @override
  String get auditEventsLast14 => 'Événements d\'audit — 14 derniers jours';

  @override
  String get auditByEntityLast30 => 'Audit par entité — 30 derniers jours';

  @override
  String get recentLogins => 'Connexions récentes';

  @override
  String get recentAuditEvents => 'Événements d\'audit récents';

  @override
  String get noActivityYet => 'Aucune activité pour l\'instant';

  @override
  String get noDataYet => 'Aucune donnée pour l\'instant';

  @override
  String get noAuditEntriesYet => 'Aucune entrée d\'audit pour l\'instant';

  @override
  String get auditEventsCount => 'Événements d\'audit';

  @override
  String failedShort(String error) {
    return 'Échec : $error';
  }

  @override
  String get username => 'Nom d\'utilisateur';

  @override
  String get fullName => 'Nom complet';

  @override
  String get phoneOptional => 'Téléphone (optionnel)';

  @override
  String get phone => 'Téléphone';

  @override
  String get address => 'Adresse';

  @override
  String get legalName => 'Raison sociale';

  @override
  String get taxNumber => 'Numéro fiscal';

  @override
  String get logoUrl => 'URL du logo';

  @override
  String get passwordField => 'Mot de passe';

  @override
  String get newPasswordKeepBlank =>
      'Nouveau mot de passe (laisser vide pour conserver)';

  @override
  String get min8Chars => '8 caractères minimum';

  @override
  String get invalidEmail => 'E-mail invalide';

  @override
  String get noneOption => '— Aucun —';

  @override
  String get branchField => 'Succursale';

  @override
  String get companyField => 'Société';

  @override
  String get rolesField => 'Rôles';

  @override
  String deleteCannotBeUndone(String name) {
    return 'Supprimer « $name » ? Cette action est irréversible.';
  }

  @override
  String deleteCascadeWarn(String name) {
    return 'Supprimer « $name » ? Les succursales et données liées seront supprimées en cascade.';
  }

  @override
  String get selectCompany => 'Sélectionnez une société';

  @override
  String get noBranches => 'Aucune succursale';

  @override
  String branchesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count succursales',
      one: '1 succursale',
      zero: 'Aucune succursale',
    );
    return '$_temp0';
  }

  @override
  String get usersSubtitle => 'Créez et gérez les utilisateurs du système.';

  @override
  String get newUser => 'Nouvel utilisateur';

  @override
  String get editUser => 'Modifier l\'utilisateur';

  @override
  String get deleteUser => 'Supprimer l\'utilisateur';

  @override
  String get searchUsers => 'Rechercher des utilisateurs…';

  @override
  String get companiesSubtitle =>
      'Chaque société peut avoir ses propres succursales, utilisateurs et thème.';

  @override
  String get newCompany => 'Nouvelle société';

  @override
  String get editCompany => 'Modifier la société';

  @override
  String get deleteCompany => 'Supprimer la société';

  @override
  String codeColon(String code) {
    return 'Code : $code';
  }

  @override
  String get branchesSubtitle => 'Les succursales appartiennent aux sociétés.';

  @override
  String get newBranch => 'Nouvelle succursale';

  @override
  String get editBranch => 'Modifier la succursale';

  @override
  String get deleteBranch => 'Supprimer la succursale';

  @override
  String get settingsSubtitle =>
      'Paramètres clé/valeur au niveau du système. Tout élément marqué « public » est visible sans authentification.';

  @override
  String get addRow => 'Ajouter une ligne';

  @override
  String get settingsSaved => 'Paramètres enregistrés';

  @override
  String get keyField => 'Clé';

  @override
  String get valueField => 'Valeur';

  @override
  String get typeField => 'Type';

  @override
  String get publicLabel => 'Public';

  @override
  String get noSettingsYet => 'Aucun paramètre pour l\'instant';

  @override
  String get loginActivitySubtitle =>
      'Chaque connexion, rafraîchissement, déconnexion et tentative échouée.';

  @override
  String get eventField => 'Événement';

  @override
  String get allEvents => 'Tous les événements';

  @override
  String get loginEvent => 'Connexion';

  @override
  String get logoutEvent => 'Déconnexion';

  @override
  String get refreshEvent => 'Rafraîchissement';

  @override
  String get successField => 'Succès';

  @override
  String get successfulOption => 'Réussi';

  @override
  String get failedOption => 'Échoué';

  @override
  String get searchLoginEvents =>
      'Rechercher par utilisateur, IP ou user agent…';

  @override
  String get resultColumn => 'Résultat';

  @override
  String get okShort => 'OK';

  @override
  String get failShort => 'FAIL';

  @override
  String get reasonColumn => 'Raison';

  @override
  String get systemLogsSubtitle =>
      'Événements côté serveur : démarrage, erreurs, avertissements, infos.';

  @override
  String get clearOlderThan30 => 'Effacer les plus anciens de 30 jours';

  @override
  String get clearOldLogsTitle => 'Effacer les anciens journaux ?';

  @override
  String get clearOldLogsBody =>
      'Supprime tous les journaux système plus anciens que 30 jours. Action irréversible.';

  @override
  String get levelField => 'Niveau';

  @override
  String get allLevels => 'Tous les niveaux';

  @override
  String get levelDebug => 'Debug';

  @override
  String get levelInfo => 'Info';

  @override
  String get levelWarn => 'Avertissement';

  @override
  String get levelError => 'Erreur';

  @override
  String get sourceField => 'Source';

  @override
  String get searchMessageContext => 'Rechercher dans le message ou contexte…';

  @override
  String get messageField => 'Message';

  @override
  String get webhooksSubtitle =>
      'Notifications POST vers des URL externes lors d\'événements système. Signées HMAC.';

  @override
  String get newWebhook => 'Nouveau webhook';

  @override
  String get noSubscriptionsYet => 'Aucun abonnement pour l\'instant.';

  @override
  String get enableLabel => 'Activer';

  @override
  String get disableLabel => 'Désactiver';

  @override
  String get sendTestEvent => 'Envoyer un événement test';

  @override
  String get recentDeliveries => 'Livraisons récentes';

  @override
  String get testEventDispatched => 'Événement test envoyé';

  @override
  String get deleteSubscriptionTitle => 'Supprimer l\'abonnement ?';

  @override
  String get deleteSubscriptionBody =>
      'Supprime l\'abonnement et tout l\'historique de livraison.';

  @override
  String recentDeliveriesFor(String name) {
    return 'Livraisons récentes — $name';
  }

  @override
  String get noDeliveriesYet => 'Aucune livraison pour l\'instant.';

  @override
  String get newWebhookSubscription => 'Nouvel abonnement webhook';

  @override
  String get codeLowerSnake => 'Code (minuscules, snake_case)';

  @override
  String get urlHttps => 'URL (https://...)';

  @override
  String get secretOptionalAuto =>
      'Secret (optionnel — généré automatiquement si vide)';

  @override
  String get eventsLabel => 'Événements';

  @override
  String get pickAtLeastOneEvent => 'Sélectionnez au moins un événement';

  @override
  String get webhookSecretTitle => 'Secret du webhook';

  @override
  String webhookSecretSaveWarn(String secret) {
    return 'Enregistrez ce secret en lieu sûr — il ne sera plus affiché :\n\n$secret';
  }

  @override
  String get approvalsSubtitle =>
      'Demandes en attente d\'une personne avec <entity>.approve.';

  @override
  String get newRequest => 'Nouvelle demande';

  @override
  String get statusPending => 'En attente';

  @override
  String get statusApproved => 'Approuvée';

  @override
  String get statusRejected => 'Rejetée';

  @override
  String get statusCancelled => 'Annulée';

  @override
  String get approveLabel => 'Approuver';

  @override
  String get rejectLabel => 'Rejeter';

  @override
  String get approveTitle => 'Approuver la demande ?';

  @override
  String get rejectTitle => 'Rejeter la demande ?';

  @override
  String get noteOptional => 'Note (optionnelle)';

  @override
  String get requestApproval => 'Demander une approbation';

  @override
  String get entityProductsHint => 'Entité (ex. products)';

  @override
  String get titleField => 'Titre';

  @override
  String get submitLabel => 'Soumettre';

  @override
  String get approvalsRequestedBy => 'Demandé par';

  @override
  String get approvalsTitleColumn => 'Titre';

  @override
  String get setupLocked =>
      'La configuration est verrouillée. Demandez au Super Administrateur de choisir un type d\'activité.';

  @override
  String get welcomePickBusinessType =>
      'Bienvenue — choisissez un type d\'activité';

  @override
  String get setupExplain =>
      'Ceci détermine les modules, tables et menus initiaux. Vous pouvez tout modifier plus tard, ajouter des tables et exécuter du SQL depuis la page Base de données.';

  @override
  String get alreadyConfiguredHint =>
      'Déjà configuré ? Visitez les pages Entités personnalisées et Base de données pour ajouter des tables, modifier des colonnes ou exécuter du SQL.';

  @override
  String get skipAndContinue => 'Passer et continuer';

  @override
  String get useThis => 'Utiliser celui-ci';

  @override
  String applyFailed(String error) {
    return 'Échec de l\'application : $error';
  }

  @override
  String get deleteRowTitle => 'Supprimer la ligne';

  @override
  String newEntitySingular(String singular) {
    return 'Nouveau $singular';
  }

  @override
  String editEntitySingular(String singular) {
    return 'Modifier $singular';
  }

  @override
  String tableLabel(String tableName) {
    return 'Table : $tableName';
  }

  @override
  String searchEntityHint(String label) {
    return 'Rechercher $label…';
  }

  @override
  String get customEntitiesAdminRestricted =>
      'L\'administration des entités personnalisées est réservée au Super Administrateur.';

  @override
  String get customEntitiesSubtitle =>
      'Tables adaptées à votre activité. Chaque entité a ses propres permissions, son menu et sa page CRUD.';

  @override
  String get newEntity => 'Nouvelle entité';

  @override
  String get editEntity => 'Modifier l\'entité';

  @override
  String get noCustomEntitiesYet =>
      'Aucune entité personnalisée pour l\'instant.';

  @override
  String deleteEntityTitle(String label) {
    return 'Supprimer « $label »';
  }

  @override
  String get deleteEntityBody =>
      'Vous pouvez soit conserver la table sous-jacente (données préservées, seul l\'enregistrement est supprimé), soit la supprimer (irréversible).';

  @override
  String get unregisterOnly => 'Désenregistrer seulement';

  @override
  String get dropTable => 'Supprimer la table';

  @override
  String get addColumn => 'Ajouter une colonne';

  @override
  String get addAtLeastOneColumn => 'Ajoutez au moins une colonne';

  @override
  String get codeUsedInUrl => 'Code (utilisé dans l\'URL et l\'API)';

  @override
  String get sqlTableName => 'Nom de la table SQL';

  @override
  String get displayLabelPlural => 'Libellé d\'affichage (pluriel)';

  @override
  String get singularName => 'Nom au singulier';

  @override
  String get categoryField => 'Catégorie';

  @override
  String get iconNameField => 'Nom de l\'icône';

  @override
  String get iconNameHint => 'reports, business, store, …';

  @override
  String get columnsLabel => 'Colonnes';

  @override
  String get systemEntitiesAlterWarn =>
      'Entités système — les modifications de colonnes ne sont pas encore propagées à la table SQL. Utilisez l\'admin Base de données pour exécuter ALTER manuellement.';

  @override
  String get updateLabel => 'Mettre à jour';

  @override
  String get fieldNameSnakeCase => 'Nom du champ (snake_case)';

  @override
  String get labelField => 'Libellé';

  @override
  String get requiredLabel => 'Requis';

  @override
  String get uniqueLabel => 'Unique';

  @override
  String get searchableLabel => 'Recherchable';

  @override
  String get showInList => 'Afficher dans la liste';

  @override
  String starterTablesCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count tables de démarrage',
      one: '1 table de démarrage',
      zero: 'Aucune table de démarrage',
    );
    return '$_temp0';
  }

  @override
  String columnsCount(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count colonnes',
      one: '1 colonne',
      zero: 'Aucune colonne',
    );
    return '$_temp0';
  }

  @override
  String get reportSchedulesSubtitle =>
      'Exécutez n\'importe quel rapport à une cadence récurrente. Les résultats sont stockés sur chaque planification.';

  @override
  String get newSchedule => 'Nouvelle planification';

  @override
  String get noSchedulesYet =>
      'Aucune planification pour l\'instant. Cliquez sur « Nouvelle planification ».';

  @override
  String get runNow => 'Exécuter maintenant';

  @override
  String get recentRuns => 'Exécutions récentes';

  @override
  String get runSucceeded => 'Exécution réussie';

  @override
  String runFailedMsg(String error) {
    return 'Échec de l\'exécution : $error';
  }

  @override
  String get deleteScheduleTitle => 'Supprimer la planification ?';

  @override
  String get deleteScheduleBody =>
      'Ceci arrête les exécutions futures et supprime la planification + son historique.';

  @override
  String recentRunsFor(String name) {
    return 'Exécutions récentes — $name';
  }

  @override
  String get noRunsYet => 'Aucune exécution pour l\'instant.';

  @override
  String get noReportsDefinedYet => 'Aucun rapport défini pour l\'instant.';

  @override
  String get templatesSubtitle =>
      'Capturez le thème actuel + les tables personnalisées. Réappliquez plus tard ou partagez entre installations.';

  @override
  String get templatesRestricted =>
      'Les modèles sont réservés au Super Administrateur.';

  @override
  String get saveCurrentSetup =>
      'Enregistrer la configuration actuelle comme modèle';

  @override
  String get saveCurrent => 'Enregistrer l\'actuel';

  @override
  String get importJson => 'Importer JSON';

  @override
  String get noTemplatesYet => 'Aucun modèle pour l\'instant.';

  @override
  String applyTemplateTitle(String name) {
    return 'Appliquer « $name » ?';
  }

  @override
  String get applyTemplateBody =>
      'Ceci enregistrera toutes les tables personnalisées et activera le thème du modèle. Les tables existantes du même nom sont conservées (seul l\'enregistrement est mis à jour).';

  @override
  String get templateSaved => 'Modèle enregistré';

  @override
  String get templateApplied => 'Modèle appliqué';

  @override
  String get copiedJsonToClipboard => 'JSON copié dans le presse-papiers';

  @override
  String exportFailed(String error) {
    return 'Échec de l\'exportation : $error';
  }

  @override
  String get importTemplateTitle => 'Importer un modèle';

  @override
  String get templateImported => 'Modèle importé';

  @override
  String importFailed(String error) {
    return 'Échec de l\'importation : $error';
  }

  @override
  String invalidJson(String error) {
    return 'JSON invalide : $error';
  }

  @override
  String get deleteTemplateTitle => 'Supprimer le modèle';

  @override
  String get copyJson => 'Copier JSON';

  @override
  String get applyAction => 'Appliquer';

  @override
  String get pagesSubtitle =>
      'Pages personnalisées composées de blocs. Conçues dans le générateur de pages.';

  @override
  String get newPage => 'Nouvelle page';

  @override
  String get noPagesYet =>
      'Aucune page personnalisée pour l\'instant. Cliquez sur « Nouvelle page » pour en concevoir une.';

  @override
  String get deletePageTitle => 'Supprimer la page ?';

  @override
  String get deletePageBody => 'Supprime la page et tous ses blocs.';

  @override
  String get openInBuilder => 'Ouvrir dans le générateur';

  @override
  String get openPage => 'Ouvrir la page';

  @override
  String get pagesStatLabel => 'Pages';

  @override
  String get blocksStatLabel => 'Blocs';

  @override
  String get avgBlocksPerPage => 'Blocs moyens / page';

  @override
  String get blockUsage => 'Utilisation des blocs';

  @override
  String get addBlock => 'Ajouter un bloc';

  @override
  String get emptyPageHint =>
      'Page vide. Ajoutez des blocs depuis le panneau de droite.';

  @override
  String get themeBuilderRestricted =>
      'Le générateur de thèmes est réservé au Super Administrateur.';

  @override
  String get themeBuilderTitle => 'Générateur de thèmes';

  @override
  String themeBuilderEditing(String name) {
    return 'Modification de « $name »';
  }

  @override
  String get saveAndActivate => 'Enregistrer et activer';

  @override
  String get themeActivated => 'Thème activé';

  @override
  String get themeSavedMsg => 'Thème enregistré';

  @override
  String get systemSubtitle =>
      'Informations serveur, connexions de bases de données et configuration.';

  @override
  String get databaseConnectionsHeader => 'Connexions de bases de données';

  @override
  String get addConnectionLabel => 'Ajouter une connexion';

  @override
  String get noConnectionsYet =>
      'Aucune connexion pour l\'instant. Ajoutez-en une pour changer de base de données depuis l\'UI.';

  @override
  String get primaryChip => 'PRIMAIRE';

  @override
  String get promoteToPrimary => 'Promouvoir comme primaire';

  @override
  String get promoteToPrimaryTitle => 'Promouvoir comme primaire ?';

  @override
  String get promoteWarn =>
      'Ceci réécrit DATABASE_URL dans .env. Le serveur doit être redémarré avant que les changements ne prennent effet, et la nouvelle base de données doit déjà avoir le schéma. Une sauvegarde du .env précédent est conservée dans .env-backups/.';

  @override
  String get promoteAction => 'Promouvoir';

  @override
  String get updatedRestartRequired => 'Mis à jour. Redémarrage requis.';

  @override
  String get deleteConnectionTitle => 'Supprimer la connexion ?';

  @override
  String get deleteConnectionBody =>
      'Supprime la connexion enregistrée du registre. N\'affecte pas la base de données elle-même.';

  @override
  String get initDatabaseHeader => 'Initialiser la base de données avec SQL';

  @override
  String get initDatabaseHint =>
      'Collez des instructions CREATE TABLE / ALTER TABLE / INSERT séparées par des points-virgules. Les instructions s\'exécutent dans l\'ordre.';

  @override
  String get runStatements => 'Exécuter les instructions';

  @override
  String get running => 'Exécution…';

  @override
  String get addDatabaseConnection =>
      'Ajouter une connexion de base de données';

  @override
  String get databaseSubtitle =>
      'Inspectez les tables, prévisualisez les lignes, exécutez du SQL. Toutes les requêtes sont auditées.';

  @override
  String get databaseRestricted =>
      'L\'admin de base de données est réservé au Super Administrateur.';

  @override
  String describeFailed(String error) {
    return 'Échec de la description : $error';
  }

  @override
  String get runWriteQueryTitle => 'Exécuter une requête d\'écriture ?';

  @override
  String get runWriteQueryBody =>
      'Vous êtes sur le point d\'exécuter du SQL en mode écriture. Assurez-vous de savoir ce que cela fait. Les tables d\'authentification principales sont toujours protégées.';

  @override
  String get saveQueryTitle => 'Enregistrer la requête';

  @override
  String get querySavedMsg => 'Requête enregistrée';

  @override
  String get sqlRunner => 'Exécuteur SQL';

  @override
  String get writeMode => 'Mode écriture';

  @override
  String get savedQueriesHeader => 'Requêtes enregistrées';

  @override
  String get nothingSavedYet => 'Rien d\'enregistré pour l\'instant.';

  @override
  String get loadAction => 'Charger';

  @override
  String noRowsReturnedMsg(String count) {
    return 'Aucune ligne retournée ($count).';
  }

  @override
  String get columnsHeader => 'Colonnes';

  @override
  String get foreignKeysHeader => 'Clés étrangères';

  @override
  String previewHeader(int count) {
    return 'Aperçu (premières $count lignes)';
  }

  @override
  String get editSubsystemTooltip => 'Modifier identité et modules';

  @override
  String editSubsystemTitle(String name) {
    return 'Identité et modules — $name';
  }

  @override
  String get brandingSection => 'Identité visuelle';

  @override
  String get modulesSection => 'Modules';

  @override
  String get modulesHelp =>
      'Les modules de base (tableau de bord, utilisateurs, etc.) sont fusionnés automatiquement — listez uniquement les éléments supplémentaires de la barre latérale que ce sous-système doit exposer.';

  @override
  String get subsystemSaved => 'Paramètres du sous-système enregistrés';

  @override
  String get appNameLabel => 'Nom de l\'application';

  @override
  String get logoUrlLabel => 'URL du logo';

  @override
  String get primaryColorLabel => 'Couleur principale';

  @override
  String get iconPathLabel => 'Chemin de l\'icône (.ico)';

  @override
  String get addModuleLabel => 'Ajouter un code de module';

  @override
  String get addBlockHeader => 'Ajouter un bloc';

  @override
  String get blockTypeText => 'Texte';

  @override
  String get blockTypeHeading => 'Titre';

  @override
  String get blockTypeImage => 'Image';

  @override
  String get blockTypeButton => 'Bouton';

  @override
  String get blockTypeCard => 'Carte';

  @override
  String get blockTypeContainer => 'Conteneur';

  @override
  String get blockTypeDivider => 'Séparateur';

  @override
  String get blockTypeSpacer => 'Espace';

  @override
  String get blockTypeList => 'Liste';

  @override
  String get blockTypeTable => 'Tableau';

  @override
  String get blockTypeChart => 'Graphique';

  @override
  String get blockTypeIframe => 'Intégration (iframe)';

  @override
  String get blockTypeHtml => 'HTML brut';

  @override
  String get blockTypeCustomEntityList => 'Liste d\'entités personnalisées';

  @override
  String get blockTypeReport => 'Rapport';

  @override
  String inspectorEditTitle(String label) {
    return 'Modifier $label';
  }

  @override
  String get inspectorTitleText => 'Modifier le texte';

  @override
  String get inspectorTitleHeading => 'Modifier le titre';

  @override
  String get inspectorTitleImage => 'Modifier l\'image';

  @override
  String get inspectorTitleButton => 'Modifier le bouton';

  @override
  String get inspectorTitleCard => 'Modifier la carte';

  @override
  String get inspectorTitleSpacer => 'Modifier l\'espace';

  @override
  String get inspectorTitleIframe => 'Modifier l\'iframe';

  @override
  String get inspectorTitleHtml => 'Modifier le HTML';

  @override
  String get inspectorTitleReport => 'Modifier le bloc rapport';

  @override
  String get inspectorTitleEntityList => 'Modifier la liste d\'entités';

  @override
  String get inspectorTitleDivider => 'Séparateur';

  @override
  String get inspectorNoOptions => 'Aucune option à configurer.';

  @override
  String get inspectorLevelLabel => 'Niveau';

  @override
  String get inspectorH1 => 'H1 — affichage';

  @override
  String get inspectorH2 => 'H2 — gros titre';

  @override
  String get inspectorH3 => 'H3 — titre';

  @override
  String get inspectorH4 => 'H4 — sous-titre';

  @override
  String get inspectorImageUrlHint =>
      'https://example.com/photo.jpg ou /uploads/x.png';

  @override
  String get inspectorFitLabel => 'Ajustement';

  @override
  String get inspectorFitCover => 'Couvrir';

  @override
  String get inspectorFitContain => 'Contenir';

  @override
  String get inspectorFitFill => 'Remplir';

  @override
  String get inspectorRouteLabel => 'Route (ex. /products)';

  @override
  String get inspectorStyleLabel => 'Style';

  @override
  String get inspectorVariantFilled => 'Plein';

  @override
  String get inspectorVariantOutlined => 'Contour';

  @override
  String get inspectorVariantText => 'Texte';

  @override
  String get inspectorBodyLabel => 'Corps';

  @override
  String get inspectorHeightPxLabel => 'Hauteur (pixels logiques)';

  @override
  String get inspectorHtmlNotice =>
      'Le HTML est nettoyé côté serveur. Les scripts, les gestionnaires on* et les URL javascript: sont supprimés.';

  @override
  String get inspectorReportCodeLabel => 'Code du rapport (ex. users.by_role)';

  @override
  String get inspectorRenderAsLabel => 'Afficher comme';

  @override
  String get inspectorRenderAsTable => 'Tableau';

  @override
  String get inspectorRenderAsChart => 'Graphique';

  @override
  String get inspectorEntityCodeLabel => 'Code de l\'entité (ex. products)';

  @override
  String get inspectorPageSizeLabel => 'Taille de page';

  @override
  String inspectorInvalidJson(String error) {
    return 'JSON invalide : $error';
  }

  @override
  String get targetEntityLabel => 'Code de l\'entité cible';

  @override
  String relationsAddLabel(String target) {
    return 'Ajouter $target';
  }

  @override
  String get relationsLoadFailed => 'Impossible de charger les options';

  @override
  String get relationsNoTarget => 'Aucune entité cible configurée';

  @override
  String get relationsEmpty => '—';

  @override
  String get exportCsv => 'Exporter en CSV';

  @override
  String csvExportedTo(String path) {
    return 'Enregistré dans $path';
  }

  @override
  String get logoutEverywhereMenu => 'Se déconnecter de tous les appareils';

  @override
  String get logoutEverywhereTitle => 'Se déconnecter de tous les appareils ?';

  @override
  String get logoutEverywhereBody =>
      'Cela mettra fin à toutes les sessions actives de votre compte, sur tous les appareils. Vous devrez vous reconnecter sur chacun.';

  @override
  String get logoutEverywhereConfirm => 'Tout déconnecter';

  @override
  String get recordHistory => 'Historique';

  @override
  String get noHistoryYet => 'Aucun historique pour cet enregistrement.';

  @override
  String get systemActor => 'Système';

  @override
  String get formulaLabel => 'Formule';

  @override
  String get formulaHelp =>
      'Expression numérique. Utilisez les noms de champs (qty, price) et les opérateurs + - * / ( ).';

  @override
  String get computedField => 'Calculé';

  @override
  String get computedHelp =>
      'Cette valeur est calculée automatiquement à partir d\'autres champs.';

  @override
  String get importCsv => 'Importer CSV';

  @override
  String get importCsvHelp =>
      'Collez le contenu CSV. La première ligne doit être un en-tête correspondant aux noms de colonnes de l\'entité. Les colonnes inconnues sont ignorées. Lancez d\'abord Aperçu pour voir ce qui se passerait sans rien écrire.';

  @override
  String get previewAction => 'Aperçu';

  @override
  String get importAction => 'Importer';

  @override
  String get previewBadge => 'APERÇU';

  @override
  String importSummary(int total, int created, int skipped, int errCount) {
    return '$total lignes • $created créées • $skipped ignorées • $errCount erreurs';
  }

  @override
  String bulkDeleteButton(int count) {
    return 'Supprimer $count';
  }

  @override
  String get bulkDeleteTitle => 'Supprimer les lignes sélectionnées ?';

  @override
  String bulkDeleteConfirm(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: 'Supprimer $count lignes ?',
      one: 'Supprimer 1 ligne ?',
    );
    return '$_temp0 Cette action est irréversible.';
  }

  @override
  String bulkDeleteResult(int count) {
    String _temp0 = intl.Intl.pluralLogic(
      count,
      locale: localeName,
      other: '$count lignes supprimées',
      one: '1 ligne supprimée',
      zero: 'Rien supprimé',
    );
    return '$_temp0';
  }

  @override
  String get sessionsTitle => 'Appareils actifs';

  @override
  String get sessionsSubtitle =>
      'Sessions actuellement connectées à votre compte. Révoquez celles que vous ne reconnaissez pas.';

  @override
  String get noActiveSessions => 'Aucune session active.';

  @override
  String get currentSessionBadge => 'CET APPAREIL';

  @override
  String sessionMeta(String issuedAt, String expiresAt) {
    return 'Connecté le $issuedAt • Expire le $expiresAt';
  }

  @override
  String get revokeAction => 'Révoquer';

  @override
  String get revokeSessionTitle => 'Révoquer cette session ?';

  @override
  String get revokeSessionConfirm =>
      'L\'appareil utilisant cette session sera déconnecté lors de la prochaine tentative de rafraîchissement du jeton d\'accès.';

  @override
  String get revokeCurrentSessionWarn =>
      'Il s\'agit de votre session actuelle. La révoquer vous déconnectera immédiatement de cet appareil.';

  @override
  String get sessionRevoked => 'Session révoquée.';

  @override
  String revokeFailed(String error) {
    return 'Échec de la révocation : $error';
  }

  @override
  String get unknownDevice => 'Appareil inconnu';

  @override
  String get viewPermissionLabel => 'Permission de lecture';

  @override
  String get editPermissionLabel => 'Permission d\'écriture';

  @override
  String get fieldPermissionHelp =>
      'Code de permission optionnel. Laissez vide pour hériter des permissions de l\'entité.';

  @override
  String get generateResetToken => 'Générer un jeton de réinitialisation';

  @override
  String get generateResetTokenTitle =>
      'Générer un jeton de réinitialisation ?';

  @override
  String generateResetTokenConfirm(String username) {
    return 'Générer un jeton à usage unique pour \"$username\" ? Le jeton n\'est affiché qu\'une seule fois — copiez-le et partagez-le avec l\'utilisateur hors du système.';
  }

  @override
  String get generate => 'Générer';

  @override
  String resetTokenFailed(String error) {
    return 'Échec de la génération : $error';
  }

  @override
  String resetTokenDialogTitle(String username) {
    return 'Jeton de réinitialisation pour $username';
  }

  @override
  String get resetTokenWarning =>
      'Enregistrez ce jeton maintenant. Il n\'est affiché qu\'une seule fois et ne peut pas être récupéré plus tard.';

  @override
  String resetTokenExpires(String when) {
    return 'Expire $when';
  }

  @override
  String get resetTokenLabel => 'Jeton';

  @override
  String get resetUrlLabel => 'URL de réinitialisation';

  @override
  String get copyToken => 'Copier le jeton';

  @override
  String get copyResetUrl => 'Copier l\'URL';

  @override
  String get copiedToClipboard => 'Copié dans le presse-papiers';

  @override
  String get resetPasswordTitle => 'Réinitialiser votre mot de passe';

  @override
  String get resetPasswordBody =>
      'Entrez le jeton de réinitialisation fourni par votre administrateur, puis choisissez un nouveau mot de passe.';

  @override
  String get resetTokenField => 'Jeton de réinitialisation';

  @override
  String get newPasswordField => 'Nouveau mot de passe';

  @override
  String get confirmPasswordField => 'Confirmer le mot de passe';

  @override
  String get passwordsMustMatch => 'Les mots de passe ne correspondent pas';

  @override
  String get resetPasswordAction => 'Réinitialiser le mot de passe';

  @override
  String get resetPasswordSuccess =>
      'Mot de passe réinitialisé. Connectez-vous avec votre nouveau mot de passe.';

  @override
  String resetPasswordFailedMsg(String error) {
    return 'Échec de la réinitialisation : $error';
  }

  @override
  String get twoFactorTitle => 'Authentification à deux facteurs';

  @override
  String get twoFactorCodeHint =>
      'Entrez le code à 6 chiffres de votre application d\'authentification.';

  @override
  String get twoFactorRecoveryHint =>
      'Entrez l\'un de vos codes de récupération (10 caractères hex, tirets optionnels).';

  @override
  String get twoFactorCodeField => 'Code d\'authentification';

  @override
  String get recoveryCodeField => 'Code de récupération';

  @override
  String get useRecoveryInstead => 'Utiliser un code de récupération';

  @override
  String get useTotpInstead => 'Utiliser le code d\'authentification';

  @override
  String get twoFactorEnabled => 'Activée';

  @override
  String get twoFactorNotEnabled => 'Non activée';

  @override
  String twoFactorEnabledOn(String when) {
    return 'Activée le $when';
  }

  @override
  String get enable2FA => 'Activer la 2FA';

  @override
  String get disable2FA => 'Désactiver la 2FA';

  @override
  String get enable2FAStep1 =>
      'Étape 1 : scannez ce QR avec votre application d\'authentification (ou collez le secret manuellement).';

  @override
  String get enable2FAStep2 =>
      'Étape 2 : entrez le code à 6 chiffres affiché par l\'application pour confirmer.';

  @override
  String get secretLabel => 'Secret';

  @override
  String get copySecret => 'Copier le secret';

  @override
  String get recoveryCodesTitle => 'Enregistrez vos codes de récupération';

  @override
  String get recoveryCodesBody =>
      'Chaque code est utilisable une seule fois si vous perdez l\'accès à votre authentificateur. Conservez-les en lieu sûr — ils ne seront pas affichés à nouveau.';

  @override
  String get copyRecoveryCodes => 'Copier tous les codes';

  @override
  String get twoFactorEnableSuccess =>
      'L\'authentification à deux facteurs est activée.';

  @override
  String get twoFactorDisableSuccess =>
      'L\'authentification à deux facteurs a été désactivée.';

  @override
  String get twoFactorEnableFailed =>
      'Échec de la vérification. Réessayez avec un code récent de votre application.';

  @override
  String twoFactorDisableFailed(String error) {
    return 'Échec de la désactivation : $error';
  }

  @override
  String get disable2FATitle =>
      'Désactiver l\'authentification à deux facteurs ?';

  @override
  String get disable2FABody =>
      'Entrez le code actuel de votre application (ou un code de récupération) pour confirmer.';

  @override
  String get reset2FA => 'Réinitialiser la 2FA';

  @override
  String reset2FAConfirm(String username) {
    return 'Réinitialiser la 2FA pour \"$username\" ? Cela désactive leur authentification à deux facteurs et supprime leurs codes de récupération. À utiliser quand l\'utilisateur a perdu son authentificateur ET tous ses codes de récupération.';
  }

  @override
  String reset2FASuccess(String username) {
    return '2FA réinitialisée pour $username';
  }

  @override
  String reset2FAWasNotEnabled(String username) {
    return '$username n\'avait pas la 2FA activée — rien à réinitialiser.';
  }

  @override
  String get forgotPasswordTitle => 'Mot de passe oublié';

  @override
  String get forgotPasswordLink => 'Mot de passe oublié ?';

  @override
  String get forgotPasswordPrompt =>
      'Entrez votre nom d\'utilisateur ou e-mail. Si le compte existe, nous enverrons un lien de réinitialisation à usage unique.';

  @override
  String get sending => 'Envoi en cours…';

  @override
  String get sendResetLink => 'Envoyer le lien de réinitialisation';

  @override
  String get backToSignIn => 'Retour à la connexion';

  @override
  String get checkYourEmail => 'Vérifiez votre e-mail';

  @override
  String get resetLinkSentMessage =>
      'Si un compte existe pour ce nom d\'utilisateur ou e-mail, un lien de réinitialisation a été envoyé. Le lien est valide pour la prochaine heure et ne peut être utilisé qu\'une seule fois.';

  @override
  String get emailNotConfiguredOnServer =>
      'L\'e-mail n\'est pas configuré sur ce serveur. Demandez à un administrateur de réinitialiser votre mot de passe manuellement.';

  @override
  String somethingWentWrongDetail(String error) {
    return 'Une erreur s\'est produite : $error';
  }
}
