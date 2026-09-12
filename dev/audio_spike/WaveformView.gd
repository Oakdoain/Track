extends Control
class_name AudioSpikeWaveformView

signal selection_changed(start_time: float, end_time: float)
signal selection_cleared

const WAVE_COLOR := Color("#143FA4")
const WAVE_SECONDARY_COLOR := Color("#9AADE8")
const BACKGROUND_COLOR := Color("#F7F9FF")
const BORDER_COLOR := Color("#D7DEF3")
const SELECTION_COLOR := Color(0.078, 0.247, 0.643, 0.18)
const PLAYHEAD_COLOR := Color("#9E2F3E")
var _duration_seconds: float = 60.0
var _waveform_peaks: PackedVector2Array = PackedVector2Array()
var _playhead_seconds: float = 0.0
var _selection_anchor_seconds: float = 0.0
var _selection_cursor_seconds: float = 0.0
var _has_selection: bool = false
var _is_dragging: bool = false


func _ready() -> void:
	mouse_default_cursor_shape = Control.CURSOR_CROSS
	custom_minimum_size = Vector2(360.0, 180.0)
	resized.connect(queue_redraw)
	queue_redraw()


func set_duration(seconds: float) -> void:
	_duration_seconds = maxf(seconds, 0.001)
	_playhead_seconds = clampf(_playhead_seconds, 0.0, _duration_seconds)
	if _has_selection:
		_selection_anchor_seconds = clampf(_selection_anchor_seconds, 0.0, _duration_seconds)
		_selection_cursor_seconds = clampf(_selection_cursor_seconds, 0.0, _duration_seconds)
	queue_redraw()


func set_waveform(points: PackedFloat32Array) -> void:
	var peaks := PackedVector2Array()
	peaks.resize(points.size())
	for index in range(points.size()):
		var amplitude := clampf(absf(points[index]), 0.0, 1.0)
		peaks[index] = Vector2(-amplitude, amplitude)
	set_waveform_peaks(peaks)


func set_waveform_peaks(peaks: PackedVector2Array) -> void:
	_waveform_peaks = peaks.duplicate()
	queue_redraw()


func set_playhead(time_seconds: float) -> void:
	_playhead_seconds = clampf(time_seconds, 0.0, _duration_seconds)
	queue_redraw()


func set_selection(start_time: float, end_time: float, emit_change: bool = true) -> void:
	_selection_anchor_seconds = clampf(start_time, 0.0, _duration_seconds)
	_selection_cursor_seconds = clampf(end_time, 0.0, _duration_seconds)
	_has_selection = true
	queue_redraw()
	if emit_change:
		var normalized := get_selection()
		selection_changed.emit(normalized.x, normalized.y)


func clear_selection() -> void:
	_is_dragging = false
	_has_selection = false
	_selection_anchor_seconds = 0.0
	_selection_cursor_seconds = 0.0
	queue_redraw()
	selection_cleared.emit()


func has_selection() -> bool:
	return _has_selection


func get_selection() -> Vector2:
	return Vector2(
		minf(_selection_anchor_seconds, _selection_cursor_seconds),
		maxf(_selection_anchor_seconds, _selection_cursor_seconds)
	)


func time_to_x(time_seconds: float) -> float:
	return clampf(time_seconds / _duration_seconds, 0.0, 1.0) * size.x


func x_to_time(x_position: float) -> float:
	var ratio := clampf(x_position / maxf(size.x, 1.0), 0.0, 1.0)
	return ratio * _duration_seconds


func get_duration_seconds() -> float:
	return _duration_seconds


func get_waveform_peak_count() -> int:
	return _waveform_peaks.size()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		var mouse_button := event as InputEventMouseButton
		if mouse_button.button_index != MOUSE_BUTTON_LEFT:
			return
		if mouse_button.pressed:
			_is_dragging = true
			_selection_anchor_seconds = x_to_time(mouse_button.position.x)
			_selection_cursor_seconds = _selection_anchor_seconds
			_has_selection = true
			_emit_current_selection()
		else:
			if not _is_dragging:
				return
			_selection_cursor_seconds = x_to_time(mouse_button.position.x)
			_is_dragging = false
			_emit_current_selection()
		accept_event()
	elif event is InputEventMouseMotion and _is_dragging:
		var mouse_motion := event as InputEventMouseMotion
		_selection_cursor_seconds = x_to_time(mouse_motion.position.x)
		_emit_current_selection()
		accept_event()


func _emit_current_selection() -> void:
	queue_redraw()
	var normalized := get_selection()
	selection_changed.emit(normalized.x, normalized.y)


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), BACKGROUND_COLOR, true)
	draw_rect(Rect2(Vector2(0.5, 0.5), size - Vector2.ONE), BORDER_COLOR, false, 1.0)

	var center_y := size.y * 0.5
	var top := 18.0
	var bottom := maxf(size.y - 18.0, top + 1.0)
	draw_line(
		Vector2(0.0, center_y),
		Vector2(size.x, center_y),
		WAVE_SECONDARY_COLOR,
		1.0
	)

	_draw_time_grid(top, bottom)
	_draw_waveform(center_y, top, bottom)

	if _has_selection:
		var selection := get_selection()
		var start_x := time_to_x(selection.x)
		var end_x := time_to_x(selection.y)
		var selection_rect := Rect2(start_x, top, maxf(end_x - start_x, 1.0), bottom - top)
		draw_rect(selection_rect, SELECTION_COLOR, true)
		draw_line(Vector2(start_x, top), Vector2(start_x, bottom), WAVE_COLOR, 2.0)
		draw_line(Vector2(end_x, top), Vector2(end_x, bottom), WAVE_COLOR, 2.0)

	var playhead_x := time_to_x(_playhead_seconds)
	draw_line(Vector2(playhead_x, top), Vector2(playhead_x, bottom), PLAYHEAD_COLOR, 1.5)


func _draw_time_grid(top: float, bottom: float) -> void:
	var interval := 10.0
	var marker := 0.0
	while marker <= _duration_seconds + 0.001:
		var x_position := time_to_x(marker)
		draw_line(
			Vector2(x_position, top),
			Vector2(x_position, bottom),
			Color(0.078, 0.247, 0.643, 0.08),
			1.0
		)
		marker += interval


func _draw_waveform(center_y: float, top: float, bottom: float) -> void:
	if _waveform_peaks.is_empty():
		return
	var available_height := maxf((bottom - top) * 0.46, 1.0)
	var point_count := _waveform_peaks.size()
	for index in range(point_count):
		var ratio := 0.0 if point_count <= 1 else float(index) / float(point_count - 1)
		var x_position := ratio * size.x
		var peak := _waveform_peaks[index]
		var minimum := clampf(minf(peak.x, peak.y), -1.0, 1.0)
		var maximum := clampf(maxf(peak.x, peak.y), -1.0, 1.0)
		var top_y := center_y - maximum * available_height
		var bottom_y := center_y - minimum * available_height
		draw_line(
			Vector2(x_position, top_y),
			Vector2(x_position, bottom_y),
			WAVE_COLOR,
			1.0
		)
