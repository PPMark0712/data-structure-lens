extends SceneTree
## Run with: godot --headless --path . --script tests/test_models.gd
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	call_deferred("_run")

func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		printerr("FAIL: " + message)

func _run() -> void:
	var count := 0
	for entry in LabCatalog.ENTRIES:
		var path := "res://scripts/models/%s.gd" % entry[4]
		if not ResourceLoader.exists(path):
			check(false, "%s model script exists: %s" % [entry[1], path])
			continue
		count += 1
		var model := LabCatalog.create(entry)
		check(model != null, entry[1] + " creates")
		if model == null: continue
		check(model.invariant().is_empty(), entry[1] + " default invariant")
		for operation in model.operations():
			var fresh := LabCatalog.create(entry)
			var args := {}
			for field in operation.fields:
				args[field.key] = field.initial if field.text else int(field.initial)
			var ok := fresh.perform(operation.id, args)
			check(ok, "%s.%s default operation: %s" % [entry[1], operation.id, fresh.error])
			check(fresh.invariant().is_empty(), "%s.%s invariant" % [entry[1], operation.id])
			check(not fresh.frames.is_empty(), "%s.%s emits frames" % [entry[1], operation.id])
			for frame in fresh.frames:
				check_frame(frame, entry[1] + "." + operation.id)
	check(count == LabCatalog.ENTRIES.size(), "every catalog entry is covered")
	var parser := LabModel.new()
	check(parser.integers("-9223372036854775808").is_empty() and not parser.error.is_empty(),
		"minimum int64 cannot bypass sequence limits")
	_frame_references()
	_random_linear()
	_random_hash()
	_random_disjoint_set()
	_random_ranges()
	_random_segments()
	print("Tested %d modules; %d checks; %d failures." % [count, checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func check_frame(frame: Dictionary, label: String) -> void:
	var ids := {}
	for node in frame.nodes:
		check(not ids.has(str(node.id)), label + " unique visual IDs")
		ids[str(node.id)] = true
		check(node.pos is Vector2 and node.pos.is_finite(), label + " finite coordinates")
	for edge in frame.edges:
		check(ids.has(str(edge.from)) and ids.has(str(edge.to)), label + " edge endpoints exist")
	for active in frame.get("active", []):
		check(ids.has(str(active)), label + " active node exists")

func _frame_references() -> void:
	var tree := BalancedModel.new("avl")
	check(tree.perform("find", {"value": 999}), "missing balanced-tree lookup")
	for frame in tree.frames: check_frame(frame, "avl.missing")
	var trie := TrieModel.new("trie")
	check(trie.perform("find", {"value": "zzz"}), "missing Trie lookup")
	for frame in trie.frames: check_frame(frame, "trie.missing")
	var red_black := RedBlackModel.new()
	check(red_black.perform("build", {"values": "1"}), "singleton red-black build")
	check(red_black.perform("delete", {"value": 1}), "singleton red-black deletion")
	for frame in red_black.frames: check_frame(frame, "red_black.singleton_delete")

func _random_linear() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1001
	for kind in ["array", "dynamic_array", "linked", "doubly"]:
		var model := LinearModel.new(kind)
		model.recording = false
		var reference: Array = [12, 7, 24, 16]
		for round in 100:
			var value := rng.randi_range(-20, 20)
			var limit := 8 if kind == "array" else 16
			if reference.is_empty() or (rng.randf() < 0.5 and reference.size() < limit):
				var index := rng.randi_range(0, reference.size())
				check(model.perform("insert", {"index": index + 1, "value": value}), "linear insert")
				reference.insert(index, value)
			else:
				var index := rng.randi_range(0, reference.size() - 1)
				check(model.perform("delete", {"index": index + 1}), "linear delete")
				reference.remove_at(index)
			var actual: Array = []
			for item in model.items: actual.append(item.value)
			check(actual == reference, kind + " differential sequence")
			check(model.invariant().is_empty(), kind + " invariant")

func _random_hash() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 221
	for kind in ["hash_linear", "hash_quadratic", "hash_chain"]:
		var model := HashModel.new(kind)
		model.recording = false
		model.perform("clear", {})
		var reference := {}
		for round in 100:
			var value := rng.randi_range(-15, 15)
			if rng.randf() < 0.5:
				if model.perform("insert", {"value": value}): reference[value] = true
			else:
				model.perform("delete", {"value": value})
				reference.erase(value)
			for key in range(-15, 16):
				check(model.contains(key) == reference.has(key), kind + " membership")
			check(model.invariant().is_empty(), kind + " invariant")

func _disjoint_root(parents: Array[int], x: int) -> int:
	while parents[x] != x:
		x = parents[x]
	return x

func _random_disjoint_set() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 744
	var model := DisjointSetModel.new()
	model.recording = false
	check(model.perform("build", {"size": 12}), "disjoint set build")
	var groups: Array[int] = []
	for i in range(13):
		groups.append(i)
	for round in 120:
		var a := rng.randi_range(1, 12)
		var b := rng.randi_range(1, 12)
		if rng.randf() < 0.6:
			var from := groups[a]
			var to := groups[b]
			check(model.perform("union", {"a": a, "b": b}), "disjoint set union")
			for i in range(1, 13):
				if groups[i] == from:
					groups[i] = to
		else:
			check(model.perform("connected", {"a": a, "b": b}), "disjoint set connected")
			check(model.connected_result == (groups[a] == groups[b]),
				"disjoint set connectivity matches independent partition")
		check(model.invariant().is_empty(), "disjoint set invariant")
		for x in range(1, 13):
			for y in range(1, 13):
				check((_disjoint_root(model.parent, x) == _disjoint_root(model.parent, y)) ==
					(groups[x] == groups[y]), "disjoint set differential partition")

func _random_ranges() -> void:
	if not ResourceLoader.exists("res://scripts/models/ranges.gd"): return
	var rng := RandomNumberGenerator.new()
	rng.seed = 771
	var model: LabModel = load("res://scripts/models/ranges.gd").new("fenwick")
	model.recording = false
	var reference: Array = model.data.duplicate()
	for round in 100:
		var index := rng.randi_range(1, 8)
		var delta := rng.randi_range(-10, 10)
		model.perform("add", {"index": index, "value": delta})
		reference[index - 1] += delta
		var l := rng.randi_range(1, 8)
		var r := rng.randi_range(l, 8)
		model.perform("query", {"l": l, "r": r})
		var expected := 0
		for i in range(l - 1, r): expected += reference[i]
		check(model.result == expected, "Fenwick differential sum")
		check(model.invariant().is_empty(), "Fenwick invariant")
	model = load("res://scripts/models/ranges.gd").new("fenwick2")
	model.recording = false
	reference = model.grid.duplicate(true)
	for round in 100:
		var x := rng.randi_range(1, 4)
		var y := rng.randi_range(1, 4)
		var delta := rng.randi_range(-10, 10)
		model.perform("add", {"x": x, "y": y, "value": delta})
		reference[x][y] += delta
		var x1 := rng.randi_range(1, 4)
		var y1 := rng.randi_range(1, 4)
		var x2 := rng.randi_range(x1, 4)
		var y2 := rng.randi_range(y1, 4)
		model.perform("query", {"x1": x1, "y1": y1, "x2": x2, "y2": y2})
		var expected := 0
		for i in range(x1, x2 + 1):
			for j in range(y1, y2 + 1): expected += reference[i][j]
		check(model.result == expected, "2D Fenwick differential sum")
		check(model.invariant().is_empty(), "2D Fenwick invariant")

func _random_segments() -> void:
	var script := load("res://scripts/models/segment.gd")
	var rng := RandomNumberGenerator.new()
	rng.seed = 831
	for kind in ["segment", "dynamic_segment", "persistent_segment"]:
		var model: LabModel = script.new(kind)
		model.recording = false
		var reference: Array = model.data.duplicate()
		for round in (5 if kind == "persistent_segment" else 100):
			var l := rng.randi_range(0, model.domain - 1)
			var r := rng.randi_range(l, model.domain - 1) if kind == "segment" else l
			var delta := rng.randi_range(-10, 10)
			var args := {"l": l + 1, "r": r + 1, "value": delta} if kind == "segment" else {"index": l + 1, "value": delta}
			check(model.perform("add", args), kind + " update")
			for i in range(l, r + 1): reference[i] += delta
			check(model.invariant().is_empty(), kind + " invariant")
			for i in model.domain:
				var end := rng.randi_range(i, model.domain - 1)
				var expected := 0
				for j in range(i, end + 1): expected += reference[j]
				model.perform("query", {"l": i + 1, "r": end + 1})
				check(model.result == expected, kind + " brute sum")
				check(model.invariant().is_empty(), kind + " query preserves invariant")
		if kind == "persistent_segment":
			model.perform("version", {"version": 1})
			model.perform("query", {"l": 1, "r": 8})
			check(model.result == 31, "persistent segment original version unchanged")
	var model: LabModel = load("res://scripts/models/segment2.gd").new()
	model.recording = false
	var reference: Array = model.grid.duplicate(true)
	for round in 100:
		var x := rng.randi_range(0, 3)
		var y := rng.randi_range(0, 3)
		var delta := rng.randi_range(-10, 10)
		check(model.perform("add", {"x": x + 1, "y": y + 1, "value": delta}), "2D segment update")
		reference[x][y] += delta
		var x1 := rng.randi_range(0, 3)
		var y1 := rng.randi_range(0, 3)
		var x2 := rng.randi_range(x1, 3)
		var y2 := rng.randi_range(y1, 3)
		model.perform("query", {"x1": x1 + 1, "y1": y1 + 1, "x2": x2 + 1, "y2": y2 + 1})
		var expected := 0
		for i in range(x1, x2 + 1):
			for j in range(y1, y2 + 1): expected += reference[i][j]
		check(model.result == expected, "2D segment brute sum")
		check(model.invariant().is_empty(), "2D segment invariant")
