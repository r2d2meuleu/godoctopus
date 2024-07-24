## Handles the physics for walking, gravity and friction for the entity's [CharacterBody2D] in a "platform" world.
## This allows player characters as well as monsters to share the same movement logic.
## NOTE: Does NOT handle player input. Control is provided by [PlatformerPhysicsControlComponent] and AI components etc.
## Requirements: Entity with [CharacterBody2D], AFTER [PlatformerPhysicsControlComponent]
## @experimental

class_name PlatformerPhysicsComponent
extends CharacterBodyComponent

# CREDIT: THANKS: https://github.com/uheartbeast — https://github.com/uheartbeast/Heart-Platformer-Godot-4 — https://youtu.be/M8-JVjtJlIQ


#region Parameters

@export var isEnabled: bool = true:
	set(newValue):
		isEnabled = newValue
		if not isEnabled:
			# Reset other flags only once
			self.inputDirection = 0
			self.isInputZero = true

@export var parameters: PlatformerMovementParameters = PlatformerMovementParameters.new()

#endregion


#region State

enum State { idle, moveOnFloor, moveInAir }

var states := {
	State.idle:			null,
	State.moveOnFloor:	null,
	State.moveInAir:	null,
	# State.jumping:	null, # TBD
	# State.falling:	null, # TBD
	}

var currentState: State:
	set(newValue):
		currentState = newValue
		# DEBUG: printDebug(str(currentState))

var inputDirection:		float
var lastInputDirection:	float
var isInputZero:			bool = true

var gravity:	 float = ProjectSettings.get_setting(Global.SettingsPaths.gravity)

#endregion


func _ready() -> void:
	self.currentState = State.idle
	if parentEntity.body:
		printLog("parentEntity.body.motion_mode → Grounded")
		parentEntity.body.motion_mode = CharacterBody2D.MOTION_MODE_GROUNDED
	else:
		printWarning("Missing parentEntity.body: " + parentEntity.logName)


#region Update Cycle

func _physics_process(delta: float) -> void:
	if not isEnabled: return
	
	# Force movement in the [CharacterBodyComponent] superclass because this subclass always performs its processing like gravity and friction.
	self.shouldMoveThisFrame = true
	super._physics_process(delta)


func updateStateBeforeMove(delta: float) -> void:
	# CREDIT: THANKS: uHeartbeast@GitHub/YouTube
	# NOTE: The order of processing is as per Heartbeast's tutorial.
	
	# Perform [CharacterBodyComponent]'s updates before anything else.
	super.updateStateBeforeMove(delta)
	
	# Sanitize the control input and prepare flags etc. for use by other functions.
	processInput()
	
	# NOTE: `currentState` MUST be updated BEFORE `CharacterBody2D.move_and_slide(])` and AFTER `processInput()`
	# DESIGN: Using `match` here may seem too cluttered and ambiguous
	
	if currentState == State.idle and not isInputZero:
		# CHECK: Should this be done in `processInput()` so that there is only one check for [isInputZero]?
		currentState = State.moveOnFloor if isOnFloor else State.moveInAir
	
	if currentState != State.idle and body.velocity.is_zero_approx():
		currentState = State.idle
	
	# Let's fall from wherever we were in the previous frame, before we do anything else.
	processGravity(delta)
	
	# Walk the Walk
	
	processHorizontalMovement(delta) # = applyAccelerationOnFloor(delta) & applyAccelerationInAir(delta)
	processAllFriction(delta) # = applyFrictionOnFloor(delta) & applyFrictionInAir(delta)


## Prepares player input processing, after the input is provided by other components like [PlatformerPhysicsControlComponent] and AI agents. 
## Affected by [member isEnabled].
func processInput() -> void:
	# TBD: Should be guarded by [isEnabled] or should the flags etc. always be updated?
	if not isEnabled: return

	# NOTE: The input direction is provided by other components like [PlatformerPhysicsControlComponent] and AI agents.
	# self.inputDirection = Input.get_axis(GlobalInput.Actions.moveLeft, GlobalInput.Actions.moveRight)

	# Cache properties that are accessed often to avoid repeated function calls on other objects.
	
	self.isInputZero = is_zero_approx(inputDirection)

	if not isInputZero: lastInputDirection = inputDirection

	# NOTE: DESIGN: Accept input in air even if [member shouldAllowMovementInputInAir] is `false`,
	# so that some games can let the player turn around to shoot in any direction while in air, for example.


func updateStateAfterMove(delta: float) -> void:
	# Perform [CharacterBodyComponent]'s updates before anything else.
	super.updateStateAfterMove(delta)
	
	if shouldShowDebugInfo: showDebugInfo()
	
	# Clear the input so it doesn't carry on over to the next frame.
	clearInput()


func clearInput() -> void:
	inputDirection = 0 # TBD: Should the "no input" state just be a `0` or some other flag?
	#jumpInput = false # NOTE: Let the control components reset the `jumpInput`
	# The justPressed/justReleased flags should be reset here because they represent a state for only 1 frame

#endregion


#region Platformer Physics

func processGravity(delta: float) -> void:
	# Vertical Slowdown
	if not body.is_on_floor(): # ATTENTION: Cache [isOnFloor] AFTER processing gravity.
		body.velocity.y += (gravity * parameters.gravityScale) * delta
	
	if shouldShowDebugInfo and not body.velocity.is_equal_approx(previousVelocity): printDebug(str("body.velocity after processGravity(): ", body.velocity))


## Applies movement with or without gradual acceleration depending on the [member shouldApplyAccelerationOnFloor] or [member shouldApplyAccelerationInAir] flags.
## NOTE: NOT affected by [member isEnabled], so other components such as Enemy AI may drive this component without player input.
func processHorizontalMovement(delta: float) -> void:
	# Nothing to do if there is no player input.
	if isInputZero: return

	if isOnFloor: # Are we on the floor?
		if parameters.shouldApplyAccelerationOnFloor: # Apply the speed gradually or instantly?
			body.velocity.x = move_toward(body.velocity.x, parameters.speedOnFloor * inputDirection, parameters.accelerationOnFloor * delta)
		else:
			body.velocity.x = inputDirection * parameters.speedOnFloor
	elif parameters.shouldAllowMovementInputInAir: # Are we in the air and are movement changes allowed in air?
		if parameters.shouldApplyAccelerationInAir: # Apply the speed gradually or instantly?
			body.velocity.x = move_toward(body.velocity.x, parameters.speedInAir * inputDirection, parameters.accelerationInAir * delta)
		else:
			body.velocity.x = inputDirection * parameters.speedInAir
	
	if shouldShowDebugInfo and not body.velocity.is_equal_approx(previousVelocity): printDebug(str("body.velocity after processHorizontalMovement(): ", body.velocity))


## Applies friction if there is no player input and either [member shouldApplyFrictionOnFloor] or [member shouldApplyFrictionInAir] is `true`.
## NOTE: NOT affected by [member isEnabled], so other components such as Enemy AI may drive this component without player input.
func processAllFriction(delta: float) -> void:
	# Don't apply friction if the player is trying to move;
	# only apply friction to slow down when there is no player input, OR
	# NOTE: If movement is not allowed in air, then apply air friction regardless of player input.
	
	if isOnFloor and isInputZero:
		if parameters.shouldStopInstantlyOnFloor:
			body.velocity.x = 0 # TBD: Ensure that the body can be moved by other forces?
		elif parameters.shouldApplyFrictionOnFloor: 
			body.velocity.x = move_toward(body.velocity.x, 0.0, parameters.frictionOnFloor * delta)
	elif (not isOnFloor) and (isInputZero or not parameters.shouldAllowMovementInputInAir):
		if parameters.shouldStopInstantlyInAir:
			body.velocity.x = 0 # TBD: Ensure that the body can be moved by other forces?
		elif parameters.shouldApplyFrictionInAir: 
			body.velocity.x = move_toward(body.velocity.x, 0.0, parameters.frictionInAir * delta)
	
	if shouldShowDebugInfo and not body.velocity.is_equal_approx(previousVelocity): printDebug(str("body.velocity after processAllFriction(): ", body.velocity))

#endregion


#region Standalone Functions

# THANKS: CREDIT: uHeartbeast@YouTube https://youtu.be/M8-JVjtJlIQ

## Applies [member accelerationOnFloor] regardless of [member shouldApplyAccelerationOnFloor]; this flag should be checked by caller.
func applyAccelerationOnFloor(delta: float) -> void:
	if (not isInputZero) and isOnFloor:
		body.velocity.x = move_toward(body.velocity.x, parameters.speedOnFloor * inputDirection, parameters.accelerationOnFloor * delta)


## Applies [member accelerationInAir] regardless of [member shouldApplyAccelerationInAir]; this flag should be checked by caller.
func applyAccelerationInAir(delta: float) -> void:
	if (not isInputZero) and (not isOnFloor):
		body.velocity.x = move_toward(body.velocity.x, parameters.speedInAir * inputDirection, parameters.accelerationInAir * delta)


## Applies [member frictionOnFloor] regardless of [member shouldApplyFrictionOnFloor]; this flag should be checked by caller.
func applyFrictionOnFloor(delta: float) -> void:
	# Friction on floor should only be applied if there is no input;
	# otherwise the player would not be able to start moving in the first place!
	if isInputZero and isOnFloor:
		if parameters.shouldStopInstantlyOnFloor:
			# TBD: Ensure that the body can be moved by other forces?
			body.velocity.x = 0
		elif parameters.shouldApplyFrictionOnFloor: 
			body.velocity.x = move_toward(body.velocity.x, 0.0, parameters.frictionOnFloor * delta)


## Applies [member frictionInAir] regardless of [member shouldApplyFrictionInAir]; this flag should be checked by caller.
func applyFrictionInAir(delta: float) -> void:
	# If movement is not allowed in air, then apply air friction regardless of player input.
	if (isInputZero or not parameters.shouldAllowMovementInputInAir) and (not isOnFloor):
		if parameters.shouldStopInstantlyInAir:
			body.velocity.x = 0 # TBD: Ensure that the body can be moved by other forces?
		elif parameters.shouldApplyFrictionInAir: 
			body.velocity.x = move_toward(body.velocity.x, 0.0, parameters.frictionInAir * delta)
		

#endregion


func showDebugInfo() -> void:
	if not shouldShowDebugInfo: return
	super.showDebugInfo()
	Debug.watchList.state = currentState
	Debug.watchList.input = inputDirection
	
	# Friction?
	if isOnFloor and parameters.shouldApplyFrictionOnFloor and isInputZero:
		Debug.watchList.friction = "floor"
	elif (not isOnFloor) and parameters.shouldApplyFrictionInAir and (isInputZero or not parameters.shouldAllowMovementInputInAir):
		Debug.watchList.friction = "air"
	else:
		Debug.watchList.friction = "none"
