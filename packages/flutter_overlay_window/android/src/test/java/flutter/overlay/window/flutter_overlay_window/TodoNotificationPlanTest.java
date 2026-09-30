package flutter.overlay.window.flutter_overlay_window;

import org.junit.Test;
import java.util.Calendar;
import java.util.TimeZone;
import static org.junit.Assert.*;

public class TodoNotificationPlanTest {
    @Test public void onlyFutureNewJobsAreEligible() {
        assertFalse(TodoNotificationPlan.eligible("2026-09-30", "", "2026-09-30", false, false));
        assertFalse(TodoNotificationPlan.eligible("2026-09-29", "", "2026-09-30", false, false));
        assertTrue(TodoNotificationPlan.eligible("2026-10-01", "", "2026-09-30", false, false));
    }

    @Test public void midnightRetainsEarlierPlansButMovingToTodayDoesNotAddOne() {
        assertTrue(TodoNotificationPlan.eligible("2026-10-01", "2026-10-01", "2026-10-01", false, false));
        assertFalse(TodoNotificationPlan.eligible("2026-10-01", "2026-10-02", "2026-10-01", false, false));
        assertFalse(TodoNotificationPlan.eligible("2026-09-30", "2026-09-30", "2026-10-01", false, false));
    }

    @Test public void completedAndStartedJobsDoNotGetMorningReminders() {
        assertFalse(TodoNotificationPlan.eligible("2026-10-01", "2026-10-01", "2026-09-30", true, false));
        assertFalse(TodoNotificationPlan.eligible("2026-10-01", "2026-10-01", "2026-09-30", false, true));
    }

    @Test public void timeIsLocalCalendarTimeAcrossDst() {
        TimeZone zone = TimeZone.getTimeZone("America/New_York");
        long before = TodoNotificationPlan.atTime("2026-03-07", 540, zone);
        long after = TodoNotificationPlan.atTime("2026-03-08", 540, zone);
        assertEquals(23 * 60 * 60 * 1000L, after - before);
        Calendar calendar = Calendar.getInstance(zone);
        calendar.setTimeInMillis(after);
        assertEquals(9, calendar.get(Calendar.HOUR_OF_DAY));
        assertEquals(0, calendar.get(Calendar.MINUTE));
    }

    @Test public void timezoneChangeKeepsNineOClockLocally() {
        long korea = TodoNotificationPlan.atTime("2026-10-01", 540, TimeZone.getTimeZone("Asia/Seoul"));
        long utc = TodoNotificationPlan.atTime("2026-10-01", 540, TimeZone.getTimeZone("UTC"));
        assertEquals(9 * 60 * 60 * 1000L, utc - korea);
    }

    @Test(expected = IllegalArgumentException.class) public void invalidTimeIsRejected() {
        TodoNotificationPlan.atTime("2026-10-01", 1440, TimeZone.getTimeZone("UTC"));
    }
}
