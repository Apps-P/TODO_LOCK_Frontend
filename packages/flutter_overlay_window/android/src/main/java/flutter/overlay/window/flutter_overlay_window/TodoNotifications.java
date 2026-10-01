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
import org.json.JSONObject;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.HashSet;
import java.util.List;
import java.util.Map;
import java.util.Set;
import java.util.TimeZone;
import java.util.TreeMap;

/** Durable, local-only mirror. Hive remains the authority for job data. */
final class TodoNotifications {
    static final String PREFS = "todolock_notifications";
    static final String REMINDERS = "todo_morning_reminders";
    static final String RUNNING = "todo_running_jobs";
    static final String DATE_EXTRA = "todolock_date";
    static final String REMINDER_ACTION = "todolock.REMINDER";
    static final String FINISH_ACTION = "todolock.REFRESH_RUNNING";
    private static final String MORNING_TAG = "todo-morning:";
    private static final String RUNNING_TAG = "todo-running:";
    private static final int ID = 1;

    static SharedPreferences prefs(Context context) {
        return context.getSharedPreferences(PREFS, Context.MODE_PRIVATE);
    }

    static void createChannels(Context context) {
        if (Build.VERSION.SDK_INT < 26) return;
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        NotificationChannel morning = new NotificationChannel(REMINDERS, "예정된 할 일", NotificationManager.IMPORTANCE_DEFAULT);
        morning.setDescription("미리 추가한 할 일을 해당 날짜의 설정한 시간에 알려줍니다.");
        manager.createNotificationChannel(morning);
        NotificationChannel running = new NotificationChannel(RUNNING, "진행 중인 할 일", NotificationManager.IMPORTANCE_LOW);
        running.setDescription("현재 집중 중인 할 일과 남은 시간");
        manager.createNotificationChannel(running);
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
        Map<String, Object> status = new HashMap<>();
        status.put("allowed", NotificationManagerCompat.from(context).areNotificationsEnabled());
        status.put("remindersAllowed", allowed(context, REMINDERS));
        status.put("runningAllowed", allowed(context, RUNNING));
        status.put("exactAllowed", exactAllowed(context));
        return status;
    }

    static synchronized void synchronize(Context context, List<Map<String, Object>> todos,
                                         boolean enabled, int minuteOfDay) throws Exception {
        if (minuteOfDay < 0 || minuteOfDay >= 1440) throw new IllegalArgumentException("Invalid reminder time");
        SharedPreferences prefs = prefs(context);
        JSONObject previous = new JSONObject(prefs.getString("eligible", "{}"));
        JSONObject eligible = new JSONObject();
        String today = TodoNotificationPlan.day(System.currentTimeMillis(), TimeZone.getDefault());
        JSONArray snapshot = new JSONArray();
        for (Map<String, Object> item : todos) {
            JSONObject todo = new JSONObject(item);
            String id = todo.getString("id");
            String date = todo.getString("date");
            TodoNotificationPlan.atTime(date, minuteOfDay, TimeZone.getDefault());
            if (TodoNotificationPlan.eligible(date, previous.optString(id), today,
                    todo.optBoolean("done"), todo.optLong("endTime") > 0)) {
                eligible.put(id, date);
            }
            snapshot.put(todo);
        }
        if (!prefs.edit().putString("todos", snapshot.toString())
                .putString("eligible", eligible.toString()).putBoolean("enabled", enabled)
                .putInt("minuteOfDay", minuteOfDay).commit()) {
            throw new IllegalStateException("알림 예약을 저장하지 못했습니다.");
        }
        refresh(context);
    }

    static boolean hasNotificationWork(Context context) {
        SharedPreferences prefs = prefs(context);
        try {
            if (prefs.getBoolean("enabled", true) && new JSONObject(prefs.getString("eligible", "{}")).length() > 0) return true;
            JSONArray todos = new JSONArray(prefs.getString("todos", "[]"));
            for (int i = 0; i < todos.length(); i++) {
                JSONObject todo = todos.getJSONObject(i);
                if (!todo.optBoolean("done") && todo.optLong("endTime") > System.currentTimeMillis()) return true;
            }
        } catch (Exception ignored) { }
        return false;
    }

    static synchronized void refresh(Context context) throws Exception {
        createChannels(context);
        SharedPreferences prefs = prefs(context);
        long now = System.currentTimeMillis();
        TimeZone zone = TimeZone.getDefault();
        String today = TodoNotificationPlan.day(now, zone);
        JSONArray todos = new JSONArray(prefs.getString("todos", "[]"));
        JSONObject eligible = new JSONObject(prefs.getString("eligible", "{}"));
        Set<String> delivered = new HashSet<>(prefs.getStringSet("delivered", new HashSet<>()));
        delivered.removeIf(date -> date.compareTo(today) < 0);
        Map<String, List<String>> groups = new TreeMap<>();
        Set<String> keep = new HashSet<>();
        Set<String> active = activeTags(context);
        long nextReminder = Long.MAX_VALUE;
        long nextFinish = Long.MAX_VALUE;
        boolean enabled = prefs.getBoolean("enabled", true);
        int minute = prefs.getInt("minuteOfDay", 540);
        for (int i = 0; i < todos.length(); i++) {
            JSONObject todo = todos.getJSONObject(i);
            String id = todo.getString("id");
            String date = todo.getString("date");
            String content = todo.getString("content");
            if (todo.optBoolean("done")) continue;
            long end = todo.optLong("endTime");
            if (end > now) {
                // Locked jobs already have their foreground-service notification.
                if (!todo.optBoolean("lock")) {
                    String tag = RUNNING_TAG + id;
                    keep.add(tag);
                    post(context, tag, runningNotification(context, content, date, end));
                    nextFinish = Math.min(nextFinish, end);
                }
            } else if (end == 0 && enabled && date.equals(eligible.optString(id)) && date.compareTo(today) >= 0) {
                List<String> contents = groups.get(date);
                if (contents == null) { contents = new ArrayList<>(); groups.put(date, contents); }
                contents.add(content);
            }
        }
        for (Map.Entry<String, List<String>> entry : groups.entrySet()) {
            String date = entry.getKey();
            long when = TodoNotificationPlan.atTime(date, minute, zone);
            String tag = MORNING_TAG + date;
            if (when <= now && date.equals(today)) {
                // Never re-alert after a tap/dismissal, resume, time change or reboot.
                if (!delivered.contains(date) || active.contains(tag)) {
                    if (post(context, tag, reminderNotification(context, date, entry.getValue()))) delivered.add(date);
                }
                keep.add(tag);
            } else if (when > now && !delivered.contains(date)) {
                nextReminder = Math.min(nextReminder, when);
            }
        }
        NotificationManager manager = context.getSystemService(NotificationManager.class);
        for (String tag : active) {
            if ((tag.startsWith(MORNING_TAG) || tag.startsWith(RUNNING_TAG)) && !keep.contains(tag)) manager.cancel(tag, ID);
        }
        if (!prefs.edit().putStringSet("delivered", delivered).commit()) throw new IllegalStateException("알림 기록 저장 실패");
        schedule(context, REMINDER_ACTION, nextReminder);
        schedule(context, FINISH_ACTION, nextFinish);
    }

    static Set<String> activeTags(Context context) {
        Set<String> tags = new HashSet<>();
        for (StatusBarNotification item : context.getSystemService(NotificationManager.class).getActiveNotifications()) {
            if (item.getTag() != null) tags.add(item.getTag());
        }
        return tags;
    }

    private static boolean post(Context context, String tag, Notification notification) {
        String channel = tag.startsWith(MORNING_TAG) ? REMINDERS : RUNNING;
        if (!allowed(context, channel)) return false;
        try {
            context.getSystemService(NotificationManager.class).notify(tag, ID, notification);
            return true;
        } catch (SecurityException denied) { return false; }
    }

    static PendingIntent openDate(Context context, String date) {
        Intent intent = context.getPackageManager().getLaunchIntentForPackage(context.getPackageName());
        if (intent == null) return null;
        intent.setAction("todolock.OPEN." + date);
        intent.putExtra(DATE_EXTRA, date);
        intent.addFlags(Intent.FLAG_ACTIVITY_CLEAR_TOP | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        return PendingIntent.getActivity(context, date.hashCode(), intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
    }

    static Notification runningNotification(Context context, String content, String date, long endTime) {
        createChannels(context);
        return new NotificationCompat.Builder(context, RUNNING)
                .setSmallIcon(R.drawable.notification_icon)
                .setContentTitle(content).setContentText("집중 중 · 남은 시간")
                .setSubText("진행 중인 할 일")
                .setWhen(endTime).setShowWhen(true).setUsesChronometer(true).setChronometerCountDown(true)
                .setTimeoutAfter(Math.max(1, endTime - System.currentTimeMillis()))
                .setContentIntent(openDate(context, date))
                .setOngoing(true).setOnlyAlertOnce(true).setSilent(true)
                .setCategory(NotificationCompat.CATEGORY_PROGRESS).setPriority(NotificationCompat.PRIORITY_LOW)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build();
    }

    private static Notification reminderNotification(Context context, String date, List<String> contents) {
        NotificationCompat.InboxStyle style = new NotificationCompat.InboxStyle();
        for (String content : contents) style.addLine(content);
        return new NotificationCompat.Builder(context, REMINDERS)
                .setSmallIcon(R.drawable.notification_icon)
                .setContentTitle("오늘 예정된 할 일 " + contents.size() + "개")
                .setContentText(contents.get(0)).setStyle(style)
                .setContentIntent(openDate(context, date)).setAutoCancel(true)
                .setOnlyAlertOnce(true).setCategory(NotificationCompat.CATEGORY_REMINDER)
                .setVisibility(NotificationCompat.VISIBILITY_PRIVATE).build();
    }

    private static void schedule(Context context, String action, long when) {
        AlarmManager manager = context.getSystemService(AlarmManager.class);
        Intent intent = new Intent(context, TodoNotificationReceiver.class).setAction(action);
        PendingIntent pending = PendingIntent.getBroadcast(context, 0, intent,
                PendingIntent.FLAG_UPDATE_CURRENT | PendingIntent.FLAG_IMMUTABLE);
        manager.cancel(pending);
        if (when == Long.MAX_VALUE) return;
        if (exactAllowed(context)) {
            try {
                manager.setExactAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pending);
                return;
            } catch (SecurityException permissionChanged) { /* Permission may be revoked between calls. */ }
        }
        manager.setAndAllowWhileIdle(AlarmManager.RTC_WAKEUP, when, pending);
    }
}
