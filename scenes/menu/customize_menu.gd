extends Control
class_name CustomizeMenu

const MAIN_MENU_SCENE_PATH := "res://scenes/menu/MainMenu.tscn"

@onready var back_button: Button = $CenterContainer/Columns/LeftPanel/LeftContent/BackButton
@onready var title_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Title
@onready var eyebrow_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Eyebrow
@onready var divider_label: Label = $CenterContainer/Columns/LeftPanel/LeftContent/Divider
@onready var element_label: Label = $CenterContainer/Columns/RightPanel/RightContent/ElementEyebrow
@onready var element_name_label: Label = $CenterContainer/Columns/RightPanel/RightContent/ElementNameLabel
@onready var element_list: VBoxContainer = $CenterContainer/Columns/RightPanel/RightContent/ElementScroll/ElementList
@onready var nickname_input: LineEdit = $CenterContainer/Columns/LeftPanel/LeftContent/NicknameInput
@onready var color_list: HBoxContainer = $CenterContainer/Columns/LeftPanel/LeftContent/ColorList
@onready var character_list: VBoxContainer = $CenterContainer/Columns/LeftPanel/LeftContent/CharacterList

var element_buttons: Dictionary = {}
var color_buttons: Array = []
var character_buttons: Dictionary = {}

func _ready() -> void:
	theme = UiTheme.build()
	title_label.add_theme_font_override("font", UiTheme.title_font())
	eyebrow_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	divider_label.add_theme_font_override("font", UiTheme.eyebrow_font())
	element_label.add_theme_font_override("font", UiTheme.eyebrow_font())

	back_button.pressed.connect(_on_back_pressed)

	_setup_element_buttons()
	_setup_color_buttons()
	_setup_character_buttons()

	nickname_input.text = NetworkState.player_nickname
	nickname_input.text_changed.connect(_on_nickname_changed)
	_select_color(NetworkState.player_color)

func _on_back_pressed() -> void:
	get_tree().change_scene_to_file(MAIN_MENU_SCENE_PATH)

func _setup_element_buttons() -> void:
	for button in element_list.get_children():
		var row: HBoxContainer = button.get_node("Row")
		var icon: ElementIcon = row.get_node("ElementIcon")
		var name_label: Label = row.get_node("Name")
		element_buttons[icon.element] = {"icon": icon, "label": name_label}
		button.pressed.connect(_on_element_selected.bind(icon.element))
	_on_element_selected(NetworkState.selected_element)

func _on_element_selected(element: ElementType.Type) -> void:
	NetworkState.selected_element = element
	for el in element_buttons:
		var entry: Dictionary = element_buttons[el]
		var is_selected: bool = (el == element)
		entry["icon"].selected = is_selected
		entry["label"].add_theme_color_override("font_color", UiTheme.COL_SIGNAL if is_selected else UiTheme.COL_INK_DIM)
	element_name_label.text = ElementType.display_name(element)

func _setup_color_buttons() -> void:
	for button in color_list.get_children():
		var swatch: Control = button.get_node("Swatch")
		color_buttons.append({"button": button, "swatch": swatch})
		button.pressed.connect(_on_color_selected.bind(swatch.swatch_color))

func _on_color_selected(color: Color) -> void:
	_select_color(color)
	NetworkState.save_settings()

func _select_color(color: Color) -> void:
	NetworkState.player_color = color
	for entry in color_buttons:
		entry["swatch"].selected = entry["swatch"].swatch_color.is_equal_approx(color)

func _setup_character_buttons() -> void:
	for id in CharacterLibrary.ids():
		var button := Button.new()
		button.text = CharacterLibrary.display_name(id)
		button.custom_minimum_size = Vector2(0, 40)
		character_list.add_child(button)
		character_buttons[id] = button
		button.pressed.connect(_on_character_selected.bind(id))
	_select_character(NetworkState.selected_character_id)

func _on_character_selected(id: String) -> void:
	_select_character(id)
	NetworkState.save_settings()

func _select_character(id: String) -> void:
	NetworkState.selected_character_id = id
	for character_id in character_buttons:
		var button: Button = character_buttons[character_id]
		var is_selected: bool = (character_id == id)
		button.add_theme_color_override("font_color", UiTheme.COL_SIGNAL if is_selected else UiTheme.COL_INK)

func _on_nickname_changed(new_text: String) -> void:
	var nickname := new_text.strip_edges()
	if nickname.is_empty():
		nickname = NetworkState.DEFAULT_NICKNAME
	NetworkState.player_nickname = nickname
	NetworkState.save_settings()
