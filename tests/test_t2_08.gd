extends SceneTree

var checks := 0
var failures: Array[String] = []


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	for high_risk_node in range(1, 5):
		await _test_failed_route(high_risk_node)
	await _test_all_safer_route()
	await _test_incomplete_snapshot_is_blocked()
	await _test_inconsistent_snapshot_is_blocked()
	await _test_forged_snapshot_is_blocked()
	if failures.is_empty():
		print("[T2-08-TEST] PASS checks=%d" % checks)
		quit(0)
	else:
		for failure in failures:
			push_error("[T2-08-TEST] " + failure)
		print("[T2-08-TEST] FAIL checks=%d failures=%d" % [checks, failures.size()])
		quit(1)


func _new_game():
	var packed_scene: PackedScene = load("res://scenes/main.tscn")
	var game = packed_scene.instantiate()
	root.add_child(game)
	await process_frame
	return game


func _test_failed_route(high_risk_node: int) -> void:
	var game = await _new_game()
	for node_number in range(1, 4):
		var route_key := "high_risk" if node_number == high_risk_node else "safer"
		_check(game.confirm_expedition_route(node_number, route_key), "高风险节点 %d 前置节点 %d 应确认成功" % [high_risk_node, node_number])
	var fourth_route_id := 1 if high_risk_node == 4 else 2
	game.call("_select_fourth_node_route", fourth_route_id)
	game.call("_confirm_fourth_node_route")
	var snapshot: Dictionary = game.call("get_expedition_state_snapshot")
	_check(snapshot["status"] == "failed_route", "高风险节点 %d 应由权威状态归类为失败路线" % high_risk_node)
	var panel: PanelContainer = game.get("t2_08_settlement_panel")
	_check(panel.visible, "高风险节点 %d 应显示失败结算" % high_risk_node)
	var reason_label: Label = game.get("t2_08_settlement_reason_label")
	var node_names := ["松风口", "沉桥", "焦石坡", "折锋关"]
	_check(reason_label.text.contains(node_names[high_risk_node - 1]), "高风险节点 %d 的结算原因应对应已确认节点" % high_risk_node)
	var losses_label: Label = game.get("t2_08_settlement_losses_label")
	_check(losses_label.text == "结算损失：\n剑折断\n阿禾轻伤返庄", "高风险节点 %d 只能出现两项已批准损失" % high_risk_node)
	var result_note: Label = game.get("fourth_result_note_label")
	_check(result_note.text == "本次失败路线已在折锋关结算。", "高风险节点 %d 的损失应在确认后的结算页面呈现" % high_risk_node)
	game.queue_free()
	await process_frame


func _test_all_safer_route() -> void:
	var game = await _new_game()
	for node_number in range(1, 4):
		_check(game.confirm_expedition_route(node_number, "safer"), "全安全路线节点 %d 应确认成功" % node_number)
	game.call("_select_fourth_node_route", 2)
	game.call("_confirm_fourth_node_route")
	var snapshot: Dictionary = game.call("get_expedition_state_snapshot")
	_check(snapshot["status"] == "all_safer", "全安全路线应保留权威 all_safer 状态")
	var panel: PanelContainer = game.get("t2_08_settlement_panel")
	_check(not panel.visible, "全安全路线不得进入失败结算")
	var result_note: Label = game.get("fourth_result_note_label")
	_check(result_note.text == "四个节点均已确认较安全，避开了本次指定失败及其损失。", "全安全路线只说明避开指定失败与损失")
	_check(not result_note.text.contains("成功") and not result_note.text.contains("奖励"), "全安全提示不得称成功或加奖励")
	game.queue_free()
	await process_frame


func _test_incomplete_snapshot_is_blocked() -> void:
	var game = await _new_game()
	_check(game.confirm_expedition_route(1, "high_risk"), "阻塞测试节点 1 应可确认")
	var before: Dictionary = game.call("get_expedition_state_snapshot")
	var resolved: bool = game.call("_apply_t2_08_resolution", before)
	var after: Dictionary = game.call("get_expedition_state_snapshot")
	_check(not resolved, "未完成四节点时必须阻止结算")
	_check(not game.get("t2_08_settlement_panel").visible, "未完成四节点时不得显示损失")
	_check(before == after, "被阻止的结算不得改变权威路线状态")
	game.queue_free()
	await process_frame


func _test_inconsistent_snapshot_is_blocked() -> void:
	var game = await _new_game()
	for node_number in range(1, 4):
		var route_key := "high_risk" if node_number == 1 else "safer"
		_check(game.confirm_expedition_route(node_number, route_key), "不一致测试节点 %d 应确认成功" % node_number)
	game.call("_select_fourth_node_route", 2)
	game.call("_confirm_fourth_node_route")
	var snapshot: Dictionary = game.call("get_expedition_state_snapshot")
	snapshot["status"] = "all_safer"
	var resolved: bool = game.call("_apply_t2_08_resolution", snapshot)
	_check(not resolved, "路线与状态冲突时必须阻止结算")
	_check(not game.get("t2_08_settlement_panel").visible, "路线与状态冲突时不得展示损失")
	_check(game.call("get_expedition_state_snapshot")["status"] == "failed_route", "冲突快照不得覆写权威状态")
	game.queue_free()
	await process_frame


func _test_forged_snapshot_is_blocked() -> void:
	var game = await _new_game()
	_check(game.confirm_expedition_route(1, "high_risk"), "伪造快照测试当前节点 1 应确认成功")
	var before: Dictionary = game.call("get_expedition_state_snapshot")
	var forged_safe := _make_test_snapshot(["safer", "safer", "safer", "safer"], "all_safer")
	var resolved: bool = game.call("_apply_t2_08_resolution", forged_safe)
	_check(not resolved, "当前未完成状态不得接受另一份自洽的四节点全安全快照")
	_check(not game.get("t2_08_settlement_panel").visible, "来源不符的全安全快照不得改变结算 UI")
	_check(before == game.call("get_expedition_state_snapshot"), "拒绝伪造全安全快照不得改变权威路线")
	game.queue_free()
	await process_frame

	game = await _new_game()
	for node_number in range(1, 5):
		_check(game.confirm_expedition_route(node_number, "safer"), "当前全安全状态节点 %d 应确认成功" % node_number)
	var forged_failed := _make_test_snapshot(["safer", "high_risk", "safer", "safer"], "failed_route")
	resolved = game.call("_apply_t2_08_resolution", forged_failed)
	_check(not resolved, "当前全安全状态不得接受另一份自洽的失败路线快照")
	_check(not game.get("t2_08_settlement_panel").visible, "来源不符的失败快照不得显示损失")
	_check(game.call("get_expedition_state_snapshot")["status"] == "all_safer", "拒绝伪造失败快照不得改变全安全权威状态")
	game.queue_free()
	await process_frame

	game = await _new_game()
	for node_number in range(1, 5):
		var route_key := "high_risk" if node_number == 1 else "safer"
		_check(game.confirm_expedition_route(node_number, route_key), "当前失败状态节点 %d 应确认成功" % node_number)
	var other_failed_route := _make_test_snapshot(["safer", "safer", "high_risk", "safer"], "failed_route")
	resolved = game.call("_apply_t2_08_resolution", other_failed_route)
	_check(not resolved, "权威状态键相同时，四节点路线事实不同也必须阻止结算")
	_check(not game.get("t2_08_settlement_panel").visible, "高风险节点位置不符的快照不得显示损失")
	_check(game.call("get_expedition_state_snapshot")["confirmed_routes"][0] == "high_risk", "拒绝替代失败快照不得改变真实高风险节点")
	game.queue_free()
	await process_frame


func _make_test_snapshot(routes: Array, status_key: String) -> Dictionary:
	return {
		"schema_version": 1,
		"node_order": ["松风口", "沉桥", "焦石坡", "折锋关"],
		"route_codes": ["unconfirmed", "high_risk", "safer"],
		"confirmed_routes": routes,
		"status": status_key,
	}


func _check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
