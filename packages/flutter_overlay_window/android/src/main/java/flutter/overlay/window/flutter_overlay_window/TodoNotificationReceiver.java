package flutter.overlay.window.flutter_overlay_window;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

public class TodoNotificationReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        try { TodoNotifications.refresh(context); }
        catch (Exception e) { Log.e("TodoNotifications", "Could not refresh notifications", e); }
    }
}
