extends Control
class_name InvestigationTimelineCanvas

const FONT_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const C_BLUE := Color("#143FA4")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_GRID := Color("#D7DEF3")
const C_GRID_SOFT := Color("#E8ECF8")
const C_CURRENT := Color("#9E2F3E")
const LABEL_WIDTH := 190.0
const TRACK_WIDTH := 820.0
const RULER_HEIGHT := 54.0
const ROW_HEIGHT := 66.0

var _roles: Array[Dictionary] = []
var _tasks: Array[Dictionary] = []
var _actor_states: Dictionary = {}
var _start_time: int = 19 * 60
var _end_time: int = 22 * 60 + 45
var _current_time: int = 19 * 60
var _icon_cache: Dictionary = {}


func configure(
	roles: Array[Dictionary],
	tasks: Array[Dictionary],
	actor_states: Dictionary,
	start_time: int,
	end_time: int,
	current_time: int
) -> void:
	_roles = roles.duplicate(true)
	_tasks = tasks.duplicate(true)
	_actor_states = actor_states.duplicate(true)
	_start_time = start_time
	_end_time = maxi(start_time + 1, end_time)
	_current_time = current_time
	custom_minimum_size = Vector2(LABEL_WIDTH + TRACK_WIDTH, RULER_HEIGHT + ROW_HEIGHT * _roles.size())
	queue_redraw()


func _draw() -> void:
	var track_left := LABEL_WIDTH
	var track_right := LABEL_WIDTH + TRACK_WIDTH
	draw_rect(Rect2(Vector2.ZERO, size), Color("#F7F9FF"))
	draw_line(Vector2(track_left, 0), Vector2(track_left, size.y), C_GRID, 1.0)
	_draw_ruler(track_left, track_right)
	for index in range(_roles.size()):
		_draw_role_row(index, _roles[index], track_left, track_right)
	_draw_current_time(track_left)


func _draw_ruler(track_left: float, track_right: float) -> void:
	for minute in range(_start_time, _end_time + 1, 15):
		var x := _time_x(minute, track_left)
		var major := (minute - _start_time) % 30 == 0 or minute == _end_time
		draw_line(Vector2(x, 25.0 if major else 34.0), Vector2(x, size.y), C_GRID if major else C_GRID_SOFT, 1.0)
		if major:
			draw_string(FONT_REGULAR, Vector2(x - 28.0, 19.0), _format_time(minute), HORIZONTAL_ALIGNMENT_CENTER, 56.0, 13, C_SUBTEXT)
	draw_line(Vector2(track_left, RULER_HEIGHT - 1.0), Vector2(track_right, RULER_HEIGHT - 1.0), C_BLUE, 1.0)
	draw_string(FONT_SEMIBOLD, Vector2(20.0, 34.0), "角色 / 当前状态", HORIZONTAL_ALIGNMENT_LEFT, LABEL_WIDTH - 28.0, 15, C_BLUE)


func _draw_role_row(index: int, role: Dictionary, track_left: float, track_right: float) -> void:
	var top := RULER_HEIGHT + index * ROW_HEIGHT
	var center_y := top + ROW_HEIGHT * 0.5
	var role_id := str(role.get("id", ""))
	var color := Color(str(role.get("color", "#143FA4")))
	if index % 2 == 1:
		draw_rect(Rect2(0.0, top, size.x, ROW_HEIGHT), Color("#F1F5FF"))
	draw_line(Vector2(0.0, top + ROW_HEIGHT), Vector2(track_right, top + ROW_HEIGHT), C_GRID_SOFT, 1.0)
	var icon := _load_icon(str(role.get("icon_key", "contact")))
	if icon != null:
		draw_texture_rect(icon, Rect2(16.0, center_y - 10.0, 20.0, 20.0), false, color)
	draw_string(FONT_SEMIBOLD, Vector2(46.0, top + 27.0), str(role.get("display_name", role_id)), HORIZONTAL_ALIGNMENT_LEFT, 132.0, 15, C_TEXT)
	draw_string(FONT_REGULAR, Vector2(46.0, top + 49.0), _status_text(role_id, role), HORIZONTAL_ALIGNMENT_LEFT, 138.0, 12, C_SUBTEXT)
	for task in _tasks:
		if str(task.get("executor", "")) == role_id:
			_draw_task(task, top, track_left, color)


func _draw_task(task: Dictionary, row_top: float, track_left: float, color: Color) -> void:
	var start := int(task.get("start_time", _current_time))
	var finish := int(task.get("complete_time", start + int(task.get("duration", 0))))
	var x1 := _time_x(clampi(start, _start_time, _end_time), track_left)
	var x2 := _time_x(clampi(finish, _start_time, _end_time), track_left)
	var width := maxf(42.0, x2 - x1)
	if x1 + width > track_left + TRACK_WIDTH:
		width = track_left + TRACK_WIDTH - x1
	var completed := str(task.get("status", "active")) == "completed"
	var fill := color
	fill.a = 0.32 if completed else 0.82
	var rect := Rect2(x1 + 2.0, row_top + 12.0, maxf(1.0, width - 4.0), ROW_HEIGHT - 24.0)
	draw_rect(rect, fill)
	draw_rect(rect, color, false, 1.0)
	var suffix := " · 已完成" if completed else " · 进行中"
	var label := "%s · %d分钟%s" % [str(task.get("action_name", task.get("action_id", "任务"))), int(task.get("duration", maxi(0, finish - start))), suffix]
	draw_string(FONT_REGULAR, Vector2(rect.position.x + 8.0, rect.position.y + 25.0), label, HORIZONTAL_ALIGNMENT_LEFT, maxf(0.0, rect.size.x - 16.0), 12, Color.WHITE if not completed else C_TEXT)


func _draw_current_time(track_left: float) -> void:
	if _current_time < _start_time or _current_time > _end_time:
		return
	var x := _time_x(_current_time, track_left)
	draw_line(Vector2(x, RULER_HEIGHT - 3.0), Vector2(x, size.y), C_CURRENT, 2.0)
	draw_string(FONT_SEMIBOLD, Vector2(x - 31.0, 48.0), _format_time(_current_time), HORIZONTAL_ALIGNMENT_CENTER, 62.0, 12, C_CURRENT)


func _status_text(role_id: String, role: Dictionary) -> String:
	var state_value: Variant = _actor_states.get(role_id, {})
	if state_value is Dictionary:
		var state := state_value as Dictionary
		if str(state.get("status", "idle")) == "busy":
			return "%s · 余%d分钟" % [str(state.get("current_action_name", "执行任务")), int(state.get("remaining_time", 0))]
		if role_id in ["assistant", "police"]:
			return "空闲"
	return str(role.get("status", "当前状态未知"))


func _time_x(minutes: int, track_left: float) -> float:
	return track_left + float(minutes - _start_time) / float(_end_time - _start_time) * TRACK_WIDTH


func _format_time(minutes: int) -> String:
	return "%02d:%02d" % [minutes / 60, minutes % 60]


func _load_icon(icon_key: String) -> Texture2D:
	if _icon_cache.has(icon_key):
		return _icon_cache[icon_key] as Texture2D
	var path := "res://assets/icons/lucide/%s.svg" % icon_key
	var texture := load(path) as Texture2D if ResourceLoader.exists(path) else null
	_icon_cache[icon_key] = texture
	return texture
