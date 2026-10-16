package ae.moei.szhp.dao;

import java.math.BigDecimal;
import java.sql.ResultSet;
import java.sql.ResultSetMetaData;
import java.sql.SQLException;
import java.sql.Timestamp;
import java.time.format.DateTimeFormatter;
import java.util.HashSet;
import java.util.Set;

/**
 * One result-set row, read by column name and tolerant of missing columns.
 *
 * <p>Tolerance matters because {@code usp_SZHP_HousingApplication_Get} selects
 * {@code h.*}: which columns come back depends on the live table, and one this
 * build does not know about must not fail the whole read.
 *
 * <p>The column set is resolved once per row rather than per lookup - the
 * detail mapper reads about seventy columns, so doing it per lookup would walk
 * the metadata seventy times over.
 */
final class Row {

    private static final DateTimeFormatter ISO = DateTimeFormatter.ISO_LOCAL_DATE_TIME;

    private final ResultSet rs;
    private final Set<String> columns;

    private Row(ResultSet rs, Set<String> columns) {
        this.rs = rs;
        this.columns = columns;
    }

    static Row of(ResultSet rs) throws SQLException {
        ResultSetMetaData meta = rs.getMetaData();
        Set<String> names = new HashSet<>(meta.getColumnCount() * 2);
        for (int i = 1; i <= meta.getColumnCount(); i++) {
            String label = meta.getColumnLabel(i);
            names.add((label == null || label.isEmpty() ? meta.getColumnName(i) : label).toUpperCase());
        }
        return new Row(rs, names);
    }

    /** The value as a String, or null when absent or SQL NULL. */
    String str(String column) throws SQLException {
        if (!columns.contains(column.toUpperCase())) {
            return null;
        }
        Object value = rs.getObject(column);
        return switch (value) {
            case null -> null;
            case Timestamp timestamp -> timestamp.toLocalDateTime().format(ISO);
            case java.sql.Date sqlDate -> sqlDate.toLocalDate().toString();
            case BigDecimal decimal -> decimal.stripTrailingZeros().toPlainString();
            default -> String.valueOf(value);
        };
    }

    Boolean bool(String column) throws SQLException {
        if (!columns.contains(column.toUpperCase())) {
            return null;
        }
        boolean value = rs.getBoolean(column);
        return rs.wasNull() ? null : value;
    }
}
