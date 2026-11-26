extends Control

# Temporary test assumptions for T2-01 only; not approved balance values.
const ATTEMPT_DURATION_SECONDS := 6.0
const HIT_WINDOW_START_RATIO := 0.40
const HIT_WINDOW_END_RATIO := 0.60

const COLOR_BACKGROUND := Color("#10151d")
const COLOR_PANEL := Color("#19212b")
const COLOR_PANEL_BORDER := Color("#2b3846")
const COLOR_TEXT := Color("#edf1f5")
const COLOR_MUTED := Color("#a6b1bd")
const COLOR_ACCENT := Color("#e6b96b")
const COLOR_EARLY := Color("#6ca9de")
const COLOR_HIT := Color("#72c9a2")
const COLOR_LATE := Color("#e28a79")
const CUMULATIVE_RISK_NOTICE := "累计规则（四个历练节点；派遣不计入节点）：任一节点经确认的高风险选择即把本次历练标记为“失败路线”；只有松风口、沉桥、焦石坡、折锋关四节点全程确认较安全，才能避开这次失败及其损失。预期失败边界为剑折断、阿禾轻伤返庄；结算前尚未发生。"

var elapsed_seconds := 0.0
var attempt_active := true

var timing_track: TimingTrack
var clock_label: Label
var state_label: Label
var result_detail_label: Label
var result_panel: PanelContainer
var strike_button: Button
var retry_button: Button
var dispatch_button: Button
var forge_page: VBoxContainer
var forge_title: Label
var page_center: CenterContainer
var responsive_rows: Array[BoxContainer] = []
var dispatch_page: VBoxContainer
var departure_page: VBoxContainer
var current_result_name := ""
var dispatch_result_label: Label
var departure_status_label: Label
var node_entry_button: Button
var node_continue_button: Button
var node_page: VBoxContainer
var node_result_page: VBoxContainer
var high_risk_panel: PanelContainer
var safer_route_panel: PanelContainer
var high_risk_button: Button
var safer_route_button: Button
var node_confirm_button: Button
var confirmed_route_label: Label
var selected_node_route: int = NodeRoute.NONE
var second_node_page: VBoxContainer
var second_node_result_page: VBoxContainer
var second_high_risk_panel: PanelContainer
var second_safer_route_panel: PanelContainer
var second_high_risk_button: Button
var second_safer_route_button: Button
var second_node_confirm_button: Button
var second_confirmed_route_label: Label
var second_node_selected_route: int = NodeRoute.NONE
var third_node_entry_button: Button
var third_node_page: VBoxContainer
var third_node_result_page: VBoxContainer
var third_high_risk_panel: PanelContainer
var third_safer_route_panel: PanelContainer
var third_high_risk_button: Button
var third_safer_route_button: Button
var third_node_confirm_button: Button
var third_confirmed_route_label: Label
var third_node_selected_route: int = NodeRoute.NONE
var fourth_node_entry_button: Button
var fourth_node_page: VBoxContainer
var fourth_node_result_page: VBoxContainer
var fourth_high_risk_panel: PanelContainer
var fourth_safer_route_panel: PanelContainer
var fourth_high_risk_button: Button
var fourth_safer_route_button: Button
var fourth_node_confirm_button: Button
var fourth_prior_routes_label: Label
var fourth_preconfirm_state_label: Label
var fourth_result_state_label: Label
var fourth_confirmed_route_label: Label
var fourth_node_selected_route: int = NodeRoute.NONE
var fourth_node_blocked := false
var fourth_result_note_label: Label
var t2_08_settlement_panel: PanelContainer
var t2_08_settlement_reason_label: Label
var t2_08_settlement_losses_label: Label

enum NodeRoute { NONE, HIGH_RISK, SAFER }
enum ForgePhase { INITIAL, REFORGE, COMPLETE }

var forge_phase: ForgePhase = ForgePhase.INITIAL


class ExpeditionRunState extends RefCounted:
	const NODE_COUNT := 4
	const ROUTE_UNCONFIRMED := "unconfirmed"
	const ROUTE_HIGH_RISK := "high_risk"
	const ROUTE_SAFER := "safer"
	const STATUS_UNDECIDED := "undecided"
	const STATUS_FAILED_ROUTE := "failed_route"
	const STATUS_ALL_SAFER := "all_safer"

	var _confirmed_routes: Array[String] = [
		ROUTE_UNCONFIRMED, ROUTE_UNCONFIRMED, ROUTE_UNCONFIRMED, ROUTE_UNCONFIRMED
	]

	func confirm_route(node_number: int, route_key: String) -> bool:
		if node_number < 1 or node_number > NODE_COUNT:
			return false
		if route_key != ROUTE_HIGH_RISK and route_key != ROUTE_SAFER:
			return false
		if node_number != _next_confirmation_node():
			return false
		_confirmed_routes[node_number - 1] = route_key
		return true

	func is_route_confirmed(node_number: int) -> bool:
		if node_number < 1 or node_number > NODE_COUNT:
			return false
		return _confirmed_routes[node_number - 1] != ROUTE_UNCONFIRMED

	func get_confirmed_route(node_number: int) -> String:
		if node_number < 1 or node_number > NODE_COUNT:
			return ROUTE_UNCONFIRMED
		return _confirmed_routes[node_number - 1]

	func get_status_key() -> String:
		if _confirmed_routes.has(ROUTE_HIGH_RISK):
			return STATUS_FAILED_ROUTE
		for route_key in _confirmed_routes:
			if route_key != ROUTE_SAFER:
				return STATUS_UNDECIDED
		return STATUS_ALL_SAFER

	func get_snapshot() -> Dictionary:
		return {
			"schema_version": 1,
			"node_order": ["松风口", "沉桥", "焦石坡", "折锋关"],
			"route_codes": [ROUTE_UNCONFIRMED, ROUTE_HIGH_RISK, ROUTE_SAFER],
			"confirmed_routes": _confirmed_routes.duplicate(),
			"status": get_status_key(),
		}

	func _next_confirmation_node() -> int:
		for index in range(NODE_COUNT):
			if _confirmed_routes[index] == ROUTE_UNCONFIRMED:
				return index + 1
		return 0


var expedition_run_state := ExpeditionRunState.new()


class TimingTrack extends Control:
	var progress_ratio := 0.0
	var hit_start_ratio := 0.0
	var hit_end_ratio := 1.0

	func _ready() -> void:
		custom_minimum_size = Vector2(0, 76)
		mouse_filter = Control.MOUSE_FILTER_IGNORE

	func set_timing(progress: float, hit_start: float, hit_end: float) -> void:
		progress_ratio = clampf(progress, 0.0, 1.0)
		hit_start_ratio = hit_start
		hit_end_ratio = hit_end
		queue_redraw()

	func _draw() -> void:
		if size.x <= 0.0:
			return
		var lane_y := 25.0
		var lane_height := 26.0
		var start_x := hit_start_ratio * size.x
		var end_x := hit_end_ratio * size.x
		draw_rect(Rect2(Vector2(0, lane_y), Vector2(size.x, lane_height)), Color("#303b47"), true)
		draw_rect(Rect2(Vector2(start_x, lane_y), Vector2(end_x - start_x, lane_height)), COLOR_HIT, true)
		draw_line(Vector2(start_x, lane_y - 5.0), Vector2(start_x, lane_y + lane_height + 5.0), Color("#c7f0db"), 2.0, true)
		draw_line(Vector2(end_x, lane_y - 5.0), Vector2(end_x, lane_y + lane_height + 5.0), Color("#c7f0db"), 2.0, true)
		var marker_x := progress_ratio * size.x
		draw_line(Vector2(marker_x, 9.0), Vector2(marker_x, lane_y + lane_height + 10.0), COLOR_TEXT, 3.0, true)
		draw_circle(Vector2(marker_x, 9.0), 6.0, COLOR_ACCENT)


func _ready() -> void:
	# A newly loaded scene always starts a fresh in-memory round; no browser state is read.
	expedition_run_state = ExpeditionRunState.new()
	_build_interface()
	_reset_attempt()


# T2-07 runtime contract v1: read a copy with get_expedition_state_snapshot();
# confirm node 4 through confirm_expedition_route(4, "high_risk" or "safer").
func get_expedition_state_snapshot() -> Dictionary:
	return expedition_run_state.get_snapshot()


func confirm_expedition_route(node_number: int, route_key: String) -> bool:
	return expedition_run_state.confirm_route(node_number, route_key)


func _process(delta: float) -> void:
	if not attempt_active:
		return
	elapsed_seconds = minf(elapsed_seconds + delta, ATTEMPT_DURATION_SECONDS)
	_update_timing_display()
	if elapsed_seconds >= ATTEMPT_DURATION_SECONDS:
		_resolve_result("偏晚", "计时结束仍未落锤，本次记为偏晚。", COLOR_LATE, false)


func _build_interface() -> void:
	var background := ColorRect.new()
	background.color = COLOR_BACKGROUND
	background.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	var scroll := ScrollContainer.new()
	scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	scroll.offset_left = 12
	scroll.offset_right = -12
	scroll.offset_top = 12
	scroll.offset_bottom = -12
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.scroll_deadzone = 10
	scroll.follow_focus = true
	add_child(scroll)

	page_center = CenterContainer.new()
	page_center.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page_center.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var demo_theme := Theme.new()
	demo_theme.default_font = load("res://assets/fonts/internal-demo-zh.otf") as Font
	demo_theme.default_font_size = 16
	page_center.theme = demo_theme
	scroll.add_child(page_center)

	var page := VBoxContainer.new()
	forge_page = page
	page.custom_minimum_size = Vector2(820, 0)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	page.add_theme_constant_override("separation", 14)
	page_center.add_child(page)

	var eyebrow := _make_label("铸剑山庄", 14, COLOR_ACCENT)
	page.add_child(eyebrow)

	forge_title = _make_label("单次落锤", 36, COLOR_TEXT)
	page.add_child(forge_title)

	var intro := _make_label("观察移动标记，在高亮窗口内主动落锤一次。结果只依据可见时机。", 16, COLOR_MUTED)
	page.add_child(intro)

	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 18))
	page.add_child(card)

	var content_margin := MarginContainer.new()
	content_margin.add_theme_constant_override("margin_left", 26)
	content_margin.add_theme_constant_override("margin_right", 26)
	content_margin.add_theme_constant_override("margin_top", 22)
	content_margin.add_theme_constant_override("margin_bottom", 22)
	card.add_child(content_margin)

	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	content_margin.add_child(content)

	var section_title := _make_label("时机轨道", 19, COLOR_TEXT)
	content.add_child(section_title)

	var instruction := _make_label("标记从左向右移动；落在高亮区之前为偏早，经过高亮区为命中，越过后为偏晚。", 14, COLOR_MUTED)
	instruction.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	content.add_child(instruction)

	timing_track = TimingTrack.new()
	timing_track.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(timing_track)

	clock_label = _make_label("经过 0.0 秒 / %.1f 秒" % ATTEMPT_DURATION_SECONDS, 13, COLOR_MUTED)
	content.add_child(clock_label)

	var legend := HBoxContainer.new()
	legend.add_theme_constant_override("separation", 20)
	content.add_child(legend)
	legend.add_child(_make_label("偏早：窗口前", 13, COLOR_EARLY))
	legend.add_child(_make_label("命中：高亮区", 13, COLOR_HIT))
	legend.add_child(_make_label("偏晚：窗口后", 13, COLOR_LATE))
	for item in legend.get_children():
		item.autowrap_mode = TextServer.AUTOWRAP_OFF

	strike_button = Button.new()
	strike_button.text = "落锤（本轮一次）"
	strike_button.custom_minimum_size = Vector2(0, 54)
	strike_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	strike_button.add_theme_font_size_override("font_size", 18)
	strike_button.add_theme_color_override("font_color", Color("#18211e"))
	strike_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	strike_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	strike_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), Color("#8bd6b2"), 1, 12))
	strike_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), Color("#5caf8a"), 1, 12))
	strike_button.pressed.connect(_on_strike_pressed)
	content.add_child(strike_button)

	state_label = _make_label("观察中：等待你主动落锤。", 16, COLOR_ACCENT)
	content.add_child(state_label)

	result_panel = PanelContainer.new()
	result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#202a34"), COLOR_PANEL_BORDER, 1, 10))
	content.add_child(result_panel)
	var result_margin := MarginContainer.new()
	result_margin.add_theme_constant_override("margin_left", 14)
	result_margin.add_theme_constant_override("margin_right", 14)
	result_margin.add_theme_constant_override("margin_top", 10)
	result_margin.add_theme_constant_override("margin_bottom", 10)
	result_panel.add_child(result_margin)
	result_detail_label = _make_label("每轮只可落锤一次。计时结束仍未操作会显示“偏晚”；结果后可手动重试。", 14, COLOR_MUTED)
	result_detail_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result_margin.add_child(result_detail_label)

	retry_button = Button.new()
	retry_button.text = "再试一次"
	retry_button.custom_minimum_size = Vector2(0, 46)
	retry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	retry_button.add_theme_font_size_override("font_size", 16)
	retry_button.add_theme_color_override("font_color", COLOR_TEXT)
	retry_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	retry_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	retry_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	retry_button.pressed.connect(_reset_attempt)
	content.add_child(retry_button)

	dispatch_button = Button.new()
	dispatch_button.text = "查看派遣简报"
	dispatch_button.custom_minimum_size = Vector2(0, 50)
	dispatch_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_button.add_theme_font_size_override("font_size", 17)
	dispatch_button.add_theme_color_override("font_color", Color("#18211e"))
	dispatch_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	dispatch_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	dispatch_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), Color("#f0c982"), 1, 12))
	dispatch_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#c99d54"), Color("#c99d54"), 1, 12))
	dispatch_button.pressed.connect(_show_dispatch_brief)
	dispatch_button.visible = false
	content.add_child(dispatch_button)

	_build_dispatch_pages(page_center)
	page_center.mouse_filter = Control.MOUSE_FILTER_PASS
	for container in page_center.find_children("*", "Container", true, false):
		container.mouse_filter = Control.MOUSE_FILTER_PASS
	for screen in page_center.get_children():
		screen.visibility_changed.connect(func():
			if screen.visible:
				scroll.set_deferred("scroll_vertical", 0)
		)
	get_viewport().size_changed.connect(_adapt_layout)
	_adapt_layout()


func _make_responsive_row() -> BoxContainer:
	var row := BoxContainer.new()
	responsive_rows.append(row)
	return row


func _adapt_layout() -> void:
	var available_width := get_viewport_rect().size.x
	for screen in page_center.get_children():
		screen.custom_minimum_size.x = clampf(available_width - 44, 0, 820)
	for row in responsive_rows:
		row.vertical = available_width < 600


func _make_label(text_value: String, font_size: int, font_color: Color) -> Label:
	var label := Label.new()
	label.text = text_value
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", font_color)
	return label


func _make_panel_style(fill_color: Color, border_color: Color, border_width: int, corner_radius: int) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(border_width)
	style.set_corner_radius_all(corner_radius)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 8.0
	style.content_margin_bottom = 8.0
	return style


func _update_timing_display() -> void:
	if is_instance_valid(timing_track):
		timing_track.set_timing(elapsed_seconds / ATTEMPT_DURATION_SECONDS, HIT_WINDOW_START_RATIO, HIT_WINDOW_END_RATIO)
	if is_instance_valid(clock_label):
		clock_label.text = "经过 %.1f 秒 / %.1f 秒" % [elapsed_seconds, ATTEMPT_DURATION_SECONDS]


func _on_strike_pressed() -> void:
	if not attempt_active:
		return
	var result_name := "偏晚"
	var result_description := "落锤发生在高亮窗口之后，本次记为偏晚。"
	var result_color := COLOR_LATE
	if elapsed_seconds < ATTEMPT_DURATION_SECONDS * HIT_WINDOW_START_RATIO:
		result_name = "偏早"
		result_description = "落锤发生在高亮窗口之前，本次记为偏早。"
		result_color = COLOR_EARLY
	elif elapsed_seconds <= ATTEMPT_DURATION_SECONDS * HIT_WINDOW_END_RATIO:
		result_name = "命中"
		result_description = "落锤发生在高亮窗口内，本次记为命中。"
		result_color = COLOR_HIT
	_resolve_result(result_name, result_description, result_color, true)


func _resolve_result(result_name: String, result_description: String, result_color: Color, struck: bool) -> void:
	attempt_active = false
	current_result_name = result_name
	strike_button.disabled = true
	strike_button.text = "本轮已落锤" if struck else "本轮已结束"
	retry_button.visible = true
	dispatch_button.visible = forge_phase == ForgePhase.INITIAL and struck
	state_label.text = "结果：" + result_name
	state_label.add_theme_color_override("font_color", result_color)
	result_detail_label.text = result_description + " 可点击“再试一次”重新开始。"
	result_detail_label.add_theme_color_override("font_color", COLOR_TEXT)
	result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#202a34"), result_color, 2, 10))
	print("[T2-01] result=%s elapsed=%.3f s" % [result_name, elapsed_seconds])
	if forge_phase == ForgePhase.REFORGE and struck:
		forge_phase = ForgePhase.COMPLETE
		forge_title.text = "Demo 结束"
		state_label.text = "新剑已铸成：" + result_name
		result_detail_label.text = result_description + " 刷新页面可以重新体验。"
		retry_button.hide()
		print("[T2-09] reforge=complete result=%s" % result_name)


func _reset_attempt() -> void:
	if forge_phase == ForgePhase.COMPLETE:
		return
	elapsed_seconds = 0.0
	attempt_active = true
	current_result_name = ""
	if is_instance_valid(strike_button):
		strike_button.disabled = false
		strike_button.text = "落锤（本轮一次）"
	if is_instance_valid(dispatch_button):
		dispatch_button.visible = false
	if is_instance_valid(retry_button):
		retry_button.visible = false
	if is_instance_valid(state_label):
		state_label.text = "观察中：等待你主动落锤。"
		state_label.add_theme_color_override("font_color", COLOR_ACCENT)
	if is_instance_valid(result_detail_label):
		result_detail_label.text = "每轮只可落锤一次。计时结束仍未操作会显示“偏晚”；结果后可手动重试。"
		result_detail_label.add_theme_color_override("font_color", COLOR_MUTED)
	if is_instance_valid(result_panel):
		result_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#202a34"), COLOR_PANEL_BORDER, 1, 10))
	_update_timing_display()


func _start_reforge() -> void:
	if forge_phase != ForgePhase.INITIAL or not t2_08_settlement_panel.is_visible_in_tree():
		return
	forge_phase = ForgePhase.REFORGE
	fourth_node_result_page.hide()
	forge_title.text = "重铸新剑"
	forge_page.show()
	_reset_attempt()
	print("[T2-09] reforge=started")


func _build_dispatch_pages(center: CenterContainer) -> void:
	dispatch_page = VBoxContainer.new()
	dispatch_page.custom_minimum_size = Vector2(820, 0)
	dispatch_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	dispatch_page.add_theme_constant_override("separation", 14)
	dispatch_page.visible = false
	center.add_child(dispatch_page)

	dispatch_page.add_child(_make_label("T2-02  /  派遣准备", 14, COLOR_ACCENT))
	dispatch_page.add_child(_make_label("出发简报", 36, COLOR_TEXT))
	var intro := _make_label("这把剑将由阿禾带往折锋谷。", 16, COLOR_MUTED)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dispatch_page.add_child(intro)

	var summary_panel := PanelContainer.new()
	summary_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	dispatch_page.add_child(summary_panel)
	var summary_margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		summary_margin.add_theme_constant_override("margin_" + margin_name, 20)
	for margin_name in ["top", "bottom"]:
		summary_margin.add_theme_constant_override("margin_" + margin_name, 16)
	summary_panel.add_child(summary_margin)
	var summary_content := VBoxContainer.new()
	summary_content.add_theme_constant_override("separation", 8)
	summary_margin.add_child(summary_content)
	summary_content.add_child(_make_label("派遣对象：阿禾  |  历练地：折锋谷", 17, COLOR_TEXT))
	dispatch_result_label = _make_label("当前这把剑的锻造结果：", 17, COLOR_ACCENT)
	summary_content.add_child(dispatch_result_label)
	var result_note := _make_label("此结果是锻造反馈，不是剑属性；不会改变上述风险。", 13, COLOR_MUTED)
	result_note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	summary_content.add_child(result_note)

	dispatch_page.add_child(_make_cumulative_risk_notice())
	var risk_row := _make_responsive_row()
	risk_row.add_theme_constant_override("separation", 12)
	dispatch_page.add_child(risk_row)
	risk_row.add_child(_make_dispatch_risk_card(
		"高风险路线",
		"若选择已批准的高风险路线，按公开规则，这把剑可折断，阿禾可轻伤返庄。",
		COLOR_LATE
	))
	risk_row.add_child(_make_dispatch_risk_card(
		"较安全路线",
		"较安全路线可避开这次失败及其损失；不保证成功。",
		COLOR_HIT
	))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	dispatch_page.add_child(action_row)
	var back_button := Button.new()
	back_button.text = "返回锻造"
	back_button.custom_minimum_size = Vector2(0, 52)
	back_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	back_button.add_theme_font_size_override("font_size", 17)
	back_button.add_theme_color_override("font_color", COLOR_TEXT)
	back_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	back_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	back_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	back_button.pressed.connect(_return_to_forge)
	action_row.add_child(back_button)

	var confirm_button := Button.new()
	confirm_button.text = "确认出发"
	confirm_button.custom_minimum_size = Vector2(0, 52)
	confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	confirm_button.add_theme_font_size_override("font_size", 17)
	confirm_button.add_theme_color_override("font_color", Color("#18211e"))
	confirm_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	confirm_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	confirm_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), Color("#8bd6b2"), 1, 12))
	confirm_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), Color("#5caf8a"), 1, 12))
	confirm_button.pressed.connect(_confirm_dispatch)
	action_row.add_child(confirm_button)

	departure_page = VBoxContainer.new()
	departure_page.custom_minimum_size = Vector2(820, 0)
	departure_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	departure_page.add_theme_constant_override("separation", 14)
	departure_page.visible = false
	center.add_child(departure_page)
	departure_page.add_child(_make_label("T2-02  /  已确认", 14, COLOR_ACCENT))
	departure_page.add_child(_make_label("阿禾已出发", 36, COLOR_TEXT))
	departure_status_label = _make_label("", 19, COLOR_HIT)
	departure_page.add_child(departure_status_label)
	node_entry_button = Button.new()
	node_entry_button.text = "前往 01"
	node_entry_button.custom_minimum_size = Vector2(0, 52)
	node_entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_entry_button.add_theme_font_size_override("font_size", 17)
	node_entry_button.add_theme_color_override("font_color", Color("#18211e"))
	node_entry_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	node_entry_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	node_entry_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), Color("#f0c982"), 1, 12))
	node_entry_button.pressed.connect(_show_node_choice)
	departure_page.add_child(node_entry_button)

	node_page = VBoxContainer.new()
	node_page.custom_minimum_size = Vector2(820, 0)
	node_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_page.add_theme_constant_override("separation", 14)
	node_page.visible = false
	center.add_child(node_page)
	node_page.add_child(_make_label("01", 36, COLOR_TEXT))
	node_page.add_child(_make_label("路线选择", 20, COLOR_ACCENT))
	node_page.add_child(_make_cumulative_risk_notice())

	var route_row := _make_responsive_row()
	route_row.add_theme_constant_override("separation", 12)
	node_page.add_child(route_row)
	route_row.add_child(_make_node_route_card(
		"高风险路线：",
		"剑可折断；阿禾可轻伤返庄。",
		NodeRoute.HIGH_RISK,
		COLOR_LATE
	))
	route_row.add_child(_make_node_route_card(
		"较安全路线：",
		"可避开这次失败及其损失；不保证成功。",
		NodeRoute.SAFER,
		COLOR_HIT
	))

	var node_action_row := HBoxContainer.new()
	node_action_row.add_theme_constant_override("separation", 12)
	node_page.add_child(node_action_row)
	var return_button := Button.new()
	return_button.text = "返回派遣"
	return_button.custom_minimum_size = Vector2(0, 52)
	return_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_button.add_theme_font_size_override("font_size", 17)
	return_button.add_theme_color_override("font_color", COLOR_TEXT)
	return_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	return_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	return_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	return_button.pressed.connect(_return_to_departure)
	node_action_row.add_child(return_button)

	node_confirm_button = Button.new()
	node_confirm_button.text = "确认路线"
	node_confirm_button.custom_minimum_size = Vector2(0, 52)
	node_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_confirm_button.add_theme_font_size_override("font_size", 17)
	node_confirm_button.add_theme_color_override("font_color", Color("#18211e"))
	node_confirm_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	node_confirm_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	node_confirm_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), Color("#8bd6b2"), 1, 12))
	node_confirm_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), Color("#5caf8a"), 1, 12))
	node_confirm_button.pressed.connect(_confirm_node_route)
	node_action_row.add_child(node_confirm_button)

	node_result_page = VBoxContainer.new()
	node_result_page.custom_minimum_size = Vector2(820, 0)
	node_result_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_result_page.add_theme_constant_override("separation", 14)
	node_result_page.visible = false
	center.add_child(node_result_page)
	confirmed_route_label = _make_label("已选择路线：", 22, COLOR_HIT)
	node_result_page.add_child(confirmed_route_label)
	node_continue_button = Button.new()
	node_continue_button.text = "前往 02"
	node_continue_button.custom_minimum_size = Vector2(0, 52)
	node_continue_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	node_continue_button.add_theme_font_size_override("font_size", 17)
	node_continue_button.add_theme_color_override("font_color", Color("#18211e"))
	node_continue_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	node_continue_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	node_continue_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), Color("#f0c982"), 1, 12))
	node_continue_button.pressed.connect(_show_second_node_choice)
	node_result_page.add_child(node_continue_button)
	_build_second_node_pages(center)
	_build_third_node_pages(center)
	_build_fourth_node_pages(center)


func _build_second_node_pages(center: CenterContainer) -> void:
	second_node_page = VBoxContainer.new()
	second_node_page.custom_minimum_size = Vector2(820, 0)
	second_node_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_node_page.add_theme_constant_override("separation", 14)
	second_node_page.visible = false
	center.add_child(second_node_page)
	second_node_page.add_child(_make_label("02", 36, COLOR_TEXT))
	second_node_page.add_child(_make_label("路线选择", 20, COLOR_ACCENT))
	second_node_page.add_child(_make_label("折锋谷历练：01之后是02。", 16, COLOR_MUTED))
	second_node_page.add_child(_make_cumulative_risk_notice())

	var second_route_row := _make_responsive_row()
	second_route_row.add_theme_constant_override("separation", 12)
	second_node_page.add_child(second_route_row)
	second_route_row.add_child(_make_node_route_card(
		"高风险路线：",
		"高风险路线：剑可折断；阿禾可轻伤返庄。",
		NodeRoute.HIGH_RISK,
		COLOR_LATE,
		true
	))
	second_route_row.add_child(_make_node_route_card(
		"较安全路线：",
		"较安全路线可避开这次失败及其损失；不保证成功。",
		NodeRoute.SAFER,
		COLOR_HIT,
		true
	))

	var second_node_action_row := HBoxContainer.new()
	second_node_action_row.add_theme_constant_override("separation", 12)
	second_node_page.add_child(second_node_action_row)
	var previous_node_button := Button.new()
	previous_node_button.text = "返回上一节点"
	previous_node_button.custom_minimum_size = Vector2(0, 52)
	previous_node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous_node_button.add_theme_font_size_override("font_size", 17)
	previous_node_button.add_theme_color_override("font_color", COLOR_TEXT)
	previous_node_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	previous_node_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	previous_node_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	previous_node_button.pressed.connect(_return_to_previous_node)
	second_node_action_row.add_child(previous_node_button)

	second_node_confirm_button = Button.new()
	second_node_confirm_button.text = "确认路线"
	second_node_confirm_button.custom_minimum_size = Vector2(0, 52)
	second_node_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_node_confirm_button.add_theme_font_size_override("font_size", 17)
	second_node_confirm_button.add_theme_color_override("font_color", Color("#18211e"))
	second_node_confirm_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	second_node_confirm_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	second_node_confirm_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), Color("#8bd6b2"), 1, 12))
	second_node_confirm_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), Color("#5caf8a"), 1, 12))
	second_node_confirm_button.pressed.connect(_confirm_second_node_route)
	second_node_action_row.add_child(second_node_confirm_button)

	second_node_result_page = VBoxContainer.new()
	second_node_result_page.custom_minimum_size = Vector2(820, 0)
	second_node_result_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	second_node_result_page.add_theme_constant_override("separation", 14)
	second_node_result_page.visible = false
	center.add_child(second_node_result_page)
	second_confirmed_route_label = _make_label("已选择路线：", 22, COLOR_HIT)
	second_node_result_page.add_child(second_confirmed_route_label)
	var second_placeholder_panel := PanelContainer.new()
	second_placeholder_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	second_node_result_page.add_child(second_placeholder_panel)
	var second_placeholder_margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		second_placeholder_margin.add_theme_constant_override("margin_" + margin_name, 20)
	for margin_name in ["top", "bottom"]:
		second_placeholder_margin.add_theme_constant_override("margin_" + margin_name, 18)
	second_placeholder_panel.add_child(second_placeholder_margin)
	var second_placeholder := _make_label("路线已确认。下一站是焦石坡。", 16, COLOR_MUTED)
	second_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	second_placeholder_margin.add_child(second_placeholder)

	third_node_entry_button = Button.new()
	third_node_entry_button.text = "前往 03"
	third_node_entry_button.custom_minimum_size = Vector2(0, 52)
	third_node_entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	third_node_entry_button.add_theme_font_size_override("font_size", 17)
	third_node_entry_button.add_theme_color_override("font_color", Color("#18211e"))
	third_node_entry_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	third_node_entry_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	third_node_entry_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), Color("#f0c982"), 1, 12))
	third_node_entry_button.pressed.connect(_show_third_node_choice)
	second_node_result_page.add_child(third_node_entry_button)


func _build_third_node_pages(center: CenterContainer) -> void:
	# T2-05 is 焦石坡; the runtime heading remains "03".
	third_node_page = VBoxContainer.new()
	third_node_page.custom_minimum_size = Vector2(820, 0)
	third_node_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	third_node_page.add_theme_constant_override("separation", 14)
	third_node_page.visible = false
	center.add_child(third_node_page)
	third_node_page.add_child(_make_label("焦石坡", 14, COLOR_ACCENT))
	third_node_page.add_child(_make_label("03", 36, COLOR_TEXT))
	third_node_page.add_child(_make_label("折锋谷历练：从已确认的 02 进入第三节点。弟子：阿禾。", 16, COLOR_MUTED))
	third_node_page.add_child(_make_label("路线选择", 20, COLOR_ACCENT))
	third_node_page.add_child(_make_cumulative_risk_notice())

	var third_route_row := _make_responsive_row()
	third_route_row.add_theme_constant_override("separation", 12)
	third_node_page.add_child(third_route_row)
	third_route_row.add_child(_make_third_node_route_card(
		"高风险路线",
		"这条路线后续可能导致剑折断、阿禾轻伤返庄。",
		NodeRoute.HIGH_RISK,
		COLOR_LATE
	))
	third_route_row.add_child(_make_third_node_route_card(
		"较安全路线",
		"较安全路线保留避开这次失败及其损失的可能；不保证成功。",
		NodeRoute.SAFER,
		COLOR_HIT
	))

	var third_action_row := HBoxContainer.new()
	third_action_row.add_theme_constant_override("separation", 12)
	third_node_page.add_child(third_action_row)
	var return_to_second_button := Button.new()
	return_to_second_button.text = "返回 02"
	return_to_second_button.custom_minimum_size = Vector2(0, 52)
	return_to_second_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return_to_second_button.add_theme_font_size_override("font_size", 17)
	return_to_second_button.add_theme_color_override("font_color", COLOR_TEXT)
	return_to_second_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	return_to_second_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	return_to_second_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	return_to_second_button.pressed.connect(_return_to_second_node)
	third_action_row.add_child(return_to_second_button)

	third_node_confirm_button = Button.new()
	third_node_confirm_button.text = "确认路线"
	third_node_confirm_button.custom_minimum_size = Vector2(0, 52)
	third_node_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	third_node_confirm_button.add_theme_font_size_override("font_size", 17)
	third_node_confirm_button.add_theme_color_override("font_color", Color("#18211e"))
	third_node_confirm_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	third_node_confirm_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	third_node_confirm_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), Color("#8bd6b2"), 1, 12))
	third_node_confirm_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), Color("#5caf8a"), 1, 12))
	third_node_confirm_button.pressed.connect(_confirm_third_node_route)
	third_action_row.add_child(third_node_confirm_button)

	third_node_result_page = VBoxContainer.new()
	third_node_result_page.custom_minimum_size = Vector2(820, 0)
	third_node_result_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	third_node_result_page.add_theme_constant_override("separation", 14)
	third_node_result_page.visible = false
	center.add_child(third_node_result_page)
	third_confirmed_route_label = _make_label("已选择路线：", 22, COLOR_HIT)
	third_node_result_page.add_child(third_confirmed_route_label)
	var third_placeholder_panel := PanelContainer.new()
	third_placeholder_panel.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	third_node_result_page.add_child(third_placeholder_panel)
	var third_placeholder_margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		third_placeholder_margin.add_theme_constant_override("margin_" + margin_name, 20)
	for margin_name in ["top", "bottom"]:
		third_placeholder_margin.add_theme_constant_override("margin_" + margin_name, 18)
	third_placeholder_panel.add_child(third_placeholder_margin)
	var third_placeholder := _make_label("路线已确认。继续前往折锋关，历练结果将在那里揭晓。", 16, COLOR_MUTED)
	third_placeholder.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	third_placeholder_margin.add_child(third_placeholder)

	fourth_node_entry_button = Button.new()
	fourth_node_entry_button.text = "前往折锋关（04）"
	fourth_node_entry_button.custom_minimum_size = Vector2(0, 52)
	fourth_node_entry_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fourth_node_entry_button.add_theme_font_size_override("font_size", 17)
	fourth_node_entry_button.add_theme_color_override("font_color", Color("#18211e"))
	fourth_node_entry_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	fourth_node_entry_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	fourth_node_entry_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), COLOR_ACCENT, 1, 12))
	fourth_node_entry_button.pressed.connect(_show_fourth_node_choice)
	third_node_result_page.add_child(fourth_node_entry_button)


func _build_fourth_node_pages(center: CenterContainer) -> void:
	fourth_node_page = VBoxContainer.new()
	fourth_node_page.custom_minimum_size = Vector2(820, 0)
	fourth_node_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fourth_node_page.add_theme_constant_override("separation", 12)
	fourth_node_page.visible = false
	center.add_child(fourth_node_page)
	fourth_node_page.add_child(_make_label("折锋关", 14, COLOR_ACCENT))
	fourth_node_page.add_child(_make_label("04  /  第四个历练节点", 32, COLOR_TEXT))
	fourth_node_page.add_child(_make_label("折锋谷历练的最后一个节点；出发简报不计入四个节点。", 15, COLOR_MUTED))
	fourth_node_page.add_child(_make_cumulative_risk_notice())
	fourth_prior_routes_label = _make_label("前三节点已确认路线：", 14, COLOR_MUTED)
	fourth_prior_routes_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fourth_node_page.add_child(fourth_prior_routes_label)
	fourth_preconfirm_state_label = _make_label("当前权威状态：未定", 16, COLOR_ACCENT)
	fourth_node_page.add_child(fourth_preconfirm_state_label)

	var route_row := _make_responsive_row()
	route_row.add_theme_constant_override("separation", 12)
	fourth_node_page.add_child(route_row)
	route_row.add_child(_make_fourth_node_route_card(
		"高风险路线",
		"按已披露边界，本次历练可能导致剑折断、阿禾轻伤返庄；本页不执行结算。",
		NodeRoute.HIGH_RISK,
		COLOR_LATE
	))
	route_row.add_child(_make_fourth_node_route_card(
		"较安全路线",
		"只有四节点全程确认较安全，才能避开这次失败及其损失；不保证其他方面成功。",
		NodeRoute.SAFER,
		COLOR_HIT
	))

	var action_row := HBoxContainer.new()
	action_row.add_theme_constant_override("separation", 12)
	fourth_node_page.add_child(action_row)
	var previous_node_button := Button.new()
	previous_node_button.text = "返回 03"
	previous_node_button.custom_minimum_size = Vector2(0, 50)
	previous_node_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	previous_node_button.add_theme_font_size_override("font_size", 17)
	previous_node_button.add_theme_color_override("font_color", COLOR_TEXT)
	previous_node_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	previous_node_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#303b47"), Color("#526170"), 1, 12))
	previous_node_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#3a4856"), Color("#718293"), 1, 12))
	previous_node_button.pressed.connect(_return_to_third_node)
	action_row.add_child(previous_node_button)

	fourth_node_confirm_button = Button.new()
	fourth_node_confirm_button.text = "确认路线"
	fourth_node_confirm_button.disabled = true
	fourth_node_confirm_button.custom_minimum_size = Vector2(0, 50)
	fourth_node_confirm_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fourth_node_confirm_button.add_theme_font_size_override("font_size", 17)
	fourth_node_confirm_button.add_theme_color_override("font_color", Color("#18211e"))
	fourth_node_confirm_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	fourth_node_confirm_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_HIT, COLOR_HIT, 1, 12))
	fourth_node_confirm_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#8bd6b2"), COLOR_HIT, 1, 12))
	fourth_node_confirm_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#5caf8a"), COLOR_HIT, 1, 12))
	fourth_node_confirm_button.pressed.connect(_confirm_fourth_node_route)
	action_row.add_child(fourth_node_confirm_button)

	fourth_node_result_page = VBoxContainer.new()
	fourth_node_result_page.custom_minimum_size = Vector2(820, 0)
	fourth_node_result_page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fourth_node_result_page.add_theme_constant_override("separation", 14)
	fourth_node_result_page.visible = false
	center.add_child(fourth_node_result_page)
	fourth_confirmed_route_label = _make_label("已确认路线：", 22, COLOR_HIT)
	fourth_node_result_page.add_child(fourth_confirmed_route_label)
	fourth_result_note_label = _make_label("本页只记录第四节点路线并显示同一历练状态；不发生返程／交接、伤害、剑折断或结果结算。", 16, COLOR_MUTED)
	fourth_result_note_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fourth_node_result_page.add_child(fourth_result_note_label)
	fourth_result_state_label = _make_label("权威状态：", 18, COLOR_ACCENT)
	fourth_result_state_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fourth_node_result_page.add_child(fourth_result_state_label)
	t2_08_settlement_panel = PanelContainer.new()
	t2_08_settlement_panel.visible = false
	t2_08_settlement_panel.add_theme_stylebox_override("panel", _make_panel_style(Color("#202a34"), COLOR_LATE, 2, 14))
	fourth_node_result_page.add_child(t2_08_settlement_panel)
	var settlement_margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		settlement_margin.add_theme_constant_override("margin_" + margin_name, 20)
	for margin_name in ["top", "bottom"]:
		settlement_margin.add_theme_constant_override("margin_" + margin_name, 16)
	t2_08_settlement_panel.add_child(settlement_margin)
	var settlement_content := VBoxContainer.new()
	settlement_content.add_theme_constant_override("separation", 8)
	settlement_margin.add_child(settlement_content)
	settlement_content.add_child(_make_label("失败路线结算", 20, COLOR_LATE))
	t2_08_settlement_reason_label = _make_label("", 16, COLOR_TEXT)
	t2_08_settlement_reason_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settlement_content.add_child(t2_08_settlement_reason_label)
	t2_08_settlement_losses_label = _make_label("", 17, COLOR_TEXT)
	t2_08_settlement_losses_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	settlement_content.add_child(t2_08_settlement_losses_label)
	var reforge_button := Button.new()
	reforge_button.name = "ReforgeButton"
	reforge_button.text = "回山庄重铸"
	reforge_button.custom_minimum_size.y = 52
	reforge_button.add_theme_font_size_override("font_size", 18)
	reforge_button.add_theme_color_override("font_color", Color("#18211e"))
	reforge_button.add_theme_color_override("font_hover_color", Color("#18211e"))
	reforge_button.add_theme_stylebox_override("normal", _make_panel_style(COLOR_ACCENT, COLOR_ACCENT, 1, 12))
	reforge_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#f0c982"), Color("#f0c982"), 1, 12))
	reforge_button.pressed.connect(_start_reforge)
	settlement_content.add_child(reforge_button)


func _make_fourth_node_route_card(title_text: String, body_text: String, route_id: int, accent_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	var margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + margin_name, 18)
	for margin_name in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 14)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 10)
	margin.add_child(content)
	var choice_button := Button.new()
	choice_button.text = title_text
	choice_button.custom_minimum_size = Vector2(0, 48)
	choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_button.toggle_mode = true
	choice_button.add_theme_font_size_override("font_size", 17)
	choice_button.add_theme_color_override("font_color", COLOR_TEXT)
	choice_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	choice_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#27323d"), COLOR_PANEL_BORDER, 1, 10))
	choice_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#303b47"), accent_color, 1, 10))
	choice_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#303b47"), accent_color, 2, 10))
	choice_button.pressed.connect(_select_fourth_node_route.bind(route_id))
	content.add_child(choice_button)
	var body := _make_label(body_text, 15, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	if route_id == NodeRoute.HIGH_RISK:
		fourth_high_risk_panel = card
		fourth_high_risk_button = choice_button
	else:
		fourth_safer_route_panel = card
		fourth_safer_route_button = choice_button
	return card


func _make_third_node_route_card(title_text: String, body_text: String, route_id: int, accent_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	var margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + margin_name, 18)
	for margin_name in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 16)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var choice_button := Button.new()
	choice_button.text = title_text
	choice_button.custom_minimum_size = Vector2(0, 48)
	choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_button.toggle_mode = true
	choice_button.add_theme_font_size_override("font_size", 17)
	choice_button.add_theme_color_override("font_color", COLOR_TEXT)
	choice_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	choice_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#27323d"), COLOR_PANEL_BORDER, 1, 10))
	choice_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#303b47"), accent_color, 1, 10))
	choice_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#303b47"), accent_color, 2, 10))
	choice_button.pressed.connect(_select_third_node_route.bind(route_id))
	content.add_child(choice_button)
	var body := _make_label(body_text, 16, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	if route_id == NodeRoute.HIGH_RISK:
		third_high_risk_panel = card
		third_high_risk_button = choice_button
	else:
		third_safer_route_panel = card
		third_safer_route_button = choice_button
	return card


func _make_dispatch_risk_card(title_text: String, body_text: String, accent_color: Color) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, accent_color, 2, 14))
	var margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + margin_name, 18)
	for margin_name in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 16)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 8)
	margin.add_child(content)
	content.add_child(_make_label(title_text, 17, accent_color))
	var body := _make_label(body_text, 14, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	return card


func _make_cumulative_risk_notice() -> PanelContainer:
	var card := PanelContainer.new()
	card.name = "T2_06_CumulativeRiskNotice"
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(Color("#202a34"), Color("#526170"), 1, 12))
	var margin := MarginContainer.new()
	margin.name = "T2_06_RiskNoticeMargin"
	for margin_name in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + margin_name, 16)
	for margin_name in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 12)
	card.add_child(margin)
	var notice := _make_label(CUMULATIVE_RISK_NOTICE, 14, COLOR_TEXT)
	notice.name = "T2_06_RiskDisclosure"
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	margin.add_child(notice)
	return card


func _make_node_route_card(title_text: String, body_text: String, route_id: int, accent_color: Color, is_second_node: bool = false) -> PanelContainer:
	var card := PanelContainer.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.add_theme_stylebox_override("panel", _make_panel_style(COLOR_PANEL, COLOR_PANEL_BORDER, 1, 14))
	var margin := MarginContainer.new()
	for margin_name in ["left", "right"]:
		margin.add_theme_constant_override("margin_" + margin_name, 18)
	for margin_name in ["top", "bottom"]:
		margin.add_theme_constant_override("margin_" + margin_name, 16)
	card.add_child(margin)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 12)
	margin.add_child(content)
	var choice_button := Button.new()
	choice_button.text = title_text
	choice_button.custom_minimum_size = Vector2(0, 48)
	choice_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	choice_button.toggle_mode = true
	choice_button.add_theme_font_size_override("font_size", 17)
	choice_button.add_theme_color_override("font_color", COLOR_TEXT)
	choice_button.add_theme_color_override("font_hover_color", COLOR_TEXT)
	choice_button.add_theme_stylebox_override("normal", _make_panel_style(Color("#27323d"), COLOR_PANEL_BORDER, 1, 10))
	choice_button.add_theme_stylebox_override("hover", _make_panel_style(Color("#303b47"), accent_color, 1, 10))
	choice_button.add_theme_stylebox_override("pressed", _make_panel_style(Color("#303b47"), accent_color, 2, 10))
	if is_second_node:
		choice_button.pressed.connect(_select_second_node_route.bind(route_id))
	else:
		choice_button.pressed.connect(_select_node_route.bind(route_id))
	content.add_child(choice_button)
	var body := _make_label(body_text, 16, COLOR_TEXT)
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_child(body)
	if is_second_node:
		if route_id == NodeRoute.HIGH_RISK:
			second_high_risk_panel = card
			second_high_risk_button = choice_button
		else:
			second_safer_route_panel = card
			second_safer_route_button = choice_button
	elif route_id == NodeRoute.HIGH_RISK:
		high_risk_panel = card
		high_risk_button = choice_button
	else:
		safer_route_panel = card
		safer_route_button = choice_button
	return card


func _show_node_choice() -> void:
	if expedition_run_state.is_route_confirmed(1):
		return
	departure_page.visible = false
	node_page.visible = true
	_update_node_route_visuals()


func _select_node_route(route_id: int) -> void:
	if expedition_run_state.is_route_confirmed(1) or (route_id != NodeRoute.HIGH_RISK and route_id != NodeRoute.SAFER):
		return
	selected_node_route = route_id
	_update_node_route_visuals()


func _select_second_node_route(route_id: int) -> void:
	if expedition_run_state.is_route_confirmed(2) or (route_id != NodeRoute.HIGH_RISK and route_id != NodeRoute.SAFER):
		return
	second_node_selected_route = route_id
	_update_second_node_route_visuals()


func _update_node_route_visuals() -> void:
	if not is_instance_valid(high_risk_panel) or not is_instance_valid(safer_route_panel):
		return
	var high_selected := selected_node_route == NodeRoute.HIGH_RISK
	var safer_selected := selected_node_route == NodeRoute.SAFER
	high_risk_button.button_pressed = high_selected
	safer_route_button.button_pressed = safer_selected
	high_risk_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_LATE if high_selected else COLOR_PANEL_BORDER, 2 if high_selected else 1, 14
	))
	safer_route_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_HIT if safer_selected else COLOR_PANEL_BORDER, 2 if safer_selected else 1, 14
	))
	if is_instance_valid(node_confirm_button):
		node_confirm_button.disabled = selected_node_route == NodeRoute.NONE or expedition_run_state.is_route_confirmed(1)


func _return_to_departure() -> void:
	if expedition_run_state.is_route_confirmed(1):
		return
	node_page.visible = false
	departure_page.visible = true


func _show_second_node_choice() -> void:
	if not expedition_run_state.is_route_confirmed(1) or expedition_run_state.is_route_confirmed(2):
		return
	node_result_page.visible = false
	second_node_page.visible = true
	_update_second_node_route_visuals()


func _update_second_node_route_visuals() -> void:
	if not is_instance_valid(second_high_risk_panel) or not is_instance_valid(second_safer_route_panel):
		return
	var high_selected := second_node_selected_route == NodeRoute.HIGH_RISK
	var safer_selected := second_node_selected_route == NodeRoute.SAFER
	second_high_risk_button.button_pressed = high_selected
	second_safer_route_button.button_pressed = safer_selected
	second_high_risk_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_LATE if high_selected else COLOR_PANEL_BORDER, 2 if high_selected else 1, 14
	))
	second_safer_route_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_HIT if safer_selected else COLOR_PANEL_BORDER, 2 if safer_selected else 1, 14
	))
	if is_instance_valid(second_node_confirm_button):
		second_node_confirm_button.disabled = second_node_selected_route == NodeRoute.NONE or expedition_run_state.is_route_confirmed(2)


func _return_to_previous_node() -> void:
	if expedition_run_state.is_route_confirmed(2):
		return
	second_node_page.visible = false
	node_result_page.visible = true


func _confirm_second_node_route() -> void:
	if expedition_run_state.is_route_confirmed(2) or second_node_selected_route == NodeRoute.NONE:
		return
	var route_id := second_node_selected_route
	if not confirm_expedition_route(2, _route_key_from_selection(route_id)):
		push_error("[T2-06][BLOCKED] 无法一致确认节点 02；已停止本次状态更新。")
		return
	second_node_selected_route = NodeRoute.NONE
	second_confirmed_route_label.text = "已选择路线：" + _confirmed_route_name(2)
	second_node_page.visible = false
	second_node_result_page.visible = true
	_update_second_node_route_visuals()
	print("[T2-04] node=02 route=%s confirmed=true state=%s" % [_confirmed_route_name(2), expedition_run_state.get_status_key()])


func _confirm_node_route() -> void:
	if expedition_run_state.is_route_confirmed(1) or selected_node_route == NodeRoute.NONE:
		return
	var route_id := selected_node_route
	if not confirm_expedition_route(1, _route_key_from_selection(route_id)):
		push_error("[T2-06][BLOCKED] 无法一致确认节点 01；已停止本次状态更新。")
		return
	selected_node_route = NodeRoute.NONE
	confirmed_route_label.text = "已选择路线：" + _confirmed_route_name(1)
	node_page.visible = false
	node_result_page.visible = true
	_update_node_route_visuals()
	print("[T2-03] route=%s confirmed=true state=%s" % [_confirmed_route_name(1), expedition_run_state.get_status_key()])


func _node_route_name(route_id: int) -> String:
	if route_id == NodeRoute.HIGH_RISK:
		return "高风险路线"
	if route_id == NodeRoute.SAFER:
		return "较安全路线"
	return ""


func _route_key_from_selection(route_id: int) -> String:
	if route_id == NodeRoute.HIGH_RISK:
		return "high_risk"
	if route_id == NodeRoute.SAFER:
		return "safer"
	return "unconfirmed"


func _route_id_from_key(route_key: String) -> int:
	if route_key == "high_risk":
		return NodeRoute.HIGH_RISK
	if route_key == "safer":
		return NodeRoute.SAFER
	return NodeRoute.NONE


func _confirmed_route_name(node_number: int) -> String:
	return _node_route_name(_route_id_from_key(expedition_run_state.get_confirmed_route(node_number)))


func _show_dispatch_brief() -> void:
	if current_result_name.is_empty() or not is_instance_valid(dispatch_page):
		return
	dispatch_result_label.text = "当前这把剑的锻造结果：" + current_result_name
	forge_page.visible = false
	departure_page.visible = false
	dispatch_page.visible = true


func _return_to_forge() -> void:
	dispatch_page.visible = false
	forge_page.visible = true


func _confirm_dispatch() -> void:
	if current_result_name.is_empty():
		return
	departure_status_label.text = "已出发：阿禾 | 折锋谷 | 锻造结果：" + current_result_name
	dispatch_page.visible = false
	forge_page.visible = false
	departure_page.visible = true


func _show_third_node_choice() -> void:
	if not expedition_run_state.is_route_confirmed(2) or expedition_run_state.is_route_confirmed(3):
		return
	second_node_result_page.visible = false
	third_node_page.visible = true
	_update_third_node_route_visuals()


func _select_third_node_route(route_id: int) -> void:
	if expedition_run_state.is_route_confirmed(3) or (route_id != NodeRoute.HIGH_RISK and route_id != NodeRoute.SAFER):
		return
	third_node_selected_route = route_id
	_update_third_node_route_visuals()


func _update_third_node_route_visuals() -> void:
	if not is_instance_valid(third_high_risk_panel) or not is_instance_valid(third_safer_route_panel):
		return
	var high_selected := third_node_selected_route == NodeRoute.HIGH_RISK
	var safer_selected := third_node_selected_route == NodeRoute.SAFER
	third_high_risk_button.button_pressed = high_selected
	third_safer_route_button.button_pressed = safer_selected
	third_high_risk_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_LATE if high_selected else COLOR_PANEL_BORDER, 2 if high_selected else 1, 14
	))
	third_safer_route_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_HIT if safer_selected else COLOR_PANEL_BORDER, 2 if safer_selected else 1, 14
	))
	if is_instance_valid(third_node_confirm_button):
		third_node_confirm_button.disabled = third_node_selected_route == NodeRoute.NONE or expedition_run_state.is_route_confirmed(3)


func _return_to_second_node() -> void:
	if expedition_run_state.is_route_confirmed(3):
		return
	third_node_page.visible = false
	second_node_result_page.visible = true


func _confirm_third_node_route() -> void:
	if expedition_run_state.is_route_confirmed(3) or third_node_selected_route == NodeRoute.NONE:
		return
	var route_id := third_node_selected_route
	if not confirm_expedition_route(3, _route_key_from_selection(route_id)):
		push_error("[T2-06][BLOCKED] 无法一致确认节点 03；已停止本次状态更新。")
		return
	third_node_selected_route = NodeRoute.NONE
	third_confirmed_route_label.text = "已选择路线：" + _confirmed_route_name(3)
	third_node_page.visible = false
	third_node_result_page.visible = true
	_update_third_node_route_visuals()
	print("[T2-05] node=03 route=%s confirmed=true state=%s" % [_confirmed_route_name(3), expedition_run_state.get_status_key()])


func _fourth_node_snapshot_error(snapshot: Dictionary, require_unconfirmed_node4: bool) -> String:
	if snapshot.get("schema_version") != 1:
		return "状态快照版本不符，不能安全读取第四节点状态。"
	if snapshot.get("node_order") != ["松风口", "沉桥", "焦石坡", "折锋关"]:
		return "四节点顺序与已批准契约不符，不能进入第四节点。"
	var routes_value: Variant = snapshot.get("confirmed_routes")
	if not (routes_value is Array):
		return "状态快照缺少已确认路线数组，不能进入第四节点。"
	var routes: Array = routes_value
	if routes.size() != 4:
		return "状态快照中的路线数量不是四项，不能进入第四节点。"
	for index in range(3):
		if routes[index] != "high_risk" and routes[index] != "safer":
			return "前三节点存在未确认或不支持的路线事实，按契约停止。"
	var fourth_route: String = str(routes[3])
	if require_unconfirmed_node4 and fourth_route != "unconfirmed":
		return "第四节点已确认或状态不一致，不能重复确认。"
	if not require_unconfirmed_node4 and fourth_route != "high_risk" and fourth_route != "safer":
		return "第四节点确认后快照不含有效路线，按契约停止。"
	var status_key: String = str(snapshot.get("status", ""))
	if status_key != "undecided" and status_key != "failed_route" and status_key != "all_safer":
		return "状态快照中的权威状态不受支持，按契约停止。"
	return ""


func _fourth_node_status_text(status_key: String) -> String:
	if status_key == "failed_route":
		return "失败路线（按公开规则在折锋关失败；本页尚未结算）"
	if status_key == "all_safer":
		return "全程较安全（可避开本次失败及其损失；不保证其他方面成功）"
	if status_key == "undecided":
		return "未定"
	return "状态读取异常"


func _t2_08_snapshot_error(snapshot: Dictionary) -> String:
	var authoritative_snapshot := get_expedition_state_snapshot()
	if snapshot.size() != authoritative_snapshot.size():
		return "结算候选快照与同一 Main 实例的当前权威状态不一致；按契约停止结算。"
	for key in ["schema_version", "node_order", "route_codes", "confirmed_routes", "status"]:
		if not snapshot.has(key) or snapshot[key] != authoritative_snapshot.get(key):
			return "结算候选快照与同一 Main 实例的当前权威状态不一致；按契约停止结算。"
	var error_message := _fourth_node_snapshot_error(snapshot, false)
	if not error_message.is_empty():
		return error_message
	var routes: Array = snapshot["confirmed_routes"]
	var expected_status := "all_safer"
	if routes.has("high_risk"):
		expected_status = "failed_route"
	if str(snapshot["status"]) != expected_status:
		return "四节点已确认路线与权威状态不一致；按契约停止结算。"
	return ""


func _apply_t2_08_resolution(snapshot: Dictionary) -> bool:
	if is_instance_valid(t2_08_settlement_panel):
		t2_08_settlement_panel.visible = false
	var error_message := _t2_08_snapshot_error(snapshot)
	if not error_message.is_empty():
		fourth_result_state_label.text = "权威本次历练状态：结算阻塞"
		fourth_result_note_label.text = "已停止结算：" + error_message
		push_error("[T2-08][BLOCKED] " + error_message)
		return false

	var routes: Array = snapshot["confirmed_routes"]
	var route_names := ["松风口", "沉桥", "焦石坡", "折锋关"]
	var confirmed_high_risk_nodes: Array[String] = []
	for index in range(4):
		if routes[index] == "high_risk":
			confirmed_high_risk_nodes.append(route_names[index])

	if str(snapshot["status"]) == "failed_route":
		if confirmed_high_risk_nodes.is_empty():
			fourth_result_state_label.text = "权威本次历练状态：结算阻塞"
			fourth_result_note_label.text = "已停止结算：失败路线没有可追溯的已确认高风险节点。"
			push_error("[T2-08][BLOCKED] 失败路线没有可追溯的已确认高风险节点。")
			return false
		fourth_result_state_label.text = "权威本次历练状态：失败路线"
		t2_08_settlement_reason_label.text = "失败原因：" + "、".join(confirmed_high_risk_nodes) + "确认了高风险路线；按已披露累计规则，本次历练成为失败路线。"
		t2_08_settlement_losses_label.text = "结算损失：\n剑折断\n阿禾轻伤返庄"
		fourth_result_note_label.text = "本次失败路线已在折锋关结算。"
		t2_08_settlement_panel.visible = true
		print("[T2-08] settlement=failed_route high_risk_nodes=%s losses=[sword_broken, ahe_minor_injury_returned]" % [",".join(confirmed_high_risk_nodes)])
		return true

	fourth_result_state_label.text = "权威本次历练状态：全程较安全"
	fourth_result_note_label.text = "四个节点均已确认较安全，避开了本次指定失败及其损失。"
	print("[T2-08] settlement=not_applied status=all_safer confirmed_routes=%s" % [str(routes)])
	return true


func _fourth_node_route_name(route_key: String) -> String:
	if route_key == "high_risk":
		return "高风险路线"
	if route_key == "safer":
		return "较安全路线"
	return "未确认"


func _fourth_node_block(message: String) -> void:
	fourth_node_blocked = true
	push_error("[T2-07][BLOCKED] " + message)
	if is_instance_valid(fourth_prior_routes_label):
		fourth_prior_routes_label.text = "状态契约阻塞：" + message
	if is_instance_valid(fourth_preconfirm_state_label):
		fourth_preconfirm_state_label.text = "已停止：未继续读取或确认第四节点。"
	if is_instance_valid(fourth_high_risk_button):
		fourth_high_risk_button.disabled = true
	if is_instance_valid(fourth_safer_route_button):
		fourth_safer_route_button.disabled = true
	if is_instance_valid(fourth_node_confirm_button):
		fourth_node_confirm_button.disabled = true


func _show_fourth_node_choice() -> void:
	var snapshot := get_expedition_state_snapshot()
	var error_message := _fourth_node_snapshot_error(snapshot, true)
	if not error_message.is_empty():
		fourth_node_page.visible = true
		third_node_result_page.visible = false
		_fourth_node_block(error_message)
		return
	fourth_node_blocked = false
	third_node_result_page.visible = false
	fourth_node_result_page.visible = false
	fourth_node_page.visible = true
	var routes: Array = snapshot["confirmed_routes"]
	var node_names := ["松风口", "沉桥", "焦石坡"]
	var prior_routes := ""
	for index in range(3):
		if index > 0:
			prior_routes += "；"
		prior_routes += "%s：%s" % [node_names[index], _fourth_node_route_name(str(routes[index]))]
	fourth_prior_routes_label.text = "前三节点已确认路线：" + prior_routes
	fourth_preconfirm_state_label.text = "当前权威状态：" + _fourth_node_status_text(str(snapshot["status"]))
	_update_fourth_node_route_visuals()
	print("[T2-07] enter node=04 prior_routes=%s state=%s" % [str(routes.slice(0, 3)), str(snapshot["status"])])


func _select_fourth_node_route(route_id: int) -> void:
	if fourth_node_blocked or (route_id != NodeRoute.HIGH_RISK and route_id != NodeRoute.SAFER):
		return
	var error_message := _fourth_node_snapshot_error(get_expedition_state_snapshot(), true)
	if not error_message.is_empty():
		_fourth_node_block(error_message)
		return
	fourth_node_selected_route = route_id
	_update_fourth_node_route_visuals()


func _update_fourth_node_route_visuals() -> void:
	if not is_instance_valid(fourth_high_risk_panel) or not is_instance_valid(fourth_safer_route_panel):
		return
	var high_selected := fourth_node_selected_route == NodeRoute.HIGH_RISK
	var safer_selected := fourth_node_selected_route == NodeRoute.SAFER
	fourth_high_risk_button.button_pressed = high_selected
	fourth_safer_route_button.button_pressed = safer_selected
	fourth_high_risk_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_LATE if high_selected else COLOR_PANEL_BORDER, 2 if high_selected else 1, 14
	))
	fourth_safer_route_panel.add_theme_stylebox_override("panel", _make_panel_style(
		Color("#202a34"), COLOR_HIT if safer_selected else COLOR_PANEL_BORDER, 2 if safer_selected else 1, 14
	))
	fourth_high_risk_button.disabled = fourth_node_blocked
	fourth_safer_route_button.disabled = fourth_node_blocked
	if is_instance_valid(fourth_node_confirm_button):
		fourth_node_confirm_button.disabled = fourth_node_blocked or fourth_node_selected_route == NodeRoute.NONE


func _return_to_third_node() -> void:
	var error_message := _fourth_node_snapshot_error(get_expedition_state_snapshot(), true)
	if not error_message.is_empty():
		_fourth_node_block(error_message)
		return
	fourth_node_page.visible = false
	fourth_node_result_page.visible = false
	third_node_result_page.visible = true


func _confirm_fourth_node_route() -> void:
	if fourth_node_blocked or fourth_node_selected_route == NodeRoute.NONE:
		return
	var before_snapshot := get_expedition_state_snapshot()
	var error_message := _fourth_node_snapshot_error(before_snapshot, true)
	if not error_message.is_empty():
		_fourth_node_block(error_message)
		return
	var route_key := _route_key_from_selection(fourth_node_selected_route)
	if not confirm_expedition_route(4, route_key):
		_fourth_node_block("Main 的既有路线确认契约拒绝节点 04；未创建替代状态。")
		return
	var after_snapshot := get_expedition_state_snapshot()
	error_message = _fourth_node_snapshot_error(after_snapshot, false)
	if not error_message.is_empty():
		_fourth_node_block(error_message)
		return
	var confirmed_routes: Array = after_snapshot["confirmed_routes"]
	if confirmed_routes[3] != route_key:
		_fourth_node_block("确认后第四项路线与刚才显式确认的选择不一致。")
		return
	fourth_node_selected_route = NodeRoute.NONE
	fourth_confirmed_route_label.text = "已确认路线：" + _fourth_node_route_name(route_key)
	_apply_t2_08_resolution(after_snapshot)
	fourth_node_page.visible = false
	fourth_node_result_page.visible = true
	_update_fourth_node_route_visuals()
	print("[T2-07] node=04 route=%s confirmed=true state=%s" % [_fourth_node_route_name(route_key), str(after_snapshot["status"])])
