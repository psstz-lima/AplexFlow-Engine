#ifndef APLEXFLOW_EXECUTION_TRADECLUSTERINGENGINE_MQH
#define APLEXFLOW_EXECUTION_TRADECLUSTERINGENGINE_MQH

#include "../core/Context.mqh"

class TradeClusteringEngine
  {
public:
   int                BuildClusterId(const datetime barTime,const AFStrategyId strategy) const
     {
      return ((int)(barTime/300)%100000)+((int)strategy*100000);
     }

   bool               Allow(const AFConfig &config,const AFSymbolState &state,const AFSignalCandidate &candidate,const AFVolatilityForecast &forecast,string &reason) const
     {
      const int entries=state.clusterEntries[(int)candidate.strategy];
      if(entries==0)
        {
         reason="";
         return true;
        }
      if(entries>=config.maxClusterEntries)
        {
         reason="cluster entry cap reached";
         return false;
        }
      if(forecast.breakoutProbability<0.60)
        {
         reason="scale-in blocked without volatility confirmation";
         return false;
        }
      reason="";
      return true;
     }

   double             ScaleInRiskMultiplier(const AFSymbolState &state,const AFSignalCandidate &candidate) const
     {
      const int entries=state.clusterEntries[(int)candidate.strategy];
      if(entries<=0)
         return 1.0;
      if(entries==1)
         return 0.70;
      return 0.50;
     }
  };

#endif
