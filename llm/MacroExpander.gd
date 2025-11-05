extends RefCounted
class_name MacroExpander

## Single-pass allowlisted macro expander compatible with common ST-style tags.
## Intentionally avoids nesting and side effects. Unknown macros are preserved.

static func expand(text: String, ctx: Dictionary = {}) -> String:
    if typeof(text) != TYPE_STRING or text == "":
        return text

    var out := String(text)

    # Support angle-bracket variants
    out = out.replace("<USER>", str(ctx.get("user_name", "You")))
    out = out.replace("<BOT>", str(ctx.get("char_name", ctx.get("character_name", ""))))

    var regex := RegEx.new()
    var err := regex.compile("\\{\\{([^{}]+)\\}\\}")
    if err != OK:
        return out

    var _replace := func(full: String, inner: String) -> String:
        var token_raw := inner.strip_edges()
        var token := token_raw.to_lower()

        # General mapping (no arguments)
        match token:
            "user":
                return str(ctx.get("user_name", "You"))
            "char":
                return str(ctx.get("char_name", ctx.get("character_name", "")))
            "description":
                return str(ctx.get("char_description", ctx.get("description", "")))
            "personality":
                return str(ctx.get("char_personality", ctx.get("personality", "")))
            "mesexamples":
                return str(ctx.get("mes_examples", ctx.get("mes_example", "")))
            "charversion":
                return str(ctx.get("char_version", ctx.get("character_version", "")))
            "scenario":
                return str(ctx.get("scene_description", ctx.get("scenario", "")))
            "time":
                return _time_string()
            "date":
                return _date_string()
            "weekday":
                return _weekday_string()
            "isotime":
                return _iso_time_string()
            "isodate":
                return _iso_date_string()
            "lastmessage":
                return str(ctx.get("last_message", ""))
            "lastusermessage":
                return str(ctx.get("last_user_message", ""))
            "lastcharmessage":
                return str(ctx.get("last_char_message", ""))
            _:
                pass

        # time_UTC±X
        if token.begins_with("time_utc"):
            return _time_with_utc_offset(token_raw)

        # datetimeformat ... (basic subset: supports YYYY, MM, DD, HH, mm, ss)
        if token.begins_with("datetimeformat"):
            var fmt := token_raw.substr("datetimeformat".length()).strip_edges()
            return _format_datetime(fmt)

        # getvar::name / getglobalvar::name (read-only)
        if token.begins_with("getvar::"):
            var name := token_raw.substr(8)
            return str(ctx.get("vars_local", {}).get(name, ""))
        if token.begins_with("getglobalvar::"):
            var gname := token_raw.substr(13)
            return str(ctx.get("vars_global", {}).get(gname, ""))

        # Unknown macro: leave as-is to preserve compatibility
        return full

    # Perform single-pass replacement
    var result := ""
    var last_end := 0
    var matches := regex.search_all(out)
    if matches == null:
        return out
    for m in matches:
        var s := m.get_start(0)
        var e := m.get_end(0)
        var inner := m.get_string(1)
        result += out.substr(last_end, s - last_end)
        result += _replace.call(m.get_string(0), inner)
        last_end = e
    result += out.substr(last_end)
    return result

static func _time_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%02d:%02d" % [int(dt["hour"]), int(dt["minute"])]

static func _date_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%04d-%02d-%02d" % [int(dt["year"]), int(dt["month"]), int(dt["day"])]

static func _weekday_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    # Godot returns weekday: 0=Sunday..6=Saturday
    var names := ["Sunday", "Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday"]
    var idx := int(dt.get("weekday", 0))
    if idx >= 0 and idx < names.size():
        return names[idx]
    return ""

static func _iso_time_string() -> String:
    var dt := Time.get_datetime_dict_from_system()
    return "%02d:%02d:%02d" % [int(dt["hour"]), int(dt["minute"]), int(dt["second"])]

static func _iso_date_string() -> String:
    return _date_string()

static func _time_with_utc_offset(token_raw: String) -> String:
    # token_raw like: time_UTC+2 or time_UTC-5
    var sign_idx := token_raw.find("UTC")
    if sign_idx == -1:
        return _time_string()
    var offs := token_raw.substr(sign_idx + 3)
    offs = offs.strip_edges()
    if offs == "":
        return _time_string()
    var hours := int(offs)
    var dt := Time.get_datetime_dict_from_system()
    var h := int(dt["hour"]) + hours
    h = int(posmod(h, 24))
    return "%02d:%02d" % [h, int(dt["minute"])]

static func _format_datetime(fmt: String) -> String:
    # Basic formatter: replace placeholders in fmt
    var dt := Time.get_datetime_dict_from_system()
    var out := String(fmt)
    out = out.replace("YYYY", "%04d" % int(dt["year"]))
    out = out.replace("MM", "%02d" % int(dt["month"]))
    out = out.replace("DD", "%02d" % int(dt["day"]))
    out = out.replace("HH", "%02d" % int(dt["hour"]))
    out = out.replace("mm", "%02d" % int(dt["minute"]))
    out = out.replace("ss", "%02d" % int(dt["second"]))
    return out


