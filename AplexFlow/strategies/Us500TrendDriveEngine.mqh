#ifndef APLEXFLOW_STRATEGIES_US500TRENDDRIVEENGINE_MQH
#define APLEXFLOW_STRATEGIES_US500TRENDDRIVEENGINE_MQH

#include "../core/Context.mqh"

class Us500TrendDriveEngine
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

   bool              IsPrimaryDriveWindow(void) const
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
      if(!AFDedicatedUs500Enabled(config) || !IsUs500(symbol) || ArraySize(decisionRates)<20 || atr<=0.0)
         return false;
      if(!(session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP))
         return false;
      if(!IsPrimaryDriveWindow())
         return false;
      if(!(regime==STRONG_TREND || regime==WEAK_TREND || regime==VOLATILITY_EXPANSION || forecast.breakoutProbability>=0.58))
         return false;

      const MqlRates bar=decisionRates[1];
      const double recentHigh=AFHighestHigh(decisionRates,8,2);
      const double recentLow=AFLowestLow(decisionRates,8,2);
      const double openingHigh=AFHighestHigh(decisionRates,4,2);
      const double openingLow=AFLowestLow(decisionRates,4,2);
      const double closeStrength=AFCloseStrength(bar);
      const double slope=AFComputeSlope(decisionRates,10,1);
      const double slopeNorm=(atr>0.0 ? slope/atr : 0.0);
      const double bodyStrength=MathAbs(bar.close-bar.open)/MathMax(atr,1e-6);
      const double wickNoise=AFWickNoise(bar);
      const double avgTickVolume=AverageTickVolume(decisionRates,2,8);
      const bool elevatedParticipation=(avgTickVolume>0.0 && (double)bar.tick_volume>=avgTickVolume*1.00);
      const double buffer=0.025*atr;

      if(slopeNorm>=0.05 &&
         forecast.breakoutProbability>=0.46 &&
         bodyStrength>=0.34 &&
         wickNoise<=0.48 &&
         elevatedParticipation &&
         bar.close>recentHigh+buffer &&
         bar.close>openingHigh &&
         closeStrength>=0.58)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_US500_OPEN_DRIVE;
         candidate.direction=DIR_LONG;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,MathMin(bar.low-(0.16*atr),openingHigh-(0.10*atr)));
         candidate.riskMultiplier=0.88;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=0.88;
         candidate.rationale="US500 trend drive breakout";
         return true;
        }

      if(regime==VOLATILITY_EXPANSION &&
         slopeNorm<=-0.09 &&
         forecast.breakoutProbability>=0.60 &&
         bodyStrength>=0.55 &&
         wickNoise<=0.34 &&
         avgTickVolume>0.0 &&
         (double)bar.tick_volume>=avgTickVolume*1.20 &&
         bar.close<recentLow-buffer &&
         bar.close<openingLow &&
         (1.0-closeStrength)>=0.68)
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_US500_OPEN_DRIVE;
         candidate.direction=DIR_SHORT;
         candidate.entry=bar.close;
         candidate.stop=AFNormalizePrice(symbol,MathMax(bar.high+(0.16*atr),openingLow+(0.10*atr)));
         candidate.riskMultiplier=0.82;
         candidate.dedicatedAlpha=true;
         candidate.alphaStrength=0.82;
         candidate.rationale="US500 downside trend drive";
         return true;
        }

      return false;
     }
  };

#endif
