package flutter.overlay.window.flutter_overlay_window;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Context;
import android.content.Intent;
import android.content.SharedPreferences;
import android.os.Build;
import android.service.notification.StatusBarNotification;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;
import org.json.JSONArray;
import org.json.JSONException;
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.Comparator;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;

final class TodoNotifications {
    static final String DAILY = "todo_daily_jobs";
    static final String RUNNING = "todo_running_jobs";
    static final String LOCK_SERVICE = "todo_lock_service";
    static final String DATE_EXTRA = "todolock_date";
    static final String DAY_ACTION = "todolock.REFRESH_DAY";
    static final String FINISH_ACTION = "todolock.REFRESH_RUNNING";
    private static final String DAILY_TAG = "todo-daily";
    private static final String RUNNING_TAG = "todo-running:";

    static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences("todolock_notifications", Context.MODE_PRIVATE);
    }

    static void createChannels(Context context) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        NotificationChannel daily = new NotificationChannel(DAILY, "오늘의 할 일", NotificationManager.IMPORTANCE_LOW);
        daily.setDescription("오늘의 할 일을 앱에 정렬된 순서대로 계속 표시합니다.");
        manager.createNotificationChannel(daily);
        NotificationChannel running = new NotificationChannel(RUNNING, "진행 중인 타이머", NotificationManager.IMPORTANCE_LOW);
        running.setDescription("실행 중인 할 일의 남은 시간을 별도로 표시합니다.");
        manager.createNotificationChannel(running);
        NotificationChannel lock = new NotificationChannel(LOCK_SERVICE, "화면 잠금 서비스", NotificationManager.IMPORTANCE_LOW);
        lock.setDescription("화면 잠금이 실행 중임을 알리는 필수 서비스 알림입니다.");
        manager.createNotificationChannel(lock);
    }

    static boolean allowed(Context context, String channel) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) return false;
        if (Build.VERSION.SDK_INT < 26) return true;
        NotificationChannel value = context.getSystemService(NotificationManager.class).getNotificationChannel(channel);
        return value == null || value.getImportance() != NotificationManager.IMPORTANCE_NONE;
    }

    static boolean exactAllowed(Context context) {
        return Build.VERSION.SDK_INT < 31 || context.getSystemService(AlarmManager.class).canScheduleExactAlarms();
    }

    static Map<String, Object> status(Context context) {
        createChannels(context);
        Map<String, Object> result = new HashMap<>();
        result.put("allowed", NotificationManagerCompat.from(context).areNotificationsEnabled());
        result.put("dailyAllowed", allowed(context, DAILY));
        result.put("runningAllowed", allowed(context, RUNNING));
        result.put("exactAllowed", exactAllowed(context));
        return result;
    }

    static synchronized void synchronize(Context context, List<Map<String, Object>> todos,
                                         boolean dailyEnabled, boolean runningEnabled) throws JSONException {
        JSONArray snapshot = new JSONArray();
        for (Map<String, Object> map : todos) snapshot.put(new JSONObject(map));
        // The native snapshot lets date-change receivers work without a Flutter engine.
        if (!prefs(context).edit().putString("todos", snapshot.toString())
                .putBoolean("dailyEnabled", dailyEnabled).putBoolean("runningEnabled", runningEnabled)
                .remove("eligible").remove("delivered").remove("enabled").remove("minute").commit()) {
            throw new IllegalStateException("Could not save notifications");
        }
        refresh(context);
    }

    static boolean hasNotificationWork(Context context) throws JSONException {
        SharedPreferences p = prefs(context);
        if (p.getBoolean("dailyEnabled", p.getBoolean("enabled", true))) return true;
        if (!p.getBoolean("runningEnabled", true)) return false;
        JSONArray todos = new JSONArray(p.getString("todos", "[]"));
        for (int i = 0; i < todos.length(); i++) {
            JSONObject todo = todos.getJSONObject(i);
            if (!todo.optBoolean("done") && todo.optLong("endTime") > System.currentTimeMillis()) return true;
        }
        return false;
    }

    static synchronized void refresh(Context context) throws JSONException {
        createChannels(context);
        SharedPreferences p = prefs(context);
        JSONArray snapshot = new JSONArray(p.getString("todos", "[]"));
        List<JSONObject> todos = new ArrayList<>();
        for (int i = 0; i < snapshot.length(); i++) todos.add(snapshot.getJSONObject(i));
        // Stable sort also preserves the stored order for old snapshots without an order field.
        todos.sort(Comparator.comparingInt(todo -> todo.optInt("order")));
        long now = System.currentTimeMillis();
        TimeZone zone = TimeZone.getDefault();
        String today = TodoNotificationPlan.day(now, zone);
        long midnight = TodoNotificationPlan.nextMidnight(now, zone);
        boolean dailyEnabled = p.getBoolean("dailyEnabled", p.getBoolean("enabled", true));
        boolean runningEnabled = p.getBoolean("runningEnabled", true);
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        Set<String> keep = new HashSet<>();
        List<String> lines = new ArrayList<>();
        long nextFinish = Long.MAX_VALUE;
        for (JSONObject todo : todos) {
            String id = todo.getString("id");
            String date = todo.getString("date");
            String content = todo.optString("content");
            long end = todo.optLong("endTime");
            boolean done = todo.optBoolean("done") || (end > 0 && end <= now);
            if (dailyEnabled && today.equals(date)) {
                lines.add((lines.size() + 1) + ". " + content);
            }
            if (!done && end > now) {
                if (dailyEnabled || runningEnabled) nextFinish = Math.min(nextFinish, end);
                // The lock foreground service owns its timer, avoiding duplicates.
                if (runningEnabled && !todo.optBoolean("lock")) {
                    String tag = RUNNING_TAG + id;
                    post(context, tag, RUNNING, runningNotification(context, content, date, end));
                    keep.add(tag);
                }
            }
        }
        if (dailyEnabled) {
            String title = "오늘의 할 일 " + lines.size() + "개";
            String body = lines.isEmpty() ? "오늘 등록된 할 일이 없습니다." : android.text.TextUtils.join("\n", lines);
            Notification notification = new NotificationCompat.Builder(context, DAILY)
                    .setSmallIcon(R.drawable.notification_icon).setContentTitle(title)
                    .setContentText(lines.isEmpty() ? body : lines.get(0))
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(body))
                    .setSubText(today).setShowWhen(false)
                    .setContentIntent(openDate(context, today)).setOngoing(true).setAutoCancel(false)
                    .setOnlyAlertOnce(true).setSilent(true)
                    // If Android delays background work, never leave yesterday's list visible.
                    .setTimeoutAfter(Math.max(1, midnight - now))
                    .setCategory(NotificationCompat.CATEGORY_STATUS)
                    .setPriority(NotificationCompat.PRIORITY_LOW)
                    .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build();
            post(context, DAILY_TAG, DAILY, notification);
            keep.add(DAILY_TAG);
        }
        for (StatusBarNotification notification : manager.getActiveNotifications()) {
            String tag = notification.getTag();
            if (tag != null && (tag.equals(DAILY_TAG) || tag.startsWith("todo-morning:")
                    || tag.startsWith(RUNNING_TAG)) && !keep.contains(tag)) manager.cancel(tag, 1);
        }
        // Remove old 09:00 alarms and their obsolete notification channel on upgrade.
        schedule(context, "todolock.REMINDER", Long.MAX_VALUE);
        if (Build.VERSION.SDK_INT >= 26) manager.deleteNotificationChannel("todo_morning_reminders");
        schedule(context, DAY_ACTION, dailyEnabled ? midnight : Long.MAX_VALUE);
        schedule(context, FINISH_ACTION, nextFinish);
        OverlayService.refreshNotification();
    }

    private static void post(Context context, String tag, String channel, Notification notification) {
        if (!allowed(context, channel)) return;
        try { context.getSystemService(NotificationManager.class).notify(tag, 1, notification); }
        catch (SecurityException denied) { /* System permission may be revoked between checks. */ }
    }

    static PendingIntent openDate(Context context, String date) {
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent == null) return null;
        intent.setAction("todolock.OPEN." + date);
        intent.putExtra(DATE_EXTRA, date);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(context, date.hashCode(), intent, PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static Notification runningNotification(Context context, String content, String date, long end) {
        createChannels(context);
        return new NotificationCompat.Builder(context, RUNNING)
                .setSmallIcon(R.drawable.notification_icon).setContentTitle(content)
                .setContentText("집중 중 · 남은 시간").setSubText("진행 중인 타이머")
                .setWhen(end).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
                .setTimeoutAfter(Math.max(1, end - System.currentTimeMillis()))
                .setContentIntent(openDate(context, date)).setOngoing(true).setOnlyAlertOnce(true)
                .setSilent(true).setCategory(NotificationCompat.CATEGORY_PROGRESS)
                .setPriority(NotificationCompat.PRIORITY_LOW).setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build();
    }

    static Notification lockServiceNotification(Context context, JSONObject active) {
        createChannels(context);
        String date = active.optString("date", TodoNotificationPlan.day(System.currentTimeMillis(), TimeZone.getDefault()));
        if (prefs(context).getBoolean("runningEnabled", true)) {
            return runningNotification(context, active.optString("contents", "TODOnLOCK 집중 중"),
                    date, active.optLong("endTime", System.currentTimeMillis() + 1000));
        }
        // Android requires a foreground-service notification even with the optional timer off.
        return new NotificationCompat.Builder(context, LOCK_SERVICE)
                .setSmallIcon(R.drawable.notification_icon).setContentTitle("화면 잠금 실행 중")
                .setContentText("설정한 시간이 끝날 때까지 잠금이 유지됩니다.")
                .setContentIntent(openDate(context, date)).setOngoing(true).setOnlyAlertOnce(true)
                .setShowWhen(false).setSilent(true).setPriority(NotificationCompat.PRIORITY_LOW)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build();
    }

    private static void schedule(Context context, String action, long at) {
        AlarmManager manager = context.getSystemService(AlarmManager.class);
        PendingIntent pending = PendingIntent.getBroadcast(context, 0,
                new Intent(context, TodoNotificationReceiver.class).setAction(action),
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        manager.cancel(pending);
        if (at == Long.MAX_VALUE) { pending.cancel(); return; }
        if (exactAllowed(context)) {
            try { manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending); return; }
            catch (SecurityException revoked) { /* Permission may change after the check. */ }
        }
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, at, pending);
    }
}
