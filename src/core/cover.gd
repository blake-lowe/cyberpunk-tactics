class_name Cover
extends RefCounted
## One 2x2 m (1 square) section of cover (p182). Binary: it either fully covers or it's gone.
## Excess damage past 0 HP is lost; it does not carry to the person behind (p182).

var material: String
var thick: bool
var max_hp: int
var hp: int


static func make(p_material: String, p_thick: bool) -> Cover:
	var c := Cover.new()
	c.material = p_material
	c.thick = p_thick
	c.max_hp = int(RulesDB.load_json("armor.json")["cover_hp"][p_material][0 if p_thick else 1])
	c.hp = c.max_hp
	return c


func is_cover() -> bool:
	return hp > 0


## Returns true if this damage destroyed the cover.
func take_damage(amount: int) -> bool:
	if hp <= 0:
		return false
	hp = maxi(0, hp - amount)
	return hp == 0


## Explosions only hurt targets behind cover they can destroy (p174).
func blocks_explosion(damage: int) -> bool:
	return is_cover() and damage < hp
