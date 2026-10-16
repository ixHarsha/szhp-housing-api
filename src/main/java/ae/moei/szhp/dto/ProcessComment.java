package ae.moei.szhp.dto;

/** Mirrors IProcessComment. */
public record ProcessComment(
        String comments,
        String actedBy,
        String taskName,
        String processStatus,
        String createdDate) {
}
