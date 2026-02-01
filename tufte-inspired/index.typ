// Some definitions presupposed by pandoc's typst output.


#let blockquote(body) = [
  #set text( size: 0.8em )
  #align(right, block(inset: (right: 5em, top: 0.2em, bottom: 0.2em))[#body])
]

#let horizontalrule = [
  #line(start: (25%,0%), end: (75%,0%))
]

#let endnote(num, contents) = [
  #stack(dir: ltr, spacing: 3pt, super[#num], contents)
]

#show terms: it => {
  it.children
    .map(child => [
      #strong[#child.term]
      #block(inset: (left: 1.5em, top: -0.4em))[#child.description]
      ])
    .join()
}

// Some quarto-specific definitions.

#show raw.where(block: true): block.with(
    fill: luma(245),
    width: 100%,
    inset: 8pt,
    radius: 2pt
  )

#let block_with_new_content(old_block, new_content) = {
  let d = (:)
  let fields = old_block.fields()
  fields.remove("body")
  if fields.at("below", default: none) != none {
    // TODO: this is a hack because below is a "synthesized element"
    // according to the experts in the typst discord...
    fields.below = fields.below.amount
  }
  return block.with(..fields)(new_content)
}

#let empty(v) = {
  if type(v) == "string" {
    // two dollar signs here because we're technically inside
    // a Pandoc template :grimace:
    v.matches(regex("^\\s*$")).at(0, default: none) != none
  } else if type(v) == "content" {
    if v.at("text", default: none) != none {
      return empty(v.text)
    }
    for child in v.at("children", default: ()) {
      if not empty(child) {
        return false
      }
    }
    return true
  }

}

// Subfloats
// This is a technique that we adapted from https://github.com/tingerrr/subpar/
#let quartosubfloatcounter = counter("quartosubfloatcounter")

#let quarto_super(
  kind: str,
  caption: none,
  label: none,
  supplement: str,
  position: none,
  subrefnumbering: "1a",
  subcapnumbering: "(a)",
  body,
) = {
  context {
    let figcounter = counter(figure.where(kind: kind))
    let n-super = figcounter.get().first() + 1
    set figure.caption(position: position)
    [#figure(
      kind: kind,
      supplement: supplement,
      caption: caption,
      {
        show figure.where(kind: kind): set figure(numbering: _ => numbering(subrefnumbering, n-super, quartosubfloatcounter.get().first() + 1))
        show figure.where(kind: kind): set figure.caption(position: position)

        show figure: it => {
          let num = numbering(subcapnumbering, n-super, quartosubfloatcounter.get().first() + 1)
          show figure.caption: it => {
            num.slice(2) // I don't understand why the numbering contains output that it really shouldn't, but this fixes it shrug?
            [ ]
            it.body
          }

          quartosubfloatcounter.step()
          it
          counter(figure.where(kind: it.kind)).update(n => n - 1)
        }

        quartosubfloatcounter.update(0)
        body
      }
    )#label]
  }
}
// #show figure: it => {
//   let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
//   if kind_match == none {
//     return it
//   }
// }
// #show figure.where(kind: kind.matches(regex(""))): none
// callout rendering
// this is a figure show rule because callouts are crossreferenceable
#show figure: it => {
  set par(first-line-indent: 0em)

  if type(it.kind) != str {
    return it
  }
  let kind_match = it.kind.matches(regex("^quarto-callout-(.*)")).at(0, default: none)
  if kind_match == none {
    return it
  }
  let kind = kind_match.captures.at(0, default: "other")
  kind = upper(kind.first()) + kind.slice(1)
  // now we pull apart the callout and reassemble it with the crossref name and counter

  // when we cleanup pandoc's emitted code to avoid spaces this will have to change
  let old_callout = it.body.children.at(1).body.children.at(1)
  let old_title_block = old_callout.body.children.at(0)
  let old_title = old_title_block.body.body.children.at(2)

  // TODO use custom separator if available
  let new_title = if empty(old_title) {
    [#kind #it.counter.display()]
  } else {
    [#kind #it.counter.display(): #old_title]
  }

  let new_title_block = block_with_new_content(
    old_title_block,
    block_with_new_content(
      old_title_block.body,
      old_title_block.body.body.children.at(0) +
      old_title_block.body.body.children.at(1) +
      new_title))

  block_with_new_content(old_callout,
    new_title_block +
    old_callout.body.children.at(1))
}

// 2023-10-09: #fa-icon("fa-info") is not working, so we'll eval "#fa-info()" instead
#let callout(body: [], title: "Callout", background_color: luma(245), icon: none, icon_color: black) = {
  block(
    breakable: false,
    fill: background_color,
    stroke: (paint: icon_color, thickness: 0.5pt, cap: "round"),
    width: 100%,
    radius: 2pt,
    block(
      inset: 1pt,
      width: 100%,
      below: 0pt,
      block(
        fill: background_color,
        width: 100%,
        inset: 8pt)[#text(icon_color, weight: 900)[#icon] #title]) +
      if(body != []){
        block(
          inset: 1pt,
          width: 100%,
          block(fill: white, width: 100%, inset: 8pt, body))
      }
    )
}

#show figure: set text(size: 8pt)
#import "@preview/drafting:0.2.0": *
#import "@preview/marginalia:0.2.3" as marginalia: note, notefigure, wideblock

#let sidecite(key, mode, prefix, suffix, noteNum, hash) = context {
  if query(bibliography).len()>0 {
    let supplement = if suffix.split(",").filter(value => not value.contains("dy.")).join(",") == "" {
      none
    } else {
      suffix.split(",").filter(value => not value.contains("dy.")).join(",")
    }

    let filtered = suffix.split(",").filter(value => value.contains("dy.")).join(",")

    let dy = if filtered != none {
      eval(filtered.match(regex("(\d+)(pt|mm|cm|in|em)")).text)
    } else {
      0pt
    }

    // Show citation in main text for APA style, plus full citation in margin
    // APA uses parenthetical citations in text plus detailed info in margin

    // Show the normal citation in main text (parenthetical for APA)
    if supplement != none and supplement.len()>0 {
      cite(key, form: "normal", supplement: supplement)
    } else {
      cite(key, form: "normal")
    }

    // Also add full citation details in unnumbered sidenote
    marginalia.note(dy: dy, numbering: none)[
      #if supplement != none and supplement.len()>0 {
        cite(key, form:"full", supplement: supplement)
      } else {
        cite(key, form:"full")
      }]
  }
}


// Numbered sidenote function for footnotes - global scope
#let sidenote(content) = marginalia.note(
  numbering: (.., i) => super[#i],
  flush-numbering: true,
  anchor-numbering: (.., i) => super[#i],
)[#content]

#let marginnote(content) = marginalia.note(
  numbering: none,
)[#content]

// ───────────────────────────────────────────────────────────────
// TUFTE-STYLE MARGIN CAPTIONS & HELPERS
// ───────────────────────────────────────────────────────────────

#let marginaliasize = 12pt

// Custom counter for breakable code blocks - unified with figure counter
// #let codecounter = counter(figure.where(kind: raw))
#let codecounter = counter("code")  // or reuse your existing raw-figure counter

// Alignment offsets for main-width margin captions
// Account for default element padding to align with first line/row
#let table-caption-dy = 1.85em  //1.9em   // Tables have default spacing above

#let image-caption-dy = -0.25em   // Images minimal padding

#let code-caption-dy = 2.5em    //1.65em    // Code blocks have default padding

#let quote-caption-dy = 5.15em   // Block quotes have 2.4em default above spacing

// Optional: equation numbers in margin (default: false)
#let tufte_equation_numbers_in_margin = false

// Helper for breakable code blocks with captions (for fullwidth use)
// Usage: #codecaption([Caption text here], ```lang ... ```)
// #let codecaption(caption, body, dy: 1.2em) = {
//   codecounter.step()
//   context {
//     let code-num = codecounter.get().first()
//     // Place the body first, then the margin note positioned at the beginning
//     body
//     marginalia.note(numbering: none, dy: dy)[
//       #text(size: marginaliasize)[
//         #strong[Code #code-num.] #caption
//       ]
//     ]
//   }
// }

// Helper for quotes with margin attribution
// Usage: #marginquote([Quoted text...], source: [— Author, Work])
#let marginquote(body, source: none, dy: 0.25em) = {
  if source != none {
    marginalia.note(dy: dy)[#source]
  }
  quote[#body]
}

// Custom wideblock matching Tufte fullwidth calculation
// fullwidth = textwidth + marginparsep + marginparwidth
// For our dimensions: 107mm + 8.2mm + 49.4mm = 164.6mm
// Since marginalia uses 100% as textwidth, we add the margin space

#let wideblock(content, ..kwargs) = {
  // For fullwidth figures, detect and convert code figures to breakable format
  show figure.where(kind: raw): it => {
    // For fullwidth code blocks, extract caption and make breakable
    codecounter.step()
    context {
      let code-num = codecounter.get().first()
      // Render the raw code block directly (breakable)
      it.body
      // Add margin caption positioned relative to end of code block
      marginalia.note(numbering: none, dy: 1.2em)[
        #text()[
        // #text(size: marginaliasize)[
          #strong[Code #code-num.] #it.caption.body
        ]
      ]
    }
  }

  // For other fullwidth figures, captions should appear below as margin notes
  show figure.where(kind: table): it => {
    it.body
    v(1.5em) //v(1.0em)  // Increased space after tables

    marginalia.note(numbering: none)[
      #text()[
      // #text(size: marginaliasize)[
        #strong[Table #it.counter.display("I").] #it.caption.body
      ]
    ]
  }

  show figure.where(kind: image): it => {
    it.body
    v(1.5em)   // 0.75em Default spacing for images/other content
    marginalia.note(numbering: none)[
      #text()[
      // #text(size: marginaliasize)[
        #strong[Figure #it.counter.display("1").] #it.caption.body
      ]
    ]
  }

  show figure.where(kind: quote): it => {
    it.body
    v(1.5em)   // 0.75em Moderate space after quotes (they have 1.8em below padding)

    marginalia.note(numbering: none)[
      #text()[
      // #text(size: marginaliasize)[
        #strong[Quote #it.counter.display("1").] #it.caption.body
      ]
    ]
  }

  // Use marginalia's wideblock
  marginalia.wideblock(..kwargs)[#content]
}// Enhanced fullwidth environment that preserves margin note functionality
// This ensures sidenotes and marginnotes work correctly even in fullwidth content
#let fullwidth(content, ..kwargs) = {
  // Use marginalia's wideblock to ensure proper margin note positioning
  marginalia.wideblock(..kwargs)[#content]
}

// typst-template.typ
#let with-table-rows(n: int, body) = {
  set table(
    stroke: (_, y) => (
      top: if y == 0 { 1.2pt } else if y == 1 { 0.8pt } else { 0pt },
      bottom: if y == n - 1 { 1.2pt } else { 0pt }
    ),
    inset: (x: 5pt, y: 5pt),
  )
  body
}

// Fonts used in front matter, sidenotes, bibliography, and captions
#let sans-fonts = (
    "Calibri",
    "Arial",
  )

// Fonts used for headings and body copy
#let serif-fonts = (
  "Minion 3",
  "ETBembo",
  "Georgia",
  "Times New Roman",
)

// Monospaced fonts
#let mono-fonts = (
  "Consolas",
  "Courier New",
)// Math fonts
//#show math.equation: set text(font: "Euler Math")
//#show math.equation: set text(font: "TeX Gyre Pagella Math", number-type: "old-style")
#show math.equation: set text(number-type: "old-style")

// Global font settings
#show page: set text(font: serif-fonts)

// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++
// ++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++++

#let article(
  title: [Paper Title],
  shorttitle: none,
  subtitle: none,
  authors: none,
  product: none,
  date: none,
  dateformat: "[day].[month].[year]",
  paper: "us-letter",
  margin: none,
  headerascent: 30% + 0pt,
  lang: "en",
  region: "US",
  sectionnumbering: none,
  version: none,
  draft: false,
  distribution: none,
  abstract: none,
  abstracttitle: none,
  publisher: none,
  documenttype: none,
  toc: none,
  toc_title: none,
  bib: none,
  bibliography-title: "Referanser",
  bibliography-style: "springer-humanities-author-date",
  first-page-footer: none,
  book: false,
  // Font size parameters - user configurable with Tufte defaults
  base-fontsize: 12pt,          // \normalsize - body text (Tufte default)
  margin-fontsize: none,        // \footnotesize - sidenotes/captions (auto-calculated if none)
  small-fontsize: none,         // \small - abstract/quotes (auto-calculated if none)
  large-fontsize: none,         // \large - b-heads (auto-calculated if none)
  Large-fontsize: none,         // \Large - a-heads/author/date (auto-calculated if none)
  huge-fontsize: none,          // \huge - titles (auto-calculated if none)
  scriptsize-fontsize: none,    // \scriptsize - email addresses (auto-calculated if none)
  doc
) = {
  // Calculate font sizes - clean sizes for 12pt base, authentic Tufte for 10pt base, proportional for others
  let base-size = base-fontsize

  // For 12pt base, use clean rounded sizes; for 10pt use authentic Tufte; otherwise use proportional scaling
  let margin-size = if margin-fontsize == none {
    if base-size == 12pt { 10pt }
    else if base-size == 10pt { 8pt }  // Tufte sidenotes/captions
    else { base-size * 0.8 }
  } else { margin-fontsize }

  let small-size = if small-fontsize == none {
    if base-size == 12pt { 11pt }
    else if base-size == 10pt { 9pt }  // Tufte block quote
    else { base-size * 0.9 }
  } else { small-fontsize }

  let large-size = if large-fontsize == none {
    if base-size == 12pt { 13pt }
    else if base-size == 10pt { 11pt }  // Tufte subsection (B-heads)
    else { base-size * 1.1 }
  } else { large-fontsize }

  let Large-size = if Large-fontsize == none {
    if base-size == 12pt { 14pt }
    else if base-size == 10pt { 12pt }  // Tufte section (A-heads)
    else { base-size * 1.2 }
  } else { Large-fontsize }

  let huge-size = if huge-fontsize == none {
    if base-size == 12pt { 20pt }
    else if base-size == 10pt { 20pt }  // Tufte chapter
    else { base-size * 1.67 }
  } else { huge-fontsize }

  let script-size = if scriptsize-fontsize == none {
    if base-size == 12pt { 8pt }
    else if base-size == 10pt { 7pt }  // Smaller than sidenotes for email addresses
    else { base-size * 0.7 }
  } else { scriptsize-fontsize }
  // Configure marginalia based on book vs article mode using Tufte LaTeX dimensions
  let config = if book {
    // Book mode: alternating margins, preserving ~107mm text width
    (
      inner: (far: 21mm, width: 49mm, sep: 8mm),   // Left margin: 78mm
      outer: (far: 21mm, width: 49mm, sep: 8mm),   // Right margin: 78mm
      top: 27mm,
      bottom: 20mm,
      book: true,
    )
  } else {
    // Article mode: Tufte dimensions, all notes on right side
    (
      inner: (far: 25mm, width: 0mm, sep: 0mm),    // Left margin: 25mm (matches Tufte's 24.8mm)
      outer: (far: 21mm, width: 49mm, sep: 8mm),   // Right margin: 78mm (21+49+8, for notes)
      top: 27mm,
      bottom: 20mm,
      book: false,
    )
  }
  // Setup marginalia package - this automatically handles page margins!
  show: marginalia.setup.with(..config)
  show: marginalia.show-frame.with(stroke: 1pt + red)

  let header-ascent = if paper == "a4" {
    50% + 0pt
  } else {
    headerascent
  }

  let page_width = if paper == "a4" {
    210mm
  } else {
    8.5in
  }

  // Use marginalia wideblock directly for proper table handling
  // let wideblock(content) = block(width: 100% + margin.right - rightpadding, content)

  // Convert footnotes to numbered sidenotes using marginalia
  show footnote: it => marginalia.note(
    numbering: "1",
    text-style: (size: margin-size, font: serif-fonts)
  )[#it.body]

  let header-ascent = if paper == "a4" {
    50% + 0pt
  } else {
    headerascent
  }

  // Page setup

  // From https://github.com/gnishihara/quarto-appendix/blob/main/_extensions/appendix/typst-template.typ
  // Allow custom title for bibliography section
  //set bibliography(title: bibliography-title, style: bibliography-style)
  set bibliography(title: none, style: bibliography-style)


  // Just a subtle lightness to decrease the harsh contrast
  set text(
    fill: luma(30),
    lang: lang,
    region: region,
    historical-ligatures: true,
    number-type: "old-style",
  )

  let lr(l, r, ..kwargs) = wideblock( ..kwargs,
    grid(columns: (1fr, 4fr), align(left, text(size: margin-size, l)), align(right, text(size: small-size, r)))  // \footnotesize, \small
  )

  set par(justify: true)
  set page(
    paper: paper,
    header: context {
      if counter(page).get().first() > 1 {
        set text(font: serif-fonts, tracking: 1.5pt, size: small-size)
        wideblock(
          align(right)[
            #if shorttitle != none {
              smallcaps(lower(shorttitle))
            } else {
             smallcaps(lower(title))
            }
            #h(1em)
            #counter(page).display()
          ]
        )
      }
    },
    header-ascent: header-ascent,
    footer: context {
      if counter(page).get().first() < 2 {
        if first-page-footer !=none {first-page-footer}
      }
    },
  )

  //set-page-properties()

 // set-margin-note-defaults(
 //   stroke: none,
 //   side: right,
  //  page-width: page_width - margin.right - .5in - 1em,
  //  margin-right: margin.right - margin.left
  //)
  set par(leading: .75em, justify: true, linebreaks: "optimized", first-line-indent: 1em, spacing: 0.65em)
  // Modern Typst syntax - paragraphs are no longer blocks

  // Frontmatter

  let authorblock() = [
    #set text(font: serif-fonts, size: Large-size, style: "italic")  // \Large - author
    #set par(first-line-indent: 0em)
    #for (author) in authors [
      #author.name
      #linebreak()
      #if author.email != none [#text(size: script-size, font: mono-fonts, link("mailto:" + author.email.replace("\\@", "@")))]  // \scriptsize
      //#if author.email != none [#text(size: 7pt, font: mono-fonts, [#author.email])]
      #linebreak()
    ]

    #if date != none {
      if date.contains(".") {
        let (day, month, year) = date.split(".")
        let date_obj = datetime(year: int(year), month: int(month), day: int(day))
        [#date_obj.display(dateformat)]
      } else {
        let (year, month, day) = date.split("-")
        let date_obj = datetime(year: int(year), month: int(month), day: int(day))
        [#date_obj.display(dateformat)]
      }
    }
  ]

  //title block
  wideblock({
    set par(first-line-indent: 0pt)
    v(-.5cm)
    text(font: sans-fonts, number-type: "lining", tracking: 1.5pt, fill: gray.lighten(60%), upper(documenttype))
    v(.1cm)//v(.5cm)
    text(font: serif-fonts, style: "italic", size: huge-size, hyphenate: false, weight: "regular", title)  // \huge - chapter heads
    linebreak()
    text(font: serif-fonts, style: "italic", size: Large-size, stretch: 80%, weight: "regular", hyphenate: true, subtitle)  // \Large
    linebreak()
    if version != none {text(font: sans-fonts, size: margin-size, style: "normal", fill: gray)[#version]} else []  // \footnotesize
    if authors != none {authorblock()}
  })

  // Abstract outside of wideblock for proper quotation-style indentation
  if abstract != none {
    // Quotation-style indent like Tufte LaTeX (1pc = 12pt each side)
    block(inset: (left: 12pt, right: 12pt, top: 0.5em, bottom: 0.5em))[#text(font: serif-fonts, size: small-size)[#abstract]]  // \small - quote environment
    v(1.5em)  // Reduced spacing after abstract
  } else {v(3em)}

  //TOC
  let tocblock() = context {
    //set par(first-line-indent: 0pt)
    // Create inline-compatible content following marginalia documentation pattern
    [
      #text(font: serif-fonts, size: large-size, weight: "regular", style: "italic")[#toc_title]  // \Large - toc entries
      #linebreak()
      #linebreak()
      #text(font: serif-fonts, size: margin-size, weight: "regular", style: "italic")[  // \large
        #outline(
          title: none,
          depth: 1,
          indent: 1em,
        )
      ]
    ]
  }

  if toc !=none [#marginalia.note(numbering: none, dy: 0.45em)[#tocblock()]]//[#margin-note(dx: 0em, dy: -1em)[#tocblock()]]


  // Headings - Authentic Tufte hierarchy
  set heading(
    numbering: sectionnumbering
  )
  show heading.where(level:1): it => {
    v(2em, weak: true)
    text(size: Large-size, weight: "regular", style: "italic", it)
    v(1em, weak: true)
  }

  show heading.where(level:2): it => {
    v(1.3em, weak: true)
    text(size: large-size, weight: "regular", style: "italic", it)
    v(1em, weak: true)
  }

  show heading.where(level:3): it => {
    v(1em, weak:true)
    text(size: small-size, style:"italic", weight: "regular", it)
    v(0.65em, weak:true)
  }

  show heading: it => {
    if it.level <= 3 {it} else {}
  }

  // TODO: Handle Quarto appendices.


  // Tables and figures
  // Clean Tufte table styling - booktabs with dynamic bottom rules
  show table.cell.where(y: 0): strong  // Bold headers

  show figure: set figure.caption(separator: [.#h(0.5em)])
  show figure.caption: set align(left)
  show figure.caption: set text(font: serif-fonts)

  // show figure.where(kind: table): set figure(numbering: "I")
  show figure.where(kind: image): set figure(supplement: [Figure], numbering: "1")
  // show figure.where(kind: raw): set figure(supplement: [Code], numbering: "1")
  show figure.where(kind: quote): set figure(supplement: [Quote], numbering: "1")

  // Tufte-style margin captions for main-width content
  // Fullwidth content is handled by the wideblock show rule
  show figure.where(kind: table): it => {
    // Main width: margin caption aligned with content
    let margin-caption = marginalia.note(numbering: none, dy: table-caption-dy)[
      #text(size: margin-size)[
        #strong[Table #it.counter.display("1").] #it.caption.body
      ]
    ]
    [#margin-caption#it.body]
  }

  show figure.where(kind: image): it => {
    let margin-caption = marginalia.note(numbering: none, dy: image-caption-dy)[
      #text(size: margin-size)[
        #strong[Figure #it.counter.display("1").] #it.caption.body
      ]
    ]
    [#margin-caption#it.body]
  }

  show figure.where(kind: raw): it => {
    let margin-caption = marginalia.note(numbering: none, dy: code-caption-dy)[
      #text(size: margin-size)[
        #strong[Code #it.counter.display("1").] #it.caption.body
      ]
    ]
    [#margin-caption#it.body]
  }

  show figure.where(kind: quote): it => {
    let margin-caption = marginalia.note(numbering: none, dy: quote-caption-dy)[
      #text(size: margin-size)[
        #strong[Quote #it.counter.display("1").] #it.caption.body
      ]
    ]
    [#margin-caption#it.body]
  }

  show raw: set text(font: mono-fonts, size: margin-size, historical-ligatures: false)  // \footnotesize


  // Equations - Standard numbering (for margin numbering, see commented code below)
  set math.equation(numbering: (..n) => {
    text(font: serif-fonts, numbering("(1)", ..n))
  })
  show math.equation: set block(spacing: 0.65em)

  // For equation numbers in margin, uncomment and replace the above with:
  // set math.equation(numbering: none)
  // let eq_dy = 0.15em
  // show math.equation: it => {
  //   marginalia.note(numbered: none, dy: eq_dy)[
  //     #strong[Eq.] #it.counter.display((n) => numbering("(1)", n))
  //   ]
  //   it
  // }

  //show link: underline

  // Lists
  set enum(
    indent: 1em,
    body-indent: 1em,
  )
  show enum: set par(justify: false)
  set list(
    indent: 1em,
    body-indent: 1em,
  )
  show list: set par(justify: false)

  // Tufte-style quotes with margin attributions
  show quote: it => {
    set text(size: small-size, style: "italic")
    set par(leading: 0.6em)
    block(
      inset: (left: 1.2em, right: 1.2em, top: 0.8em, bottom: 0.8em),
      it
    )
  }


  // Body text
  set text(
    font: serif-fonts,
    style: "normal",
    weight: "regular",
    hyphenate: true,
    size: base-size  // User-configurable base font size
  )

  show cite.where(form: "prose"): none

  //set text(size: 12pt)
  v(-.5in)
  doc

  //if bib != none {
  //  heading(level:1,[References])
  //  bib
  //}
}

#show: doc => article(
  title: [A Tufte Inspired Manuscript],
    subtitle: [Using Quarto… and Typst!],
  
  authors: (
                    (
          name: [Eirik Tengesdal],
          affiliation: [],
          location: [],
          role: [],
          email: "eirik.tengesdal\@oslomet.no"
          ),
            ),
  date: "2026-01-21",
  lang: "en",
  region: "GB",
  abstract: [This #strong[Tufte Inspired] manuscript format for Quarto honors Edward Tufte's distinctive style. It simplifies creating handout-like documents and websites by emulating the aesthetics of Tufte's books. This document serves two purposes: It showcases the format and acts as an evolving authoring guide.

],
  abstracttitle: "Abstract",
  paper: "a4",
  sectionnumbering: "1.1.1",
  toc: true,
  version: [v.1.0],
  bibliography-style: "springer-humanities-author-date",
publisher: "Publisher",
documenttype: [Handout],
  toc_title: [Table of contents],
// //   toc_depth: 3,
  // cols: 1,
  doc,
)

= Introduction
<introduction>
#figure([
#box(image("Images/et_midjourney_transparent.png", width: 75.0%))
], caption: figure.caption(
position: bottom, 
[
Edward R. Tufte, godfather of charts, slayer of slide decks. Art by Fred Guth and MidJourney.
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)
<fig-tufte>


Professor Emeritus of Political Science, Statistics and Computer Sciente at Yale University, Edward Tufte is an expert in the presentation of informational. #ref(<fig-tufte>, supplement: [Figure]).

Tufte's style is known for extensive use of sidenotes, integration of graphics with text and typography#sidenote[Tufte’s website: https://www.edwardtufte.com/tufte/].

Below we illustrate some of the key features of the Tufte-inspired format. Firstly, we demonstrate the use of fullwidth figures by placing it in a `::: fullwidth [...] :::` block. As can be seen in the example below, spans the full width of the page.

Note the use of the `fig-cap` chunk option to provide a figure caption. You can adjust the proportions of figures using the `fig-width` and `fig-height` chunk options. These are specified in inches, and will be automatically scaled down to fit within the handout margin.

= Usage
<usage>
== Arbitrary Margin Content
<arbitrary-margin-content>
You can include anything in the margin by places the class `.column-margin` on the element. See an example on the right about the first fundamental theorem of calculus.

== Arbitrary Full Width Content
<arbitrary-full-width-content>
Any content can span to the full width of the page, simply place the element in a `div` and add the class `.column-page-right`. For example, the following code will display its contents as full width.

#block(width: 100%+75.2mm)[
```md
::: {.column-page-right}
Any _full width_ content here.
:::
```

]
Now I will also test the footnotes.#sidenote[Test footnote.] Now we continue.

New paragraph here.

Test3.

This is a text with a sidenote.#sidenote[This is a sidenote without offset.]

This is another text with a conditional sidenote with offset. Test.

#block(width: 100%+75.2mm)[
#figure([
#box(image("Images/Minard.png"))
], caption: figure.caption(
position: bottom, 
[
Minard's map of Napoleon's Russian campaign, described by Edward Tufte as "may well be the best statistical graphic ever drawn".
]), 
kind: "quarto-float-fig", 
supplement: "Figure", 
)


]
#block[
#heading(
level: 
1
, 
outlined: 
false
, 
[
Acknowledgements
]
)
]
Thanks to the Quarto and Typst teams for these wonderful tools. This format is made possible by #link("https://github.com/quarto-dev/quarto-cli/discussions?discussions_q=author%3Afredguth")[Quarto's] and #link("https://discord.gg/2uDybryKPe")[Typst's] communities. Special thanks to:

- Mickaël Canouil (`@mcanouil`);
- Gordon Woodhull (`@gordonwoodhull`);
- Charles Teague (`@dragonstyle`);
- Raniere Silva (`@rgaiacs`); and
- Christophe Dervieux (`@cderv`)
- `@pgsuper`

#block[
#heading(
level: 
1
, 
numbering: 
none
, 
[
References
]
)
]


 

#set bibliography(style: "springer-humanities-author-date")


#bibliography("references.bib")

