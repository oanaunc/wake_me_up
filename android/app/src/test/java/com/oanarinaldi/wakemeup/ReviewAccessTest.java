package com.oanarinaldi.wakemeup;

import org.junit.Test;

import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

public class ReviewAccessTest {
    private static final String DIGEST_OF_ABC = "ungWv48Bz+pBQUDeXa4iI7ADYaOWF3qctBD/YfIAFa0=";

    @Test public void acceptsOnlyTheConfiguredReviewerCode() {
        assertTrue(ReviewAccess.matches(" abc\n", DIGEST_OF_ABC));
        assertFalse(ReviewAccess.matches("abd", DIGEST_OF_ABC));
        assertFalse(ReviewAccess.matches("abc", ""));
        assertFalse(ReviewAccess.matches("abc", "invalid!"));
    }
}
