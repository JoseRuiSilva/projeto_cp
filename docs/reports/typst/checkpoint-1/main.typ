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
O caso de estudo é um simulador de dinâmica molecular de árgon @foleylab2016 com $N = 5000$ partículas e 201 iterações do ciclo temporal (`NumTime = 200`). Em cada passo, `VelocityVerlet()` atualiza posições e meias-velocidades, chama `computeAccelerations()` (potencial de Lennard-Jones avaliado sobre os $N(N-1) slash 2$ pares, $O(N^2)$), completa as velocidades e aplica as paredes elásticas. No fim do passo, `main()` chama ainda `MeanSquaredVelocity()`, `Kinetic()` e `Potential()`. Todas estas funções, exceto as duas que percorrem pares, são $O(N)$.

A versão original foi medida num nó A64FX (1 core, GCC 15.2.0, `-O3 -ffast-math`) com `perf`: *325,23 s*, 650,4 G ciclos, 216,8 G instruções, IPC de 0,33 e 918 M _cache-misses_. O `perf record` mostra que dois ciclos duplos sobre pares concentram 99,93% do tempo: `Potential()` (66,50%) e `computeAccelerations()` (33,43%). `Potential()` volta a percorrer os mesmos pares apenas para obter a energia potencial e ainda recorre a `pow()`, o que a torna a função mais pesada.

Quanto a dependências, os passos de tempo são sequenciais, porque cada um depende das acelerações do anterior. Dentro de um passo, as iterações em $i$ são independentes. No entanto, o código aplica a 3.ª lei de Newton ($F_(j i) = -F_(i j)$) e escreve em `a[j]` dentro do ciclo, pelo que paralelizar diretamente o ciclo exterior provoca _data races_.

= Otimizações e Desenho Paralelo
Antes de paralelizar, aplicaram-se três otimizações sequenciais @chapman2007: (i) substituir `pow()` e `sqrt()` por multiplicações com $r^(-2)$ e $r^(-6)$; (ii) fundir `Potential()` em `computeAccelerations()`, eliminando um dos dois ciclos $O(N^2)$. Isto é válido porque as posições não mudam entre as duas chamadas; a energia é acumulada nos mesmos pares $i < j$ e multiplicada por $8 epsilon$, o que reproduz a dupla contagem ($i != j$) do original; (iii) passar para um _layout_ SoA (`rx`, `ry`, `rz`, ...) alinhado a 64 bytes, adequado à vetorização SVE. Só com estas alterações, o tempo em 1 _thread_ desce para 25,55 s (12,7× face ao original).

== Alternativas consideradas
Para resolver as escritas concorrentes em `a[j]`, avaliaram-se, com base em OpenMP @openmp52, três abordagens:
- *`atomic` nas atualizações de `a[j]`*: é simples, mas cada interação par a par passa a ter 3 operações atómicas em vírgula flutuante. Isto gera contenção, impede a vetorização do ciclo interior e não escala.
- *Matriz completa sem 3.ª lei de Newton*: cada _thread_ calcula todas as interações da sua partícula $i$ e escreve apenas em `a[i]`. Não há *races* nem reduções, mas o trabalho duplica ($N^2$ em vez de $N^2 slash 2$ pares).
- *Buffers privados por thread + redução*: cada _thread_ acumula forças num vetor próprio e, no fim, os vetores são somados em paralelo. Mantém o trabalho em $N^2 slash 2$ pares e não precisa de sincronização no ciclo interior. O custo extra é $O(P dot N)$ por passo, desprezável face a $O(N^2)$.

Estas alternativas não foram medidas isoladamente. A escolha baseia-se na análise do trabalho e da sincronização de cada uma.

== Solução escolhida
A solução implementada usa buffers privados (terceira alternativa) dentro de uma única região paralela por passo. Os buffers são alocados uma única vez (`ensureThreadBuffers()`), e cada _thread_ usa um _offset_ múltiplo de `STRIDE`, alinhado a 64 bytes, o que evita _false sharing_. Cada _thread_ começa por zerar o seu buffer. A seguir, o `omp for` sobre os pares escreve apenas nesse buffer. Depois da barreira implícita, um segundo `omp for` soma os $P$ buffers em `ax`, `ay` e `az`, ficando cada partícula a cargo de uma só _thread_. A energia potencial é obtida com `reduction(+:pot_sum)`. Não há _data races_. As restantes funções $O(N)$ ficaram sequenciais, porque o seu custo é desprezável face ao ciclo de pares.

O ciclo exterior é triangular (a iteração $i$ processa $N - i - 1$ pares), pelo que o escalonamento é determinante. Com `schedule(guided)`, o `libgomp` entrega o primeiro bloco, o maior ($ceil(N slash P)$), às iterações mais pesadas, e o _speedup_ fica limitado a $S(P) = 1 slash (1 - (1 - 1 slash P)^2)$. Este modelo prevê 1,33×, 2,29× e 4,27× para 2, 4 e 8 _threads_, praticamente iguais aos valores medidos (1,34×, 2,29× e 4,27×). A 48 _threads_ a eficiência fica em 47,7% (1,94 s). Com `schedule(static, 1)`, a distribuição cíclica equilibra a carga sem _overhead_ dinâmico e o tempo desce para 1,03 s (eficiência de 88,8%).

No ciclo interior, `#pragma omp simd reduction(+:...)` permite ao GCC vetorizar a redução sem `-ffast-math`; sem esta diretiva o tempo quase duplica (1,43 s). As _threads_ ficam fixas aos _cores_ com `OMP_PROC_BIND=close` e `OMP_PLACES=cores`.

= Resultados Experimentais e Escalabilidade
Todas as medições foram feitas num nó `normal-arm` do Deucalion @deucalion2026, com um Fujitsu A64FX de 48 _cores_ repartidos por 4 CMG/NUMA de 12 _cores_, compilando com GCC 15.2.0.

*Validação.* O valor de $P(t)$ tem de coincidir com a referência (157203191.80025804) em 14 dígitos. Com `-ffast-math` o 14.º dígito falha (…80023986). Sem essa flag, o resultado passa e o custo é de apenas ~10 ms. A seguir forçou-se SVE de 512 bits (`-mcpu=a64fx -msve-vector-bits=512`), o que reduziu o tempo em 48 _threads_ de 1,04 s para 0,72 s (−30,8%). Acrescentar `-fno-math-errno -fno-trapping-math`, que preservam a semântica IEEE-754, baixou-o para 0,67 s. A versão final obtém $P(t) = 157203191.80025285$ (passa).

#figure(
  table(
    columns: 4,
    align: center,
    stroke: 0.5pt,
    [*Threads*], [*Tempo (s)*], [*Speedup*], [*Eficiência*],
    [1], [25,55], [1,00], [100%],
    [2], [12,87], [1,99], [99,3%],
    [4], [6,31], [4,05], [101,3%],
    [8], [3,19], [8,01], [100,1%],
    [12], [2,22], [11,51], [95,9%],
    [16], [1,72], [14,89], [93,1%],
    [24], [1,19], [21,53], [89,7%],
    [32], [0,92], [27,65], [86,4%],
    [48], [0,67], [37,87], [78,9%],
  ),
  caption: [Escalabilidade forte da versão final (SVE 512-bit, `schedule(static, 1)`). Original sequencial: 325,23 s.],
) <tab:tempos>

#let W = 6.6cm
#let H = 3.8cm
#let pts(data) = {
  let p = data.map(((x, y)) => (x / 48 * W, H - y / 48 * H))
  (curve.move(p.first()),) + p.slice(1).map(q => curve.line(q))
}
#let static1 = ((1, 1), (2, 1.99), (4, 4.05), (8, 8.01), (12, 11.51), (16, 14.89), (24, 21.53), (32, 27.65), (48, 37.87))
#let guided = ((1, 1), (2, 1.34), (4, 2.29), (8, 4.27), (12, 6.25), (16, 8.21), (24, 12.04), (32, 15.80), (48, 22.89))

#figure(
  box(width: W + 0.8cm, height: H + 1.2cm, inset: (left: 0.6cm, bottom: 0.8cm))[
    #place(rect(width: W, height: H, stroke: 0.5pt))
    #for t in (12, 24, 36) {
      place(line(start: (t / 48 * W, 0pt), end: (t / 48 * W, H), stroke: (paint: luma(200), thickness: 0.4pt)))
      place(line(start: (0pt, H - t / 48 * H), end: (W, H - t / 48 * H), stroke: (paint: luma(200), thickness: 0.4pt)))
    }
    #place(line(start: (0pt, H), end: (W, 0pt), stroke: (dash: "dashed", thickness: 0.6pt)))
    #place(curve(stroke: 1pt + blue, ..pts(static1)))
    #place(curve(stroke: 1pt + red, ..pts(guided)))
    #for t in (0, 12, 24, 36, 48) {
      place(dx: t / 48 * W - 0.15cm, dy: H + 0.1cm, text(7pt)[#t])
      place(dx: -0.5cm, dy: H - t / 48 * H - 0.15cm, text(7pt)[#t])
    }
    #place(dx: W / 2 - 0.6cm, dy: H + 0.45cm, text(7pt)[N.º de _threads_])
    #place(dx: 0.2cm, dy: 0.15cm, text(7pt)[
      #text(fill: blue)[━] `static, 1` (final) \
      #text(fill: red)[━] `guided` \
      ╌ ideal
    ])
  ],
  kind: image,
  caption: [Speedup em função do número de threads (face à versão otimizada a 1 _thread_).],
) <fig:speedup>

A @tab:tempos e a @fig:speedup mostram uma escalabilidade quase linear até 12 _threads_, ou seja, enquanto a execução cabe num único CMG. A partir daí a eficiência desce até 78,9% a 48 _threads_. Pela lei de Amdahl, $S(48) = 37,87$ corresponde a uma fração sequencial efetiva de $f approx 0,57%$. Esta fração era de 0,27% sem SVE: a vetorização acelerou 1,72× a parte paralela e, por isso, o peso relativo do _overhead_ OpenMP aumentou.

Os contadores de hardware sugerem a mesma explicação. Entre 1 e 48 _threads_, as instruções sobem de 15,7 G para 37,4 G, o IPC de 0,31 para 0,60 e os _cache-misses_ de 458 M para 605 M. A hipótese é que o trabalho extra vem da espera ativa nas 4 sincronizações de cada passo (barreiras do `single` e dos dois `omp for` e fim da região) e da redução dos 48 buffers privados entre CMGs, e não de mais computação útil. A fração sequencial resulta, por sua vez, dos ciclos $O(N)$ de `VelocityVerlet()`, `Kinetic()` e `MeanSquaredVelocity()` e da abertura da região paralela em cada passo.

= Conclusão
A versão final reduz o tempo de 325,23 s para 0,67 s com 48 _threads_ (482× face ao original), sem _data races_ e com o resultado validado em 14 dígitos. O maior ganho isolado veio da paralelização (37,9×), seguido das otimizações sequenciais com vetorização SVE (12,7×). Na paralelização, o escalonamento foi decisivo: só a troca de `guided` por `static, 1` quase duplicou o desempenho.

Como trabalho futuro, propõe-se reduzir o custo da redução entre CMGs (por exemplo, com uma redução hierárquica por nó NUMA) e diminuir as sincronizações por passo de tempo, que limitam a eficiência acima de 12 _threads_. O `single` pode ser removido usando `omp_get_num_threads()` em cada _thread_, e a região paralela pode englobar também os ciclos $O(N)$ do integrador.

#bibliography("../referencias.bib", title: "Referências", style: "ieee")
