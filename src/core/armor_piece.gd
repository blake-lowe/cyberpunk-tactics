class_name ArmorPiece
extends RefCounted
## Worn armor in one location (head or body). SP ablates by 1 whenever damage gets through (p186).

var id: String
var name: String
var max_sp: int
var sp: int
var penalty: int  ## Applied to REF, DEX and MOVE; only the worst worn penalty counts (p184).
var upgraded := false  ## Tech Upgrade Expertise +1 SP (p148): one upgrade per item
var rigged := false    ## jury-rigged this gig (p147): not again until fully repaired


## Repair/upgrade DV by the item's price (Maker table p149, by Price Category).
static func maker_dv(price: int) -> int:
	if price <= 20: return 9      # Cheap/Everyday
	if price <= 50: return 13     # Costly
	if price <= 100: return 17    # Premium
	if price <= 500: return 21    # Expensive
	if price <= 1000: return 24   # Very Expensive
	return 29                     # Luxury+


static func from_id(armor_id: String) -> ArmorPiece:
	var d := RulesDB.armor(armor_id)
	var a := ArmorPiece.new()
	a.id = armor_id
	a.name = d["name"]
	a.max_sp = int(d["sp"])
	a.sp = a.max_sp
	a.penalty = int(d["penalty"])
	return a


func ablate(amount: int = 1) -> void:
	sp = maxi(0, sp - amount)


func repair() -> void:
	sp = max_sp
	rigged = false


func price() -> int:
	return int(RulesDB.armor(id).get("cost", 100)) if RulesDB.load_json("armor.json")["armor"].has(id) else 1000
