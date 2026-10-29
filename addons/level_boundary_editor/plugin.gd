@tool
extends EditorPlugin

# Draws a Level's boundaries (setDefaultLeft / defaultLeftBoundry, etc.) as a rectangle in the
# 2D editor viewport. Select the Level node, hover one of the rectangle's edges or corners, and
# drag to resize it. Hold Ctrl to snap to SNAP_STEP pixels. Changes can be undone with Ctrl+Z.
#
# Sides that aren't set (checkbox off, or a huge placeholder value) are drawn as dashed lines
# along the border of the viewport. Drag one inward to place it; that turns the side on.
# Requires Godot 4.2+ (uses the EditorInterface singleton).

const LEFT = 1
const TOP = 2
const RIGHT = 4
const BOTTOM = 8

const GRAB_DISTANCE = 8.0		# how close (screen px) the mouse must be to an edge to grab it
const UNSET_MARGIN = 14.0		# unset sides are drawn this far inside the viewport border
const UNSET_LIMIT = 1000000		# boundary values at or beyond this count as "no boundary"
const SNAP_STEP = 16			# pixels, used while Ctrl is held

const COLOR_EDGE = Color(0.35, 0.8, 1.0, 0.9)
const COLOR_UNSET = Color(0.35, 0.8, 1.0, 0.45)
const COLOR_HOT = Color(1.0, 0.85, 0.2, 1.0)

# per side: [value property, enabled property, label]
const PROPS = {
	LEFT: ["defaultLeftBoundry", "setDefaultLeft", "Left"],
	TOP: ["defaultTopBoundry", "setDefaultTop", "Top"],
	RIGHT: ["defaultRightBoundry", "setDefaultRight", "Right"],
	BOTTOM: ["defaultBottomBoundry", "setDefaultBottom", "Bottom"],
}

var selected_level = null			# the Level node that is currently selected (the one that can be edited)
var hovered = 0						# bitmask of sides under the mouse
var dragging = 0					# bitmask of sides being dragged
var drag_start = {}					# property -> value when the drag started (for undo)
var grab_offset = Vector2.ZERO		# keeps the edge from jumping when you grab it slightly off-centre
var last_view = Rect2(0, 0, 1152, 648)
var last_signature = ""

func _enter_tree():
	# lets us draw the rectangle even when the Level node isn't selected
	set_force_draw_over_forwarding_enabled()

# redraw when the numbers/checkboxes are changed in the inspector
func _process(_delta):
	var level = _drawn_level()
	if level == null:
		return
	var parts = []
	for side in PROPS:
		parts.append(level.get(PROPS[side][0]))
		parts.append(level.get(PROPS[side][1]))
	var signature = str(parts)
	if signature != last_signature:
		last_signature = signature
		update_overlays()

# ---------------------------------------------------------------- editor plugin hooks

func _handles(object) -> bool:
	return _is_level(object)

func _edit(object):
	selected_level = object if _is_level(object) else null
	hovered = 0
	update_overlays()

func _make_visible(visible):
	if not visible and dragging == 0:
		selected_level = null
		hovered = 0
	update_overlays()

func _forward_canvas_gui_input(event) -> bool:
	if not _is_level(selected_level):
		return false
	
	if event is InputEventMouseMotion:
		if dragging != 0:
			_drag_to(event.position, event.ctrl_pressed)
			return true
		var h = _hit_test(selected_level, event.position)
		if h != hovered:
			hovered = h
			update_overlays()
		return false
	
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed and dragging == 0 and not event.alt_pressed:
			var h = _hit_test(selected_level, event.position)
			if h != 0:
				_begin_drag(h, event.position)
				return true # consume so the editor doesn't also select/move other nodes
		elif not event.pressed and dragging != 0:
			_end_drag()
			return true
	return false

func _forward_canvas_force_draw_over_viewport(overlay: Control):
	var level = _drawn_level()
	if level == null:
		return
	last_view = Rect2(Vector2.ZERO, overlay.size)
	var e = _edges(level)
	var hot = dragging
	if hot == 0 and level == selected_level:
		hot = hovered
	
	for side in PROPS:
		_draw_side(overlay, level, side, e, hot)
	if hot != 0:
		_draw_handle(overlay, level, e, hot)

# ---------------------------------------------------------------- helpers

func _is_level(node) -> bool:
	return node != null and is_instance_valid(node) and node is Node2D and node.get("defaultLeftBoundry") != null

# the Level to draw: the selected one, otherwise the root of the open scene
func _drawn_level():
	if _is_level(selected_level):
		return selected_level
	var root = EditorInterface.get_edited_scene_root()
	if _is_level(root):
		return root
	return null

func _is_unset(level, side) -> bool:
	var p = PROPS[side]
	return not level.get(p[1]) or abs(level.get(p[0])) >= UNSET_LIMIT

# screen position of each side (x for left/right, y for top/bottom)
func _edges(level) -> Dictionary:
	var e = {}
	var vt: Transform2D = level.get_viewport_transform()
	for side in PROPS:
		if _is_unset(level, side):
			match side:
				LEFT: e[side] = last_view.position.x + UNSET_MARGIN
				TOP: e[side] = last_view.position.y + UNSET_MARGIN
				RIGHT: e[side] = last_view.end.x - UNSET_MARGIN
				_: e[side] = last_view.end.y - UNSET_MARGIN
		else:
			var v = level.get(PROPS[side][0])
			if side == LEFT or side == RIGHT:
				e[side] = (vt * Vector2(v, 0)).x
			else:
				e[side] = (vt * Vector2(0, v)).y
	return e

# which side(s) the mouse is over (two bits set = a corner)
func _hit_test(level, mouse: Vector2) -> int:
	var e = _edges(level)
	var x0 = min(e[LEFT], e[RIGHT])
	var x1 = max(e[LEFT], e[RIGHT])
	var y0 = min(e[TOP], e[BOTTOM])
	var y1 = max(e[TOP], e[BOTTOM])
	var in_x = mouse.x >= x0 - GRAB_DISTANCE and mouse.x <= x1 + GRAB_DISTANCE
	var in_y = mouse.y >= y0 - GRAB_DISTANCE and mouse.y <= y1 + GRAB_DISTANCE
	var mask = 0
	if in_y:
		if abs(mouse.x - e[LEFT]) <= GRAB_DISTANCE:
			mask |= LEFT
		if abs(mouse.x - e[RIGHT]) <= GRAB_DISTANCE:
			mask |= RIGHT
	if in_x:
		if abs(mouse.y - e[TOP]) <= GRAB_DISTANCE:
			mask |= TOP
		if abs(mouse.y - e[BOTTOM]) <= GRAB_DISTANCE:
			mask |= BOTTOM
	# very thin rectangle: only grab the nearer side
	if (mask & LEFT) != 0 and (mask & RIGHT) != 0:
		mask &= ~(RIGHT if abs(mouse.x - e[LEFT]) <= abs(mouse.x - e[RIGHT]) else LEFT)
	if (mask & TOP) != 0 and (mask & BOTTOM) != 0:
		mask &= ~(BOTTOM if abs(mouse.y - e[TOP]) <= abs(mouse.y - e[BOTTOM]) else TOP)
	return mask

func _begin_drag(mask: int, mouse: Vector2):
	dragging = mask
	drag_start = {}
	for side in PROPS:
		if (mask & side) != 0:
			drag_start[PROPS[side][0]] = selected_level.get(PROPS[side][0])
			drag_start[PROPS[side][1]] = selected_level.get(PROPS[side][1])
	var e = _edges(selected_level)
	grab_offset = Vector2.ZERO
	if (mask & LEFT) != 0:
		grab_offset.x = e[LEFT] - mouse.x
	elif (mask & RIGHT) != 0:
		grab_offset.x = e[RIGHT] - mouse.x
	if (mask & TOP) != 0:
		grab_offset.y = e[TOP] - mouse.y
	elif (mask & BOTTOM) != 0:
		grab_offset.y = e[BOTTOM] - mouse.y

func _drag_to(mouse: Vector2, snap: bool):
	var level = selected_level
	var vt: Transform2D = level.get_viewport_transform()
	var world: Vector2 = vt.affine_inverse() * (mouse + grab_offset)
	if snap:
		world = world.snapped(Vector2(SNAP_STEP, SNAP_STEP))
	for side in PROPS:
		if (dragging & side) == 0:
			continue
		var v = int(round(world.x if (side == LEFT or side == RIGHT) else world.y))
		level.set(PROPS[side][0], _limit(level, side, v))
		level.set(PROPS[side][1], true) # dragging a side turns it on
	level.notify_property_list_changed()
	update_overlays()

# keep left < right and top < bottom
func _limit(level, side, v: int) -> int:
	var opposite = {LEFT: RIGHT, RIGHT: LEFT, TOP: BOTTOM, BOTTOM: TOP}[side]
	if _is_unset(level, opposite):
		return v
	var o = level.get(PROPS[opposite][0])
	if side == LEFT or side == TOP:
		return min(v, o - 1)
	return max(v, o + 1)

func _end_drag():
	var ur = get_undo_redo()
	ur.create_action("Resize Level Boundaries")
	for prop in drag_start:
		ur.add_do_property(selected_level, prop, selected_level.get(prop))
		ur.add_undo_property(selected_level, prop, drag_start[prop])
	ur.commit_action()
	dragging = 0
	drag_start = {}
	update_overlays()

# ---------------------------------------------------------------- drawing

func _draw_side(overlay: Control, level, side: int, e: Dictionary, hot: int):
	var view = last_view
	var unset = _is_unset(level, side)
	var color = COLOR_UNSET if unset else COLOR_EDGE
	if (hot & side) != 0:
		color = COLOR_HOT
	var a: Vector2
	var b: Vector2
	if side == LEFT or side == RIGHT:
		var x = e[side]
		if x < view.position.x - 1.0 or x > view.end.x + 1.0:
			return
		a = Vector2(x, clampf(e[TOP], view.position.y, view.end.y))
		b = Vector2(x, clampf(e[BOTTOM], view.position.y, view.end.y))
	else:
		var y = e[side]
		if y < view.position.y - 1.0 or y > view.end.y + 1.0:
			return
		a = Vector2(clampf(e[LEFT], view.position.x, view.end.x), y)
		b = Vector2(clampf(e[RIGHT], view.position.x, view.end.x), y)
	var width = 2.0 if (hot & side) != 0 else 1.0
	if unset:
		overlay.draw_dashed_line(a, b, color, width, 6.0)
	else:
		overlay.draw_line(a, b, color, width)

# sizing handle and value label at the hovered / dragged edge or corner
func _draw_handle(overlay: Control, level, e: Dictionary, hot: int):
	var mouse = overlay.get_local_mouse_position()
	var p = Vector2.ZERO
	if (hot & LEFT) != 0:
		p.x = e[LEFT]
	elif (hot & RIGHT) != 0:
		p.x = e[RIGHT]
	else:
		p.x = clampf(mouse.x, min(e[LEFT], e[RIGHT]), max(e[LEFT], e[RIGHT]))
	if (hot & TOP) != 0:
		p.y = e[TOP]
	elif (hot & BOTTOM) != 0:
		p.y = e[BOTTOM]
	else:
		p.y = clampf(mouse.y, min(e[TOP], e[BOTTOM]), max(e[TOP], e[BOTTOM]))
	
	var handle = Rect2(p - Vector2(5, 5), Vector2(10, 10))
	overlay.draw_rect(handle, COLOR_HOT)
	overlay.draw_rect(handle, Color.BLACK, false, 1.0)
	
	var texts = []
	for side in PROPS:
		if (hot & side) != 0:
			var shown = "unset" if _is_unset(level, side) else str(level.get(PROPS[side][0]))
			texts.append("%s: %s" % [PROPS[side][2], shown])
	var text = "   ".join(texts)
	var font = ThemeDB.fallback_font
	var size = ThemeDB.fallback_font_size
	var pos = p + Vector2(12, -10)
	overlay.draw_string_outline(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, 4, Color.BLACK)
	overlay.draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, size, Color.WHITE)
