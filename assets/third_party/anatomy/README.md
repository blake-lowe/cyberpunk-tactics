# Anatomical plates (Milton, Rees's Cyclopaedia): source and licence

`anatomy_ink.png` is two engraved anatomical plates lifted off photographs of the prints, for the
cyberware screens' default body style, "anatomy" (`ChromeBody`, `src/ui/screens/body_anatomy.gd`).

| | |
|---|---|
| Main plate | *A standing male écorché figure: front view.* Line engraving by Thomas Milton (1743-1827), "Anatomy, Myology, Plate VIII", published London: Longman, Hurst, Rees & Orme, 1 May 1804 (Rees's *Cyclopaedia*). Wellcome Collection 583178i (miro image V0008060FA). |
| Deep plate | *A standing male écorché figure: front view, showing the skeleton and muscles.* Line engraving by Thomas Milton, "Anatomy, Myology, Plate X", published London: Longman, Hurst, Rees & Orme, 1 June 1803. Wellcome Collection 583179i (miro image V0008060EB). |
| Source | Wellcome Collection: [works/yfpteejr](https://wellcomecollection.org/works/yfpteejr) and [works/aspbvkwm](https://wellcomecollection.org/works/aspbvkwm); full-size images from the IIIF server, `https://iiif.wellcomecollection.org/image/V0008060FA/full/full/0/default.jpg` (2370 x 3078) and `.../V0008060EB/full/full/0/default.jpg` (2320 x 3129). |
| Licence | **Public domain.** The Wellcome Collection's catalogue API gives both images the licence `pdm`, "Public Domain Mark" (https://creativecommons.org/share-your-work/public-domain/pdm/), access "Open". The engraver died in 1827 and the prints were published in 1803 and 1804. Credit (courtesy, not required): Wellcome Collection. |
| Checked | 2026-11-11, from the Wellcome Collection catalogue API (`/catalogue/v2/images/rv6fhfmw` and `/images/f479t7jz`: `locations[0].license`) |

What was done to them (`tools/gen_anatomy_ink.py`, which documents the steps and rebuilds the file):
the engraved line separated from the paper (its grain, the foxing and a later owner's blue pencil
notes dropped), the figure's silhouette found and everything outside it cut away (the title, plate
number and imprint lines), and the plate printed in reverse as light (the paper inside the figure
light, the engraved lines dark). The deep plate was warped onto the main plate's pose through
hand-placed landmark pairs (the same man a year apart, standing a little wider). Nothing is traced
or added: the anatomy is Milton's.

Channels: R the main plate as light, G its silhouette, B the deep plate as light (warped), A the
outline. Import it with `process/fix_alpha_border=false` (every channel is data).

Considered and not used: Julien Bouglé's colour muscle figure (Wikimedia Commons, "Bougle whole2
retouched.png", 1899; public domain), a fine plate but colour lithograph tones extract poorly as
line, and Commons was refusing full-size downloads from this machine; Paul Richer's *Anatomie
artistique* (1890; Commons), whose plates are regional and lettered rather than a whole figure.
