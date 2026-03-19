#ifndef APLEXFLOW_RISK_RISKCONTAINMENTSYSTEM_MQH
#define APLEXFLOW_RISK_RISKCONTAINMENTSYSTEM_MQH

#include "../core/Context.mqh"

class RiskContainmentSystem
  {
private:
   double             m_dayStartEquity;
   double             m_weekStartEquity;
   double             m_peakEquity;
   double             m_weekPeakEquity;
   bool               m_hardBlocked;
   string             m_blockReason;

public:
                     RiskContainmentSystem(void)
     {
      m_dayStartEquity=0.0;
      m_weekStartEquity=0.0;
      m_peakEquity=0.0;
      m_weekPeakEquity=0.0;
      m_hardBlocked=false;
      m_blockReason="";
     }

   void              Initialize(void)
     {
      const double equity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_dayStartEquity=equity;
      m_weekStartEquity=equity;
      m_peakEquity=equity;
      m_weekPeakEquity=equity;
      m_hardBlocked=false;
      m_blockReason="";
     }

   void              ResetDay(void)
     {
      m_dayStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_hardBlocked=false;
      m_blockReason="";
     }

   void              ResetWeek(void)
     {
      m_weekStartEquity=AccountInfoDouble(ACCOUNT_EQUITY);
      m_weekPeakEquity=m_weekStartEquity;
      m_hardBlocked=false;
      m_blockReason="";
     }

   void              Refresh(const AFConfig &config,AFPortfolioSnapshot &snapshot)
     {
      snapshot.balance=AccountInfoDouble(ACCOUNT_BALANCE);
      snapshot.equity=AccountInfoDouble(ACCOUNT_EQUITY);
      snapshot.freeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);

      m_peakEquity=MathMax(m_peakEquity,snapshot.equity);
      m_weekPeakEquity=MathMax(m_weekPeakEquity,snapshot.equity);
      snapshot.peakEquity=m_peakEquity;
      snapshot.peakWeekEquity=m_weekPeakEquity;

      snapshot.drawdownPct=(m_peakEquity>0.0 ? ((m_peakEquity-snapshot.equity)/m_peakEquity)*100.0 : 0.0);
      snapshot.dailyPnlPct=(m_dayStartEquity>0.0 ? ((snapshot.equity-m_dayStartEquity)/m_dayStartEquity)*100.0 : 0.0);
      snapshot.weeklyPnlPct=(m_weekStartEquity>0.0 ? ((snapshot.equity-m_weekStartEquity)/m_weekStartEquity)*100.0 : 0.0);
      snapshot.blockNewRisk=false;
      snapshot.blockReason="";

      if(snapshot.drawdownPct>=config.maxEquityDrawdownPct)
        {
         m_hardBlocked=true;
         m_blockReason=StringFormat("Equity DD %.2f%% >= %.2f%%",snapshot.drawdownPct,config.maxEquityDrawdownPct);
        }
      else if(snapshot.dailyPnlPct<=-config.maxDailyLossPct)
        {
         snapshot.blockNewRisk=true;
         snapshot.blockReason=StringFormat("Daily loss %.2f%% <= -%.2f%%",snapshot.dailyPnlPct,config.maxDailyLossPct);
        }
      else if(snapshot.weeklyPnlPct>=config.weeklyProfitLockPct)
        {
         const double weekGain=MathMax(0.0,m_weekPeakEquity-m_weekStartEquity);
         const double giveback=MathMax(0.0,m_weekPeakEquity-snapshot.equity);
         const double givebackPct=(weekGain>0.0 ? (giveback/weekGain)*100.0 : 0.0);
         if(givebackPct>=config.weeklyProfitGivebackPct)
           {
            snapshot.blockNewRisk=true;
            snapshot.blockReason=StringFormat("Weekly profit lock active (giveback %.2f%%)",givebackPct);
           }
        }

      if(m_hardBlocked)
        {
         snapshot.blockNewRisk=true;
         snapshot.blockReason=m_blockReason;
        }
     }

   bool              CanTrade(string &reason) const
     {
      reason=m_blockReason;
      return !m_hardBlocked;
     }
  };

#endif
