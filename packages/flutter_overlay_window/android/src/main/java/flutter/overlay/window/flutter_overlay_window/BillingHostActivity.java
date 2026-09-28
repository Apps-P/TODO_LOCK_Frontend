package flutter.overlay.window.flutter_overlay_window;

import android.app.Activity;
import android.app.Application;
import android.os.Bundle;
import android.graphics.Color;
import android.view.WindowManager;
import android.widget.TextView;
import android.view.Gravity;
import com.android.billingclient.api.*;
import java.util.Collections;
import java.util.List;

/** Only this non-exported host may temporarily hide the overlay for Play UI.
 * An opaque host remains behind the Play sheet; stopping the host OR proxy
 * restores the overlay even if Play never sends a purchase callback.
 */
public final class BillingHostActivity extends Activity implements Application.ActivityLifecycleCallbacks {
    private BillingClient client;
    private String session;
    private String product;
    private boolean launched;
    private boolean pausedForSheet;
    private boolean stopped;
    private final PaymentVisibilityState visibility = new PaymentVisibilityState();

    @Override public void onCreate(Bundle state) {
        super.onCreate(state);
        LockBillingBridge.init(this);
        session = getIntent().getStringExtra("session");
        product = getIntent().getStringExtra("product");
        if (!LockBillingBridge.isRequestActive(session)) { finish(); return; }
        LockBillingBridge.attach(this);
        getApplication().registerActivityLifecycleCallbacks(this);
        getWindow().addFlags(WindowManager.LayoutParams.FLAG_SECURE);
        TextView text = new TextView(this);
        text.setText("Google Play 결제 확인 중…\n결제를 취소하면 잠금이 유지됩니다.");
        text.setTextColor(Color.BLACK); text.setBackgroundColor(0xFFF2F0EF);
        text.setGravity(Gravity.CENTER); text.setTextSize(20); setContentView(text);
        client = BillingClient.newBuilder(this).setListener((result, purchases) -> runOnUiThread(() -> {
            OverlayService.setPaymentHidden(false);
            if (result.getResponseCode() == BillingClient.BillingResponseCode.OK && purchases != null) {
                boolean verified = false;
                boolean pending = false;
                for (Purchase purchase : purchases) {
                    pending |= purchase.getPurchaseState() == Purchase.PurchaseState.PENDING;
                    verified |= LockBillingBridge.processPurchase(client, purchase);
                }
                if (LockBillingBridge.isRequestActive(session)) cancel(pending ? "pending" : verified ? "credit" : "error");
            } else {
                cancel(result.getResponseCode() == BillingClient.BillingResponseCode.USER_CANCELED ? "canceled" : "error");
            }
        })).enablePendingPurchases(PendingPurchasesParams.newBuilder().enableOneTimeProducts().build())
            .enableAutoServiceReconnection().build();
        client.startConnection(new BillingClientStateListener() {
            @Override public void onBillingSetupFinished(BillingResult result) {
                runOnUiThread(() -> {
                    if (!canLaunch()) return;
                    if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) { cancel("error"); return; }
                    queryOwnedThenProduct();
                });
            }
            @Override public void onBillingServiceDisconnected() { runOnUiThread(() -> cancel("error")); }
        });
    }
    private void cancel(String status) {
        if (LockBillingBridge.isHost(this)) LockBillingBridge.cancel(status);
    }
    private boolean canLaunch() {
        return !stopped && !isFinishing() && LockBillingBridge.isRequestActive(session);
    }
    private void queryOwnedThenProduct() {
        client.queryPurchasesAsync(QueryPurchasesParams.newBuilder().setProductType(BillingClient.ProductType.INAPP).build(),
            (result, purchases) -> runOnUiThread(() -> {
                if (!canLaunch()) return;
                if (result.getResponseCode() != BillingClient.BillingResponseCode.OK) { cancel("error"); return; }
                for (Purchase purchase : purchases) {
                    if (!purchase.getProducts().contains(product)) continue;
                    if (purchase.getPurchaseState() == Purchase.PurchaseState.PENDING) { cancel("pending"); return; }
                    if (!LockBillingBridge.processPurchase(client, purchase)) { cancel("error"); return; }
                }
                if (canLaunch() && !LockBillingBridge.useRecoveredCredit(session)) queryProduct();
            }));
    }
    private void queryProduct() {
        QueryProductDetailsParams.Product item = QueryProductDetailsParams.Product.newBuilder()
            .setProductId(product).setProductType(BillingClient.ProductType.INAPP).build();
        client.queryProductDetailsAsync(QueryProductDetailsParams.newBuilder().setProductList(Collections.singletonList(item)).build(),
            (result, detailsResult) -> runOnUiThread(() -> {
                if (!canLaunch()) return;
                List<ProductDetails> details = detailsResult.getProductDetailsList();
                if (result.getResponseCode() != BillingClient.BillingResponseCode.OK || details.isEmpty()) { cancel("unavailable"); return; }
                ProductDetails detailsItem = details.get(0);
                List<ProductDetails.OneTimePurchaseOfferDetails> offers = detailsItem.getOneTimePurchaseOfferDetailsList();
                if (offers == null || offers.isEmpty()) { cancel("unavailable"); return; }
                BillingFlowParams.ProductDetailsParams line = BillingFlowParams.ProductDetailsParams.newBuilder()
                    .setProductDetails(detailsItem).setOfferToken(offers.get(0).getOfferToken()).build();
                BillingResult launch = client.launchBillingFlow(this, BillingFlowParams.newBuilder()
                    .setProductDetailsParamsList(Collections.singletonList(line))
                    .setObfuscatedAccountId(LockBillingBridge.account())
                    .setObfuscatedProfileId(LockBillingBridge.profile(session)).build());
                if (launch.getResponseCode() == BillingClient.BillingResponseCode.OK) {
                    launched = true; visibility.open(); LockBillingBridge.sheetOpened();
                } else cancel("error");
            }));
    }
    @Override protected void onPause() {
        super.onPause(); if (launched) pausedForSheet = true;
    }
    @Override protected void onResume() {
        super.onResume(); stopped = false;
        if (launched && pausedForSheet) {
            // The host is visible again: payment UI was dismissed. The billing
            // callback may arrive later; it can still journal a verified purchase.
            visibility.restore(); cancel("canceled");
        }
    }
    @Override protected void onStop() {
        stopped = true; visibility.restore();
        cancel("canceled");
        super.onStop();
    }
    @Override public void onBackPressed() { visibility.restore(); cancel("canceled"); }
    @Override protected void onDestroy() {
        if (LockBillingBridge.isHost(this) || !LockBillingBridge.isPaymentOpen()) OverlayService.setPaymentHidden(false);
        getApplication().unregisterActivityLifecycleCallbacks(this);
        LockBillingBridge.detach(this);
        // Keep the client briefly for an in-flight result/consume racing dismissal.
        BillingClient old = client;
        if (old != null) new android.os.Handler(android.os.Looper.getMainLooper()).postDelayed(old::endConnection, 10000);
        super.onDestroy();
    }
    @Override public void onActivityStopped(Activity activity) {
        if (activity.getClass().getName().startsWith("com.android.billingclient.") && visibility.restore())
            cancel("canceled");
    }
    @Override public void onActivityCreated(Activity a, Bundle b) {}
    @Override public void onActivityStarted(Activity a) {}
    @Override public void onActivityResumed(Activity a) {}
    @Override public void onActivityPaused(Activity a) {}
    @Override public void onActivitySaveInstanceState(Activity a, Bundle b) {}
    @Override public void onActivityDestroyed(Activity a) {}
}
