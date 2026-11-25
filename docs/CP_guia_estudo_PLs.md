# Computação Paralela (MEI, UMinho 2026/27) - guia das PLs

Como ler isto:
- Cada PL tem: o que é para fazer, como fazer, o que esperar do resultado, a matéria associada e a crítica.
- Nas PL01 a PL03 a base são as tuas resoluções (os .txt). Nas PL04 a PL07 ainda não tenho resolução tua, por isso é a minha previsão de como se faz.
- "Previsão" = o que espero que dê. Confirma sempre no cluster antes de escreveres como facto.
- Não vi os ficheiros da PL06 (`/share/cpar/PL07-Codigo`: exe2.c, quicksort, Makefile, perf1.sh, run.sh...). O que digo do quicksort é pelo enunciado e pela matéria.

Aviso rápido: o teu `PL01.txt` tem a password do cluster em texto. Tira isso antes de entregares ou partilhares o ficheiro.

---

## 0. Mapa geral

| PL | Tema | Aula/matéria | Estado |
|---|---|---|---|
| PL00 | Ambiente (SeARCH), MM base, perf, modelo de desempenho | Aula 1 | sem resolução tua |
| PL01 | Equação de desempenho, perf, threads, Amdahl, grafo de dependências | Aulas 1 e 2 | resolvida |
| PL02 | Localidade (espacial/temporal), transposta, unroll, tiling | Aula 3 | resolvida |
| PL03 | Vetorização (SSE), float vs double, Roofline | Aula 4 | resolvida |
| PL04 | OpenMP básico: parallel, for, master, single, critical, barrier, ordered, schedule | Aulas 5 e 6 | por fazer |
| PL05 | Data sharing, data races, erros de arredondamento, pi | Aula 7 (+ nota Erros Numéricos) | por fazer |
| PL06 | Overhead de critical/atomic/reduction, quicksort com tasks | Aula 8 | por fazer |
| PL07 | MPI: pipeline, farm, MM distribuída | Aula 9 | por fazer |

### Glossário (as siglas que voltam sempre)

| Sigla / conceito | O que é | Analogia |
|---|---|---|
| #I | número de instruções executadas | nº de passos da receita |
| CPI | ciclos por instrução (média) | minutos médios gastos por passo |
| Tcc | duração de um ciclo = 1/frequência | duração de um "minuto" do relógio |
| IPC | instruções por ciclo = 1/CPI | passos feitos por minuto |
| Texe = #I x CPI x Tcc | equação de desempenho | tempo total = passos x minutos por passo x duração do minuto |
| FLOP/s | operações de vírgula flutuante por segundo | contas feitas por segundo |
| Hotspot | zona do código onde se gasta mais tempo | a fila de caixa que atrasa o supermercado todo |
| Speedup S | T_sequencial / T_paralelo | quantas vezes ficou mais rápido |
| Eficiência E | S / nº de PUs | quanto do esforço extra deu retorno |
| Amdahl | parte sequencial limita o ganho máximo a 1/(parte sequencial) | obra com 10 pedreiros mas só uma betoneira |
| Cache miss | dado não está na cache, vai à RAM | ir ao armazém em vez de ao bolso |
| Localidade espacial | aceder a endereços vizinhos | tirar os livros que estão na mesma prateleira |
| Localidade temporal | reaceder ao mesmo dado em pouco tempo | manter na secretária o livro que estás a usar |
| SIMD | uma instrução, vários dados | um carimbo que marca 4 folhas de uma vez |
| Roofline | desempenho limitado ou pelo CPU (teto) ou pela memória (rampa) | cozinheiro rápido, mas fornecedor lento: manda o mais lento |
| Intensidade aritmética | FLOP por byte movido | quantas contas fazes por cada viagem ao armazém |
| Data race | 2+ threads, mesma posição, pelo menos uma escreve, sem sincronização | dois a corrigir o mesmo número no quadro ao mesmo tempo |
| Reduction | cada thread soma o seu bocado, no fim juntam-se | cada um conta o seu monte, só no fim se somam os totais |
| SPMD | mesmo programa em N processos, cada um com um rank | mesma receita, vários cozinheiros, cada um com o seu número |

---

## PL00 - Ambiente e caso de estudo (multiplicação de matrizes)

### O que é para fazer
1. Entrar no cluster, compilar e correr um hello world num nó da partição `cpar`.
2. Escrever a MM (double, matrizes NxN, funções separadas: alloc, init, mmult, validação), medir o tempo, repetir com `-O3`.
3. Recolher métricas com `perf stat` e dizer qual é a mais relevante.
4. (*) Calcular o desempenho de pico (`lscpu`) e o desempenho atingido, `perf stat -M flops`.
5. (*) Profiling com `perf record` / `perf report`.

### Como fazer
```
ssh <id>@s7edu.di.uminho.pt
module load gcc/11.2.0
gcc hello.c -o hello && srun --partition=cpar ./hello
gcc -g -fno-omit-frame-pointer -O0 mmult.c -o mmult      # (o gcc sem -O é O0)
gcc -g -fno-omit-frame-pointer -O3 mmult.c -o mmult_o3
srun --partition=cpar perf stat ./mmult
srun --partition=cpar perf stat ./mmult_o3
srun --partition=cpar perf stat -M flops ./mmult_o3
srun --partition=cpar perf record -g -F 99 -o perf.data ./mmult_o3
perf report -i perf.data                                   # na front-end
```
- Porque é que `time srun ...` não é preciso? O `time` à frente do srun mede também a alocação do nó, o arranque do job e a saída. Não é só o teu programa. Por isso se usa `perf stat` (mede o processo) ou `omp_get_wtime`/`clock_gettime` dentro do código.
- Métrica mais relevante para explicar a diferença O0 vs O3: o número de instruções (#I), que desce muito. Convém também olhar para o CPI (ver crítica na PL01).
- Pico de um core sem vetorização (do slide da aula 3): `#PUs x FP por instrução x instruções por ciclo x frequência`. O exemplo do slide dá 1 x 1 x 2 x 2.9 GHz = ~6 GFlop/s. Tens de ler a frequência real no `lscpu`.
- FLOPs da MM = 2 x N^3 (uma multiplicação e uma soma por iteração). Para N=512 são 268 MFlop, e desempenho = FLOPs / Texe.

### Previsão com os teus números (O0 1.29 s, O3 0.49 s)
| Versão | Texe | GFlop/s (268 MFlop / Texe) |
|---|---|---|
| O0 | 1.29 s | ~0.21 |
| O3 | 0.49 s | ~0.55 |

Comparado com o pico de ~6 GFlop/s do slide, andas à volta de 10%. É o que o slide da aula 3 diz: a base é baixa, e mais baixa ainda quando se juntam threads.

### Matéria associada
Aula 1: ciclo de otimização (medir, analisar, modificar, verificar), modelo vs métrica vs ferramenta, `perf` (amostragem, overhead baixo, não dá contagens exatas) vs Score-P (instrumentação, contagens exatas, overhead alto). "Otimizar sem medir é adivinhar".

---

## PL01 - Introdução ao paralelismo

### O que é para fazer
- Ex.1: identificar #I, CPI, Tcc no `perf stat`; ver o efeito de N=512 -> 1024; ver o ganho do O3.
- Ex.2: perfil com `perf record`; complexidade de cada fase; qual otimizar primeiro.
- Ex.3: MM com `std::thread` (paralelismo de dados por blocos de linhas de C); speedup com 4, 8, 16 threads; causas de não haver speedup ideal.
- Ex.4: Pearson, que chamadas se podem fazer em paralelo, speedup máximo, dependências dentro de cada função.

### Como fizeste / o que deu

**Ex.1**
| Caso | #I | Ciclos | Tempo |
|---|---|---|---|
| 512, O0 | 6.08 G | 3.22 G | 1.29 s |
| 1024, O0 | 48.47 G | - | 9.53 s |
| 512, O3 | 1.10 G | - | 0.49 s |

- N dobra -> O(N^3) -> 8x. Está certo: #I subiu 8x (6.08 G -> 48.47 G) e o tempo ~7.4x (1.29 -> 9.53 s).
- O3: ganho 2.6x.

**Ex.2**: complexidades alloc/init O(N^2), mmult O(N^3), validação O(1); mmult é 97.7% do tempo. Restrição: dependência de dados (a multiplicação só começa depois de init).

**Ex.3** (speedup vs 0.489 s sequencial O3)
| Threads | Tempo | Speedup | Eficiência |
|---|---|---|---|
| 4 | 0.150 s | 3.26 | 82% |
| 8 | 0.0747 s | 6.55 | 82% |
| 16 | 0.0444 s | 11.01 | 69% |

Truque para ver o peso da parte sequencial: a partir de Amdahl, 1/S = f + (1-f)/p. Com 8 e 16 threads sai f ~ 3% (os 4 threads deram um valor mais alto, provavelmente ruído de medição). 3% de 0.489 s são ~15 ms: é o `init` (muitas chamadas a `rand()`) mais criar as threads.

**Ex.4**
- 11 chamadas (2 sum, 2 deviation, 3 mdeviation, 3 sum, 1 sqrt), caminho crítico de 5 passos -> speedup máximo 11/5 = 2.2.
- Dentro das funções: deviation e mdeviation são maps (iterações independentes, paralelismo de dados); sum é uma redução (somas parciais por thread e junção no fim).

### Matéria associada
- Aula 1/2: equação de desempenho, Lei de Amdahl, speedup e eficiência, strong vs weak scalability.
- Grafo de dependências: trabalho T1 (soma de tudo), caminho crítico T∞, paralelismo médio T1/T∞ (aqui 11/5 = 2.2).
- Paralelismo de dados (escala com o tamanho dos dados) vs de funções (limitado pelo nº de funções independentes).
- Map e reduce. Em FP a soma não é associativa, por isso reorganizar a redução pode mudar as últimas casas decimais.

### A nossa crítica
- 1.a / 1.c: dizer só "foi o #I" é meia verdade. No O3 o #I desceu 5.5x mas o tempo só 2.6x, ou seja, o CPI subiu (na PL02 o base a O2 tem CPI 1.09, contra 0.53 do O0). Menos instruções, mas cada uma pesa mais, porque o O3 tira as instruções "fáceis" e deixa as que esperam pela memória. Diz isto, mostra que percebeste a equação.
- 3.c i): "stalled-cycles-frontend ~79% = contenção de memória / largura de banda" está errado. Frontend stall é a parte que vai buscar/descodificar instruções. Esperas por memória são backend stalls. Podes manter a conclusão (parte sequencial + overheads), mas não atribuas os frontend stalls à largura de banda.
- 3.c ii): diz também que o `rand()` em `init` é sequencial, e que com tempos de 44 ms a criação de threads já pesa.
- Tens o texto "Olhando para o teu resultado..." copiado nas respostas. Reescreve em primeira pessoa/estilo teu.
- Typo no enunciado (`vni2`) não tem importância, mas não o copies para o relatório.

---

## PL02 - Localidade de dados

### O que é para fazer
- Ex.1: que acessos (Cij, Aik, Bkj) têm localidade espacial no DOT; estimar misses L1; versão com transposta; medir; porquê o ganho não é proporcional; (*) nº de permutações de loops e a melhor; (*) array 1D vs array de ponteiros.
- Ex.2: porque é que melhor localidade melhora o speedup paralelo; comparar speedup de 16 threads base vs transposta.
- Ex.3: temporal locality com unroll (4 dot products no ciclo interno); (*) tiling com T = 8, 16, 32, 64.

### Como fizeste / o que deu
- Ex.1.a/b: A[i][k] sequencial (bom), B[k][j] salta N posições (mau), C[i][j] constante no ciclo k (localidade temporal). B domina os misses.
- Tabela N=512 (-O2):

| Versão | Time | CPI | #I | L1_DMiss | Miss/#I |
|---|---|---|---|---|---|
| base | 0.490 | 1.09 | 1.105 G | 141.5 M | 0.128 |
| transp | 0.176 | 0.44 | 972 M | 17.2 M | 0.017 |

- Ex.2: speedup base 16 threads = 0.489/0.044 = 11.1x; transposta = 0.176/0.031 = 5.67x.
- Ex.3.b (tiling):

| T | Time | CPI | #I | L1_DMiss |
|---|---|---|---|---|
| base | 0.490 | 1.09 | 1.105 G | 141.6 M |
| 8 | 0.281 | 0.47 | 1.457 G | 40.0 M |
| 16 | 0.370 | 0.68 | 1.342 G | 149.9 M |
| 32 | 0.421 | 0.81 | 1.289 G | 179.0 M |
| 64 | 0.448 | 0.88 | 1.263 G | 172.3 M |

### Matéria associada
Aula 3: princípio da localidade, hierarquia de memória (registos -> cache -> RAM -> disco), 4 Cs de misses (compulsórios, capacidade, conflito, coerência), modelo de memória externa (conta-se nº de blocos transferidos, cada miss = 1 bloco de 64 B = 8 doubles), tiling/blocking, false sharing, first-touch/NUMA.

Cálculo de estimativa que a tabela pede (linha de cache = 8 doubles):
| Versão | Misses estimados N=512 | Medido |
|---|---|---|
| base | B: N^3 = 134 M, A: N^3/8 = 17 M, total ~151 M | 141.5 M |
| transp | A e B_T: 2 x N^3/8 = 34 M | 17.2 M |
| unroll j+=4 | B: N^3/4 = 34 M, A: ~4 M, total ~38 M | (corre e mede) |

### A nossa crítica
- Faltam na tua tabela as colunas `L1_DMiss (estimated)` e `Miss/#I` do unroll. O enunciado pede explicitamente a estimativa. Usa a tabela acima.
- 1.e está errado: em ikj o ciclo interno (j) varia a coluna de **B e C**, e A[i][k] fica constante. Dizeres "A e C" contradiz o que escreveste certo na PL03. Melhores ordens: ikj e kij. Piores: jki e kji (6 permutações no total).
- Ex.2: a explicação do speedup é contraditória. Dizes que a Lei de Amdahl explica a descida, mas depois dizes que há menos contenção no barramento (o que devia *subir* o speedup). Além disso, comparas speedup com baselines sequenciais compilados com flags diferentes: transp sequencial a O2 (0.176 s) vs paralela a O3 -DNT=16. Para ser justo, mede a transposta sequencial a O3 e divide por aí. É provável que o 5.67x seja em parte artefacto disso. Mantém Amdahl como explicação do ângulo "o sequencial ficou mais barato, a parte fixa (init, transpose, criação de threads) pesa mais".
- Ex.3.a: o grande ganho do unroll em j é em **B**, não em A. Com 4 colunas seguidas, B[k][j..j+3] estão na mesma linha de cache, por isso os misses de B caem para ~N^3/4. Os de A já eram poucos (N^3/8). Também convém usar variáveis locais (c0..c3) em vez de `C[...] +=` quatro vezes, senão o compilador pode não conseguir manter os acumuladores em registos. Falta o resultado medido do `mmult_unroll`.
- Ex.3.b: não discutiste a tabela. Há aqui uma coisa boa para escrever: T=8 é o melhor e T>=16 volta a dar tantos misses como o base. Com N=512, uma linha de B está a 4 KB da seguinte (512 x 8 B), e numa cache L1 de 32 KB, 8 vias, endereços separados por 4 KB caem todos no mesmo conjunto. Quando o bloco tem mais de 8 linhas, há **conflict misses**. É uma hipótese (confirma com a tua `lscpu`/cache), mas encaixa com os dados e com os 4 Cs das notas. Nota também que o #I sobe (1.46 G) por causa dos ciclos extra do tiling.

---

## PL03 - Vetorização e modelo Roofline

### O que é para fazer
- Ex.1: porque o compilador não vetoriza o DOT; que ordem de loops permite; compilar com `-ftree-vectorize -msse4`; medir double vs float; (*) AVX e alinhamento a 32 B.
- Ex.2: Roofline: pico em GFlop/s, tempo da MM 1024; desenhar teto e rampa; ponto da MM ikj; (*) STREAM e unroll paralelo.

### Como fizeste / o que deu
- Ex.1.a: acesso a B[k*N+j] com salto N + redução em C[i][j] no ciclo interno.
- Ex.1.b/c: ordem ikj (ou kij); SSE4 = 128 bits = 2 doubles -> ganho potencial 2x (4x com vetores de 4).
- Ex.1.d/e (N=512):

| Versão | Time | CPI | #I |
|---|---|---|---|
| base_v (ikj, sem vetorizar) | 0.153 s | 0.33 | 1.105 G |
| vect() double | 0.080 s | 0.33 | 570.6 M |
| vect() float | 0.046 s | 0.35 | 302.7 M |

- Ex.2.a (a tua resposta): 16 FLOP/ciclo x 2.5 GHz = 40 GFlop/s; MM 1024 = 2.147 GFlop -> 0.053 s; ponto de inflexão 40/20 = 2 Flop/B; ponto 2.e = 0.25 Flop/B.
- Ex.2.f: STREAM Triad ~57.4 GB/s; `mmult_final` (unroll + 16 threads, 1024) = 0.224 s.

### Matéria associada
Aula 4: SIMD, registos vetoriais (SSE 128, AVX 256, AVX512), peak = #cores x SIMDlen x IPC x freq, vetorização só com paralelismo de dados e sem dependências, AoS vs SoA, precisão vs desempenho (float tem metade dos bytes, o dobro dos elementos por registo, mas menos casas decimais; mixed precision), aula 3: Roofline (zona memory-bound vs compute-bound).

### A nossa crítica
- **2.a: 40 vs 20 GFlop/s.** Na figura do enunciado os portos têm **FP MUL** (porto 0) e **FP ADD** (porto 1) separados, e nada de FMA. A pergunta pede mesmo "constraints entre operações FP que correm em simultâneo", ou seja, 1 mul + 1 add por ciclo. Com 256 bits (4 doubles): 4 + 4 = 8 FLOP/ciclo x 2.5 GHz = **20 GFlop/s**. A prova a favor: o eixo Y do gráfico acaba em 32, por isso 40 nem caberia. Com 20 GFlop/s: MM 1024 = 2.147 / 20 = **0.107 s**; ponto de inflexão 20/20 = **1 Flop/B**; rampa passa por (0.125, 2.5), (0.25, 5), (0.5, 10), (1, 20). Confirma isto com o professor/PL antes de entregar. Se usares FMA, tens de justificar com a figura.
- **2.e**: dizes 0.25 (2 FLOP / 8 B) mas a explicação está confusa e falta o resultado final. Contagem limpa por iteração do ciclo interno em ikj: 2 FLOP; A[i][k] fica em registo; lês B[k][j] (8 B) e C[i][j] (8 B). 2/16 = **0.125 Flop/B**, e o eixo do gráfico começa justamente em 0.125. Desempenho atingível = 0.125 x 20 GB/s = **2.5 GFlop/s** (ou 5 se contares só 8 B). Escolhe uma contagem, diz qual é e marca o ponto.
- Nota para a discussão: a tua versão vetorizada a 512 dá 268 MFlop / 0.080 s = ~3.4 GFlop/s, acima de 2.5. Não é contradição: três matrizes de 2 MB cabem na cache, e a rampa é a de DRAM. Vale a pena dizer isto.
- 1.e: falta a discussão de **precisão**. O objetivo do guia inclui "trade-off performance/precisão". Imprime `C[N/2+5]` em float e em double e calcula o erro relativo.
- 1.f: o aviso do alinhamento é verdade, mas "anula os ganhos" é exagero: em CPUs modernas só custa quando o vetor atravessa linhas de cache. Para implementar: `aligned_alloc(32, ...)` ou `__attribute__((aligned(32)))`, e compilar com `-mavx`.
- 2.f: a conclusão do unroll paralelo é uma afirmação sem prova. Calcula o desempenho: 2 x 1024^3 / 0.224 s = ~9.6 GFlop/s e marca-o no gráfico com a rampa de 57.4 GB/s. Compara com a versão paralela sem unroll a 1024. Só assim mostras que o gargalo de memória foi contornado.

---

## PL04 - Introdução a OpenMP (como se comporta cada diretiva)

### O que é para fazer
Compilar com `gcc -O2 -fopenmp ex41.c` e correr com `srun --partition=cpar --cpus-per-task=2 ./a.out` o programa com 2 threads (loop de 100 iterações a imprimir `T<id>:i<n>`). Correr 2 ou 3 vezes cada variante e explicar a ordem do output.

### Como fazer
Ficheiro base (o do enunciado, `#pragma omp parallel num_threads(2)` seguido do `for`). Cada exercício é inserir **uma** diretiva entre o `parallel` e o `for`. Faz um ficheiro por variante (ex21.c, ex22.c, ...) e vai ao passo seguinte só depois de veres o output.

### Previsão por exercício
| Variante | O que acontece | Ordem entre threads | Ordem dentro de cada thread |
|---|---|---|---|
| Ex.1 só `parallel` | **as duas threads fazem as 100 iterações** (trabalho duplicado, nada é dividido) | varia de execução para execução (interleaving) | sempre crescente (i0, i1, ...) |
| 2.1 `omp for` | as 100 iterações são **divididas** pelas threads | varia | crescente dentro de cada |
| 2.2 `omp master` | só a thread 0 faz o loop todo (as 100) | só há uma thread a escrever | crescente. Não há barreira no fim do master |
| 2.3 `omp single` | uma só thread (a primeira que chegar) faz o loop todo | só uma a escrever. Qual das duas muda entre runs | crescente. Há barreira implícita no fim |
| 2.4 `omp critical` | cada thread faz o loop todo, mas **uma de cada vez** (exclusão mútua) | primeiro uma thread imprime as 100, depois a outra. Quem vai primeiro pode mudar | crescente. Sincronização = exclusão mútua |
| 3.1 `barrier` dentro do loop | cada thread faz as 100 iterações, mas todas esperam umas pelas outras a cada iteração | as iterações aparecem aos pares: (T0:i0, T1:i0) antes de (i1...). A ordem dentro do par varia | crescente. Sincronização = barreira (todas esperam por todas) |
| 3.2 `omp for ordered` + `omp ordered` antes do printf | o loop é dividido, mas o printf sai **sempre por ordem de iteração** i0, i1, ..., i99 | sempre igual | o que muda é só que thread corre cada iteração |

Schedule (Ex.4), todos sobre o 2.1:
| Variante | Distribuição | É sempre igual? |
|---|---|---|
| `static` | um bloco contínuo por thread (T0: 0-49, T1: 50-99) | sim |
| `static,10` | blocos de 10 em round-robin (T0: 0-9, T1: 10-19, T0: 20-29...) | sim |
| `dynamic` | pedaços (chunk=1 por omissão) dados à medida que as threads pedem | não, varia |
| `dynamic,10` | pedaços de 10 a pedido | não |
| `guided` | como o dynamic, mas o tamanho do pedaço vai diminuindo | não |

Atenção: o slide diz chunk=1 por omissão, mas no GCC o `static` sem chunk costuma dar um bloco por thread. Vê no teu output e escreve o que viste.

### Matéria associada
Aula 5/6: modelo fork-join, thread vs processo, escalonamento de threads (lógico vs físico), região parallel, work-sharing (for, sections, single), sincronização (critical, atomic, barrier, ordered), schedule static (menos overhead) vs dynamic (melhor balanceamento).
- Analogia do schedule: static = dividir as encomendas pelos estafetas de manhã; dynamic = quem acaba pede outra ao chefe (balanceia melhor, mas o chefe fica ocupado = overhead).

### Cuidados
- O `printf` é thread-safe, por isso as linhas não se misturam, mas a ordem muda.
- Com loops tão curtos, em `dynamic` pode parecer que uma thread faz quase tudo: é a outra a arrancar tarde, não é bug.

---

## PL05 - Correção em OpenMP: data sharing, data races, erros de FP

### O que é para fazer
- Ex.1: programa com `w` partilhada e `w++` num for; testar 1.0 (sem cláusula), `private`, `firstprivate`, `lastprivate`, `reduction(+:w)`; valor inicial, valor dentro do loop, valor final.
- Ex.2: produto interno (100000 elementos); paralelizar com `parallel for` sem mais nada; ver se muda de run para run e com 2/4/8 threads; corrigir; ver se há solução melhor.
- (*) Ex.3: pi com n = 1e9; paralelizar; speedup com 2, 4, 8, 16 threads.

### Como fazer
```
export OMP_NUM_THREADS=N
gcc -O2 -fopenmp -lm prog.c
srun --partition=cpar --cpus-per-task=N ./a.out
```

### Previsão Ex.1 (w começa a 10, 100 iterações)
| Variante | Valor inicial em cada thread | Valor final dentro do loop | Valor final **depois** do loop |
|---|---|---|---|
| 1.0 (shared) | 10 (partilhado) | pode haver valores repetidos/saltados (data race) | ≤ 110; pode vir 110 muitas vezes, corre várias vezes para ver |
| 1.1 `private(w)` | **indefinido** (lixo) | conta a partir do lixo | **10** (a cópia privada é descartada) |
| 1.2 `firstprivate(w)` | 10 em cada | 10 + nº de iterações dessa thread (60 se static) | **10** |
| 1.3 `lastprivate(w)` | indefinido | como o private | valor da cópia da **última iteração** (i=99), logo indefinido + contagem |
| 1.4 `reduction(+:w)` | **0** (elemento neutro da soma) | contagens parciais por thread | **110** = 10 + 100, o resultado esperado |

Só a reduction dá determinístico e correto. Pergunta c) "o valor final é o esperado?": esperado = 110.

### Previsão Ex.2 (dot product)
- Sem proteção: `dot += a[i]*b[i]` é uma leitura-soma-escrita sobre a mesma variável partilhada. Duas threads leem o mesmo valor, ambas somam e escrevem. Uma atualização perde-se: resultado diferente a cada run e com nº de threads diferente (a e b).
- Valor de referência: a[i] = 1/(size-i), b[i] = a[i]^2, logo dot = soma de 1/k^3, k=1..100000 = ζ(3) ≈ **1.2020569...** (valida contra isto e contra a versão sequencial).
- c) Corrigir com `#pragma omp critical` ou `#pragma omp atomic` na linha do `dot +=`. Funciona mas serializa as 100000 atualizações. Valida com 2, 4, 8 threads.
- d) Melhor: `#pragma omp parallel for reduction(+:dot)`. Cada thread soma o seu bocado em privado, só se juntam no fim. Sem sincronização por iteração, escala.
- Atenção: mesmo com reduction, o resultado com 2, 4 e 8 threads pode diferir **nas últimas casas** (ordem das somas muda, soma FP não é associativa). Isto é ruído aceitável, ao contrário da race. Como distinguir (da nota "Erros Numéricos vs Concorrência"): 1) corre com 1 thread, deve dar sempre o mesmo valor; 2) `gcc -fsanitize=thread` deteta races; 3) fixa a ordem (`OMP_SCHEDULE=static`). Se a variação desaparece, era só arredondamento.

### Previsão Ex.3 (pi)
Código: `#pragma omp parallel for reduction(+:mypi)` no loop. Sequencial = compilar sem `-fopenmp`. Medir com `perf stat` (ou `omp_get_wtime`) e fazer 2, 4, 8, 16 threads. Speedup = T_seq / T_par.
- Previsão: speedup perto do linear até ao número de cores físicos. Há muito cálculo por iteração (divisão), quase nenhum acesso à memória, a redução só junta no fim. Acima dos cores físicos (hyperthreads) cresce pouco.
- Cuidado: `float h = 1.0/n` e `i*h` fazem as contas do ponto em **float**. Prevejo um pi com erro por volta da 7ª casa decimal, que é erro numérico e não data race (e vai aparecer igual com qualquer nº de threads). Experimenta com `double h` e compara.

### Matéria associada
Aula 7: memória partilhada e data races, shared vs private, firstprivate/lastprivate/reduction, `critical` (pessimista, bloqueia) vs `atomic` (otimista, tenta e repete), erros FP (não-associatividade, 0.1+0.2) vs races, 4º desafio "garantir correção".
- Analogia: private = cada um com a sua folha de rascunho; shared = o quadro da sala; reduction = no fim somam-se as folhas.

---

## PL06 - Otimizar desempenho e tasks

### O que é para fazer
- Ex.1: pi com n = 1e7; comparar `critical`, `atomic` e `reduction`; scalability com 1, 2, 4 PUs vs sequencial; (*) perf record do critical em 4 PUs.
- Ex.2: quicksort com OpenMP tasks (a), por que um dos dois runs demora mais; paralelizar; análise teórica do ganho; scalability 2/4/8 threads; tasks nas chamadas recursivas; cut-off de 100 elementos.

### Como fazer (Ex.1)
```
cp -r /share/cpar/PL07-Codigo .     # sim, o enunciado diz PL07-Codigo
srun --partition=cpar --cpus-per-task=X perf stat -M cpi ./a.out    # X = 1, 2, 4
sbatch --partition=cpar --cpus-per-task=4 perf1.sh                  # (*) perf record
```
Três versões do programa, só muda a linha do `mypi`: `critical`, `atomic`, `reduction(+:mypi)`. Mede também o sequencial (sem -fopenmp).

### Previsão Ex.1
| Versão | Previsão |
|---|---|
| critical | **mais lento que o sequencial**, e pior com mais PUs. Cada iteração chama o lock da libgomp (`GOMP_critical_start/end`): as threads fazem fila |
| atomic | melhor que critical (um `lock cmpxchg` com repetição em vez de um lock), mas ainda com contenção: pode ficar abaixo do sequencial |
| reduction | speedup perto do linear (cada thread só toca na sua cópia) |

`perf stat -M cpi`: o CPI sobe com a contenção (as threads gastam ciclos à espera). No perf record do critical, espera ver o tempo concentrado nas funções do runtime OpenMP (lock/futex/spin), e não no cálculo de `f`.

### Previsão Ex.2 (quicksort)
- a) Um run mais lento: em geral é o efeito de aquecimento no primeiro (page faults na primeira escrita, caches/TLB frias) e/ou o segundo ordenar um vetor já ordenado. O `exe2.c` imprime contadores PAPI, compara os dois runs (cache misses, tempo) para sustentar a explicação.
- b) Região `#pragma omp parallel` + `#pragma omp single`; no topo, depois do partition (sequencial), duas `#pragma omp task` para as duas metades (`quickSort_internal(arr,0,j)` e `(arr,i,size)`), e `taskwait` se for preciso.
- c) Contas para N = 2048 e 2 tasks:
  - Trabalho total ~ N log2 N = 2048 x 11 = 22528.
  - Parte sequencial: o partition do topo = N = 2048 (9.1%).
  - Parte paralela: 2 metades de (N/2) log2(N/2) = 1024 x 10 = 10240 cada.
  - Tempo com 2 PUs = 2048 + 10240 = 12288. Speedup máximo = 22528 / 12288 ≈ **1.83**.
- d) Com 2, 4, 8 threads e só 2 tasks: speedup sobe até 2 threads e **estagna** (só há 2 tasks, o resto fica parado: idle time). Escreve que o limite não é o hardware, é o paralelismo disponível.
- e) Tasks em cada chamada recursiva: aparece muito mais paralelismo, o speedup deve melhorar com 2 e 4 threads. Limite teórico: caminho crítico ≈ N + N/2 + N/4 + ... ≈ 2N (os partitions em cadeia), logo speedup máx. ≈ N log2 N / 2N = log2 N / 2 ≈ 5.5 para N=2048. Com sub-problemas pequenos, o overhead de criar tasks pode comer o ganho.
- f) Cut-off: não criar task se o tamanho ≤ 100. Reduz overhead (tasks minúsculas custam mais a criar que a executar), melhora com mais threads. Procura o melhor valor experimentalmente (ex.: 10, 50, 100, 500, 1000...) e mostra uma tabela tempo vs cut-off para 1, 2 e 4 threads. Previsão: curva em "U" (muito baixo = overhead, muito alto = pouco paralelismo / desequilíbrio).

### Matéria associada
Aula 8: causas de não haver speedup ideal (1. trabalho sequencial, 2. overhead de paralelismo, 3. idle time / desequilíbrio de carga), desafios 5 (manter overhead mínimo) e 6 (evitar idle time), modelo de tasks (task = sequência de instruções; thread = contexto de execução; PU = hardware), `omp task`/`taskwait`, `sections` vs tasks.
- Analogia task: em vez de dares a cada pedreiro uma parede fixa, pões as tarefas numa mesa e quem fica livre pega na próxima.

---

## PL07 - Introdução a MPI

### O que é para fazer
- Ex.1: pipeline de processos: (a) 4 processos fixos, (b) nº arbitrário (`MPI_Comm_size`), (c) 10 mensagens.
- Ex.2 (opcional): farm: (a) static (1 tarefa por worker), (b) dynamic (10x tarefas), (c) coletivas (`Bcast` + `Reduce`).
- Ex.3: MM distribuída com coletivas: estratégia de partição e implementação com `Bcast`/`Scatter`/`Gather`.

### Como fazer
Compilar: `mpicc -O2 prog.c`. Correr com `sbatch mpi.sh`:
```
#!/bin/bash
#SBATCH --time=1:00
#SBATCH --ntasks=4
#SBATCH --partition=cpar
mpirun -np 4 ./a.out
```
`--ntasks` tem de ser igual ao `-np`.

### Previsão Ex.1 (pipeline, SPMD)
Mesmo código para todos, o comportamento depende do `rank`:
```c
MPI_Comm_rank(MPI_COMM_WORLD, &rank);
MPI_Comm_size(MPI_COMM_WORLD, &size);
for (int m = 0; m < 10; m++) {
    if (rank == 0) msg = 123456 + m;
    else MPI_Recv(&msg, 1, MPI_INT, rank-1, 0, MPI_COMM_WORLD, &status);
    printf("rank %d processou %d\n", rank, msg);     // processamento
    if (rank < size-1) MPI_Send(&msg, 1, MPI_INT, rank+1, 0, MPI_COMM_WORLD);
}
```
- (a) = esta lógica com `-np 4`; (b) = a mesma, já funciona com qualquer `-np`; (c) = o `for` das 10 mensagens.
- Não há deadlock: a cadeia é linear e sem ciclos. A entrega ponto-a-ponto é ordenada, logo as mensagens chegam por ordem.
- Paralelismo de funções: depois de o pipeline "encher" todos os ranks trabalham ao mesmo tempo, em mensagens diferentes. Tempo ≈ (nº de estágios + nº de mensagens - 1) x tempo de um estágio.

### Previsão Ex.2 (farm, rank 0 = master)
- (a) Static: master envia 1 tarefa (inteiro) a cada worker (`Send`), workers calculam e devolvem, master recebe os resultados (`Recv` com `MPI_ANY_SOURCE`).
- (b) Dynamic: master envia 1 tarefa a cada worker, depois, sempre que recebe um resultado (`status.MPI_SOURCE` diz quem foi), manda a próxima tarefa a esse worker. Quando as 10 x workers tarefas acabam, manda uma mensagem de paragem (tag ou valor especial). Quem é mais rápido recebe mais tarefas (como o `schedule(dynamic)` do OpenMP).
- (c) Coletivas: `MPI_Bcast` do argumento a todos, cada um calcula, `MPI_Reduce` com `MPI_SUM` para o root.

### Previsão Ex.3 (MM distribuída)
- a1) Alternativas para repartir C: por **blocos de linhas**, por blocos de colunas, por **blocos 2D**, ou elemento a elemento (cíclico).
- a2) A mais simples: blocos de linhas. Cada processo precisa das suas N/P linhas de A e de **toda a matriz B** (para cada elemento de C precisa de uma coluna inteira de B).
- b) Implementação: root aloca e inicializa A e B, depois `MPI_Bcast(B, N*N, MPI_DOUBLE, 0, ...)`, `MPI_Scatter(A, N*N/P, MPI_DOUBLE, A_local, N*N/P, MPI_DOUBLE, 0, ...)`, cada um calcula as suas N/P linhas de C, e `MPI_Gather(C_local, ...)` para o root. N tem de ser divisível por P (senão `Scatterv`).
- Medir com `MPI_Wtime`: tempo de comunicação (Bcast de N^2 doubles + Scatter + Gather) vs de cálculo (N^3/P). B é replicada em todos os processos: gasta memória e o Bcast pesa para N pequeno.

### Matéria associada
Aula 9: memória distribuída (processos com espaços de endereçamento separados, comunicação só por mensagens, dados movidos explicitamente), SPMD e rank, `MPI_Send`/`Recv` e modos (standard, `Ssend`, `Rsend`, `Bsend`, não bloqueantes `Isend`/`Wait`), coletivas (`Barrier`, `Bcast`, `Scatter`/`Gather`, `Reduce`, `Allreduce`...). Boas práticas: minimizar comunicação (mesmo repetindo cálculo), preferir scheduling estático, medir comunicação e balanceamento, evitar controlo centralizado.
- Analogia SPMD: a mesma carta com instruções é entregue a N pessoas, e cada uma lê "se eu for a nº 0 faço isto, se for a nº 1 faço aquilo". `MPI_Send/Recv` = entregar uma carta em mão a quem está noutra sala (memórias separadas).

---

## Resumo de erros/ações nas PL01-03 (para corrigires)

| PL | Onde | Problema | Ação |
|---|---|---|---|
| 01 | 1.c | só #I, esquecendo que o CPI sobe | acrescentar CPI |
| 01 | 3.c i) | frontend stalls != memória | corrigir a interpretação |
| 01 | geral | texto "Olhando para o teu resultado" e password no ficheiro | reescrever e apagar |
| 02 | 1.d | faltam colunas estimadas e Miss/#I do unroll | preencher com as contas acima |
| 02 | 1.e | ikj varia B e C, não A e C | corrigir |
| 02 | Ex.2 | baselines com flags diferentes, explicação contraditória | medir transp seq a O3 |
| 02 | 3.a | o ganho do unroll é em B | corrigir a estimativa |
| 02 | 3.b | tabela sem discussão (conflict misses a T>=16) | escrever |
| 03 | 2.a-d | 40 GFlop/s com FMA vs 20 pela figura | verificar e decidir |
| 03 | 2.e | 0.25 mal explicado, sem ponto atingível | 0.125 ou 0.25 + 2.5/5 GFlop/s |
| 03 | 1.e | falta discussão de precisão | medir erro float vs double |
| 03 | 2.f | conclusão sem GFlop/s medido | 9.6 GFlop/s e marcar no gráfico |
