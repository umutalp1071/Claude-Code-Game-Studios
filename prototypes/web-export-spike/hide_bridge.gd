extends Node
# HideBridge — autoload. Installs the JS-side visibilitychange/pagehide
# listener ONCE and re-emits it into Godot as a signal, so Gate A (input)
# and Gate B (persistence) can both consume the same hide event, per the
# verification plan's own instruction to reuse it across both gates rather
# than each probe installing its own listener.
# ponytail: throwaway spike code.

signal hide_detected(js_ts: float, gd_now: float, frame: int)

var _cb: JavaScriptObject  # MUST stay held — create_callback() refs get GC'd if dropped
var _window: JavaScriptObject

func _ready() -> void:
	if not OS.has_feature("web"):
		ProbeLog.line("[HideBridge] not running on web — hide detection disabled (desktop editor run)")
		return
	_window = JavaScriptBridge.get_interface("window")
	_cb = JavaScriptBridge.create_callback(_on_hide_from_js)
	JavaScriptBridge.eval("""
		window.__probe_n = (parseInt(localStorage.getItem('probe_js') || '0'));
		window.__probe_hide = function () {
			if (document.visibilityState !== 'hidden') return;
			window.__probe_hide_ts = performance.now();
			localStorage.setItem('probe_js', String(++window.__probe_n));
			if (window.__probe_gd_cb) window.__probe_gd_cb(window.__probe_hide_ts);
		};
		document.addEventListener('visibilitychange', window.__probe_hide);
		window.addEventListener('pagehide', window.__probe_hide);
	""", true)
	_window.__probe_gd_cb = _cb
	ProbeLog.line("[HideBridge] JS visibilitychange/pagehide listener installed")

func _on_hide_from_js(args: Array) -> void:
	var js_ts: float = args[0]
	var now: float = float(JavaScriptBridge.eval("performance.now()", true))
	var frame := Engine.get_frames_drawn()
	ProbeLog.line("[HideBridge] gd callback: frame=%d lag=%.1fms" % [frame, now - js_ts])
	hide_detected.emit(js_ts, now, frame)

func probe_js_value() -> String:
	if not OS.has_feature("web"):
		return "n/a (desktop editor run)"
	return str(JavaScriptBridge.eval("localStorage.getItem('probe_js')", true))
