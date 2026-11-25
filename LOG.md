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