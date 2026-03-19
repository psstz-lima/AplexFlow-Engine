#ifndef APLEXFLOW_TELEMETRY_PERFORMANCETRACKER_MQH
#define APLEXFLOW_TELEMETRY_PERFORMANCETRACKER_MQH

#include "../core/Context.mqh"

class PerformanceTracker
  {
private:
   AFStrategyStats    m_stats[AF_MAX_STRATEGIES];

public:
   void              Initialize(void)
     {
      for(int i=0; i<AF_MAX_STRATEGIES; ++i)
        {
         m_stats[i].trades=0;
         m_stats[i].wins=0;
         m_stats[i].losses=0;
         m_stats[i].grossProfit=0.0;
         m_stats[i].grossLoss=0.0;
         m_stats[i].expectancyR=0.0;
         m_stats[i].rollingScore=0.0;
         m_stats[i].cooldownUntil=0;
        }
     }

   void              ApplyOutcome(const AFTradeOutcome &outcome)
     {
      if(!outcome.valid)
         return;
      const int idx=(int)outcome.strategy;
      m_stats[idx].trades++;
      if(outcome.profit>=0.0)
        {
         m_stats[idx].wins++;
         m_stats[idx].grossProfit+=outcome.profit;
        }
      else
        {
         m_stats[idx].losses++;
         m_stats[idx].grossLoss+=MathAbs(outcome.profit);
        }
      m_stats[idx].expectancyR=(((m_stats[idx].expectancyR*(m_stats[idx].trades-1))+outcome.profitR)/(double)m_stats[idx].trades);
      m_stats[idx].rollingScore=m_stats[idx].expectancyR*ProfitFactor(outcome.strategy);
     }

   double            ProfitFactor(const AFStrategyId strategy) const
     {
      AFStrategyStats stats=m_stats[(int)strategy];
      if(stats.grossLoss<=0.0)
         return (stats.grossProfit>0.0 ? 99.0 : 0.0);
      return stats.grossProfit/stats.grossLoss;
     }

   double            WinRate(const AFStrategyId strategy) const
     {
      AFStrategyStats stats=m_stats[(int)strategy];
      if(stats.trades<=0)
         return 0.0;
      return ((double)stats.wins/(double)stats.trades)*100.0;
     }

   AFStrategyStats    Stats(const AFStrategyId strategy) const
     {
      return m_stats[(int)strategy];
     }
  };

#endif
