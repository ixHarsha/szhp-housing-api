package ae.moei.szhp;

import org.junit.jupiter.api.Test;
import org.springframework.boot.test.context.SpringBootTest;
import org.springframework.test.context.TestPropertySource;

/**
 * Wires the whole application: the DAOs declare twelve SimpleJdbcCalls, so a
 * mistake in the procedure parameter declarations shows up here.
 *
 * <p>No SQL Server is contacted. The calls are built with
 * withoutProcedureColumnMetaDataAccess(), so none of them reads database
 * metadata at startup, and Hikari opens no connection until a query runs.
 */
@SpringBootTest
@TestPropertySource(properties = {
        "spring.datasource.url=jdbc:sqlserver://localhost:1433;databaseName=MOEI;encrypt=false",
        "spring.datasource.username=unused",
        "spring.datasource.password=unused",
})
class ApplicationContextTest {

    @Test
    void contextLoads() {
        // Startup failure fails the test.
    }
}
