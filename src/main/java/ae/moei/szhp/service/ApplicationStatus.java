package ae.moei.szhp.service;

import java.util.Set;

/**
 * STATUS values as they really occur in MOEI_SZHP_HOUSING_APPLICATIONS.
 *
 * <p>The live data carries three spellings of "under review"
 * (UNDERREVIEW, UNDER_REVIEW, APPLICATIONUNDERREVIEW) and three of
 * "cancelled". They are recognised rather than normalised: rewriting them
 * would change rows the programme already owns.
 */
public final class ApplicationStatus {

    public static final String DRAFT = "DRAFT";
    public static final String SUBMITTED = "SUBMITTED";
    public static final String UNDER_REVIEW = "UNDERREVIEW";
    public static final String RETURNED = "RETURNED";
    public static final String APPROVED = "APPROVED";
    public static final String REJECTED = "REJECTED_BY_MOEI";

    private static final Set<String> UNDER_REVIEW_FORMS =
            Set.of("UNDERREVIEW", "UNDER_REVIEW", "APPLICATIONUNDERREVIEW");

    private static final Set<String> EDITABLE = Set.of(DRAFT, RETURNED);

    private ApplicationStatus() {
    }

    public static boolean isUnderReview(String status) {
        return status != null && UNDER_REVIEW_FORMS.contains(status.toUpperCase());
    }

    /** Only a draft or a returned request may still be changed by the applicant. */
    public static boolean isEditable(String status) {
        return status != null && EDITABLE.contains(status.toUpperCase());
    }

    public static boolean isSubmittable(String status) {
        return isEditable(status);
    }
}
