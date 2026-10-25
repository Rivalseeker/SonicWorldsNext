extends StaticBody2D

var bumperCount = 0


func physics_collision(body, _hitVector):
	# on collision bump the player away and play animation, pretty simple
	body.movement = (body.global_position-global_position).normalized()*7*60.0
	
	var isAmy = (body.character == Global.CHARACTERS.AMY)
	var hammerSpinning = (isAmy and body.animator.current_animation == "dropDash")
	var hammerPos = body.animator.current_animation_position
	# NEW: was she charging a drop dash when bumped? (jump and air states both track dropTimer)
	var inAirStates = (body.currentState == body.STATES.JUMP or body.currentState == body.STATES.AIR)
	var wasCharging = (isAmy and inAirStates and body.stateList[body.currentState].dropTimer > 0)
	
	if body.currentState == body.STATES.JUMP: # set the state to air
		# remember whether Amy has already used her double jump (entering the air state would reset it)
		var doubleJumpWasUsed = body.stateList[body.STATES.JUMP].doubleJumpUsed
		var abilityWasUsed = body.abilityUsed
		
		body.set_state(body.STATES.AIR)
		
		if isAmy:
			# Amy only gets one double jump per time in the air, bumpers don't refresh it
			body.stateList[body.STATES.AIR].doubleJumpUsed = doubleJumpWasUsed
			body.abilityUsed = abilityWasUsed
			
			# entering the air state resets the hammer spin; put it back where it was
			if hammerSpinning and body.animator.current_animation != "dropDash":
				body.animator.play("dropDash")
				body.animator.seek(hammerPos, true)
				body.shieldSprite.get_node("InstaShieldHitbox/HitBox").set_deferred("disabled", false)
	
	# NEW: any bumper hit cancels Amy's drop dash and blocks it until she double jumps again
	if isAmy and body.currentState == body.STATES.AIR:
		var airState = body.stateList[body.STATES.AIR]
		airState.bumpedInAir = true
		airState.dropDashEnabled = false
		airState.dropTimer = 0
		if wasCharging:
			body.sfx[20].stop()
	
	$Bumper.play("default")
	
	Global.play_sound($BumperSFX.stream)
	# score counter
	if bumperCount < 10:
		Global.add_score(global_position,0)
		bumperCount += 1

#func physics_collision(body, _hitVector):
	## on collision bump the player away and play animation, pretty simple
	#body.movement = (body.global_position-global_position).normalized()*7*60.0
	#
	## Amy only: was she rolling or hammer spinning when bumped? (checked before any state change)
	#var currentAnim = body.animator.current_animation
	#var hammerSpinning = (currentAnim == "dropDash")
	#var hammerPos = body.animator.current_animation_position
	#var amyBumpRefresh = (body.character == Global.CHARACTERS.AMY and (currentAnim == "roll" or hammerSpinning))
	#
	#if body.currentState == body.STATES.JUMP: # set the state to air
		#body.set_state(body.STATES.AIR)
	#
	## every bump gives Amy another double jump (only while rolling or hammer spinning)
	#if amyBumpRefresh and body.currentState == body.STATES.AIR:
		#body.abilityUsed = false
		#body.stateList[body.STATES.AIR].doubleJumpUsed = false
		#
		## entering the air state resets the hammer spin; put it back where it was
		#if hammerSpinning and body.animator.current_animation != "dropDash":
			#body.animator.play("dropDash")
			#body.animator.seek(hammerPos, true)
			#body.shieldSprite.get_node("InstaShieldHitbox/HitBox").set_deferred("disabled", false)
	#
	#$Bumper.play("default")
	#
	#Global.play_sound($BumperSFX.stream)
	## score counter
	#if bumperCount < 10:
		#Global.add_score(global_position,0)
		#bumperCount += 1

#func physics_collision(body, _hitVector):
	## on collision bump the player away and play animation, pretty simple
	#body.movement = (body.global_position-global_position).normalized()*7*60.0
	#
	#if body.currentState == body.STATES.JUMP: # set the state to air
		## Amy's double jump / hammer plays "dropDash", which the air state resets to "RESET"
		## (leaving her frozen), so go back to the rolling animation afterwards
		#var wasHammerSpin = (body.animator.current_animation == "dropDash")
		#body.set_state(body.STATES.AIR)
		#if wasHammerSpin:
			#body.animator.play("roll")
	#
	#$Bumper.play("default")
	#
	#Global.play_sound($BumperSFX.stream)
	## score counter
	#if bumperCount < 10:
		#Global.add_score(global_position,0)
		#bumperCount += 1
