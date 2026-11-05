extends Control
## Quiet, original 3.6-second G3 farewell intro. No CRT or video decoding.
signal completed

const LOGO_PATH: String = "res://assets/icons/platforms/playstation-logo-colour.svg"
const BG: Color = Color("0b1020")
const DURATION: float = 3.6
const END_FADE: float = 3.18
var _started: bool = false
var _finished: bool = false
var _begin_ms: int = 0
var _logo: TextureRect

func _ready() -> void:
    mouse_filter = Control.MOUSE_FILTER_STOP
    process_mode = Node.PROCESS_MODE_ALWAYS
    set_process(false)
    _logo = TextureRect.new()
    _logo.mouse_filter = Control.MOUSE_FILTER_IGNORE
    _logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
    _logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
    _logo.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
    var picture: Image = Image.new()
    if FileAccess.file_exists(LOGO_PATH) and picture.load_svg_from_buffer(FileAccess.get_file_as_bytes(LOGO_PATH), 1.0) == OK:
        picture.generate_mipmaps()
        _logo.texture = ImageTexture.create_from_image(picture)
    add_child(_logo)
    resized.connect(_layout)
    _layout()
    _render(0.0)

func _layout() -> void:
    var w: float = minf(size.x * 0.24, 230.0)
    var h: float = w * 0.82
    _logo.size = Vector2(w, h)
    _logo.position = (size - _logo.size) * 0.5
    _logo.pivot_offset = _logo.size * 0.5

func start() -> void:
    if _started:
        return
    _started = true
    _begin_after_draw()

func _begin_after_draw() -> void:
    await RenderingServer.frame_post_draw
    if _finished or not is_inside_tree():
        return
    _begin_ms = Time.get_ticks_msec()
    UISfx.play(&"boot", true)
    set_process(true)

func _process(_delta: float) -> void:
    var t: float = float(Time.get_ticks_msec() - _begin_ms) * 0.001
    _render(minf(t, DURATION))
    if t >= DURATION:
        _finish()

func _smooth(a: float, b: float, t: float) -> float:
    var v: float = clampf((t - a) / maxf(0.001, b - a), 0.0, 1.0)
    return v * v * (3.0 - 2.0 * v)

func _render(t: float) -> void:
    var arrival: float = _smooth(1.30, 2.05, t)
    var out: float = 1.0 - _smooth(END_FADE, DURATION, t)
    _logo.modulate.a = arrival * out if _logo.texture != null else 0.0
    _logo.scale = Vector2.ONE * lerpf(0.91, 1.0, arrival)
    queue_redraw()

func _draw() -> void:
    var t: float = 0.0
    if _started and _begin_ms > 0:
        t = clampf(float(Time.get_ticks_msec() - _begin_ms) * 0.001, 0.0, DURATION)
    var out: float = 1.0 - _smooth(END_FADE, DURATION, t)
    draw_rect(Rect2(Vector2.ZERO, size), Color(BG.r, BG.g, BG.b, out))

func skip() -> void:
    if _finished:
        return
    UISfx.fade_out(&"boot", 0.16)
    _finish()

func _finish() -> void:
    if _finished:
        return
    _finished = true
    set_process(false)
    completed.emit()
