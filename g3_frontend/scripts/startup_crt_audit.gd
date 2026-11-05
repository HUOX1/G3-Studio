extends Control
## Read-only V2.4 startup inspection overlay and JSONL trace.
## This helper never writes animation parameters or changes boot timing.

const LOG_NAME: String = "g3_crt_boot_audit.jsonl"
const CAPTURE_INTERVAL: float = 0.12
const LONG_FRAME_MS: float = 32.0
const HUD_WIDTH: float = 470.0
const HUD_HEIGHT: float = 208.0

var _output: FileAccess
var _hud: Label
var _next_capture: float = 0.0
var _next_flush: float = 0.0
var _last_stage: String = ""
var _last_warning: String = "none"
var _max_frame_ms: float = 0.0
var _max_cpu_ms: float = 0.0
var _frames: int = 0
var _previous_tick_us: int = 0
var _running: bool = false
var _logo_exists: bool = false
var _duration: float = 6.2


func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_IGNORE
    z_index = 100
    position = Vector2(16.0, 16.0)
    size = Vector2(HUD_WIDTH, HUD_HEIGHT)
    var bg: ColorRect = ColorRect.new()
    bg.color = Color(0.015, 0.033, 0.060, 0.88)
    bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
    add_child(bg)
    bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
    _hud = Label.new()
    _hud.position = Vector2(12.0, 8.0)
    _hud.size = Vector2(HUD_WIDTH - 24.0, HUD_HEIGHT - 16.0)
    _hud.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _hud.add_theme_font_size_override("font_size", 13)
    _hud.add_theme_color_override("font_color", Color(0.82, 0.95, 1.0))
    _hud.text = "G3 CRT AUDIT / preparing..."
    add_child(_hud)


func configure(duration: float, logo_exists: bool) -> void:
    _duration = duration
    _logo_exists = logo_exists
    var abs_path: String = ProjectSettings.globalize_path("user://" + LOG_NAME)
    _output = FileAccess.open("user://" + LOG_NAME, FileAccess.WRITE)
    if _output == null:
        push_warning("G3 CRT AUDIT cannot open log: " + abs_path)
        _last_warning = "log open failed"
    else:
        _write({"kind":"meta", "version":"PHASE_2_5_CLOCK_AND_FX", "log_path":abs_path,
            "project":"G3", "duration_s":_duration, "logo_exists":_logo_exists,
            "viewport_px":_vector2_array(get_viewport_rect().size),
            "unix_s":Time.get_unix_time_from_system()})
    print("[G3_BOOT_AUDIT] LOG_PATH=", abs_path)


func mark(event_name: String, elapsed: float) -> void:
    _write({"kind":"event", "event":event_name, "t_s":_round3(elapsed),
        "frame_index":_frames, "viewport_px":_vector2_array(get_viewport_rect().size)})
    print("[G3_BOOT_AUDIT] ", event_name, " t=", "%.3f" % elapsed)
    if _output != null:
        _output.flush()
    if event_name == "BOOT_STARTED":
        _running = true


func sample(t: float, delta: float, cpu_ms: float, material: ShaderMaterial,
        logo: TextureRect, phosphor: TextureRect, logo_stage: Control,
        holder: CenterContainer, wall_t: float) -> void:
    _frames += 1
    var now_us: int = Time.get_ticks_usec()
    var wall_gap_ms: float = 0.0
    if _previous_tick_us > 0:
        wall_gap_ms = float(now_us - _previous_tick_us) / 1000.0
    _previous_tick_us = now_us
    var frame_ms: float = delta * 1000.0
    _max_frame_ms = maxf(_max_frame_ms, frame_ms)
    _max_cpu_ms = maxf(_max_cpu_ms, cpu_ms)
    var stage: String = _get_stage(t)
    if stage != _last_stage:
        _last_stage = stage
        mark("STAGE_" + stage, t)

    if frame_ms >= LONG_FRAME_MS or wall_gap_ms >= LONG_FRAME_MS:
        _last_warning = "FRAME delta %.1f / wall %.1f ms @ %.2fs" % [frame_ms, wall_gap_ms, wall_t]
        _write({"kind":"long_frame", "t_s":_round3(t),
            "wall_s":_round3(wall_t), "wall_gap_ms":_round3(wall_gap_ms),
            "frame_gap_ms":_round3(frame_ms), "script_cpu_ms":_round3(cpu_ms),
            "stage":stage, "frame_index":_frames})

    if t < _next_capture:
        return
    _next_capture = t + CAPTURE_INTERVAL
    var power: float = _uniform(material, "power_envelope")
    var burst: float = _uniform(material, "power_burst")
    var reveal: float = _uniform(material, "reveal_progress")
    var tracking: float = _uniform(material, "glitch_strength")
    var scan: float = _uniform(material, "scan_envelope")
    var snow: float = _uniform(material, "snow_envelope")
    var settle: float = _uniform(material, "settle_envelope")
    var viewport: Vector2 = get_viewport_rect().size
    var screen_logo: Rect2 = Rect2()
    var texture_px: Vector2 = Vector2.ZERO
    if phosphor != null:
        screen_logo = phosphor.get_global_rect()
        if phosphor.texture != null:
            texture_px = phosphor.texture.get_size()
    var alpha_original: float = 0.0
    var alpha_crt: float = 0.0
    if logo != null:
        alpha_original = logo.modulate.a
    if phosphor != null:
        alpha_crt = phosphor.modulate.a
    var alpha_holder: float = 0.0
    if holder != null:
        alpha_holder = holder.modulate.a
    var logo_scale: Vector2 = Vector2.ONE
    if logo_stage != null:
        logo_scale = logo_stage.scale

    _write({"kind":"frame_sample", "t_s":_round3(t),
        "wall_s":_round3(wall_t), "visual_lag_ms":_round3(maxf(wall_t - t, 0.0) * 1000.0),
        "stage":stage, "frame_index":_frames,
        "wall_gap_ms":_round3(wall_gap_ms), "frame_gap_ms":_round3(frame_ms),
        "script_cpu_ms":_round3(cpu_ms), "engine_fps":Engine.get_frames_per_second(),
        "viewport_px":_vector2_array(viewport), "logo_rect_px":_rect_array(screen_logo),
        "logo_texture_px":_vector2_array(texture_px), "logo_stage_scale":_vector2_array(logo_scale),
        "alpha_original":_round3(alpha_original), "alpha_crt":_round3(alpha_crt),
        "alpha_holder":_round3(alpha_holder),
        "power":_round3(power), "burst":_round3(burst), "reveal":_round3(reveal),
        "tear":_round3(tracking), "scan":_round3(scan),
        "snow":_round3(snow), "settle":_round3(settle)})

    if _hud != null:
        _hud.text = ("G3 CRT BOOT  /  DIAGNOSTIC 2.5\n"
            + "visual %.2f / wall %.2f s  |  %s\n" % [t, wall_t, stage]
            + "FPS %d   delta %.1f ms  real %.1f ms\n" % [Engine.get_frames_per_second(), frame_ms, wall_gap_ms]
            + "script %.2f ms   MAX %.2f ms\n" % [cpu_ms, _max_cpu_ms]
            + "POWER %.2f / BURST %.2f / REVEAL %.2f\n" % [power, burst, reveal]
            + "TEAR %.2f / SCAN %.2f / SNOW %.2f / LOCK %.2f\n" % [tracking, scan, snow, settle]
            + "LOGO %dx%d   TEX %dx%d  A %.2f / %.2f\n" % [int(screen_logo.size.x), int(screen_logo.size.y), int(texture_px.x), int(texture_px.y), alpha_crt, alpha_original]
            + "WARN: " + _last_warning)

    if t >= _next_flush and _output != null:
        _next_flush = t + 0.9
        _output.flush()


func close() -> void:
    if _output != null:
        _write({"kind":"summary", "frames":_frames,
            "max_frame_gap_ms":_round3(_max_frame_ms),
            "max_script_cpu_ms":_round3(_max_cpu_ms),
            "last_stage":_last_stage})
        _output.flush()
        _output.close()
        _output = null
    _running = false


func _exit_tree() -> void:
    if _output != null:
        close()


func _get_stage(t: float) -> String:
    if t < 0.34:
        return "PREHEAT"
    if t < 1.43:
        return "POWER_BURST"
    if t < 1.85:
        return "LOGO_REVEAL"
    if t < 2.29:
        return "VHS_TEAR_1"
    if t < 2.58:
        return "STATIC_PULSE"
    if t < 3.00:
        return "VHS_TEAR_2"
    if t < 3.68:
        return "SIGNAL_SETTLE"
    if t < 4.78:
        return "CLEAN_LOGO"
    if t < 5.60:
        return "HOLD"
    return "FADE_OUT"


func _uniform(material: ShaderMaterial, parameter: String) -> float:
    if material == null:
        return -1.0
    var value: Variant = material.get_shader_parameter(parameter)
    if value == null:
        return -1.0
    return float(value)


func _write(data: Dictionary) -> void:
    if _output != null:
        _output.store_line(JSON.stringify(data))


func _round3(value: float) -> float:
    return roundf(value * 1000.0) / 1000.0


func _vector2_array(value: Vector2) -> Array:
    return [_round3(value.x), _round3(value.y)]


func _rect_array(value: Rect2) -> Array:
    return [_round3(value.position.x), _round3(value.position.y),
        _round3(value.size.x), _round3(value.size.y)]
