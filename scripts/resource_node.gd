class_name ResourceNode
extends Node2D

## Điểm tài nguyên trên map (vô hạn ở M1): cây gỗ / mỏ đá / mỏ vàng.

var res_type: String = "wood" # wood | stone | gold
var is_big: bool = false

func setup(p_type: String, p_big: bool) -> void:
	res_type = p_type
	is_big = p_big
	add_to_group("res_nodes")
	var spr := Sprite2D.new()
	match p_type:
		"wood":
			var at := AtlasTexture.new()
			at.atlas = load("res://assets/deco/tree.png")
			at.region = Rect2(0, 0, 256, 256)
			spr.texture = at
			spr.scale = Vector2(0.62, 0.62) if p_big else Vector2(0.44, 0.44)
			spr.position = Vector2(0, -46)
		"stone":
			spr.texture = load("res://assets/resources/stone.png")
			spr.scale = Vector2(1.15, 1.15) if p_big else Vector2(0.8, 0.8)
			spr.position = Vector2(0, -18)
		"gold":
			spr.texture = load("res://assets/resources/goldmine.png")
			spr.scale = Vector2(1.05, 1.05) if p_big else Vector2(0.72, 0.72)
			spr.position = Vector2(0, -16)
	add_child(spr)
