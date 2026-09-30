package flutter.overlay.window.flutter_overlay_window;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/** Calendar rules kept independent of Android so midnight and DST are testable. */
final class TodoNotificationPlan {
    static String day(long now, TimeZone zone) {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT);
        format.setTimeZone(zone);
        return format.format(new Date(now));
    }

    static boolean eligible(String date, String previouslyScheduledDate, String today,
                            boolean done, boolean started) {
        if (done || started || date.compareTo(today) < 0) return false;
        // A newly added today's job does not get a morning reminder. A job
        // scheduled earlier keeps its reminder when its date becomes today.
        return date.compareTo(today) > 0 || date.equals(previouslyScheduledDate);
    }

    static long atTime(String date, int minuteOfDay, TimeZone zone) {
        if (minuteOfDay < 0 || minuteOfDay >= 1440) throw new IllegalArgumentException("Invalid time");
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT);
        format.setLenient(false);
        format.setTimeZone(zone);
        try {
            Calendar calendar = Calendar.getInstance(zone);
            calendar.setTime(format.parse(date));
            calendar.set(Calendar.HOUR_OF_DAY, minuteOfDay / 60);
            calendar.set(Calendar.MINUTE, minuteOfDay % 60);
            calendar.set(Calendar.SECOND, 0);
            calendar.set(Calendar.MILLISECOND, 0);
            return calendar.getTimeInMillis();
        } catch (ParseException e) {
            throw new IllegalArgumentException("Invalid date", e);
        }
    }
}
