package ae.moei.szhp.dao;

import ae.moei.szhp.dto.ApplicantDetails;
import ae.moei.szhp.dto.Attachment;
import ae.moei.szhp.dto.EmployerDetail;
import ae.moei.szhp.dto.FamilyDetails;
import ae.moei.szhp.dto.HousingApplicationDetails;
import ae.moei.szhp.dto.HousingApplicationSummary;
import ae.moei.szhp.dto.RequestHistory;
import ae.moei.szhp.service.AttachmentType;
import org.springframework.jdbc.core.RowMapper;

/**
 * Maps the procedure result sets onto the UI-facing DTOs.
 *
 * <p>Everything crosses as a String because that is what the UI contract
 * declares; dates are rendered ISO-8601 so dayjs parses them unchanged.
 */
public final class RowMappers {

    private RowMappers() {
    }

    public static final RowMapper<HousingApplicationSummary> SUMMARY = (rs, rowNum) -> {
        Row row = Row.of(rs);
        return new HousingApplicationSummary(
                    row.str("APPLICATION_ID"),
                    row.str("APPLICATION_NO"),
                    row.str("REFERENCE_NO"),
                    row.str("APPLICANT"),
                    row.str("APPLICANT_NAME_EN"),
                    row.str("EMIRATES_ID"),
                    row.str("REQUEST_TYPE"),
                    row.str("AID_TYPE"),
                    row.str("ASSISTANCE_TYPE"),
                    row.str("REGION"),
                    row.str("REGION_EN"),
                    row.str("STATUS"),
                    row.str("STATUS"),
                    row.str("AWARDED_AID_AMOUNT"),
                    row.str("CREATED_DATE"),
                    row.str("UPDATED_DATE"));
    };

    public static final RowMapper<FamilyDetails> FAMILY = (rs, rowNum) -> {
        Row row = Row.of(rs);
        return new FamilyDetails(
            row.str("ID"),
            row.str("APPLICANT"),
            row.str("FULLNAME_EN"),
            row.str("FULLNAME_AR"),
            row.str("RELATIONSHIP"),
            row.str("MARITAL_STATUS"),
            row.str("DATE_OF_BIRTH"),
            row.str("AGE"),
            row.str("GENDER"),
            row.str("EMIRATES_ID"),
            row.str("SPECIAL_NEEDS"),
            row.bool("IS_ACTIVE"));
    };

    public static final RowMapper<RequestHistory> HISTORY = (rs, rowNum) -> {
        Row row = Row.of(rs);
        return new RequestHistory(
            row.str("ID"),
            row.str("REQUEST_ID"),
            row.str("TASK_ID"),
            row.str("TASK_NAME"),
            row.str("PROCESS_TYPE"),
            row.str("TASK_ACTION"),
            row.str("STATUS"),
            row.str("PROCESS_STATUS"),
            row.str("REQUEST_STATUS"),
            row.str("COMMENTS"),
            row.str("ACTED_BY"),
            row.str("ACCEPTED_BY"),
            row.bool("IS_ACTIVE"),
            row.str("CREATED_DATE"),
            row.str("COMPLETION_DATE"));
    };

    /** usp_SZHP_Attachment_List / _Get. FILE_CONTENT is read separately, by STORED_ATTACHMENT. */
    public static final RowMapper<Attachment> ATTACHMENT = (rs, rowNum) -> {
        Row row = Row.of(rs);
        String requestId = row.str("REQUEST_ID");
        String id = row.str("ID");
        String typeId = row.str("ATTACHMENT_TYPE_ID");
        return new Attachment(
            row.str("FILE_NAME"),
            "/housing-applications/" + requestId + "/attachments/" + id,
            typeId,
            id,
            row.str("SOURCE"),
            AttachmentType.labelOf(typeId),
            row.str("LAST_UPDATED_DATE"),
            row.str("FILE_SIZE"),
            requestId,
            id,
            row.str("APPLICANT_ID"),
            row.str("CATEGORY"),
            row.str("FILE_TYPE"),
            row.str("STATUS"));
    };

    public static final RowMapper<StoredAttachment> STORED_ATTACHMENT = (rs, rowNum) ->
            new StoredAttachment(ATTACHMENT.mapRow(rs, rowNum), Row.of(rs).str("FILE_CONTENT"));

    /** usp_SZHP_HousingApplication_Get returns the joined application row. */
    public static final RowMapper<HousingApplicationDetails> DETAILS = (rs, rowNum) -> {
        Row row = Row.of(rs);
        HousingApplicationDetails d = new HousingApplicationDetails();

        d.applicationId = row.str("APPLICATION_ID");
        d.applicationNumber = row.str("APPLICATION_NO");
        d.referenceNo = row.str("REFERENCE_NO");
        d.agreementId = row.str("AGREEMENT_ID");
        d.fileNo = row.str("FILE_NO");
        d.requestType = row.str("REQUEST_TYPE");
        d.source = row.str("SOURCE");

        d.status = row.str("STATUS");
        d.applicationStatus = row.str("STATUS");
        d.rejectionReason = row.str("REJECTION_REASON");
        d.returnReason = row.str("RETURN_REASON");

        d.aidType = row.str("AID_TYPE");
        d.assistanceType = row.str("ASSISTANCE_TYPE");
        d.assistancePurpose = row.str("ASSISTANCE_PURPOSE");
        d.purposeCategory = row.str("ASSISTANCE_PURPOSE_CATEGORY");

        d.maritalStatus = row.str("MARITAL_STATUS");
        d.maritalCategory = row.str("MARITAL_CATEGORY");
        d.noOfWives = row.str("NO_OF_WIVES");
        d.noOfChildrens = row.str("NO_OF_CHILDREN");
        d.marriageDate = row.str("MARRIAGE_DATE");
        d.divorceDate = row.str("DIVORCE_DATE");
        d.spouseDeathDate = row.str("SPOUSE_DEATH_DATE");
        d.fatherDeathDate = row.str("FATHER_DEATH_DATE");
        d.motherDeathDate = row.str("MOTHER_DEATH_DATE");
        d.familyBookEmirate = row.str("FAMILY_BOOK_EMIRATE");

        d.region = row.str("REGION");
        d.regionEn = row.str("REGION_EN");
        d.regionAr = row.str("REGION_AR");
        d.housingOwnership = row.str("HOUSING_OWNERSHIP");
        d.location = row.str("LOCATION");
        d.leaseRentalDate = row.str("LEASE_RENTAL_DATE");
        d.yearsOfStaying = row.str("YEARS_OF_STAYING");
        d.landForConstruction = row.str("LAND_FOR_CONSTRUCTION");
        d.latitude = row.str("LATITUDE");
        d.longitude = row.str("LONGITUDE");
        d.pod = row.str("POD");
        d.poboxNo = row.str("POBOX_NO");

        d.technicalConsition = row.str("TECHNICAL_CONSITION");
        d.dwellingYOC = row.str("DWELLING_YOC");
        d.constructionAreSqFeet = row.str("CONSTRUCTION_AREA_SQ_FEET");
        d.noOfOccupants = row.str("NO_OF_OCCUPANTS");
        d.noOfRooms = row.str("NO_OF_ROOMS");
        d.noOfCouncils = row.str("NO_OF_COUNCILS");
        d.noOfBedRooms = row.str("NO_OF_BED_ROOMS");
        d.noOfBathrooms = row.str("NO_OF_BATHROOMS");
        d.noOfKitchens = row.str("NO_OF_KITCHENS");
        d.receviedHousingAID = row.str("RECEIVED_HOUSING_AID");
        d.noPrevHousingAsst = row.str("NO_PREV_HOUSING_ASST");

        d.awardedAidAmount = row.str("AWARDED_AID_AMOUNT");
        d.awardedAidType = row.str("AWARDED_AID_TYPE");
        d.awardedAssistanceType = row.str("AWARDED_ASSISTANCE_TYPE");
        d.awardedAssistancePurpose = row.str("AWARDED_ASSISTANCE_PURPOSE");
        d.awardedPurposeCategory = row.str("AWARDED_PURPOSE_CATEGORY");
        d.awardedNoOfBedrooms = row.str("AWARDED_NO_OF_BED_ROOMS");
        d.awardedMessage = row.str("AWARDED_MESSAGE");

        d.processInstanceId = row.str("PROCESS_INSTANCE_ID");
        d.technicalResearchId = row.str("TECHNICAL_RESEARCHERID");
        d.socialResearchId = row.str("SOCIAL_RESEARCHERID");
        d.techVisitStatus = row.str("TECH_VISIT_STATUS");
        d.socialVisitStatus = row.str("SOCIAL_VISIT_STATUS");
        d.housingReqStdyTeamId = row.str("HOUSING_REQ_STDY_TEAM_ID");
        d.externalQarar = row.str("EXTERNAL_QARAR");

        d.createdDate = row.str("CREATED_DATE");
        d.updatedDate = row.str("UPDATED_DATE");
        d.updatedByApplicant = row.str("UPDATED_BY_APPLICANT");

        d.applicant = new ApplicantDetails(
                row.str("APPLICANT_USER_ID"),
                null,
                row.str("APPLICANT_EMIRATES_ID"),
                row.str("FULLNAME_EN"),
                row.str("FULLNAME_AR"),
                row.str("EMAIL_ID"),
                row.str("MOBILE_NO"),
                row.str("MOBILE_NO"),
                row.str("MOBILE_NO2"),
                row.str("ADDRESS"),
                row.str("POBOX_NO"),
                row.str("GENDER"),
                row.str("QUALIFICATION"),
                row.str("MARITAL_STATUS"),
                row.str("DATE_OF_BIRTH"),
                row.str("FAMILY_NO"),
                row.str("TOWN_NO"),
                null,
                null,
                null,
                row.str("NO_OF_DEPENDENT"),
                null,
                null,
                row.str("REGION_AR"),
                row.str("REGION_EN"));

        d.employerDetails = new EmployerDetail(
                row.str("EMP_ID"),
                row.str("APPLICANT"),
                row.str("EMPLOYER_NAME"),
                row.str("DESIGNATION"),
                row.str("SECTOR"),
                row.str("WORK_CATEGORY"),
                row.str("ANNUAL_INCOME"),
                null,
                row.str("START_DATE"),
                row.str("END_DATE"),
                null);

        return d;
    };

}
