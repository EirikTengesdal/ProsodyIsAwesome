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
#import "@preview/marginalia:0.3.1" as marginalia: note, notefigure, wideblock
#import "@preview/codly:1.3.0": *
#import "@preview/codly-languages:0.1.1": *

// Custom state to track if we're in outline mode
#let in-outline = state("in-outline", false)

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

    // Map Pandoc citation modes to Typst citation forms
    // Pandoc: @author → mode: "AuthorInText" → Typst: form: "prose" → "Author (year)"
    // Pandoc: [@author] → mode: "NormalCitation" → Typst: form: "normal" → "(Author, year)"
    // Pandoc: [-@author] → mode: "SuppressAuthor" → Typst: form: "year" → "(year)"
    let cite-form = if mode == "AuthorInText" {
      "prose"
    } else if mode == "SuppressAuthor" {
      "year"
    } else {
      "normal"
    }

    // Show citation in margin note text
    if supplement != none and supplement.len()>0 {
      cite(key, form: cite-form, supplement: supplement)
    } else {
      cite(key, form: cite-form)
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

// Citation function for use INSIDE margin notes
// Shows inline citation, then full details below in separate margin note
#let margincite(key, mode, prefix, suffix, noteNum, hash) = context {
  if query(bibliography).len()>0 {
    let supplement = if suffix.split(",").filter(value => not value.contains("dy.")).join(",") == "" {
      none
    } else {
      suffix.split(",").filter(value => not value.contains("dy.")).join(",")
    }

    // For citations inside margins, just show the citation inline
    if supplement != none and supplement.len()>0 {
      cite(key, form: "normal", supplement: supplement)
    } else {
      cite(key, form: "normal")
    }

    // Add full citation below as separate margin note
    linebreak()
    marginalia.note(dy: 0em, numbering: none)[
      #cite(key, form:"full")
    ]
  }
}


// Numbered sidenote function for footnotes - accepts all marginalia parameters
#let sidenote(..args, content) = {
  // Extract named arguments, providing defaults for numbered sidenotes
  let defaults = (
    numbering: (.., i) => super[#i],
    flush-numbering: true,
    anchor-numbering: (.., i) => super[#i],
  )

  // Merge user args with defaults
  marginalia.note(..defaults, ..args.named())[#content]
}

// Unnumbered margin note function for .column-margin divs - accepts all marginalia parameters
#let marginnote(..args, content) = {
  // Default to no numbering
  let defaults = (
    numbering: none,
  )

  // Merge user args with defaults
  marginalia.note(..defaults, ..args.named())[#content]
}

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

#let wideblock(content, table-size: 10pt, columns: none, ..kwargs) = {
  // Apply table customizations with automatic column conversion
  show table: it => {
    set text(size: table-size)

    // Convert table columns from percentages/auto to fractional units
    // This ensures tables use 100% of wideblock width
    let new-table = it

    if it.columns != none and type(it.columns) == array {
      // Analyze column specifications
      let has-percent = false
      let has-auto = false
      let total-percent = 0%
      let auto-count = 0

      for col in it.columns {
        if type(col) == relative {
          has-percent = true
          total-percent = total-percent + col
        } else if col == auto {
          has-auto = true
          auto-count = auto-count + 1
        }
      }

      // If we have mix of percentages and auto, convert to fractional units
      if has-percent and has-auto {
        let remaining = 100% - total-percent
        let auto-fraction = if auto-count > 0 { remaining / auto-count } else { 0% }

        // Build new column spec with fractional units
        let new-cols = ()
        for col in it.columns {
          if type(col) == relative {
            // Convert percentage to fraction: 25% -> 25fr
            let pct-value = col / 1%  // Get numeric value (25% -> 25)
            new-cols.push(pct-value * 1fr)
          } else if col == auto {
            // Convert auto to calculated fraction
            let pct-value = auto-fraction / 1%
            new-cols.push(pct-value * 1fr)
          } else {
            new-cols.push(col)
          }
        }

        // Recreate table with converted columns and force full width
        table(
          columns: new-cols,
          ..it.fields().pairs().filter(p => p.at(0) != "columns" and p.at(0) != "children").fold((:), (dict, p) => {
            dict.insert(p.at(0), p.at(1))
            dict
          }),
          ..it.children
        )
      } else {
        // No conversion needed, just wrap in block
        block(width: 100%, breakable: false, it)
      }
    } else {
      // Make tables non-breakable
      block(breakable: false, it)
    }
  }

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
  toc_depth: 1,
  bib: none,
  show-bibliography: false,        // Hide bibliography by default (Tufte style uses sidecite only)
  bibliography-title: "Referanser",
  bibliography-style: "springer-humanities-author-date",
  first-page-footer: none,
  book: false,
  show-layout-frame: false,
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
  
  // Conditionally show layout frame for debugging (must be after setup):
  show: doc => {
    if show-layout-frame {
      marginalia.show-frame(stroke: 1pt + red, doc)
    } else {
      doc
    }
  }

  // Tufte-compatible color for links and code
  let tufte-link-color = rgb(0, 51, 102)  // Professional dark blue

  // Enable PowerShell syntax highlighting
  set raw(syntaxes: "_extensions/EirikTengesdal/tufte-inspired/PowerShell.sublime-syntax")

  // Initialize codly for beautiful code blocks with line numbers
  show: codly-init.with()

  // Configure codly - override 'r' mapping with proper R definition using local SVG icon
  // Icon formatting matches codly-languages __icon() helper function
  codly(
    languages: (
      ..codly-languages,
      r: (
        name: "R",
        color: rgb("#276dc3"),
        icon: box(
          image("_extensions/EirikTengesdal/tufte-inspired/r.svg", height: 0.9em),
          baseline: 0.05em,
          inset: 0pt,
          outset: 0pt,
        ) + h(0.3em)
      ),
    ),
    zebra-fill: luma(245),           // Light gray for alternating rows
    stroke: 0.5pt + luma(200),       // Subtle border
    number-format: n => text(fill: gray, size: 0.8em)[#n],  // Match code text size
    display-icon: true,              // Show language icons
    display-name: true,              // Show language names
    breakable: false,                // Keep code blocks together (h3 setting will keep them with headings)
  )

  // Style links with monospace font and Tufte color
  show link: it => text(
    font: mono-fonts,
    size: 0.8em,
    fill: tufte-link-color,
    it
  )

  // Apply same styling to inline code (background color matching code blocks, with Tufte color)
  show raw.where(block: false): it => box(
    fill: luma(245),
    inset: (x: 3pt, y: 0pt),
    outset: (y: 3pt),
    radius: 2pt,
    text(size: 0.8em, fill: tufte-link-color, it)  // Tufte color for inline code
  )

  // Keep headings together with following content (e.g., code blocks)
  // This prevents page breaks between headings and their code
  // h1 and h2: Breakable by default (allows page breaks after section headings)
  // h3 and h4: Non-breakable (keeps subsection headings with their content)
  // Users can override by adding {.keep-with-heading} class to code blocks in QMD

  show heading.where(level: 3): it => {
    block(breakable: false)[
      #it
      #v(0.65em, weak: true)
    ]
  }

  show heading.where(level: 4): it => {
    block(breakable: false)[
      #it
      #v(0.65em, weak: true)
    ]
  }

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

  // Hide bibliography (Tufte style uses sidecite in margin, not end-of-document list)
  show bibliography: none

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

  // ORCID icon helper function
  let orcid(height: 10pt, o) = [
    #box(height: height, baseline: 10%, link("https://orcid.org/" + o)[#image("_extensions/EirikTengesdal/tufte-inspired/orcid.svg")])
  ]

  let authorblock() = [
    #set text(font: serif-fonts, size: Large-size, style: "italic")  // \Large - author
    #set par(first-line-indent: 0em)
    #for (author) in authors [
      #author.name
      #if author.at("orcid", default: none) != none [ #orcid(author.at("orcid"))]
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

  // === MARGINALIA SETUP ===
  // State to control margin note visibility (for hiding in outline)
  let hide-marginalia-in-outline = state("hide-marginalia-in-outline", false)

  // Show rule to hide marginalia raw inlines when state is true
  show raw.where(block: false): it => context {
    if hide-marginalia-in-outline.get() {
      // Check if this raw inline contains marginalia
      let text-repr = repr(it.text)
      if text-repr.contains("marginalia") {
        // Hide margin notes in outline
        none
      } else {
        // Keep other raw inlines (code, etc.)
        it
      }
    } else {
      // Normal rendering - show everything
      it
    }
  }

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
        // Hide margin notes in outline using state toggle
        // Based on: https://sitandr.github.io/typst-examples-book/book/snippets/chapters/outlines.html#ignore-citations-and-footnotes
        #context {
          hide-marginalia-in-outline.update(true)
          outline(
            title: none,
            depth: toc_depth,
            indent: 1em,
          )
          hide-marginalia-in-outline.update(false)
        }
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

  //set text(size: 12pt)
  v(-.5in)
  doc

  //if bib != none {
  //  heading(level:1,[References])
  //  bib
  //}
}

#show: doc => article(
  title: [Wavelet Prosody Toolkit],
      subtitle: [Installation Guide],
  
  authors: (
                    (
          name: [Eirik Tengesdal],
          affiliation: [Oslo Metropolitan University, University of Oslo],
          location: [],
          role: [],
          email: "eirik.tengesdal\@oslomet.no",
          orcid: "0000-0003-0599-8925"
          ),
            ),
  date: "2026-02-01",
  lang: "nb",
  region: "NO",
  abstract: [This guide provides #strong[cross-platform installation instructions] for the #emph[Wavelet Prosody Toolkit] on Windows, macOS, and Linux. Two installation methods are provided: a global user-level installation for general use across multiple projects, and a per-project installation with isolated dependencies for reproducible research environments.

],
  abstracttitle: "Sammendrag",
  paper: "a4",
  sectionnumbering: "1.1.1",
  toc: true,
publisher: "Publisher",
documenttype: "",
  toc_title: [Innholdsfortegnelse],
  toc_depth: 1,
  show-layout-frame: true,
  doc,
)

= Introduction
<introduction>
The #link("https://github.com/asuni/wavelet_prosody_toolkit")[Wavelet Prosody Toolkit] is a powerful tool for analysing prosodic features in speech. This guide helps you install it on Windows, macOS, or Linux, but no guarantees are made. It describes files that are included in the installation package, pertaining to two installation methods: a global user-level installation and a per-project installation.

You can download the installation scripts from here: #link("...")[…];.

== Support
<support>
For installation issues, please email Eirik Tengesdal at #link("mailto:eirik.tengesdal@oslomet.no")[eirik.tengesdal\@oslomet.no];.

#[#{
  show heading: none
  heading(level: 1, outlined: true)[Which Installation Method?]
  counter(heading).update((..nums) => {
    let arr = nums.pos()
    arr.slice(0, -1) + (arr.last() - 1,)
  })
}#heading(level: 1, outlined: false)[Which Installation Method?#sidenote()[For most users, the *global installation* is simpler and more convenient. Use per-project only when you need strict dependency isolation.] <which-installation-method1>]]
== Global Installation (recommended):
<global-installation-recommended>
- Windows: #raw(lang:"powershell", "install_toolkit_standalone.ps1")
- macOS/Linux: #raw(lang:"bash", "install_toolkit_standalone.sh")
- Use across multiple projects without reinstalling

== Per-Project Installation:
<per-project-installation>
- Windows: #raw(lang:"powershell", "install_toolkit_project.ps1")
- macOS/Linux: #raw(lang:"bash", "install_toolkit_project.sh")
- Isolated dependencies and strict reproducibility

= Option 1: Global User-Level Installation
<option-1-global-user-level-installation>
This installs the toolkit once to your user Python environment, making it available from any directory.#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
Default Locations:Windows: %USERPROFILE%\wavelet_prosody_toolkitmacOS/Linux: ~/wavelet_prosody_toolkit]

== Installation
<installation>
=== Windows (PowerShell)
<windows-powershell>
#wideblock[
```powershell
# Navigate to where you downloaded the script
cd path\to\scripts

# Install to default location
.\install_toolkit_standalone.ps1

# OR install to custom location
.\install_toolkit_standalone.ps1 -InstallDir "C:\Tools\wavelet_prosody_toolkit"
```

]
=== macOS/Linux (Bash)
<macoslinux-bash>
#wideblock[
```bash
# Make script executable
chmod +x install_toolkit_standalone.sh

# Install to default location
./install_toolkit_standalone.sh

# OR install to custom location
./install_toolkit_standalone.sh /path/to/your/preferred/location
```

]
== Usage
<usage>
After installation, you can use the toolkit from #strong[any directory];:

=== Windows
<windows>
```powershell
# Launch the GUI
python -m wavelet_prosody_toolkit.wavelet_gui

# Or use in your Python scripts
python your_analysis_script.py
```

=== macOS/Linux
<macoslinux>
```bash
# Launch the GUI
python3 -m wavelet_prosody_toolkit.wavelet_gui

# Or use in your Python scripts
python3 your_analysis_script.py
```

#strong[Python Usage]

In your Python code (all platforms):

```python
import wavelet_prosody_toolkit
# Use toolkit functions
```

== Updating the Toolkit
<updating-the-toolkit>
=== Windows
<windows-1>
```powershell
cd $HOME\wavelet_prosody_toolkit
git pull
```

=== macOS/Linux
<macoslinux-1>
```bash
cd ~/wavelet_prosody_toolkit
git pull
```

#[#{
  show heading: none
  heading(level: 1, outlined: true)[Option 2: Per-Project Installation]
  counter(heading).update((..nums) => {
    let arr = nums.pos()
    arr.slice(0, -1) + (arr.last() - 1,)
  })
}#heading(level: 1, outlined: false)[Option 2: Per-Project Installation#sidenote()[Use this method when you need isolated dependencies for reproducible research environments.] <option-2-per-project-installation2>]]
This creates a project-specific installation with its own virtual environment.

== Installation
<installation-1>
=== Windows (PowerShell)
<windows-powershell-1>
```powershell
# In your project directory
.\install_toolkit_project.ps1
```

=== macOS/Linux (Bash)
<macoslinux-bash-1>
```bash
# In your project directory
chmod +x install_toolkit_project.sh
./install_toolkit_project.sh
```

== Usage
<usage-1>
=== Windows
<windows-2>
#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
Virtual EnvironmentThe toolkit is installed in an isolated environment (.venv) within your project directory.]
```powershell
# Activate the virtual environment
.\.venv\Scripts\Activate.ps1

# Launch the GUI
python -m wavelet_prosody_toolkit.wavelet_gui

# Run your analysis scripts
python your_analysis_script.py
```

=== macOS/Linux
<macoslinux-2>
```bash
# Activate the virtual environment
source .venv/bin/activate

# Launch the GUI
python -m wavelet_prosody_toolkit.wavelet_gui

# Run your analysis scripts
python your_analysis_script.py
```

== Updating the Toolkit
<updating-the-toolkit-1>
=== Windows
<windows-3>
```powershell
cd vendor\wavelet_prosody_toolkit
git pull
```

=== macOS/Linux
<macoslinux-3>
```bash
cd vendor/wavelet_prosody_toolkit
git pull
```

= Prerequisites
<prerequisites>
Before running either script, ensure you have the following installed:

== All Platforms
<all-platforms>
#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
Python Version:Python 3.8 or later is recommended. The toolkit may work with earlier versions but has not been tested.]
=== Python 3
<python-3>
#strong[Windows:]

```powershell
python --version
```

Download from: #link("https://www.python.org/downloads/")[python.org/downloads]

#strong[macOS/Linux:]

```bash
python3 --version
```

=== Git
<git>
#strong[Windows:]

```powershell
git --version
```

Download from: #link("https://git-scm.com/download/win")[git-scm.com/download/win]

#strong[macOS/Linux:]

```bash
git --version
```

== Platform-Specific
<platform-specific>
=== macOS Only
<macos-only>
Xcode Command Line Tools:

```bash
xcode-select --install
```

=== Windows Only
<windows-only>
Microsoft C++ Build Tools (if PyQt6 fails to install):

- Download #link("https://visualstudio.microsoft.com/downloads/")[Visual Studio Build Tools]
- Select "Desktop development with C++"#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
  Dependencies:The following packages will be automatically installed:PyWaveletsscipynumpymatplotlibPyQt6]

= Quick Start Example
<quick-start-example>
== Global Installation
<global-installation>
=== Windows
<windows-4>
```powershell
# Install once
.\install_toolkit_standalone.ps1

# Navigate to your project
cd C:\Users\YourName\my_prosody_analysis

# Create your analysis script
@"
import wavelet_prosody_toolkit as wpt
# Your analysis code here
"@ | Out-File -Encoding utf8 analyze.py

# Run it
python analyze.py
```

=== macOS/Linux
<macoslinux-4>
```bash
# Install once
./install_toolkit_standalone.sh

# Navigate to your project
cd ~/my_prosody_analysis

# Create your analysis script
cat > analyze.py << 'EOF'
import wavelet_prosody_toolkit as wpt
# Your analysis code here
EOF

# Run it
python3 analyze.py
```

== Per-Project Installation
<per-project-installation-1>
=== Windows
<windows-5>
```powershell
# In your project directory
.\install_toolkit_project.ps1

# Activate environment
.\.venv\Scripts\Activate.ps1

# Create and run your analysis
python analyze.py
```

=== macOS/Linux
<macoslinux-5>
```bash
# In your project directory
./install_toolkit_project.sh

# Activate environment
source .venv/bin/activate

# Create and run your analysis
python analyze.py
```

= Summary of Installation Files
<summary-of-installation-files>
The following table summarises the installation scripts included in this package:

#wideblock[
#with-table-rows(n: 3)[
#table(
  columns: (25%, auto, auto),
  align: (auto,auto,auto,),
  table.header([Purpose], [Windows], [macOS/Linux],),
  table.hline(),
  [Global installation], [#raw(lang:"powershell", "install_toolkit_standalone.ps1");], [#raw(lang:"bash", "install_toolkit_standalone.sh");],
  [Per-project installation], [#raw(lang:"powershell", "install_toolkit_project.ps1");], [#raw(lang:"bash", "install_toolkit_project.sh");],
)
]
]
#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
File Distribution:All files are included in the distribution package and can be used independently.]
= Additional Resources
<additional-resources>
Test for Additional Resources:#sidenote(numbering: none, anchor-numbering: none)[#set par(first-line-indent: 0em)
Support:For issues specific to the toolkit itself (not installation), please refer to the GitHub repository’s issue tracker.]

- #strong[Toolkit Repository];: #link("https://github.com/asuni/wavelet_prosody_toolkit")[github.com/asuni/wavelet\_prosody\_toolkit]
- #strong[Installation Method];: pip install in editable mode (allows toolkit updates via `git pull`)
- #strong[Installation Type];: User-level (no admin/sudo required)

\

#block[
#heading(
level: 
1
, 
numbering: 
none
, 
[
Acknowledgements
]
)
]
This installation package was created to facilitate the use of the Wavelet Prosody Toolkit across different operating systems and research environments. Special thanks to the toolkit developers and the Python scientific computing community.
