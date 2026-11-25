#import "../template.typ": ieee

#show: ieee.with(
  title: "Otimização e Paralelização OpenMP de uma Simulação de Dinâmica Molecular no Deucalion",
  authors: (
    (
      name: "Alexandr Victorovitch Tchikoulaev",
      number: "PG65363",
      affiliation: "Departamento de Informática, Universidade do Minho",
    ),
    (
      name: "José Rui Mendes da Silva",
      number: "PG65420",
      affiliation: "Departamento de Informática, Universidade do Minho",
    ),
  ),
  abstract: [
    Este relatório analisa, otimiza e paraleliza em OpenMP uma simulação de dinâmica molecular de átomos de árgon, executada na partição ARM do supercomputador Deucalion. Identificam-se os pontos críticos do código, comparam-se alternativas de paralelização e avalia-se a escalabilidade da solução escolhida.
  ],
  keywords: [dinâmica molecular, OpenMP, computação paralela, escalabilidade, Deucalion],
)

= Introdução e Profiling
[Por preencher: descrição do caso de estudo e resultados do profiling (por exemplo, com `perf`) @foleylab2016.]

= Otimizações e Desenho Paralelo
[Por preencher: otimizações sequenciais e alternativas de paralelização com OpenMP @openmp52 @chapman2007.]

== Alternativas consideradas
[Por preencher.]

== Solução escolhida
[Por preencher.]

= Resultados Experimentais e Escalabilidade
[Por preencher: ambiente (partição ARM do Deucalion @deucalion2026), validação e escalabilidade forte (1 a 48 threads).]

#figure(
  table(
    columns: 3,
    align: center,
    stroke: 0.5pt,
    [*Threads*], [*Tempo (s)*], [*Speedup*],
    [1], [-], [1,0],
    [48], [-], [-],
  ),
  caption: [Tempos de execução e speedup],
) <tab:tempos>

#figure(
  rect(width: 100%, height: 3cm, stroke: 0.5pt)[#align(center + horizon)[Gráfico de escalabilidade]],
  caption: [Speedup em função do número de threads.],
) <fig:speedup>

= Conclusão
[Por preencher: speedup final e trabalho futuro.]

#bibliography("../referencias.bib", title: "Referências", style: "ieee")