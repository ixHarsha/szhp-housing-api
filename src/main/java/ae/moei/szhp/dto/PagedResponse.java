package ae.moei.szhp.dto;

import java.util.List;

public record PagedResponse<T>(List<T> data, int totalCount, int pageNo, int pageSize) {
}
