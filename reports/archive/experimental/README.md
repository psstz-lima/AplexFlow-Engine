# Experimental Reports

Indice local para manter `reports/archive/experimental/` navegavel.

## Estrutura

- `2025_full_year/`
  - `presets/`: presets manuais usados na virada para o ano cheio de 2025
  - `searches/`: exports de busca (`*.results.json`, `*.best.set`, warmups)
  - `runs/`: revalidacoes e breakdowns gerados por `Run-AplexFlowResearch.ps1`
- `2026_research/`
  - `presets/`: presets experimentais mantidos fora de `reports/final/`
  - `searches/`: rodadas de frontier, dedicated basket e NASA subset
  - `summaries/`: summaries soltos de probes, groundtruths e full-basket checks
- `infra_smoke/`
  - `outputs/`: smokes, probes de parser, multi-core e outputs pequenos
  - `runs/`: diretorios de runs curtos usados para validar infra

## Convencao

- buscas automatizadas ficam em `searches/` com o mesmo prefixo do run
- revalidacoes completas ficam em `runs/<run_name>/`
- presets criados manualmente ou preservados para pesquisa ficam em `presets/`
- summaries soltos que nao sao um run completo ficam em `summaries/`

## Atalhos uteis

- 2025 full-year frontier:
  - `2025_full_year/searches/frontier_subset_2025_4k10dd_v1.results.json`
  - `2025_full_year/runs/frontier_subset_2025_4k10dd_v1_full_year_reval/`
- 2025 drawdown defense:
  - `2025_full_year/runs/frontier_2025_survival_v1_defense_reval/`
  - `2025_full_year/runs/frontier_2025_survival_v1_defense_v2_reval/`
- 2025 US500 dedicado:
  - `2025_full_year/searches/us500_only_2025_dedicated_v1.results.json`
  - `2025_full_year/runs/us500_only_2025_balanced_full_year/`
- 2026 dedicated subset:
  - `2026_research/searches/dedicated_subset_search_v3_base.results.json`
  - `2026_research/searches/nasa_dedicated_subset_v3.results.json`
- infra multi-core:
  - `infra_smoke/outputs/multi_core_smoke_v2.results.json`

## Notes

- Warmups `*.worker-XX.warmup.summary.json` ficam ao lado do search principal para facilitar troubleshooting do pool multi-core.
- `mt5-workers/*/reports/` preserva os HTML detalhados apontados pelos JSONs; caches e logs podem ser limpos sem perder os summaries.
