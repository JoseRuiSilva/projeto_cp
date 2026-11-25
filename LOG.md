# Registo de Alterações (WA1 - Computação Paralela)

## [Commit 1] Estrutura inicial do projeto
- **O que foi feito:** Criação do repositório com os documentos de apoio (docs/) e o código base fornecido pelo docente (MD.cpp, Makefile, inputdata.txt).
- **Objetivo:** Estabelecer o ponto de partida intacto antes de qualquer otimização ou paralelização.

## [Em curso] Setup no Deucalion e Baseline/Profiling
- **Ambiente:** Conta ARM `f202500010hpcvlabuminhoa`, pasta de trabalho `/projects/F202500010HPCVLABUMINHO/2026-2027cp/$USER/wa1`.
- **Transferência:** Repositório `projeto_cp` clonado no Deucalion (temporariamente público para agilizar o clone).
- **Lembrete pendente:** Voltar a colocar o repositório `projeto_cp` como **Privado** no GitHub no fim do trabalho e validar o acesso.
- **Experiência 1 (`job_baseline.sh`):** Compilação do `MD.cpp` original com `GCC/15.2.0` (`-O3 -ffast-math -g -fno-omit-frame-pointer`) num nó `normal-arm`, recolha de métricas base (`perf stat`), linha de validação (`cp_output.txt`) e *profiling* (`perf record` / `perf report`).

## [Commit 2] Baseline medido no Deucalion + Implementação otimizada com OpenMP
- **Baseline original (A64FX, 1 core, GCC 15.2.0 `-O3 -ffast-math`):**
  - Tempo: `325.23 s` | Ciclos: `650.44 G` | Instruções: `216.82 G` | IPC: `0.33` (CPI: `3.00`) | Cache-misses: `918.33 M`.
  - Profiling (`perf record`): `Potential()` = `66.50%`, `computeAccelerations()` = `33.43%` (total `99.93%`).
  - Validação (`cp_output.txt`): `P(t) = 157203191.80025804`, `PE = -51311.54755276` (exato face à referência).
- **Otimizações aplicadas em `src/MD.cpp`:**
  - Substituição de `pow()` e `sqrt()` por multiplicações (`inv_r2`, `inv_r6`).
  - Fusão de `Potential()` dentro de `computeAccelerations()` (elimina o segundo ciclo $O(N^2)$).
  - Layout SoA alinhado a 64 bytes (`alignas(64)`) para vetorização SVE no A64FX.
  - Paralelização OpenMP com buffers privados por thread (`STRIDE` alinhado contra *false sharing*), `schedule(guided)` para balancear o ciclo triangular e redução paralela final (zero *data races*).
- **Alterações no `Makefile`:** Compilação com `g++ -O3 -march=native -ffast-math -fopenmp` e exportação de `OMP_NUM_THREADS`, `OMP_PROC_BIND=close`, `OMP_PLACES=cores`.

## [Experiência 2] Benchmark OpenMP com `schedule(guided)` (Deucalion A64FX)
- **Validação (1T e 48T):** Falhou critério dos 14 dígitos em P(t) devido a -ffast-math (`T = 153.39884091`, `KE = 8096.63469410`, `PE = -51311.54755276`, `P = 157203191.80024040`, erro relativo $1.1 \times 10^{-13}$).
- **Escalabilidade forte (`schedule(guided)`, `OMP_PROC_BIND=close`, `OMP_PLACES=cores`):**
  - `1T`: `44.37 s` (7.3× vs orig.) | IPC `0.53` | Cache-misses `459.0 M`
  - `2T`: `33.10 s` (1.34× vs 1T, Ef. `67.0%`) | IPC `0.53` | Cache-misses `474.7 M`
  - `4T`: `19.34 s` (2.29× vs 1T, Ef. `57.3%`) | IPC `0.54` | Cache-misses `470.0 M`
  - `8T`: `10.38 s` (4.27× vs 1T, Ef. `53.4%`) | IPC `0.56` | Cache-misses `493.3 M`
  - `12T`: `7.10 s` (6.25× vs 1T, Ef. `52.1%`) | IPC `0.57` | Cache-misses `492.4 M`
  - `16T`: `5.41 s` (8.21× vs 1T, Ef. `51.3%`) | IPC `0.59` | Cache-misses `508.9 M`
  - `24T`: `3.68 s` (12.04× vs 1T, Ef. `50.2%`) | IPC `0.62` | Cache-misses `517.1 M`
  - `32T`: `2.81 s` (15.80× vs 1T, Ef. `49.4%`) | IPC `0.65` | Cache-misses `534.8 M`
  - `48T`: `1.94 s` (22.89× vs 1T, **167.8× vs orig.**, Ef. `47.7%`) | IPC `0.71` | Cache-misses `581.5 M`
- **Diagnóstico:** A eficiência converge para ~50% porque `schedule(guided)` no `libgomp` atribui o maior bloco inicial ($\lceil N/P \rceil$) às iterações iniciais (`i = 0..N/P`), que são as mais pesadas no ciclo triangular decrescente.
- **Próxima alteração:** Trocar `schedule(guided)` por `schedule(static, 1)` (distribuição cíclica balanceada sem *overhead* dinâmico).

## [Experiência 3 — Versão Final] Benchmark OpenMP com `schedule(static, 1)` (Deucalion A64FX)
- **Validação (1T e 48T):** Falhou critério dos 14 dígitos em P(t) devido a -ffast-math (`T = 153.39884091`, `KE = 8096.63469410`, `PE = -51311.54755276`, `P = 157203191.80023986`, erro relativo $1.16 \times 10^{-13}$).
- **Escalabilidade forte (`schedule(static, 1)`, `OMP_PROC_BIND=close`, `OMP_PLACES=cores`):**
  - `1T`: `44.80 s` (7.3× vs orig.) | IPC `0.51` | Cache-misses `459.1 M`
  - `2T`: `22.48 s` (1.99× vs 1T, Ef. `99.6%`) | IPC `0.51` | Cache-misses `470.1 M`
  - `4T`: `11.26 s` (3.98× vs 1T, Ef. `99.5%`) | IPC `0.52` | Cache-misses `470.9 M`
  - `8T`: `5.65 s` (7.93× vs 1T, Ef. `99.2%`) | IPC `0.53` | Cache-misses `496.7 M`
  - `12T`: `3.82 s` (11.73× vs 1T, Ef. `97.8%`) | IPC `0.54` | Cache-misses `495.1 M`
  - `16T`: `2.86 s` (15.66× vs 1T, Ef. `97.9%`) | IPC `0.54` | Cache-misses `507.2 M`
  - `24T`: `1.93 s` (23.21× vs 1T, Ef. `96.7%`) | IPC `0.55` | Cache-misses `516.2 M`
  - `32T`: `1.47 s` (30.46× vs 1T, Ef. `95.2%`) | IPC `0.56` | Cache-misses `535.3 M`
  - `48T`: `1.03 s` (43.31× vs 1T, **314.4× vs orig.**, Ef. `90.2%`) | IPC `0.60` | Cache-misses `580.0 M`
- **Ganho face a `schedule(guided)`:** Redução de `1.94 s` para `1.03 s` em 48 threads (eficiência subiu de `47.7%` para `90.2%`), confirmando o balanceamento de carga no ciclo triangular.

## [Experiência 4] Teste de flags de vírgula flutuante e validação final (14 dígitos)
- **Problema detetado:** Com `-ffast-math`, `P(t) = 157203191.80023986` falhava no 14.º dígito face à referência (`157203191.80025804`).
- **Testes em 48 threads (`schedule(static, 1)`):**
  - `-O3 -march=native -fopenmp`: `1.041 s` | `P(t) = 157203191.80025399` (**PASSA**, 14 dígitos exatos).
  - `-O3 -march=native -fopenmp -ffast-math`: `1.031 s` | `P(t) = 157203191.80023986` (falha 14.º dígito).
  - `-O3 -march=native -fopenmp -ffp-contract=off`: `1.148 s` | `P(t) = 157203191.80025628` (passa, mas ~10% mais lento).
- **Decisão:** Remover `-ffast-math` do `Makefile` (`-O3 -march=native -fopenmp`), garantindo conformidade numérica total com perda negligenciável (~10 ms).

## [Experiência 5 — Versão Final Validada] Benchmark OpenMP sem `-ffast-math` (`schedule(static, 1)`, Deucalion A64FX)
- **Compilação:** `g++ -O3 -march=native -fopenmp src/MD.cpp -lm -o md` (`OMP_PROC_BIND=close`, `OMP_PLACES=cores`).
- **Validação (critério 14 dígitos em `P(t)`):** **PASSOU**
  - `1T`: `P(t) = 157203191.80025634` (referência: `157203191.80025804` — 14 dígitos exatos).
  - `48T`: `P(t) = 157203191.80025399` (14 dígitos exatos; `T`, `KE` e `PE` exatos; `Total En.` varia apenas no último dígito).
- **Escalabilidade forte (1 a 48 threads):**
  - `1T`: `44.08 s` (`7.38×` vs orig.) | IPC `0.52` | Inst. `45.74 G` | Cache-misses `458.4 M`
  - `2T`: `21.99 s` (`2.00×` vs 1T, Ef. `100.2%`) | IPC `0.53` | Inst. `46.18 G` | Cache-misses `469.4 M`
  - `4T`: `11.03 s` (`3.99×` vs 1T, Ef. `99.9%`) | IPC `0.54` | Inst. `47.01 G` | Cache-misses `470.7 M`
  - `8T`: `5.54 s` (`7.95×` vs 1T, Ef. `99.4%`) | IPC `0.55` | Inst. `48.69 G` | Cache-misses `497.5 M`
  - `12T`: `3.75 s` (`11.77×` vs 1T, Ef. `98.1%`) | IPC `0.57` | Inst. `50.32 G` | Cache-misses `498.3 M`
  - `16T`: `2.82 s` (`15.63×` vs 1T, Ef. `97.7%`) | IPC `0.57` | Inst. `51.01 G` | Cache-misses `516.3 M`
  - `24T`: `1.91 s` (`23.04×` vs 1T, Ef. `96.0%`) | IPC `0.58` | Inst. `52.70 G` | Cache-misses `534.5 M`
  - `32T`: `1.46 s` (`30.19×` vs 1T, Ef. `94.4%`) | IPC `0.59` | Inst. `54.37 G` | Cache-misses `557.0 M`
  - `48T`: `1.03 s` (`42.64×` vs 1T, **`314.65×` vs orig.**, Ef. `88.8%`) | IPC `0.64` | Inst. `61.42 G` | Cache-misses `610.1 M`