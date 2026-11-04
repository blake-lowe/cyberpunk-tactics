#!/usr/bin/env python3
"""Builds the content-catalogue review page from catalogue renders.

    python3 tools/catalogue_page.py <render_dir> <out.html> [notes.json]

<render_dir> holds faction_<id>.png (tools/catalogue.gd) and places/site_<id>.png,
places/district_<profile>.png (greybox --promo shots). The page shows every faction, building
site and district profile with its data, any review notes, and Keep / Change / Unsure verdicts
that save to the artifact's db (collection "verdicts", one doc per item: choice, note, updated).
notes.json (optional): {"sections": {section: {"intro", "choice": {question, options}}},
"items": {"section/id": {"finding", "recommend"}}}.
"""
import base64
import html
import io
import json
import os
import sys

from PIL import Image


def jpeg_uri(path, crop=None, width=None, q=82):
    im = Image.open(path).convert("RGB")
    if crop:
        im = im.crop(crop)
    if width and im.width > width:
        im = im.resize((width, round(im.height * width / im.width)), Image.LANCZOS)
    buf = io.BytesIO()
    im.save(buf, "JPEG", quality=q, optimize=True)
    return "data:image/jpeg;base64," + base64.b64encode(buf.getvalue()).decode()


def load(p):
    return json.load(open(p, encoding="utf-8"))


def main():
    rd, out = sys.argv[1], sys.argv[2]
    notes = load(sys.argv[3]) if len(sys.argv) > 3 else {"sections": {}, "items": {}}
    fac = load("data/world/factions.json")["factions"]
    doctrines = load("data/world/security.json")["doctrines"]
    sites = {k: v for k, v in load("data/gen/sites.json").items() if k != "_doc"}
    districts = {k: v for k, v in load("data/gen/districts.json").items() if k != "_doc"}
    items = []
    for fid, f in fac.items():
        p = os.path.join(rd, "faction_%s.png" % fid)
        facts = [["Kind", f.get("kind", "")]]
        if f.get("doctrine"):
            facts.append(["Security", doctrines.get(f["doctrine"], {}).get("name", f["doctrine"])])
        ranks = f.get("roster", {}).get("ranks", {})
        if ranks:
            facts.append(["Ranks", " / ".join(ranks.get(t, "") for t in ["mook", "lieutenant", "mini_boss"] if ranks.get(t))])
        if f.get("gigs"):
            facts.append(["Target of", ", ".join(g.replace("_", " ") for g in f["gigs"])])
        items.append({"section": "factions", "id": fid, "name": f.get("name", fid), "facts": facts,
                      "img": jpeg_uri(p, crop=(60, 190, 900, 540), width=840) if os.path.exists(p) else ""})
    for sid, s in sites.items():
        p = os.path.join(rd, "places", "site_%s.png" % sid)
        facts = [["Layout", str(s.get("layout", {}).get("algorithm", s.get("layout", "")) if isinstance(s.get("layout"), dict) else s.get("layout", ""))]]
        if s.get("floors"):
            facts.append(["Floors", "%s-%s" % tuple(s["floors"]) if isinstance(s["floors"], list) else str(s["floors"])])
        items.append({"section": "sites", "id": sid, "name": s.get("name", sid.replace("_", " ")).title() if not s.get("name") else s["name"],
                      "facts": [f for f in facts if f[1]], "img": jpeg_uri(p, width=960, q=78) if os.path.exists(p) else ""})
    for did, d in districts.items():
        p = os.path.join(rd, "places", "district_%s.png" % did)
        facts = []
        for k, label in [("pattern", "Streets"), ("floors", "Floors"), ("security", "Security"), ("decay", "Decay")]:
            v = d.get(k)
            if v is not None:
                facts.append([label, "%s-%s" % tuple(v) if isinstance(v, list) else str(v)])
        items.append({"section": "districts", "id": did, "name": d.get("name", did.replace("_", " ").title()),
                      "facts": facts, "img": jpeg_uri(p, width=960, q=78) if os.path.exists(p) else ""})
    for it in items:
        n = notes.get("items", {}).get("%s/%s" % (it["section"], it["id"]))
        if n:
            it["note"] = n
    page = TEMPLATE.replace("__DATA__", json.dumps({"items": items, "sections": notes.get("sections", {})}, ensure_ascii=False).replace("</", "<\\/"))
    open(out, "w", encoding="utf-8").write(page)
    print("%s: %d items, %.1f MB" % (out, len(items), len(page) / 1e6))


TEMPLATE = r"""<title>Night City Catalogue</title>
<meta name="claude:viewport-fit-sides" content="cover">
<link rel="stylesheet" href="https://fonts.googleapis.com/css2?family=Chakra+Petch:wght@500;600;700&family=IBM+Plex+Sans:wght@400;500;600&family=IBM+Plex+Mono:wght@400;500&display=swap">
<style>
/* Layout: a sticky tally bar over three sections (factions, sites, districts); each a grid of
   review cards: picture, the data behind it, any finding, then Keep / Change / Unsure. The game's
   own HUD palette: cyan crew, gold objectives, red hostiles, on blue-black ink. */
:root {
	--ink: #0b0e14; --panel: #131923; --raise: #1a2230; --line: #263142;
	--fg: #e4ebf2; --dim: #8796a4; --cyan: #05d9e8; --gold: #f9c80e; --red: #ff3b4f; --green: #39f0a0;
	--on-accent: #061016;
	--display: "Chakra Petch", "Rajdhani", "Segoe UI", system-ui, sans-serif;
	--body: "IBM Plex Sans", "Segoe UI", system-ui, sans-serif;
	--mono: "IBM Plex Mono", ui-monospace, "SFMono-Regular", Menlo, monospace;
	color-scheme: dark;
}
@media (prefers-color-scheme: light) { :root:not([data-theme="dark"]) {
	--ink: #eef1f4; --panel: #ffffff; --raise: #f5f7f9; --line: #d3dae2;
	--fg: #0f151c; --dim: #4e5b68; --cyan: #00727c; --gold: #8a6500; --red: #c2132c; --green: #0b7448;
	--on-accent: #ffffff; color-scheme: light; } }
:root[data-theme="light"] {
	--ink: #eef1f4; --panel: #ffffff; --raise: #f5f7f9; --line: #d3dae2;
	--fg: #0f151c; --dim: #4e5b68; --cyan: #00727c; --gold: #8a6500; --red: #c2132c; --green: #0b7448;
	--on-accent: #ffffff; color-scheme: light; }
body { background: var(--ink); color: var(--fg); font: 15px/1.55 var(--body); }
body::before { content: ""; position: fixed; inset: 0 0 auto; height: env(safe-area-inset-top, 0px); z-index: 10; background: var(--panel); }
.wrap { max-width: 1240px; margin: 0 auto; padding-left: max(16px, env(safe-area-inset-left, 0px)); padding-right: max(16px, env(safe-area-inset-right, 0px)); }
header.top { padding-block: 28px 18px; display: grid; gap: 8px; }
.eyebrow { font: 600 12px/1 var(--display); letter-spacing: .16em; text-transform: uppercase; color: var(--cyan); }
h1 { font: 700 clamp(28px, 4vw, 40px)/1.1 var(--display); margin: 0; text-wrap: balance; }
.lede { color: var(--dim); max-width: 66ch; margin: 0; }
.bar { position: sticky; top: env(safe-area-inset-top, 0px); z-index: 5; background: var(--panel); border-block: 1px solid var(--line); }
.bar .wrap { display: flex; flex-wrap: wrap; gap: 10px 22px; align-items: center; padding-block: 10px; }
.tally { display: flex; flex-wrap: wrap; gap: 6px 18px; font: 500 13px/1.3 var(--mono); font-variant-numeric: tabular-nums; color: var(--dim); }
.tally b { color: var(--fg); font-weight: 500; }
.filters { display: flex; gap: 6px; margin-left: auto; flex-wrap: wrap; }
.chip { font: 600 12px/1 var(--display); letter-spacing: .08em; text-transform: uppercase; padding: 8px 12px; border: 1px solid var(--line); background: transparent; color: var(--dim); cursor: pointer; }
.chip[aria-pressed="true"] { color: var(--on-accent); background: var(--cyan); border-color: var(--cyan); }
.chip:focus-visible, .seg button:focus-visible, textarea:focus-visible, .opt:focus-visible { outline: 2px solid var(--gold); outline-offset: 2px; }
.status { font: 400 12px/1.3 var(--mono); color: var(--dim); }
.status.warn { color: var(--gold); }
section { padding-block: 34px 8px; display: grid; gap: 16px; }
section > h2 { font: 700 22px/1.2 var(--display); margin: 0; display: flex; align-items: baseline; gap: 12px; }
section > h2 small { font: 500 13px var(--mono); color: var(--dim); }
section > p { margin: 0; color: var(--dim); max-width: 72ch; }
.choice { border: 1px solid var(--line); background: var(--panel); padding: 16px; display: grid; gap: 12px; }
.choice h3 { margin: 0; font: 600 16px/1.35 var(--display); }
.opts { display: grid; grid-template-columns: repeat(auto-fit, minmax(230px, 1fr)); gap: 10px; }
.opt { text-align: left; border: 1px solid var(--line); background: var(--raise); color: var(--fg); padding: 12px; cursor: pointer; display: grid; gap: 4px; font: inherit; }
.opt strong { font: 600 14px/1.3 var(--display); letter-spacing: .02em; display: flex; gap: 8px; align-items: center; flex-wrap: wrap; }
.opt span { color: var(--dim); font-size: 13.5px; }
.opt[aria-pressed="true"] { border-color: var(--cyan); box-shadow: inset 0 0 0 1px var(--cyan); }
.rec { font: 600 10.5px/1 var(--display); letter-spacing: .1em; text-transform: uppercase; color: var(--on-accent); background: var(--gold); padding: 3px 6px; }
.grid { display: grid; grid-template-columns: repeat(auto-fill, minmax(min(100%, 360px), 1fr)); gap: 16px; }
.card { background: var(--panel); border: 1px solid var(--line); display: grid; grid-template-rows: auto 1fr auto; min-width: 0; }
.card[data-choice="keep"] { border-color: color-mix(in srgb, var(--green) 55%, var(--line)); }
.card[data-choice="change"] { border-color: color-mix(in srgb, var(--red) 60%, var(--line)); }
.card[data-choice="unsure"] { border-color: color-mix(in srgb, var(--gold) 55%, var(--line)); }
.shot { aspect-ratio: 16 / 9; max-width: 100%; background: var(--raise); display: grid; place-items: center; overflow: hidden; }
.card[data-section="factions"] .shot { aspect-ratio: 840 / 350; }
.shot img { width: 100%; height: 100%; object-fit: cover; display: block; }
.shot em { color: var(--dim); font: 400 12px var(--mono); }
.body { padding: 14px 16px 6px; display: grid; gap: 10px; align-content: start; min-width: 0; }
.name { display: flex; align-items: baseline; gap: 10px; flex-wrap: wrap; }
.name h3 { margin: 0; font: 600 17px/1.25 var(--display); }
.name code { font: 400 12px var(--mono); color: var(--dim); }
dl { margin: 0; display: grid; grid-template-columns: max-content 1fr; gap: 3px 12px; font-size: 13.5px; }
dt { color: var(--dim); font: 500 11px/1.9 var(--display); letter-spacing: .1em; text-transform: uppercase; }
dd { margin: 0; min-width: 0; overflow-wrap: anywhere; }
.note { border-left: 3px solid var(--gold); padding: 6px 0 6px 10px; font-size: 13.5px; display: grid; gap: 4px; }
.note b { font: 600 11px/1.4 var(--display); letter-spacing: .1em; text-transform: uppercase; color: var(--gold); }
.verdict { padding: 10px 16px 16px; display: grid; gap: 8px; }
.seg { display: grid; grid-template-columns: repeat(3, 1fr); border: 1px solid var(--line); }
.seg button { font: 600 12.5px/1 var(--display); letter-spacing: .08em; text-transform: uppercase; padding: 10px 6px; background: transparent; color: var(--dim); border: 0; cursor: pointer; }
.seg button + button { border-left: 1px solid var(--line); }
.seg button[aria-pressed="true"][data-v="keep"] { background: var(--green); color: var(--on-accent); }
.seg button[aria-pressed="true"][data-v="change"] { background: var(--red); color: var(--on-accent); }
.seg button[aria-pressed="true"][data-v="unsure"] { background: var(--gold); color: var(--on-accent); }
.seg button:disabled { cursor: not-allowed; opacity: .55; }
textarea { width: 100%; box-sizing: border-box; min-height: 38px; resize: vertical; background: var(--raise); color: var(--fg); border: 1px solid var(--line); padding: 8px 10px; font: 400 13.5px/1.45 var(--body); }
.saved { font: 400 11.5px var(--mono); color: var(--dim); min-height: 1em; }
footer { padding-block: 30px 40px; color: var(--dim); font-size: 13px; }
@media (prefers-reduced-motion: no-preference) { .card { transition: border-color .2s; } }
</style>

<header class="top wrap">
	<div class="eyebrow">Content review · data/world + data/gen</div>
	<h1>Night City Catalogue</h1>
	<p class="lede">Every faction, building site and district the generator can build, rendered from the data. Mark each one Keep, Change or Unsure and add a note; verdicts save as you go and Claude reads them back before the next content pass.</p>
</header>
<div class="bar"><div class="wrap">
	<div class="tally" id="tally"></div>
	<span class="status" id="status">Connecting to saved verdicts…</span>
	<div class="filters" role="group" aria-label="Show">
		<button class="chip" id="f-all" data-f="all" aria-pressed="true">All</button>
		<button class="chip" id="f-open" data-f="open" aria-pressed="false">No verdict yet</button>
		<button class="chip" id="f-change" data-f="change" aria-pressed="false">Change</button>
	</div>
</div></div>
<main class="wrap" id="main"></main>
<footer class="wrap">Rebuild with <code>tools/catalogue.gd</code> (faction looks), greybox <code>--promo=1</code> shots (places) and <code>tools/catalogue_page.py</code>.</footer>

<script id="data" type="application/json">__DATA__</script>
<script>
const DATA = JSON.parse(document.getElementById("data").textContent);
const SECTIONS = [["factions", "Factions"], ["sites", "Building sites"], ["districts", "Districts"]];
const state = {};          // key -> {choice, note}
let db = null, canWrite = false, filter = "all";
const key = it => `cat_${it.section}_${it.id}`;
const esc = s => String(s).replace(/[&<>"]/g, c => ({"&": "&amp;", "<": "&lt;", ">": "&gt;", '"': "&quot;"}[c]));

function render() {
	const main = document.getElementById("main");
	main.innerHTML = "";
	for (const [sid, title] of SECTIONS) {
		const its = DATA.items.filter(i => i.section === sid);
		const sec = document.createElement("section");
		sec.id = sid;
		const meta = DATA.sections[sid] || {};
		sec.innerHTML = `<h2>${title} <small>${its.length}</small></h2>` + (meta.intro ? `<p>${esc(meta.intro)}</p>` : "");
		if (meta.choice) sec.appendChild(choiceBlock(sid, meta.choice));
		const grid = document.createElement("div");
		grid.className = "grid";
		for (const it of its) grid.appendChild(card(it));
		sec.appendChild(grid);
		main.appendChild(sec);
	}
	applyFilter();
	tally();
}

function choiceBlock(sid, ch) {
	const k = `cat_${sid}__choice`;
	const box = document.createElement("div");
	box.className = "choice";
	box.innerHTML = `<h3>${esc(ch.question)}</h3><div class="opts"></div><textarea id="${k}-note" placeholder="Anything to add?" aria-label="Note on this question"></textarea><div class="saved" id="${k}-saved"></div>`;
	const opts = box.querySelector(".opts");
	for (const o of ch.options) {
		const b = document.createElement("button");
		b.className = "opt"; b.id = `${k}-${o.id}`; b.dataset.k = k; b.dataset.v = o.id;
		b.setAttribute("aria-pressed", String((state[k] || {}).choice === o.id));
		b.innerHTML = `<strong>${esc(o.label)}${o.recommended ? ' <span class="rec">Recommended</span>' : ""}</strong><span>${esc(o.detail)}</span>`;
		b.disabled = !canWrite;
		b.onclick = () => choose(k, o.id);
		opts.appendChild(b);
	}
	wireNote(box.querySelector("textarea"), k);
	return box;
}

function card(it) {
	const k = key(it), s = state[k] || {};
	const el = document.createElement("article");
	el.className = "card"; el.dataset.section = it.section; el.dataset.key = k;
	if (s.choice) el.dataset.choice = s.choice;
	const facts = it.facts.map(([a, b]) => `<dt>${esc(a)}</dt><dd>${esc(b)}</dd>`).join("");
	const note = it.note ? `<div class="note"><b>Finding</b><span>${esc(it.note.finding)}</span>${it.note.recommend ? `<b>Recommend</b><span>${esc(it.note.recommend)}</span>` : ""}</div>` : "";
	el.innerHTML = `<div class="shot">${it.img ? `<img alt="${esc(it.name)} render" loading="lazy" src="${it.img}">` : "<em>no render yet</em>"}</div>
		<div class="body"><div class="name"><h3>${esc(it.name)}</h3><code>${esc(it.id)}</code></div><dl>${facts}</dl>${note}</div>
		<div class="verdict"><div class="seg" role="group" aria-label="Verdict for ${esc(it.name)}">
			${["keep", "change", "unsure"].map(v => `<button id="${k}-${v}" data-v="${v}" aria-pressed="${s.choice === v}">${v}</button>`).join("")}
		</div><textarea id="${k}-note" placeholder="Note (what to change, or why)" aria-label="Note on ${esc(it.name)}"></textarea><div class="saved" id="${k}-saved"></div></div>`;
	for (const b of el.querySelectorAll(".seg button")) { b.disabled = !canWrite; b.onclick = () => choose(k, b.dataset.v); }
	wireNote(el.querySelector("textarea"), k);
	return el;
}

function wireNote(ta, k) {
	ta.value = (state[k] || {}).note || "";
	ta.disabled = !canWrite;
	let t = null;
	ta.addEventListener("input", () => { clearTimeout(t); t = setTimeout(() => saveNote(k, ta.value), 900); });
	ta.addEventListener("blur", () => { clearTimeout(t); if (ta.value !== ((state[k] || {}).note || "")) saveNote(k, ta.value); });
}

const pending = {};   // one write at a time per document
async function write(k) {
	if (!db || !canWrite) return;
	if (pending[k]) { pending[k].again = true; return; }
	pending[k] = {again: false};
	const out = document.getElementById(`${k}-saved`);
	try {
		do {
			pending[k].again = false;
			if (out) out.textContent = "Saving…";
			const s = state[k] || {};
			await db.collection("verdicts").doc(k).set({choice: s.choice || "", note: s.note || "", updated: new Date().toISOString()});
		} while (pending[k].again);
		if (out) out.textContent = "Saved";
	} catch (e) {
		if (out) out.textContent = e && e.code === "permission_denied" ? "You can view this page but not save verdicts." : "Couldn't save. Your choice is kept here; try again in a moment.";
	} finally { delete pending[k]; }
}

function choose(k, v) {
	state[k] = Object.assign({}, state[k], {choice: v});
	document.querySelectorAll(`[id^="${CSS.escape(k)}-"][data-v]`).forEach(b => b.setAttribute("aria-pressed", String(b.dataset.v === v)));
	const c = document.querySelector(`.card[data-key="${CSS.escape(k)}"]`);
	if (c) c.dataset.choice = v;
	tally(); applyFilter(); write(k);
}

function saveNote(k, text) {
	state[k] = Object.assign({}, state[k], {note: text});
	write(k);
}

function tally() {
	const t = document.getElementById("tally");
	const parts = SECTIONS.map(([sid, title]) => {
		const its = DATA.items.filter(i => i.section === sid);
		const done = its.filter(i => (state[key(i)] || {}).choice).length;
		return `<span>${title} <b>${done}/${its.length}</b></span>`;
	});
	const changes = DATA.items.filter(i => (state[key(i)] || {}).choice === "change").length;
	t.innerHTML = parts.join("") + `<span>To change <b>${changes}</b></span>`;
}

function applyFilter() {
	for (const c of document.querySelectorAll(".card")) {
		const ch = c.dataset.choice || "";
		c.hidden = filter === "open" ? ch !== "" : filter === "change" ? ch !== "change" : false;
	}
}
for (const b of document.querySelectorAll(".chip")) b.onclick = () => {
	filter = b.dataset.f;
	document.querySelectorAll(".chip").forEach(x => x.setAttribute("aria-pressed", String(x === b)));
	applyFilter();
};

render();

(async () => {
	const status = document.getElementById("status");
	db = window.claude ? await window.claude.use("db") : null;
	if (!db) { status.textContent = "Verdicts can't be saved in this view (sign in to claude.ai to review)."; status.classList.add("warn"); return; }
	canWrite = true;
	let first = true;
	const timer = setTimeout(() => { status.textContent = "Saved verdicts can't be reached yet; choices made now will save when it connects."; status.classList.add("warn"); }, 10000);
	db.collection("verdicts").onSnapshot(snap => {
		for (const d of snap.docs) {
			if (!d.id.startsWith("cat_")) continue;
			const v = d.data() || {};
			if (pending[d.id]) continue;   // our own write is in flight; keep the local value
			state[d.id] = {choice: String(v.choice || ""), note: String(v.note || "")};
		}
		if (!snap.metadata.fromCache) { clearTimeout(timer); status.classList.remove("warn"); status.textContent = "Verdicts save as you go"; }
		const active = document.activeElement && document.activeElement.tagName === "TEXTAREA" ? document.activeElement.id : null;
		if (first || !active) { render(); first = false; }
		else tally();
	}, err => { clearTimeout(timer); status.textContent = "Couldn't load saved verdicts (" + (err && err.code || "error") + ")."; status.classList.add("warn"); });
})();
</script>
"""

if __name__ == "__main__":
    main()
