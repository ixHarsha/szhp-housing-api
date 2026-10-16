package ae.moei.szhp.dto;

/** Mirrors IFamilyDetails. */
public record FamilyDetails(
        String id,
        String applicant,
        String fullNameEn,
        String fullNameAr,
        String relationship,
        String maritalStatus,
        String dateOfBirth,
        String age,
        String gender,
        String emiratesId,
        String specialNeeds,
        Boolean isActive) {
}
