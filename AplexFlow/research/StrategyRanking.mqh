#ifndef APLEXFLOW_RESEARCH_STRATEGYRANKING_MQH
#define APLEXFLOW_RESEARCH_STRATEGYRANKING_MQH

#include "../telemetry/PerformanceTracker.mqh"

class StrategyRanking
  {
public:
   void               Rank(const PerformanceTracker &tracker,int &order[]) const
     {
      ArrayResize(order,AF_MAX_STRATEGIES);
      double scores[AF_MAX_STRATEGIES];
      for(int i=0; i<AF_MAX_STRATEGIES; ++i)
        {
         order[i]=i;
         scores[i]=tracker.Stats((AFStrategyId)i).expectancyR*tracker.ProfitFactor((AFStrategyId)i);
        }

      for(int i=0; i<AF_MAX_STRATEGIES-1; ++i)
        {
         for(int j=i+1; j<AF_MAX_STRATEGIES; ++j)
           {
            if(scores[j]>scores[i])
              {
               const double tmpScore=scores[i];
               scores[i]=scores[j];
               scores[j]=tmpScore;
               const int tmpOrder=order[i];
               order[i]=order[j];
               order[j]=tmpOrder;
              }
           }
        }
     }
  };

#endif
