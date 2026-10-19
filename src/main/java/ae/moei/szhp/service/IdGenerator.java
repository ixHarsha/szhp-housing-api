package ae.moei.szhp.service;

import java.security.SecureRandom;
import org.springframework.stereotype.Component;

/**
 * Primary keys in these tables are application-assigned strings, not identity
 * columns: APPLICATION_ID looks like MSZHP_100005 and COMMON_REQUEST_HISTORY.ID
 * is an NVARCHAR(50). This mints them in the same shape.
 */
@Component
public class IdGenerator {

    private static final SecureRandom RANDOM = new SecureRandom();

    /** e.g. MSZHP_482913746. */
    public String applicationId() {
        return "MSZHP_" + Math.abs(RANDOM.nextLong() % 1_000_000_000L);
    }

    /** e.g. HIST_1a2b3c4d5e6f. */
    public String historyId() {
        return "HIST_" + Long.toHexString(Math.abs(RANDOM.nextLong()));
    }

    /** e.g. ATT_1a2b3c4d5e6f. */
    public String attachmentId() {
        return "ATT_" + Long.toHexString(Math.abs(RANDOM.nextLong()));
    }
}
