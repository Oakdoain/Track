extends RefCounted
class_name NarrativeGraphLayout

const HORIZONTAL_GAP := 64.0
const VERTICAL_GAP := 72.0
const SIDE_MARGIN := 56.0
const TOP_MARGIN := 56.0
const BOTTOM_MARGIN := 72.0
const MIN_CANVAS_SIZE := Vector2(1080.0, 720.0)
const DEFAULT_NODE_SIZE := Vector2(260.0, 96.0)


static func calculate(
	nodes: Array[Dictionary],
	visible_nodes: Dictionary,
	initial_node_id: String,
	node_sizes: Dictionary
) -> Dictionary:
	var node_by_id: Dictionary = {}
	var source_order: Dictionary = {}
	var outgoing: Dictionary = {}
	var incoming: Dictionary = {}

	for index in range(nodes.size()):
		var node: Dictionary = nodes[index]
		var node_id: String = str(node.get("node_id", ""))

		if node_id == "" or node_by_id.has(node_id):
			continue

		node_by_id[node_id] = node
		source_order[node_id] = index
		outgoing[node_id] = []
		incoming[node_id] = []

	for node_id_value in node_by_id.keys():
		var node_id: String = str(node_id_value)
		var targets: Array[String] = _node_targets(node_by_id[node_id] as Dictionary, node_by_id)
		outgoing[node_id] = targets

		for target_id in targets:
			(incoming[target_id] as Array).append(node_id)

	var depths: Dictionary = {}
	var queue: Array[String] = []

	if node_by_id.has(initial_node_id):
		depths[initial_node_id] = 0
		queue.append(initial_node_id)

	var queue_index := 0

	while queue_index < queue.size():
		var source_id: String = queue[queue_index]
		queue_index += 1
		var source_depth: int = int(depths[source_id])

		for target_id in outgoing.get(source_id, []):
			if not depths.has(target_id):
				depths[target_id] = source_depth + 1
				queue.append(target_id)

	var fallback_depth := 0

	for depth_value in depths.values():
		fallback_depth = maxi(fallback_depth, int(depth_value))

	for node_id_value in node_by_id.keys():
		var node_id: String = str(node_id_value)

		if not depths.has(node_id):
			depths[node_id] = fallback_depth + 1

	var layers: Dictionary = {}
	var max_depth := 0

	for visible_id_value in visible_nodes.keys():
		var visible_id: String = str(visible_id_value)

		if not node_by_id.has(visible_id):
			continue

		var depth: int = int(depths.get(visible_id, 0))
		max_depth = maxi(max_depth, depth)

		if not layers.has(depth):
			layers[depth] = []

		(layers[depth] as Array).append(visible_id)

	for depth_value in layers.keys():
		(layers[depth_value] as Array).sort_custom(func(a: Variant, b: Variant) -> bool:
			return int(source_order.get(str(a), 0)) < int(source_order.get(str(b), 0))
		)

	var ranks: Dictionary = _build_ranks(layers)

	for depth in range(1, max_depth + 1):
		if layers.has(depth):
			_sort_layer_by_neighbors(layers[depth] as Array, incoming, ranks, source_order)
			ranks = _build_ranks(layers)

	for depth in range(max_depth - 1, -1, -1):
		if layers.has(depth):
			_sort_layer_by_neighbors(layers[depth] as Array, outgoing, ranks, source_order)
			ranks = _build_ranks(layers)

	var widest_layer := 0.0
	var layer_widths: Dictionary = {}

	for depth_value in layers.keys():
		var width := _layer_width(layers[depth_value] as Array, node_sizes)
		layer_widths[depth_value] = width
		widest_layer = maxf(widest_layer, width)

	var canvas_width := maxf(MIN_CANVAS_SIZE.x, widest_layer + SIDE_MARGIN * 2.0)
	var positions: Dictionary = {}
	var max_bottom := TOP_MARGIN

	for depth in range(max_depth + 1):
		if not layers.has(depth):
			continue

		var layer: Array = layers[depth]
		var layer_width: float = float(layer_widths.get(depth, 0.0))
		var x := (canvas_width - layer_width) * 0.5
		var y := TOP_MARGIN + float(depth) * (DEFAULT_NODE_SIZE.y + VERTICAL_GAP)

		for node_id_value in layer:
			var node_id: String = str(node_id_value)
			var node_size: Vector2 = node_sizes.get(node_id, DEFAULT_NODE_SIZE)
			positions[node_id] = Vector2(x, y)
			x += node_size.x + HORIZONTAL_GAP
			max_bottom = maxf(max_bottom, y + node_size.y)

	return {
		"positions": positions,
		"sizes": node_sizes.duplicate(true),
		"depths": depths,
		"outgoing": outgoing,
		"canvas_size": Vector2(canvas_width, maxf(MIN_CANVAS_SIZE.y, max_bottom + BOTTOM_MARGIN))
	}


static func _node_targets(node: Dictionary, node_by_id: Dictionary) -> Array[String]:
	var targets: Array[String] = []
	var choices: Variant = node.get("choices", [])

	if choices is Array:
		for choice in choices:
			if not (choice is Dictionary):
				continue

			var target_id: String = str((choice as Dictionary).get("to", ""))

			if target_id != "" and node_by_id.has(target_id) and not targets.has(target_id):
				targets.append(target_id)

	var graph_targets: Variant = node.get("graph_targets", [])

	if graph_targets is Array:
		for target_value in graph_targets:
			var target_id: String = str(target_value)

			if target_id != "" and node_by_id.has(target_id) and not targets.has(target_id):
				targets.append(target_id)

	return targets


static func _build_ranks(layers: Dictionary) -> Dictionary:
	var ranks: Dictionary = {}

	for depth_value in layers.keys():
		var layer: Array = layers[depth_value]

		for index in range(layer.size()):
			ranks[str(layer[index])] = float(index)

	return ranks


static func _sort_layer_by_neighbors(
	layer: Array,
	neighbors_by_id: Dictionary,
	ranks: Dictionary,
	source_order: Dictionary
) -> void:
	layer.sort_custom(func(a: Variant, b: Variant) -> bool:
		var a_id := str(a)
		var b_id := str(b)
		var a_score := _neighbor_score(a_id, neighbors_by_id, ranks, source_order)
		var b_score := _neighbor_score(b_id, neighbors_by_id, ranks, source_order)

		if is_equal_approx(a_score, b_score):
			return int(source_order.get(a_id, 0)) < int(source_order.get(b_id, 0))

		return a_score < b_score
	)


static func _neighbor_score(
	node_id: String,
	neighbors_by_id: Dictionary,
	ranks: Dictionary,
	source_order: Dictionary
) -> float:
	var neighbors: Variant = neighbors_by_id.get(node_id, [])

	if not (neighbors is Array) or (neighbors as Array).is_empty():
		return float(source_order.get(node_id, 0))

	var score := 0.0
	var count := 0

	for neighbor_value in neighbors:
		var neighbor_id := str(neighbor_value)

		if ranks.has(neighbor_id):
			score += float(ranks[neighbor_id])
			count += 1

	return score / float(count) if count > 0 else float(source_order.get(node_id, 0))


static func _layer_width(layer: Array, node_sizes: Dictionary) -> float:
	var width := 0.0

	for node_id_value in layer:
		var node_size: Vector2 = node_sizes.get(str(node_id_value), DEFAULT_NODE_SIZE)
		width += node_size.x

	if layer.size() > 1:
		width += HORIZONTAL_GAP * float(layer.size() - 1)

	return width
