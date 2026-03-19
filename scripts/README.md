# Scripts

Interface oficial de automacao do projeto.

- `Run-Mt5Backtest.ps1`: runner base de backtest no `mt5-portable`.
- `Import-CustomCsvHistory.ps1`: importacao de CSV para simbolo customizado do MT5.
- `Import-HistoricalFolder.ps1`: importa em lote os CSVs da pasta de historicos para simbolos customizados usados pela pesquisa.
- `Run-AplexFlowResearch.ps1`: bateria principal da arquitetura atual, com sincronizacao automatica do workspace para o `mt5-portable` antes de compilar; agora tambem aceita `-OptimizationMode` e `-PortfolioAnchor`.
- `Search-AdaptiveBasket.ps1`: busca automatizada de perfis do basket, com modos `broad`, `refine`, `dedicated` e `frontier`, ranking por PF/DD, exportacao do melhor preset e pool opcional de workers via `-MaxParallel`; no multi-core o default atual eh `bases` isoladas por worker para evitar lock no historico.
- `Clean-Workspace.ps1`: limpa caches, logs e temporarios de `mt5-workers/` e, opcionalmente, de `mt5-portable/`, preservando reports e presets.

Organizacao:

- `scripts/` fica reservado para entrypoints oficiais e recorrentes.
- `scripts/archive/` guarda runners historicos de tuning e refinamento.
- `scratch/experiments/` continua sendo a area para probes ad hoc e material temporario.

Exemplo de limpeza segura apos rodadas longas de pesquisa:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Clean-Workspace.ps1 -IncludePortable
```
