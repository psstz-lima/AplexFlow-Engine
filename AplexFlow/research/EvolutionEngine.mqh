#ifndef APLEXFLOW_RESEARCH_EVOLUTIONENGINE_MQH
#define APLEXFLOW_RESEARCH_EVOLUTIONENGINE_MQH

#include "../core/Context.mqh"
#include "../telemetry/PerformanceTracker.mqh"
#include "StrategyRanking.mqh"
#include "ParameterSearch.mqh"

class EvolutionEngine
  {
private:
   StrategyRanking    m_ranking;
   ParameterSearch    m_search;

public:
   void               ExportPreset(const AFConfig &config,const PerformanceTracker &tracker)
     {
      if(!config.enableEvolutionExport)
         return;

      int order[];
      m_ranking.Rank(tracker,order);
      const int topStrategy=(ArraySize(order)>0 ? order[0] : 0);
      const double evolvedEdge=AFClamp(config.edgeThreshold+(tracker.Stats((AFStrategyId)topStrategy).expectancyR*0.05),0.52,0.80);
      const string body=m_search.BuildPresetBody(config,topStrategy,evolvedEdge);

      FolderCreate("AplexFlow",FILE_COMMON);
      const string path="AplexFlow\\"+config.presetOutputName;
      const int handle=FileOpen(path,FILE_COMMON|FILE_WRITE|FILE_TXT|FILE_ANSI);
      if(handle==INVALID_HANDLE)
         return;
      FileWriteString(handle,body);
      FileClose(handle);
     }
  };

#endif
