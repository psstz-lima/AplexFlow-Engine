#ifndef APLEXFLOW_RISK_CONVEXPOSITIONSIZING_MQH
#define APLEXFLOW_RISK_CONVEXPOSITIONSIZING_MQH

#include "../core/Context.mqh"

class ConvexPositionSizing
  {
public:
   double             BaseRiskPct(const double balance) const
     {
      if(balance<400.0)
         return 2.5;
      if(balance<800.0)
         return 2.2;
      if(balance<1500.0)
         return 2.0;
      if(balance<3000.0)
         return 1.5;
      return 1.2;
     }

   double             ComputeRiskPct(const AFConfig &config,const double balance,const double confidence,const AFVolatilityForecast &forecast,const AFSessionState &session,const double correlationPenalty) const
     {
      double riskPct=BaseRiskPct(balance);
      riskPct*=AFClamp(0.60+(confidence*0.90),0.60,1.35);
      riskPct*=AFClamp(1.20-(0.25*MathMax(0.0,forecast.atrAcceleration-1.0)),0.75,1.15);
      riskPct*=AFClamp(0.70+(0.50*session.activityScore),0.65,1.15);
      riskPct*=AFClamp(1.0-(0.55*correlationPenalty),0.35,1.0);
      riskPct=MathMin(riskPct,config.maxPerSymbolRiskPct);
      return AFClamp(riskPct,0.20,config.maxPerSymbolRiskPct);
     }
  };

#endif
