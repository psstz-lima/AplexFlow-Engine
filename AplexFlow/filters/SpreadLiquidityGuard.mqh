#ifndef APLEXFLOW_FILTERS_SPREADLIQUIDITYGUARD_MQH
#define APLEXFLOW_FILTERS_SPREADLIQUIDITYGUARD_MQH

#include "../core/Context.mqh"

class SpreadLiquidityGuard
  {
public:
   bool               Allow(const AFConfig &config,const AFMicrostructureState &micro,const double atr,const string symbol) const
     {
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0.0)
         return false;
      if(micro.spreadPoints<=0.0)
         return false;
      double spreadEmergency=config.spreadEmergencyPoints;
      double maxSpreadAtrFrac=config.maxSpreadAtrFrac;
      if(AFDedicatedUs500Enabled(config) && AFIsUs500Symbol(symbol))
        {
         spreadEmergency=MathMax(spreadEmergency,320.0);
         maxSpreadAtrFrac=MathMax(maxSpreadAtrFrac,0.60);
        }
      else if(AFDedicatedXauEnabled(config) && AFIsXauSymbol(symbol))
        {
         spreadEmergency=MathMax(spreadEmergency,80.0);
         maxSpreadAtrFrac=MathMax(maxSpreadAtrFrac,0.20);
        }
      if(micro.spreadPoints>spreadEmergency)
         return false;
      if(atr<=0.0)
         return (micro.spreadPoints<=spreadEmergency*0.5);
      const double spreadFrac=(micro.spreadPoints*point)/atr;
      return (spreadFrac<=maxSpreadAtrFrac);
     }
  };

#endif
