extends Node2D

@export var music = preload("res://Audio/Soundtrack/6. SWD_TLZa1.ogg")
@export var nextZone: String = "res://Scene/Zones/BaseZone.tscn"

@export_enum("Bird", "Squirrel", "Rabbit", "Chicken", "Penguin", "Seal", "Pig", "Eagle", "Mouse", "Monkey", "Turtle", "Bear")var animal1 = 0
@export_enum("Bird", "Squirrel", "Rabbit", "Chicken", "Penguin", "Seal", "Pig", "Eagle", "Mouse", "Monkey", "Turtle", "Bear")var animal2 = 1

# Boundries (world coordinates, in pixels)
# With the "Level Boundary Editor" plugin enabled (Project Settings > Plugins), these are drawn as a
# rectangle in the 2D viewport. Select this node, then drag the rectangle's edges or corners to resize it.
# A side whose checkbox is off, or that still has a huge placeholder value, is drawn dashed along the
# border of the viewport; drag it inward to place it (that also turns the checkbox on).
# These values only affect the running game, so this script does not need to be a @tool script.
@export_group("Level Boundaries")
## Use the left boundary below.
@export var setDefaultLeft = true
## Left edge of the level (x, pixels).
@export var defaultLeftBoundry  = -100000000
## Use the top boundary below.
@export var setDefaultTop = true
## Top edge of the level (y, pixels).
@export var defaultTopBoundry  = -100000000

## Use the right boundary below.
@export var setDefaultRight = true
## Right edge of the level (x, pixels).
@export var defaultRightBoundry = 100000000
## Use the bottom boundary below.
@export var setDefaultBottom = true
## Bottom edge of the level (y, pixels).
@export var defaultBottomBoundry = 100000000

func _ready():
	if setDefaultLeft:
		Global.hardBorderLeft  = defaultLeftBoundry
	if setDefaultRight:
		Global.hardBorderRight = defaultRightBoundry
	if setDefaultTop:
		Global.hardBorderTop    = defaultTopBoundry
	if setDefaultBottom:
		Global.hardBorderBottom  = defaultBottomBoundry
	
	level_reset_data(false)

# used for stage starts, also used for returning from special stages
func level_reset_data(playCard = true):
	# music handling
	Global.bossMusic.stop()
	if Global.music != null:
		if music != null:
			Global.music.stream = music
			Global.music.play()
			Global.music.stream_paused = false
		else:
			Global.music.stop()
			Global.music.stream = null
	
	# set next zone
	if nextZone != null:
		Global.nextZone = nextZone
	
	Main.sceneCanPause = true
	# set animals
	Global.animals = [animal1,animal2]
	# if global hud and play card, run hud ready script
	if playCard and is_instance_valid(Global.hud):
		$HUD._ready()
