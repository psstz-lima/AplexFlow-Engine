#ifndef APLEXFLOW_RESEARCH_BACKTESTRUNNER_MQH
#define APLEXFLOW_RESEARCH_BACKTESTRUNNER_MQH

#include "../core/Context.mqh"

class BacktestRunner
  {
public:
   bool               IsResearchContext(void) const
     {
      return (MQLInfoInteger(MQL_TESTER)!=0 || MQLInfoInteger(MQL_OPTIMIZATION)!=0);
     }

   string             ContextTag(const AFConfig &config) const
     {
      return StringFormat("tf=%s micro=%s latency=%dms symbols=%d",
                          EnumToString(config.decisionTf),
                          EnumToString(config.microTf),
                          config.backtestLatencyMs,
                          config.symbolCount);
     }
  };

#endif
