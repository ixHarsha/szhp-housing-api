package ae.moei.szhp.web;

import java.time.OffsetDateTime;

public record ApiError(int status, String error, String message, OffsetDateTime timestamp) {

    public static ApiError of(int status, String error, String message) {
        return new ApiError(status, error, message, OffsetDateTime.now());
    }
}
