#ifndef APLEXFLOW_STRATEGIES_XAULIQUIDITYRECLAIMENGINE_MQH
#define APLEXFLOW_STRATEGIES_XAULIQUIDITYRECLAIMENGINE_MQH

#include "../core/Context.mqh"

class XauLiquidityReclaimEngine
  {
private:
   bool              IsXau(const string symbol) const
     {
      return AFIsXauSymbol(symbol);
     }

   double            SessionBoost(const AFSessionState &session) const
     {
      if(session.tag==SESSION_OVERLAP)
         return 0.06;
      if(session.tag==SESSION_LONDON || session.tag==SESSION_NEWYORK)
         return 0.03;
      return 0.0;
     }

public:
   bool              Evaluate(const AFConfig &config,const string symbol,const AFMarketRegime regime,const AFLiquidityMap &map,const AFVolatilityForecast &forecast,const AFSessionState &session,const MqlRates &decisionRates[],const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!AFDedicatedXauReclaimEnabled(config) || !IsXau(symbol) || ArraySize(decisionRates)<22 || atr<=0.0)
         return false;
      if(!(session.tag==SESSION_LONDON || session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP))
         return false;
      if(!(regime==RANGE || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION || regime==DEFENSIVE))
         return false;

      const MqlRates bar=decisionRates[1];
      const double priorLow=AFLowestLow(decisionRates,12,2);
      const double priorHigh=AFHighestHigh(decisionRates,12,2);
      const double closeStrength=AFCloseStrength(bar);
      const double wickNoise=AFWickNoise(bar);
      const double bodyFrac=AFClamp(MathAbs(bar.close-bar.open)/MathMax(atr,1e-6),0.0,2.0);
      const double sweepBuffer=0.04*atr;
      const double reclaimBuffer=0.015*atr;
      const double lowerSupport=(map.nearestBelow>0.0 ? map.nearestBelow : priorLow);
      const double upperResistance=(map.nearestAbove>0.0 ? map.nearestAbove : priorHigh);

      if(priorLow>0.0 &&
         lowerSupport>0.0 &&
         bar.low<(priorLow-sweepBuffer) &&
         bar.close>(priorLow+reclaimBuffer) &&
         bar.close>(lowerSupport+0.01*atr) &&
         bar.close>bar.open &&
         closeStrength>=0.62 &&
         wickNoise>=0.30 &&
         wickNoise<=0.82 &&
         bodyFrac>=0.24 &&
         forecast.breakoutProbability<=0.72)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_XAU_LIQUIDITY_RECLAIM;
         candidate.direction=DIR_LONG;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,MathMin(bar.low-(0.14*atr),priorLow-(0.18*atr)));
         candidate.riskMultiplier=1.00;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=AFClamp(0.84+SessionBoost(session)+AFClamp((bar.close-priorLow)/MathMax(atr,1e-6),0.0,0.10),0.84,0.97);
         candidate.rationale="XAU downside sweep reclaimed into session liquidity";
         return true;
        }

      if(priorHigh>0.0 &&
         upperResistance>0.0 &&
         bar.high>(priorHigh+sweepBuffer) &&
         bar.close<(priorHigh-reclaimBuffer) &&
         bar.close<(upperResistance-0.01*atr) &&
         bar.close<bar.open &&
         (1.0-closeStrength)>=0.62 &&
         wickNoise>=0.30 &&
         wickNoise<=0.82 &&
         bodyFrac>=0.24 &&
         forecast.breakoutProbability<=0.72)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_XAU_LIQUIDITY_RECLAIM;
         candidate.direction=DIR_SHORT;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,MathMax(bar.high+(0.14*atr),priorHigh+(0.18*atr)));
         candidate.riskMultiplier=1.00;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=AFClamp(0.84+SessionBoost(session)+AFClamp((priorHigh-bar.close)/MathMax(atr,1e-6),0.0,0.10),0.84,0.97);
         candidate.rationale="XAU upside sweep rejected back below liquidity";
         return true;
        }

      return false;
     }
  };

#endif
