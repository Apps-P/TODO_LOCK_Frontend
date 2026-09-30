package flutter.overlay.window.flutter_overlay_window;

import android.content.BroadcastReceiver;
import android.content.Context;
import android.content.Intent;
import android.util.Log;

/** Alarms and reboot recovery work without starting a Flutter engine. */
public final class TodoNotificationReceiver extends BroadcastReceiver {
    @Override public void onReceive(Context context, Intent intent) {
        try {
            TodoNotifications.refresh(context);
        } catch (Exception error) {
            Log.e("TodoNotifications", "Could not restore notifications", error);
        }
    }
}
