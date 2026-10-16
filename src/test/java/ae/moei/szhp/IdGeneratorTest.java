package ae.moei.szhp;

import static org.assertj.core.api.Assertions.assertThat;

import ae.moei.szhp.service.IdGenerator;
import java.util.HashSet;
import java.util.Set;
import org.junit.jupiter.api.Test;

class IdGeneratorTest {

    private final IdGenerator generator = new IdGenerator();

    @Test
    void applicationIdsMatchTheLivePrefixAndAreDistinct() {
        Set<String> ids = new HashSet<>();
        for (int i = 0; i < 500; i++) {
            String id = generator.applicationId();
            assertThat(id).startsWith("MSZHP_");
            assertThat(id).doesNotContain("-");
            ids.add(id);
        }
        assertThat(ids).hasSize(500);
    }

    @Test
    void historyIdsFitTheNvarchar50Column() {
        for (int i = 0; i < 200; i++) {
            assertThat(generator.historyId()).startsWith("HIST_").hasSizeLessThanOrEqualTo(50);
        }
    }
}
