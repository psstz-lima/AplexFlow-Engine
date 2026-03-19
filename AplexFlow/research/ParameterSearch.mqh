#ifndef APLEXFLOW_RESEARCH_PARAMETERSEARCH_MQH
#define APLEXFLOW_RESEARCH_PARAMETERSEARCH_MQH

#include "../core/Context.mqh"

class ParameterSearch
  {
public:
   string             BuildPresetBody(const AFConfig &config,const int topStrategy,const double evolvedEdgeThreshold) const
     {
      const bool enableBreakout=(topStrategy==STRATEGY_VOLATILITY_BREAKOUT ||
                                 topStrategy==STRATEGY_XAU_SESSION_BREAKOUT ||
                                 config.enableBreakout);
      const bool enableMomentum=(topStrategy==STRATEGY_MOMENTUM_CONTINUATION ||
                                 topStrategy==STRATEGY_US500_OPEN_DRIVE ||
                                 config.enableMomentum);
      const bool enableMeanReversion=(topStrategy==STRATEGY_MEAN_REVERSION || config.enableMeanReversion);
      const bool enableSweep=(topStrategy==STRATEGY_LIQUIDITY_SWEEP || config.enableSweep);

      string body="";
      body+="InpSymbols="+InpSymbols+"\r\n";
      body+="InpDecisionTimeframe="+(string)config.decisionTf+"\r\n";
      body+="InpMicrostructureTimeframe="+(string)config.microTf+"\r\n";
      body+="InpEdgeThreshold="+DoubleToString(evolvedEdgeThreshold,2)+"\r\n";
      body+="InpEnableBreakout="+(enableBreakout ? "true" : "false")+"\r\n";
      body+="InpEnableMomentum="+(enableMomentum ? "true" : "false")+"\r\n";
      body+="InpEnableMeanReversion="+(enableMeanReversion ? "true" : "false")+"\r\n";
      body+="InpEnableSweep="+(enableSweep ? "true" : "false")+"\r\n";
      body+="InpBacktestLatencyMs="+(string)config.backtestLatencyMs+"\r\n";
      return body;
     }
  };

#endif
