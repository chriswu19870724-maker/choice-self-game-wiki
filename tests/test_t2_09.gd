extends SceneTree

const MainScene := preload("res://scenes/main.tscn")

var failures: Array[String] = []
var checks := 0


func _initialize() -> void:
	call_deferred("_run")


func _run() -> void:
	var game = MainScene.instantiate()
	root.add_child(game)
	await process_frame
	var strike: Button = game.strike_button
	var retry: Button = game.retry_button
	var dispatch: Button = game.dispatch_button
	var fresh: Dictionary = game.get_expedition_state_snapshot()
	game._start_reforge()
	_check(game.forge_title.text == "单次落锤", "Fresh sessions cannot enter reforge")
	game.elapsed_seconds = 2.8
	strike.pressed.emit()
	_check(game.current_result_name == "命中" and dispatch.visible, "Initial active strike opens dispatch")
	game._show_dispatch_brief()
	game._confirm_dispatch()
	game._show_node_choice()
	game._select_node_route(1)
	game._confirm_node_route()
	game._show_second_node_choice()
	game._select_second_node_route(2)
	game._confirm_second_node_route()
	game._show_third_node_choice()
	game._select_third_node_route(2)
	game._confirm_third_node_route()
	game._show_fourth_node_choice()
	game._select_fourth_node_route(2)
	game._confirm_fourth_node_route()
	var settled: Dictionary = game.get_expedition_state_snapshot()
	_check(settled["confirmed_routes"] == ["high_risk", "safer", "safer", "safer"], "Four confirmed route facts at settlement")
	var reforge := game.t2_08_settlement_panel.find_child("ReforgeButton", true, false) as Button
	_check(reforge.is_visible_in_tree(), "Failure settlement offers reforge")
	reforge.pressed.emit()
	_check(strike.is_visible_in_tree() and not strike.disabled, "Reforge uses the same active strike button")
	_check(game.get_expedition_state_snapshot() == settled, "Reforge preserves route facts on entry")
	game._process(6.0)
	_check(retry.is_visible_in_tree() and not dispatch.visible and game.forge_title.text != "Demo 结束", "Reforge timeout requires an active strike before ending")
	retry.pressed.emit()
	game.elapsed_seconds = 4.2
	strike.pressed.emit()
	_check(game.current_result_name == "偏晚" and game.state_label.text == "新剑已铸成：偏晚", "Reforge shows a new sword and the original timing result")
	_check(game.forge_title.text == "Demo 结束", "Demo ends after the reforge strike")
	_check(not retry.visible and not dispatch.visible and strike.disabled, "Demo ending exposes no extra round")
	game._reset_attempt()
	game._start_reforge()
	strike.pressed.emit()
	_check(game.forge_title.text == "Demo 结束" and strike.disabled, "Stale actions cannot restart a completed Demo")
	_check(game.get_expedition_state_snapshot() == settled, "Finished reforge retains the same confirmed routes")
	game.queue_free()
	await process_frame

	var next_game = MainScene.instantiate()
	root.add_child(next_game)
	await process_frame
	_check(next_game.get_expedition_state_snapshot() == fresh, "A new game instance clears every confirmed route")
	for node in range(1, 5):
		next_game.confirm_expedition_route(node, "safer")
	next_game._apply_t2_08_resolution(next_game.get_expedition_state_snapshot())
	next_game.fourth_node_result_page.show()
	next_game._start_reforge()
	_check(next_game.forge_title.text == "单次落锤", "All-safer resolution cannot open reforge")
	next_game.queue_free()
	await process_frame

	for failure in failures:
		push_error(failure)
	print("[T2-09-TEST] %s checks=%d" % ["PASS" if failures.is_empty() else "FAIL", checks])
	quit(0 if failures.is_empty() else 1)


func _check(condition: bool, description: String) -> void:
	checks += 1
	if not condition:
		failures.append(description)
