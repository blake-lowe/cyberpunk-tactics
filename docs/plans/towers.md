# Towers: T3 Band Stages in Night City 2045 (design)

Status: owner-approved 2026-11-08 (decisions in section 8). Build follows section 6, sky band first. It builds on the approved T3 (floorresearch2/proposals.json,
highrise_3_band_stages.png) and H1 (the per-building floor stack that becomes the tower strip).
Book cites are NC2045 pages as `data/world/locations.json` gives them; CPR core pages from `docs/rules/`. **ours** = a
number or call the book does not give.

One fix to the mock: "Arasaka Annex · 52 F" is not 2045 canon, because Arasaka's HQ is the Crater (hot_zone_2, p.93). The book's own
50-storey tower is **Raven Microcybernetics** (floors 40-50, p.124-125), which is the better pilot.

---

## 1. Which canon locations are towers

Rule of thumb (ours): a place becomes a band tower when the book calls it a skyscraper, high-rise or tower **and** gives
a floor programme with a gap of more than ~3 floors between two places a gig can happen. A building of 6 floors or fewer stays an ordinary
building. Book heights are quoted; any total storey count the book omits is ours and has to be marked `# ours` in data.

| Location (id) | District | What the book says (cite) | Bands (B = below street, R = roof) | Gigs |
|---|---|---|---|---|
| **Raven Microcybernetics** (the_glen_24) | The Glen | "Deliberately forgettable skyscraper"; opaque lobby, one McCain desk whose job is to call NCPD; tenants on floors 1-39, **Raven on 40-50** (p.124-125) | Street: 1 lobby + 2 tenants · Sky: 48-50 + R (R and the 50 cap are book-consistent, pad ours) | data_theft, corp_extraction (+assassination hook) |
| **Thurgood Towers / MA&F** (the_glen_19) | The Glen | Twin white skyscrapers, **walkways every 10 floors**; MA&F on the top floors, appointment and armed escort only; about half the other floors empty; ground-floor gun shop and barber; staff implant opens doors and **elevators** (p.123) | Street: 1 + tenants · Staging: an empty floor + its 10th-floor walkway (e.g. 40) · Sky: top 2-3 + R. Height ours (~60) | data_theft, corp_extraction, assassination |
| **Continental Brands Office** (downtown_5) | Downtown | Public lower floors (Megamart, test-kitchen tours), staff-only middle floors with offices and labs, **top five floors executive suites** (p.83) | Street: 1-2 public · Mid: 2 lab floors · Exec: 2 of the top five + R. Height ours | data_theft, sabotage, corp_extraction |
| **Ziggurat HQ** (upper_marina_40); set piece `ziggurat_hq` | Upper Marina | Curved tower: CitiNet repair bays low; development and CitiNet/Data Pool control in the middle; execs high, **UR's suite at the apex**; public 1F Net Museum and auditorium; fire/EMS station at the base; **server floor kept secret** (p.78). Staff housing hung under the curve (p.77) | Street: 1 + bays (today's 6-floor set piece, cut down) · Mid: CitiNet floors (strip shows a range: the secret floor) · Apex: UR suite + R. Height ours | data_theft, sabotage, corp_extraction, assassination |
| **Guăngbō Tower** (little_china_4) | Little China | Old radio tower turned container tower; **B: Gold Dragons Security** (range, gym, cells, garage); 4 floors of Ling Po Imports over the lobby; **9-10 LCRA + Tong front + clinic**, library on 10; **15-16 Libertine Lanes** bowling (Dragons hangout); top floor VR arcade, closed for renovation (p.99-100) | Street: B1 + lobby + 1 · Mid: 9-10 · Top: 15-16 + top floor (≥17, exact ours) | data_theft, sabotage, gang_hit |
| **Tyger Works Tower** (kabuki_23) | Kabuki | **Ten storeys**: 1-2 Kimen-Gumi HQ, **3-4 jail**, 5 coffins, 6-7 cab/food, 8 clinic and law, **9-10 senior offices**, garage under (p.207) | Street: B1 + 1-4 (rescue from the jail is the book hook) · Top: 8-10 + R | gang_hit, rescue, data_theft |
| **Nakagawa Kabuki Theater** (kabuki_14) | Kabuki | 1-5 theatre, 6 museum, next four Foundation offices, **penthouse on top**; sniper Zen watches the rooftops (p.205) | Street: 1-2 theatre · Top: 10 + penthouse (11 by count) + R | assassination, data_theft |
| **Haakensen Tower** (south_night_city_6) | South NC | The district's only new skyscraper; café on the ground floor; **Scythe Security on 2F and in the underground garage**; Haakensen on the top floors (p.143) | Street: B1 + 1-2 · Top: 2 floors + R. Height ours | data_theft, assassination, sabotage |
| **New Libertine Tower** (downtown_18) | Downtown | Teal tower; Whitewater Security on **floors 1-3**, a private clinic on **5**, City Manager Ortega on the **top two** (p.86) | Street: 1-3 · (Mid: 5) · Top: 2 + R | data_theft, assassination, sabotage |
| **Segotari HQ / EXCEL-1** (kabuki_19) | Kabuki | **Bottom nine floors** EXCEL-1 entertainment; offices upper; cube hotel in the basement (p.206) | Street: B1 + 1-2 · Top: offices | data_theft, sabotage |
| **Network 54 Plaza** (new_westbrook_15) | New Westbrook | Self-contained fortress tower crowned by the N54 sign: offices, studios, talent housing, public viewing rooms (p.218) | Street: reception · Mid: studios · Top: talent/exec + sign roof. Heights ours | data_theft, corp_extraction, sabotage |
| **Trauma Team Tower** (watson_development_32); set piece `trauma_team_tower` | Watson | Hospital, **AV launch bays per squad, air-control tower**; dispatch and execs **buried in the subbasement** (p.195) | *Inverted*: Sub: dispatch/exec · Street: hospital · Top: launch bays + pad | data_theft, sabotage |
| **Hall of Justice** (the_glen_15) | The Glen | Towers; civil courts low, DA in the middle, criminal courts high; prisoners underground; **The Judge NET on the top floor, Netwatch AV on the roof** (rumour, p.122) | Street: B cells + lobby · Top: Judge floor + R | rescue, data_theft, sabotage |
| **Megabuilding H10** (watson_development_13) | Watson | Cubes low, then conapts, then luxury suites and the Highwall Club; radio station on the roof (p.191) | Street: courtyard + cubes · Top: luxury + R | gang_hit, sabotage, data_theft |
| Convention Center (upper_marina_32) | Upper Marina | Two hall floors; two glass towers locked down hard; **skybridge Night Sky Room** (p.76) | Street: halls · Top: tower top + skybridge | assassination, data_theft |
| Digital Divinity (upper_marina_11) | Upper Marina | High-security tower with **AV pads**; "All-Spring of Deus" NET (p.71) | Street · Top + pad | data_theft |

**Not band towers:** Eurasiabank Plaza (p.93) is a *sunken* tower, six floors underground with the top crumbled. That is
BasementGen's job and already a set piece. Totentanz/Burleson Tower (p.94) is played at the club in its base. N54 ruin and
the Crater (p.93-94) have no gigs. Militech Offices (7 up, **20 sublevels** on the lift panel, p.183) and Trauma Team Tower
would be *downward* bands, which are later work (Q8). Hotels: the book gives no heights, except Muy Caro, which has 5 floors and stays ordinary (p.229).
Highcourt Plaza (p.132, guests arrive "by Aerocab AV") is a roof-pad candidate if the owner wants a hotel tower.

## 2. Gig kinds on bands

The objectives place the target in the target building's most secure room (`Encounter.secure_cell`, sites.json `anchors`),
so in a tower that room usually falls in the band whose zone is highest. **Approaches:**
- **L, the lobby + lift.** The default: walk in through public rooms (`_public_access`), then use a keycard, bypass or netrunner at the car.
- **R, the roof by AV.** Only where the book puts a pad (Nakagawa Garage p.205, Digital Divinity p.71, NCPD #3 p.192, Hall of Justice p.122,
  TT Tower p.195). The crew owns no AV, so the insertion is an **Aerocab charter** (Aerocab, p.215). The price and the alarm on landing are ours (Q4).
- **S, fire stairs.** Off-map transit between bands, the fallback when the lifts are locked down.
- **T, staging floor.** Deploy on an empty floor (MA&F "half the floors empty", p.123; Brownstone Waterfront "borrow an empty unit", p.70), then take the stairs to the band.

| Kind (objective module) | Where it sits | How the crew gets there | Tower twist |
|---|---|---|---|
| data_theft (`data`) | Server room or data vault: the mid band (Continental labs, Ziggurat's secret CitiNet floor shown as a range on the strip) or **B1** (sites.json corp_office `below_grade`: "server floor under the tower") | L to the band, then jack in there (§4); B1 data is a **street-band-only gig** | NET per band: the File can't be pulled from the lobby |
| assassination (`assassinate`) | Exec band (Haakensen, Ortega, Shinobu's penthouse, UR's apex) | L, R or T | The mark's exits are **the lift and the roof pad**. Holding or locking the lift traps the mark; Trauma Team lands on the pad (the mark's card) |
| rescue (`rescue`) | Cells: Tyger Works 3-4 (p.207), Hall of Justice and NCPD basements | Mostly a **street-band gig**; a high cell means L up and an escorted ride down | The freed hostage rides in the car; 4 places means two trips |
| sabotage (`sabotage`) | Server core or generator: CitiNet floor, B1 plant | L or S | 3-round fuse: get to the lift. Blasts never cross bands |
| corp_extraction (`snatch`) | Labs/mid band | L (MA&F: a snatched employee's implant works the lifts, p.123) | The package carrier rides down; if they go down, the package stays on the floor |
| gang_hit (`eliminate`) | The gang's floors: Guăngbō 15-16 bowling, Tyger Works 9-10, H10 | L or S; **gang doctrine has no keycards and no lockdown** | A one-band gig (Q3): the other band's gangers come down as backup |

## 3. Security Codes and doctrine per band

| Band | TacMap zones | Lift row needs | Posts / devices (existing rooms.json) |
|---|---|---|---|
| Street / lobby (B1, 1, 2) | STREET, PUBLIC, STAFF (security post, garage) | Public rows open; the B1 row needs the staff card | Security desk, `alarm_panel`, lift-lobby camera |
| Mid (labs, offices) | STAFF, SECURE | Staff card | Lift-lobby post and camera; camera groups per floor |
| Exec | SECURE, VAULT | Secure card | Bodyguards; turrets at security 3 (`has_turrets`) |
| Roof / pad | SECURE (ours) | Not a lift row: stairs from exec (ours) | Sniper nest (Zen hook, p.205), AV |

- **Keycards (existing).** `Encounter._hand_out_keycards` gives one guard per locked zone that zone's card. `loot_keycard` opens every lock of
  that zone or below. Tower rows reuse it: a car stops at a row when the crew holds the row's zone card, holds the lift
  Control Node, wins the panel bypass (`BYPASS_DV` 13/13/15/17 by security, RULES-UNVERIFIED, CPR p.209), or carries an implant (MA&F).
- **Codes (unchanged).** The site code is rolled once (1d10 under `n`, NC2045 p.7). Responders arrive after 1d6 or 1d10 minutes at
  `ROUNDS_PER_MINUTE` 2 (HOUSE-RULE), sized by intensity on the p.399 budget. **New:** they arrive at the street band's entrance instead of the
  map's far edge (`_spawn_wave`), then ride the lift (+1 round) to the alarm band. If the crew holds or locks the lift, they take
  the stairs at stair pace (§5). Factions the book flies (Trauma Team; Netwatch on the Hall of Justice roof, p.122; NCPD #3 roof pads, p.192) can
  land on the pad instead. This links to the owner's 2026-11-06 backlog item (rappel from the AV).
- **Lockdown (new doctrine field `lockdown`, HOUSE-RULE).** At alarm 2 (`call_it_in`), every car goes to the lobby and opens. Rows above PUBLIC lock to
  their zone card, and stairwell doors into SECURE floors become security doors. The strip turns amber. Values: `default`,
  `corp_standard`, `corp_military` = "recall"; `gang_den` = none (gangs have no keycards either), so gang towers keep their lifts running for both
  sides.
- **Utility Code power out** (p.8, 1 gig in 3) already kills cameras and turrets; ours: it also stops the lifts, so the gig becomes a stairs gig (Q5).

## 4. Netrunning

The roadmap principle holds: we keep the book's node types, DVs, abilities, ICE and Defences, and the NET's structure is our graph (M2 verdicts).

- **The lift Control Node.** CPR lists elevators among Control Node devices (p.199). Today Furnish adds one
  `elevator` device on floor 0 (group `elevator`, zone PUBLIC), and taking the node only disables it. Proposal: the node sits at the
  **STAFF** level of the street band's NET (building services, ours), and each operation is a NET Action, once per Turn per node (p.199):
  **Call** (send a car to a row), **Hold** (car stays, doors open, enemy calls fail), **Lock** (rows and cars refuse: strand a
  response team at the lobby, or stall a car between floors with its riders in it), and **Unlock rows** (in place of a keycard). Jacking out loses the node (p.199).
- **Sleep Gas Elevator** (the book's Environmental Defense, p.215-216): the car seals, rolls top of Initiative, DV13 Resist
  Torture/Drugs or Unconscious, 60 HP, Electronics/Security Tech counter DV17 / 5 min. Exec-band cars at security 3 carry it on the lift node.
  Whoever holds the node can gas a car, so the crew's netrunner can gas responders and the site can gas the crew.
- **NET per band (recommended).** Each band gets its own architecture with its own access points (Jack In needs an access point within 6 m with no wall between, p.198). The bands are joined by
  paired sockets that link the same level only, which already works (`net_links`). This puts the lift in the lobby NET while the exec File is only
  reachable upstairs. A runner can stay downstairs and ferry the crew, but the data job still needs someone in the room. The book backs the split:
  one architecture tops out at 18 floors and 2-3 Control Nodes (p.217), and big sites run several (EuroBank p.121). The cheaper alternative
  (A) is one NET for the whole tower with band subnets. It is simpler, but a lobby jack-in could then reach exec content.
- **Virus at the lowest floor** (owner backlog 2026-11-07; p.200). The Virus is left at the bottom node of an architecture; on our graph
  that is the deepest level, the B1 security office or server room of the lobby NET. It makes up to 2 changes and persists after Jack Out. Book
  price for "make a Control Node malfunction": DV10, 2 NET Actions. Using it on the lift (HOUSE-RULE by analogy): **the lifts ignore lockdown and row locks
  for the rest of the gig**. This is double-edged, because the guards can use them too (Q7). It is the way to open the lifts for good: plant it early
  in the street band, and the late lockdown can't touch you. Other p.200 Viruses carry over unchanged (disable a Black ICE DV10/2;
  delete all Black ICE DV12/10; halve floors DV12/10). Nobody on the site runs the NET yet, so nothing can destroy the Virus (DV = the Virus Check, p.200).
- **Cameras and turrets per band.** Cameras already group per zone per floor (`cameras_<zone>_f<n>`), and turrets per secure room. Each
  becomes a Control Node in its band's NET, so blinding the sky band needs a runner in the sky band. `master_cameras`
  (net-only, deepest level) stays per NET. Every band's lift lobby has a camera (rooms.json), so a car that dings on arrival at a band the crew has not blinded is seen.
- The book's metaphor for an architecture is an elevator of floors (p.209), so the strip and the NET view can share a look.

## 5. Rules

| Item | Value | Tag |
|---|---|---|
| Call / ride | Pressing the panel = Use an Object Action (p.169). Riders board and the car leaves at end of turn; they arrive at the start of their next turn. 4 riders (ours) | HOUSE-RULE: CPR has no lift rule. **One round per ride** matches our pacing: 1 round ≈ 30 s at `ROUNDS_PER_MINUTE` 2, and an express car covers ~150-200 m in 30 s (ours). RAW rounds are ~3 s (NC2045 p.7-8 example) |
| Lift inside a band, ordinary buildings | Unchanged: an elevator shaft costs 1 move per floor (`Nav`) | (Q2) |
| Stairs inside a band | 1 per floor (Nav, existing); ladders/fire escapes climb at 2 per floor (p.169) | existing |
| Fire stairs between bands | Off-map transit. Pacing-consistent: ~4 floors/min up, 6 down (ours) → **2 floors/round up, 3 down**, so 46 floors ≈ 23 rounds. T3's draft said 1 round per 10 floors | HOUSE-RULE (Q1). docs/rules gives no fatigue rule; none applied |
| Falling | 40 m per turn end, DV15 Athletics to catch a ledge, 2d6 per 10 m, **skyscraper fall = dead** (p.181). A storey is 3.2 m (`FH` 1.6 squares), so a 3-storey drop is ~10 m | RAW. Falls aren't modelled in Encounter today. Band edges and shafts stay solid: doors open only on a car, so nobody can walk into the shaft |
| Grapple gun | 30 m line, climbed at no movement penalty (p.181/353), ~9 storeys: a within-band route at most (later) | RAW |
| Panel bypass | Electronics/Security Tech vs `BYPASS_DV` (p.209) | RULES-UNVERIFIED (existing) |
| Sleep Gas Elevator | As p.215-216 | RAW |

## 6. Staged build plan (cost against current code)

| Stage | Scope | Work against today's code | Est. |
|---|---|---|---|
| 0 | Prerequisite | H1 stack (proposal: ~2.5-3 wk). If the sky band ships first, only the strip widget is needed (3 d) | — |
| **1a Sky band only (T1)** | One band (e.g. Raven 48-50 + R); crew deploys from a lift car or the pad; riding down = extraction | `TacMap.storey_base` + save field so `floor_name` prints 48 (pattern of `basements`) 1 d · `tower` block per location in docs/world (storeys, bands, programmes, pad, cite; ours tagged) → gen_world_data 1 d · tower_top recipe: BuildingGen `floors` = band size, programme per storey (Layouts.program `keep`), `lift_in` lift lobby = deploy 2-3 d · GigSetup.for_campaign picks the band from the objective kind 1 d · responders spawn at the lift lobby / stairwell, not the far entrance (`_spawn_wave`) 1-2 d · facade impostor + smog + far-city plane (WorldBuilder / sky shader) 3-4 d · strip 3 d · soak `--plan` entry 0.5 d | ~2 wk |
| **1b Lobby band only** | Street + lobby + B1 (BasementGen `below_grade`), tower rising out of frame. Plays B1 data, cells rescue, the Scythe / Whitewater floors | Impostor above (reuses 1a's) · `BuildingGen._roof` skipped when the tower continues · taller neighbour in the backdrop · rows above shown "off map" | ~1 wk |
| **2 Full bands (T3)** | Two bands in one TacMap, the lift ride as the cut between them | `TacMap.bands` [{from, to, storey_from}] built **BasementGen-style**: plan each band as its own BuildingGen pass, then stack it with an `append`, the mirror of `TacMap.lift` (shift nothing, record ranges) 3-4 d · Nav/FloorNav: band link = ride; Encounter transit state (cf. `_off_map`), car position, capacity, DING noise 5-7 d · view: generalise `_grade_shows` / `_below_grade_view` to "in band"; Vision/LOS/blasts stop at band edges; ride cut + counter 3-4 d · HUD call mode 2 d · AI uses lifts/stairs 3 d · soak transit invariants 1-2 d | ~2.5-3 wk |
| **3 Security + NET** | Keycard rows, lockdown, lift verbs, gas car, NET per band, Virus | doctrine `lockdown` (security.md → gen) 1 d · lift node verbs + Sleep Gas Elevator 3 d · architectures per band + paired sockets (`architectures` keyed by structure+band) 2-3 d · generic Virus at the bottom node (all NETs; lift case first) 3 d · power-out stops lifts 0.5 d | ~1.5-2 wk |
| **4 Canon towers** | Raven (pilot), Continental, Tyger Works, Guăngbō, Haakensen; Ziggurat's 6-floor set piece → bands (secret CitiNet floor as a strip range) | Set-piece recipes in setpieces.json with `bands`; ~2-3 d each | ~2 wk |

**Visual sign-off (the owner's ask).** It needs a 🔶 review page with verdicts saved on the page, per CLAUDE.md.
- **V1, after 1a (the gate before stage 2).** Headless renders (xvfb, software GL; the owner judges them locally):
  1. The sky band at the default iso camera, three seeds (Raven corp, Ziggurat apex, hotel), day and night palettes. The facade should fall into smog over the far city.
  2. The strip at idle, in call mode, with the car moving, with padlocked rows, in amber lockdown, showing an intel range ("44-48"), and with crew/foe pips.
  3. Lift doors with the floor indicator, the Alt lift plate, and the lift-lobby camera.
  4. The H1 cut at 49 with 50 dashed above. (Owner's V1 verdict: the dashed outline is removed; the strip tells the floors.)
- **V2, the release gate, after 2-3.** Everything in V1, plus:
  1. The street band with the tower climbing out of frame and a taller neighbour.
  2. A ride-cut contact sheet: doors close, the counter rolls, the facade streaks, plus the reduced-motion version.
  3. The DING arrival into a waiting lift lobby.
  4. The NET view of the lobby NET with the lift node held, next to the strip.
  5. The gassed-car state.
  6. A lockdown turn showing the response team's pips climbing the stairwell column.

## 7. Open questions for the owner

1. **Stair pace between bands:** pacing-consistent 2 floors/round up (46 floors ≈ 23 rounds, so lockdown really bites), or T3's 1 round per 10 floors? *Recommend pacing-consistent.*
2. **Lifts inside a band and in ordinary buildings:** keep the 1-move-per-floor walk, or make every lift a ride? *Recommend keeping the walk; only band links are rides.*
3. **Gang hit in a tower:** play a single band and count only its guards plus backup? *Recommend yes.*
4. **Roof insertion:** an Aerocab charter only where the book puts a pad? At what price, and does a corp pad landing raise the alarm, or only "suspicious"?
5. **Power out:** do the lifts die (a stairs-only gig), or keep running in fire-service mode for security only?
6. **NET per band (recommended) or one NET per tower?**
7. **Lift Virus:** double-edged "malfunction", so the guards can ride too (closer to p.200), or crew-only row unlocks?
8. **Downward bands** (Militech's 20 sublevels, Trauma Team's subbasement execs): use the same strip later, or never?
9. **Heights the book omits** (Ziggurat, Continental, Haakensen, N54, Thurgood): pick plausible totals (ours, tagged), or show "?" on the strip's hairline?

## 8. Owner decisions (2026-11-08)
1. No floor-by-floor stair walk between bands. Proposed instead: the stairwell is a band transition like the lift (quick cut, ~1 round per 5 floors while the alarm clock runs) with re-entry floors only; other floors need a locked fire door bypass or keycard. **Approved by the owner, 2026-11-08.**
2. Lift rides are allowed in small buildings too; most buildings have no lift.
3. Gang hit in a tower: a single band.
4. No Aerocab charter for now.
5. Power out: stair doors fail open (fire code), lifts go to fire-service mode (security only). This is the stairs' role (stairwell approved, see 1).
6. One NET per band.
7. Lift Virus: closest to the book (malfunction both sides can use) if it plays well.
8. Downward bands approved.
9. Missing heights: plausible values where floors are a reasonable expectation, tagged ours.
- Tower gigs are rare and gated to later progression; keep a good mix of high-rise and low-rise gigs.
- Admin custom gig builder (dev mode) for debugging all content.

## 9. Stage 1a as built (2026-11-08)

- **Storeys.** `TacMap.storey_base`, `TacMap.bands` (one record in 1a: `{id, kind, from_floor, to_floor, storey_from,
  roof_floor, programme}`; stage 2 appends) and `TacMap.tower`; `floor_name` prints 48, 49, 50, R. Saved in
  `to_dict` on tower maps only (`storeys_from_dict` reads them back); ordinary maps are byte-identical.
- **Data.** `docs/world/towers.md` sets `locations.<id>.tower` for nine towers (Raven, MA&F, Continental, Ziggurat apex,
  Haakensen, New Libertine, Segotari, N54, Highcourt Plaza); heights the book omits are ours and flagged.
  Recipes `tower_corp` / `tower_hotel` in sites.json: a shared five-band plan with storey programmes.
- **Generation.** Scene `tower_top` (TowerGen): one sealed BuildingGen pass (no street door, rooms grow from the lift
  lobby), the lift car on an inner lobby wall with its doors toward the default camera, VOID sky round the plate.
  Deploy = the car and the lobby squares before it (also the extraction zone: riding down is getting out).
- **Responders.** `Encounter.arrival_cell`: out of the lift or up the fire stair on the crew's storey, the farther
  free one (complication waves too). The assassination mark's only exit is the car on the band's lowest storey,
  so a crew member standing in it holds the lift and traps the mark.
- **HOUSE-RULE (ours):** a tower band's lowest storey has public access like a set piece's public floor (the crew
  stepping out of the car passes as visitors until a restricted door), else the lobby camera raised the alarm on
  every tower gig at round 1.
- **Campaign.** gigs.json `tower`: past best Reputation 4, one board in four carries one tower offer in place of an
  ordinary one; pay x1.5. Ordinary offers at a tower's place still play its street building until stage 1b.
  One tower gig in `tower.day_in` (3) plays by day (owner, V1 verdicts), drawn from its seed and kept on the gig
  as `sky` (Campaign.tower_sky; the map's params carry it to the greybox's light). `--sky=day|night` overrides.
  Dev builder: Tower field, `--tower=<id|location|any>`, `--band`.
- **View.** WorldBuilder surround `sky`, built by TowerDress in each tower's look (TowerLook,
  `data/gen/tower_looks.json`, by the tower's short id, else its recipe): the band's outer walls get the facade's
  skin outside (inside they are as they were), and the impostor facade under the plate repeats the band's lowest
  storey square by square (tower.gdshader mask), rooms lit or dark storey by storey, so there is no seam (owner, V1).
  Setbacks, plant storeys with catwalks, light seams, floodlighting; the crown (fins, logo sign, gold tiers, lit
  ring) off the back edges with a mast, dishes and aviation lights, drawn only while the roof is; greebles below
  (cradle, pipes, holo-ad screens, Highcourt's blade sign and AV pad, MA&F's twin and walkways, sky-bridge stubs);
  a far city of varied towers with crowns and rooftop ads, huge holograms in the smog, drone traffic, the street
  grid far below and the smog lit from beneath. Height fog hangs under the band (LOOKS `tower_top`, `tower_day`).
  Lift car with seven-segment floor indicator; Alt lift plate; the tower strip (programme names, car, gold
  objective notch, `2-47 · 46 floors` hairline, `1 lobby · off map`).
- **Deferred to stage 2+** (V1 items not built): call mode, the moving car and ride cut, padlocked rows, amber
  lockdown, intel range rows, DING, stairwell transition, street band (1b).
