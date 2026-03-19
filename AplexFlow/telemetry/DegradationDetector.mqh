#ifndef APLEXFLOW_TELEMETRY_DEGRADATIONDETECTOR_MQH
#define APLEXFLOW_TELEMETRY_DEGRADATIONDETECTOR_MQH

#include "../core/Context.mqh"
#include "PerformanceTracker.mqh"

class DegradationDetector
  {
public:
   bool               ShouldDisable(const AFConfig &config,const PerformanceTracker &tracker,const AFStrategyId strategy,int &cooldownMinutes,string &reason) const
     {
      AFStrategyStats stats=tracker.Stats(strategy);
      if(stats.trades<config.degradationWindow)
         return false;

      const double pf=tracker.ProfitFactor(strategy);
      if(stats.expectancyR<config.minExpectancyR || pf<0.95)
        {
         cooldownMinutes=180;
         reason=StringFormat("%s degraded: expectancy %.3fR pf %.2f",AFStrategyName(strategy),stats.expectancyR,pf);
         return true;
        }
      return false;
     }

   bool               ShouldDisableSymbol(const AFConfig &config,const AFSymbolState &state,int &cooldownMinutes,string &reason) const
     {
      AFSymbolPerformance performance=state.performance;
      if(performance.trades<config.symbolDegradationWindow)
         return false;

      const double pf=AFProfitFactor(performance);
      if(performance.expectancyR<config.minSymbolExpectancyR || pf<config.symbolMinProfitFactor)
        {
         cooldownMinutes=config.symbolCooldownMinutes;
         reason=StringFormat("%s degraded: expectancy %.3fR pf %.2f",state.symbol,performance.expectancyR,pf);
         return true;
        }
      return false;
     }
  };

#endif
