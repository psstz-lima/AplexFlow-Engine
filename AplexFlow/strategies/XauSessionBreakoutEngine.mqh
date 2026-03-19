#ifndef APLEXFLOW_STRATEGIES_XAUSESSIONBREAKOUTENGINE_MQH
#define APLEXFLOW_STRATEGIES_XAUSESSIONBREAKOUTENGINE_MQH

#include "../core/Context.mqh"

class XauSessionBreakoutEngine
  {
private:
   bool              IsXau(const string symbol) const
     {
      return AFIsXauSymbol(symbol);
     }

   double            AverageRange(const MqlRates &rates[],const int shift,const int length) const
     {
      if(length<=0)
         return 0.0;
      double total=0.0;
      int used=0;
      for(int i=shift; i<shift+length && i<ArraySize(rates); ++i)
        {
         total+=AFBarRange(rates[i]);
         ++used;
        }
      return (used>0 ? total/(double)used : 0.0);
     }

public:
   bool              Evaluate(const AFConfig &config,const string symbol,const AFMarketRegime regime,const AFVolatilityForecast &forecast,const AFSessionState &session,const MqlRates &decisionRates[],const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(!AFDedicatedXauEnabled(config) || !IsXau(symbol) || ArraySize(decisionRates)<24 || atr<=0.0)
         return false;
      if(!(session.tag==SESSION_LONDON || session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP))
         return false;
      if(!(regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION))
         return false;

      const MqlRates bar=decisionRates[1];
      const double driveHigh=AFHighestHigh(decisionRates,10,2);
      const double driveLow=AFLowestLow(decisionRates,10,2);
      const double closeStrength=AFCloseStrength(bar);
      const double bodyFrac=AFClamp(MathAbs(bar.close-bar.open)/MathMax(atr,1e-6),0.0,2.5);
      const double wickNoise=AFWickNoise(bar);
      const double fastRange=AverageRange(decisionRates,2,6);
      const double slowRange=AverageRange(decisionRates,8,12);
      const bool compressed=(slowRange>0.0 && fastRange<=0.92*slowRange);
      const bool impulse=(forecast.impulseCandle || AFBarRange(bar)>=0.95*atr);
      const double buffer=0.04*atr;
      const double previousHigh=AFHighestHigh(decisionRates,4,2);
      const double previousLow=AFLowestLow(decisionRates,4,2);

      if(impulse &&
         compressed &&
         forecast.breakoutProbability>=0.56 &&
         bodyFrac>=0.55 &&
         wickNoise<=0.34 &&
         bar.close>driveHigh+buffer &&
         bar.close>previousHigh &&
         closeStrength>=0.63)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_XAU_SESSION_BREAKOUT;
         candidate.direction=DIR_LONG;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,bar.low-MathMax(0.20*atr,bar.close-driveHigh));
         candidate.riskMultiplier=1.04;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=0.92;
         candidate.rationale="XAU session breakout drive";
         return true;
        }

      if(impulse &&
         compressed &&
         forecast.breakoutProbability>=0.56 &&
         bodyFrac>=0.55 &&
         wickNoise<=0.34 &&
         bar.close<driveLow-buffer &&
         bar.close<previousLow &&
         (1.0-closeStrength)>=0.63)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_XAU_SESSION_BREAKOUT;
         candidate.direction=DIR_SHORT;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,bar.high+MathMax(0.20*atr,driveLow-bar.close));
         candidate.riskMultiplier=1.04;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=0.92;
         candidate.rationale="XAU downside session drive";
         return true;
        }

      return false;
     }
  };

#endif
