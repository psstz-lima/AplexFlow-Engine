#ifndef APLEXFLOW_STRATEGIES_VOLATILITYBREAKOUTENGINE_MQH
#define APLEXFLOW_STRATEGIES_VOLATILITYBREAKOUTENGINE_MQH

#include "../core/Context.mqh"

class VolatilityBreakoutEngine
  {
public:
   bool               Evaluate(const AFConfig &config,const AFMarketRegime regime,const AFVolatilityForecast &forecast,const AFLiquidityMap &map,const MqlRates &decisionRates[],const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!config.enableBreakout || ArraySize(decisionRates)<config.breakoutLookback+5 || atr<=0.0)
         return false;
      if(!(regime==STRONG_TREND || regime==VOLATILITY_EXPANSION))
         return false;

      const double recentHigh=AFHighestHigh(decisionRates,config.breakoutLookback,2);
      const double recentLow=AFLowestLow(decisionRates,config.breakoutLookback,2);
      const double closeStrength=AFCloseStrength(decisionRates[1]);
      const double buffer=config.breakoutBufferAtr*atr;

      if(decisionRates[1].close>recentHigh+buffer && forecast.breakoutProbability>=0.55 && closeStrength>=0.60)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_VOLATILITY_BREAKOUT;
         candidate.direction=DIR_LONG;
         candidate.entry=decisionRates[1].close;
         candidate.stop=MathMin(decisionRates[1].low-(0.15*atr),recentHigh-(0.25*atr));
         candidate.rationale=StringFormat("Bullish breakout above %.5f into %s",recentHigh,map.nearestAbove>0.0 ? "liquidity pocket" : "expansion");
         return true;
        }

      if(decisionRates[1].close<recentLow-buffer && forecast.breakoutProbability>=0.55 && (1.0-closeStrength)>=0.60)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_VOLATILITY_BREAKOUT;
         candidate.direction=DIR_SHORT;
         candidate.entry=decisionRates[1].close;
         candidate.stop=MathMax(decisionRates[1].high+(0.15*atr),recentLow+(0.25*atr));
         candidate.rationale=StringFormat("Bearish breakout below %.5f into expansion",recentLow);
         return true;
        }

      return false;
     }
  };

#endif
