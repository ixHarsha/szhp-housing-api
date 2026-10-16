package ae.moei.szhp.service;

/** A request the caller is not allowed to make: wrong state, missing data. */
public class RuleViolationException extends RuntimeException {

    public RuleViolationException(String message) {
        super(message);
    }
}
