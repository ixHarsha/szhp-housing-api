package ae.moei.szhp.dto;

/** One COMMON_REQUEST_HISTORY row, as the timeline consumes it. */
public record RequestHistory(
        String id,
        String requestId,
        String taskId,
        String taskName,
        String processType,
        String taskAction,
        String status,
        String processStatus,
        String requestStatus,
        String comments,
        String actedBy,
        String acceptedBy,
        Boolean isActive,
        String createdDate,
        String completionDate) {
}
