package ae.moei.szhp.service;

import ae.moei.szhp.dao.AttachmentDao;
import ae.moei.szhp.dao.HousingApplicationDao;
import ae.moei.szhp.dao.StoredAttachment;
import ae.moei.szhp.dto.Attachment;
import ae.moei.szhp.dto.HousingApplicationDetails;
import java.io.IOException;
import java.io.UncheckedIOException;
import java.util.Base64;
import java.util.List;
import java.util.Locale;
import java.util.Map;
import java.util.Set;
import java.util.stream.Collectors;
import org.springframework.stereotype.Service;
import org.springframework.web.multipart.MultipartFile;

/**
 * Supporting documents for a request. Files are stored base64-encoded in
 * MOEI_SZHP_ATTACHMENTS.FILE_CONTENT (demo storage, see 04_attachments.sql).
 */
@Service
public class AttachmentService {

    public static final long MAX_FILE_SIZE = 5L * 1024 * 1024;
    public static final int MAX_FILES_PER_REQUEST = 20;

    /** Extension -> MIME type. The stored type comes from here, never from the client. */
    private static final Map<String, String> ALLOWED = Map.of(
            "pdf", "application/pdf",
            "jpg", "image/jpeg",
            "jpeg", "image/jpeg",
            "png", "image/png");

    private final AttachmentDao attachments;
    private final HousingApplicationDao applications;
    private final IdGenerator idGenerator;

    public AttachmentService(AttachmentDao attachments, HousingApplicationDao applications, IdGenerator idGenerator) {
        this.attachments = attachments;
        this.applications = applications;
        this.idGenerator = idGenerator;
    }

    public List<Attachment> list(String applicationId) {
        require(applicationId);
        return attachments.list(applicationId);
    }

    /** For callers that have already loaded the application. */
    List<Attachment> listLoaded(String applicationId) {
        return attachments.list(applicationId);
    }

    public Attachment upload(String applicationId, String attachmentTypeId, MultipartFile file, String applicant) {
        HousingApplicationDetails application = requireEditable(applicationId);
        AttachmentType type = AttachmentType.of(attachmentTypeId);

        if (file == null || file.isEmpty()) {
            throw new IllegalArgumentException("Choose a file to upload.");
        }
        if (file.getSize() > MAX_FILE_SIZE) {
            throw new IllegalArgumentException("Files must be 5 MB or smaller.");
        }
        String fileName = cleanFileName(file.getOriginalFilename());
        String extension = extensionOf(fileName);
        String mimeType = ALLOWED.get(extension);
        if (mimeType == null) {
            throw new IllegalArgumentException("Only PDF, JPG and PNG files can be uploaded.");
        }
        byte[] content = bytesOf(file);
        if (!matchesSignature(extension, content)) {
            throw new IllegalArgumentException("The file content does not match its ." + extension + " extension.");
        }
        if (attachments.list(applicationId).size() >= MAX_FILES_PER_REQUEST) {
            throw new RuleViolationException(
                    "A request can have at most %d documents.".formatted(MAX_FILES_PER_REQUEST));
        }

        String owner = application.applicant == null ? null : application.applicant.userId();
        String attachmentId = idGenerator.attachmentId();
        attachments.insert(attachmentId, applicationId, owner, type.name(), fileName, mimeType,
                content.length, Base64.getEncoder().encodeToString(content),
                isBlank(applicant) ? owner : applicant);

        return attachments.list(applicationId).stream()
                .filter(a -> attachmentId.equals(a.id()))
                .findFirst()
                .orElseThrow();
    }

    public AttachmentFile download(String applicationId, String attachmentId) {
        StoredAttachment stored = attachments.find(applicationId, attachmentId)
                .orElseThrow(() -> new NotFoundException(
                        "Attachment %s was not found on request %s.".formatted(attachmentId, applicationId)));
        return new AttachmentFile(stored.attachment(), Base64.getDecoder().decode(stored.base64Content()));
    }

    public void delete(String applicationId, String attachmentId) {
        requireEditable(applicationId);
        if (!attachments.delete(applicationId, attachmentId)) {
            throw new NotFoundException(
                    "Attachment %s was not found on request %s.".formatted(attachmentId, applicationId));
        }
    }

    /** Submission rule: every required document type has at least one file. */
    public void assertRequiredDocuments(String applicationId) {
        Set<String> present = attachments.list(applicationId).stream()
                .map(Attachment::attachmentTypeId)
                .collect(Collectors.toSet());
        List<String> missing = AttachmentType.required().stream()
                .filter(type -> !present.contains(type.name()))
                .map(AttachmentType::label)
                .toList();
        if (!missing.isEmpty()) {
            throw new RuleViolationException(
                    "Upload the following documents before submitting: " + String.join(", ", missing) + ".");
        }
    }

    /* ------------------------------------------------------------ helpers */

    private HousingApplicationDetails require(String applicationId) {
        return applications.find(applicationId)
                .orElseThrow(() -> new NotFoundException(
                        "Housing application %s was not found.".formatted(applicationId)));
    }

    private HousingApplicationDetails requireEditable(String applicationId) {
        HousingApplicationDetails application = require(applicationId);
        if (!ApplicationStatus.isEditable(application.status)) {
            throw new RuleViolationException(
                    "Documents can no longer be changed on a request with status '%s'.".formatted(application.status));
        }
        return application;
    }

    /** Drops any path the browser sent and characters that do not belong in a header. */
    static String cleanFileName(String original) {
        String name = original == null ? "" : original;
        name = name.substring(Math.max(name.lastIndexOf('/'), name.lastIndexOf('\\')) + 1);
        name = name.replaceAll("[\\p{Cntrl}\"]", "").trim();
        if (name.isEmpty()) {
            throw new IllegalArgumentException("The file has no name.");
        }
        return name.length() > 200 ? name.substring(name.length() - 200) : name;
    }

    static String extensionOf(String fileName) {
        int dot = fileName.lastIndexOf('.');
        return dot < 0 ? "" : fileName.substring(dot + 1).toLowerCase(Locale.ROOT);
    }

    /** Checks the leading bytes, so a renamed executable is not accepted as a PDF. */
    static boolean matchesSignature(String extension, byte[] content) {
        return switch (extension) {
            case "pdf" -> startsWith(content, 0x25, 0x50, 0x44, 0x46);        // %PDF
            case "png" -> startsWith(content, 0x89, 0x50, 0x4E, 0x47);        // .PNG
            case "jpg", "jpeg" -> startsWith(content, 0xFF, 0xD8, 0xFF);
            default -> false;
        };
    }

    private static boolean startsWith(byte[] content, int... signature) {
        if (content.length < signature.length) {
            return false;
        }
        for (int i = 0; i < signature.length; i++) {
            if ((content[i] & 0xFF) != signature[i]) {
                return false;
            }
        }
        return true;
    }

    private static byte[] bytesOf(MultipartFile file) {
        try {
            return file.getBytes();
        } catch (IOException ex) {
            throw new UncheckedIOException("The uploaded file could not be read.", ex);
        }
    }

    private static boolean isBlank(String value) {
        return value == null || value.isBlank();
    }

    /** A decoded attachment, ready to stream back. */
    public record AttachmentFile(Attachment attachment, byte[] content) {
    }
}
