# Vitruvian Man: source and licence

`vitruvian_ink.png` is the ink of Leonardo da Vinci's *Vitruvian Man* (pen, ink and wash on paper,
c. 1490; Gallerie dell'Accademia, Venice) lifted off a photograph of the sheet, for the cyberware
screens' "vitruvian" body style (`ChromeBody`, `src/ui/screens/body_vitruvian.gd`).

| | |
|---|---|
| Work | Leonardo da Vinci (1452-1519), *Vitruvian Man*, c. 1490 |
| Photograph used | Wikimedia Commons, [File:Da Vinci Vitruve Luc Viatour.jpg](https://commons.wikimedia.org/wiki/File:Da_Vinci_Vitruve_Luc_Viatour.jpg), its 1920 px rendition |
| Licence | **Public domain.** Commons tags the file `PD-Art` (a faithful photographic reproduction of a two-dimensional public-domain work) with `PD-old` (the author died over 100 years ago); its licence field reads "Public domain", "Copyrighted: False", "Attribution required: false". The file page notes: "this is in the public domain, despite the photographer's contradictory claim. Any use is permissible, and no credit to the photographer is necessary." Photograph credit (courtesy, not required): Luc Viatour, www.lucnix.be. |
| Checked | 2026-11-11, from the Commons API (`extmetadata`) and the file page's wikitext |

What was done to it (`tools/gen_vitruvian_ink.py`, which documents the steps and rebuilds it): the ink
separated from the paper, lone specks dropped, the ink's density kept as alpha (so the hatching and wash
keep their tone), the drawn circle and square erased (the game redraws them), and everything outside
the circle (the mirror-writing) cut away. Nothing else is traced or added: the figure's line work is
Leonardo's.

Not used: Commons' vector redrawing "Da Vinci Vitruve Luc Viatour 2.svg" (also tagged public domain).
It is a loose redrawing (different face and proportions), and a fresh trace of the original needed no
licence judgement about a third party's redrawing.
