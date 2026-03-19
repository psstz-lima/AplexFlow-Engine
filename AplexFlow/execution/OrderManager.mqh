#ifndef APLEXFLOW_EXECUTION_ORDERMANAGER_MQH
#define APLEXFLOW_EXECUTION_ORDERMANAGER_MQH

#include "../core/Context.mqh"

class OrderManager
  {
private:
   CTrade             m_trade;
   AFConfig           m_config;

   bool               IsSuccessfulRetcode(const uint retcode) const
     {
      return (retcode==TRADE_RETCODE_DONE ||
              retcode==TRADE_RETCODE_DONE_PARTIAL ||
              retcode==TRADE_RETCODE_PLACED ||
              retcode==TRADE_RETCODE_NO_CHANGES);
     }

public:
   void               Initialize(const AFConfig &config)
     {
      m_config=config;
      m_trade.SetExpertMagicNumber((long)config.magicNumber);
      m_trade.SetDeviationInPoints(config.maxSlippagePoints);
      m_trade.SetAsyncMode(false);
     }

   bool               PlaceEntry(const string symbol,const AFSignalCandidate &candidate,const double volume,ulong &ticket,string &reason)
     {
      ticket=0;
      if(volume<=0.0)
        {
         reason="volume resolved to zero";
         return false;
        }

      const string comment=AFComment(candidate);
      const double tp=AFNormalizePrice(symbol,candidate.target3);
      const double sl=AFNormalizePrice(symbol,candidate.stop);
      const double limitEntry=AFNormalizePrice(symbol,candidate.entry);

      bool ok=false;
      if(candidate.executionMethod==EXEC_MARKET)
        {
         if(candidate.direction==DIR_LONG)
            ok=m_trade.Buy(volume,symbol,0.0,sl,tp,comment);
         else if(candidate.direction==DIR_SHORT)
            ok=m_trade.Sell(volume,symbol,0.0,sl,tp,comment);
        }
      else
        {
         const datetime expiration=TimeCurrent()+(PeriodSeconds(m_config.decisionTf)*m_config.pendingExpiryBars);
         if(candidate.direction==DIR_LONG)
            ok=m_trade.BuyLimit(volume,limitEntry,symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration,comment);
         else if(candidate.direction==DIR_SHORT)
            ok=m_trade.SellLimit(volume,limitEntry,symbol,sl,tp,ORDER_TIME_SPECIFIED,expiration,comment);

         if(!ok && candidate.executionMethod==EXEC_HYBRID && m_config.allowPendingFallback)
           {
            if(candidate.direction==DIR_LONG)
               ok=m_trade.Buy(volume,symbol,0.0,sl,tp,comment);
            else if(candidate.direction==DIR_SHORT)
               ok=m_trade.Sell(volume,symbol,0.0,sl,tp,comment);
           }
        }

      if(!ok)
        {
         reason=StringFormat("order rejected retcode=%d",m_trade.ResultRetcode());
         return false;
        }

      ticket=m_trade.ResultOrder();
      if(ticket==0)
         ticket=m_trade.ResultDeal();
      reason="";
      return true;
     }

   bool               ModifyPosition(const ulong positionId,const string symbol,const double sl,const double tp)
     {
      if(!PositionSelectByTicket(positionId))
         return false;

      const long positionType=PositionGetInteger(POSITION_TYPE);
      const double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
      const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
      const double currentSl=PositionGetDouble(POSITION_SL);
      const double currentTp=PositionGetDouble(POSITION_TP);
      const double stopLevel=MathMax((double)SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL),
                                     (double)SymbolInfoInteger(symbol,SYMBOL_TRADE_FREEZE_LEVEL))*point;

      if(point>0.0)
        {
         const bool sameSl=(MathAbs(sl-currentSl)<point);
         const bool sameTp=(MathAbs(tp-currentTp)<point);
         if(sameSl && sameTp)
            return false;
        }

      if(stopLevel>0.0)
        {
         if(positionType==POSITION_TYPE_BUY)
           {
            if(sl>0.0 && sl>=(bid-stopLevel))
               return false;
            if(tp>0.0 && tp<=(ask+stopLevel))
               return false;
           }
         else if(positionType==POSITION_TYPE_SELL)
           {
            if(sl>0.0 && sl<=(ask+stopLevel))
               return false;
            if(tp>0.0 && tp>=(bid-stopLevel))
               return false;
           }
        }

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);
      request.action=TRADE_ACTION_SLTP;
      request.position=positionId;
      request.symbol=symbol;
      request.magic=m_config.magicNumber;
      request.sl=sl;
      request.tp=tp;
      if(!OrderSend(request,result))
         return false;
      return IsSuccessfulRetcode(result.retcode);
     }

   bool               ClosePartial(const ulong positionId,const string symbol,double volume)
     {
      if(!PositionSelectByTicket(positionId))
         return false;

      volume=AFNormalizeVolume(symbol,volume);
      if(volume<=0.0)
         return false;

      const long positionType=PositionGetInteger(POSITION_TYPE);
      const double bid=SymbolInfoDouble(symbol,SYMBOL_BID);
      const double ask=SymbolInfoDouble(symbol,SYMBOL_ASK);

      MqlTradeRequest request;
      MqlTradeResult result;
      ZeroMemory(request);
      ZeroMemory(result);

      request.action=TRADE_ACTION_DEAL;
      request.position=positionId;
      request.symbol=symbol;
      request.magic=m_config.magicNumber;
      request.volume=volume;
      request.deviation=m_config.maxSlippagePoints;
      request.type=(positionType==POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY);
      request.price=(positionType==POSITION_TYPE_BUY ? bid : ask);
      if(!OrderSend(request,result))
         return false;
      return IsSuccessfulRetcode(result.retcode);
     }

   bool               ClosePosition(const ulong positionId,const string symbol)
     {
      if(!PositionSelectByTicket(positionId))
         return false;
      const double volume=PositionGetDouble(POSITION_VOLUME);
      return ClosePartial(positionId,symbol,volume);
     }
  };

#endif
