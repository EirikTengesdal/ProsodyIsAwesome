#show: doc => article(
$if(title)$
  title: [$title$],
  $if(shorttitle)$
  shorttitle: [$shorttitle$],
  $endif$
  $if(subtitle)$
  subtitle: [$subtitle$],
  $endif$
$endif$

$if(by-author)$
  authors: (
    $for(by-author)$
      $if(it.name.literal)$
          (
          name: [$it.name.literal$],
          affiliation: [$for(it.affiliations)$$it.name$$sep$, $endfor$],
          location: [$it.location$],
          role: [$for(it.roles)$$it.role$$sep$, $endfor$],
          email: "$it.email$"$if(it.orcid)$,
          orcid: "$it.orcid$"$endif$
          ),
      $endif$
    $endfor$
  ),
$endif$
$if(date)$
  date: "$date$",
$endif$
$if(lang)$
  lang: "$lang$",
$endif$
$if(region)$
  region: "$region$",
$endif$
$if(abstract)$
  abstract: [$abstract$],
  abstracttitle: "$labels.abstract$",
$endif$
$if(margin)$
  margin: ($for(margin/pairs)$$margin.key$: $margin.value$, $endfor$),
$endif$
$if(paper-size)$
  paper: "$paper-size$",
$endif$
$if(fontsize)$
  fontsize: $fontsize$,
$endif$
$if(section-numbering)$
  sectionnumbering: "$section-numbering$",
$endif$
$if(toc)$
  toc: $toc$,
$endif$
$if(version)$
  version: [$version$],
$endif$
$if(reference-section-title)$
  bibliography-title: "$reference-section-title$",
$endif$
$if(bibliographystyle)$
  bibliography-style: "$bibliographystyle$",
$endif$
$if(first-page-footer)$
 first-page-footer: [$first-page-footer$],
$endif$
publisher: $if(publisher)$$publisher$$else$"Publisher"$endif$,
documenttype: $if(documenttype)$[$documenttype$]$else$""$endif$,
$if(toc-title)$
  toc_title: [$toc-title$],
$endif$
$if(toc-depth)$
  toc_depth: $toc-depth$,
$endif$
$if(show-layout-frame)$
  show-layout-frame: $show-layout-frame$,
$endif$
  doc,
)
