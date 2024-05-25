## Receives damage from a [DamageComponent] and passes it on to the parent [Entity]'s [HealthComponent].
## Requirements: This component must be an [Area2D] or connected to signals from an [Area2D]

class_name DamageReceivingComponent
extends Component

# CHECK: Dynamically find co-components?

#region Parameters
@export var healthComponent:  HealthComponent
@export var factionComponent: FactionComponent

@export var isEnabled: bool = true: ## Also effects [member Area2D.monitorable] and [member Area2D.monitoring]
	set(newValue):
		isEnabled = newValue
		# Toggle the area too, to ensure that [DamageComponent] can re-detect us,
		# e.g. after an [InvulnerabilityOnHitComponent] ends.
		self.area.monitorable = newValue
		self.area.monitoring  = newValue

#endregion


#region Signals

signal didReceiveDamage(damageComponent: DamageComponent, amount: int, attackerFactions: int)

## This signal is always raised when colliding with a [DamageComponent] even if the factions are friendly and no health is reduced.
signal didCollideWithDamage(damageComponent: DamageComponent)

signal didAccumulateFractionalDamage(damageComponent: DamageComponent, amount: float, attackerFactions: int)

#endregion


#region State

var area: Area2D:
	get: return self.get_node(".") as Area2D # HACK: TODO: Find better way to cast

## To eliminate any possibility of bugs or inaccuracies arising from floating point math imprecision.
var accumulatedFractionalDamage: float

## A list of [DamageComponent]s currently in collision contact.
var damageComponentsInContact: Array[DamageComponent]

#endregion


func _ready():

	# Is there a HealthComponent and FactionComponent? If not, try to find them from the Entity. In any case, we will still emit a `didReceiveDamage` signal.

	if not healthComponent:
		healthComponent = self.findCoComponent(HealthComponent)

	if not factionComponent:
		factionComponent = self.findCoComponent(FactionComponent)


#region Collisions


func onAreaEntered(area: Area2D):
	if not isEnabled: return

	var damageComponent := getDamageComponent(area)

	# If the Area2D is not a DamageComponent, there's nothing to do.
	if damageComponent:
		damageComponentsInContact.append(damageComponent)
		didCollideWithDamage.emit(damageComponent)

	# processCollision(damageComponent, null) # NOTE: Damage-causing area collision is initiated by the [DamageComponent] script.


func onAreaExited(area: Area2D) -> void:
	if not isEnabled: return

	# No need to cast the area's type, just remove it from the array.
	damageComponentsInContact.erase(area)

	# Reset the accumulatedFractionalDamage if there is no source of damage in contact.
	if damageComponentsInContact.size() <= 0:
		accumulatedFractionalDamage = 0


## Casts an [Area2D] as a [DamageComponent].
func getDamageComponent(area: Area2D) -> DamageComponent:
	var damageComponent: DamageComponent = area.get_node(".") as DamageComponent # HACK: TODO: Find better way to cast

	if not damageComponent:
		## NOTE: This warning may help to set collision masks properly.
		printDebug("Cannot cast area as DamageComponent: " + str(area) + " | Check collision masks")
		return null

	# Is it our own entity?
	if damageComponent.parentEntity == self.parentEntity:
		return null

	return damageComponent


## This function may be called by a colliding [DamageComponent].
func processCollision(damageComponent: DamageComponent, attackerFactionComponent: FactionComponent):
	if not isEnabled: return

	if attackerFactionComponent:
		self.handleDamage(damageComponent, damageComponent.damageOnCollision, attackerFactionComponent.factions, damageComponent.friendlyFire)
	else:
		printWarning("No FactionComponent provided with DamageComponent on attacker Entity: " + str(damageComponent.parentEntity))
		self.handleDamage(damageComponent, damageComponent.damageOnCollision, 0, damageComponent.friendlyFire)

#endregion


## Checks whether the attacking faction should cause damage to the parent entity.
## Take damage only if NO factions match; if the attacker and target are not in a same faction.
## or even if there is no FactionComponent at all. This lets objects such as trees or rocks to handle "mining" and yield resources.
##
## Example: if CharacterA is in the Players faction and CharacterB is in Enemies, they can damage each other.
## But if CharacterB is in Enemies and ALSO IN Players, they will not damage each other.
func checkFactions(attackerFactions: int = 0, friendlyFire: bool = false) -> bool:
	var shouldReceiveDamage := false

	if friendlyFire or not self.factionComponent:
		shouldReceiveDamage = true
	else:
		var myFactions = self.factionComponent.factions
		shouldReceiveDamage = not (myFactions & attackerFactions) # Bitwise AND means any matching bits at all.

	return shouldReceiveDamage


## NOTE: [param damageComponent] may be `null` in case the caller is a [DamageTimerComponent]
func handleDamage(damageComponent: DamageComponent, damageAmount: int, attackerFactions: int = 0, friendlyFire: bool = false):
	if not isEnabled or not checkFactions(attackerFactions, friendlyFire):
		return

	# Even if there is no HealthComponent, we will still emit the signal.
	if healthComponent:
		healthComponent.damage(damageAmount)

	# CHECK: Should this signal be emitted regardless of health?
	didReceiveDamage.emit(damageComponent, damageAmount, attackerFactions)


## Converts float damage values to a single integer damage value.
## Such as damage accumulated over time/per frame.
func handleFractionalDamage(damageComponent: DamageComponent, fractionalDamage: float, attackerFactions: int = 0, friendlyFire: bool = false):
	# INFO: The convention is to keep all player-facing stats as integers,
	# to eliminate any potential bugs or inconsistencies arising from floating point math inaccuracies.

	# TBD: WTF? Do we really need this?

	if not isEnabled \
	or is_zero_approx(fractionalDamage) or fractionalDamage < 0.0 \
	or not checkFactions(attackerFactions, friendlyFire):
		return

	self.accumulatedFractionalDamage += fractionalDamage

	# TBD: Is it be costly to emit this signal each frame? Should it be emitted regardless of health?
	didAccumulateFractionalDamage.emit(damageComponent, fractionalDamage, attackerFactions)

	# Drain the damage

	var damageToApply: int = 0

	while accumulatedFractionalDamage > 1.0 \
	or is_equal_approx(accumulatedFractionalDamage, 1.0):
		# DEBUG: printLog("Time: " + str(Time.get_ticks_msec()) + " | accumulatedFractionalDamage: " + str(accumulatedFractionalDamage))
		damageToApply += 1
		accumulatedFractionalDamage -= 1.0

	if damageToApply > 0:
		# Even if there is no HealthComponent, we will still emit the signal.
		if healthComponent:
			healthComponent.damage(damageToApply)

		# CHECK: Should this signal be emitted regardless of health?
		didReceiveDamage.emit(damageComponent, damageToApply, attackerFactions)


func handleDamageTimerComponent(damageTimerComponent: DamageTimerComponent) -> bool:
	# TODO: Signals
	# TODO: Removal

	if not checkFactions(damageTimerComponent.attackerFactions, damageTimerComponent.friendlyFire):
		return false

	self.parentEntity.add_child(damageTimerComponent)
	return true

