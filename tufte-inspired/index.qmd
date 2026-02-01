---
title: "A Tufte Inspired Manuscript"
subtitle: "Using Quarto... and Typst!"
#shorttitle: "Handout Layout"
documenttype: Handout
#lang: nb-NO
#language: custom.yml
abstract: |
  This **Tufte Inspired** manuscript format for Quarto honors Edward Tufte's distinctive style. It simplifies creating handout-like documents and websites by emulating the aesthetics of Tufte's books. This document serves two purposes: It showcases the format and acts as an evolving authoring guide.

author:
  - name: "Eirik Tengesdal"
    id: ET
    orcid: 0000-0003-0599-8925
    email: "eirik.tengesdal@oslomet.no"
toc: true

version: [v.1.0]
date: last-modified
execute:
  keep-md: true
  keep-typ: true
bibliography: references.bib
bibliographystyle: "springer-humanities-author-date"
---

# Introduction

::: {.column-margin dy=-11cm}
![Edward R. Tufte, godfather of charts, slayer of slide decks. Art by Fred Guth and MidJourney.](Images/et_midjourney_transparent.png){width=75% #fig-tufte}
:::

Professor Emeritus of Political Science, Statistics and Computer Sciente at Yale University, Edward Tufte is an expert in the presentation of informational. @fig-tufte.

Tufte's style is known for extensive use of sidenotes, integration of graphics with text and typography[^2].

[^2]: Tufte's [website](https://www.edwardtufte.com/tufte/): <https://www.edwardtufte.com/tufte/>

Below we illustrate some of the key features of the Tufte-inspired format. Firstly, we demonstrate the use of fullwidth figures by placing it in a `::: fullwidth [...] :::` block. As can be seen in the example below,  spans the full width of the page.

<!--
::: fullwidth
![Minard's map of Napoleon's Russian campaign, described by Edward Tufte as "may well be the best statistical graphic ever drawn"](Images/Minard.png){#fig-minard}
:::
-->

Note the use of the `fig-cap` chunk option to provide a figure caption. You can adjust the proportions of figures using the `fig-width` and `fig-height` chunk options. These are specified in inches, and will be automatically scaled down to fit within the handout margin.

# Usage

## Arbitrary Margin Content

You can include anything in the margin by places the class `.column-margin` on the element. See an example on the right about the first fundamental theorem of calculus.


## Arbitrary Full Width Content

Any content can span to the full width of the page, simply place the element in a `div` and add the class `.column-page-right`. For example, the following code will display its contents as full width.

::: column-page-right
``` md
::: {.column-page-right}
Any _full width_ content here.
:::
```
:::

Now I will also test the footnotes.[^3] Now we continue.

[^3]: Test footnote.

New paragraph here.

Test3.

This is a text with a sidenote.[^4]

[^4]: This is a sidenote without offset.

This is another text with a conditional sidenote with offset. Test.

::: column-page-right
![Minard's map of Napoleon's Russian campaign, described by Edward Tufte as "may well be the best statistical graphic ever drawn".](Images/Minard.png)
:::

# Acknowledgements {.unlisted}

Thanks to the Quarto and Typst teams for these wonderful tools.  This format is made possible by [Quarto's](https://github.com/quarto-dev/quarto-cli/discussions?discussions_q=author%3Afredguth) and [Typst's](https://discord.gg/2uDybryKPe) communities. Special thanks to:

- Mickaël Canouil (`@mcanouil`);
- Gordon Woodhull (`@gordonwoodhull`);
- Charles Teague (`@dragonstyle`);
- Raniere Silva (`@rgaiacs`); and
- Christophe Dervieux (`@cderv`)
- `@pgsuper`

# References {.unnumbered}

::: {#refs .content-visible when-format="html"}
:::
