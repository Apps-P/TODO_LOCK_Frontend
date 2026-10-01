package flutter.overlay.window.flutter_overlay_window;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.net.Uri;
import android.os.Build;
import android.provider.Settings;
import androidx.core.app.ActivityCompat;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.BinaryMessenger;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;
import java.util.List;
import java.util.Map;

final class TodoNotificationBridge implements MethodChannel.MethodCallHandler,
        PluginRegistry.RequestPermissionsResultListener, PluginRegistry.NewIntentListener {
    private static final int PERMISSION_REQUEST = 7321;
    private final Context context;
    private final MethodChannel channel;
    private ActivityPluginBinding binding;
    private MethodChannel.Result permissionResult;

    TodoNotificationBridge(Context context, BinaryMessenger messenger) {
        this.context = context;
        channel = new MethodChannel(messenger, "todolock/notifications");
        channel.setMethodCallHandler(this);
    }

    void attach(ActivityPluginBinding value) {
        detach();
        binding = value;
        value.addRequestPermissionsResultListener(this);
        value.addOnNewIntentListener(this);
    }

    void detach() {
        if (binding != null) {
            binding.removeRequestPermissionsResultListener(this);
            binding.removeOnNewIntentListener(this);
            binding = null;
        }
        if (permissionResult != null) {
            permissionResult.success(TodoNotifications.status(context));
            permissionResult = null;
        }
    }

    void dispose() { detach(); channel.setMethodCallHandler(null); }

    @Override @SuppressWarnings("unchecked")
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        try {
            switch (call.method) {
                case "sync":
                    List<Map<String, Object>> todos = call.argument("todos");
                    Boolean enabled = call.argument("enabled");
                    Number minutes = call.argument("minuteOfDay");
                    if (todos == null || enabled == null || minutes == null) throw new IllegalArgumentException("Missing notification data");
                    TodoNotifications.synchronize(context, todos, enabled, minutes.intValue());
                    result.success(null);
                    if (TodoNotifications.hasNotificationWork(context)
                            && !TodoNotifications.prefs(context).getBoolean("permissionRequested", false)) {
                        requestPermission(null);
                    }
                    break;
                case "status": result.success(TodoNotifications.status(context)); break;
                case "requestPermission": requestPermission(result); break;
                case "openNotificationSettings":
                    Intent settings = Build.VERSION.SDK_INT >= 26
                            ? new Intent(Settings.ACTION_APP_NOTIFICATION_SETTINGS).putExtra(Settings.EXTRA_APP_PACKAGE, context.getPackageName())
                            : new Intent(Settings.ACTION_APPLICATION_DETAILS_SETTINGS, Uri.parse("package:" + context.getPackageName()));
                    settings.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                    context.startActivity(settings);
                    result.success(null); break;
                case "openExactAlarmSettings":
                    if (Build.VERSION.SDK_INT >= 31 && !TodoNotifications.exactAllowed(context)) {
                        Intent exact = new Intent(Settings.ACTION_REQUEST_SCHEDULE_EXACT_ALARM,
                                Uri.parse("package:" + context.getPackageName()));
                        exact.addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
                        context.startActivity(exact);
                    }
                    result.success(null); break;
                case "consumeLaunchDate":
                    result.success(binding == null ? null : consumeDate(binding.getActivity().getIntent())); break;
                default: result.notImplemented();
            }
        } catch (Exception error) {
            result.error("NOTIFICATION_ERROR", error.getMessage(), null);
        }
    }

    private void requestPermission(MethodChannel.Result result) {
        if (Build.VERSION.SDK_INT < 33 || context.checkSelfPermission(Manifest.permission.POST_NOTIFICATIONS) == PackageManager.PERMISSION_GRANTED
                || binding == null) {
            if (result != null) result.success(TodoNotifications.status(context));
            return;
        }
        if (permissionResult != null) {
            if (result != null) result.success(TodoNotifications.status(context));
            return;
        }
        TodoNotifications.prefs(context).edit().putBoolean("permissionRequested", true).apply();
        permissionResult = result;
        ActivityCompat.requestPermissions(binding.getActivity(), new String[]{Manifest.permission.POST_NOTIFICATIONS}, PERMISSION_REQUEST);
    }

    @Override public boolean onRequestPermissionsResult(int code, String[] permissions, int[] grants) {
        if (code != PERMISSION_REQUEST) return false;
        try { TodoNotifications.refresh(context); } catch (Exception ignored) { }
        MethodChannel.Result result = permissionResult;
        permissionResult = null;
        if (result != null) result.success(TodoNotifications.status(context));
        return true;
    }

    private String consumeDate(Intent intent) {
        if (intent == null) return null;
        String date = intent.getStringExtra(TodoNotifications.DATE_EXTRA);
        intent.removeExtra(TodoNotifications.DATE_EXTRA);
        return date;
    }

    @Override public boolean onNewIntent(Intent intent) {
        String date = consumeDate(intent);
        if (date == null) return false;
        channel.invokeMethod("openDate", date);
        return true;
    }
}
