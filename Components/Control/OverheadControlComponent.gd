## Provides overhead-view (i.e. "top-down") movement control for the parent [Entity]'s [CharacterBody2D].

class_name OverheadControlComponent
extends CharacterBodyManipulatingComponentBase


#region Parameters
@export var isEnabled:  bool = true
@export var parameters: OverheadMovementParameters = OverheadMovementParameters.new()
#endregion


#region State
var inputDirection		:= Vector2.ZERO
var lastInputDirection	:= Vector2.ZERO
var lastDirection		:= Vector2.ZERO ## Normalized
#endregion


func _ready() -> void:
	# Set the entity's [CharacterBody2D] motion mode to Floating.
	if characterBodyComponent and characterBodyComponent.body:
		printLog("characterBodyComponent.body.motion_mode → Floating")
		characterBodyComponent.body.motion_mode = CharacterBody2D.MOTION_MODE_FLOATING
		characterBodyComponent.shouldResetVelocityIfZeroMotion = true
		#characterBodyComponent.didMove.connect(self.characterBodyComponent_didMove)
	else:
		printWarning("Missing CharacterBody2D in Entity: " + parentEntity.logName)


func _physics_process(delta: float) -> void:
	# DEBUG: printLog("_physics_process()")
	if not isEnabled: return
	processWalkInput(delta)
	characterBodyComponent.queueMoveAndSlide()

	# Avoid the "glue effect" where the character sticks to a wall until the velocity changes to the opposite direction.
	# parentEntity.callOnceThisFrame(Tools.resetBodyVelocityIfZeroMotion, [body]) # TBD: Should this be optional?

	# DEBUG:
	if shouldShowDebugInfo: showDebugInfo()


## Get the input direction and handle the movement/deceleration.
func processWalkInput(delta: float) -> void:
	if not isEnabled: return

	self.inputDirection = Input.get_vector(GlobalInput.Actions.moveLeft, GlobalInput.Actions.moveRight, GlobalInput.Actions.moveUp, GlobalInput.Actions.moveDown)

	if not inputDirection.is_zero_approx(): lastInputDirection = inputDirection

	if parameters.shouldApplyAcceleration:
		body.velocity = body.velocity.move_toward(inputDirection * parameters.speed, parameters.acceleration * delta)
	else:
		body.velocity = inputDirection * parameters.speed

	# TODO: Compare setting vector components separately vs together

	# Friction?

	if parameters.shouldApplyFriction:

		if is_zero_approx(inputDirection.x):
			body.velocity.x = move_toward(body.velocity.x, 0.0, parameters.friction * delta)

		if is_zero_approx(inputDirection.y):
			body.velocity.y = move_toward(body.velocity.y, 0.0, parameters.friction * delta)

	# Disable friction by maintaining velcoty fron the previous frame?

	if parameters.shouldMaintainPreviousVelocity and not inputDirection:
		body.velocity = characterBodyComponent.previousVelocity

	# Minimum velocity?

	if parameters.shouldMaintainMinimumVelocity:
		if body.velocity.length() < parameters.minimumSpeed:
			if body.velocity.is_zero_approx():
				body.velocity = self.lastVelocity.normalized() * parameters.minimumSpeed
			else:
				body.velocity = body.velocity.normalized() * parameters.minimumSpeed

	# Last direction

	if not body.velocity.is_zero_approx():
		#if currentState == State.idle: currentState = State.walk
		lastDirection = body.velocity.normalized()


func showDebugInfo() -> void:
	if not shouldShowDebugInfo: return
	Debug.watchList.lastInput		= lastInputDirection
	Debug.watchList.lastDirection	= lastDirection
