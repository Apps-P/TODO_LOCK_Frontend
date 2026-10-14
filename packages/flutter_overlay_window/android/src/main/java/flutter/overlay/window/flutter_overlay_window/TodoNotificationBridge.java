package flutter.overlay.window.flutter_overlay_window;

import android.Manifest;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import android.util.Log;
import androidx.core.content.ContextCompat;
import java.util.List;
import java.util.Map;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

final class TodoNotificationBridge implements MethodChannel.MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener, PluginRegistry.NewIntentListener {
    private static final int REQUEST = 7321;
    private final Context context;
    private final MethodChannel channel;
    private ActivityPluginBinding binding;
    private MethodChannel.Result pending;
    private boolean requesting;

    TodoNotificationBridge(Context context, BinaryMessenger messenger) {
        this.context = context;
        channel = new MethodChannel(messenger, "todolock/notifications");
        channel.setMethodCallHandler(this);
    }

    void attach(ActivityPluginBinding value) {
        detach();
        binding = value;
        binding.addRequestPermissionsResultListener(this);
        binding.addOnNewIntentListener(this);
    }

    void detach() {
        if (binding != null) {
            binding.removeRequestPermissionsResultListener(this);
            binding.removeOnNewIntentListener(this);
        }
        binding = null;
        requesting = false;
        if (pending != null) { pending.success(TodoNotifications.status(context)); pending = null; }
    }

    void dispose() { detach(); channel.setMethodCallHandler(null); }

    @Override public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "sync":
                    List<Map<String, Object>> todos = call.argument("todos");
                    Boolean dailyEnabled = call.argument("dailyEnabled");
                    Boolean runningEnabled = call.argument("runningEnabled");
                    TodoNotifications.synchronize(context, todos,
                            Boolean.TRUE.equals(dailyEnabled), Boolean.TRUE.equals(runningEnabled));
                    result.success(null);
                    try {
                        if (!TodoNotifications.prefs(context).getBoolean("permissionRequested", false)
                                && TodoNotifications.hasNotificationWork(context)) requestPermission(null);
                    } catch (Exception e) { Log.w("TodoNotifications", "Permission prompt unavailable", e); }
                    return;
                case "status": result.success(TodoNotifications.status(context)); return;
                case "requestPermission": requestPermission(result); return;
                case "consumeLaunchDate":
                    result.success(binding == null ? null : consume(binding.getActivity().getIntent())); return;
                case "openNotificationSettings":
                    Intent settings = Build.VERSION.SDK_INT >= 26
                            ? new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName())
                            : new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + context.getPackageName()));
                    context.startActivity(settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                    result.success(null); return;
                case "openExactAlarmSettings":
                    if (Build.VERSION.SDK_INT >= 31 && !TodoNotifications.exactAllowed(context))
                        context.startActivity(new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:" + context.getPackageName())).addFlags(Intent.FLAG_ACTIVITY_NEW_TASK));
                    result.success(null); return;
                default: result.notImplemented();
            }
        } catch (Exception e) { result.error("NOTIFICATIONS", e.getMessage(), null); }
    }

    private void requestPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT < 33 || binding == null || requesting ||
                ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED) {
            if (result != null) result.success(TodoNotifications.status(context));
            return;
        }
        pending = result;
        requesting = true;
        try {
            binding.getActivity().requestPermissions(new String[]{Manifest.permission.POST_NOTIFICATIONS}, REQUEST);
            TodoNotifications.prefs(context).edit().putBoolean("permissionRequested", true).apply();
        } catch (RuntimeException e) { pending = null; requesting = false; throw e; }
    }

    @Override public boolean onRequestPermissionsResult(int code, String[] permissions, int[] results) {
        if (code != REQUEST) return false;
        requesting = false;
        try { TodoNotifications.refresh(context); }
        catch (Exception e) { Log.w("TodoNotifications", "Refresh after permission failed", e); }
        if (pending != null) { pending.success(TodoNotifications.status(context)); pending = null; }
        return true;
    }

    private String consume(Intent intent) {
        if (intent == null) return null;
        String date = intent.getStringExtra(TodoNotifications.DATE_EXTRA);
        intent.removeExtra(TodoNotifications.DATE_EXTRA);
        return date;
    }

    @Override public boolean onNewIntent(Intent intent) {
        String date = consume(intent);
        if (date == null) return false;
        channel.invokeMethod("openDate", date);
        return true;
    }
}
