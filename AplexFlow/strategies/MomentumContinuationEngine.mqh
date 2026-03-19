#ifndef APLEXFLOW_STRATEGIES_MOMENTUMCONTINUATIONENGINE_MQH
#define APLEXFLOW_STRATEGIES_MOMENTUMCONTINUATIONENGINE_MQH

#include "../core/Context.mqh"

class MomentumContinuationEngine
  {
private:
   double             MicroImpulseScore(const MqlRates &microRates[],const AFDirection direction) const
     {
      if(ArraySize(microRates)<6)
         return 0.0;
      double score=0.0;
      for(int i=1; i<=5; ++i)
        {
         const double change=microRates[i].close-microRates[i].open;
         score+=(change*(double)AFDirectionSign(direction));
        }
      const double denom=MathAbs(microRates[1].high-microRates[1].low)+1e-6;
      return AFClamp((score/denom)*0.5,0.0,1.0);
     }

public:
   bool               Evaluate(const AFConfig &config,const AFMarketRegime regime,const MqlRates &decisionRates[],const MqlRates &microRates[],const double atr,const double slope,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!config.enableMomentum || ArraySize(decisionRates)<8 || atr<=0.0)
         return false;
      if(!(regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION))
         return false;

      const double slopeNorm=(atr>0.0 ? slope/atr : 0.0);
      const double closeStrength=AFCloseStrength(decisionRates[1]);
      const double mid=0.5*(decisionRates[1].high+decisionRates[1].low);

      if(slopeNorm>=config.weakTrendSlopeThreshold && closeStrength>=config.momentumCloseStrengthMin && decisionRates[1].close>=mid)
        {
         const double microScore=MicroImpulseScore(microRates,DIR_LONG);
         if(microScore>=config.momentumMicroImpulseMin)
           {
            candidate.valid=true;
            candidate.strategy=STRATEGY_MOMENTUM_CONTINUATION;
            candidate.direction=DIR_LONG;
            candidate.entry=decisionRates[1].close;
            candidate.stop=MathMin(decisionRates[1].low-(0.10*atr),decisionRates[2].low-(0.15*atr));
            candidate.rationale="Momentum continuation aligned with M5 slope and M1 impulse";
            return true;
           }
        }

      if(slopeNorm<=-config.weakTrendSlopeThreshold && (1.0-closeStrength)>=config.momentumCloseStrengthMin && decisionRates[1].close<=mid)
        {
         const double microScore=MicroImpulseScore(microRates,DIR_SHORT);
         if(microScore>=config.momentumMicroImpulseMin)
           {
            candidate.valid=true;
            candidate.strategy=STRATEGY_MOMENTUM_CONTINUATION;
            candidate.direction=DIR_SHORT;
            candidate.entry=decisionRates[1].close;
            candidate.stop=MathMax(decisionRates[1].high+(0.10*atr),decisionRates[2].high+(0.15*atr));
            candidate.rationale="Momentum continuation short with microstructure confirmation";
            return true;
           }
        }

      return false;
     }
  };

#endif
