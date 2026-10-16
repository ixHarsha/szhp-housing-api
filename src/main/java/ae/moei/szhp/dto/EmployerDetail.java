package ae.moei.szhp.dto;

/** Mirrors IEmployerDetail. 'desigination' keeps the existing spelling. */
public record EmployerDetail(
        String id,
        String applicant,
        String employerName,
        String desigination,
        String sector,
        String workCategory,
        String annualIncome,
        String createdDate,
        String startDate,
        String endDate,
        String isActive) {
}
