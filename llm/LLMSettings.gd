extends Resource
class_name LLMSettings

## LLM provider configuration
@export var provider: String = "openai"  # "openai", "openrouter", "ollama", "custom"
@export var api_base_url: String = "https://api.openai.com/v1"
@export var api_key: String = ""
@export var model: String = "gpt-4o-mini"
@export var debug_trace: bool = false

const PROVIDER_URLS = {
	"openai": "https://api.openai.com/v1",
	"openrouter": "https://openrouter.ai/api/v1",
	"ollama": "http://localhost:11434/api"
}

func get_api_url() -> String:
	if provider == "custom":
		return api_base_url
	return PROVIDER_URLS.get(provider, PROVIDER_URLS.openai)

func set_provider(p_provider: String):
	provider = p_provider
	if not provider == "custom" and PROVIDER_URLS.has(provider):
		api_base_url = PROVIDER_URLS[provider]
