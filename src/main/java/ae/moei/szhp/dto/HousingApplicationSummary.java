package ae.moei.szhp.dto;

/** One row of the applications list. */
public record HousingApplicationSummary(
        String applicationId,
        String applicationNumber,
        String referenceNo,
        String applicant,
        String applicantNameEn,
        String emiratesId,
        String requestType,
        String aidType,
        String assistanceType,
        String region,
        String regionEn,
        String status,
        String processStatus,
        String awardedAidAmount,
        String createdDate,
        String updatedDate) {
}
