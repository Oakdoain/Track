extends Control
class_name InvestigationTimelineView

const TimelineCanvasScript := preload("res://scripts/ui/InvestigationTimelineCanvas.gd")
const FONT_REGULAR := preload("res://assets/fonts/NotoSerifCJKsc-Regular.otf")
const FONT_SEMIBOLD := preload("res://assets/fonts/NotoSerifCJKsc-SemiBold.otf")
const C_BG := Color("#F7F9FF")
const C_BLUE := Color("#143FA4")
const C_TEXT := Color("#26314C")
const C_SUBTEXT := Color("#5B6684")
const C_LINE := Color("#D7DEF3")

var _current_time_label: Label
var _summary_label: Label
var _empty_label: Label
var _scroll: ScrollContainer
var _canvas: InvestigationTimelineCanvas


func _ready() -> void:
	_build()


func render(loader: CaseDataLoader, runtime: CaseRuntimeState, manager: CaseActionManager) -> void:
	if _canvas == null:
		_build()
	var enabled := loader != null and runtime != null and manager != null and manager.is_enabled()
	_empty_label.visible = not enabled
	_scroll.visible = enabled
	if not enabled:
		_current_time_label.text = "当前时间 --:--"
		_summary_label.text = "当前无任务"
		return
	var metadata := loader.get_case_metadata()
	var timeline_value: Variant = metadata.get("timeline", {})
	var timeline: Dictionary = timeline_value if timeline_value is Dictionary else {}
	var roles: Array[Dictionary] = []
	for role_value in timeline.get("roles", []):
		if role_value is Dictionary:
			roles.append((role_value as Dictionary).duplicate(true))
	var tasks: Array[Dictionary] = []
	for history_action in runtime.action_history:
		var completed := history_action.duplicate(true)
		completed["status"] = "completed"
		tasks.append(completed)
	for active_action in runtime.active_actions:
		var active := active_action.duplicate(true)
		active["status"] = "active"
		tasks.append(active)
	var states := {
		"assistant": manager.get_actor_state("assistant"),
		"police": manager.get_actor_state("police")
	}
	_current_time_label.text = "当前时间 %s" % manager.format_time()
	_summary_label.text = "%s｜已完成 %d｜已触发事件 %d" % [
		manager.describe_status(),
		runtime.completed_actions.size(),
		runtime.event_flags.size()
	]
	_canvas.configure(
		roles,
		tasks,
		states,
		int(timeline.get("start_time", 19 * 60)),
		int(timeline.get("end_time", 22 * 60 + 45)),
		runtime.investigation_time
	)


func _build() -> void:
	if _canvas != null:
		return
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 28)
	margin.add_theme_constant_override("margin_right", 28)
	margin.add_theme_constant_override("margin_top", 24)
	margin.add_theme_constant_override("margin_bottom", 24)
	add_child(margin)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 10)
	margin.add_child(layout)
	var title := _label("调查时间轴", 28, C_BLUE, FONT_SEMIBOLD)
	layout.add_child(title)
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)
	layout.add_child(header)
	_current_time_label = _label("当前时间 --:--", 17, C_BLUE, FONT_SEMIBOLD)
	header.add_child(_current_time_label)
	var divider := VSeparator.new()
	divider.add_theme_stylebox_override("separator", _line_style())
	header.add_child(divider)
	_summary_label = _label("当前无任务", 14, C_SUBTEXT, FONT_REGULAR)
	_summary_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(_summary_label)
	var separator := HSeparator.new()
	separator.add_theme_stylebox_override("separator", _line_style())
	layout.add_child(separator)
	_scroll = ScrollContainer.new()
	_scroll.name = "TimelineScroll"
	_scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	layout.add_child(_scroll)
	_style_scrollbar(_scroll.get_h_scroll_bar(), false)
	_style_scrollbar(_scroll.get_v_scroll_bar(), true)
	_canvas = TimelineCanvasScript.new() as InvestigationTimelineCanvas
	_canvas.name = "TimelineCanvas"
	_scroll.add_child(_canvas)
	_empty_label = _label("暂无可展示调度数据", 18, C_SUBTEXT, FONT_REGULAR)
	_empty_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_empty_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_empty_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(_empty_label)


func _label(text: String, font_size: int, color: Color, font: Font) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_override("font", font)
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	return label


func _line_style() -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = C_LINE
	return style


func _style_scrollbar(bar: ScrollBar, vertical: bool) -> void:
	bar.custom_minimum_size = Vector2(8, 0) if vertical else Vector2(0, 8)
	var empty := StyleBoxEmpty.new()
	bar.add_theme_stylebox_override("scroll", empty)
	bar.add_theme_stylebox_override("scroll_focus", empty)
	bar.add_theme_stylebox_override("grabber", _scroll_grabber(Color("#9AADE8")))
	bar.add_theme_stylebox_override("grabber_highlight", _scroll_grabber(C_BLUE))
	bar.add_theme_stylebox_override("grabber_pressed", _scroll_grabber(Color("#0B2F87")))


func _scroll_grabber(color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(2)
	return style
