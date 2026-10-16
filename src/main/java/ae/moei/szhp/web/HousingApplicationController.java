package ae.moei.szhp.web;

import ae.moei.szhp.dto.HousingApplicationDetails;
import ae.moei.szhp.dto.HousingApplicationSummary;
import ae.moei.szhp.dto.PagedResponse;
import ae.moei.szhp.dto.RequestHistory;
import ae.moei.szhp.service.HousingApplicationService;
import java.util.List;
import org.springframework.http.HttpStatus;
import org.springframework.web.bind.annotation.GetMapping;
import org.springframework.web.bind.annotation.PathVariable;
import org.springframework.web.bind.annotation.PostMapping;
import org.springframework.web.bind.annotation.PutMapping;
import org.springframework.web.bind.annotation.RequestBody;
import org.springframework.web.bind.annotation.RequestHeader;
import org.springframework.web.bind.annotation.RequestMapping;
import org.springframework.web.bind.annotation.RequestParam;
import org.springframework.web.bind.annotation.ResponseStatus;
import org.springframework.web.bind.annotation.RestController;

/**
 * The external housing assistance form.
 *
 * <p>There is no sign-in here. In the real portal the applicant comes from the
 * shell's token; standalone the id arrives in {@code X-Applicant-Id}, which the
 * service takes at face value. That is not a security control.
 */
@RestController
@RequestMapping("/api/housing-applications")
public class HousingApplicationController {

    private static final String APPLICANT_HEADER = "X-Applicant-Id";

    private final HousingApplicationService service;

    public HousingApplicationController(HousingApplicationService service) {
        this.service = service;
    }

    @GetMapping
    public PagedResponse<HousingApplicationSummary> list(
            @RequestHeader(value = APPLICANT_HEADER, required = false) String applicant,
            @RequestParam(required = false) String status,
            @RequestParam(required = false) String search,
            @RequestParam(required = false) Integer pageNo,
            @RequestParam(required = false) Integer pageSize) {
        return service.list(applicant, status, search, pageNo, pageSize);
    }

    @GetMapping("/{applicationId}")
    public HousingApplicationDetails get(@PathVariable String applicationId) {
        return service.get(applicationId);
    }

    @GetMapping("/{applicationId}/history")
    public List<RequestHistory> history(@PathVariable String applicationId) {
        return service.history(applicationId);
    }

    @PostMapping
    @ResponseStatus(HttpStatus.CREATED)
    public HousingApplicationDetails create(
            @RequestBody HousingApplicationDetails form,
            @RequestHeader(value = APPLICANT_HEADER, required = false) String applicant,
            @RequestParam(defaultValue = "false") boolean submit) {
        return service.create(form, applicant, submit);
    }

    @PutMapping("/{applicationId}")
    public HousingApplicationDetails update(
            @PathVariable String applicationId,
            @RequestBody HousingApplicationDetails form,
            @RequestHeader(value = APPLICANT_HEADER, required = false) String applicant,
            @RequestParam(defaultValue = "false") boolean submit) {
        return service.update(applicationId, form, applicant, submit);
    }

    @PostMapping("/{applicationId}/submit")
    public HousingApplicationDetails submit(
            @PathVariable String applicationId,
            @RequestHeader(value = APPLICANT_HEADER, required = false) String applicant) {
        return service.submit(applicationId, applicant);
    }
}
