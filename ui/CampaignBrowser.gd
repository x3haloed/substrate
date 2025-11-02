extends Control

signal campaign_selected(cartridge: Cartridge, file_path: String)
signal closed()

@onready var grid: GridContainer = $MarginContainer/VBox/Scroll/Grid

const THUMB_PREFERRED_SIZE := 512

func _ready():
	# Autoload singletons are available as global variables
	if CartridgeManagerTool and not CartridgeManagerTool.library_updated.is_connected(refresh):
		CartridgeManagerTool.library_updated.connect(refresh)
	refresh()

func refresh():
	if not is_instance_valid(grid):
		return
	# Clear
	for child in grid.get_children():
		child.queue_free()
	# Populate
	var mgr := CartridgeManagerTool
	if mgr == null:
		return
	var items := mgr.get_library()
	# Use the player library by default in the campaign browser
	items = mgr.get_library(CartridgeManager.StoreKind.PLAYER)
	for item in items:
		var file_path := str(item.get("path", ""))
		var cart: Cartridge = item.get("cartridge", null)
		if cart == null:
			continue
		var entry := _create_card(cart, file_path)
		grid.add_child(entry)

func _create_card(cart: Cartridge, file_path: String) -> Control:
	var card := Button.new()
	card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	card.size_flags_vertical = Control.SIZE_EXPAND_FILL
	card.focus_mode = Control.FOCUS_NONE
	card.clip_text = false
	card.text = ""  # We will add children for layout

	var vb := VBoxContainer.new()
	vb.custom_minimum_size = Vector2(280, 360)
	vb.alignment = BoxContainer.ALIGNMENT_BEGIN
	card.add_child(vb)

	var tex := TextureRect.new()
	tex.stretch_mode = TextureRect.STRETCH_SCALE
	tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tex.custom_minimum_size = Vector2(280, 180)
	tex.texture = _load_thumbnail_from_zip(file_path, cart.get_thumbnail_path(THUMB_PREFERRED_SIZE))
	vb.add_child(tex)

	var title := Label.new()
	title.text = cart.name
	title.autowrap_mode = TextServer.AUTOWRAP_WORD
	title.clip_text = false
	vb.add_child(title)

	var meta := Label.new()
	meta.text = "%s  ·  v%s" % [cart.author if cart.author != "" else "", cart.version]
	meta.modulate = Color(0.9, 0.9, 0.9, 0.8)
	meta.autowrap_mode = TextServer.AUTOWRAP_WORD
	vb.add_child(meta)

	card.pressed.connect(func():
		campaign_selected.emit(cart, file_path)
	)

	return card

func _load_thumbnail_from_zip(zip_path: String, internal_path: String) -> Texture2D:
	if zip_path == "" or internal_path == "":
		return null
	var zip := ZIPReader.new()
	var err := zip.open(zip_path)
	if err != OK:
		return null
	if not zip.file_exists(internal_path):
		# Fallback cascade
		for k in ["previews/thumbnail_512.png", "previews/thumbnail_1024.png", "previews/thumbnail_256.png"]:
			if zip.file_exists(k):
				internal_path = k
				break
	if not zip.file_exists(internal_path):
		zip.close()
		return null
	var bytes: PackedByteArray = zip.read_file(internal_path)
	zip.close()
	if bytes.is_empty():
		return null
	var img := Image.new()
	var ierr := img.load_png_from_buffer(bytes)
	if ierr != OK:
		return null
	var tex := ImageTexture.create_from_image(img)
	return tex

func hide_browser():
	visible = false
	closed.emit()
