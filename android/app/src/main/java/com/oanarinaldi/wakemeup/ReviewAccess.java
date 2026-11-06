package com.oanarinaldi.wakemeup;

import java.nio.charset.StandardCharsets;
import java.security.MessageDigest;
import java.security.NoSuchAlgorithmException;
import java.util.Base64;

final class ReviewAccess {
    private ReviewAccess() {}

    static boolean matches(String input, String encodedDigest) {
        if (encodedDigest.isEmpty() || input.length() > 128) return false;
        try {
            byte[] expected = Base64.getDecoder().decode(encodedDigest);
            byte[] actual = MessageDigest.getInstance("SHA-256")
                .digest(input.trim().getBytes(StandardCharsets.UTF_8));
            return MessageDigest.isEqual(expected, actual);
        } catch (IllegalArgumentException | NoSuchAlgorithmException e) {
            return false;
        }
    }
}
