package ae.moei.szhp.service;

import static org.assertj.core.api.Assertions.assertThat;
import static org.assertj.core.api.Assertions.assertThatThrownBy;

import org.junit.jupiter.api.Test;

class AttachmentRulesTest {

    @Test
    void emiratesIdAndFamilyBookAreRequiredToSubmit() {
        assertThat(AttachmentType.required())
                .containsExactly(AttachmentType.EMIRATES_ID, AttachmentType.FAMILY_BOOK);
    }

    @Test
    void unknownTypeIsABadRequest() {
        assertThat(AttachmentType.of("family_book")).isEqualTo(AttachmentType.FAMILY_BOOK);
        assertThatThrownBy(() -> AttachmentType.of("PASSPORT")).isInstanceOf(IllegalArgumentException.class);
        assertThatThrownBy(() -> AttachmentType.of(null)).isInstanceOf(IllegalArgumentException.class);
    }

    @Test
    void contentMustMatchTheExtension() {
        byte[] pdf = {0x25, 0x50, 0x44, 0x46, 0x2D};
        byte[] png = {(byte) 0x89, 0x50, 0x4E, 0x47, 0x0D};
        byte[] jpg = {(byte) 0xFF, (byte) 0xD8, (byte) 0xFF, (byte) 0xE0};

        assertThat(AttachmentService.matchesSignature("pdf", pdf)).isTrue();
        assertThat(AttachmentService.matchesSignature("png", png)).isTrue();
        assertThat(AttachmentService.matchesSignature("jpeg", jpg)).isTrue();
        assertThat(AttachmentService.matchesSignature("pdf", png)).isFalse();
        assertThat(AttachmentService.matchesSignature("pdf", new byte[] {0x25})).isFalse();
        assertThat(AttachmentService.matchesSignature("exe", pdf)).isFalse();
    }

    @Test
    void fileNameLosesAnyPathTheBrowserSent() {
        assertThat(AttachmentService.cleanFileName("C:\\Users\\me\\Emirates ID.pdf")).isEqualTo("Emirates ID.pdf");
        assertThat(AttachmentService.cleanFileName("../../etc/passwd.png")).isEqualTo("passwd.png");
        assertThat(AttachmentService.cleanFileName("bad\"name\n.pdf")).isEqualTo("badname.pdf");
        assertThatThrownBy(() -> AttachmentService.cleanFileName("  ")).isInstanceOf(IllegalArgumentException.class);
    }
}
