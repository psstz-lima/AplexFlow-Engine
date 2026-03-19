#ifndef APLEXFLOW_CORE_STATEMACHINE_MQH
#define APLEXFLOW_CORE_STATEMACHINE_MQH

#include "Context.mqh"

class AplexFlowStateMachine
  {
private:
   int m_dayKey;
   int m_weekKey;

public:
                     AplexFlowStateMachine(void)
     {
      m_dayKey=0;
      m_weekKey=0;
     }

   void              Initialize(void)
     {
      const datetime now=TimeCurrent();
      m_dayKey=AFCurrentDayKey(now);
      m_weekKey=AFCurrentWeekKey(now);
     }

   bool              RollCalendar(const datetime now,bool &newDay,bool &newWeek)
     {
      const int dayKey=AFCurrentDayKey(now);
      const int weekKey=AFCurrentWeekKey(now);
      newDay=(dayKey!=m_dayKey);
      newWeek=(weekKey!=m_weekKey);
      if(newDay)
         m_dayKey=dayKey;
      if(newWeek)
         m_weekKey=weekKey;
      return (newDay || newWeek);
     }

   bool              IsNewDecisionBar(AFSymbolState &state,const ENUM_TIMEFRAMES timeframe)
     {
      const datetime currentBar=iTime(state.symbol,timeframe,0);
      if(currentBar<=0)
         return false;
      if(state.lastDecisionBar==0)
        {
         state.lastDecisionBar=currentBar;
         return true;
        }
      if(currentBar!=state.lastDecisionBar)
        {
         state.lastDecisionBar=currentBar;
         return true;
        }
      return false;
     }

   bool              IsStrategyBlocked(const AFSymbolState &state,const AFStrategyId strategy,const datetime now) const
     {
      return (state.strategyBlockedUntil[(int)strategy]>now);
     }

   bool              IsSymbolBlocked(const AFSymbolState &state,const datetime now) const
     {
      return (state.performance.blockedUntil>now);
     }

   void              BlockStrategy(AFSymbolState &state,const AFStrategyId strategy,const int minutes)
     {
      state.strategyBlockedUntil[(int)strategy]=TimeCurrent()+(minutes*60);
     }

   void              BlockSymbol(AFSymbolState &state,const int minutes)
     {
      state.performance.blockedUntil=TimeCurrent()+(minutes*60);
     }

   int               ActiveClusterEntries(const AFSymbolState &state,const AFStrategyId strategy,const int clusterId) const
     {
      if(state.clusterIds[(int)strategy]!=clusterId)
         return 0;
      return state.clusterEntries[(int)strategy];
     }

   void              MarkClusterTrade(AFSymbolState &state,const AFStrategyId strategy,const int clusterId)
     {
      const int idx=(int)strategy;
      if(state.clusterIds[idx]!=clusterId)
        {
         state.clusterIds[idx]=clusterId;
         state.clusterEntries[idx]=0;
        }
      state.clusterEntries[idx]++;
     }

   void              ReduceClusterEntry(AFSymbolState &state,const AFStrategyId strategy)
     {
      const int idx=(int)strategy;
      state.clusterEntries[idx]=MathMax(0,state.clusterEntries[idx]-1);
     }

   void              ResetDailyState(AFSymbolState &state)
     {
      state.tradesToday=0;
      state.lossesToday=0;
      for(int i=0; i<AF_MAX_STRATEGIES; ++i)
         state.clusterEntries[i]=0;
     }
  };

#endif
