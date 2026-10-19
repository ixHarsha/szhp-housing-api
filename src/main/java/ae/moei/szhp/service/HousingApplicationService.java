package ae.moei.szhp.service;

import ae.moei.szhp.dao.HousingApplicationDao;
import ae.moei.szhp.dto.FamilyDetails;
import ae.moei.szhp.dto.HousingApplicationDetails;
import ae.moei.szhp.dto.HousingApplicationSummary;
import ae.moei.szhp.dto.PagedResponse;
import ae.moei.szhp.dto.RequestHistory;
import java.math.BigDecimal;
import java.sql.Date;
import java.time.LocalDate;
import java.util.List;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.stereotype.Service;
import org.springframework.transaction.annotation.Transactional;

@Service
public class HousingApplicationService {

    private final HousingApplicationDao dao;
    private final IdGenerator idGenerator;
    private final AttachmentService attachments;

    public HousingApplicationService(HousingApplicationDao dao, IdGenerator idGenerator, AttachmentService attachments) {
        this.dao = dao;
        this.idGenerator = idGenerator;
        this.attachments = attachments;
    }

    /* -------------------------------------------------------------- reads */

    public PagedResponse<HousingApplicationSummary> list(String applicant,
                                                         String status,
                                                         String search,
                                                         Integer pageNo,
                                                         Integer pageSize) {
        int page = pageNo == null || pageNo < 1 ? 1 : pageNo;
        int size = pageSize == null ? 10 : Math.clamp(pageSize, 1, 100);
        String normalisedStatus = isBlank(status) || "ALL".equalsIgnoreCase(status) ? null : status.trim();
        String normalisedSearch = isBlank(search) ? null : search.trim();
        return dao.list(isBlank(applicant) ? null : applicant, normalisedStatus, normalisedSearch, page, size);
    }

    public HousingApplicationDetails get(String applicationId) {
        HousingApplicationDetails details = require(applicationId);
        enrich(details);
        return details;
    }

    public List<RequestHistory> history(String applicationId) {
        require(applicationId);
        return dao.listHistory(applicationId);
    }

    /**
     * Attaches the uploaded documents, the applicant's family and the
     * eligibility verdict.
     *
     * <p>Eligibility comes from the programme's own rule, run in the database
     * rather than reimplemented here, so there is one definition of it.
     */
    private void enrich(HousingApplicationDetails details) {
        details.attachments = attachments.listLoaded(details.applicationId);

        String applicant = details.applicant == null ? null : details.applicant.userId();
        if (isBlank(applicant)) {
            return;
        }

        List<FamilyDetails> family = dao.listFamily(applicant);
        details.family = family;

        BigDecimal salary = monthlySalary(details);
        if (salary != null) {
            dao.eligibility(applicant, salary).ifPresent(verdict -> details.eligibility = verdict);
        }
    }

    /**
     * The eligibility rule compares against a monthly figure, while the column
     * is ANNUAL_INCOME, so the annual value is divided down before use.
     */
    private static BigDecimal monthlySalary(HousingApplicationDetails details) {
        if (details.employerDetails == null || isBlank(details.employerDetails.annualIncome())) {
            return null;
        }
        try {
            return new BigDecimal(details.employerDetails.annualIncome())
                    .divide(BigDecimal.valueOf(12), 2, java.math.RoundingMode.HALF_UP);
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    /* ------------------------------------------------------------- writes */

    @Transactional
    public HousingApplicationDetails create(HousingApplicationDetails form, String applicant, boolean submit) {
        if (isBlank(applicant)) {
            throw new RuleViolationException("An applicant is required to create a request.");
        }
        if (submit) {
            assertSubmittable(form);
        }

        String applicationId = idGenerator.applicationId();
        String status = submit ? ApplicationStatus.SUBMITTED : ApplicationStatus.DRAFT;

        dao.insert(applicationId, applicant, status,
                isBlank(form.source) ? "Website" : form.source, applicant, formValues(form));
        if (submit) {
            // A brand-new request has no documents yet, so this rejects and the
            // transaction rolls the insert back. Save a draft, upload, then submit.
            attachments.assertRequiredDocuments(applicationId);
        }

        dao.changeStatus(applicationId, status,
                submit ? "Application Submitted" : "Draft Created",
                submit ? "SUBMIT" : "QUEUED",
                submit ? "Application submitted" : "Draft created",
                applicant, idGenerator.historyId());

        return get(applicationId);
    }

    @Transactional
    public HousingApplicationDetails update(String applicationId,
                                            HousingApplicationDetails form,
                                            String applicant,
                                            boolean submit) {
        HousingApplicationDetails existing = require(applicationId);
        if (!ApplicationStatus.isEditable(existing.status)) {
            throw new RuleViolationException(
                    "A request with status '%s' can no longer be edited.".formatted(existing.status));
        }
        if (submit) {
            assertSubmittable(form);
        }

        dao.update(applicationId, applicant, formValues(form));

        if (submit) {
            attachments.assertRequiredDocuments(applicationId);
            boolean resubmission = ApplicationStatus.RETURNED.equalsIgnoreCase(existing.status);
            dao.changeStatus(applicationId, ApplicationStatus.SUBMITTED,
                    resubmission ? "Applicant Resubmission" : "Application Submitted",
                    "SUBMIT",
                    resubmission ? "Resubmitted with the requested information" : "Application submitted",
                    applicant, idGenerator.historyId());
        }

        return get(applicationId);
    }

    @Transactional
    public HousingApplicationDetails submit(String applicationId, String applicant) {
        HousingApplicationDetails existing = require(applicationId);
        if (!ApplicationStatus.isSubmittable(existing.status)) {
            throw new RuleViolationException(
                    "A request with status '%s' cannot be submitted.".formatted(existing.status));
        }
        assertSubmittable(existing);
        attachments.assertRequiredDocuments(applicationId);

        boolean resubmission = ApplicationStatus.RETURNED.equalsIgnoreCase(existing.status);
        dao.changeStatus(applicationId, ApplicationStatus.SUBMITTED,
                resubmission ? "Applicant Resubmission" : "Application Submitted",
                "SUBMIT",
                resubmission ? "Resubmitted with the requested information" : "Application submitted",
                isBlank(applicant) ? existing.applicant.userId() : applicant,
                idGenerator.historyId());

        return get(applicationId);
    }

    /* ------------------------------------------------------------ helpers */

    private HousingApplicationDetails require(String applicationId) {
        return dao.find(applicationId)
                .orElseThrow(() -> new NotFoundException(
                        "Housing application %s was not found.".formatted(applicationId)));
    }

    /** Rules that apply on submit but not on a draft save. */
    private static void assertSubmittable(HousingApplicationDetails form) {
        List<String> missing = new java.util.ArrayList<>();
        if (isBlank(form.maritalStatus)) {
            missing.add("marital status");
        }
        if (isBlank(form.region)) {
            missing.add("region");
        }
        if (isBlank(form.familyBookEmirate)) {
            missing.add("emirate based on family book");
        }
        if (isBlank(form.housingOwnership)) {
            missing.add("housing ownership");
        }
        if (isBlank(form.assistanceType)) {
            missing.add("type of assistance");
        }
        if (isBlank(form.assistancePurpose)) {
            missing.add("purpose of assistance");
        }
        if (!missing.isEmpty()) {
            throw new RuleViolationException(
                    "Complete the following before submitting: " + String.join(", ", missing) + ".");
        }
    }

    /** Maps the payload onto the procedure parameters, converting as it goes. */
    private static MapSqlParameterSource formValues(HousingApplicationDetails f) {
        return new MapSqlParameterSource()
                .addValue("AidType", f.aidType)
                .addValue("AssistanceType", f.assistanceType)
                .addValue("AssistancePurpose", f.assistancePurpose)
                .addValue("AssistancePurposeCategory", f.purposeCategory)
                .addValue("MaritalStatus", f.maritalStatus)
                .addValue("MaritalCategory", f.maritalCategory)
                .addValue("NoOfWives", toInt(f.noOfWives))
                .addValue("NoOfChildren", toInt(f.noOfChildrens))
                .addValue("MarriageDate", toDate(f.marriageDate))
                .addValue("DivorceDate", toDate(f.divorceDate))
                .addValue("SpouseDeathDate", toDate(f.spouseDeathDate))
                .addValue("FamilyBookEmirate", f.familyBookEmirate)
                .addValue("Region", f.region)
                .addValue("HousingOwnership", f.housingOwnership)
                .addValue("Location", f.location)
                .addValue("LeaseRentalDate", toDate(f.leaseRentalDate))
                .addValue("YearsOfStaying", toInt(f.yearsOfStaying))
                .addValue("LandForConstruction", f.landForConstruction)
                .addValue("TechnicalConsition", f.technicalConsition)
                .addValue("DwellingYOC", f.dwellingYOC)
                .addValue("ConstructionAreaSqFeet", toDecimal(f.constructionAreSqFeet))
                .addValue("NoOfOccupants", toInt(f.noOfOccupants))
                .addValue("NoOfRooms", toInt(f.noOfRooms))
                .addValue("NoOfCouncils", toInt(f.noOfCouncils))
                .addValue("NoOfBathrooms", toInt(f.noOfBathrooms))
                .addValue("NoOfKitchens", toInt(f.noOfKitchens))
                .addValue("NoOfBedRooms", toInt(f.noOfBedRooms))
                .addValue("ReceivedHousingAid", f.receviedHousingAID)
                .addValue("NoPrevHousingAsst",
                        f.noPrevHousingAsst == null ? null : String.valueOf(f.noPrevHousingAsst));
    }

    private static Integer toInt(String value) {
        if (isBlank(value)) {
            return null;
        }
        try {
            return Integer.valueOf(value.trim());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    private static BigDecimal toDecimal(String value) {
        if (isBlank(value)) {
            return null;
        }
        try {
            return new BigDecimal(value.trim());
        } catch (NumberFormatException ex) {
            return null;
        }
    }

    /** The UI sends dates as YYYY-MM-DD. */
    private static Date toDate(String value) {
        if (isBlank(value)) {
            return null;
        }
        try {
            return Date.valueOf(LocalDate.parse(value.trim().substring(0, 10)));
        } catch (RuntimeException ex) {
            return null;
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }
}
