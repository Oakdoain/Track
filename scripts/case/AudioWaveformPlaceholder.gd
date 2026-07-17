extends Control

signal seek_requested(progress_ratio: float)
signal playhead_drag_started(progress_ratio: float)
signal playhead_drag_updated(progress_ratio: float)
signal playhead_drag_finished(progress_ratio: float)
signal playhead_drag_cancelled(progress_ratio: float)

const WAVE_COLOR := Color("#123FA4")
const WAVE_SOFT := Color("#8FA8F2")
const CENTER_LINE := Color("#D7DEF3")
const PROGRESS_COLOR := Color("#0A318A")
const EMPTY_TEXT_COLOR := Color("#8995B8")
const HORIZONTAL_PADDING: float = 18.0
const VERTICAL_PADDING: float = 18.0
const TARGET_BAR_SPACING: float = 7.0

var _progress_ratio: float = 0.0
var _waveform_samples: PackedFloat32Array = PackedFloat32Array()
var _drag_enabled: bool = false
var _is_dragging_playhead: bool = false
var _dragged_progress: float = 0.0


func _ready() -> void:
	custom_minimum_size = Vector2(520, 96)
	resized.connect(queue_redraw)


func set_progress_ratio(value: float) -> void:
	var safe_value: float = 0.0 if is_nan(value) or is_inf(value) else value

	if _is_dragging_playhead:
		return

	_progress_ratio = clampf(safe_value, 0.0, 1.0)
	queue_redraw()


func set_drag_enabled(enabled: bool) -> void:
	_drag_enabled = enabled

	if not _drag_enabled:
		cancel_playhead_drag()
		mouse_default_cursor_shape = Control.CURSOR_ARROW


func cancel_playhead_drag(notify_cancelled: bool = true) -> void:
	var was_dragging := _is_dragging_playhead
	_is_dragging_playhead = false
	_dragged_progress = _progress_ratio

	if was_dragging and notify_cancelled:
		playhead_drag_cancelled.emit(_dragged_progress)


func is_dragging_playhead() -> bool:
	return _is_dragging_playhead


func set_waveform_samples(values: PackedFloat32Array) -> void:
	_waveform_samples.clear()

	for value in values:
		if is_nan(value) or is_inf(value):
			continue

		_waveform_samples.append(clampf(value, 0.0, 1.0))

	queue_redraw()


func _draw() -> void:
	var draw_size: Vector2 = size
	var center_y: float = draw_size.y * 0.5
	var usable_width: float = maxf(1.0, draw_size.x - HORIZONTAL_PADDING * 2.0)
	var start_x: float = HORIZONTAL_PADDING

	draw_line(
		Vector2(start_x, center_y),
		Vector2(start_x + usable_width, center_y),
		CENTER_LINE,
		1.0
	)

	if _waveform_samples.is_empty():
		_draw_empty_state(start_x, center_y, usable_width)
	else:
		var calculated_count: int = maxi(
			2,
			int(floor(usable_width / TARGET_BAR_SPACING)) + 1
		)
		var bar_count: int = mini(_waveform_samples.size(), calculated_count)
		var step: float = usable_width / float(bar_count - 1) if bar_count > 1 else 0.0
		var max_height: float = maxf(1.0, center_y - VERTICAL_PADDING)

		for index in range(bar_count):
			var source_start: int = int(floor(float(index) * float(_waveform_samples.size()) / float(bar_count)))
			var source_end: int = int(ceil(float(index + 1) * float(_waveform_samples.size()) / float(bar_count)))
			source_end = clampi(source_end, source_start + 1, _waveform_samples.size())
			var amplitude: float = 0.0

			for source_index in range(source_start, source_end):
				amplitude = maxf(amplitude, _waveform_samples[source_index])

			var x: float = (
				start_x + step * float(index)
				if bar_count > 1
				else start_x + usable_width * 0.5
			)
			var height: float = maxf(3.0, max_height * amplitude)
			var sample_ratio: float = float(index) / float(maxi(1, bar_count - 1))
			var color: Color = WAVE_COLOR if sample_ratio <= _progress_ratio else WAVE_SOFT
			draw_line(
				Vector2(x, center_y - height),
				Vector2(x, center_y + height),
				color,
				2.0,
				true
			)

	var progress_x: float = start_x + usable_width * _progress_ratio
	draw_line(
		Vector2(progress_x, 7.0),
		Vector2(progress_x, draw_size.y - 13.0),
		PROGRESS_COLOR,
		3.0,
		true
	)

	var anchor_center := Vector2(progress_x, draw_size.y - 8.0)
	var anchor_points := PackedVector2Array([
		anchor_center + Vector2(0.0, -5.0),
		anchor_center + Vector2(5.0, 0.0),
		anchor_center + Vector2(0.0, 5.0),
		anchor_center + Vector2(-5.0, 0.0)
	])
	draw_colored_polygon(anchor_points, PROGRESS_COLOR)


func _gui_input(event: InputEvent) -> void:
	if not _drag_enabled:
		return

	if event is InputEventMouseButton:
		var mouse_event: InputEventMouseButton = event as InputEventMouseButton

		if mouse_event.button_index != MOUSE_BUTTON_LEFT:
			return

		if mouse_event.pressed:
			_is_dragging_playhead = true
			_update_dragged_progress(mouse_event.position.x)
			playhead_drag_started.emit(_dragged_progress)
			accept_event()

		return

	if event is InputEventMouseMotion and not _is_dragging_playhead:
		var motion_event: InputEventMouseMotion = event as InputEventMouseMotion
		mouse_default_cursor_shape = (
			Control.CURSOR_HSIZE
			if Rect2(Vector2.ZERO, size).has_point(motion_event.position)
			else Control.CURSOR_ARROW
		)


func _input(event: InputEvent) -> void:
	if not _is_dragging_playhead:
		return

	if event is InputEventMouseMotion:
		var motion_event := event as InputEventMouseMotion

		if (motion_event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_update_dragged_progress(_viewport_to_local_x(motion_event.position))
			playhead_drag_updated.emit(_dragged_progress)
			get_viewport().set_input_as_handled()
		else:
			_finish_playhead_drag(true)
		return

	if event is InputEventMouseButton:
		var mouse_event := event as InputEventMouseButton

		if mouse_event.button_index == MOUSE_BUTTON_LEFT and not mouse_event.pressed:
			_update_dragged_progress(_viewport_to_local_x(mouse_event.position))
			_finish_playhead_drag(false)
			get_viewport().set_input_as_handled()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and _is_dragging_playhead:
		_finish_playhead_drag(true)


func _update_dragged_progress(mouse_x: float) -> void:
	var usable_width: float = maxf(1.0, size.x - HORIZONTAL_PADDING * 2.0)
	_dragged_progress = clampf((mouse_x - HORIZONTAL_PADDING) / usable_width, 0.0, 1.0)
	_progress_ratio = _dragged_progress
	queue_redraw()


func _finish_playhead_drag(cancelled: bool) -> void:
	if not _is_dragging_playhead:
		return

	_is_dragging_playhead = false

	if cancelled:
		playhead_drag_cancelled.emit(_dragged_progress)
	else:
		playhead_drag_finished.emit(_dragged_progress)
		seek_requested.emit(_dragged_progress)


func _viewport_to_local_x(viewport_position: Vector2) -> float:
	return (get_global_transform_with_canvas().affine_inverse() * viewport_position).x


func _draw_empty_state(start_x: float, center_y: float, usable_width: float) -> void:
	var fallback_font: Font = ThemeDB.fallback_font

	if fallback_font == null:
		return

	draw_string(
		fallback_font,
		Vector2(start_x, center_y - 7.0),
		"暂无波形数据",
		HORIZONTAL_ALIGNMENT_CENTER,
		usable_width,
		12,
		EMPTY_TEXT_COLOR
	)
