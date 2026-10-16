package ae.moei.szhp;

import static org.assertj.core.api.Assertions.assertThat;

import ae.moei.szhp.service.ApplicationStatus;
import org.junit.jupiter.api.Test;

class ApplicationStatusTest {

    @Test
    void recognisesEverySpellingOfUnderReviewInTheLiveData() {
        assertThat(ApplicationStatus.isUnderReview("UNDERREVIEW")).isTrue();
        assertThat(ApplicationStatus.isUnderReview("UNDER_REVIEW")).isTrue();
        assertThat(ApplicationStatus.isUnderReview("APPLICATIONUNDERREVIEW")).isTrue();
    }

    @Test
    void underReviewIsCaseInsensitiveAndNullSafe() {
        assertThat(ApplicationStatus.isUnderReview("underreview")).isTrue();
        assertThat(ApplicationStatus.isUnderReview(null)).isFalse();
        assertThat(ApplicationStatus.isUnderReview("APPROVED")).isFalse();
    }

    @Test
    void onlyDraftAndReturnedAreEditable() {
        assertThat(ApplicationStatus.isEditable("DRAFT")).isTrue();
        assertThat(ApplicationStatus.isEditable("RETURNED")).isTrue();

        assertThat(ApplicationStatus.isEditable("SUBMITTED")).isFalse();
        assertThat(ApplicationStatus.isEditable("UNDERREVIEW")).isFalse();
        assertThat(ApplicationStatus.isEditable("APPROVED")).isFalse();
        assertThat(ApplicationStatus.isEditable("REJECTED_BY_MOEI")).isFalse();
        assertThat(ApplicationStatus.isEditable(null)).isFalse();
    }

    @Test
    void anApprovedRequestCannotBeSubmittedAgain() {
        assertThat(ApplicationStatus.isSubmittable("APPROVED")).isFalse();
        assertThat(ApplicationStatus.isSubmittable("DRAFT")).isTrue();
        assertThat(ApplicationStatus.isSubmittable("RETURNED")).isTrue();
    }
}
