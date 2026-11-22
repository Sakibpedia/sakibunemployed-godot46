extends Node
## Optional on-device inference through IREE.gd (design doc Section 14), behind a feature flag.
## First use: a small pose model in Level 12 that reads the coaching centre's CCTV frames.
## The game runs fully without it; every caller must handle enabled == false.

const FLAG := "game/ai/iree_pose_model"
const MODULE_PATH := "res://models/pose.vmfb"
## Set this to the class your IREE.gd build registers; it varies between releases.
const IREE_CLASS := &"IREEModule"

var enabled := false
var _module: Object = null


func _ready() -> void:
	if not ProjectSettings.get_setting(FLAG, false):
		return
	if not ClassDB.class_exists(IREE_CLASS) or not FileAccess.file_exists(MODULE_PATH):
		push_warning("IREE pose model unavailable; feature stays off")
		return
	_module = ClassDB.instantiate(IREE_CLASS)
	if _module and _module.has_method(&"load"):
		_module.call(&"load", MODULE_PATH)
		enabled = true


## Returns 2D keypoints (normalised 0..1) for one frame, or an empty array when disabled.
func estimate_pose(frame: Image) -> PackedVector2Array:
	if not enabled or frame == null:
		return PackedVector2Array()
	var rgb := frame.duplicate() as Image
	rgb.convert(Image.FORMAT_RGB8)
	rgb.resize(192, 192, Image.INTERPOLATE_BILINEAR)
	var out = _module.call(&"run", rgb.get_data())   # adapter call; see README
	return out if out is PackedVector2Array else PackedVector2Array()
