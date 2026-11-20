extends Area3D

@export var interaction_prompt: String = "Examinar"
@export_multiline var description: String = ""
@export var target_path: NodePath = NodePath("..")


func get_prompt() -> String:
	var target: Node = get_node_or_null(target_path)
	if target != null and target.has_method("get_interaction_prompt"):
		return target.get_interaction_prompt()
	return interaction_prompt


func interact(interactor: Node) -> void:
	var target: Node = get_node_or_null(target_path)
	if target != null and target.has_method("interact"):
		target.interact(interactor)
	elif interactor.has_method("show_interaction_message"):
		interactor.show_interaction_message(description)
