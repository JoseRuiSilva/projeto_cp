// Template IEEE Conference (A4, 2 colunas) - sem pacotes externos.
// Uso: #show: ieee.with(title: ..., authors: (...), abstract: [...], keywords: [...])

// Small Caps simulado: maiúsculas mantêm-se, minúsculas passam a maiúsculas mais pequenas
#let sc(body) = {
  show regex("\\p{Ll}+"): it => text(size: 0.8em, upper(it))
  body
}

#let ieee(
  title: "",
  authors: (),
  abstract: none,
  keywords: none,
  doc,
) = {
  // Metadados do PDF
  set document(title: title, author: authors.map(a => a.name))

  // Página: A4, 2 colunas, sem numeração/cabeçalho/rodapé
  set page(
    paper: "a4",
    margin: (top: 1.9cm, bottom: 2.8cm, left: 1.43cm, right: 1.43cm),
    columns: 2,
    numbering: none,
    header: none,
    footer: none,
  )
  set columns(gutter: 0.42cm)

  // Tipografia: corpo 10 pt, justificado, indentação na 1.ª linha (também após títulos)
  set text(
    font: ("Times New Roman", "Liberation Serif", "Libertinus Serif", "Linux Libertine"),
    size: 10pt,
    lang: "pt",
    region: "PT",
  )
  set par(
    justify: true,
    leading: 0.5em,
    spacing: 0.5em,
    first-line-indent: (amount: 1em, all: true),
  )

  // Código
  show raw: set text(font: ("DejaVu Sans Mono", "Consolas"), size: 8pt)

  // Títulos: I. / A. / 1)
  set heading(numbering: (..nums) => {
    let n = nums.pos()
    if n.len() == 1 { numbering("I.", n.at(0)) }
    else if n.len() == 2 { numbering("A.", n.at(1)) }
    else { numbering("1)", n.at(2)) }
  })

  // Nível 1: centrado, Small Caps, 10 pt, sem negrito
  // (a bibliografia também é nível 1, mas sem numeração)
  show heading.where(level: 1): it => block(
    above: 1.1em, below: 0.6em, width: 100%, sticky: true,
    align(center, text(size: 10pt, weight: "regular", sc({
      if it.numbering != none {
        counter(heading).display(it.numbering)
        h(0.5em)
      }
      it.body
    }))),
  )

  // Nível 2: esquerda, itálico, 10 pt, sem negrito
  show heading.where(level: 2): it => block(
    above: 0.9em, below: 0.4em, width: 100%, sticky: true,
    text(size: 10pt, weight: "regular", style: "italic", {
      counter(heading).display(it.numbering)
      h(0.5em)
      it.body
    }),
  )

  // Nível 3: "1)" itálico, indentado
  show heading.where(level: 3): it => block(
    above: 0.7em, below: 0.3em, sticky: true,
    pad(left: 1em, text(size: 10pt, weight: "regular", style: "italic", {
      counter(heading).display(it.numbering)
      h(0.5em)
      it.body
    })),
  )

  // Tabelas: legenda ACIMA, "TABELA I" + título centrados em Small Caps, 8 pt
  show figure.where(kind: table): set figure(numbering: "I", supplement: [Tabela])
  show figure.where(kind: table): set figure.caption(position: top)
  show figure.caption.where(kind: table): it => align(center, text(size: 8pt, sc({
    it.supplement
    [ ]
    context it.counter.display(it.numbering)
    linebreak()
    it.body
  })))
  show figure.where(kind: table): set block(breakable: false)

  // Figuras: legenda ABAIXO, "Fig. 1." a 8 pt
  show figure.where(kind: image): set figure(numbering: "1", supplement: [Fig.])
  show figure.where(kind: image): set figure.caption(separator: [. ])
  show figure.caption.where(kind: image): set text(size: 8pt)
  show figure: set block(above: 1em, below: 1em)

  // Tabelas em 8 pt
  show table: set text(size: 8pt)

  // Referências: 8 pt, estilo IEEE
  show bibliography: set text(size: 8pt)
  show bibliography: set par(leading: 0.5em, spacing: 0.6em, first-line-indent: 0pt)

  // Cabeçalho a 1 coluna no topo da 1.ª página (título + autores)
  place(
    top + center,
    scope: "parent",
    float: true,
    {
      set par(first-line-indent: 0pt, justify: false)
      align(center)[
        #text(size: 22pt, weight: "regular")[#title]
        #v(0.8em)
        #grid(
          columns: (1fr,) * authors.len(),
          column-gutter: 1.5em,
          ..authors.map(a => [
            #text(size: 10pt)[#a.name] \
            #text(size: 9pt)[#a.number] \
            #text(size: 9pt, style: "italic")[#a.affiliation]
          ])
        )
        #v(1em)
      ]
    },
  )

  // Resumo e Palavras-chave: 9 pt, negrito, sem indentação
  {
    set par(first-line-indent: 0pt)
    set text(size: 9pt, weight: "bold")
    if abstract != none {
      emph[Resumo-]
      abstract
      parbreak()
    }
    if keywords != none {
      emph[Palavras-chave-]
      keywords
      v(0.4em)
    }
  }

  doc
}