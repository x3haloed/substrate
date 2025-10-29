extends Control
class_name SettingsPanel

## LLM provider settings UI

signal settings_saved()
signal closed()

@onready var provider_option: OptionButton = $VBox/ProviderBox/ProviderOption
@onready var api_url_edit: LineEdit = $VBox/URLBox/APIUrlEdit
@onready var api_key_edit: LineEdit = $VBox/KeyBox/APIKeyEdit
@onready var model_edit: LineEdit = $VBox/ModelBox/ModelEdit
@onready var save_button: Button = $VBox/SaveButton
@onready var close_button: Button = $VBox/CloseButton

var settings: LLMSettings

const PROVIDER_NAMES = ["OpenAI", "OpenRouter", "Ollama", "Custom"]

func _ready():
	save_button.pressed.connect(_on_save_pressed)
	close_button.pressed.connect(_on_close_pressed)
	provider_option.item_selected.connect(_on_provider_selected)
	
	# Populate provider dropdown
	for provider_name in PROVIDER_NAMES:
		provider_option.add_item(provider_name)
	
	visible = false

func load_settings(p_settings: LLMSettings):
	settings = p_settings
	if not settings:
		return
	
	match settings.provider:
		"openai":
			provider_option.selected = 0
		"openrouter":
			provider_option.selected = 1
		"ollama":
			provider_option.selected = 2
		"custom":
			provider_option.selected = 3
		_:
			provider_option.selected = 0
	
	api_url_edit.text = settings.api_base_url
	api_key_edit.text = settings.api_key
	model_edit.text = settings.model
	
	_update_url_edit_state()

func _on_provider_selected(index: int):
	match index:
		0:
			settings.set_provider("openai")
		1:
			settings.set_provider("openrouter")
		2:
			settings.set_provider("ollama")
		3:
			settings.set_provider("custom")
	
	_update_url_edit_state()

func _update_url_edit_state():
	var is_custom = provider_option.selected == 3
	api_url_edit.editable = is_custom
	if not is_custom:
		api_url_edit.text = settings.get_api_url()

func _on_save_pressed():
	if not settings:
		return
	
	settings.api_base_url = api_url_edit.text
	settings.api_key = api_key_edit.text
	settings.model = model_edit.text
	
	# Save to resource file
	var path = "res://llm/settings.tres"
	ResourceSaver.save(settings, path)
	
	settings_saved.emit()
	visible = false

func _on_close_pressed():
	visible = false
	closed.emit()
