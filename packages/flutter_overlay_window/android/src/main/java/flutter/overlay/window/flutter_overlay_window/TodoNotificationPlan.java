package flutter.overlay.window.flutter_overlay_window;

import java.text.ParseException;
import java.text.SimpleDateFormat;
import java.util.Calendar;
import java.util.Date;
import java.util.Locale;
import java.util.TimeZone;

/** Calendar rules shared by app synchronization and background receivers. */
final class TodoNotificationPlan {
    static String day(long now, TimeZone zone) {
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT);
        format.setTimeZone(zone);
        return format.format(new Date(now));
    }

    static long nextMidnight(long now, TimeZone zone) {
        Calendar calendar = Calendar.getInstance(zone);
        calendar.setTimeInMillis(now);
        calendar.add(Calendar.DAY_OF_MONTH, 1);
        calendar.set(Calendar.HOUR_OF_DAY, 0);
        calendar.set(Calendar.MINUTE, 0);
        calendar.set(Calendar.SECOND, 0);
        calendar.set(Calendar.MILLISECOND, 0);
        return calendar.getTimeInMillis();
    }

    static long atTime(String date, int minute, TimeZone zone) {
        if (minute < 0 || minute >= 1440 || !date.matches("\\d{4}-\\d{2}-\\d{2}"))
            throw new IllegalArgumentException("Invalid reminder date or time");
        SimpleDateFormat format = new SimpleDateFormat("yyyy-MM-dd", Locale.ROOT);
        format.setTimeZone(zone);
        format.setLenient(false);
        try {
            Calendar calendar = Calendar.getInstance(zone);
            calendar.setTime(format.parse(date));
            calendar.set(Calendar.HOUR_OF_DAY, minute / 60);
            calendar.set(Calendar.MINUTE, minute % 60);
            calendar.set(Calendar.SECOND, 0);
            calendar.set(Calendar.MILLISECOND, 0);
            return calendar.getTimeInMillis();
        } catch (ParseException e) {
            throw new IllegalArgumentException("Invalid reminder date", e);
        }
    }
}
