#ifndef APLEXFLOW_LIQUIDITY_LIQUIDITYSWEEPENGINE_MQH
#define APLEXFLOW_LIQUIDITY_LIQUIDITYSWEEPENGINE_MQH

#include "../core/Context.mqh"

class LiquiditySweepEngine
  {
private:
   bool               DetectSweepAbove(const MqlRates &bar,const double level,const double tolerance,const double rejectCloseMin) const
     {
      if(level<=0.0)
         return false;
      const double closeStrength=1.0-AFCloseStrength(bar);
      return (bar.high>level+tolerance && bar.close<level && closeStrength>=rejectCloseMin);
     }

   bool               DetectSweepBelow(const MqlRates &bar,const double level,const double tolerance,const double rejectCloseMin) const
     {
      if(level<=0.0)
         return false;
      const double closeStrength=AFCloseStrength(bar);
      return (bar.low<level-tolerance && bar.close>level && closeStrength>=rejectCloseMin);
     }

public:
   bool               Evaluate(const AFConfig &config,const MqlRates &decisionRates[],const AFLiquidityMap &map,const double atr,AFSignalCandidate &candidate) const
     {
      AFResetCandidate(candidate);
      if(ArraySize(decisionRates)<config.sweepLookback+5 || atr<=0.0)
         return false;

      const MqlRates bar=decisionRates[1];
      const double tolerance=0.10*atr;
      const double bearishStop=bar.high+(0.25*atr);
      const double bullishStop=bar.low-(0.25*atr);

      if(DetectSweepAbove(bar,map.prevDayHigh,tolerance,config.sweepRejectCloseMin) ||
         DetectSweepAbove(bar,map.sessionHigh,tolerance,config.sweepRejectCloseMin) ||
         DetectSweepAbove(bar,map.nearestAbove,tolerance,config.sweepRejectCloseMin))
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_LIQUIDITY_SWEEP;
         candidate.direction=DIR_SHORT;
         candidate.entry=bar.close;
         candidate.stop=bearishStop;
         candidate.rationale="Bearish liquidity sweep rejection";
         return true;
        }

      if(DetectSweepBelow(bar,map.prevDayLow,tolerance,config.sweepRejectCloseMin) ||
         DetectSweepBelow(bar,map.sessionLow,tolerance,config.sweepRejectCloseMin) ||
         DetectSweepBelow(bar,map.nearestBelow,tolerance,config.sweepRejectCloseMin))
        {
         candidate.valid=true;
         candidate.strategy=STRATEGY_LIQUIDITY_SWEEP;
         candidate.direction=DIR_LONG;
         candidate.entry=bar.close;
         candidate.stop=bullishStop;
         candidate.rationale="Bullish liquidity sweep rejection";
         return true;
        }

      return false;
     }
  };

#endif
