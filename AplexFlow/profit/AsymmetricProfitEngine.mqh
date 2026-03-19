#ifndef APLEXFLOW_PROFIT_ASYMMETRICPROFITENGINE_MQH
#define APLEXFLOW_PROFIT_ASYMMETRICPROFITENGINE_MQH

#include "../core/Context.mqh"
#include "../execution/OrderManager.mqh"

class AsymmetricProfitEngine
  {
private:
   double             MinStopDistance(const string symbol) const
     {
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      if(point<=0.0)
         return 0.0;
      const double raw=MathMax((double)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
                               (double)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL));
      return raw*point;
     }

   double             MinTrailStep(const AFConfig &config,const string symbol,const double atr) const
     {
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      double step=MathMax(0.0,config.trailStepAtr*atr);
      if(point>0.0)
         step=MathMax(step,5.0*point);
      return step;
     }

   bool               TrailCooldownReady(const AFConfig &config,const AFPositionPlan &plan) const
     {
      if(config.minStopUpdateSeconds<=0 || plan.lastStopUpdateTime<=0)
         return true;
      return ((TimeCurrent()-plan.lastStopUpdateTime)>=config.minStopUpdateSeconds);
     }

public:
   void               Manage(const AFConfig &config,AFPositionPlan &plan,const double atr,OrderManager &orders) const
     {
      if(!plan.active || !PositionSelectByTicket(plan.positionId))
         return;

      const double point=SymbolInfoDouble(plan.symbol,SYMBOL_POINT);
      if(point<=0.0)
         return;

      const long positionType=PositionGetInteger(POSITION_TYPE);
      const double currentVolume=PositionGetDouble(POSITION_VOLUME);
      const double currentSl=PositionGetDouble(POSITION_SL);
      const double currentTp=PositionGetDouble(POSITION_TP);
      const double bid=SymbolInfoDouble(plan.symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(plan.symbol,SYMBOL_ASK);
      const double currentPrice=(positionType==POSITION_TYPE_BUY ? bid : ask);
      const double currentR=AFUnrealizedR(plan,currentPrice);

      if(!plan.tp1Done && currentR>=config.tp1R && currentVolume>SymbolInfoDouble(plan.symbol,SYMBOL_VOLUME_MIN))
        {
         const double targetVolume=MathMax(SymbolInfoDouble(plan.symbol,SYMBOL_VOLUME_MIN),plan.volumeInitial*0.33);
         if(orders.ClosePartial(plan.positionId,plan.symbol,targetVolume))
           {
            plan.tp1Done=true;
            plan.volumeRemaining=MathMax(0.0,currentVolume-targetVolume);
           }
        }

      if(!plan.movedBreakEven && currentR>=config.breakEvenAtR)
        {
         const double breakeven=plan.entry+((plan.direction==DIR_LONG ? 2.0 : -2.0)*point);
         if((plan.direction==DIR_LONG && currentSl>=breakeven-point) ||
            (plan.direction==DIR_SHORT && currentSl>0.0 && currentSl<=breakeven+point))
           {
            plan.movedBreakEven=true;
            plan.lastManagedStop=currentSl;
           }
         else
           {
            const double normalizedBreakeven=AFNormalizePrice(plan.symbol,breakeven);
            if(orders.ModifyPosition(plan.positionId,plan.symbol,normalizedBreakeven,currentTp))
              {
               plan.movedBreakEven=true;
               plan.lastManagedStop=normalizedBreakeven;
               plan.lastStopUpdateTime=TimeCurrent();
              }
           }
        }

      if(!plan.tp2Done && currentR>=config.tp2R && PositionSelectByTicket(plan.positionId))
        {
         const double liveVolume=PositionGetDouble(POSITION_VOLUME);
         const double targetVolume=MathMax(SymbolInfoDouble(plan.symbol,SYMBOL_VOLUME_MIN),plan.volumeInitial*0.33);
         if(liveVolume>(targetVolume+SymbolInfoDouble(plan.symbol,SYMBOL_VOLUME_MIN)) && orders.ClosePartial(plan.positionId,plan.symbol,targetVolume))
           {
            plan.tp2Done=true;
            plan.volumeRemaining=MathMax(0.0,liveVolume-targetVolume);
           }
        }

      if(currentR>=config.trailStartR && atr>0.0)
        {
         double trailingStop=currentSl;
         if(plan.direction==DIR_LONG)
            trailingStop=MathMax(currentSl,currentPrice-(config.trailAtrMult*atr));
         else if(plan.direction==DIR_SHORT)
            trailingStop=MathMin(currentSl>0.0 ? currentSl : DBL_MAX,currentPrice+(config.trailAtrMult*atr));

         if(plan.direction==DIR_SHORT && currentSl<=0.0)
            trailingStop=currentPrice+(config.trailAtrMult*atr);

         const double minDistance=MinStopDistance(plan.symbol);
         const double minStep=MinTrailStep(config,plan.symbol,atr);
         bool shouldModify=false;
         if(plan.direction==DIR_LONG)
            shouldModify=(trailingStop>(currentSl+minStep) && trailingStop<(currentPrice-minDistance));
         else if(plan.direction==DIR_SHORT)
            shouldModify=((currentSl<=0.0 || trailingStop<(currentSl-minStep)) && trailingStop>(currentPrice+minDistance));

         if(shouldModify && TrailCooldownReady(config,plan))
           {
            const double normalizedStop=AFNormalizePrice(plan.symbol,trailingStop);
            if(orders.ModifyPosition(plan.positionId,plan.symbol,normalizedStop,currentTp))
              {
               plan.lastManagedStop=normalizedStop;
               plan.lastStopUpdateTime=TimeCurrent();
              }
           }
        }

      const int barsOpen=(int)((TimeCurrent()-plan.openTime)/PeriodSeconds(config.decisionTf));
      if(barsOpen>=config.earlyLossBars && currentR<config.earlyLossProgressR)
        {
         if((plan.direction==DIR_LONG && currentPrice<plan.entry-(0.35*plan.riskRPoints)) ||
            (plan.direction==DIR_SHORT && currentPrice>plan.entry+(0.35*plan.riskRPoints)))
            orders.ClosePosition(plan.positionId,plan.symbol);
        }
     }
  };

#endif
