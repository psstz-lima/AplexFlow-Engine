#ifndef APLEXFLOW_CORE_ENGINE_MQH
#define APLEXFLOW_CORE_ENGINE_MQH

#include "Context.mqh"
#include "StateMachine.mqh"
#include "SymbolAlphaProfileEngine.mqh"
#include "../regime/MarketRegimeEngine.mqh"
#include "../liquidity/LiquidityHeatmapEngine.mqh"
#include "../liquidity/LiquiditySweepEngine.mqh"
#include "../liquidity/LiquidityTrapDetector.mqh"
#include "../strategies/VolatilityBreakoutEngine.mqh"
#include "../strategies/MomentumContinuationEngine.mqh"
#include "../strategies/MeanReversionEngine.mqh"
#include "../strategies/XauSessionBreakoutEngine.mqh"
#include "../strategies/XauLiquidityReclaimEngine.mqh"
#include "../strategies/Us500TrendDriveEngine.mqh"
#include "../strategies/Us500ImpulsePullbackEngine.mqh"
#include "../models/VolatilityForecastModel.mqh"
#include "../models/EdgeScoringModel.mqh"
#include "../models/OnlineLearningModel.mqh"
#include "../risk/RiskManager.mqh"
#include "../risk/ConvexPositionSizing.mqh"
#include "../risk/RiskContainmentSystem.mqh"
#include "../portfolio/PortfolioAllocator.mqh"
#include "../portfolio/CorrelationManager.mqh"
#include "../execution/ExecutionOptimizer.mqh"
#include "../execution/TradeClusteringEngine.mqh"
#include "../execution/OrderManager.mqh"
#include "../filters/MarketMicrostructureFilter.mqh"
#include "../filters/SpreadLiquidityGuard.mqh"
#include "../filters/SessionIntelligence.mqh"
#include "../profit/AsymmetricProfitEngine.mqh"
#include "../telemetry/TelemetryEngine.mqh"
#include "../telemetry/PerformanceTracker.mqh"
#include "../telemetry/DegradationDetector.mqh"
#include "../research/BacktestRunner.mqh"
#include "../research/ParameterSearch.mqh"
#include "../research/StrategyRanking.mqh"
#include "../research/EvolutionEngine.mqh"

struct AFSignalIntent
  {
   bool active;
   ulong seedTicket;
   string symbol;
   string comment;
   AFMarketRegime regime;
   AFSignalCandidate candidate;
   double volume;
   datetime created;
  };

struct AFSymbolProcessSlot
  {
   int index;
   double priority;
  };

class AplexFlowEngine
  {
private:
   AFConfig                  m_config;
   AFSymbolState             m_symbolStates[AF_MAX_SYMBOLS];
   AFPositionPlan            m_plans[AF_MAX_ACTIVE_PLANS];
   AFSignalIntent            m_intents[AF_MAX_ACTIVE_PLANS];
   AFPortfolioSnapshot       m_portfolio;
   AplexFlowStateMachine     m_stateMachine;
   SymbolAlphaProfileEngine  m_symbolProfiles;
   MarketRegimeEngine        m_regimeEngine;
   LiquidityHeatmapEngine    m_heatmapEngine;
   LiquiditySweepEngine      m_sweepEngine;
   LiquidityTrapDetector     m_trapDetector;
   VolatilityBreakoutEngine  m_breakoutEngine;
   MomentumContinuationEngine m_momentumEngine;
   MeanReversionEngine       m_meanReversionEngine;
   XauSessionBreakoutEngine  m_xauBreakoutEngine;
   XauLiquidityReclaimEngine m_xauReclaimEngine;
   Us500TrendDriveEngine     m_us500DriveEngine;
   Us500ImpulsePullbackEngine m_us500PullbackEngine;
   VolatilityForecastModel   m_volatilityModel;
   EdgeScoringModel          m_edgeModel;
   OnlineLearningModel       m_learningModel;
   RiskManager               m_riskManager;
   ConvexPositionSizing      m_positionSizer;
   RiskContainmentSystem     m_riskContainment;
   PortfolioAllocator        m_portfolioAllocator;
   CorrelationManager        m_correlationManager;
   ExecutionOptimizer        m_executionOptimizer;
   TradeClusteringEngine     m_tradeClustering;
   OrderManager              m_orderManager;
   MarketMicrostructureFilter m_microstructureFilter;
   SpreadLiquidityGuard      m_spreadGuard;
   SessionIntelligence       m_sessionIntelligence;
   AsymmetricProfitEngine    m_profitEngine;
   TelemetryEngine           m_telemetry;
   PerformanceTracker        m_performance;
   DegradationDetector       m_degradation;
   BacktestRunner            m_backtestRunner;
   EvolutionEngine           m_evolution;
   bool                      m_initialized;
   int                       m_closedTrades;

private:
   void                      ResetContainers(void)
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         m_plans[i].active=false;
         m_plans[i].positionId=0;
         m_plans[i].orderTicket=0;
         m_plans[i].symbol="";
         m_plans[i].lastManagedStop=0.0;
         m_plans[i].lastStopUpdateTime=0;
         m_intents[i].active=false;
         m_intents[i].seedTicket=0;
         m_intents[i].symbol="";
         m_intents[i].comment="";
         m_intents[i].volume=0.0;
         m_intents[i].created=0;
        }
     }

   void                      InitializeSymbolStates(void)
     {
      for(int i=0; i<AF_MAX_SYMBOLS; ++i)
        {
         m_symbolStates[i].symbol="";
         m_symbolStates[i].enabled=false;
         m_symbolStates[i].lastDecisionBar=0;
         m_symbolStates[i].regime=DEFENSIVE;
         m_symbolStates[i].lastAtr=0.0;
         m_symbolStates[i].lastScore=0.0;
         m_symbolStates[i].performance.trades=0;
         m_symbolStates[i].performance.wins=0;
         m_symbolStates[i].performance.losses=0;
         m_symbolStates[i].performance.grossProfit=0.0;
         m_symbolStates[i].performance.grossLoss=0.0;
         m_symbolStates[i].performance.expectancyR=0.0;
         m_symbolStates[i].performance.blockedUntil=0;
         m_symbolStates[i].tradesToday=0;
         m_symbolStates[i].lossesToday=0;
         for(int j=0; j<AF_MAX_STRATEGIES; ++j)
           {
            m_symbolStates[i].clusterEntries[j]=0;
            m_symbolStates[i].clusterIds[j]=0;
            m_symbolStates[i].strategyBlockedUntil[j]=0;
           }
        }

      for(int i=0; i<m_config.symbolCount; ++i)
        {
         m_symbolStates[i].symbol=m_config.symbols[i];
         m_symbolStates[i].enabled=true;
         SymbolSelect(m_symbolStates[i].symbol,true);
        }
     }

   int                       FindSymbolIndex(const string symbol) const
     {
      for(int i=0; i<m_config.symbolCount; ++i)
        {
         if(m_symbolStates[i].symbol==symbol)
            return i;
        }
      return -1;
     }

   int                       FindPlanByPosition(const ulong positionId) const
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(m_plans[i].active && m_plans[i].positionId==positionId)
            return i;
        }
      return -1;
     }

   int                       FindFreePlanSlot(void) const
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(!m_plans[i].active)
            return i;
        }
      return -1;
     }

   int                       FindIntentByComment(const string symbol,const string comment) const
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(m_intents[i].active && m_intents[i].symbol==symbol && m_intents[i].comment==comment)
            return i;
        }
      return -1;
     }

   int                       ActivePlansCount(void) const
     {
      int count=0;
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(m_plans[i].active)
            ++count;
        }
      return count;
     }

   int                       ActiveCarrierPlansCount(void) const
     {
      int count=0;
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(!m_plans[i].active)
            continue;
         if(AFIsDedicatedCarrierStrategy(m_plans[i].strategy) &&
            AFCarrierReserveEligibleSymbol(m_config,m_plans[i].symbol))
            ++count;
        }
      return count;
     }

   double                    SymbolPriority(const AFSymbolState &state) const
     {
      double priority=0.0;
      if(AFIsXauSymbol(state.symbol))
         priority+=0.30;
      else if(AFIsUs500Symbol(state.symbol))
         priority+=0.26;
      else if(state.symbol=="USDJPY" || state.symbol=="USDCAD")
         priority+=0.08;
      else if(state.symbol=="AUDUSD")
         priority-=0.08;
      else if(state.symbol=="EURUSD" || state.symbol=="GBPUSD")
         priority-=0.12;

      if(state.performance.trades>0)
        {
         const double pf=AFProfitFactor(state.performance);
         priority+=AFClamp((pf-1.0)*0.18,-0.12,0.18);
         priority+=AFClamp(state.performance.expectancyR*0.20,-0.10,0.10);
        }

      priority-=AFClamp((double)state.lossesToday*0.03,0.0,0.09);
      priority+=AFClamp(state.lastScore-0.55,-0.08,0.08);
      return priority;
     }

   int                       BuildProcessQueue(AFSymbolProcessSlot &queue[])
     {
      ArrayResize(queue,0);
      for(int i=0; i<m_config.symbolCount; ++i)
        {
         if(!m_stateMachine.IsNewDecisionBar(m_symbolStates[i],m_config.decisionTf))
            continue;
         const int slot=ArraySize(queue);
         ArrayResize(queue,slot+1);
         queue[slot].index=i;
         queue[slot].priority=SymbolPriority(m_symbolStates[i]);
        }

      const int count=ArraySize(queue);
      for(int i=0; i<count-1; ++i)
        {
         int best=i;
         for(int j=i+1; j<count; ++j)
           {
            if(queue[j].priority>queue[best].priority)
               best=j;
           }
         if(best!=i)
           {
            const AFSymbolProcessSlot temp=queue[i];
            queue[i]=queue[best];
            queue[best]=temp;
           }
        }
      return count;
     }

   double                    ActiveRiskPct(void)
     {
      return m_riskManager.TotalOpenRiskPct(m_plans,AF_MAX_ACTIVE_PLANS,AccountInfoDouble(ACCOUNT_BALANCE));
     }

   void                      RefreshPortfolio(void)
     {
      m_riskContainment.Refresh(m_config,m_portfolio);
      m_portfolio.totalOpenRiskPct=ActiveRiskPct();
     }

   double                    PlanRiskMoney(const AFPositionPlan &plan) const
     {
      const double tickSize=SymbolInfoDouble(plan.symbol,SYMBOL_TRADE_TICK_SIZE);
      const double tickValue=SymbolInfoDouble(plan.symbol,SYMBOL_TRADE_TICK_VALUE);
      if(tickSize<=0.0 || tickValue<=0.0)
         return 0.0;
      const double stopDistance=MathAbs(plan.entry-plan.initialStop);
      return (stopDistance/tickSize)*tickValue*plan.volumeInitial;
     }

   double                    PositionRealizedProfit(const ulong positionId) const
     {
      if(!HistorySelectByPosition(positionId))
         return 0.0;
      double total=0.0;
      const int deals=HistoryDealsTotal();
      for(int i=0; i<deals; ++i)
        {
         const ulong dealTicket=HistoryDealGetTicket(i);
         if(dealTicket==0)
            continue;
         total+=HistoryDealGetDouble(dealTicket,DEAL_PROFIT);
         total+=HistoryDealGetDouble(dealTicket,DEAL_SWAP);
         total+=HistoryDealGetDouble(dealTicket,DEAL_COMMISSION);
        }
      return total;
     }

   void                      ApplySymbolOutcome(AFSymbolState &state,const AFTradeOutcome &outcome)
     {
      state.performance.trades++;
      if(outcome.profit>=0.0)
        {
         state.performance.wins++;
         state.performance.grossProfit+=outcome.profit;
        }
      else
        {
         state.performance.losses++;
         state.performance.grossLoss+=MathAbs(outcome.profit);
        }

      state.performance.expectancyR=
         (((state.performance.expectancyR*(state.performance.trades-1))+outcome.profitR)/(double)state.performance.trades);
     }

   void                      RememberIntent(const string symbol,const AFMarketRegime regime,const AFSignalCandidate &candidate,const double volume,const ulong ticket)
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(!m_intents[i].active)
           {
            m_intents[i].active=true;
            m_intents[i].seedTicket=ticket;
            m_intents[i].symbol=symbol;
            m_intents[i].comment=AFComment(candidate);
            m_intents[i].regime=regime;
            m_intents[i].candidate=candidate;
            m_intents[i].volume=volume;
            m_intents[i].created=TimeCurrent();
            return;
           }
        }
     }

   void                      ExpireIntents(void)
     {
      const datetime now=TimeCurrent();
      const int expirySec=PeriodSeconds(m_config.decisionTf)*MathMax(1,m_config.pendingExpiryBars+1);
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(m_intents[i].active && (now-m_intents[i].created)>expirySec)
            m_intents[i].active=false;
        }
     }

   void                      PrepareTargets(const AFConfig &config,const string symbol,AFSignalCandidate &candidate) const
     {
      const double directionSign=(double)AFDirectionSign(candidate.direction);
      const double riskDistance=MathAbs(candidate.entry-candidate.stop);
      candidate.target1=AFNormalizePrice(symbol,candidate.entry+(directionSign*riskDistance*config.tp1R));
      candidate.target2=AFNormalizePrice(symbol,candidate.entry+(directionSign*riskDistance*config.tp2R));
      candidate.target3=AFNormalizePrice(symbol,candidate.entry+(directionSign*riskDistance*config.tp3R));
      candidate.stop=AFNormalizePrice(symbol,candidate.stop);
     }

   double                    RegimeAlignment(const AFSignalCandidate &candidate,const AFMarketRegime regime,const double slope,const double atr) const
     {
      const double slopeNorm=(atr>0.0 ? slope/atr : 0.0);
      if(candidate.strategy==STRATEGY_MEAN_REVERSION)
         return ((regime==RANGE || regime==DEFENSIVE) ? 0.95 : 0.35);
      if(candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
         return ((regime==RANGE || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION) ? 0.90 : 0.55);
      if(candidate.strategy==STRATEGY_US500_IMPULSE_PULLBACK)
         return ((regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION) ? 0.96 : 0.55);
      if(candidate.direction==DIR_LONG && slopeNorm>0.0 && (regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION))
         return 0.95;
      if(candidate.direction==DIR_SHORT && slopeNorm<0.0 && (regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION))
         return 0.95;
      return (regime==VOLATILITY_EXPANSION ? 0.70 : 0.40);
     }

   double                    LiquidityFeature(const AFSignalCandidate &candidate,const AFLiquidityMap &map,const double atr) const
     {
      if(atr<=0.0)
         return 0.0;
      double reference=0.0;
      if(candidate.direction==DIR_LONG)
         reference=(map.nearestBelow>0.0 ? map.nearestBelow : map.prevDayLow);
      else if(candidate.direction==DIR_SHORT)
         reference=(map.nearestAbove>0.0 ? map.nearestAbove : map.prevDayHigh);
      if(reference<=0.0)
         return AFClamp(map.heatScore/2.0,0.2,1.0);
      const double distance=MathAbs(candidate.entry-reference)/atr;
      return AFClamp(1.0-(distance/2.5),0.15,1.0);
     }

   double                    MomentumFeature(const AFSignalCandidate &candidate,const double slope,const double atr,const MqlRates &decisionRates[]) const
     {
      if(atr<=0.0)
         return 0.0;
      const double slopeNorm=(slope/atr)*(double)AFDirectionSign(candidate.direction);
      const double closeStrength=(candidate.direction==DIR_LONG ? AFCloseStrength(decisionRates[1]) : 1.0-AFCloseStrength(decisionRates[1]));
      return AFClamp((0.5*AFClamp(slopeNorm*4.0,0.0,1.0))+(0.5*closeStrength),0.0,1.0);
     }

   double                    StructureFeature(const AFSignalCandidate &candidate,const double trapScore,const MqlRates &decisionRates[]) const
     {
      if(candidate.strategy==STRATEGY_LIQUIDITY_SWEEP || candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
         return AFClamp(trapScore,0.0,1.0);
      const double closeStrength=(candidate.direction==DIR_LONG ? AFCloseStrength(decisionRates[1]) : 1.0-AFCloseStrength(decisionRates[1]));
      return AFClamp(closeStrength,0.0,1.0);
     }

   void                      PopulateFeatures(const AFConfig &config,const AFSignalCandidate &rawCandidate,const AFMarketRegime regime,const AFLiquidityMap &map,const AFVolatilityForecast &forecast,const AFMicrostructureState &micro,const AFSessionState &session,const double slope,const double atr,const double trapScore,const MqlRates &decisionRates[],AFSignalCandidate &candidate)
     {
      candidate=rawCandidate;
      candidate.features[0]=RegimeAlignment(candidate,regime,slope,atr);
      candidate.features[1]=LiquidityFeature(candidate,map,atr);
      candidate.features[2]=((candidate.strategy==STRATEGY_MEAN_REVERSION || candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM) ? 1.0-forecast.breakoutProbability : forecast.breakoutProbability);
      candidate.features[3]=MomentumFeature(candidate,slope,atr,decisionRates);
      candidate.features[4]=session.activityScore;
      candidate.features[5]=AFClamp(1.0-(micro.spreadAtrFrac/MathMax(0.01,config.maxSpreadAtrFrac)),0.0,1.0);
      candidate.features[6]=StructureFeature(candidate,trapScore,decisionRates);
     }

   bool                      ScoreAndApproveCandidate(const AFConfig &config,const string symbol,AFSymbolState &state,const AFMarketRegime regime,const AFVolatilityForecast &forecast,const AFMicrostructureState &micro,const AFSessionState &session,AFSignalCandidate &candidate,string &reason)
     {
      if(m_stateMachine.IsStrategyBlocked(state,candidate.strategy,TimeCurrent()))
        {
         reason=StringFormat("%s strategy on cooldown",AFStrategyCode(candidate.strategy));
         return false;
        }

      double weights[];
      m_learningModel.Snapshot(weights);
      m_edgeModel.Score(weights,candidate);
      const double strategyBias=m_symbolProfiles.StrategyEdgeBias(config,symbol,candidate.strategy);
      const double dedicatedBias=(AFDedicatedAlphaEnabled(config,symbol) ? m_symbolProfiles.DedicatedStrategyBias(symbol,candidate) : 0.0);
      candidate.edgeScore=AFClamp(candidate.edgeScore+strategyBias+dedicatedBias,0.0,1.0);
      candidate.confidence=AFClamp(candidate.confidence+strategyBias+dedicatedBias,0.0,1.0);
      state.lastScore=candidate.edgeScore;
      if(candidate.edgeScore<config.edgeThreshold)
        {
         reason=StringFormat("edge %.2f below threshold %.2f",candidate.edgeScore,config.edgeThreshold);
         return false;
        }
      if(AFDedicatedUs500Enabled(config) &&
         AFIsUs500Symbol(symbol) &&
         candidate.strategy==STRATEGY_US500_OPEN_DRIVE &&
         candidate.edgeScore<MathMax(0.80,config.edgeThreshold+0.10))
        {
         reason=StringFormat("US500 open drive edge %.2f below dedicated floor",candidate.edgeScore);
         return false;
        }

      candidate.clusterId=m_tradeClustering.BuildClusterId(iTime(symbol,config.decisionTf,1),candidate.strategy);
      if(!m_tradeClustering.Allow(config,state,candidate,forecast,reason))
         return false;

      candidate.riskMultiplier*=m_tradeClustering.ScaleInRiskMultiplier(state,candidate);
      m_executionOptimizer.Select(config,micro,session,forecast,candidate);

      double bid=0.0;
      double ask=0.0;
      if(candidate.executionMethod==EXEC_MARKET && AFGetBidAsk(symbol,bid,ask))
         candidate.entry=(candidate.direction==DIR_LONG ? ask : bid);

      PrepareTargets(config,symbol,candidate);
      return true;
     }

   bool                      BuildSignals(const AFConfig &config,const string symbol,AFSymbolState &state,const MqlRates &decisionRates[],const MqlRates &microRates[],const AFMarketRegime regime,const AFLiquidityMap &map,const AFVolatilityForecast &forecast,const AFMicrostructureState &micro,const AFSessionState &session,const double atr,const double slope,AFSignalCandidate &bestCandidate,string &reason)
     {
      AFResetCandidate(bestCandidate);
      const bool isUs500=(AFDedicatedUs500Enabled(config) && AFIsUs500Symbol(symbol));
      AFSignalCandidate candidates[AF_MAX_CANDIDATES];
      for(int i=0; i<AF_MAX_CANDIDATES; ++i)
         AFResetCandidate(candidates[i]);

      int candidateCount=0;
      AFSignalCandidate raw;
      AFResetCandidate(raw);

      if(m_xauReclaimEngine.Evaluate(config,symbol,regime,map,forecast,session,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         const double trapScore=m_trapDetector.ScoreTrap(raw,microRates);
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,trapScore,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(m_xauBreakoutEngine.Evaluate(config,symbol,regime,forecast,session,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.62,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(m_us500DriveEngine.Evaluate(config,symbol,regime,forecast,session,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.60,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(m_us500PullbackEngine.Evaluate(config,symbol,regime,forecast,session,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.68,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(!isUs500 && m_breakoutEngine.Evaluate(config,regime,forecast,map,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.50,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(!isUs500 && m_momentumEngine.Evaluate(config,regime,decisionRates,microRates,atr,slope,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.55,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(m_meanReversionEngine.Evaluate(config,regime,map,decisionRates,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,0.60,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      AFResetCandidate(raw);
      if(!isUs500 && m_sweepEngine.Evaluate(config,decisionRates,map,atr,raw) && candidateCount<AF_MAX_CANDIDATES)
        {
         const double trapScore=m_trapDetector.ScoreTrap(raw,microRates);
         PopulateFeatures(config,raw,regime,map,forecast,micro,session,slope,atr,trapScore,decisionRates,candidates[candidateCount]);
         ++candidateCount;
        }

      if(candidateCount<=0)
        {
         reason="no strategy candidate";
         return false;
        }

      double bestScore=-1.0;
      double bestDedicatedScore=-1.0;
      AFSignalCandidate bestDedicatedCandidate;
      AFResetCandidate(bestDedicatedCandidate);
      for(int i=0; i<candidateCount; ++i)
        {
         string localReason="";
         if(!ScoreAndApproveCandidate(config,symbol,state,regime,forecast,micro,session,candidates[i],localReason))
            continue;
         if(candidates[i].dedicatedAlpha &&
            AFCarrierReserveEligibleSymbol(config,symbol) &&
            candidates[i].edgeScore>bestDedicatedScore)
           {
            bestDedicatedScore=candidates[i].edgeScore;
            bestDedicatedCandidate=candidates[i];
           }
         if(candidates[i].edgeScore>bestScore)
           {
            bestScore=candidates[i].edgeScore;
            bestCandidate=candidates[i];
           }
        }

      if(bestDedicatedScore>=0.0 &&
         (bestScore<0.0 || bestDedicatedScore>=(bestScore-0.03)))
        {
         bestCandidate=bestDedicatedCandidate;
         return true;
        }

      if(bestScore<0.0)
        {
         reason="candidates rejected by edge/risk filters";
         return false;
        }
      return true;
     }

   void                      ProcessSymbol(AFSymbolState &state)
     {
      if(!state.enabled)
         return;

      if(m_stateMachine.IsSymbolBlocked(state,TimeCurrent()))
        {
         m_telemetry.LogBlock(state.symbol,"symbol on cooldown");
         return;
        }

      MqlRates decisionRates[];
      MqlRates microRates[];
      if(!AFCopyRates(state.symbol,m_config.decisionTf,m_config.lookbackBars,decisionRates))
         return;
      if(!AFCopyRates(state.symbol,m_config.microTf,64,microRates))
         return;

      AFConfig symbolConfig;
      double symbolRiskBias=1.0;
      m_symbolProfiles.Adapt(m_config,state.symbol,symbolConfig,symbolRiskBias);

      string riskReason="";
      if(!m_riskManager.CanTradeSymbol(symbolConfig,m_portfolio,state,riskReason))
        {
         m_telemetry.LogBlock(state.symbol,riskReason);
         return;
        }

      double atr=0.0;
      double slope=0.0;
      double compression=0.0;
      const AFMarketRegime regime=m_regimeEngine.Classify(symbolConfig,decisionRates,atr,slope,compression);
      state.regime=regime;
      state.lastAtr=atr;
      if(atr<=0.0)
         return;

      const AFSessionState session=m_sessionIntelligence.Evaluate(symbolConfig);
      const AFVolatilityForecast forecast=m_volatilityModel.Forecast(symbolConfig,decisionRates);
      const AFMicrostructureState micro=m_microstructureFilter.Evaluate(symbolConfig,state.symbol,microRates,atr,session);
      if(!micro.stable)
        {
         m_telemetry.LogBlock(state.symbol,"microstructure unstable");
         return;
        }
      if(!m_spreadGuard.Allow(symbolConfig,micro,atr,state.symbol))
        {
         m_telemetry.LogBlock(state.symbol,"spread guard blocked");
         return;
        }

      AFLiquidityMap map;
      m_heatmapEngine.Build(symbolConfig,decisionRates,atr,map);

      AFSignalCandidate candidate;
      string reason="";
      if(!BuildSignals(symbolConfig,state.symbol,state,decisionRates,microRates,regime,map,forecast,micro,session,atr,slope,candidate,reason))
        {
         if(reason!="")
            m_telemetry.LogBlock(state.symbol,reason);
         return;
        }

      const double correlationPenalty=m_correlationManager.PenaltyForSymbol(symbolConfig,m_portfolio,state.symbol,candidate.direction,m_plans,AF_MAX_ACTIVE_PLANS);
      if(symbolConfig.enableCorrelationHardBlock)
        {
         const int correlatedCount=
            m_correlationManager.HighlyCorrelatedCount(symbolConfig,m_portfolio,state.symbol,candidate.direction,m_plans,AF_MAX_ACTIVE_PLANS,symbolConfig.correlationHardBlock);
         if(correlatedCount>=symbolConfig.maxCorrelatedPositions)
           {
            reason=StringFormat("correlated exposure cap reached (%d >= %d, corr %.2f)",
                                correlatedCount,
                                symbolConfig.maxCorrelatedPositions,
                                correlationPenalty);
            m_telemetry.LogBlock(state.symbol,reason);
            return;
           }
        }

      double requestedRiskPct=m_positionSizer.ComputeRiskPct(symbolConfig,m_portfolio.balance,candidate.confidence,forecast,session,correlationPenalty);
      requestedRiskPct*=m_riskManager.CandidateRiskBias(state.symbol,candidate,session,forecast);
      requestedRiskPct*=candidate.riskMultiplier*symbolRiskBias;

      const int activePlans=ActivePlansCount();
      const int activeCarrierPlans=ActiveCarrierPlansCount();
      double approvedRiskPct=0.0;
      if(!m_portfolioAllocator.Allocate(symbolConfig,m_portfolio,state.symbol,candidate,requestedRiskPct,activePlans,activeCarrierPlans,approvedRiskPct,reason))
        {
         m_telemetry.LogBlock(state.symbol,reason);
         return;
        }

      const double riskMoney=m_portfolio.balance*(approvedRiskPct/100.0);
      const double volume=AFRiskVolumeForStop(state.symbol,riskMoney,candidate.entry,candidate.stop);
      if(volume<=0.0)
        {
         m_telemetry.LogBlock(state.symbol,"position sizing resolved to zero volume");
         return;
        }

      ulong ticket=0;
      if(!m_orderManager.PlaceEntry(state.symbol,candidate,volume,ticket,reason))
        {
         m_telemetry.LogBlock(state.symbol,reason);
         return;
        }

      RememberIntent(state.symbol,regime,candidate,volume,ticket);
      m_telemetry.LogSignal(state.symbol,regime,candidate);
     }

   void                      SyncOrphanPositions(void)
     {
      for(int i=PositionsTotal()-1; i>=0; --i)
        {
         const ulong positionId=PositionGetTicket(i);
         if(positionId==0 || !PositionSelectByTicket(positionId))
            continue;
         if((ulong)PositionGetInteger(POSITION_MAGIC)!=m_config.magicNumber)
            continue;
         if(FindPlanByPosition(positionId)>=0)
            continue;

         const int slot=FindFreePlanSlot();
         if(slot<0)
            return;
         const string symbol=PositionGetString(POSITION_SYMBOL);
         const string comment=PositionGetString(POSITION_COMMENT);
         m_plans[slot].active=true;
         m_plans[slot].positionId=positionId;
         m_plans[slot].symbol=symbol;
         m_plans[slot].strategy=AFExtractStrategyFromComment(comment);
         m_plans[slot].regime=DEFENSIVE;
         m_plans[slot].direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? DIR_LONG : DIR_SHORT);
         m_plans[slot].entry=PositionGetDouble(POSITION_PRICE_OPEN);
         m_plans[slot].initialStop=PositionGetDouble(POSITION_SL);
         m_plans[slot].target3=PositionGetDouble(POSITION_TP);
         m_plans[slot].target1=m_plans[slot].entry;
         m_plans[slot].target2=m_plans[slot].entry;
         m_plans[slot].riskRPoints=MathAbs(m_plans[slot].entry-m_plans[slot].initialStop);
         m_plans[slot].volumeInitial=PositionGetDouble(POSITION_VOLUME);
         m_plans[slot].volumeRemaining=m_plans[slot].volumeInitial;
         m_plans[slot].tp1Done=false;
         m_plans[slot].tp2Done=false;
         m_plans[slot].movedBreakEven=false;
         m_plans[slot].lastManagedStop=m_plans[slot].initialStop;
         m_plans[slot].lastStopUpdateTime=(datetime)PositionGetInteger(POSITION_TIME_UPDATE);
         m_plans[slot].clusterId=AFExtractClusterId(comment);
         m_plans[slot].confidence=0.50;
         m_plans[slot].openTime=(datetime)PositionGetInteger(POSITION_TIME);
         m_plans[slot].comment=comment;
         for(int j=0; j<AF_FEATURE_COUNT; ++j)
            m_plans[slot].features[j]=0.5;
        }
     }

   void                      ManageOpenPositions(void)
     {
      for(int i=0; i<AF_MAX_ACTIVE_PLANS; ++i)
        {
         if(!m_plans[i].active)
            continue;
         if(!PositionSelectByTicket(m_plans[i].positionId))
            continue;
         MqlRates rates[];
         if(!AFCopyRates(m_plans[i].symbol,m_config.decisionTf,64,rates))
            continue;
         const double atr=AFComputeATR(rates,m_config.atrPeriod,1);
         AFConfig symbolConfig;
         double symbolRiskBias=1.0;
         m_symbolProfiles.Adapt(m_config,m_plans[i].symbol,symbolConfig,symbolRiskBias);
         m_profitEngine.Manage(symbolConfig,m_plans[i],atr,m_orderManager);
        }
     }

   void                      RegisterOpenPlan(const ulong positionId,const string symbol,const string comment)
     {
      if(FindPlanByPosition(positionId)>=0)
         return;
      const int intentIndex=FindIntentByComment(symbol,comment);
      const int slot=FindFreePlanSlot();
      if(slot<0)
         return;
      if(!PositionSelectByTicket(positionId))
         return;

      AFSignalCandidate candidate;
      AFResetCandidate(candidate);
      AFMarketRegime regime=DEFENSIVE;
      double volume=PositionGetDouble(POSITION_VOLUME);
      if(intentIndex>=0)
        {
         candidate=m_intents[intentIndex].candidate;
         regime=m_intents[intentIndex].regime;
         volume=m_intents[intentIndex].volume;
         m_intents[intentIndex].active=false;
        }
      else
        {
         candidate.strategy=AFExtractStrategyFromComment(comment);
         candidate.direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? DIR_LONG : DIR_SHORT);
         candidate.clusterId=AFExtractClusterId(comment);
         for(int i=0; i<AF_FEATURE_COUNT; ++i)
            candidate.features[i]=0.5;
        }

      m_plans[slot].active=true;
      m_plans[slot].positionId=positionId;
      m_plans[slot].symbol=symbol;
      m_plans[slot].strategy=candidate.strategy;
      m_plans[slot].regime=regime;
      m_plans[slot].direction=(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY ? DIR_LONG : DIR_SHORT);
      m_plans[slot].entry=PositionGetDouble(POSITION_PRICE_OPEN);
      m_plans[slot].initialStop=(PositionGetDouble(POSITION_SL)>0.0 ? PositionGetDouble(POSITION_SL) : candidate.stop);
      m_plans[slot].target1=(candidate.target1>0.0 ? candidate.target1 : PositionGetDouble(POSITION_TP));
      m_plans[slot].target2=(candidate.target2>0.0 ? candidate.target2 : PositionGetDouble(POSITION_TP));
      m_plans[slot].target3=(candidate.target3>0.0 ? candidate.target3 : PositionGetDouble(POSITION_TP));
      m_plans[slot].riskRPoints=MathAbs(m_plans[slot].entry-m_plans[slot].initialStop);
      m_plans[slot].volumeInitial=volume;
      m_plans[slot].volumeRemaining=PositionGetDouble(POSITION_VOLUME);
      m_plans[slot].tp1Done=false;
      m_plans[slot].tp2Done=false;
      m_plans[slot].movedBreakEven=false;
      m_plans[slot].lastManagedStop=m_plans[slot].initialStop;
      m_plans[slot].lastStopUpdateTime=(datetime)PositionGetInteger(POSITION_TIME_UPDATE);
      m_plans[slot].clusterId=candidate.clusterId;
      m_plans[slot].confidence=candidate.confidence;
      m_plans[slot].openTime=(datetime)PositionGetInteger(POSITION_TIME);
      m_plans[slot].comment=comment;
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         m_plans[slot].features[i]=candidate.features[i];

      const int stateIndex=FindSymbolIndex(symbol);
      if(stateIndex>=0)
        {
         m_symbolStates[stateIndex].tradesToday++;
         m_stateMachine.MarkClusterTrade(m_symbolStates[stateIndex],candidate.strategy,candidate.clusterId);
        }
     }

   void                      RegisterClosedPlan(const ulong positionId,const string symbol)
     {
      const int planIndex=FindPlanByPosition(positionId);
      if(planIndex<0)
         return;

      AFTradeOutcome outcome;
      outcome.valid=true;
      outcome.positionId=positionId;
      outcome.symbol=symbol;
      outcome.strategy=m_plans[planIndex].strategy;
      outcome.regime=m_plans[planIndex].regime;
      outcome.profit=PositionRealizedProfit(positionId);
      const double riskMoney=PlanRiskMoney(m_plans[planIndex]);
      outcome.profitR=(riskMoney>0.0 ? outcome.profit/riskMoney : 0.0);
      outcome.label=(outcome.profit>0.01 ? 1 : (outcome.profit<-0.01 ? -1 : 0));
      outcome.closeTime=TimeCurrent();
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         outcome.features[i]=m_plans[planIndex].features[i];

      m_performance.ApplyOutcome(outcome);
      m_learningModel.ApplyOutcome(outcome);
      m_telemetry.LogOutcome(outcome,m_performance);
      m_closedTrades++;

      const int stateIndex=FindSymbolIndex(symbol);
      if(stateIndex>=0)
        {
         ApplySymbolOutcome(m_symbolStates[stateIndex],outcome);
         m_stateMachine.ReduceClusterEntry(m_symbolStates[stateIndex],m_plans[planIndex].strategy);
         if(outcome.label<0)
            m_symbolStates[stateIndex].lossesToday++;
        }

      int cooldownMinutes=0;
      string reason="";
      if(stateIndex>=0 && m_degradation.ShouldDisableSymbol(m_config,m_symbolStates[stateIndex],cooldownMinutes,reason))
        {
         m_stateMachine.BlockSymbol(m_symbolStates[stateIndex],cooldownMinutes);
         m_telemetry.LogBlock(symbol,reason);
        }

      cooldownMinutes=0;
      reason="";
      if(stateIndex>=0 && m_degradation.ShouldDisable(m_config,m_performance,m_plans[planIndex].strategy,cooldownMinutes,reason))
        {
         m_stateMachine.BlockStrategy(m_symbolStates[stateIndex],m_plans[planIndex].strategy,cooldownMinutes);
         m_telemetry.LogBlock(symbol,reason);
        }

      m_plans[planIndex].active=false;
      if(m_config.enableEvolutionExport && (m_closedTrades%5)==0)
         m_evolution.ExportPreset(m_config,m_performance);
     }

public:
                        AplexFlowEngine(void)
     {
      m_initialized=false;
      m_closedTrades=0;
      ResetContainers();
     }

                       ~AplexFlowEngine(void)
     {
      if(m_initialized && m_config.enableEvolutionExport)
         m_evolution.ExportPreset(m_config,m_performance);
     }

   int                  OnInit(void)
     {
      if(!AFBuildConfig(m_config))
         return INIT_FAILED;

      ResetContainers();
      InitializeSymbolStates();
      m_stateMachine.Initialize();
      m_learningModel.Initialize(m_config);
      m_riskContainment.Initialize();
      m_orderManager.Initialize(m_config);
      m_performance.Initialize();
      m_telemetry.Initialize(m_config);
      RefreshPortfolio();
      SyncOrphanPositions();

      if(m_backtestRunner.IsResearchContext())
         m_telemetry.LogInfo(m_backtestRunner.ContextTag(m_config));

      m_initialized=true;
      return INIT_SUCCEEDED;
     }

   void                 OnTick(void)
     {
      if(!m_initialized)
         return;

      bool newDay=false;
      bool newWeek=false;
      m_stateMachine.RollCalendar(TimeCurrent(),newDay,newWeek);
      if(newDay)
        {
         m_riskContainment.ResetDay();
         for(int i=0; i<m_config.symbolCount; ++i)
            m_stateMachine.ResetDailyState(m_symbolStates[i]);
        }
      if(newWeek)
         m_riskContainment.ResetWeek();

      ExpireIntents();
      RefreshPortfolio();
      ManageOpenPositions();
      SyncOrphanPositions();
      m_correlationManager.Update(m_config,m_portfolio);

      if(m_config.enableDedicatedSymbolAlphas)
        {
         AFSymbolProcessSlot queue[];
         const int queueCount=BuildProcessQueue(queue);
         for(int i=0; i<queueCount; ++i)
            ProcessSymbol(m_symbolStates[queue[i].index]);
         return;
        }

      for(int i=0; i<m_config.symbolCount; ++i)
        {
         if(m_stateMachine.IsNewDecisionBar(m_symbolStates[i],m_config.decisionTf))
            ProcessSymbol(m_symbolStates[i]);
        }
     }

   void                 OnTradeTransaction(const MqlTradeTransaction &trans,const MqlTradeRequest &request,const MqlTradeResult &result)
     {
      if(!m_initialized)
         return;
      if(trans.type!=TRADE_TRANSACTION_DEAL_ADD)
         return;
      if(!HistoryDealSelect(trans.deal))
         return;

      const ulong positionId=(ulong)HistoryDealGetInteger(trans.deal,DEAL_POSITION_ID);
      const string symbol=HistoryDealGetString(trans.deal,DEAL_SYMBOL);
      const long magic=HistoryDealGetInteger(trans.deal,DEAL_MAGIC);
      if((ulong)magic!=m_config.magicNumber)
         return;

      const ENUM_DEAL_ENTRY entryType=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal,DEAL_ENTRY);
      const string comment=HistoryDealGetString(trans.deal,DEAL_COMMENT);

      if(entryType==DEAL_ENTRY_IN)
        {
         RegisterOpenPlan(positionId,symbol,comment);
         return;
        }

      if(entryType==DEAL_ENTRY_OUT || entryType==DEAL_ENTRY_OUT_BY)
        {
         if(!PositionSelectByTicket(positionId))
            RegisterClosedPlan(positionId,symbol);
        }
     }
  };

#endif
