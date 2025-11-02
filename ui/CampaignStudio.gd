extends Control

@onready var tab_container: TabContainer = $Margin/VBox/Tabs

signal closed()

func _ready():
    pass

func show_studio():
    visible = true

func hide_studio():
    visible = false
    closed.emit()


