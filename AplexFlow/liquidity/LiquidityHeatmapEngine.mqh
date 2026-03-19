#ifndef APLEXFLOW_LIQUIDITY_LIQUIDITYHEATMAPENGINE_MQH
#define APLEXFLOW_LIQUIDITY_LIQUIDITYHEATMAPENGINE_MQH

#include "../core/Context.mqh"

class LiquidityHeatmapEngine
  {
private:
   void               AddLevel(AFLiquidityMap &map,const double price,const double strength,const int side,const string tag) const
     {
      if(price<=0.0 || map.count>=AF_MAX_LIQUIDITY_LEVELS)
         return;
      map.levels[map.count].price=price;
      map.levels[map.count].strength=strength;
      map.levels[map.count].side=side;
      map.levels[map.count].tag=tag;
      ++map.count;
     }

public:
   void               Build(const AFConfig &config,const MqlRates &decisionRates[],const double atr,AFLiquidityMap &map) const
     {
      AFResetLiquidityMap(map);
      if(ArraySize(decisionRates)<config.previousDayBars+10 || atr<=0.0)
         return;

      const double currentPrice=decisionRates[1].close;
      map.prevDayHigh=AFHighestHigh(decisionRates,config.previousDayBars,1);
      map.prevDayLow=AFLowestLow(decisionRates,config.previousDayBars,1);
      map.sessionHigh=AFHighestHigh(decisionRates,72,1);
      map.sessionLow=AFLowestLow(decisionRates,72,1);
      map.orderBlockHigh=0.0;
      map.orderBlockLow=0.0;

      AddLevel(map,map.prevDayHigh,1.0,+1,"PDH");
      AddLevel(map,map.prevDayLow,1.0,-1,"PDL");
      AddLevel(map,map.sessionHigh,0.7,+1,"SH");
      AddLevel(map,map.sessionLow,0.7,-1,"SL");
      AddLevel(map,AFHighestHigh(decisionRates,config.liquiditySwingWindow,1),0.9,+1,"SWING_H");
      AddLevel(map,AFLowestLow(decisionRates,config.liquiditySwingWindow,1),0.9,-1,"SWING_L");

      const double tolerance=config.equalLevelToleranceAtr*atr;
      for(int i=2; i<2+config.liquiditySwingWindow && i<ArraySize(decisionRates); ++i)
        {
         for(int j=i+2; j<2+config.liquiditySwingWindow && j<ArraySize(decisionRates); ++j)
           {
            if(MathAbs(decisionRates[i].high-decisionRates[j].high)<=tolerance)
              {
               map.hasEqualHigh=true;
               AddLevel(map,(decisionRates[i].high+decisionRates[j].high)*0.5,0.85,+1,"EQH");
               i=config.liquiditySwingWindow+2;
               break;
              }
            if(MathAbs(decisionRates[i].low-decisionRates[j].low)<=tolerance)
              {
               map.hasEqualLow=true;
               AddLevel(map,(decisionRates[i].low+decisionRates[j].low)*0.5,0.85,-1,"EQL");
               i=config.liquiditySwingWindow+2;
               break;
              }
           }
        }

      for(int i=2; i<2+config.orderBlockLookback && (i+1)<ArraySize(decisionRates); ++i)
        {
         if(decisionRates[i].close<decisionRates[i].open && decisionRates[i-1].close>decisionRates[i-1].open &&
            AFBarImpulse(decisionRates[i-1],atr))
           {
            map.orderBlockHigh=decisionRates[i].high;
            map.orderBlockLow=decisionRates[i].low;
            AddLevel(map,map.orderBlockHigh,0.65,+1,"OBH");
            AddLevel(map,map.orderBlockLow,0.65,-1,"OBL");
            break;
           }
        }

      map.nearestAbove=0.0;
      map.nearestBelow=0.0;
      map.heatScore=0.0;
      for(int i=0; i<map.count; ++i)
        {
         const double levelPrice=map.levels[i].price;
         if(levelPrice>currentPrice)
           {
            if(map.nearestAbove<=0.0 || levelPrice<map.nearestAbove)
               map.nearestAbove=levelPrice;
           }
         if(levelPrice<currentPrice)
           {
            if(map.nearestBelow<=0.0 || levelPrice>map.nearestBelow)
               map.nearestBelow=levelPrice;
           }

         const double distance=MathAbs(levelPrice-currentPrice);
         if(distance<=2.0*atr)
            map.heatScore+=map.levels[i].strength*(1.0-(distance/(2.0*atr)));
        }
     }
  };

#endif
