#property strict
#property version   "2.00"
#property description "AplexFlow Engine - Adaptive Quantitative Framework"

#include "AplexFlow/core/Engine.mqh"

AplexFlowEngine g_engine;

int OnInit()
  {
   return g_engine.OnInit();
  }

void OnTick()
  {
   g_engine.OnTick();
  }

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
  {
   g_engine.OnTradeTransaction(trans,request,result);
  }
