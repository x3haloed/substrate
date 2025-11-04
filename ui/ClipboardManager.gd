extends AcceptDialog
class_name ClipboardManager

@onready var show_button: Button = $VBoxContainer/HBoxContainer/ShowButton
@onready var paste_button: Button = $VBoxContainer/HBoxContainer/PasteFromOSButton
@onready var clipboard_view: TextEdit = $VBoxContainer/ClipboardView
@onready var clear_button: Button = $VBoxContainer/HBoxContainer/ClearButton

var _paste_cb: JavaScriptObject

func _ready() -> void:
	title = "Clipboard Manager"
	if show_button:
		show_button.pressed.connect(_on_show_pressed)
	if paste_button:
		paste_button.pressed.connect(_on_paste_from_os_pressed)
	if clear_button:
		clear_button.pressed.connect(_on_clear_pressed)

	# Only relevant for Web exports; disable OS paste button otherwise
	if not OS.has_feature("web"):
		paste_button.disabled = true
		return

	# Prepare JS bridge interface for paste results
	_paste_cb = JavaScriptBridge.create_callback(_on_js_clipboard_text)
	JavaScriptBridge.eval(r"""
        (function(){
            if (!window.__godotClipboard) window.__godotClipboard = {};
            window.__godotClipboard._send = function(_){}; // will be replaced from Godot
        })();
	""")
	var iface := JavaScriptBridge.get_interface("__godotClipboard")
	if iface:
		iface._send = _paste_cb

func _on_show_pressed() -> void:
	var txt := DisplayServer.clipboard_get()
	clipboard_view.text = txt if typeof(txt) == TYPE_STRING else str(txt)

func _on_paste_from_os_pressed() -> void:
	# Must be triggered by a user gesture; works on the Web in button handler
	if not OS.has_feature("web"):
		return
	JavaScriptBridge.eval(r"""
        (function(){
            try {
                if (navigator.clipboard && navigator.clipboard.readText) {
                    navigator.clipboard.readText().then(function(t){
                        if (!window.__godotClipboard) window.__godotClipboard = {};
                        if (window.__godotClipboard._send) window.__godotClipboard._send(t || '');
                    }).catch(function(){ /* ignore */ });
                }
            } catch (_) { /* ignore */ }
        })();
	""")

func _on_js_clipboard_text(args: Array) -> void:
	if args.is_empty():
		return
	var text := str(args[0])
	DisplayServer.clipboard_set(text)
	clipboard_view.text = text

func _on_clear_pressed() -> void:
	DisplayServer.clipboard_set("")
	clipboard_view.text = ""
