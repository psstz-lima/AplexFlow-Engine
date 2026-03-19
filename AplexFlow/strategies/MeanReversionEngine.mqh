#ifndef APLEXFLOW_STRATEGIES_MEANREVERSIONENGINE_MQH
#define APLEXFLOW_STRATEGIES_MEANREVERSIONENGINE_MQH

#include "../core/Context.mqh"

class MeanReversionEngine
  {
public:
   bool               Evaluate(const AFConfig &config,const AFMarketRegime regime,const AFLiquidityMap &map,const MqlRates &decisionRates[],const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!config.enableMeanReversion || ArraySize(decisionRates)<config.compressionLookback+8 || atr<=0.0)
         return false;
      if(!(regime==RANGE || regime==DEFENSIVE))
         return false;

      const double zScore=AFComputeZScoreClose(decisionRates,config.compressionLookback,1);
      const double close=decisionRates[1].close;

      if(zScore<=-config.meanReversionZScore && map.nearestBelow>0.0 && close<=map.nearestBelow+(0.35*atr))
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_MEAN_REVERSION;
         candidate.direction=DIR_LONG;
         candidate.entry=close;
         candidate.stop=close-(1.10*atr);
         candidate.rationale="Mean reversion from downside stretch into liquidity";
         return true;
        }

      if(zScore>=config.meanReversionZScore && map.nearestAbove>0.0 && close>=map.nearestAbove-(0.35*atr))
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_MEAN_REVERSION;
         candidate.direction=DIR_SHORT;
         candidate.entry=close;
         candidate.stop=close+(1.10*atr);
         candidate.rationale="Mean reversion from upside stretch into liquidity";
         return true;
        }

      return false;
     }
  };

#endif
