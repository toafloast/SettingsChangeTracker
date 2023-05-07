@icon("res://addons/ChangeDiscard/icon-simple.png")
extends Node

##Change Discarder Addon for quick-and-easy options menus.
##
##Keeps track of simple node changes- like Control nodes changing values, through signals.
##To use, connect the signal corresponding to a value change to a ChangeDiscard node's "track_change" function.

##Automatically save the settings to a file. Not recommended, it is better to integrate it into your own user settings saving/loading system.
@export var load_from_file : bool = false
##The filepath to save to. Must be unique for every instance of ChangeDiscard to prevent overwriting. res:// saves to project, user:// saves to user data folder.
@export var save_filepath : String = "res://addons/ChangeDiscard/changediscardtest.save"
@export_subgroup("Encrypt")
##Encrypt the resulting file using the provided key. Not necessary, since this is mostlikely just saving configs.
@export var encrypt : bool = false
##File encryption/decryption key. Use your own!
@export var encryption_key : String = "use-your-own-key"

##Default values, set on initialization.
var default_values : Dictionary = {}
##If a value is changed, it gets put here.
var tracked_changes : Dictionary = {}


##The number of changes present- useful to have a UI to see how many changes there are.
var number_of_changes : int = 0
##Emitted when the current state of the tracked values doesn't match the stored state- a change was made.
signal changes_detected
##Emitted when the current state of the tracked values matches the stored state again.
signal changes_discarded
##Emitted when the user saves the changes.
signal changes_saved

func _ready() -> void:
	#OPTIONAL - await to load up the appropriate settings here
	if load_from_file == true:
		load_changes_from_file()
	initialize()

##Grab the connected signals and set up default and tracked values.
func initialize() -> void:
	var connections = get_incoming_connections()

	for sigdict in connections:
		#user should only bind the node's path
		if sigdict["callable"].get_bound_arguments_count() == 0:
			printerr("A node path wasn't provided to the ChangeDiscard node. If this is intended, pass an empty String.")
			continue

		var bound = sigdict["callable"].get_bound_arguments()[0]

		if bound == "":
			continue

		var incoming_node = get_node(bound)
		var default = incoming_node.get(get_control_property(incoming_node))
		default_values[str(get_path_to(incoming_node))] = default


#if you need to add a custom or missing control type, add it here-
#consider creating an issue on the github  if I missed a specific Control.
##Returns the default value of the Control based on its type.
func get_control_property(node : Control):
	if node is Range:
		return "value"
	if node is LineEdit:
		return "text"
	if node is TextEdit:
		return "text"
	if node is ColorPickerButton:
		return "color"
	if node is OptionButton:
		return "selected"
	if node is BaseButton:
		return "button_pressed"
	return null


##Connect a signal to this function.
##When connecting in editor, enable Advanced, and write a String path pointing to the sending node.
#Note- using a NodePath wouldn't work, since it is relative to the sending node, not the ChangeDiscard node.
func track_change(change, origin : String):
	if default_values[origin] == change:
		tracked_changes.erase(origin)
		check_change_difference()
		return

	tracked_changes[str(origin)] = change
	check_change_difference()


##Necessary for TextEdit and CodeEdit, as they do not provide the changed text in the signal.
func track_change_text(origin : String):
	var change = get_node(origin).text
	if default_values[origin] == change:
		tracked_changes.erase(origin)
		check_change_difference()
		return

	tracked_changes[str(origin)] = change
	check_change_difference()


##Discards all of the changes made.
func discard_changes() -> void:
	tracked_changes.clear()
	number_of_changes = 0
	change_flag = false

	for key in default_values.keys():
		var node = get_node(key)
		node.set(get_control_property(node), default_values[key])


##A flag to prevent the 'changes_detected' signal from continuously sending.
var change_flag : bool = 0
##Checks if the tracked_changes list is greater than 1, emits signal if it is, emits signal if it isn't.
func check_change_difference():
	number_of_changes = tracked_changes.keys().size()
	#theres changes! emit the signal
	if number_of_changes > 0 and !change_flag:
		change_flag = true
		changes_detected.emit()
		return
	#changes were undone, emit discard signal.
	if number_of_changes == 0 and change_flag:
		change_flag = false
		changes_discarded.emit()
		return


##Load changes from a saved dictionary.
func load_changes_from_dict(load_dict : Dictionary):
	for key in load_dict.keys():
		default_values[key] = load_dict[key]

		var node = get_node(key)
		var property = get_control_property(node)

		if property == "color":
			node.set(property, Color.html(load_dict[key]))
			continue
		node.set(property, default_values[key])


##Automatically load changes from file if load_from_file is enabled. Loads on _ready.
func load_changes_from_file() -> int:
	print("Loading from file.")
	var file : FileAccess

	if !encrypt:
		file = FileAccess.open(save_filepath, FileAccess.READ)
	else:
		file = FileAccess.open_encrypted_with_pass(save_filepath, FileAccess.READ, encryption_key)

	if file == null:
		return ERR_FILE_CANT_OPEN

	var data = JSON.parse_string(file.get_as_text())
	load_changes_from_dict(data)
	file.close()
	return OK


##Saves and returns the values dictionary for integrating with your own save/load systems.
#note - colors must be converted to and from hex, or they won't work.
func save_changes_to_dict() -> Dictionary:
	var saved = {}

	for key in default_values.keys():
		var node = get_node(key)
		var property = get_control_property(node)

		if property == "color":
			saved[key] = node.get(property).to_html()
			continue
		saved[key] = node.get(property)

	return saved


##Save changes to file if load_from_file is enabled. Doesn't save automatically.
func save_changes_to_file() -> int:
	var file : FileAccess

	if !encrypt:
		file = FileAccess.open(save_filepath, FileAccess.WRITE)
	else:
		file = FileAccess.open_encrypted_with_pass(save_filepath, FileAccess.WRITE, encryption_key)

	if file == null:
		return ERR_FILE_CANT_OPEN

	var dict = save_changes_to_dict()
	file.store_line(JSON.stringify(dict))
	file.close()
	return OK


##Saves the current changes.
func set_changes():
	for key in tracked_changes.keys():
		default_values[key] = tracked_changes[key]

	tracked_changes.clear()
	number_of_changes = 0
	change_flag = false
	changes_saved.emit()


