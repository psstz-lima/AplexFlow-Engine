#ifndef APLEXFLOW_REGIME_MARKETREGIMEENGINE_MQH
#define APLEXFLOW_REGIME_MARKETREGIMEENGINE_MQH

#include "../core/Context.mqh"

class MarketRegimeEngine
  {
public:
   AFMarketRegime     Classify(const AFConfig &config,const MqlRates &decisionRates[],double &atrOut,double &slopeOut,double &compressionOut) const
     {
      atrOut=AFComputeATR(decisionRates,config.atrPeriod,1);
      const double atrSlow=AFComputeATR(decisionRates,config.atrPeriod,config.atrPeriod+1);
      slopeOut=AFComputeSlope(decisionRates,config.trendSlopeLength,1);
      const double atrNorm=(atrOut>0.0 ? slopeOut/atrOut : 0.0);

      double avgRange=0.0;
      int used=0;
      for(int i=2; i<2+config.compressionLookback && i<ArraySize(decisionRates); ++i)
        {
         avgRange+=AFBarRange(decisionRates[i]);
         ++used;
        }
      if(used>0)
         avgRange/=(double)used;
      const double lastRange=AFBarRange(decisionRates[1]);
      compressionOut=(avgRange>0.0 ? lastRange/avgRange : 1.0);

      const bool structureShift=((decisionRates[1].high>AFHighestHigh(decisionRates,config.breakoutLookback,2)) ||
                                 (decisionRates[1].low<AFLowestLow(decisionRates,config.breakoutLookback,2)));
      const bool volatilityExpansion=(atrSlow>0.0 && (atrOut/atrSlow)>=config.volExpansionThreshold);
      const bool compressed=(compressionOut<=config.compressionThreshold);

      if(volatilityExpansion && structureShift)
         return VOLATILITY_EXPANSION;
      if(MathAbs(atrNorm)>=config.trendSlopeThreshold && !compressed)
         return STRONG_TREND;
      if(MathAbs(atrNorm)>=config.weakTrendSlopeThreshold)
         return WEAK_TREND;
      if(compressed || MathAbs(atrNorm)<(config.weakTrendSlopeThreshold*0.5))
         return RANGE;
      return DEFENSIVE;
     }
  };

#endif
