#ifndef APLEXFLOW_STRATEGIES_US500IMPULSEPULLBACKENGINE_MQH
#define APLEXFLOW_STRATEGIES_US500IMPULSEPULLBACKENGINE_MQH

#include "../core/Context.mqh"

class Us500ImpulsePullbackEngine
  {
private:
   bool              IsUs500(const string symbol) const
     {
      return AFIsUs500Symbol(symbol);
     }

   double            AverageTickVolume(const MqlRates &rates[],const int shift,const int length) const
     {
      if(length<=0)
         return 0.0;
      double total=0.0;
      int used=0;
      for(int i=shift; i<shift+length && i<ArraySize(rates); ++i)
        {
         total+=(double)rates[i].tick_volume;
         ++used;
        }
      return (used>0 ? total/(double)used : 0.0);
     }

   bool              IsDriveWindow(void) const
     {
      const datetime gmt=TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmt,dt);
      return (dt.hour>=14 && dt.hour<=20);
     }

public:
   bool              Evaluate(const AFConfig &config,const string symbol,const AFMarketRegime regime,const AFVolatilityForecast &forecast,const AFSessionState &session,const MqlRates &decisionRates[],const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!AFDedicatedUs500ImpulsePullbackEnabled(config) || !IsUs500(symbol) || ArraySize(decisionRates)<24 || atr<=0.0)
         return false;
      if(!(session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP) || !IsDriveWindow())
         return false;
      if(!(regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION))
         return false;

      const MqlRates trigger=decisionRates[1];
      const MqlRates pullback=decisionRates[2];
      const MqlRates impulse=decisionRates[3];
      const double slope=AFComputeSlope(decisionRates,10,1);
      const double slopeNorm=(atr>0.0 ? slope/atr : 0.0);
      const double baseHigh=AFHighestHigh(decisionRates,8,4);
      const double baseLow=AFLowestLow(decisionRates,8,4);
      const double avgTickVolume=AverageTickVolume(decisionRates,4,8);
      const double triggerStrength=AFCloseStrength(trigger);
      const double impulseStrength=AFCloseStrength(impulse);
      const double impulseBody=MathAbs(impulse.close-impulse.open)/MathMax(atr,1e-6);
      const double triggerBody=MathAbs(trigger.close-trigger.open)/MathMax(atr,1e-6);
      const double impulseWick=AFWickNoise(impulse);
      const double breakoutBuffer=0.03*atr;
      const bool activeParticipation=(avgTickVolume>0.0 &&
                                      ((double)impulse.tick_volume>=avgTickVolume*1.04 ||
                                       (double)trigger.tick_volume>=avgTickVolume*1.02));

      if(baseHigh>0.0 &&
         slopeNorm>=0.05 &&
         forecast.breakoutProbability>=0.46 &&
         activeParticipation &&
         impulse.close>(baseHigh+breakoutBuffer) &&
         impulseStrength>=0.64 &&
         impulseBody>=0.52 &&
         impulseWick<=0.54 &&
         pullback.low<=(impulse.close-(0.16*atr)) &&
         pullback.low>=(baseHigh-(0.14*atr)) &&
         pullback.close>=(baseHigh-(0.05*atr)) &&
         trigger.close>MathMax(baseHigh+(0.02*atr),impulse.high-(0.04*atr)) &&
         triggerStrength>=0.58 &&
         triggerBody>=0.22)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_US500_IMPULSE_PULLBACK;
         candidate.direction=DIR_LONG;
         candidate.entry=trigger.close;
         candidate.stop=AFNormalizePrice(symbol,MathMin(pullback.low-(0.12*atr),baseHigh-(0.18*atr)));
         candidate.riskMultiplier=0.96;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=AFClamp(0.86+(session.tag==SESSION_OVERLAP ? 0.05 : 0.02)+AFClamp((trigger.close-baseHigh)/MathMax(atr,1e-6),0.0,0.08),0.86,0.98);
         candidate.rationale="US500 impulse breakout held and resumed after pullback";
         return true;
        }

      if(baseLow>0.0 &&
         slopeNorm<=-0.05 &&
         forecast.breakoutProbability>=0.46 &&
         activeParticipation &&
         impulse.close<(baseLow-breakoutBuffer) &&
         (1.0-impulseStrength)>=0.64 &&
         impulseBody>=0.52 &&
         impulseWick<=0.54 &&
         pullback.high>=(impulse.close+(0.16*atr)) &&
         pullback.high<=(baseLow+(0.14*atr)) &&
         pullback.close<=(baseLow+(0.05*atr)) &&
         trigger.close<MathMin(baseLow-(0.02*atr),impulse.low+(0.04*atr)) &&
         (1.0-triggerStrength)>=0.58 &&
         triggerBody>=0.22)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_US500_IMPULSE_PULLBACK;
         candidate.direction=DIR_SHORT;
         candidate.entry=trigger.close;
         candidate.stop=AFNormalizePrice(symbol,MathMax(pullback.high+(0.12*atr),baseLow+(0.18*atr)));
         candidate.riskMultiplier=0.96;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=AFClamp(0.86+(session.tag==SESSION_OVERLAP ? 0.05 : 0.02)+AFClamp((baseLow-trigger.close)/MathMax(atr,1e-6),0.0,0.08),0.86,0.98);
         candidate.rationale="US500 downside impulse resumed after controlled pullback";
         return true;
        }

      return false;
     }
  };

#endif
