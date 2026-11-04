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
var repair_work := 0   ## hours of downtime repair done toward full SP (Campaign.repair_armor_work, p140)


## Repair/upgrade DV by the item's price (Maker table p149, by Price Category).
static func maker_dv(price: int) -> int:
	if price <= 20: return 9      # Cheap/Everyday
	if price <= 50: return 13     # Costly
	if price <= 100: return 17    # Premium
	if price <= 500: return 21    # Expensive
	if price <= 1000: return 24   # Very Expensive
	return 29                     # Luxury+


## Hours a full repair takes by the item's price (Item Repair, CPR core p140, by Price Category):
## Cheap/Everyday 1 hour, Costly 6 hours, Premium 1 day, Expensive 1 week, Very Expensive 2 weeks,
## Luxury 1 month (30 days).
static func repair_hours(price: int) -> int:
	if price <= 20: return 1
	if price <= 50: return 6
	if price <= 100: return 24
	if price <= 500: return 24 * 7
	if price <= 1000: return 24 * 14
	return 24 * 30


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
	repair_work = 0


func price() -> int:
	return int(RulesDB.armor(id).get("cost", 100)) if RulesDB.load_json("armor.json")["armor"].has(id) else 1000
