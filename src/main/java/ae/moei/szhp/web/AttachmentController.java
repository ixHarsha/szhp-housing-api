package ae.moei.szhp.web;

import ae.moei.szhp.dto.Attachment;
import ae.moei.szhp.service.AttachmentService;
import ae.moei.szhp.service.AttachmentService.AttachmentFile;
import java.nio.charset.StandardCharsets;
import java.util.List;
import org.springframework.http.ContentDisposition;
import org.springframework.http.HttpHeaders;
import org.springframework.http.HttpStatus;
import org.springframework.http.MediaType;
import org.springframework.http.ResponseEntity;
import org.springframework.web.bind.annotation.DeleteMapping;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;
import org.springframework.web.multipart.MultipartFile;

/**
 * Supporting documents for a request. Uploads are multipart; the service
 * stores them base64-encoded. Like the rest of this API, the applicant id in
 * {@code X-Applicant-Id} is trusted as sent - not a security control.
 */
@RestController
@RequestMapping("/api/housing-applications/{applicationId}/attachments")
public class AttachmentController {

    private static final String APPLICANT_HEADER = "X-Applicant-Id";

    private final AttachmentService service;

    public AttachmentController(AttachmentService service) {
        this.service = service;
    }

    @GetMapping
    public List<Attachment> list(@PathVariable String applicationId) {
        return service.list(applicationId);
    }

    @PostMapping(consumes = MediaType.MULTIPART_FORM_DATA_VALUE)
    @ResponseStatus(HttpStatus.CREATED)
    public Attachment upload(
            @PathVariable String applicationId,
            @RequestParam String attachmentTypeId,
            @RequestParam("file") MultipartFile file,
            @RequestHeader(value = APPLICANT_HEADER, required = false) String applicant) {
        return service.upload(applicationId, attachmentTypeId, file, applicant);
    }

    @GetMapping("/{attachmentId}")
    public ResponseEntity<byte[]> download(@PathVariable String applicationId, @PathVariable String attachmentId) {
        AttachmentFile file = service.download(applicationId, attachmentId);
        return ResponseEntity.ok()
                .contentType(MediaType.parseMediaType(file.attachment().fileType()))
                .header(HttpHeaders.CONTENT_DISPOSITION, ContentDisposition.inline()
                        .filename(file.attachment().fileName(), StandardCharsets.UTF_8)
                        .build()
                        .toString())
                .header("X-Content-Type-Options", "nosniff")
                .contentLength(file.content().length)
                .body(file.content());
    }

    @DeleteMapping("/{attachmentId}")
    @ResponseStatus(HttpStatus.NO_CONTENT)
    public void delete(@PathVariable String applicationId, @PathVariable String attachmentId) {
        service.delete(applicationId, attachmentId);
    }
}
