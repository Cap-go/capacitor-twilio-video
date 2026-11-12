package ee.forgr.capacitor.twilio.video;

import static org.junit.Assert.assertEquals;
import static org.junit.Assert.assertFalse;
import static org.junit.Assert.assertTrue;

import org.junit.Test;

public class CapacitorTwilioVideoTokenTest {

    private static final String VALID_TOKEN = "eyJhbGciOiJub25lIn0.eyJleHAiOjQxMDI0NDQ4MDAsImdyYW50cyI6eyJpZGVudGl0eSI6InRlc3QifX0.x";

    private static final String EXPIRED_TOKEN = "eyJhbGciOiJub25lIn0.eyJleHAiOjEsImdyYW50cyI6eyJpZGVudGl0eSI6InRlc3QifX0.x";

    @Test
    public void isTokenValid_acceptsFutureExpiration() {
        CapacitorTwilioVideo implementation = new CapacitorTwilioVideo();
        assertTrue(implementation.isTokenValid(VALID_TOKEN));
    }

    @Test
    public void isTokenValid_rejectsExpiredToken() {
        CapacitorTwilioVideo implementation = new CapacitorTwilioVideo();
        assertFalse(implementation.isTokenValid(EXPIRED_TOKEN));
    }

    @Test
    public void extractIdentity_readsGrantIdentity() {
        CapacitorTwilioVideo implementation = new CapacitorTwilioVideo();
        assertEquals("test", implementation.extractIdentity(VALID_TOKEN));
    }
}
