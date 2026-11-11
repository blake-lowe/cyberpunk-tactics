# Anatomical plates of a woman (Andrew Bell, Encyclopaedia Britannica): source and licence

`anatomy_female_ink.png` is two engraved anatomical plates lifted off photographs of the prints, for
the cyberware screens' figure of a crew member with a female body (`ChromeBody.plate_of`,
`src/ui/screens/body_anatomy.gd`, plate `"female"`). It is the counterpart of Milton's man in
`assets/third_party/anatomy/` and is processed the same way.

| | |
|---|---|
| Main plate | *Superficial anatomy of the woman: anterior view.* Engraving by Andrew Bell (1726-1809) after Govert Bidloo, [1798]; Encyclopaedia Britannica, 3rd edition, Anatomy, "Tab. II Part 3", Pl. 43. Wellcome Collection 680359i (image V0008101ER). |
| Deep plate | *Skeleton of a woman: anterior view.* Line engraving by Andrew Bell after Jean-Joseph Sue (after Marie-Geneviève-Charlotte Thiroux d'Arconville's female skeleton), [1798]; the same edition, "Tab. XLIX Part 3", Pl. 90. Wellcome Collection (image V0008127). |
| Source | Wellcome Collection: [works/affzkyvd](https://wellcomecollection.org/works/affzkyvd) and [works/bhrbkxx4](https://wellcomecollection.org/works/bhrbkxx4); full-size images from the IIIF server, `https://iiif.wellcomecollection.org/image/V0008101ER/full/full/0/default.jpg` (1181 x 1618, sha256 c82e15c4...) and `.../V0008127/full/full/0/default.jpg` (2050 x 3407, sha256 5daa4a8e...). |
| Licence | **Public domain.** The Wellcome Collection's catalogue API gives both images the licence `pdm`, "Public Domain Mark" (https://creativecommons.org/share-your-work/public-domain/pdm/), access "Open". The engraver died in 1809; the prints were published in 1797-98. Credit (courtesy, not required): Wellcome Collection. |
| Checked | 2026-11-11, from the Wellcome Collection catalogue API (`/catalogue/v2/images/qgypnh9c` and `/images/q2xctq5n`: `locations[0].license`; the works' `items[].locations[]` say the same). |

What was done to them (`tools/gen_anatomy_ink.py female`, which documents the steps and rebuilds the
file): the plate's two reference letters on her painted out with the paper round them; the engraved
line separated from the paper; her silhouette found from the ink inside a hand-traced outline (she
holds a drape that falls behind her from both hands: where she meets the drape the trace is her edge,
below the knees all round), everything outside it cut away (the drape, the title, plate number and
imprint); the plate printed in reverse as light. The skeleton plate was mirrored left to right (so its
raised arm is her raised arm), its bones found and printed as light the same way (the plate's letters
standing alone on the paper drop out; a few touching the bones remain as small marks), and warped onto
her pose through hand-placed landmark pairs. Nothing is traced into the drawing or added: the anatomy
is Bell's.

Channels: R the woman as light, G her silhouette, B the skeleton as light (mirrored, warped), A the
outline. Import it with `process/fix_alpha_border=false` (every channel is data).

Why these: the brief was a female counterpart to Milton's plates that reads as a set under the same
treatment (a line engraving of similar density, front view, standing, whole body, real anatomy,
ideally a surface or muscle plate with a matching skeleton). Female écorchés in line engraving are
almost non-existent; Bell engraved a surface figure and a skeleton of a woman for the same edition,
in the same English encyclopaedia line-engraving manner as Milton's Rees's Cyclopaedia plates five
years later, which is as close a set as the period offers. Her plate shows the body's surface (skin,
modelled by stipple and hatching), not the muscles: next to Milton's écorché she reads one layer
shallower.

Considered and not used (all Wellcome Collection, Public Domain Mark unless noted):
- J.S. Cuthbert's lithographs for John Marshall's *A Rule of Proportion* (1879), Plate V: a standing
  woman, front view, skeleton inside the body outline (V0008638EL). A clean symmetrical pose, but a
  lithographed outline drawing with almost no hatching: under the treatment it would be a glowing
  outline, not an engraving, and would not match Milton.
- S.F. Ravenet's larger 1750 engraving of the same Bidloo woman (V0008378): sharper, but set in a
  landscape (a tree and a building touch her outline), and with no matching skeleton.
- William Cheselden's skeleton of a woman with a dolphin (1733, V0047569EL): twisted, posed pose.
- Gautier d'Agoty's pregnant écorchée (colour mezzotint, 1770, V0008956): colour tone, not line; turned,
  dissected viscera.
- Soemmerring's *Tabula sceleti feminini* (1796/97): a finer skeleton, but the Wellcome holds it as a
  book record with no digitised image, and Wikimedia Commons was refusing requests from this machine
  (HTTP 429) during the search; it has no matching surface figure either.
