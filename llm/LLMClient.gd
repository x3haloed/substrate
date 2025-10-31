extends Node
class_name LLMClient

## HTTP client for OpenAI-compatible chat completions API

var settings: LLMSettings
var http_request: HTTPRequest
var pending_response: Dictionary = {}

signal request_complete(response_text: String)
signal request_error(error: String)

func _init(p_settings: LLMSettings):
	settings = p_settings
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_request_completed)

func make_request(messages: Array[Dictionary], model_override: String = "", json_schema: Dictionary = {}) -> String:
	var url = settings.get_api_url() + "/chat/completions"
	
	var request_body = {
		"model": model_override if model_override != "" else settings.model,
		"messages": messages,
		"temperature": 0.7,
	}
	# Structured outputs: if a JSON schema is provided, enable schema-constrained responses when supported
	if json_schema.size() > 0:
		if settings.provider == "openrouter":
			request_body["response_format"] = {
				"type": "json_schema",
				"json_schema": {
					"name": "structured_output",
					"strict": true,
					"schema": json_schema
				}
			}
		else:
			# Fallback to JSON mode for providers/models that don't support JSON Schema on chat completions
			request_body["response_format"] = {"type": "json_object"}
	
	var headers = [
		"Content-Type: application/json"
	]
	
	if settings.api_key != "":
		if settings.provider == "ollama":
			# Ollama doesn't require auth headers typically
			pass
		else:
			headers.append("Authorization: Bearer " + settings.api_key)
	
	var json_string = JSON.stringify(request_body)
	if settings.debug_trace:
		print("=== LLM REQUEST ===")
		print("Provider: " + settings.provider)
		print("Model: " + (model_override if model_override != "" else settings.model))
		print("Messages:\n" + JSON.stringify(messages, "\t"))
		if json_schema.size() > 0:
			print("JSON Schema:\n" + JSON.stringify(json_schema, "\t"))
		print("Request Body:\n" + json_string)
	
	var error = http_request.request(url, headers, HTTPClient.METHOD_POST, json_string)
	if error != OK:
		request_error.emit("Failed to start HTTP request: " + str(error))
		return ""
	
	# Wait for response asynchronously
	var request_id = str(Time.get_ticks_msec())
	
	pending_response[request_id] = {
		"received": false,
		"text": "",
		"error": ""
	}
	
	# Wait for response
	var max_wait = 60.0
	var elapsed = 0.0
	while not pending_response[request_id].received:
		await get_tree().process_frame
		elapsed += get_process_delta_time()
		if elapsed > max_wait:
			pending_response.erase(request_id)
			request_error.emit("Request timeout")
			return ""
	
	var result = pending_response[request_id]
	pending_response.erase(request_id)
	
	if result.error != "":
		request_error.emit(result.error)
		return ""
	
	return result.text

func _on_request_completed(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray):
	var callback = null
	if pending_response.size() > 0:
		var key = pending_response.keys()[0]
		callback = pending_response[key]
	
	var body_text = ""
	if body and body.size() > 0:
		body_text = body.get_string_from_utf8()
	if settings.debug_trace:
		print("=== LLM RESPONSE ===")
		print("HTTP Result: " + str(result) + ", Code: " + str(response_code))
		if body_text != "":
			print("Raw Body:\n" + body_text)

	if result != HTTPRequest.RESULT_SUCCESS:
		var error_msg = "HTTP request failed: " + str(result)
		if callback:
			callback.received = true
			callback.error = error_msg
		else:
			request_error.emit(error_msg)
		return
	
	if response_code != 200:
		var error_text = body.get_string_from_utf8()
		var error_msg = "HTTP error " + str(response_code) + ": " + error_text
		if callback:
			callback.received = true
			callback.error = error_msg
		else:
			request_error.emit(error_msg)
		return
	
	var json = JSON.new()
	var parse_error = json.parse(body_text)
	if parse_error != OK:
		var error_msg = "Failed to parse JSON response"
		if callback:
			callback.received = true
			callback.error = error_msg
		else:
			request_error.emit(error_msg)
		return
	
	var response = json.data
	if not response.has("choices") or response.choices.size() == 0:
		var error_msg = "No choices in response"
		if callback:
			callback.received = true
			callback.error = error_msg
		else:
			request_error.emit(error_msg)
		return
	
	var content = response.choices[0].message.content
	if callback:
		callback.received = true
		callback.text = content
	else:
		request_complete.emit(content)
