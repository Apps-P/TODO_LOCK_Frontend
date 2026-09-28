package flutter.overlay.window.flutter_overlay_window;

/** Small, Android-independent state machine: no return path re-hides a lock. */
final class PaymentVisibilityState {
    private boolean hidden;
    void open() { hidden = true; }
    boolean restore() { boolean wasHidden = hidden; hidden = false; return wasHidden; }
    boolean isHidden() { return hidden; }
}
