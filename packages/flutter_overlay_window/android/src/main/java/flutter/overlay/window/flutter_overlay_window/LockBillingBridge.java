package flutter.overlay.window.flutter_overlay_window;

import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Handler;
import android.os.Looper;
import android.util.Base64;
import com.android.billingclient.api.*;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import org.json.JSONObject;
import java.nio.charset.StandardCharsets;
import java.security.KeyFactory;
import java.security.MessageDigest;
import java.security.spec.X509EncodedKeySpec;
import java.util.*;

/** Process-wide bridge, shared by the app and overlay Flutter engines.
 * All calls and Billing callbacks run on the main thread. Preferences are the
 * durable receipt/outcome journal; Hive is written only by the main Dart engine.
 */
final class LockBillingBridge {
    private static Context context;
    private static SharedPreferences prefs;
    private static MethodChannel.Result pending;
    private static String requestedSession;
    private static BillingHostActivity host;
    private static boolean recovering;
    private static final Handler handler = new Handler(Looper.getMainLooper());
    private static final Runnable launchTimeout = () -> cancel("error");

    static void init(Context value) {
        context = value.getApplicationContext();
        prefs = context.getSharedPreferences("todolock_lock_journal", Context.MODE_PRIVATE);
    }
    private static JSONObject json(String key) {
        try { return new JSONObject(prefs.getString(key, "{}")); }
        catch (Exception e) { throw new IllegalStateException("잠금 기록을 읽지 못했습니다.", e); }
    }
    private static void store(String key, JSONObject value) {
        if (!prefs.edit().putString(key, value.toString()).commit())
            throw new IllegalStateException("잠금 기록을 저장하지 못했습니다.");
    }
    static String currentSession() { return json("active").optString("session"); }
    static boolean hasSession() { return !currentSession().isEmpty(); }
    static boolean isRequestActive(String session) {
        return pending != null && Objects.equals(requestedSession, session) && session.equals(currentSession());
    }
    static boolean isPaymentOpen() { return pending != null; }
    static boolean isHost(BillingHostActivity activity) { return host == activity; }
    static void attach(BillingHostActivity activity) { host = activity; }
    static void detach(BillingHostActivity activity) { if (host == activity) host = null; }

    @SuppressWarnings("unchecked")
    static void handle(MethodCall call, MethodChannel.Result result) {
        try {
            String session = call.argument("session");
            switch (call.method) {
                case "recoverPurchases":
                    recoverPurchases(); result.success(null); break;
                case "getSession":
                    JSONObject active = json("active");
                    result.success(active.length() == 0 ? null : asMap(active)); break;
                case "setSession":
                    if (hasSession()) throw new IllegalStateException("이미 진행 중인 잠금이 있습니다.");
                    store("active", new JSONObject((Map<String, Object>) call.arguments));
                    result.success(null); break;
                case "rollbackSession":
                    if (Objects.equals(session, currentSession())) store("active", new JSONObject());
                    result.success(null); break;
                case "getOutcomes": result.success(asMap(json("outcomes"))); break;
                case "ackOutcome":
                    JSONObject outcomes = json("outcomes"); outcomes.remove(session); store("outcomes", outcomes);
                    result.success(null); break;
                case "startBreak":
                    JSONObject lock = json("active");
                    if (!Objects.equals(session, currentSession()) || pending != null || lock.optInt("breakCount") >= 3)
                        throw new IllegalStateException("잠시 해제를 사용할 수 없습니다.");
                    if (lock.optLong("breakUntil") > System.currentTimeMillis()) throw new IllegalStateException("이미 잠시 해제 중입니다.");
                    long until = System.currentTimeMillis() + 120000;
                    lock.put("breakCount", lock.optInt("breakCount") + 1); lock.put("breakUntil", until);
                    store("active", lock); result.success(until); break;
                case "finishSession":
                    if (Objects.equals(session, currentSession())) {
                        if (System.currentTimeMillis() < json("active").optLong("endTime"))
                            throw new IllegalStateException("잠금 시간이 남아 있습니다.");
                        recordOutcome(session, "completed");
                        cancel("completed");
                        closeOverlay();
                    }
                    result.success(null); break;
                case "purchaseUnlock":
                    String product = call.argument("productId");
                    String key = call.argument("publicKey");
                    if (!Objects.equals(session, currentSession()) || session == null)
                        throw new IllegalStateException("진행 중인 잠금이 없습니다.");
                    if (pending != null) throw new IllegalStateException("결제 확인이 진행 중입니다.");
                    if (prefs.getInt("credits", 0) > 0) {
                        grantCredit(session); closeOverlay(); result.success("purchased"); break;
                    }
                    if (product == null || product.isEmpty() || key == null || key.isEmpty()) {
                        result.error("BILLING_NOT_CONFIGURED", "Google Play 상품과 결제 검증 키 설정이 필요합니다. 잠금은 유지됩니다.", null);
                        break;
                    }
                    // Validate the public key before opening any purchase UI.
                    KeyFactory.getInstance("RSA").generatePublic(new X509EncodedKeySpec(Base64.decode(key, Base64.DEFAULT)));
                    String profile = hash(session);
                    JSONObject request = new JSONObject();
                    request.put("session", session); request.put("product", product);
                    store("request_" + profile, request);
                    if (!prefs.edit().putString("public_key", key).commit()) throw new IllegalStateException("결제 설정 저장 실패");
                    pending = result; requestedSession = session;
                    Intent intent = new Intent(context, BillingHostActivity.class);
                    intent.putExtra("session", session); intent.putExtra("product", product);
                    intent.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_EXCLUDE_FROM_RECENTS);
                    handler.postDelayed(launchTimeout, 30000);
                    try { context.startActivity(intent); }
                    catch (Exception e) { cancel("error"); }
                    break;
                default: result.notImplemented();
            }
        } catch (Exception e) {
            OverlayService.setPaymentHidden(false);
            result.error("LOCK_ERROR", e.getMessage(), null);
        }
    }
    private static Map<String, Object> asMap(JSONObject value) throws Exception {
        Map<String, Object> result = new HashMap<>();
        Iterator<String> keys = value.keys();
        while (keys.hasNext()) { String key = keys.next(); result.put(key, value.get(key)); }
        return result;
    }
    static String profile(String session) { return hash(session); }
    static String account() {
        String id = prefs.getString("installation", "");
        if (id.isEmpty()) {
            id = UUID.randomUUID().toString();
            if (!prefs.edit().putString("installation", id).commit()) throw new IllegalStateException("설치 ID 저장 실패");
        }
        return hash(id);
    }
    static String hash(String value) {
        try {
            byte[] digest = MessageDigest.getInstance("SHA-256").digest(value.getBytes(StandardCharsets.UTF_8));
            StringBuilder out = new StringBuilder();
            for (byte b : digest) out.append(String.format(Locale.ROOT, "%02x", b & 255));
            return out.toString();
        } catch (Exception e) { throw new IllegalStateException(e); }
    }
    static void sheetOpened() {
        handler.removeCallbacks(launchTimeout);
        // A bounded fallback if the Play Activity never returns a lifecycle/result callback.
        handler.postDelayed(launchTimeout, 10 * 60 * 1000);
        OverlayService.setPaymentHidden(true);
    }
    static void cancel(String status) {
        handler.removeCallbacks(launchTimeout);
        // Restore natively; do not depend on a paused Dart frame or network callback.
        OverlayService.setPaymentHidden(false);
        MethodChannel.Result result = pending;
        pending = null; requestedSession = null;
        if (result != null) {
            try { result.success(status); } catch (Exception detachedEngine) { /* Journal remains durable. */ }
        }
        BillingHostActivity activity = host;
        host = null;
        if (activity != null) activity.finish();
    }
    static void recordOutcome(String session, String outcome) throws Exception {
        JSONObject outcomes = json("outcomes"); outcomes.put(session, outcome);
        SharedPreferences.Editor editor = prefs.edit().putString("outcomes", outcomes.toString());
        if (session.equals(currentSession())) editor.putString("active", "{}");
        if (!editor.commit()) throw new IllegalStateException("완료 기록 저장 실패");
    }
    static boolean useRecoveredCredit(String session) {
        if (!isRequestActive(session) || prefs.getInt("credits", 0) <= 0) return false;
        try {
            grantCredit(session); cancel("purchased"); closeOverlay();
        } catch (Exception error) { cancel("error"); }
        return true;
    }
    private static void grantCredit(String session) throws Exception {
        JSONObject outcomes = json("outcomes"); outcomes.put(session, "paid");
        if (!prefs.edit().putString("outcomes", outcomes.toString()).putString("active", "{}")
                .putInt("credits", prefs.getInt("credits", 0) - 1).commit())
            throw new IllegalStateException("결제 적용 저장 실패");
    }
    static void closeOverlay() { context.stopService(new Intent(context, OverlayService.class)); }

    private static void recoverPurchases() {
        if (recovering || pending != null || prefs.getString("public_key", "").isEmpty()) return;
        recovering = true;
        BillingClient client = BillingClient.newBuilder(context).setListener((result, purchases) -> {})
            .enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build()).build();
        Runnable cleanup = () -> { client.endConnection(); recovering = false; };
        handler.postDelayed(cleanup, 30000);
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(BillingResult result) {
                handler.post(() -> {
                    if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) {
                        handler.removeCallbacks(cleanup); cleanup.run(); return;
                    }
                    client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
                        (query, purchases) -> handler.post(() -> {
                            if (query.getResponseCode() == BillingClient.BillingResponseCode.OK)
                                for (Purchase purchase : purchases) processPurchase(client, purchase);
                            handler.removeCallbacks(cleanup); handler.postDelayed(cleanup, 5000);
                        }));
                });
            }
            @Override public void onBillingServiceDisconnected() {
                handler.post(() -> { handler.removeCallbacks(cleanup); cleanup.run(); });
            }
        });
    }

    /** Verify before granting; commit before consume. Replayed tokens never grant twice. */
    static boolean processPurchase(BillingClient client, Purchase purchase) {
        try {
            if (purchase.getPurchaseState() != Purchase.PurchaseState.PURCHASED) return false;
            String key = prefs.getString("public_key", "");
            if (!PurchaseSignature.verify(Base64.decode(key, Base64.DEFAULT),
                    purchase.getOriginalJson().getBytes(StandardCharsets.UTF_8),
                    Base64.decode(purchase.getSignature(), Base64.DEFAULT))) return false;
            JSONObject receipt = new JSONObject(purchase.getOriginalJson());
            if (!context.getPackageName().equals(receipt.optString("packageName"))) return false;
            AccountIdentifiers ids = purchase.getAccountIdentifiers();
            if (ids == null || ids.getObfuscatedProfileId() == null) return false;
            JSONObject request = json("request_" + ids.getObfuscatedProfileId());
            String session = request.optString("session");
            if (session.isEmpty() || !purchase.getProducts().contains(request.optString("product"))) return false;
            String deliveredKey = "delivered_" + hash(purchase.getPurchaseToken());
            if (!prefs.getBoolean(deliveredKey, false)) {
                if (session.equals(currentSession()) && System.currentTimeMillis() >= json("active").optLong("endTime")) {
                    recordOutcome(session, "completed"); cancel("completed"); closeOverlay();
                }
                boolean applies = session.equals(currentSession());
                SharedPreferences.Editor editor = prefs.edit().putBoolean(deliveredKey, true);
                if (applies) {
                    JSONObject outcomes = json("outcomes"); outcomes.put(session, "paid");
                    editor.putString("outcomes", outcomes.toString()).putString("active", "{}");
                } else {
                    // If the timer ended before delayed payment, preserve one future unlock.
                    editor.putInt("credits", prefs.getInt("credits", 0) + 1);
                }
                if (!editor.commit()) return false;
                if (applies) {
                    cancel("purchased"); closeOverlay();
                }
            }
            client.consumeAsync(ConsumeParams.newBuilder().setPurchaseToken(purchase.getPurchaseToken()).build(),
                (result, token) -> { /* Unconsumed purchases are retried on the next query. */ });
            return true;
        } catch (Exception e) { return false; }
    }
}
