// Template IEEE Conference (2 colunas) para WA1 - Computação Paralela
#let ieee(
  title: "",
  authors: (),
  abstract: none,
  doc,
) = {
  set document(title: title, author: authors.map(a => a.name))
  set page(
    paper: "a4",
    margin: (top: 1.9cm, bottom: 2.5cm, left: 1.4cm, right: 1.4cm),
    columns: 2,
    numbering: none,
  )
  set columns(gutter: 0.5cm)
  set text(font: ("Times New Roman", "Liberation Serif", "Linux Libertine"), size: 9.5pt, lang: "pt")
  set par(justify: true, leading: 0.52em, spacing: 0.65em, first-line-indent: 1em)

  show raw.where(block: false): set text(font: ("Consolas", "DejaVu Sans Mono"), size: 8.5pt)
  show raw.where(block: true): set text(font: ("Consolas", "DejaVu Sans Mono"), size: 8pt)

  set heading(numbering: "I.A.")
  show heading.where(level: 1): it => {
    set align(center)
    set text(size: 10pt, weight: "bold")
    block(above: 1.1em, below: 0.6em, smallcaps(it))
  }
  show heading.where(level: 2): it => {
    set text(size: 9.5pt, weight: "bold", style: "italic")
    block(above: 0.9em, below: 0.4em, it)
  }

  // Cabeçalho a toda a largura (1 coluna)
  place(
    top + center,
    scope: "parent",
    float: true,
    {
      align(center)[
        #text(size: 17pt, weight: "bold")[#title]
        #v(0.8em)
        #grid(
          columns: authors.len(),
          column-gutter: 2.5em,
          ..authors.map(a => [
            #text(size: 10pt)[#a.name (#a.number)] \
            #text(size: 8.5pt, style: "italic")[#a.affiliation]
          ])
        )
        #v(0.8em)
      ]
    }
  )

  if abstract != none {
    set par(first-line-indent: 0pt)
    text(weight: "bold", style: "italic")[Resumo—]
    text(weight: "bold", size: 9pt)[#abstract]
    v(0.6em)
  }

  doc
}