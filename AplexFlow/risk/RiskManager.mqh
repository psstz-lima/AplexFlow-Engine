#ifndef APLEXFLOW_RISK_RISKMANAGER_MQH
#define APLEXFLOW_RISK_RISKMANAGER_MQH

#include "../core/Context.mqh"

class RiskManager
  {
public:
   bool               CanTradeSymbol(const AFConfig &config,const AFPortfolioSnapshot &snapshot,const AFSymbolState &state,string &reason) const
     {
      int maxTrades=config.maxTradesPerDayPerSymbol;
      if(AFDedicatedXauEnabled(config) && AFIsXauSymbol(state.symbol))
         maxTrades=MathMax(maxTrades,5);
      else if(AFDedicatedUs500Enabled(config) && AFIsUs500Symbol(state.symbol))
         maxTrades=MathMax(maxTrades,4);

      if(state.tradesToday>=maxTrades)
        {
         reason=StringFormat("symbol reached daily trade cap (%d/%d)",state.tradesToday,maxTrades);
         return false;
        }

      if(config.enableDrawdownDefense &&
         snapshot.drawdownPct>=config.defenseActivationDrawdownPct &&
         state.performance.trades>=config.defenseMinSymbolTrades)
        {
         const double pf=AFProfitFactor(state.performance);
         const bool carrier=AFCarrierReserveEligibleSymbol(config,state.symbol);
         const double expectancyFloor=(carrier
                                       ? MathMin(-0.04,config.defenseMinSymbolExpectancyR-0.02)
                                       : config.defenseMinSymbolExpectancyR);
         const double pfFloor=(carrier
                               ? MathMax(0.82,config.defenseMinSymbolProfitFactor-0.08)
                               : config.defenseMinSymbolProfitFactor);
         if(state.performance.expectancyR<expectancyFloor || pf<pfFloor)
           {
            reason=StringFormat("drawdown defense blocked %s: expectancy %.3fR pf %.2f at DD %.2f%%",
                                state.symbol,
                                state.performance.expectancyR,
                                pf,
                                snapshot.drawdownPct);
            return false;
           }
        }

      reason="";
      return true;
     }

   double             CandidateRiskBias(const string symbol,const AFSignalCandidate &candidate,const AFSessionState &session,const AFVolatilityForecast &forecast) const
     {
      double bias=1.0;
      if(candidate.strategy==STRATEGY_XAU_SESSION_BREAKOUT)
        {
         bias*=1.04;
         if(!session.allowAggressive)
            bias*=0.90;
         if(forecast.breakoutProbability<0.58)
            bias*=0.92;
        }

      if(candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
        {
         bias*=0.98;
         if(session.allowAggressive)
            bias*=1.04;
         if(forecast.breakoutProbability>=0.66)
            bias*=0.92;
         else if(forecast.breakoutProbability>=0.42 && forecast.breakoutProbability<=0.60)
            bias*=1.03;
        }

      if(candidate.strategy==STRATEGY_US500_OPEN_DRIVE)
        {
         bias*=0.92;
         if(forecast.impulseCandle)
            bias*=1.05;
         if(session.tag!=SESSION_NEWYORK && session.tag!=SESSION_OVERLAP)
            bias*=0.85;
        }

      if(candidate.strategy==STRATEGY_US500_IMPULSE_PULLBACK)
        {
         bias*=0.96;
         if(forecast.impulseCandle)
            bias*=1.06;
         if(session.tag==SESSION_OVERLAP)
            bias*=1.03;
         if(forecast.breakoutProbability<0.46)
            bias*=0.93;
        }

      if(AFIsUs500Symbol(symbol) && candidate.strategy==STRATEGY_LIQUIDITY_SWEEP)
         bias*=0.75;

      if(candidate.dedicatedAlpha)
         bias*=AFClamp(0.95+(0.10*candidate.alphaStrength),0.95,1.08);

      return AFClamp(bias,0.70,1.15);
     }

   double             PlannedRiskPct(const AFPositionPlan &plan,const double balance) const
     {
      if(!plan.active || balance<=0.0)
         return 0.0;

      const double tickSize=SymbolInfoDouble(plan.symbol,SYMBOL_TRADE_TICK_SIZE);
      const double tickValue=SymbolInfoDouble(plan.symbol,SYMBOL_TRADE_TICK_VALUE);
      if(tickSize<=0.0 || tickValue<=0.0)
         return 0.0;

      const double stopDistance=MathAbs(plan.entry-plan.initialStop);
      const double riskMoney=(stopDistance/tickSize)*tickValue*plan.volumeRemaining;
      return (riskMoney/balance)*100.0;
     }

   double             TotalOpenRiskPct(const AFPositionPlan &plans[],const int planCount,const double balance) const
     {
      double total=0.0;
      for(int i=0; i<planCount; ++i)
        {
         if(!plans[i].active)
            continue;
         total+=PlannedRiskPct(plans[i],balance);
        }
      return total;
     }
  };

#endif
