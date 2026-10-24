extends SceneTree

## Test headless — registry net_id trong Main (INTEGRATION.md bước 1).
## Chạy: godot --headless --script tests/test_net_ids.gd
## Chỉ kiểm tra registry: chơi đơn không đổi hành vi, id thành cố định theo
## slot, id động duy nhất + tra ngược được. Phần mạng chạy thật nằm ở
## tools/run_net_test.sh.

var _failures := 0
var _game: Node = null

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

func _run() -> void:
	_game = load("res://scenes/main.tscn").instantiate()
	_game.bots_enabled = false
	root.add_child(_game)
	await _wait(0.5)
	var g = _game

	# a) Thành của slot s có net_id = s + 1, tra ngược đúng node.
	var ok_a := true
	for pid in range(4):
		var c = g.castles[pid]
		if g.net_id_of(c) != pid + 1:
			ok_a = false
		if g.node_by_net_id(pid + 1) != c:
			ok_a = false
	_check("a_castle_ids", ok_a, "net_id thanh = pid+1 ca 4 phe, node_by_net_id khop")

	# b) Id ổn định: hỏi 2 lần cùng 1 node -> cùng id.
	var v = g._villagers_of(0)[0]
	var id1: int = g.net_id_of(v)
	var id2: int = g.net_id_of(v)
	_check("b_stable", id1 == id2 and id1 >= 1000, "id nong dan on dinh = %d (>= 1000)" % id1)

	# c) Id duy nhất giữa các loại thực thể khác nhau.
	var ids := {}
	var dup := false
	for pid in range(4):
		for node in g._villagers_of(pid):
			var i: int = g.net_id_of(node)
			if ids.has(i):
				dup = true
			ids[i] = node
	for n in get_nodes_in_group("res_nodes"):
		var i2: int = g.net_id_of(n)
		if ids.has(i2):
			dup = true
		ids[i2] = n
	for n in get_nodes_in_group("sheep"):
		var i3: int = g.net_id_of(n)
		if ids.has(i3):
			dup = true
		ids[i3] = n
	_check("c_unique", not dup and ids.size() > 40, "%d thuc the, 0 trung id" % ids.size())

	# d) Tra ngược: node_by_net_id(net_id_of(x)) == x cho mẫu các loại.
	var ok_d := true
	for i in ids.keys():
		if g.node_by_net_id(int(i)) != ids[i]:
			ok_d = false
	_check("d_roundtrip", ok_d, "tra nguoc dung cho %d thuc the" % ids.size())

	# e) net_role mặc định rỗng — chơi đơn không có NetSession.
	_check("e_single_player_clean", String(g.net_role) == "" and g.get_node_or_null("NetSession") == null,
		"net_role='' va khong co node NetSession khi choi don")

	print("TEST_NET_IDS DONE failures=", _failures)
	quit(_failures)
