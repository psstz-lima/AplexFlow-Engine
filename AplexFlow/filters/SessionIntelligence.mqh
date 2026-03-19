#ifndef APLEXFLOW_FILTERS_SESSIONINTELLIGENCE_MQH
#define APLEXFLOW_FILTERS_SESSIONINTELLIGENCE_MQH

#include "../core/Context.mqh"

class SessionIntelligence
  {
public:
   AFSessionState     Evaluate(const AFConfig &config) const
     {
      AFSessionState state;
      const datetime gmt=TimeGMT();
      MqlDateTime dt;
      TimeToStruct(gmt,dt);
      const int hour=dt.hour;

      const bool london=(hour>=config.londonOpenUtc && hour<config.londonCloseUtc);
      const bool newYork=(hour>=config.newYorkOpenUtc && hour<config.newYorkCloseUtc);

      state.allowAggressive=false;
      if(london && newYork)
        {
         state.tag=SESSION_OVERLAP;
         state.activityScore=1.00;
         state.allowAggressive=true;
        }
      else if(london)
        {
         state.tag=SESSION_LONDON;
         state.activityScore=0.90;
         state.allowAggressive=config.tradeLondon;
        }
      else if(newYork)
        {
         state.tag=SESSION_NEWYORK;
         state.activityScore=0.86;
         state.allowAggressive=config.tradeNewYork;
        }
      else if(hour>=0 && hour<6)
        {
         state.tag=SESSION_ASIA;
         state.activityScore=0.35;
        }
      else
        {
         state.tag=SESSION_OFF;
         state.activityScore=0.20;
        }
      return state;
     }
  };

#endif
