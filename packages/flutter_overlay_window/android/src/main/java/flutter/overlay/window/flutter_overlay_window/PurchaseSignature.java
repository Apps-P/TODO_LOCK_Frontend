package flutter.overlay.window.flutter_overlay_window;

import java.security.KeyFactory;
import java.security.Signature;
import java.security.spec.X509EncodedKeySpec;

/** Local Play receipt signature verification; malformed input fails closed. */
final class PurchaseSignature {
    static boolean verify(byte[] key, byte[] payload, byte[] signature) {
        try {
            Signature verifier = Signature.getInstance("SHA1withRSA");
            verifier.initVerify(KeyFactory.getInstance("RSA").generatePublic(new X509EncodedKeySpec(key)));
            verifier.update(payload);
            return verifier.verify(signature);
        } catch (Exception invalid) { return false; }
    }
}
