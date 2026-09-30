class_name LabCanvas
extends Control
## Snapshot interpolation. The algorithm never observes these transient positions.
signal picked(id: String)

const INK := Color("#252a2b")
const BLUE := Color("#bce1ef")
const PAPER := Color("#fdf6e3")
var current: Dictionary = {"nodes": [], "edges": []}
var previous: Dictionary = {"nodes": [], "edges": []}
var progress := 1.0
var zoom := 1.0
var offset := Vector2(25, 25)
var active_tween: Tween
var font: Font
var dragging := false
var drag_origin := Vector2.ZERO
var moved := false

func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(400, 380)
	font = get_theme_default_font()
	resized.connect(queue_redraw)

func display(frame: Dictionary, animate: bool = true, duration: float = 0.5) -> void:
	if active_tween and active_tween.is_valid():
		active_tween.kill()
	previous = current
	current = frame
	progress = 0.0 if animate else 1.0
	if animate:
		active_tween = create_tween()
		active_tween.tween_method(_set_progress, 0.0, 1.0, duration).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
	queue_redraw()

func _set_progress(value: float) -> void:
	progress = value
	queue_redraw()

func fit() -> void:
	var nodes: Array = current.get("nodes", [])
	if nodes.is_empty():
		zoom = 1.0
		offset = Vector2(25, 25)
		return
	var bounds := Rect2(nodes[0].pos - Vector2(55, 45), Vector2(110, 100))
	for node in nodes:
		bounds = bounds.expand(node.pos - Vector2(65, 50)).expand(node.pos + Vector2(65, 60))
	zoom = clampf(minf((size.x - 60) / bounds.size.x, (size.y - 60) / bounds.size.y), 0.18, 1.4)
	offset = (size - bounds.size * zoom) / 2 - bounds.position * zoom
	queue_redraw()

func magnify(factor: float, pivot: Vector2 = Vector2(-1, -1)) -> void:
	if pivot.x < 0:
		pivot = size / 2
	var world := (pivot - offset) / zoom
	zoom = clampf(zoom * factor, 0.15, 3.0)
	offset = pivot - world * zoom
	queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			magnify(1.12, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			magnify(1.0 / 1.12, event.position)
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				dragging = true
				drag_origin = event.position
				moved = false
			else:
				if dragging and not moved:
					var point: Vector2 = (event.position - offset) / zoom
					for node in current.get("nodes", []):
						if point.distance_to(node.pos) < 34:
							picked.emit(str(node.id))
							break
				dragging = false
	elif event is InputEventMouseMotion and dragging:
		if event.position.distance_to(drag_origin) > 4:
			moved = true
		if moved:
			offset += event.relative
			queue_redraw()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), PAPER)
	if font == null:
		return
	var old := {}
	var new := {}
	for node in previous.get("nodes", []): old[str(node.id)] = node
	for node in current.get("nodes", []): new[str(node.id)] = node
	var positions := {}
	for id in new:
		var start: Vector2 = old[id].pos if old.has(id) else new[id].pos
		positions[id] = start.lerp(new[id].pos, progress)
	for id in old:
		if not new.has(id): positions[id] = old[id].pos
	draw_set_transform(offset, 0, Vector2.ONE * zoom)
	# Old edges fade out; new edges attach to interpolated node positions.
	for e in previous.get("edges", []):
		_draw_edge(e, positions, 1 - progress)
	for e in current.get("edges", []):
		_draw_edge(e, positions, progress)
	for id in old:
		if not new.has(id):
			_draw_vertex(old[id], positions[id], 1 - progress, false)
	for id in new:
		var opacity := 1.0 if old.has(id) else progress
		_draw_vertex(new[id], positions[id], opacity, current.get("active", []).has(id))
	draw_set_transform(Vector2.ZERO)
	if new.is_empty():
		draw_string(font, Vector2(36, 65), "结构为空 · 使用操作面板加入元素", HORIZONTAL_ALIGNMENT_LEFT, -1, 18, INK)

func _draw_edge(e: Dictionary, positions: Dictionary, alpha: float) -> void:
	if alpha <= 0.001 or not positions.has(str(e.from)) or not positions.has(str(e.to)):
		return
	var a: Vector2 = positions[str(e.from)]
	var b: Vector2 = positions[str(e.to)]
	var direction := (b - a).normalized()
	var perpendicular := Vector2(-direction.y, direction.x)
	var shift := perpendicular * (11.0 if e.get("dashed", false) else 0.0)
	a += direction * 28 + shift
	b -= direction * 30 - shift
	var color := Color(INK, alpha)
	if e.get("dashed", false):
		draw_dashed_line(a, b, color, 1.5, 7)
	else:
		draw_line(a, b, color, 1.7, true)
	draw_colored_polygon(PackedVector2Array([b, b - direction * 9 + perpendicular * 4,
		b - direction * 9 - perpendicular * 4]), color)
	if not str(e.get("label", "")).is_empty():
		draw_string(font, (a + b) / 2 + perpendicular * 14, str(e.label),
			HORIZONTAL_ALIGNMENT_LEFT, -1, 12, color)

func _draw_vertex(node: Dictionary, position: Vector2, alpha: float, active: bool) -> void:
	if alpha <= 0.001:
		return
	var fill := BLUE if active else PAPER
	var ink := INK
	match node.get("tone", ""):
		"red": fill = Color("#f3b8a8")
		"green": fill = Color("#d1e8bf")
		"muted": ink = Color("#999485")
		"black": fill = INK; ink = PAPER
	if active: fill = BLUE; ink = INK
	fill.a = alpha
	ink.a = alpha
	var outline := Color(INK, alpha)
	if node.get("shape", "circle") == "box":
		var rect := Rect2(position - Vector2(29, 24), Vector2(58, 48))
		draw_rect(rect, fill)
		draw_rect(rect, outline, false, 2 if active else 1.5)
	else:
		draw_circle(position, 27, fill)
		draw_arc(position, 27, 0, TAU, 48, outline, 2 if active else 1.5, true)
	var text := str(node.label)
	var text_size := 17 if text.length() < 6 else 13
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, text_size).x
	draw_string(font, position + Vector2(-width / 2, 6), text,
		HORIZONTAL_ALIGNMENT_LEFT, -1, text_size, ink)
	var detail := str(node.get("detail", ""))
	width = font.get_string_size(detail, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x
	draw_string(font, position + Vector2(-width / 2, 46), detail,
		HORIZONTAL_ALIGNMENT_LEFT, -1, 12, Color(INK, alpha))
