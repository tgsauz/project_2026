extends RefCounted
class_name RuntimeAttachmentGraph

var nodes: Dictionary = {}

func clear() -> void:
	nodes.clear()

func add_node(node: RuntimeAttachmentNode) -> void:
	if node == null or node.node_id.is_empty():
		return
	nodes[node.node_id] = node
	if not node.parent_node_id.is_empty() and nodes.has(node.parent_node_id):
		var parent := nodes[node.parent_node_id] as RuntimeAttachmentNode
		if parent != null and not parent.child_node_ids.has(node.node_id):
			parent.child_node_ids.append(node.node_id)

func remove_node(node_id: String) -> void:
	if not nodes.has(node_id):
		return
	var node := nodes[node_id] as RuntimeAttachmentNode
	if node != null and not node.parent_node_id.is_empty() and nodes.has(node.parent_node_id):
		var parent := nodes[node.parent_node_id] as RuntimeAttachmentNode
		if parent != null and parent.child_node_ids.has(node_id):
			var children := Array(parent.child_node_ids)
			children.erase(node_id)
			parent.child_node_ids = PackedStringArray(children)
	nodes.erase(node_id)

func get_node(node_id: String) -> RuntimeAttachmentNode:
	return nodes.get(node_id, null) as RuntimeAttachmentNode

func has_node(node_id: String) -> bool:
	return nodes.has(node_id)

func get_root_node_ids() -> PackedStringArray:
	var roots: Array[RuntimeAttachmentNode] = []
	for node in nodes.values():
		var attachment_node := node as RuntimeAttachmentNode
		if attachment_node != null and attachment_node.parent_node_id.is_empty():
			roots.append(attachment_node)
	roots.sort_custom(func(a: RuntimeAttachmentNode, b: RuntimeAttachmentNode): return (a.definition.sort_order if a.definition != null else 0) < (b.definition.sort_order if b.definition != null else 0))

	var ids := PackedStringArray()
	for node in roots:
		ids.append(node.node_id)
	return ids

func get_children(node_id: String) -> Array[RuntimeAttachmentNode]:
	var result: Array[RuntimeAttachmentNode] = []
	var node := get_node(node_id)
	if node == null:
		return result
	for child_id in node.child_node_ids:
		var child := get_node(child_id)
		if child != null:
			result.append(child)
	result.sort_custom(func(a: RuntimeAttachmentNode, b: RuntimeAttachmentNode): return (a.definition.sort_order if a.definition != null else 0) < (b.definition.sort_order if b.definition != null else 0))
	return result

func get_all_nodes_sorted() -> Array[RuntimeAttachmentNode]:
	var result: Array[RuntimeAttachmentNode] = []
	for node in nodes.values():
		var attachment_node := node as RuntimeAttachmentNode
		if attachment_node != null:
			result.append(attachment_node)
	result.sort_custom(func(a: RuntimeAttachmentNode, b: RuntimeAttachmentNode):
		var a_depth := _get_depth(a.node_id)
		var b_depth := _get_depth(b.node_id)
		if a_depth == b_depth:
			return (a.definition.sort_order if a.definition != null else 0) < (b.definition.sort_order if b.definition != null else 0)
		return a_depth < b_depth
	)
	return result

func _get_depth(node_id: String) -> int:
	var depth := 0
	var visited := {}
	var node := get_node(node_id)
	while node != null and not node.parent_node_id.is_empty():
		if visited.has(node.node_id):
			push_warning("RuntimeAttachmentGraph: Prevented parent-depth cycle at node '%s'." % node.node_id)
			break
		visited[node.node_id] = true
		depth += 1
		node = get_node(node.parent_node_id)
	return depth
