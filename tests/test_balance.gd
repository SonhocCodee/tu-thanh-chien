extends SceneTree

## Test headless — CÂN BẰNG CUNG THỦ vs CẬN CHIẾN (nhánh can-bang).
## Chạy: godot --headless --script tests/test_balance.gd
## Đấu tay đôi trên sân trống quanh tâm map: 2 phe lao thẳng vào nhau
## (cùng order_move về tâm), đánh tới khi 1 bên chết hết quân dàn trận.
##   cb1) 4 Kiếm sĩ vs 4 Cung thủ   -> Kiếm sĩ phải THẮNG, còn 1–3 con sống.
##   cb2) 4 Kiếm sĩ vs 6 Cung thủ   -> Cung phải THẮNG (số đông có nghĩa).
##   cb3) 2 Lính giáo vs 3 Cung thủ -> Giáo phải áp sát được và THẮNG.
## Mỗi kịch bản chạy 3 ván; PASS theo đa số ván + tiêu chí sống sót.

var _failures := 0
var _game: Node = null

const CENTER := Vector2(960, 480)
const TIME_SCALE := 20.0
const DUEL_BUDGET := 150.0 # giây mô phỏng tối đa cho 1 ván

func _initialize() -> void:
	_run()

func _check(name: String, ok: bool, detail: String) -> void:
	if ok:
		print("TEST ", name, ": PASS — ", detail)
	else:
		_failures += 1
		print("TEST ", name, ": FAIL — ", detail)

func _wait(sec: float) -> void:
	await create_timer(sec).timeout

func _new_game() -> Node:
	if _game != null and is_instance_valid(_game):
		root.remove_child(_game)
		_game.free()
	Engine.time_scale = TIME_SCALE
	paused = false
	_game = load("res://scenes/main.tscn").instantiate()
	_game.bots_enabled = false
	root.add_child(_game)
	return _game

func _spawn_unit(g: Node, pid: int, unit_type: String, pos: Vector2) -> Unit:
	var u := load("res://scenes/unit.tscn").instantiate() as Unit
	u.setup(pid, unit_type, g.get_player(pid).color_key, g, Vector2.ZERO)
	u.position = pos
	u.z_index = 10
	g.add_child(u)
	u.died.connect(g._on_unit_died)
	return u

func _alive_count(units: Array) -> int:
	var n := 0
	for u in units:
		if is_instance_valid(u) and (u as Unit).is_alive():
			n += 1
	return n

## Dàn 1 đội quanh điểm neo: hàng ngang lệch xen kẽ để không chồng điểm.
func _spawn_team(g: Node, pid: int, unit_type: String, count: int, anchor: Vector2, dir_x: float) -> Array:
	var units: Array = []
	var offs := [Vector2(0, -30), Vector2(0, 30), Vector2(0, -64), Vector2(0, 64), Vector2(0, -98), Vector2(0, 98)]
	for i in count:
		var back := Vector2(dir_x * 34.0 * float(i / 2), 0)
		units.append(_spawn_unit(g, pid, unit_type, anchor + offs[i] + back))
	return units

## Chạy 1 ván đấu: A = bên CÔNG lao thẳng vào, B = bên THỦ đứng giữ vị trí
## (đúng kịch bản user báo: cung đứng từ xa bắn, cận chiến lao vào).
## Trả về {"winner": "A"|"B"|"hoa", "alive_a": int, "alive_b": int, "time": float}
func _duel(type_a: String, n_a: int, type_b: String, n_b: int) -> Dictionary:
	var g = await _new_game()
	await _wait(0.5)
	var def_anchor := CENTER + Vector2(30, 0)
	var team_a := _spawn_team(g, 0, type_a, n_a, CENTER + Vector2(-330, 0), -1.0)
	var team_b := _spawn_team(g, 2, type_b, n_b, def_anchor, 1.0)
	g.controllers[2].order_move(def_anchor) # thủ: giữ đất quanh điểm neo
	g.controllers[0].order_move(def_anchor) # công: lao thẳng tới vị trí địch
	var t := 0.0
	while t < DUEL_BUDGET:
		await _wait(0.5)
		t += 0.5
		if _alive_count(team_a) == 0 or _alive_count(team_b) == 0:
			break
	var aa := _alive_count(team_a)
	var ab := _alive_count(team_b)
	var winner := "hoa"
	if aa > 0 and ab == 0:
		winner = "A"
	elif ab > 0 and aa == 0:
		winner = "B"
	return {"winner": winner, "alive_a": aa, "alive_b": ab, "time": t}

func _run_scenario(key: String, type_a: String, n_a: int, type_b: String, n_b: int) -> Array:
	var results: Array = []
	for i in 3:
		var r = await _duel(type_a, n_a, type_b, n_b)
		results.append(r)
		print("  VAN ", key, " #", i + 1, ": thang=", r["winner"],
			" (A con ", r["alive_a"], "/", n_a, " — B con ", r["alive_b"], "/", n_b,
			") sau ", r["time"], "s")
	return results

func _wins(results: Array, side: String) -> int:
	var n := 0
	for r in results:
		if r["winner"] == side:
			n += 1
	return n

func _run() -> void:
	# ============ cb1) 4 Kiếm sĩ (A) vs 4 Cung thủ (B) ============
	print("== CB1: 4 kiem si vs 4 cung thu ==")
	var r1 := await _run_scenario("cb1", "warrior", 4, "archer", 4)
	var w1 := _wins(r1, "A")
	var surv_ok := 0
	for r in r1:
		if r["winner"] == "A" and int(r["alive_a"]) >= 1 and int(r["alive_a"]) <= 3:
			surv_ok += 1
	_check("cb1", w1 >= 2 and surv_ok >= 2,
		"kiem si thang %d/3 van, %d/3 van thang voi 1-3 con song (muc tieu: thang + con 1-3)" % [w1, surv_ok])

	# ============ cb2) 4 Kiếm sĩ (A) vs 6 Cung thủ (B) ============
	print("== CB2: 4 kiem si vs 6 cung thu ==")
	var r2 := await _run_scenario("cb2", "warrior", 4, "archer", 6)
	var w2 := _wins(r2, "B")
	_check("cb2", w2 >= 2,
		"cung thu thang %d/3 van khi dong hon 6v4 (muc tieu: cung thang)" % w2)

	# ============ cb3) 2 Lính giáo (A) vs 3 Cung thủ (B) ============
	print("== CB3: 2 linh giao vs 3 cung thu ==")
	var r3 := await _run_scenario("cb3", "lancer", 2, "archer", 3)
	var w3 := _wins(r3, "A")
	_check("cb3", w3 >= 2,
		"linh giao thang %d/3 van (muc tieu: giao ap sat duoc cung va thang)" % w3)

	if _failures == 0:
		print("TEST BALANCE: ALL PASS")
	else:
		print("TEST BALANCE: ", _failures, " FAIL")
	quit(_failures)
