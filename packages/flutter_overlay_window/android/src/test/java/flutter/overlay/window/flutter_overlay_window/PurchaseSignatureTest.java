package flutter.overlay.window.flutter_overlay_window;

import org.junit.Test;
import static org.junit.Assert.*;
import java.nio.charset.StandardCharsets;
import java.security.*;

public class PurchaseSignatureTest {
    @Test public void authenticReceiptVerifiesButTamperedReceiptDoesNot() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        KeyPair pair = generator.generateKeyPair();
        byte[] payload = "{\"productId\":\"give_up_unlock\"}".getBytes(StandardCharsets.UTF_8);
        Signature signer = Signature.getInstance("SHA1withRSA"); signer.initSign(pair.getPrivate()); signer.update(payload);
        byte[] signature = signer.sign();
        assertTrue(PurchaseSignature.verify(pair.getPublic().getEncoded(), payload, signature));
        payload[5] ^= 1;
        assertFalse(PurchaseSignature.verify(pair.getPublic().getEncoded(), payload, signature));
    }
    @Test public void invalidKeyAndInvalidSignatureNeverVerify() {
        assertFalse(PurchaseSignature.verify(new byte[0], new byte[0], new byte[0]));
    }
    @Test public void differentAppKeyCannotVerifyReceipt() throws Exception {
        KeyPairGenerator generator = KeyPairGenerator.getInstance("RSA"); generator.initialize(2048);
        KeyPair signerKey = generator.generateKeyPair(); KeyPair otherKey = generator.generateKeyPair();
        byte[] payload = "receipt".getBytes(StandardCharsets.UTF_8);
        Signature signer = Signature.getInstance("SHA1withRSA"); signer.initSign(signerKey.getPrivate()); signer.update(payload);
        assertFalse(PurchaseSignature.verify(otherKey.getPublic().getEncoded(), payload, signer.sign()));
    }
}
