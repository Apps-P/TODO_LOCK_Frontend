package flutter.overlay.window.flutter_overlay_window;

import org.junit.Test;
import java.util.TimeZone;
import static org.junit.Assert.*;

public class TodoNotificationPlanTest {
    @Test public void midnightUsesCalendarDateAcrossDaylightSaving() {
        TimeZone ny = TimeZone.getTimeZone("America/New_York");
        long spring = TodoNotificationPlan.atTime("2026-03-08", 0, ny);
        long fall = TodoNotificationPlan.atTime("2026-11-01", 0, ny);
        assertEquals(23 * 3600000L, TodoNotificationPlan.nextMidnight(spring, ny) - spring);
        assertEquals(25 * 3600000L, TodoNotificationPlan.nextMidnight(fall, ny) - fall);
        assertEquals("2026-03-09", TodoNotificationPlan.day(TodoNotificationPlan.nextMidnight(spring, ny), ny));
    }    @Test public void usesLocalTimeAndDaylightSaving() {
        TimeZone ny = TimeZone.getTimeZone("America/New_York");
        assertEquals(23 * 3600000L, TodoNotificationPlan.atTime("2026-03-08", 540, ny) - TodoNotificationPlan.atTime("2026-03-07", 540, ny));
        assertEquals(9 * 3600000L, TodoNotificationPlan.atTime("2026-10-05", 540, TimeZone.getTimeZone("UTC")) - TodoNotificationPlan.atTime("2026-10-05", 540, TimeZone.getTimeZone("Asia/Seoul")));
    }
    @Test(expected = IllegalArgumentException.class) public void invalidTimeRejected() {
        TodoNotificationPlan.atTime("2026-10-05", 1440, TimeZone.getDefault());
    }
    @Test(expected = IllegalArgumentException.class) public void invalidDateRejected() {
        TodoNotificationPlan.atTime("2026-02-30", 540, TimeZone.getDefault());
    }
}
