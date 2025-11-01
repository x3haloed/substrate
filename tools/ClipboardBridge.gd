extends Node
class_name ClipboardBridge

var _paste_cb: JavaScriptObject

func _ready() -> void:
    # Only relevant for Web exports.
    if not OS.has_feature("web"):
        return

    # 1) Create a callback JS can call with the pasted text.
    _paste_cb = JavaScriptBridge.create_callback(_on_js_paste)

    # 2) Install a global JS handler that fires on real browser paste.
    #    Works on Ctrl/Cmd+V and context-menu paste; reads event data first,
    #    falls back to navigator.clipboard inside the user gesture.
    JavaScriptBridge.eval(r"""
        (function () {
            if (!window.__godotClipboard) window.__godotClipboard = {};
            window.__godotClipboard._send = function(_) {}; // placeholder; replaced from Godot

            function handlePaste(ev) {
                try {
                    // Prefer the event payload (works even without clipboard permissions).
                    let text = '';
                    if (ev && ev.clipboardData && typeof ev.clipboardData.getData === 'function') {
                        text = ev.clipboardData.getData('text/plain') || '';
                    }
                    if (text) {
                        window.__godotClipboard._send(text);
                        return;
                    }
                    // Fallback: navigator.clipboard (must be in a user gesture).
                    if (navigator.clipboard && navigator.clipboard.readText) {
                        navigator.clipboard.readText().then(function(t){
                            window.__godotClipboard._send(t || '');
                        }).catch(function(){ /* ignore */ });
                    }
                } catch (_) { /* ignore */ }
            }

            // Use capture to ensure we see it even if the canvas stops propagation.
            document.addEventListener('paste', handlePaste, true);
            // Bonus: catch Ctrl/Cmd+V when sites suppress 'paste' but not keydown.
            document.addEventListener('keydown', function(ev){
                const ctrl = ev.ctrlKey || ev.metaKey;
                if (ctrl && (ev.key === 'v' || ev.key === 'V')) {
                    // Attempt async read as a fallback.
                    if (navigator.clipboard && navigator.clipboard.readText) {
                        navigator.clipboard.readText().then(function(t){
                            if (t) window.__godotClipboard._send(t);
                        }).catch(function(){ /* ignore */ });
                    }
                }
            }, true);
        })();
    """)

    # 3) Wire JS -> Godot callback.
    var iface := JavaScriptBridge.get_interface("__godotClipboard")
    if iface:
        iface._send = _paste_cb  # set JS function to call our callback

func _on_js_paste(args: Array) -> void:
    if args.is_empty():
        return
    var text := str(args[0])

    # Insert into whichever control currently has focus.
    var f := get_viewport().gui_get_focus_owner()
    if f is LineEdit:
        (f as LineEdit).insert_text_at_caret(text)
    elif f is TextEdit:
        var te := f as TextEdit
        te.insert_text_at_caret(text)


