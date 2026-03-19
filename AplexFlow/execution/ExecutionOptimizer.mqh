#ifndef APLEXFLOW_EXECUTION_EXECUTIONOPTIMIZER_MQH
#define APLEXFLOW_EXECUTION_EXECUTIONOPTIMIZER_MQH

#include "../core/Context.mqh"

class ExecutionOptimizer
  {
public:
   void               Select(const AFConfig &config,const AFMicrostructureState &micro,const AFSessionState &session,const AFVolatilityForecast &forecast,AFSignalCandidate &candidate) const
     {
      const double riskDistance=MathAbs(candidate.entry-candidate.stop);
      if(candidate.strategy==STRATEGY_LIQUIDITY_SWEEP || candidate.strategy==STRATEGY_MEAN_REVERSION)
         candidate.executionMethod=(config.allowPendingFallback ? EXEC_HYBRID : EXEC_LIMIT);
      else if(candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
        {
         if(candidate.alphaStrength>=0.90 && session.allowAggressive)
            candidate.executionMethod=EXEC_MARKET;
         else
            candidate.executionMethod=(config.allowPendingFallback && micro.stable ? EXEC_HYBRID : EXEC_MARKET);
        }
      else if(candidate.strategy==STRATEGY_US500_OPEN_DRIVE)
        {
         if(candidate.direction==DIR_LONG && candidate.confidence>=0.90)
            candidate.executionMethod=EXEC_MARKET;
         else
            candidate.executionMethod=(config.allowPendingFallback ? EXEC_HYBRID : EXEC_MARKET);
        }
      else if(candidate.strategy==STRATEGY_US500_IMPULSE_PULLBACK)
        {
         if(forecast.impulseCandle && candidate.alphaStrength>=0.88)
            candidate.executionMethod=EXEC_MARKET;
         else
            candidate.executionMethod=(config.allowPendingFallback && micro.stable ? EXEC_HYBRID : EXEC_MARKET);
        }
      else if(candidate.strategy==STRATEGY_XAU_SESSION_BREAKOUT)
        {
         if(candidate.alphaStrength>=0.85 && forecast.impulseCandle)
            candidate.executionMethod=EXEC_MARKET;
         else
            candidate.executionMethod=(config.allowPendingFallback && micro.stable ? EXEC_HYBRID : EXEC_MARKET);
        }
      else if(candidate.confidence>=0.78 || forecast.impulseCandle || session.allowAggressive)
         candidate.executionMethod=EXEC_MARKET;
      else if(config.allowPendingFallback && micro.stable)
         candidate.executionMethod=EXEC_HYBRID;
      else
         candidate.executionMethod=EXEC_MARKET;

      if(candidate.executionMethod!=EXEC_MARKET && riskDistance>0.0)
        {
         const double retrace=0.25*riskDistance;
         if(candidate.direction==DIR_LONG)
            candidate.entry-=retrace;
         else if(candidate.direction==DIR_SHORT)
            candidate.entry+=retrace;
        }
     }
  };

#endif
