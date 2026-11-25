#import "../template.typ": ieee

#show: ieee.with(
  title: "Otimização e Paralelização OpenMP de uma Simulação de Dinâmica Molecular no Supercomputador Deucalion",
  authors: (
    (name: "Alexandr Victorovitch Tchikoulaev", number: "PG65363", affiliation: "Departamento de Informática, Universidade do Minho"),
    (name: "José Rui Mendes da Silva", number: "PG65420", affiliation: "Departamento de Informática, Universidade do Minho"),
  ),
  abstract: [
    Este relatório analisa, otimiza e paraleliza em OpenMP uma simulação de Dinâmica Molecular (MD) para átomos de gás Árgon ($N = 5000$, 200 passos temporais) na partição ARM (Fujitsu A64FX) do supercomputador Deucalion.
  ]
)

= Introdução e Profiling
[Por preencher com os resultados do perf]

= Otimizações e Desenho Paralelo
[Por preencher com as otimizações sequenciais e alternativas OpenMP]

= Resultados Experimentais e Escalabilidade
[Por preencher com a validação e tabela/gráfico de 1 a 48 threads]

= Conclusão
[Por preencher com o speedup final]

#bibliography("../referencias.bib", title: "Referências", style: "ieee")