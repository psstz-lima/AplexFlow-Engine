#ifndef APLEXFLOW_TELEMETRY_TELEMETRYENGINE_MQH
#define APLEXFLOW_TELEMETRY_TELEMETRYENGINE_MQH

#include "../core/Context.mqh"
#include "PerformanceTracker.mqh"

class TelemetryEngine
  {
private:
   bool               m_enabled;

   void               AppendLine(const string fileName,const string line) const
     {
      if(!m_enabled)
         return;
      FolderCreate("AplexFlow",FILE_COMMON);
      const string path="AplexFlow\\"+fileName;
      int handle=FileOpen(path,FILE_COMMON|FILE_READ|FILE_WRITE|FILE_TXT|FILE_ANSI|FILE_SHARE_READ|FILE_SHARE_WRITE);
      if(handle==INVALID_HANDLE)
         return;
      FileSeek(handle,0,SEEK_END);
      FileWriteString(handle,line+"\r\n");
      FileClose(handle);
     }

public:
   void              Initialize(const AFConfig &config)
     {
      m_enabled=config.enableTelemetry;
      if(m_enabled)
         AppendLine("engine.log",StringFormat("%s,INIT,%s,%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),_Symbol,AccountInfoString(ACCOUNT_COMPANY)));
     }

   void              LogSignal(const string symbol,const AFMarketRegime regime,const AFSignalCandidate &candidate) const
     {
      AppendLine("signals.csv",
                 StringFormat("%s,%s,%s,%s,%.4f,%.4f,%s,%s",
                              TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                              symbol,
                              AFMarketRegimeName(regime),
                              AFStrategyCode(candidate.strategy),
                              candidate.edgeScore,
                              candidate.confidence,
                              AFExecutionMethodName(candidate.executionMethod),
                              candidate.rationale));
     }

   void              LogBlock(const string symbol,const string reason) const
     {
      AppendLine("blocks.csv",
                 StringFormat("%s,%s,%s",
                              TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),
                              symbol,
                              reason));
     }

   void              LogOutcome(const AFTradeOutcome &outcome,const PerformanceTracker &tracker) const
     {
      AppendLine("trades.csv",
                 StringFormat("%s,%s,%s,%.2f,%.3f,%.2f,%.2f",
                              TimeToString(outcome.closeTime,TIME_DATE|TIME_SECONDS),
                              outcome.symbol,
                              AFStrategyCode(outcome.strategy),
                              outcome.profit,
                              outcome.profitR,
                              tracker.ProfitFactor(outcome.strategy),
                              tracker.WinRate(outcome.strategy)));
     }

   void              LogInfo(const string message) const
     {
      AppendLine("engine.log",StringFormat("%s,INFO,%s",TimeToString(TimeCurrent(),TIME_DATE|TIME_SECONDS),message));
     }
  };

#endif
