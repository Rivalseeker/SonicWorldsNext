@tool
extends StaticBody2D

@export_enum("Yellow", "Red") var type = 0
@export_enum("Up", "Down", "Right", "Left", "Diagonal Up Right", "Diagonal Up Left", "Diagonal Down Right", "Diagonal Down Left") var springDirection = 0
var hitDirection = Vector2.UP
var animList = ["SpringUp","SpringRight","SpringUpLeft","SpringUpRight"]
var animID = 0
var dirMemory = springDirection
var typeMemory = type
var speed = [10,16]

# Exported multiplier for testing Amy's enhanced hammer spring launch in the inspector
@export var amyHammerBoostMultiplier: float = 1.25

var springTextures = [preload("res://Graphics/Gimmicks/springs_yellow.png"),preload("res://Graphics/Gimmicks/springs_red.png")]

@export var springSound = preload("res://Audio/SFX/Gimmicks/Springs.wav")

func _ready():
	set_spring()

func _process(_delta):
	if Engine.is_editor_hint():
		if (springDirection != dirMemory or typeMemory != type):
			dirMemory = springDirection
			typeMemory = type
			set_spring()


func set_spring():
	match (springDirection):
		0, 1: # up, down
			$HitBox.disabled = false
			$DiagonalHitBox/AreaShape.disabled = true
			animID = 0
			$HitBox.rotation = deg_to_rad(0)
			scale = Vector2(1,1-(springDirection*2))
			hitDirection = Vector2(0,-1+(springDirection*2))
		2, 3: # right, left
			$HitBox.disabled = false
			$DiagonalHitBox/AreaShape.disabled = true
			animID = 1
			$HitBox.rotation = deg_to_rad(90)
			scale = Vector2(1-((springDirection-2)*2),1)
			hitDirection = Vector2(1-((springDirection-2)*2),0)
		4, 6: #diagonal right
			$HitBox.disabled = true
			$DiagonalHitBox/AreaShape.disabled = false
			animID = 3
			scale = Vector2(1,1-(springDirection-4))
			# place super.normalized() at the end for CD physics
			hitDirection = scale*Vector2(1,-1)
		5, 7: #diagonal left
			$HitBox.disabled = true
			$DiagonalHitBox/AreaShape.disabled = false
			animID = 2
			scale = Vector2(1,1-(springDirection-5))
			# place super.normalized() at the end for CD physics
			hitDirection = -scale
			
	$SpringAnimator.play(animList[animID])
	$SpringAnimator.advance($SpringAnimator.get_animation(animList[animID]).length)
	if $Spring.texture != springTextures[type]:
		$Spring.texture = springTextures[type]


# Collision check
func physics_collision(body, hitVector):
	# Determine if Amy currently has her hammer out (grounded or airborne)
	var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and (body.currentState == body.STATES.AMYHAMMER or body.animator.current_animation == "dropDash" or body.animator.current_animation == "hammerSwing"))

	# Standard vector direction check
	var valid_hit = (hitVector == -hitDirection)
	
	# Allow side/alternate hits for Up, Down, Left, and Right springs when Amy has her hammer out
	if not valid_hit and (springDirection >= 0 and springDirection <= 3):
		if is_amy_hammer:
			if springDirection == 0 or springDirection == 2 or springDirection == 3:
				# Up, Right, and Left springs can be triggered from the side when airborne, landing, or grounded
				valid_hit = true
			elif springDirection == 1 and not body.ground:
				# Down springs can be triggered from the side when airborne
				valid_hit = true

	if valid_hit:
		var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
		
		# do a Rock launch HAUGH!!!
		var setMove = hitDirection.rotated(rotation).rotated(-body.rotation).round()*speed[type]*60*boost
		
		# vertical movement
		if setMove.y != 0:
			var curAnim = "walk"
			match(body.animator.current_animation):
				"walk", "run", "peelOut":
					curAnim = body.animator.current_animation
				_:
					if(abs(body.groundSpeed) >= min(6*60,body.top)):
						curAnim = "run"
			body.animator.play("spring")
			body.animator.queue(curAnim)
			body.movement.y = setMove.y
			body.set_state(body.STATES.AIR)
			body.disconect_from_floor()
		# horizontal movement
		else:
			match(body.currentState):
				body.STATES.GLIDE:
					if !body.ground:
						body.animator.play("run")
						body.set_state(body.STATES.AIR)
				body.STATES.AMYHAMMER:
					body.animator.play("run")
					body.set_state(body.STATES.AIR)
					body.disconect_from_floor()
			body.movement.x = setMove.x
			body.horizontalLockTimer = (15.0/60.0)
			body.direction = sign(setMove.x)
		
		# Play spring sound at a higher pitch if boosted by hammer, otherwise normal spring sound
		if is_amy_hammer:
			var pitch_player = AudioStreamPlayer.new()
			pitch_player.stream = springSound
			pitch_player.pitch_scale = 1.35
			get_parent().add_child(pitch_player)
			pitch_player.play()
			pitch_player.finished.connect(pitch_player.queue_free)
		else:
			Global.play_sound(springSound)
		
		$SpringAnimator.play(animList[animID])
		
		#Restore Air Control
		body.airControl = true
		return true


## Collision check
#func physics_collision(body, hitVector):
	## Determine if Amy currently has her hammer out (grounded or airborne)
	#var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and (body.currentState == body.STATES.AMYHAMMER or body.animator.current_animation == "dropDash" or body.animator.current_animation == "hammerSwing"))
#
	## Standard vector direction check
	#var valid_hit = (hitVector == -hitDirection)
	#
	## Allow side/alternate hits for Up-facing (0) or Down-facing (1) vertical springs
	#if not valid_hit and (springDirection == 0 or springDirection == 1 or springDirection == 2 or springDirection == 3):
		#if body.ground:
			## Grounded: Amy with hammer can trigger Up-facing springs from the side
			#if springDirection == 0 and is_amy_hammer:
				#valid_hit = true
		#else:
			## Airborne: Amy with hammer can trigger Up-facing or Down-facing springs from the side
			#if is_amy_hammer:
				#valid_hit = true
#
	#if valid_hit:
		#var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
		#
		## do a Rock launch HAUGH!!!
		#var setMove = hitDirection.rotated(rotation).rotated(-body.rotation).round()*speed[type]*60*boost
		#
		## vertical movement
		#if setMove.y != 0:
			#var curAnim = "walk"
			#match(body.animator.current_animation):
				#"walk", "run", "peelOut":
					#curAnim = body.animator.current_animation
				#_:
					#if(abs(body.groundSpeed) >= min(6*60,body.top)):
						#curAnim = "run"
			#body.animator.play("spring")
			#body.animator.queue(curAnim)
			#body.movement.y = setMove.y
			#body.set_state(body.STATES.AIR)
			#body.disconect_from_floor()
		## horizontal movement
		#else:
			#match(body.currentState):
				#body.STATES.GLIDE:
					#if !body.ground:
						#body.animator.play("run")
						#body.set_state(body.STATES.AIR)
				#body.STATES.AMYHAMMER:
					#body.animator.play("run")
					#body.set_state(body.STATES.AIR)
					#body.disconect_from_floor()
			#body.movement.x = setMove.x
			#body.horizontalLockTimer = (15.0/60.0)
			#body.direction = sign(setMove.x)
		#
		## Play spring sound at a higher pitch if boosted by hammer, otherwise normal spring sound
		#if is_amy_hammer:
			#var pitch_player = AudioStreamPlayer.new()
			#pitch_player.stream = springSound
			#pitch_player.pitch_scale = 1.35
			#get_parent().add_child(pitch_player)
			#pitch_player.play()
			#pitch_player.finished.connect(pitch_player.queue_free)
		#else:
			#Global.play_sound(springSound)
		#
		#$SpringAnimator.play(animList[animID])
		#
		##Restore Air Control
		#body.airControl = true
		#return true
		
func _on_Diagonal_body_entered(body):
	# Check if Amy has her hammer out (grounded or airborne)
	var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and (body.currentState == body.STATES.AMYHAMMER or body.animator.current_animation == "dropDash" or body.animator.current_animation == "hammerSwing"))
	var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
	
	body.angle = body.gravityAngle
	body.movement = hitDirection.rotated(rotation).rotated(-body.rotation)*speed[type]*60*boost
	$SpringAnimator.play(animList[animID])
	
	if (hitDirection.y < 0 or is_amy_hammer):
		body.set_state(body.STATES.AIR)
		body.disconect_from_floor()
		var curAnim = "walk"
		match(body.animator.current_animation):
			"walk", "run", "peelOut":
				curAnim = body.animator.current_animation
			_:
				if(abs(body.groundSpeed) >= min(6*60,body.top)):
					curAnim = "run"
		body.animator.play("springScrew")
		body.animator.queue(curAnim)
		
	# Play spring sound at higher pitch if hammered, otherwise normal sound
	if is_amy_hammer:
		var pitch_player = AudioStreamPlayer.new()
		pitch_player.stream = springSound
		pitch_player.pitch_scale = 1.35
		get_parent().add_child(pitch_player)
		pitch_player.play()
		pitch_player.finished.connect(pitch_player.queue_free)
	else:
		Global.play_sound(springSound)


## Collision check
#func physics_collision(body, hitVector):
	## Determine if Amy currently has her hammer out (grounded or airborne)
	#var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and (body.currentState == body.STATES.AMYHAMMER or body.animator.current_animation == "dropDash" or body.animator.current_animation == "hammerSwing"))
#
	## Standard vector direction check (e.g. falling onto an up-facing spring from above)
	#var valid_hit = (hitVector == -hitDirection)
	#
	## If approaching an Up-facing spring sideways on the ground:
	## - Do NOT trigger if rolling (STATES.ROLL)
	## - DO trigger if Amy has her hammer active/swinging
	#if not valid_hit and springDirection == 0 and body.ground:
		#if is_amy_hammer:
			#valid_hit = true
#
	#if valid_hit:
		#var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
		#
		## do a Rock launch HAUGH!!!
		#var setMove = hitDirection.rotated(rotation).rotated(-body.rotation).round()*speed[type]*60*boost
		#
		## vertical movement
		#if setMove.y != 0:
			#var curAnim = "walk"
			#match(body.animator.current_animation):
				#"walk", "run", "peelOut":
					#curAnim = body.animator.current_animation
				#_:
					#if(abs(body.groundSpeed) >= min(6*60,body.top)):
						#curAnim = "run"
			#body.animator.play("spring")
			#body.animator.queue(curAnim)
			#body.movement.y = setMove.y
			#body.set_state(body.STATES.AIR)
			#body.disconect_from_floor()
		## horizontal movement
		#else:
			#match(body.currentState):
				#body.STATES.GLIDE:
					#if !body.ground:
						#body.animator.play("run")
						#body.set_state(body.STATES.AIR)
				#body.STATES.AMYHAMMER:
					#body.animator.play("run")
					#body.set_state(body.STATES.AIR)
					#body.disconect_from_floor()
			#body.movement.x = setMove.x
			#body.horizontalLockTimer = (15.0/60.0)
			#body.direction = sign(setMove.x)
		#
		## Play spring sound at a higher pitch if boosted by hammer, otherwise normal spring sound
		#if is_amy_hammer:
			#var pitch_player = AudioStreamPlayer.new()
			#pitch_player.stream = springSound
			#pitch_player.pitch_scale = 1.35
			#get_parent().add_child(pitch_player)
			#pitch_player.play()
			#pitch_player.finished.connect(pitch_player.queue_free)
		#else:
			#Global.play_sound(springSound)
		#
		#$SpringAnimator.play(animList[animID])
		#
		##Restore Air Control
		#body.airControl = true
		#return true
#
#func _on_Diagonal_body_entered(body):
	## Check if Amy has her hammer out (grounded or airborne)
	#var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and (body.currentState == body.STATES.AMYHAMMER or body.animator.current_animation == "dropDash" or body.animator.current_animation == "hammerSwing"))
	#var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
	#
	#body.angle = body.gravityAngle
	#body.movement = hitDirection.rotated(rotation).rotated(-body.rotation)*speed[type]*60*boost
	#$SpringAnimator.play(animList[animID])
	#
	#if (hitDirection.y < 0 or is_amy_hammer):
		#body.set_state(body.STATES.AIR)
		#body.disconect_from_floor()
		#var curAnim = "walk"
		#match(body.animator.current_animation):
			#"walk", "run", "peelOut":
				#curAnim = body.animator.current_animation
			#_:
				#if(abs(body.groundSpeed) >= min(6*60,body.top)):
					#curAnim = "run"
		#body.animator.play("springScrew")
		#body.animator.queue(curAnim)
		#
	## Play spring sound at higher pitch if hammered, otherwise normal sound
	#if is_amy_hammer:
		#var pitch_player = AudioStreamPlayer.new()
		#pitch_player.stream = springSound
		#pitch_player.pitch_scale = 1.35
		#get_parent().add_child(pitch_player)
		#pitch_player.play()
		#pitch_player.finished.connect(pitch_player.queue_free)
	#else:
		#Global.play_sound(springSound)


## Collision check
#func physics_collision(body, hitVector):
	## check that the players hit direction matches the direction we're facing (ignored for diagonal)
	#if hitVector == -hitDirection:
		## Check if Amy has her hammer out in the air or is in the AmyHammerSwing state
		#var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and ((!body.ground and body.animator.current_animation == "dropDash") or (body.currentState == body.STATES.AMYHAMMER)))
		#var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
		## do a Rock launch HAUGH!!!
		#var setMove = hitDirection.rotated(rotation).rotated(-body.rotation).round()*speed[type]*60*boost
		## vertical movement
		#if setMove.y != 0:
			## figure out the animation based on the players current animation
			#var curAnim = "walk"
			#match(body.animator.current_animation):
				#"walk", "run", "peelOut":
					#curAnim = body.animator.current_animation
				## if none of the animations match and speed is equal beyond the players top speed, set it to run (default is walk)
				#_:
					#if(abs(body.groundSpeed) >= min(6*60,body.top)):
						#curAnim = "run"
			## play player animation
			#body.animator.play("spring")
			#body.animator.queue(curAnim)
			## set vertical speed
			#body.movement.y = setMove.y
			#body.set_state(body.STATES.AIR)
			#body.disconect_from_floor()
		### horizontal movement
		##else:
			### exit out of state on certain states
			##match(body.currentState):
				##body.STATES.GLIDE:
					##if !body.ground:
						##body.animator.play("run")
						##body.set_state(body.STATES.AIR)
			### set horizontal speed
			##body.movement.x = setMove.x
			##body.horizontalLockTimer = (15.0/60.0) # lock for 15 frames
			##body.direction = sign(setMove.x)
		## horizontal movement
		#else:
			## exit out of state on certain states
			#match(body.currentState):
				#body.STATES.GLIDE:
					#if !body.ground:
						#body.animator.play("run")
						#body.set_state(body.STATES.AIR)
				#body.STATES.AMYHAMMER: # <--- Added check for Amy's hammer state
					#body.animator.play("run")
					#body.set_state(body.STATES.AIR)
					#body.disconect_from_floor()
			## set horizontal speed
			#body.movement.x = setMove.x
			#body.horizontalLockTimer = (15.0/60.0) # lock for 15 frames
			#body.direction = sign(setMove.x)
		#
		## Play SpinDash sound if Amy was launched with her hammer active/swinging
		#if is_amy_hammer:
			#body.sfx[3].play()
		#
		#$SpringAnimator.play(animList[animID])
		#Global.play_sound(springSound)
		#
		##Restore Air Control
		#body.airControl = true
		## Disable pole grabs - XXX Does this make any sense? How did this ever disable pole grabs?
		## body.poleGrabID = self
		#return true
	#
#
##func _on_Diagonal_body_entered(body):
	### diagonal springs are pretty straightforward
	##body.angle = body.gravityAngle
	##body.movement = hitDirection.rotated(rotation).rotated(-body.rotation)*speed[type]*60
	##$SpringAnimator.play(animList[animID])
	##if (hitDirection.y < 0):
		##body.set_state(body.STATES.AIR)
		### figure out the animation based on the players current animation
		##var curAnim = "walk"
		##match(body.animator.current_animation):
			##"walk", "run", "peelOut":
				##curAnim = body.animator.current_animation
			### if none of the animations match and speed is equal beyond the players top speed, set it to run (default is walk)
			##_:
				##if(abs(body.groundSpeed) >= min(6*60,body.top)):
					##curAnim = "run"
		### play player animation
		##body.animator.play("springScrew")
		##body.animator.queue(curAnim)
	##Global.play_sound(springSound)
	#
#func _on_Diagonal_body_entered(body):
	## diagonal springs are pretty straightforward
	#
	## Check if Amy has her hammer out in the air or is in the AmyHammerSwing state
	#var is_amy_hammer = (body.character == Global.CHARACTERS.AMY and ((!body.ground and body.animator.current_animation == "dropDash") or (body.currentState == body.STATES.AMYHAMMER)))
	#var boost = amyHammerBoostMultiplier if is_amy_hammer else 1.0
	#
	#body.angle = body.gravityAngle
	#body.movement = hitDirection.rotated(rotation).rotated(-body.rotation)*speed[type]*60*boost
	#$SpringAnimator.play(animList[animID])
	#
	## Play SpinDash sound if Amy was launched with her hammer active/swinging
	#if is_amy_hammer:
		#body.sfx[3].play()
	#
	#if (hitDirection.y < 0 or is_amy_hammer):
		#body.set_state(body.STATES.AIR)
		#body.disconect_from_floor()
		#var curAnim = "walk"
		#match(body.animator.current_animation):
			#"walk", "run", "peelOut":
				#curAnim = body.animator.current_animation
			#_:
				#if(abs(body.groundSpeed) >= min(6*60,body.top)):
					#curAnim = "run"
		#body.animator.play("springScrew")
		#body.animator.queue(curAnim)
		#
	#Global.play_sound(springSound)
	#
	### Force state to AIR if moving upward or if Amy is in her hammer swing state
	##if (hitDirection.y < 0 or (body.has_method("get_state") and body.currentState == body.STATES.AMYHAMMER)):
		##body.set_state(body.STATES.AIR)
		##body.disconect_from_floor() # <--- Ensure floor detachment
		### figure out the animation based on the players current animation
		##var curAnim = "walk"
		##match(body.animator.current_animation):
			##"walk", "run", "peelOut":
				##curAnim = body.animator.current_animation
			### if none of the animations match and speed is equal beyond the players top speed, set it to run (default is walk)
			##_:
				##if(abs(body.groundSpeed) >= min(6*60,body.top)):
					##curAnim = "run"
		### play player animation
		##body.animator.play("springScrew")
		##body.animator.queue(curAnim)
	##Global.play_sound(springSound)
	## Disable pole grabs
	## body.poleGrabID = self
