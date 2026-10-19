package ae.moei.szhp.dao;

import ae.moei.szhp.dto.Attachment;

/** An attachment row with its content, as base64 exactly as stored. */
public record StoredAttachment(Attachment attachment, String base64Content) {
}
