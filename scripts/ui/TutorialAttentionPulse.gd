extends Node
class_name TutorialAttentionPulse

signal attention_peak(event_id: String)

const ATTENTION_FADE_IN_DURATION := 0.70
const ATTENTION_PEAK_HOLD_DURATION := 0.15
const ATTENTION_FADE_OUT_DURATION := 0.70
const TUTORIAL_ATTENTION_PERIOD := (
	ATTENTION_FADE_IN_DURATION
	+ ATTENTION_PEAK_HOLD_DURATION
	+ ATTENTION_FADE_OUT_DURATION
)
const C_LIGHT_BLUE := Color("#E7ECFA")
const C_ACTIVE_PULSE_BLUE := Color("#3861B7")
const DARK_FILL_LUMINANCE_THRESHOLD := 0.38

var _entries: Dictionary = {}
var _paused: bool = false


func _process(delta: float) -> void:
	if _paused or delta <= 0.0:
		return
	for event_id_value in _entries.keys().duplicate():
		var event_id := str(event_id_value)
		var entry: Dictionary = _entries.get(event_id, {})
		var target: Control = entry.get("target") as Control
		var fill_panel: PanelContainer = entry.get("fill_panel") as PanelContainer
		if not is_instance_valid(target) or not is_instance_valid(fill_panel):
			_entries.erase(event_id)
			continue

		var elapsed := float(entry.get("elapsed", 0.0)) + delta
		entry["elapsed"] = elapsed
		if (
			bool(entry.get("play_audio", true))
			and not bool(entry.get("first_peak_emitted", false))
			and elapsed >= ATTENTION_FADE_IN_DURATION
		):
			entry["first_peak_emitted"] = true
			attention_peak.emit(event_id)

		var interaction := _interaction_control(target)
		if _interaction_overrides_attention(interaction):
			_entries[event_id] = entry
			continue

		var style := _fill_style(fill_panel)
		if style == null:
			_entries.erase(event_id)
			continue
		var base_fill: Color = entry.get("base_fill_color", Color.TRANSPARENT)
		var pulse_fill: Color = entry.get("pulse_fill_color", C_LIGHT_BLUE)
		style.bg_color = base_fill.lerp(pulse_fill, _pulse_weight(elapsed))
		_entries[event_id] = entry


func start_attention(target: Control, event_id: String, play_audio: bool = true) -> void:
	if not is_instance_valid(target) or event_id == "":
		return
	var existing: Dictionary = _entries.get(event_id, {})
	if existing.get("target") == target:
		return
	stop_attention(target)
	stop_attention_event(event_id)
	var fill_panel := _find_fill_panel(target)
	var style := _fill_style(fill_panel)
	if fill_panel == null or style == null:
		push_warning("TutorialAttentionPulse: target has no fill PanelContainer: " + target.name)
		return
	var base_fill := style.bg_color
	_entries[event_id] = {
		"target": target,
		"fill_panel": fill_panel,
		"elapsed": 0.0,
		"first_peak_emitted": false,
		"play_audio": play_audio,
		"base_fill_color": base_fill,
		"base_hover_color": base_fill,
		"base_pressed_color": base_fill,
		"base_disabled_color": base_fill,
		"pulse_fill_color": C_ACTIVE_PULSE_BLUE if base_fill.get_luminance() < DARK_FILL_LUMINANCE_THRESHOLD and base_fill.a > 0.5 else C_LIGHT_BLUE
	}


func stop_attention(target: Control) -> void:
	for event_id_value in _entries.keys().duplicate():
		var entry: Dictionary = _entries.get(event_id_value, {})
		if entry.get("target") == target:
			stop_attention_event(str(event_id_value))


func stop_attention_event(event_id: String) -> void:
	var entry: Dictionary = _entries.get(event_id, {})
	_restore_base_fill(entry)
	_entries.erase(event_id)


func stop_all_attention() -> void:
	for event_id_value in _entries.keys().duplicate():
		stop_attention_event(str(event_id_value))


func set_paused(paused: bool) -> void:
	_paused = paused


func _pulse_weight(elapsed: float) -> float:
	var phase := fmod(maxf(0.0, elapsed), TUTORIAL_ATTENTION_PERIOD)
	if phase < ATTENTION_FADE_IN_DURATION:
		return _smooth_step(phase / ATTENTION_FADE_IN_DURATION)
	phase -= ATTENTION_FADE_IN_DURATION
	if phase < ATTENTION_PEAK_HOLD_DURATION:
		return 1.0
	phase -= ATTENTION_PEAK_HOLD_DURATION
	return 1.0 - _smooth_step(phase / ATTENTION_FADE_OUT_DURATION)


func _smooth_step(value: float) -> float:
	var clamped := clampf(value, 0.0, 1.0)
	return clamped * clamped * (3.0 - 2.0 * clamped)


func _find_fill_panel(target: Control) -> PanelContainer:
	var named_panel := target.get_node_or_null("Panel") as PanelContainer
	if named_panel != null:
		return named_panel
	for child in target.get_children():
		if child is PanelContainer:
			return child as PanelContainer
	return target as PanelContainer


func _fill_style(fill_panel: PanelContainer) -> StyleBoxFlat:
	if not is_instance_valid(fill_panel):
		return null
	return fill_panel.get_theme_stylebox("panel") as StyleBoxFlat


func _interaction_control(target: Control) -> BaseButton:
	if target is BaseButton:
		return target as BaseButton
	var named_button := target.get_node_or_null("HitButton") as BaseButton
	if named_button != null:
		return named_button
	var buttons := target.find_children("*", "BaseButton", true, false)
	return buttons[0] as BaseButton if not buttons.is_empty() else null


func _interaction_overrides_attention(button: BaseButton) -> bool:
	if not is_instance_valid(button):
		return false
	return (
		button.disabled
		or button.is_hovered()
		or button.has_focus()
		or button.button_pressed
		or (button.is_hovered() and Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	)


func _restore_base_fill(entry: Dictionary) -> void:
	var target: Control = entry.get("target") as Control
	var fill_panel: PanelContainer = entry.get("fill_panel") as PanelContainer
	if not is_instance_valid(target) or not is_instance_valid(fill_panel):
		return
	if _interaction_overrides_attention(_interaction_control(target)):
		return
	var style := _fill_style(fill_panel)
	if style != null:
		style.bg_color = entry.get("base_fill_color", style.bg_color)
