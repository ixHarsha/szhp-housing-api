package ae.moei.szhp.dto;

/**
 * Mirrors IAttachment in SZHP-micro-ui, field for field.
 *
 * <p>{@code filePath} is the download path relative to the API base
 * ({@code /housing-applications/{id}/attachments/{attachmentId}}); the file
 * content itself never travels in this DTO.
 */
public record Attachment(
        String fileName,
        String filePath,
        String attachmentTypeId,
        String filePathId,
        String source,
        String type,
        String lastUpdatedDate,
        String fileSize,
        String requestId,
        String id,
        String applicantId,
        String category,
        String fileType,
        String status) {
}
