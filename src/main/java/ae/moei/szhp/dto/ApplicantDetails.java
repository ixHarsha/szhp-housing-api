package ae.moei.szhp.dto;

import java.util.List;

/** Mirrors IApplicantDetails. 'maritialStatus' keeps the existing spelling. */
public record ApplicantDetails(
        String userId,
        String uuid,
        String emiratesId,
        String fullNameEn,
        String fullNameAr,
        String email,
        String phoneNumber,
        String mobileNo,
        String mobileNo2,
        String address,
        String poboxNo,
        String gender,
        String qualification,
        String maritialStatus,
        String dateOfBirth,
        String familyNo,
        String townNo,
        EmirateDetails emirate,
        Boolean isActive,
        String createdDate,
        String noOfDependent,
        List<FamilyDetails> family,
        List<EmployerDetail> employerDetails,
        String regionAr,
        String regionEn) {
}
