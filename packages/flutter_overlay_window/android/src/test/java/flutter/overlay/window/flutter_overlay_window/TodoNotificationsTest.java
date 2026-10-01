package flutter.overlay.window.flutter_overlay_window;

import android.app.AlarmManager;
import android.app.Notification;
import android.app.NotificationManager;
import android.content.Context;
import android.content.Intent;
import org.json.JSONObject;
import org.junit.Before;
import org.junit.Test;
import org.junit.runner.RunWith;
import org.robolectric.RobolectricTestRunner;
import org.robolectric.RuntimeEnvironment;
import org.robolectric.annotation.Config;
import org.robolectric.shadows.ShadowAlarmManager;
import java.util.*;
import static org.junit.Assert.*;
import static org.robolectric.Shadows.shadowOf;

@RunWith(RobolectricTestRunner.class)
@Config(sdk = 33, manifest = Config.NONE)
public class TodoNotificationsTest {
    private Context context;
    private AlarmManager alarms;
    private NotificationManager notifications;
    private String today;
    private String tomorrow;

    @Before public void setup() {
        context = RuntimeEnvironment.getApplication();
        alarms = context.getSystemService(AlarmManager.class);
        notifications = context.getSystemService(NotificationManager.class);
        TodoNotifications.prefs(context).edit().clear().commit();
        notifications.cancelAll();
        shadowOf(alarms).setCanScheduleExactAlarms(true);
        shadowOf(notifications).setNotificationsEnabled(true);
        today = TodoNotificationPlan.day(System.currentTimeMillis(), TimeZone.getDefault());
        Calendar next = Calendar.getInstance(); next.add(Calendar.DAY_OF_MONTH, 1);
        tomorrow = TodoNotificationPlan.day(next.getTimeInMillis(), TimeZone.getDefault());
    }

    private Map<String, Object> todo(String id, String date, long end) {
        Map<String, Object> result = new HashMap<>();
        result.put("id", id); result.put("content", "Job " + id);
        result.put("date", date); result.put("endTime", end);
        result.put("done", false); result.put("lock", false);
        return result;
    }

    private void sync(boolean enabled, int minute, Map<String, Object>... values) throws Exception {
        TodoNotifications.synchronize(context, Arrays.asList(values), enabled, minute);
    }

    @Test public void futureJobsShareOneAlarmAtNineAndTimeChangesReplaceIt() throws Exception {
        Map<String, Object> a = todo("a", tomorrow, 0);
        Map<String, Object> b = todo("b", tomorrow, 0);
        sync(true, 540, a, b);
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(TodoNotificationPlan.atTime(tomorrow, 540, TimeZone.getDefault()),
                shadowOf(alarms).getScheduledAlarms().get(0).triggerAtTime);
        assertEquals(0, notifications.getActiveNotifications().length);
        sync(true, 615, a, b);
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        assertEquals(TodoNotificationPlan.atTime(tomorrow, 615, TimeZone.getDefault()),
                shadowOf(alarms).getScheduledAlarms().get(0).triggerAtTime);
        sync(false, 615, a, b);
        assertTrue(shadowOf(alarms).getScheduledAlarms().isEmpty());
        sync(true, 615, a, b);
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        sync(true, 615);
        assertTrue(shadowOf(alarms).getScheduledAlarms().isEmpty());
    }

    @Test public void newTodayAndCompletedJobsNeverScheduleMorningAlarms() throws Exception {
        Map<String, Object> completed = todo("completed", tomorrow, 0);
        completed.put("done", true);
        sync(true, 540, todo("today", today, 0), completed);
        assertTrue(shadowOf(alarms).getScheduledAlarms().isEmpty());
        assertEquals(0, notifications.getActiveNotifications().length);
    }

    @Test public void duePlansAreGroupedAndNotResentAfterDismissalOrReboot() throws Exception {
        JSONObject eligible = new JSONObject(); eligible.put("a", today); eligible.put("b", today);
        TodoNotifications.prefs(context).edit().putString("eligible", eligible.toString()).commit();
        sync(true, 0, todo("a", today, 0), todo("b", today, 0));
        assertEquals(1, notifications.getActiveNotifications().length);
        Notification notification = notifications.getActiveNotifications()[0].getNotification();
        assertEquals("오늘 예정된 할 일 2개", notification.extras.getString(Notification.EXTRA_TITLE));
        assertEquals(2, notification.extras.getCharSequenceArray(Notification.EXTRA_TEXT_LINES).length);
        notifications.cancelAll();
        new TodoNotificationReceiver().onReceive(context, new Intent(Intent.ACTION_BOOT_COMPLETED));
        assertEquals(0, notifications.getActiveNotifications().length);
    }

    @Test public void permissionDenialRetainsPlanAndGrantDeliversDueReminder() throws Exception {
        TodoNotifications.prefs(context).edit().putString("eligible", new JSONObject().put("a", today).toString()).commit();
        shadowOf(notifications).setNotificationsEnabled(false);
        sync(true, 0, todo("a", today, 0));
        assertEquals(0, notifications.getActiveNotifications().length);
        shadowOf(notifications).setNotificationsEnabled(true);
        TodoNotifications.refresh(context);
        assertEquals(1, notifications.getActiveNotifications().length);
    }

    @Test public void permissionFallbackAndBootRestoreUsePersistedMirror() throws Exception {
        shadowOf(alarms).setCanScheduleExactAlarms(false);
        sync(true, 540, todo("a", tomorrow, 0));
        ShadowAlarmManager.ScheduledAlarm alarm = shadowOf(alarms).getScheduledAlarms().get(0);
        assertNotEquals(0, alarm.windowLength);
        alarms.cancel(alarm.operation);
        new TodoNotificationReceiver().onReceive(context, new Intent(Intent.ACTION_BOOT_COMPLETED));
        assertEquals(1, shadowOf(alarms).getScheduledAlarms().size());
        shadowOf(alarms).setCanScheduleExactAlarms(true);
        new TodoNotificationReceiver().onReceive(context, new Intent(AlarmManager.ACTION_SCHEDULE_EXACT_ALARM_PERMISSION_STATE_CHANGED));
        assertEquals(0, shadowOf(alarms).getScheduledAlarms().get(0).windowLength);
    }

    @Test public void runningJobsHaveIndependentCountdownsAndAreRemovedOnStopOrCompletion() throws Exception {
        long end = System.currentTimeMillis() + 60000;
        Map<String, Object> a = todo("Aa", today, end);
        Map<String, Object> b = todo("BB", today, end + 60000);
        sync(false, 540, a, b); // Morning toggle never hides running jobs.
        assertEquals(2, notifications.getActiveNotifications().length);
        for (android.service.notification.StatusBarNotification status : notifications.getActiveNotifications()) {
            Notification notification = status.getNotification();
            assertTrue((notification.flags & Notification.FLAG_ONGOING_EVENT) != 0);
            assertTrue(notification.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER));
            assertTrue(notification.extras.getBoolean(Notification.EXTRA_CHRONOMETER_COUNT_DOWN));
            assertTrue(notification.getTimeoutAfter() > 0);
        }
        a.put("endTime", 0);
        sync(false, 540, a, b);
        assertEquals(1, notifications.getActiveNotifications().length);
        b.put("endTime", System.currentTimeMillis() - 1);
        sync(false, 540, a, b);
        assertEquals(0, notifications.getActiveNotifications().length);
        assertTrue(shadowOf(alarms).getScheduledAlarms().isEmpty());
    }

    @Test public void lockedJobsUseTheServiceNotificationWithoutDuplicates() throws Exception {
        Map<String, Object> locked = todo("locked", today, System.currentTimeMillis() + 60000);
        locked.put("lock", true);
        sync(true, 540, locked);
        assertEquals(0, notifications.getActiveNotifications().length);
        Notification service = TodoNotifications.runningNotification(context, "Locked job", today, System.currentTimeMillis() + 60000);
        assertEquals("Locked job", service.extras.getString(Notification.EXTRA_TITLE));
        assertTrue(service.extras.getBoolean(Notification.EXTRA_SHOW_CHRONOMETER));
    }
}
