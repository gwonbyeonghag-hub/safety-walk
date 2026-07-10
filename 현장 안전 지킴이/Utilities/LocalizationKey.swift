import Foundation
import SafetyWalkCore

// Type-safe access to Localizable.strings entries.
// All SwiftUI Views must use .localized on a LocalizationKey — no raw string literals.
// Add new keys here AND in both en.lproj and ko.lproj at the same time.

enum LocalizationKey: String {

    // MARK: - Tabs
    case tabHome            = "tab.home"
    case tabInspection      = "tab.inspection"
    case tabHazards         = "tab.hazards"
    case tabHistory         = "tab.history"
    case tabSettings        = "tab.settings"

    // MARK: - Home
    case homeSubtitle            = "home.subtitle"
    case homeStartInspection    = "home.startInspection"
    case homeRecentInspections  = "home.recentInspections"
    case homeAddHazard          = "home.addHazard"
    case homeNoInspectionsYet   = "home.noInspectionsYet"
    case homeInspectionsToday   = "home.inspectionsToday"
    case homeOpenHazards        = "home.openHazards"
    case homeAllClear           = "home.allClear"
    case homeNoOpenHazards      = "home.noOpenHazards"
    // iPad (regular) home extras — WO-7
    case homeQuickActions       = "home.quickActions"
    case homeAssessmentsDue     = "home.assessmentsDue"
    case homeOverdue            = "home.overdue"
    case homeDueSoon            = "home.dueSoon"
    case homeNoDueAssessments   = "home.noDueAssessments"
    case ipadSidebarSection     = "ipad.sidebar.section"
    case ipadSidebarRole        = "ipad.sidebar.role"

    // MARK: - Inspection setup
    case inspectionNoSitesYet       = "inspection.noSitesYet"
    case inspectionTemplateSummary  = "inspection.templateSummary"
    case inspectionNoArea           = "inspection.noArea"
    case inspectionAddNewArea       = "inspection.addNewArea"
    case inspectionSelectSite       = "inspection.selectSite"
    case inspectionAddNewSite       = "inspection.addNewSite"
    case inspectionSelectArea       = "inspection.selectArea"
    case inspectionEnterAreaFree    = "inspection.enterAreaFree"
    case inspectionSelectTemplate   = "inspection.selectTemplate"
    case inspectionBegin                  = "inspection.begin"
    case inspectionComplete               = "inspection.complete"
    case inspectionNoActiveInspections    = "inspection.noActiveInspections"

    // MARK: - Inspection deletion (task 5-9)
    case inspectionDelete                 = "inspection.delete"
    case inspectionDeleteTitle            = "inspection.deleteTitle"
    case inspectionDeleteMessage          = "inspection.deleteMessage"

    // MARK: - Inspection scope / category selection
    case inspectionScopeTitle             = "inspection.scopeTitle"
    case inspectionScopeSubtitle          = "inspection.scopeSubtitle"
    case inspectionSelectAll              = "inspection.selectAll"
    case inspectionClearAll               = "inspection.clearAll"
    case inspectionRecommendedDefaults    = "inspection.recommendedDefaults"
    case inspectionSelectedScopeSummary   = "inspection.selectedScopeSummary"
    case inspectionNoScopeSelected        = "inspection.noScopeSelected"
    case inspectionStartWithScope         = "inspection.startWithScope"

    // MARK: - Checklist item
    case checklistPass              = "checklist.pass"
    case checklistFail              = "checklist.fail"
    case checklistNotApplicable     = "checklist.notApplicable"
    case checklistAddNote           = "checklist.addNote"
    case checklistAttachPhoto       = "checklist.attachPhoto"
    case checklistReplacePhoto      = "checklist.replacePhoto"
    case checklistAddHazard         = "checklist.addHazard"
    case checklistHazardLinked      = "checklist.hazardLinked"
    case checklistProgress          = "checklist.progress"      // "%d / %d items"
    case checklistFailedCount       = "checklist.failedCount"  // "%d failed"

    // MARK: - Hazard
    case hazardRegistrationTitle    = "hazard.registrationTitle"
    case hazardPhoto                = "hazard.photo"
    case hazardLocation             = "hazard.location"
    case hazardType                 = "hazard.type"
    case hazardRiskLevel            = "hazard.riskLevel"
    case hazardDescription          = "hazard.description"
    case hazardDescriptionPlaceholder = "hazard.descriptionPlaceholder"
    case hazardCorrectiveStatus     = "hazard.correctiveStatus"
    case hazardSave                 = "hazard.save"
    case hazardPhotoRequired        = "hazard.photoRequired"
    case hazardNoHazardsYet         = "hazard.noHazardsYet"
    case hazardFilterAll            = "hazard.filterAll"
    case hazardClearFilters         = "hazard.clearFilters"
    case hazardDetailTitle          = "hazard.detailTitle"
    case hazardCreatedAt            = "hazard.createdAt"
    case hazardUpdatedAt            = "hazard.updatedAt"
    case hazardNoFilterResults      = "hazard.noFilterResults"
    case hazardNoSitesForStandalone = "hazard.noSitesForStandalone"

    // MARK: - Risk levels
    case riskLow        = "risk.low"
    case riskMedium     = "risk.medium"
    case riskHigh       = "risk.high"

    // MARK: - Hazard types
    case hazardTypeFallRisk     = "hazardType.fallRisk"
    case hazardTypeElectrical   = "hazardType.electrical"
    case hazardTypeFire         = "hazardType.fire"
    case hazardTypeChemical     = "hazardType.chemical"
    case hazardTypeGeneral      = "hazardType.general"
    case hazardTypeOther        = "hazardType.other"

    // MARK: - Corrective action status
    case statusNotStarted   = "status.notStarted"
    case statusInProgress   = "status.inProgress"
    case statusCompleted    = "status.completed"

    // MARK: - Inspection status
    case inspectionStatusInProgress = "inspectionStatus.inProgress"
    case inspectionStatusCompleted  = "inspectionStatus.completed"

    // MARK: - Inspection detail
    case detailContinueInspection   = "detail.continueInspection"
    case detailChecklistItems       = "detail.checklistItems"
    case detailLinkedHazards        = "detail.linkedHazards"

    // MARK: - History
    case historyNoRecords       = "history.noRecords"
    case historyTitle           = "history.title"
    case historyNoFilterResults = "history.noFilterResults"

    // MARK: - Inspection summary
    case summaryTitle           = "summary.title"
    case summaryInspector       = "summary.inspector"
    case summaryStartedAt       = "summary.startedAt"
    case summaryCompletedAt     = "summary.completedAt"
    case summaryTotalItems      = "summary.totalItems"
    case summaryFailedItems     = "summary.failedItems"
    case summaryHazardsByRisk   = "summary.hazardsByRisk"
    case summaryPass            = "summary.pass"
    case summaryFail            = "summary.fail"
    case summaryNotApplicable   = "summary.notApplicable"
    case summaryHazards         = "summary.hazards"
    case summaryShare           = "summary.share"

    // MARK: - Inspection report (Phase 4 export)
    case reportTitle            = "report.title"
    case reportGeneratedAt      = "report.generatedAt"
    case reportGeneratedBy      = "report.generatedBy"
    case reportPassRate         = "report.passRate"
    case reportOpenHazards      = "report.openHazards"
    case reportProgress         = "report.progress"
    case reportMetadata         = "report.metadata"
    case reportChecklist        = "report.checklist"
    case reportArea             = "report.area"
    case reportStatus           = "report.status"
    case reportResultSummary    = "report.resultSummary"
    case reportHazardSummary    = "report.hazardSummary"
    case reportProgressRate     = "report.progressRate"
    case reportUnchecked        = "report.unchecked"
    case reportCategoryResults  = "report.categoryResults"
    case reportChecklistItem    = "report.checklistItem"
    case reportResult           = "report.result"
    case reportNote             = "report.note"
    case reportHazardsAndActions = "report.hazardsAndActions"
    case reportEvidencePhotos   = "report.evidencePhotos"
    case reportNoEvidencePhotos = "report.noEvidencePhotos"
    case shareButton            = "share.button"
    case shareExporting         = "share.exporting"
    case shareFailed            = "share.failed"

    // MARK: - Errors (task 5-3)
    case errorPhotoLoadFailed   = "error.photoLoadFailed"
    case errorPhotoSaveFailed   = "error.photoSaveFailed"

    // MARK: - Data reset (task 5-11)
    case settingsDataManagement = "settings.dataManagement"
    case settingsResetLocalData = "settings.resetLocalData"
    case resetConfirmTitle      = "reset.confirmTitle"
    case resetConfirmMessage    = "reset.confirmMessage"
    case resetConfirmAction     = "reset.confirmAction"
    case errorResetFailed       = "error.resetFailed"

    // MARK: - Accessibility (task 5-4)
    case siteAreaCountAccessibility = "site.areaCountAccessibility"

    // MARK: - Onboarding (task 5-1)
    case onboardingTitle           = "onboarding.title"
    case onboardingSubtitle        = "onboarding.subtitle"
    case onboardingInspectorName   = "onboarding.inspectorName"
    case onboardingRegion          = "onboarding.region"
    case onboardingStart           = "onboarding.start"
    case onboardingNameRequired    = "onboarding.nameRequired"

    // MARK: - Reopen setup (task 5-14)
    case settingsAppSetup            = "settings.appSetup"
    case settingsReopenSetup         = "settings.reopenSetup"
    case setupReopenConfirmTitle     = "setupReopen.confirmTitle"
    case setupReopenConfirmMessage   = "setupReopen.confirmMessage"
    case setupReopenConfirmAction    = "setupReopen.confirmAction"

    // MARK: - Settings
    case settingsTitle              = "settings.title"
    case settingsInspectorName      = "settings.inspectorName"
    case settingsLanguage           = "settings.language"
    case languageKorean             = "language.korean"
    case languageEnglish            = "language.english"
    case settingsRegionProfile      = "settings.regionProfile"
    case settingsRegionKorea        = "settings.region.korea"
    case settingsRegionGlobal       = "settings.region.global"
    case settingsSiteManagement     = "settings.siteManagement"
    case settingsAppVersion         = "settings.appVersion"

    // MARK: - Appearance (task 5-8)
    case settingsAppearance         = "settings.appearance"
    case appearanceSystem           = "appearance.system"
    case appearanceLight            = "appearance.light"
    case appearanceDark             = "appearance.dark"

    // MARK: - Site management
    case siteManagementTitle    = "siteManagement.title"
    case siteNamePlaceholder    = "siteManagement.namePlaceholder"
    case siteAddressPlaceholder = "siteManagement.addressPlaceholder"
    case areaNamePlaceholder    = "siteManagement.areaNamePlaceholder"

    // MARK: - Site management actions (task 3-2)
    case siteAddSite                 = "site.addSite"
    case siteNoSites                 = "site.noSites"
    case siteAreasSection            = "site.areasSection"
    case siteDeleteSiteAction        = "site.deleteSiteAction"
    case siteDeleteConfirmTitle      = "site.deleteConfirmTitle"
    case siteDeleteBlockedTitle      = "site.deleteBlockedTitle"
    case siteDeleteBlockedMessage    = "site.deleteBlockedMessage"
    case areaAddArea                 = "area.addArea"
    case areaNoAreas                 = "area.noAreas"
    case areaDeleteConfirmTitle      = "area.deleteConfirmTitle"
    case areaDeleteBlockedTitle      = "area.deleteBlockedTitle"
    case areaDeleteBlockedMessage    = "area.deleteBlockedMessage"

    // MARK: - Disclaimer (non-removable legal notice)
    case disclaimerTitle = "disclaimer.title"
    case disclaimerText  = "disclaimer.text"

    // MARK: - Common
    case commonSave     = "common.save"
    case commonNext     = "common.next"
    case commonCancel   = "common.cancel"
    case commonDelete   = "common.delete"
    case commonEdit     = "common.edit"
    case commonShare    = "common.share"
    case commonBack     = "common.back"
    case commonConfirm  = "common.confirm"
    case commonRequired = "common.required"
    case commonDone     = "common.done"
    case commonComingSoon = "common.comingSoon"

    // MARK: - Risk Assessment (위험성평가) — WO-2
    case raTitle                = "ra.title"
    case raHomeCardSubtitle     = "ra.home.cardSubtitle"
    case raEmpty                = "ra.empty"
    case raNew                  = "ra.new"
    case raKind                 = "ra.kind"
    case raKindInitial          = "ra.kind.initial"
    case raKindRegular          = "ra.kind.regular"
    case raKindOccasional       = "ra.kind.occasional"
    case raMethod               = "ra.method"
    case raMethodThreeLevel     = "ra.method.threeLevel"
    case raMethodFreqSeverity   = "ra.method.freqSeverity"
    case raSite                 = "ra.site"
    case raSiteNone             = "ra.site.none"
    case raAssessor             = "ra.assessor"
    case raAssessorPlaceholder  = "ra.assessor.placeholder"
    case raNote                 = "ra.note"
    case raItemsSection         = "ra.items"
    case raItemAdd              = "ra.item.add"
    case raItemEdit             = "ra.item.edit"
    case raItemTask             = "ra.item.task"
    case raItemHazard           = "ra.item.hazard"
    case raItemCurrentControls  = "ra.item.currentControls"
    case raItemLikelihood       = "ra.item.likelihood"
    case raItemSeverity         = "ra.item.severity"
    case raItemScore            = "ra.item.score"
    case raItemRiskLevel        = "ra.item.riskLevel"
    case raItemReduction        = "ra.item.reductionMeasure"
    case raItemPostRiskLevel    = "ra.item.postRiskLevel"
    case raItemResponsible      = "ra.item.responsible"
    case raItemDueDate          = "ra.item.dueDate"
    case raItemSetDueDate       = "ra.item.setDueDate"
    case raItemStatus           = "ra.item.status"
    case raItemsEmpty           = "ra.items.empty"
    case raItemCountFormat      = "ra.itemCount"

    // MARK: - Risk Assessment methods 2/2 (체크리스트법 + JSA) — WO-2b
    case raMethodChecklist      = "ra.method.checklist"
    case raMethodJSA            = "ra.method.jsa"
    case raSeedFromInspection   = "ra.seedFromInspection"
    case raPickInspection       = "ra.pickInspection"
    case raNoCompletedInspections = "ra.noCompletedInspections"
    case raSeededFromInspection = "ra.seededFromInspection"
    case raJsaStep              = "ra.jsa.step"
    case raJsaAddStep           = "ra.jsa.addStep"

    // MARK: - Reports (WO-5b)
    case reportRaTitle          = "report.ra.title"
    case reportNo               = "report.no"
    case reportRaOwner          = "report.ra.owner"
    case reportInspectionTitle  = "report.inspection.title"
    case reportJhaTitle         = "report.jha.title"
    case reportJhaStep          = "report.jha.step"
    case reportJhaJobStep       = "report.jha.jobStep"
    case reportJhaHazards       = "report.jha.hazards"
    case reportJhaControls      = "report.jha.controls"
    case reportJhaRisk          = "report.jha.risk"

    // MARK: - macOS manager shell (WO-4)
    case macLanguage                    = "mac.language"
    case macSidebarOverview             = "mac.sidebar.overview"
    case macSidebarRole                 = "mac.sidebar.role"
    case macAppName                     = "mac.app.name"
    case macSectionDashboard            = "mac.section.dashboard"
    case macSectionSites                = "mac.section.sites"
    case macSectionInspections          = "mac.section.inspections"
    case macSectionHazards              = "mac.section.hazards"
    case macSectionRiskAssessments      = "mac.section.riskAssessments"
    case macSectionReports              = "mac.section.reports"
    case macDashboardTitle              = "mac.dashboard.title"
    case macDashboardSubtitle           = "mac.dashboard.subtitle"
    case macViewAllSites                = "mac.dashboard.viewAllSites"
    case macStatSites                   = "mac.stat.sites"
    case macStatCompletedInspections    = "mac.stat.completedInspections"
    case macStatOpenHazards             = "mac.stat.openHazards"
    case macStatAssessmentsDue          = "mac.stat.assessmentsDue"
    case macRiskDistribution            = "mac.riskDistribution"
    case macOpenCorrectiveActions       = "mac.openCorrectiveActions"
    case macAssessmentsDue              = "mac.assessmentsDue"
    case macRecentInspections           = "mac.recentInspections"
    case macNoData                      = "mac.noData"
    case macNoOpenItems                 = "mac.noOpenItems"
    case macOverdue                     = "mac.overdue"
    case macDueSoon                     = "mac.dueSoon"
    case macSelectItem                  = "mac.selectItem"
    case macAreas                       = "mac.areas"
    case macRelatedInspections          = "mac.relatedInspections"
    case macChooseReport                = "mac.chooseReport"
    case macAssessmentReports           = "mac.assessmentReports"
    case macInspectionReports           = "mac.inspectionReports"
    case macExportPDF                   = "mac.exportPDF"
    case macPrint                       = "mac.print"

    // MARK: - SafetyWalk Pro / paywall (WO-10)
    case paywallTitle                   = "paywall.title"
    case paywallTagline                 = "paywall.tagline"
    case paywallBenefitAssessment       = "paywall.benefit.assessment"
    case paywallBenefitExport           = "paywall.benefit.export"
    case paywallReassurance             = "paywall.reassurance"
    case paywallMonthly                 = "paywall.monthly"
    case paywallYearly                  = "paywall.yearly"
    case paywallRestore                 = "paywall.restore"
    case paywallTerms                   = "paywall.terms"
    case paywallPrivacy                 = "paywall.privacy"
    case paywallUnavailable             = "paywall.unavailable"
    case paywallLoading                 = "paywall.loading"
    case paywallClose                   = "paywall.close"
    case settingsProSection             = "settings.pro.section"
    case settingsProStatusActive        = "settings.pro.statusActive"
    case settingsProStatusInactive      = "settings.pro.statusInactive"
    case settingsProSubscribe           = "settings.pro.subscribe"
    case settingsProManage              = "settings.pro.manage"

    var localized: String {
        // Resolve through the app's selected language bundle (LocalizationManager) so a
        // live language toggle re-renders every string without an app restart.
        LocalizationManager.shared.string(rawValue)
    }
}

extension String {
    static func localized(_ key: LocalizationKey) -> String {
        key.localized
    }
}
