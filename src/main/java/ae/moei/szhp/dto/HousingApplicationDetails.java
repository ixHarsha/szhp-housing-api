package ae.moei.szhp.dto;

import java.util.List;

/**
 * The housing assistance request payload, used for both request and response.
 *
 * <p>Field names mirror IHousingApplicationDetails in SZHP-micro-ui one for
 * one, existing spellings included: {@code technicalConsition},
 * {@code receviedHousingAID}, {@code constructionAreSqFeet},
 * {@code noOfChildrens}. Renaming any of them changes the service contract, so
 * don't.
 *
 * <p>Values are carried as Strings because that is what the UI DTO declares and
 * what the form sends; conversion to the column types happens in the DAO.
 *
 * <p>Public fields rather than ~160 accessors: with this many optional
 * properties the boilerplate obscures the contract, and Jackson maps public
 * fields directly.
 */
public class HousingApplicationDetails {

    /* ------------------------------------------------------ identity */
    public String applicationId;
    public String applicationNumber;
    public String referenceNo;
    public String agreementId;
    public String fileNo;
    public String requestType;
    public String housingRequestType;
    public String source;

    /* -------------------------------------------------------- status */
    public String status;
    public String applicationStatus;
    public String rejectionReason;
    public String returnReason;

    /* ---------------------------------------------------- assistance */
    public String aidType;
    public String assistanceType;
    public String assistancePurpose;
    public String purposeCategory;

    /* -------------------------------------------------- social status */
    public String maritalStatus;
    public String maritalCategory;
    public String noOfWives;
    public String noOfChildrens;
    public String marriageDate;
    public String divorceDate;
    public String spouseDeathDate;
    public String fatherDeathDate;
    public String motherDeathDate;
    public String familyBookEmirate;

    /* -------------------------------------------------- housing data */
    public String region;
    public String regionEn;
    public String regionAr;
    public String housingOwnership;
    public String location;
    public String leaseRentalDate;
    public String yearsOfStaying;
    public String landForConstruction;
    public String latitude;
    public String longitude;
    public String pod;
    public String poboxNo;

    /* ------------------------------------------- residential details */
    public String technicalConsition;
    public String dwellingYOC;
    public String constructionAreSqFeet;
    public String noOfOccupants;
    public String noOfRooms;
    public String noOfCouncils;
    public String noOfBedRooms;
    public String noOfBathrooms;
    public String noOfKitchens;
    public String receviedHousingAID;
    public Object noPrevHousingAsst;

    /* -------------------------------------------------------- award */
    public String awardedAidAmount;
    public String awardedAidType;
    public String awardedAssistanceType;
    public String awardedAssistancePurpose;
    public String awardedPurposeCategory;
    public String awardedNoOfBedrooms;
    public String awardedMessage;

    /* ----------------------------------------------------- workflow */
    public String processInstanceId;
    public String taskId;
    public String taskName;
    public String technicalResearchId;
    public String socialResearchId;
    public String techVisitStatus;
    public String socialVisitStatus;
    public String housingReqStdyTeamId;
    public String externalQarar;

    /* -------------------------------------------------------- audit */
    public String createdDate;
    public String updatedDate;
    public String updatedByApplicant;

    /* ------------------------------------------------------- nested */
    public ApplicantDetails applicant;
    public EmployerDetail employerDetails;
    public ProcessComment processComment;
    public List<FamilyDetails> family;

    /** From usp_SZHP_Applicant_Eligibility: 'Eligible' or 'Not Eligible'. */
    public String eligibility;
    public Boolean isEligibleHF;
}
