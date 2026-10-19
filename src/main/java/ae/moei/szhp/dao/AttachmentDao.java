package ae.moei.szhp.dao;

import ae.moei.szhp.dto.Attachment;
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
 * Attachment access, through the procedures in db/mssql/04_attachments.sql.
 * No SQL is built in Java.
 */
@Repository
public class AttachmentDao {

    private static final String SCHEMA = "dbo";
    private static final String ROWS = "rows";

    private final SimpleJdbcCall list;
    private final SimpleJdbcCall get;
    private final SimpleJdbcCall insert;
    private final SimpleJdbcCall delete;

    public AttachmentDao(DataSource dataSource) {
        this.list = call(dataSource, "usp_SZHP_Attachment_List")
                .declareParameters(new SqlParameter("RequestId", Types.NVARCHAR))
                .returningResultSet(ROWS, RowMappers.ATTACHMENT);

        this.get = call(dataSource, "usp_SZHP_Attachment_Get")
                .declareParameters(
                        new SqlParameter("RequestId", Types.NVARCHAR),
                        new SqlParameter("AttachmentId", Types.NVARCHAR))
                .returningResultSet(ROWS, RowMappers.STORED_ATTACHMENT);

        this.insert = call(dataSource, "usp_SZHP_Attachment_Insert")
                .declareParameters(
                        new SqlParameter("AttachmentId", Types.NVARCHAR),
                        new SqlParameter("RequestId", Types.NVARCHAR),
                        new SqlParameter("ApplicantId", Types.NVARCHAR),
                        new SqlParameter("AttachmentTypeId", Types.NVARCHAR),
                        new SqlParameter("Category", Types.NVARCHAR),
                        new SqlParameter("FileName", Types.NVARCHAR),
                        new SqlParameter("FileType", Types.NVARCHAR),
                        new SqlParameter("FileSize", Types.BIGINT),
                        new SqlParameter("FileContent", Types.VARCHAR),
                        new SqlParameter("Source", Types.NVARCHAR),
                        new SqlParameter("CreatedBy", Types.NVARCHAR));

        this.delete = call(dataSource, "usp_SZHP_Attachment_Delete")
                .declareParameters(
                        new SqlParameter("RequestId", Types.NVARCHAR),
                        new SqlParameter("AttachmentId", Types.NVARCHAR),
                        new SqlOutParameter("Deleted", Types.INTEGER));
    }

    private static SimpleJdbcCall call(DataSource dataSource, String procedureName) {
        return new SimpleJdbcCall(dataSource)
                .withSchemaName(SCHEMA)
                .withProcedureName(procedureName)
                .withoutProcedureColumnMetaDataAccess();
    }

    public List<Attachment> list(String requestId) {
        return rows(list.execute(new MapSqlParameterSource("RequestId", requestId)));
    }

    public Optional<StoredAttachment> find(String requestId, String attachmentId) {
        List<StoredAttachment> rows = rows(get.execute(new MapSqlParameterSource()
                .addValue("RequestId", requestId)
                .addValue("AttachmentId", attachmentId)));
        return rows.stream().findFirst();
    }

    public void insert(String attachmentId,
                       String requestId,
                       String applicantId,
                       String attachmentTypeId,
                       String fileName,
                       String fileType,
                       long fileSize,
                       String base64Content,
                       String createdBy) {
        insert.execute(new MapSqlParameterSource()
                .addValue("AttachmentId", attachmentId)
                .addValue("RequestId", requestId)
                .addValue("ApplicantId", applicantId)
                .addValue("AttachmentTypeId", attachmentTypeId)
                .addValue("Category", "SZHP")
                .addValue("FileName", fileName)
                .addValue("FileType", fileType)
                .addValue("FileSize", fileSize)
                .addValue("FileContent", base64Content)
                .addValue("Source", "Website")
                .addValue("CreatedBy", createdBy));
    }

    /** Soft delete. Returns false when there was no active attachment to delete. */
    public boolean delete(String requestId, String attachmentId) {
        Map<String, Object> out = delete.execute(new MapSqlParameterSource()
                .addValue("RequestId", requestId)
                .addValue("AttachmentId", attachmentId));
        Object deleted = out.get("Deleted");
        return deleted instanceof Number n && n.intValue() > 0;
    }

    @SuppressWarnings("unchecked")
    private static <T> List<T> rows(Map<String, Object> out) {
        List<T> rows = (List<T>) out.get(ROWS);
        return rows == null ? List.of() : rows;
    }
}
