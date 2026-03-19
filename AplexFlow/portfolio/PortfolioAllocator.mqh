#ifndef APLEXFLOW_PORTFOLIO_PORTFOLIOALLOCATOR_MQH
#define APLEXFLOW_PORTFOLIO_PORTFOLIOALLOCATOR_MQH

#include "../core/Context.mqh"

class PortfolioAllocator
  {
public:
   bool               Allocate(const AFConfig &config,const AFPortfolioSnapshot &snapshot,const string symbol,const AFSignalCandidate &candidate,const double requestedRiskPct,const int activePositions,const int activeCarrierPositions,double &approvedRiskPct,string &reason) const
     {
      approvedRiskPct=0.0;
      const bool carrierReserveEnabled=AFHasCarrierReserveUniverse(config);
      const bool candidateCarrier=(candidate.dedicatedAlpha && AFCarrierReserveEligibleSymbol(config,symbol));
      const double reserveRiskPct=(carrierReserveEnabled ? MathMin(0.65,MathMax(0.35,config.maxPortfolioRiskPct*0.18)) : 0.0);
      if(snapshot.blockNewRisk)
        {
         reason=snapshot.blockReason;
         return false;
        }
      if(!candidateCarrier &&
         carrierReserveEnabled &&
         activeCarrierPositions<=0 &&
         config.maxPositions>1 &&
         activePositions>=(config.maxPositions-1))
        {
         reason="portfolio slot reserved for dedicated carrier";
         return false;
        }
      if(activePositions>=config.maxPositions)
        {
         reason="portfolio max positions reached";
         return false;
        }
      const double remaining=MathMax(0.0,config.maxPortfolioRiskPct-snapshot.totalOpenRiskPct);
      double usableRemaining=remaining;
      if(!candidateCarrier && carrierReserveEnabled && activeCarrierPositions<=0)
         usableRemaining=MathMax(0.0,remaining-reserveRiskPct);

      if(usableRemaining<=0.0)
        {
         reason=(carrierReserveEnabled && !candidateCarrier && activeCarrierPositions<=0
                 ? "portfolio risk reserved for dedicated carrier"
                 : "portfolio risk budget exhausted");
         return false;
        }

      const double executableFloor=(candidate.dedicatedAlpha ? 0.15 : 0.20);
      if(usableRemaining<executableFloor)
        {
         reason=(candidateCarrier ? "portfolio risk budget exhausted" : "portfolio risk reserved for dedicated carrier");
         return false;
        }

      double adjustedRequest=requestedRiskPct;
      if(candidate.dedicatedAlpha)
         adjustedRequest*=AFClamp(0.98+(0.08*candidate.alphaStrength),0.98,1.06);

      approvedRiskPct=MathMin(adjustedRequest,usableRemaining);
      if(approvedRiskPct<executableFloor)
        {
         reason="approved risk below executable floor";
         return false;
        }
      reason="";
      return true;
     }
  };

#endif
