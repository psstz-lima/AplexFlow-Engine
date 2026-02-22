# AplexFlow Engine (MT5 EA)

Expert Advisor para MetaTrader 5 baseado em breakout, pullback Fibonacci e filtros quantitativos opcionais.

Arquivo principal: `AplexFlow_Engine.mq5`

## Stack e Escopo

- Linguagem: MQL5
- Plataforma: MetaTrader 5
- Dependencia: `<Trade/Trade.mqh>` (`CTrade`)
- Estrutura atual do repo: 1 EA (sem modulo externo, sem testes automatizados)

## Como Rodar no MT5

1. Copie `AplexFlow_Engine.mq5` para `MQL5/Experts/`.
2. Compile no MetaEditor.
3. Anexe o EA ao grafico do simbolo desejado.
4. Ajuste os inputs:
   - `Profile`: `Safe` ou `Aggressive`
   - `Mode`: `Core`, `Pullback`, `Quantum`, `Defensive`, `Adaptive`, `LiquidityScalp`
   - `Shield`: `SHIELD_OFF` ou `SHIELD_ON`
   - `DebugMode`: `false/true` para logs detalhados
5. Habilite AutoTrading no terminal.

## Inputs Expostos

- `Profile`:
  - `Safe`: risco menor, menos trades/dia, filtros mais conservadores.
  - `Aggressive`: risco maior, mais trades/dia.
  - Timeframe operacional: detectado automaticamente pelo timeframe do grafico/tester selecionado.
- `Mode`:
  - `Core`: breakout + tendencia + risco (sem fibo/quant).
  - `Pullback`: breakout para criar setup + gatilho em niveis Fibonacci.
  - `Quantum`: `Pullback` + filtros Hurst e Autocorrelacao.
  - `Defensive`: `Pullback` + filtros Hurst e Entropy.
  - `Adaptive`: alterna automaticamente entre `Core/Pullback/Quantum/Defensive` conforme regime de mercado.
  - `LiquidityScalp`: pipeline estrutural `SWING -> SWEEP -> DISPLACEMENT -> MSS -> ENTRY`.
- `Shield`:
  - `SHIELD_ON`: bloqueia novas entradas sob spread spike, ATR shock, candle shock e slippage anormal.
  - `SHIELD_OFF`: desabilita o bloqueio de microestrutura.
- `DebugMode`:
  - habilita logs com tags `[LQ_SWEEP]`, `[LQ_DISP]`, `[LQ_MSS]`, `[LQ_ENTRY]`, `[SHIELD_BLOCK]`, `[RISK_ADJUST]`.

## Fluxo de Trading (Resumo)

1. `OnInit` configura parametros e cria handle do ATR.
2. Em cada `OnTick`:
   - reset diario quando vira o dia;
   - kill switch por drawdown diario;
   - trailing stop das posicoes do EA.
3. Em nova barra (`IsNewBar`):
   - valida dados minimos;
   - classifica regime de mercado e atualiza perfil adaptativo (`Base`, `Trend`, `Choppy`, `Defense`);
  - em `Mode=Adaptive`, escolhe automaticamente o modo de estrategia para a barra;
  - em `Mode=LiquidityScalp`, executa state machine estrutural com confirmacao em `shift=1` (sem repaint);
   - valida spread maximo relativo ao ATR;
   - filtra regime de volatilidade (`ATR` vs `PascalMA_ATR`);
   - detecta tendencia por slope da `PascalMA_Close` e aplica minimo de forca da tendencia;
   - valida breakout;
   - valida qualidade do breakout (corpo minimo e forca de fechamento);
   - se modo com Fibonacci, monta setup e espera toque nas retracoes;
   - aplica filtros quant quando habilitados;
   - envia ordem com lote por risco, SL e TP por ATR.
4. Em `OnTradeTransaction`, resultados sao consolidados por `positionId` somente quando a posicao fecha por completo.

## Risco e Protecoes

- Risco por trade por percentual de equity.
- Ajuste probabilistico de risco por winrate rolling e probabilidade de sequencia de perdas.
- TP inicial por ATR.
- Break-even por gatilho de ATR.
- Trailing somente apos movimento minimo favoravel (em ATR).
- Limites:
  - maximo de trades por dia;
  - maximo de perdas consecutivas;
  - maximo drawdown diario (kill switch).
- Filtro de sessao (janela de horas).
- `onePosPerSymbol`:
  - conta hedging: bloqueia apenas posicoes do proprio EA (mesmo magic).
  - conta netting/exchange: bloqueia qualquer posicao aberta no simbolo.

## Alteracoes Tecnicas Relevantes

- Trailing stop agora modifica SL/TP por `ticket` (`TRADE_ACTION_SLTP`), reduzindo risco de atuar na posicao errada em contas hedging.
- Controle de uma posicao por simbolo considera tipo de conta (hedging vs netting) e magic number.
- Registro de win/loss evita distorcao por fechamento parcial: resultado e consolidado no fechamento total da posicao.
- Adicionados filtros de qualidade de entrada: spread relativo ao ATR, forca minima de tendencia e qualidade do candle de breakout.
- Adicionada estrutura de saida por ATR: TP inicial + break-even + trailing com gatilho de ativacao.
- Adicionado `Mode=Adaptive` para troca automatica entre modos de estrategia por regime de mercado.
- Adicionado `Mode=LiquidityScalp` com state machine estrutural:
  - `LQ_IDLE -> LQ_SWEEP -> LQ_DISPLACED -> LQ_MSS -> LQ_ORDERED`
  - sweep por janela de swing, displacement por ATR, MSS por quebra de microestrutura, entrada market/retest.
- Adicionado modulo `Execution & Regime Shield` (sem API externa) com cooldown por barras.
- Filtros quant no `LiquidityScalp` passaram a atuar como ajuste soft (risco/entrada/TP), evitando bloqueio hard por overfitting.
- Guardrails de estabilidade no adaptativo:
  - confirmacao por N barras;
  - intervalo minimo entre trocas de regime;
  - limite de trocas por dia;
  - fallback automatico para `Defense` sob estresse de drawdown.

## Limitacoes Atuais

- Sem suite de testes automatizados/backtest versionado no repo.
- Sem persistencia em disco do historico de outcomes (reinicio do EA zera estatistica em memoria).
- Parametros internos sao hardcoded em `ConfigureParams()`.

## Sugestao de Validacao

1. Backtest por modo (`Core`, `Pullback`, `Quantum`, `Defensive`) e por `Profile`.
2. Teste separado em conta hedging e netting.
3. Otimizacao dos parametros de qualidade/saida por ativo:
   - `tpAtrMult`
   - `trailStartAtr`
   - `trailAtrMult`
   - `minTrendStrengthAtr`
   - `breakoutBodyAtrMin`
   - `breakoutCloseStrengthMin`
   - `maxSpreadAtrFrac`
4. Verificacao de trailing, fechamento parcial e consolidacao de resultado no journal.
