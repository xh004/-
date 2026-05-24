extends Node2D

@onready var btn_start = $PanelContainer/MenuButtons/StartButton
@onready var btn_settings = $PanelContainer/MenuButtons/SettingsButton
@onready var btn_stats = $PanelContainer/MenuButtons/StatsButton
@onready var btn_quit = $PanelContainer/MenuButtons/QuitButton

func _ready():
	setup_buttons()


func setup_buttons():
	for btn in [btn_start, btn_settings, btn_stats, btn_quit]:
		btn.pressed.connect(_on_button_click.bind(btn))
	
func _on_button_click(btn: Button):
	match btn.name:
		"StartButton":
			get_tree().change_scene_to_file("res://scence/main.tscn")
		"SettingsButton":
			print("S")  
		"StatsButton":
			print("A")
		"QuitButton":
			get_tree().quit()
