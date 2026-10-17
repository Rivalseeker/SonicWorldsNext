extends PlayerState

@export var maxChargeTime: float = 0.5

func state_exit():
	parent.get_node("HitBox").shape.size = parent.currentHitbox.NORMAL
	
func state_activated():
	parent.get_node("HitBox").position = parent.hitBoxOffset.crouch


func _process(delta):
	# Cancel Spin Dash if pressing the opposite horizontal direction
	if parent.inputs[parent.INPUTS.XINPUT] != 0 and parent.inputs[parent.INPUTS.XINPUT] == -parent.direction:
		parent.sfx[2].stop()
		parent.spindashPower = 0.0
		parent.set_state(parent.STATES.NORMAL)
		return
	
	if parent.spindashAutoCharge:
		# Hold-to-charge mode (entered from standing still)
		if parent.any_action_held():
			var charge_rate = (8.0 / maxChargeTime) * delta
			parent.spindashPower = min(8.0, parent.spindashPower + charge_rate)
			parent.sfx[2].pitch_scale = 1.0 + ((float(parent.spindashPower) / 8.0) * 0.5)
		else:
			parent.spindashPower -= ((parent.spindashPower / 0.125) / 256) * 60 * delta
	else:
		# Traditional tap-to-charge mode (entered from crouch)
		if parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
			parent.animator.stop()
			parent.animator.play("spinDash")
			parent.sfx[2].play()
			if (parent.spindashPower < 8):
				parent.spindashPower = min(parent.spindashPower + 2, 8)
			parent.sfx[2].pitch_scale = 1.0 + ((float(parent.spindashPower) / 8.0) * 0.5)
		
		parent.spindashPower -= ((parent.spindashPower / 0.125) / (256)) * 60 * delta
	
	# dust sprite
	var dash = parent.sprite.get_node("DashDust")
	dash.visible = true
	dash.flip_h = parent.sprite.flip_h
	dash.offset.x = abs(dash.offset.x) * sign(-1 + int(dash.flip_h) * 2)
	
	# Release condition
	var should_release = false
	if parent.spindashAutoCharge:
		if not parent.any_action_held():
			should_release = true
	else:
		if parent.inputs[parent.INPUTS.YINPUT] <= 0:
			should_release = true
			
	if should_release:
		parent.movement.x = (8 + (floor(parent.spindashPower) / 2)) * 60 * parent.direction
		parent.sfx[3].play()
		parent.sfx[2].stop()
		parent.sfx[2].pitch_scale = 1
		parent.set_state(parent.STATES.ROLL)
		
		# Lock camera
		parent.lock_camera((parent.spindashPower + 8) / 60.0)
		
		parent.animator.play("roll")


#func _process(delta):
	## Continuous charge while holding action button, OR button press triggers standard rev
	#if parent.any_action_held_or_pressed():
		## Increase spindashPower over time based on maxChargeTime
		#var charge_rate = (8.0 / maxChargeTime) * delta
		#parent.spindashPower = min(8.0, parent.spindashPower + charge_rate)
		#
		## Button press re-triggers animation/sound rev
		#if parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
			#parent.animator.stop()
			#parent.animator.play("spinDash")
			#parent.sfx[2].play()
			#if parent.spindashPower < 8:
				#parent.spindashPower = min(parent.spindashPower + 2, 8)
				#
		#parent.sfx[2].pitch_scale = 1.0 + ((float(parent.spindashPower) / 8.0) * 0.5)
	#
	## dust sprite
	#var dash = parent.sprite.get_node("DashDust")
	#dash.visible = true
	#dash.flip_h = parent.sprite.flip_h
	#dash.offset.x = abs(dash.offset.x) * sign(-1 + int(dash.flip_h) * 2)
	#
	## Release Spin Dash when action button (and down input) is released
	#if not parent.any_action_held_or_pressed() and parent.inputs[parent.INPUTS.YINPUT] <= 0:
		#parent.movement.x = (8 + (floor(parent.spindashPower) / 2)) * 60 * parent.direction
		#parent.sfx[3].play()
		#parent.sfx[2].stop()
		#parent.sfx[2].pitch_scale = 1
		#parent.set_state(parent.STATES.ROLL)
		#
		## Lock camera
		#parent.lock_camera((parent.spindashPower + 8) / 60.0)
		#
		#parent.animator.play("roll")


#func _process(delta):
	#
	## Charging up (if your character does something different for button 2 or 3 you'll want to adjust this)
	#if parent.inputs[parent.INPUTS.ACTION] == 1 or parent.inputs[parent.INPUTS.ACTION2] == 1 or parent.inputs[parent.INPUTS.ACTION3] == 1:
		## reset animation
		#parent.animator.stop()
		#parent.animator.play("spinDash")
		## play rev sound
		#parent.sfx[2].play()
		## increase dash power
		#if (parent.spindashPower < 8):
			#parent.spindashPower = min(parent.spindashPower+2,8)
		#parent.sfx[2].pitch_scale = 1.0+((float(parent.spindashPower)/8.0)*0.5)
	#
	## dust sprite
	#var dash = parent.sprite.get_node("DashDust")
	#dash.visible = true
	#dash.flip_h = parent.sprite.flip_h
	#dash.offset.x = abs(dash.offset.x)*sign(-1+int(dash.flip_h)*2)
	#
	## release
	#if (parent.inputs[parent.INPUTS.YINPUT] <= 0):
		#parent.movement.x = (8+(floor(parent.spindashPower) / 2))*60*parent.direction
		#parent.sfx[3].play()
		#parent.sfx[2].stop()
		#parent.sfx[2].pitch_scale = 1
		#parent.set_state(parent.STATES.ROLL)
		#
		## Lock camera
		#parent.lock_camera((parent.spindashPower+8)/60.0)
		#
		#parent.animator.play("roll")
	#
	## decrease the dash power for next frame
	#parent.spindashPower -= ((parent.spindashPower / 0.125) / (256))*60*delta

func _physics_process(_delta):
	# Gravity
	if !parent.ground:
		parent.set_state(parent.STATES.AIR)
