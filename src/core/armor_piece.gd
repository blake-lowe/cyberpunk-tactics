class_name ArmorPiece
extends RefCounted
## Worn armor in one location (head or body). SP ablates by 1 whenever damage gets through (p186).

var id: String
var name: String
var max_sp: int
var sp: int
var penalty: int  ## Applied to REF, DEX and MOVE; only the worst worn penalty counts (p184).


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
