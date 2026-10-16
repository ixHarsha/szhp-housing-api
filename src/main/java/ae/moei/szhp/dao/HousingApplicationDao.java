package ae.moei.szhp.dao;

import ae.moei.szhp.dto.FamilyDetails;
import ae.moei.szhp.dto.HousingApplicationDetails;
import ae.moei.szhp.dto.HousingApplicationSummary;
import ae.moei.szhp.dto.PagedResponse;
import ae.moei.szhp.dto.RequestHistory;
import java.math.BigDecimal;
import java.sql.Types;
import java.util.List;
import java.util.Map;
import java.util.Optional;
import javax.sql.DataSource;
import org.springframework.jdbc.core.SqlOutParameter;
import org.springframework.jdbc.core.SqlParameter;
import org.springframework.jdbc.core.namedparam.MapSqlParameterSource;
import org.springframework.jdbc.core.simple.SimpleJdbcCall;
import org.springframework.stereotype.Repository;

/**
 * All database access, through the procedures in db/mssql/02_procedures.sql.
 * No SQL is built in Java.
 */
@Repository
public class HousingApplicationDao {

    private static final String SCHEMA = "dbo";
    private static final String ROWS = "rows";

    private final SimpleJdbcCall list;
    private final SimpleJdbcCall get;
    private final SimpleJdbcCall familyList;
    private final SimpleJdbcCall eligibility;
    private final SimpleJdbcCall insert;
    private final SimpleJdbcCall update;
    private final SimpleJdbcCall changeStatus;
    private final SimpleJdbcCall historyList;

    public HousingApplicationDao(DataSource dataSource) {
        this.list = call(dataSource, "usp_SZHP_HousingApplication_List")
                .declareParameters(
                        new SqlParameter("Applicant", Types.NVARCHAR),
                        new SqlParameter("Status", Types.NVARCHAR),
                        new SqlParameter("Search", Types.NVARCHAR),
                        new SqlParameter("Offset", Types.INTEGER),
                        new SqlParameter("PageSize", Types.INTEGER),
                        new SqlOutParameter("TotalCount", Types.INTEGER))
                .returningResultSet(ROWS, RowMappers.SUMMARY);

        this.get = call(dataSource, "usp_SZHP_HousingApplication_Get")
                .declareParameters(new SqlParameter("ApplicationId", Types.NVARCHAR))
                .returningResultSet(ROWS, RowMappers.DETAILS);

        this.familyList = call(dataSource, "usp_SZHP_ApplicantFamily_List")
                .declareParameters(new SqlParameter("Applicant", Types.NVARCHAR))
                .returningResultSet(ROWS, RowMappers.FAMILY);

        this.eligibility = call(dataSource, "usp_SZHP_Applicant_Eligibility")
                .declareParameters(
                        new SqlParameter("Applicant", Types.NVARCHAR),
                        new SqlParameter("CurrentSalary", Types.DECIMAL))
                .returningResultSet(ROWS, (rs, rowNum) -> rs.getString("ELIGIBILITY"));

        this.insert = call(dataSource, "usp_SZHP_HousingApplication_Insert")
                .declareParameters(concat(
                        new SqlParameter[] {
                                new SqlParameter("ApplicationId", Types.NVARCHAR),
                                new SqlParameter("Applicant", Types.NVARCHAR),
                                new SqlParameter("RequestType", Types.NVARCHAR),
                                new SqlParameter("Status", Types.NVARCHAR),
                                new SqlParameter("Source", Types.NVARCHAR),
                        },
                        formParameters(),
                        new SqlParameter[] {
                                new SqlParameter("CreatedBy", Types.NVARCHAR),
                                new SqlOutParameter("ApplicationNo", Types.NVARCHAR),
                                new SqlOutParameter("ReferenceNo", Types.NVARCHAR),
                        }));

        this.update = call(dataSource, "usp_SZHP_HousingApplication_Update")
                .declareParameters(concat(
                        new SqlParameter[] { new SqlParameter("ApplicationId", Types.NVARCHAR) },
                        formParameters(),
                        new SqlParameter[] { new SqlParameter("UpdatedByApplicant", Types.NVARCHAR) }));

        this.changeStatus = call(dataSource, "usp_SZHP_HousingApplication_ChangeStatus")
                .declareParameters(
                        new SqlParameter("ApplicationId", Types.NVARCHAR),
                        new SqlParameter("ToStatus", Types.NVARCHAR),
                        new SqlParameter("TaskName", Types.NVARCHAR),
                        new SqlParameter("TaskAction", Types.NVARCHAR),
                        new SqlParameter("Comments", Types.NVARCHAR),
                        new SqlParameter("ActedBy", Types.NVARCHAR),
                        new SqlParameter("HistoryId", Types.NVARCHAR));

        this.historyList = call(dataSource, "usp_SZHP_RequestHistory_List")
                .declareParameters(new SqlParameter("RequestId", Types.NVARCHAR))
                .returningResultSet(ROWS, RowMappers.HISTORY);
    }

    private static SimpleJdbcCall call(DataSource dataSource, String procedureName) {
        return new SimpleJdbcCall(dataSource)
                .withSchemaName(SCHEMA)
                .withProcedureName(procedureName)
                .withoutProcedureColumnMetaDataAccess();
    }

    /** The parameter block shared by insert and update, in declaration order. */
    private static SqlParameter[] formParameters() {
        return new SqlParameter[] {
                new SqlParameter("AidType", Types.NVARCHAR),
                new SqlParameter("AssistanceType", Types.NVARCHAR),
                new SqlParameter("AssistancePurpose", Types.NVARCHAR),
                new SqlParameter("AssistancePurposeCategory", Types.NVARCHAR),
                new SqlParameter("MaritalStatus", Types.NVARCHAR),
                new SqlParameter("MaritalCategory", Types.NVARCHAR),
                new SqlParameter("NoOfWives", Types.INTEGER),
                new SqlParameter("NoOfChildren", Types.INTEGER),
                new SqlParameter("MarriageDate", Types.DATE),
                new SqlParameter("DivorceDate", Types.DATE),
                new SqlParameter("SpouseDeathDate", Types.DATE),
                new SqlParameter("FamilyBookEmirate", Types.NVARCHAR),
                new SqlParameter("Region", Types.NVARCHAR),
                new SqlParameter("HousingOwnership", Types.NVARCHAR),
                new SqlParameter("Location", Types.NVARCHAR),
                new SqlParameter("LeaseRentalDate", Types.DATE),
                new SqlParameter("YearsOfStaying", Types.INTEGER),
                new SqlParameter("LandForConstruction", Types.NVARCHAR),
                new SqlParameter("TechnicalConsition", Types.NVARCHAR),
                new SqlParameter("DwellingYOC", Types.NVARCHAR),
                new SqlParameter("ConstructionAreaSqFeet", Types.DECIMAL),
                new SqlParameter("NoOfOccupants", Types.INTEGER),
                new SqlParameter("NoOfRooms", Types.INTEGER),
                new SqlParameter("NoOfCouncils", Types.INTEGER),
                new SqlParameter("NoOfBathrooms", Types.INTEGER),
                new SqlParameter("NoOfKitchens", Types.INTEGER),
                new SqlParameter("NoOfBedRooms", Types.INTEGER),
                new SqlParameter("ReceivedHousingAid", Types.NVARCHAR),
                new SqlParameter("NoPrevHousingAsst", Types.NVARCHAR),
        };
    }

    private static SqlParameter[] concat(SqlParameter[]... blocks) {
        return java.util.Arrays.stream(blocks)
                .flatMap(java.util.Arrays::stream)
                .toArray(SqlParameter[]::new);
    }

    /* ------------------------------------------------------------ reads */

    public PagedResponse<HousingApplicationSummary> list(String applicant,
                                                         String status,
                                                         String search,
                                                         int pageNo,
                                                         int pageSize) {
        Map<String, Object> out = list.execute(new MapSqlParameterSource()
                .addValue("Applicant", applicant)
                .addValue("Status", status)
                .addValue("Search", search)
                .addValue("Offset", (pageNo - 1) * pageSize)
                .addValue("PageSize", pageSize));

        int total = out.get("TotalCount") == null ? 0 : ((Number) out.get("TotalCount")).intValue();
        List<HousingApplicationSummary> rows = rows(out);
        return new PagedResponse<>(rows, total, pageNo, pageSize);
    }

    public Optional<HousingApplicationDetails> find(String applicationId) {
        Map<String, Object> out = get.execute(new MapSqlParameterSource("ApplicationId", applicationId));
        List<HousingApplicationDetails> rows = rows(out);
        return rows.stream().findFirst();
    }

    public List<FamilyDetails> listFamily(String applicant) {
        return rows(familyList.execute(new MapSqlParameterSource("Applicant", applicant)));
    }

    public Optional<String> eligibility(String applicant, BigDecimal currentSalary) {
        Map<String, Object> out = eligibility.execute(new MapSqlParameterSource()
                .addValue("Applicant", applicant)
                .addValue("CurrentSalary", currentSalary));
        List<String> rows = rows(out);
        return rows.stream().findFirst();
    }

    public List<RequestHistory> listHistory(String requestId) {
        return rows(historyList.execute(new MapSqlParameterSource("RequestId", requestId)));
    }

    /* ----------------------------------------------------------- writes */

    /** Returns the APPLICATION_NO and REFERENCE_NO the procedure assigned. */
    public Map<String, Object> insert(String applicationId,
                                      String applicant,
                                      String status,
                                      String source,
                                      String createdBy,
                                      MapSqlParameterSource formValues) {
        MapSqlParameterSource params = formValues
                .addValue("ApplicationId", applicationId)
                .addValue("Applicant", applicant)
                .addValue("RequestType", "SZHP")
                .addValue("Status", status)
                .addValue("Source", source)
                .addValue("CreatedBy", createdBy);
        return insert.execute(params);
    }

    public void update(String applicationId, String updatedBy, MapSqlParameterSource formValues) {
        update.execute(formValues
                .addValue("ApplicationId", applicationId)
                .addValue("UpdatedByApplicant", updatedBy));
    }

    public void changeStatus(String applicationId,
                             String toStatus,
                             String taskName,
                             String taskAction,
                             String comments,
                             String actedBy,
                             String historyId) {
        changeStatus.execute(new MapSqlParameterSource()
                .addValue("ApplicationId", applicationId)
                .addValue("ToStatus", toStatus)
                .addValue("TaskName", taskName)
                .addValue("TaskAction", taskAction)
                .addValue("Comments", comments)
                .addValue("ActedBy", actedBy)
                .addValue("HistoryId", historyId));
    }

    @SuppressWarnings("unchecked")
    private static <T> List<T> rows(Map<String, Object> out) {
        List<T> rows = (List<T>) out.get(ROWS);
        return rows == null ? List.of() : rows;
    }
}
