# AplexFlow Engine

Framework quantitativo adaptativo para MetaTrader 5, com foco em:

- trading ao vivo
- pesquisa continua
- otimizacao automatizada
- evolucao de presets

O entrypoint do EA fica em `AplexFlow_Engine.mq5` e contem apenas:

- `OnInit()`
- `OnTick()`
- `OnTradeTransaction()`

Toda a logica operacional mora na arvore modular `AplexFlow/`.

## Estrutura

- `AplexFlow/core/`: contexto, engine principal e state machine
- `AplexFlow/regime/`: classificacao de regime
- `AplexFlow/liquidity/`: heatmap, sweep e trap detection
- `AplexFlow/strategies/`: breakout, momentum e mean reversion
- `AplexFlow/models/`: volatilidade, edge scoring e online learning
- `AplexFlow/risk/`: risco, convex sizing e containment
- `AplexFlow/portfolio/`: correlacao e alocacao
- `AplexFlow/execution/`: execucao, clustering e order management
- `AplexFlow/filters/`: microestrutura, spread e sessoes
- `AplexFlow/profit/`: payoff assimetrico, break-even e trailing
- `AplexFlow/telemetry/`: metricas, performance e degradacao
- `AplexFlow/research/`: backtest, ranking, parameter search e evolution
- `mt5-portable/`: ambiente MT5 isolado para compilar, importar dados e testar
- `scripts/`: entrypoints oficiais de importacao, backtest e pesquisa
- `scripts/archive/`: runners historicos preservados fora da interface principal
- `mt5-workers/`: clones locais do `mt5-portable` para pesquisa multi-core; sao regeneraveis
- `reports/final/`: artefatos validados mais recentes
- `reports/archive/`: historico de tuning, fronteiras e diagnosticos

## Universo e premissas

- Timeframe decisorio: `M5`
- Confirmacao microestrutural: `M1`
- Ativos alvo: `EURUSD, GBPUSD, USDJPY, AUDUSD, USDCAD, XAUUSD, US500`
- Capital inicial de referencia: `200 USD`
- Meta de drawdown de equity: aproximadamente `10%`
- Prioridade: sobrevivencia e edge estatistica acima de frequencia

## Componentes principais

- Regime engine: `STRONG_TREND`, `WEAK_TREND`, `RANGE`, `VOLATILITY_EXPANSION`, `DEFENSIVE`
- Liquidity intelligence: equal highs/lows, swings, session highs/lows, previous day highs/lows e order blocks
- Opportunity layer: sinais de breakout, momentum, mean reversion e liquidity sweep
- Edge scoring: combina regime, liquidez, volatilidade, momentum, sessao, spread e confirmacao estrutural
- Online learning: ajusta pesos apos cada trade com memoria rolling
- Convex sizing: escada de risco por tamanho de conta, confianca e volatilidade
- Portfolio allocator: reduz exposicao correlacionada
- Asymmetric profit engine: TP parcial, runner, break-even e trailing stop
- Risk containment: drawdown maximo, limite diario, profit lock semanal e degradacao de estrategia

## Inputs relevantes

- `InpSymbols`: cesta de ativos operados
- `InpDecisionTimeframe`, `InpMicrostructureTimeframe`
- `InpEnableSymbolAlphaProfiles`
- `InpEnableDedicatedSymbolAlphas`
- `InpEnableDedicatedXauAlpha`, `InpEnableDedicatedUs500Alpha`
- `InpEnableDedicatedXauReclaimAlpha`, `InpEnableDedicatedUs500ImpulsePullbackAlpha`
- `InpEdgeThreshold`, `InpHardBlockThreshold`
- `InpMaxEquityDrawdownPct`, `InpMaxDailyLossPct`, `InpMaxPortfolioRiskPct`
- `InpEnableCorrelationHardBlock`, `InpCorrelationHardBlock`, `InpMaxCorrelatedPositions`
- `InpTp1R`, `InpTp2R`, `InpTp3R`
- `InpBreakEvenAtR`, `InpTrailStartR`, `InpTrailAtrMult`
- `InpTrailStepAtr`, `InpMinStopUpdateSeconds`
- `InpBacktestLatencyMs`
- `InpSymbolDegradationWindow`, `InpMinSymbolExpectancyR`, `InpSymbolMinProfitFactor`, `InpSymbolCooldownMinutes`
- `InpEnableDrawdownDefense`, `InpDefenseActivationDrawdownPct`, `InpDefenseMinSymbolTrades`
- `InpDefenseMinSymbolExpectancyR`, `InpDefenseMinSymbolProfitFactor`
- `InpEnableTelemetry`, `InpEnableEvolutionExport`

## Compilacao

Fonte principal:

- `AplexFlow_Engine.mq5`

Build portavel:

- `mt5-portable/MQL5/Experts/AplexFlow/AplexFlow_Engine.mq5`
- `mt5-portable/MQL5/Experts/AplexFlow/AplexFlow_Engine.ex5`

O binario da raiz pode ser sincronizado a partir do build portavel quando o compile estiver validado.

## Pesquisa e backtest

Historico CSV informado:

- `D:/ps_st/Downloads/Dados Historicos`

Pipeline principal:

- importar historico customizado: `scripts/Import-HistoricalFolder.ps1`
- executar pesquisa/backtest: `scripts/Run-AplexFlowResearch.ps1`
- buscar presets de portfolio: `scripts/Search-AdaptiveBasket.ps1`
- limpar caches e temporarios locais: `scripts/Clean-Workspace.ps1`

Organizacao local:

- `scripts/` fica reservado para automacao oficial e recorrente
- `scripts/archive/` concentra buscas antigas, refinamentos e probes historicos
- `reports/final/` guarda os baselines e presets de referencia
- `reports/archive/` guarda rounds intermediarios de tuning e diagnostico

Exemplo de smoke test com atraso de execucao de `200 ms`:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Run-AplexFlowResearch.ps1 `
  -RunName smoke_xau_csv `
  -Symbols XAUUSD `
  -PortfolioAnchor XAUUSD `
  -UseImportedHistory `
  -FromDate 2026.01.01 `
  -ToDate 2026.03.11 `
  -Deposit 200 `
  -ExecutionMode 200
```

Exemplo de busca multi-core com `4` workers paralelos:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Search-AdaptiveBasket.ps1 `
  -RunPrefix multi_core_probe `
  -ProfileMode dedicated `
  -Symbols XAUUSD,US500 `
  -TrainFromDate 2026.01.01 `
  -TrainToDate 2026.01.10 `
  -ValidateFromDate 2026.01.01 `
  -ValidateToDate 2026.01.20 `
  -TopToValidate 1 `
  -ExecutionMode 200 `
  -MaxParallel 4 `
  -OutputPath reports\archive\experimental\infra_smoke\outputs\multi_core_probe.results.json
```

Exemplo de busca de fronteira para a meta `4k / 10dd` no subset carregador:

```powershell
powershell -ExecutionPolicy Bypass -File scripts\Search-AdaptiveBasket.ps1 `
  -RunPrefix frontier_subset_4k10dd `
  -ProfileMode frontier `
  -Symbols USDJPY,USDCAD,XAUUSD,US500 `
  -TrainFromDate 2026.01.01 `
  -TrainToDate 2026.01.31 `
  -ValidateFromDate 2026.01.01 `
  -ValidateToDate 2026.03.11 `
  -TopToValidate 3 `
  -ExecutionMode 200 `
  -MaxParallel 4 `
  -OutputPath reports\archive\experimental\2026_research\searches\frontier_subset_4k10dd.results.json
```

Observacao importante:

- um backtest unico do MT5 continua usando apenas `1` agente local; para acender varios cores no framework use `Search-AdaptiveBasket.ps1 -MaxParallel N`
- se quiser usar os agentes do proprio otimizador do MT5, os runners oficiais agora aceitam `-OptimizationMode slow_complete` ou `-OptimizationMode genetic`
- a primeira execucao paralela clona `mt5-portable` em `mt5-workers/`, entao o bootstrap inicial pode demorar mais do que as rodadas seguintes
- por padrao os workers agora usam `bases/` isoladas para evitar lock de historico entre processos MT5; isso deixa o bootstrap inicial mais pesado, mas elimina falsos `final_balance = 0` causados por `file opening error [32]`
- se quiser privilegiar bootstrap mais rapido e aceitar mais risco de lock no historico, use `-WorkerBasesMode shared`
- `-Symbols` agora aceita tanto array PowerShell quanto lista separada por virgulas
- o search multi-core reenfileira automaticamente runs invalidos que terminam com `final_balance = 0`, caso o worker ainda esteja completando warmup de historico

## Observacoes operacionais

- O compile do MetaEditor pode retornar `exit code 1` mesmo com `0 errors, 0 warnings`; o log de compilacao e a fonte da verdade.
- O projeto agora tem uma camada opt-in de defesa adaptativa por drawdown para esfriar simbolos fracos quando o portfolio entra em stress; ela fica desligada por default e eh controlada por `InpEnableDrawdownDefense`.
- O trailing stop foi endurecido com `InpTrailStepAtr` e `InpMinStopUpdateSeconds` para reduzir excesso de modificacoes em ambiente live e em backtests tick-by-tick.
- O basket agora inclui degradacao por simbolo para esfriar ativos com expectativa/pf ruins antes que contaminem o portfolio.
- O research runner sincroniza automaticamente a arvore do workspace para `mt5-portable` antes de cada compile, evitando drift entre codigo editado e codigo testado.
- O allocator agora pode aplicar bloqueio duro de exposicao altamente correlacionada para impedir empilhamento de risco parecido no basket.
- O preset default foi calibrado para um modo growth com mais espacamento horizontal do portfolio; o preset estrito com `DD 9.93%` foi preservado em `reports/final/AplexFlow_Engine.strict_dd_9_93.set`.
- O trilho robusto historico promovido para o subset `USDJPY, USDCAD, XAUUSD, US500` continua arquivado em `reports/final/AplexFlow_Engine.robust_subset_usdjpy_usdcad_xau_us500_v1.set`, mas a revalidacao desta branch em `2026.03.17` apontou a referencia pratica atual em `reports/archive/experimental/2026_research/searches/dedicated_subset_search_v3_base.results.json`: perfil `us500_only_robust`, `final_balance 214.87`, `PF 1.42` e `equity_dd 9.54%`.
- O framework agora tem uma camada experimental de perfis de alpha por ativo (`InpEnableSymbolAlphaProfiles`), pronta para pesquisa futura, mas ainda nao promovida a default porque degradou o periodo `2026.01.01 -> 2026.03.11`.
- Uma nova camada opt-in de alphas dedicadas por simbolo (`InpEnableDedicatedSymbolAlphas`) foi adicionada para pesquisa de `XAUUSD` e `US500` sem contaminar o preset default; os artefatos experimentais agora ficam agrupados por fase em `reports/archive/experimental/2025_full_year/`, `reports/archive/experimental/2026_research/` e `reports/archive/experimental/infra_smoke/`.
- A camada dedicada agora pode ser ligada por simbolo com `InpEnableDedicatedXauAlpha` e `InpEnableDedicatedUs500Alpha`, o que permite pesquisar `US500` dedicado sem forcar `XAUUSD` dedicado no mesmo basket.
- As extensoes mais experimentais ficaram separadas em flags proprias: `InpEnableDedicatedXauReclaimAlpha` segue disponivel para pesquisa e `InpEnableDedicatedUs500ImpulsePullbackAlpha` ficou `false` por default ate provar edge fora do standalone.
- O script `scripts/Search-AdaptiveBasket.ps1` agora suporta o modo `dedicated`, focado em trilhas opt-in de `US500` e combinacoes experimentais com `XAUUSD`.
- `scripts/Run-AplexFlowResearch.ps1` agora aceita `-PortfolioAnchor` para forcar o simbolo condutor do backtest de portfolio quando quisermos pesquisar um carrier especifico sem alterar a ordem de `-Symbols`.
- Os artefatos experimentais continuam em `reports/archive/experimental/`; o indice local `reports/archive/experimental/README.md` resume a convencao `presets/`, `searches/`, `runs/` e `summaries/` para evitar que a pasta vire um dump opaco.
- O framework ja suporta exportacao de presets evoluidos e ranking de pesquisa, mas a qualidade da estrategia ainda depende de novas rodadas de calibracao multiativo.
