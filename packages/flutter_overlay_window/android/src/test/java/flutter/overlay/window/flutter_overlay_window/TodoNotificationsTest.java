package flutter.overlay.window.flutter_overlay_window;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import android.service.notification.StatusBarNotification;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import java.util.Arrays;
import java.util.Collections;
import java.util.HashMap;
import java.util.Map;
import java.util.TimeZone;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class TodoNotificationsTest {
    Context context;
    AlarmManager alarms;
    NotificationManager manager;
    String today, tomorrow;

    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        alarms = context.getSystemService(AlarmManager.class);
        manager = context.getSystemService(NotificationManager.class);
        shadowOf(alarms).setCanScheduleExactAlarms(true);
        shadowOf(manager).setNotificationsEnabled(true);
        TodoNotifications.prefs(context).edit().clear().commit();
        today = TodoNotificationPlan.day(System.currentTimeMillis(), TimeZone.getDefault());
        tomorrow = TodoNotificationPlan.day(TodoNotificationPlan.nextMidnight(System.currentTimeMillis(), TimeZone.getDefault()), TimeZone.getDefault());
    }

    Map<String, Object> todo(String id, String date, int order, long end, boolean lock) {
        Map<String, Object> value = new HashMap<>();
        value.put("id", id); value.put("date", date); value.put("content", "할 일 " + id);
        value.put("order", order); value.put("endTime", end); value.put("lock", lock); value.put("done", false);
        return value;
    }

    Notification notification(String tag) {
        for (StatusBarNotification value : manager.getActiveNotifications()) {
            if (tag.equals(value.getTag())) return value.getNotification();
        }
        return null;
    }

    @Test public void todaysListIncludesAllStatesInUserOrder() throws Exception {
        Map<String, Object> done = todo("done", today, 1, 0, false); done.put("done", true);
        Map<String, Object> running = todo("running", today, 2, System.currentTimeMillis() + 600000, false);
        TodoNotifications.synchronize(context, Arrays.asList(
                todo("future", tomorrow, 1, 0, false), todo("new", today, 3, 0, false), running, done), true, false);
        assertEquals(1, manager.getActiveNotifications().length);
        Notification daily = notification("todo-daily");
        assertEquals("1. 할 일 done\n2. 할 일 running\n3. 할 일 new",
                daily.extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString());
        assertTrue((daily.flags & Notification.FLAG_ONGOING_EVENT) != 0);
    }

    @Test public void dailyAndRunningSwitchesAreIndependent() throws Exception {
        Map<String, Object> running = todo("a", today, 1, System.currentTimeMillis() + 600000, false);
        TodoNotifications.synchronize(context, Collections.singletonList(running), true, true);
        assertEquals(2, manager.getActiveNotifications().length);
        TodoNotifications.synchronize(context, Collections.singletonList(running), false, true);
        assertNull(notification("todo-daily"));
        assertTrue(notification("todo-running:a").extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN));
        TodoNotifications.synchronize(context, Collections.singletonList(running), true, false);
        assertNotNull(notification("todo-daily"));
        assertNull(notification("todo-running:a"));
        TodoNotifications.synchronize(context, Collections.singletonList(running), false, false);
        assertEquals(0, manager.getActiveNotifications().length);
        assertTrue(shadowOf(alarms).getScheduledAlarms().isEmpty());
    }

    @Test public void emptyDayStillShowsCurrentDateAndSchedulesMidnight() throws Exception {
        TodoNotifications.synchronize(context, Collections.emptyList(), true, false);
        assertEquals(today, notification("todo-daily").extras.getString(Notification.EXTRA_SUB_TEXT));
        assertEquals("오늘 등록된 할 일이 없습니다.", notification("todo-daily").extras.getString(Notification.EXTRA_TEXT));
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(TodoNotificationPlan.nextMidnight(System.currentTimeMillis(), TimeZone.getDefault()),
                shadowOf(alarms).getScheduledAlarms().get(0).getTriggerAtMs());
        new TodoNotificationReceiver().onReceive(context, new Intent(Intent.ACTION_BOOT_COMPLETED));
        assertEquals(1, manager.getActiveNotifications().length);
    }

    @Test public void expiryRemovesTimerAndKeepsDailyEntryWithoutStatus() throws Exception {
        Map<String, Object> running = todo("a", today, 1, System.currentTimeMillis() - 1, false);
        TodoNotifications.synchronize(context, Collections.singletonList(running), true, true);
        assertNull(notification("todo-running:a"));
        assertEquals("1. 할 일 a", notification("todo-daily").extras.getCharSequence(Notification.EXTRA_BIG_TEXT).toString());
    }

    @Test public void lockedTimerHasNoDuplicateAndDisabledTimerUsesServiceNotice() throws Exception {
        long end = System.currentTimeMillis() + 600000;
        TodoNotifications.synchronize(context, Collections.singletonList(todo("a", today, 1, end, true)), false, true);
        assertEquals(0, manager.getActiveNotifications().length);
        org.json.JSONObject active = new org.json.JSONObject().put("contents", "잠금").put("date", today).put("endTime", end);
        assertTrue(TodoNotifications.lockServiceNotification(context, active).extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER));
        TodoNotifications.synchronize(context, Collections.emptyList(), false, false);
        Notification notice = TodoNotifications.lockServiceNotification(context, active);
        assertFalse(notice.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER));
        assertEquals(TodoNotifications.LOCK_SERVICE, notice.getChannelId());
    }
}
