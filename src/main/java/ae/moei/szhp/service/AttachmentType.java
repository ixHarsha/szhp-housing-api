package ae.moei.szhp.service;

import java.util.Arrays;
import java.util.List;

/**
 * The documents an applicant can attach to a request. Kept in step with
 * ATTACHMENT_TYPES in the UI's constants/housing.ts.
 */
public enum AttachmentType {

    EMIRATES_ID("Emirates ID", true),
    FAMILY_BOOK("Family Book", true),
    SALARY_CERTIFICATE("Salary Certificate", false),
    LEASE_CONTRACT("Lease / Rental Contract", false),
    LAND_OWNERSHIP("Land Ownership / Allocation", false),
    OTHER("Other Supporting Documents", false);

    private final String label;
    private final boolean requiredToSubmit;

    AttachmentType(String label, boolean requiredToSubmit) {
        this.label = label;
        this.requiredToSubmit = requiredToSubmit;
    }

    public String label() {
        return label;
    }

    public boolean requiredToSubmit() {
        return requiredToSubmit;
    }

    public static List<AttachmentType> required() {
        return Arrays.stream(values()).filter(AttachmentType::requiredToSubmit).toList();
    }

    /** @throws IllegalArgumentException for an unknown code, which the API reports as 400. */
    public static AttachmentType of(String code) {
        if (code != null) {
            for (AttachmentType type : values()) {
                if (type.name().equalsIgnoreCase(code.trim())) {
                    return type;
                }
            }
        }
        throw new IllegalArgumentException("Unknown attachment type '%s'.".formatted(code));
    }

    /** The label for a stored code, or the code itself if it is not one of ours. */
    public static String labelOf(String code) {
        for (AttachmentType type : values()) {
            if (type.name().equalsIgnoreCase(code)) {
                return type.label;
            }
        }
        return code;
    }
}
