#ifndef APLEXFLOW_FILTERS_MARKETMICROSTRUCTUREFILTER_MQH
#define APLEXFLOW_FILTERS_MARKETMICROSTRUCTUREFILTER_MQH

#include "../core/Context.mqh"

class MarketMicrostructureFilter
  {
public:
   AFMicrostructureState Evaluate(const AFConfig &config,const string symbol,const MqlRates &microRates[],const double atr,const AFSessionState &session) const
     {
      AFMicrostructureState state;
      state.spreadPoints=AFSpreadPoints(symbol);
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      state.spreadAtrFrac=(atr>0.0 ? (state.spreadPoints*point)/atr : 0.0);

      int directionChangeLimit=6;
      double wickNoiseCeiling=0.58;
      double liquidityFloor=0.30;
      double spreadEmergency=config.spreadEmergencyPoints;

      if(AFDedicatedUs500Enabled(config) && AFIsUs500Symbol(symbol))
        {
         directionChangeLimit=(session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP ? 9 : 8);
         wickNoiseCeiling=(session.tag==SESSION_NEWYORK || session.tag==SESSION_OVERLAP ? 0.76 : 0.72);
         liquidityFloor=0.18;
         spreadEmergency=MathMax(spreadEmergency,320.0);
        }
      else if(AFDedicatedXauEnabled(config) && AFIsXauSymbol(symbol))
        {
         directionChangeLimit=7;
         wickNoiseCeiling=0.66;
         liquidityFloor=0.24;
         spreadEmergency=MathMax(spreadEmergency,80.0);
        }

      double wickNoise=0.0;
      int directionChanges=0;
      int lastSign=0;
      const int maxBars=MathMin(10,ArraySize(microRates)-1);
      for(int i=1; i<=maxBars; ++i)
        {
         wickNoise+=AFWickNoise(microRates[i]);
         const int sign=(microRates[i].close>microRates[i].open ? 1 : (microRates[i].close<microRates[i].open ? -1 : 0));
         if(i>1 && sign!=0 && lastSign!=0 && sign!=lastSign)
            directionChanges++;
         if(sign!=0)
            lastSign=sign;
        }
      if(maxBars>0)
         wickNoise/=(double)maxBars;

      state.wickNoise=wickNoise;
      state.erraticTicks=(directionChanges>=directionChangeLimit && wickNoise>=wickNoiseCeiling);
      state.spreadOk=(state.spreadPoints<=spreadEmergency);
      state.liquidityOk=(session.activityScore>=liquidityFloor || wickNoise<=(wickNoiseCeiling-0.18));
      state.stable=(state.spreadOk && state.liquidityOk && !state.erraticTicks);
      return state;
     }
  };

#endif
