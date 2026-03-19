#ifndef APLEXFLOW_MODELS_VOLATILITYFORECASTMODEL_MQH
#define APLEXFLOW_MODELS_VOLATILITYFORECASTMODEL_MQH

#include "../core/Context.mqh"

class VolatilityForecastModel
  {
public:
   AFVolatilityForecast Forecast(const AFConfig &config,const MqlRates &decisionRates[]) const
     {
      AFVolatilityForecast forecast;
      forecast.atrFast=AFComputeATR(decisionRates,config.atrPeriod,1);
      forecast.atrSlow=AFComputeATR(decisionRates,config.atrPeriod,config.atrPeriod+1);

      double avgRange=0.0;
      int used=0;
      for(int i=2; i<2+config.compressionLookback && i<ArraySize(decisionRates); ++i)
        {
         avgRange+=AFBarRange(decisionRates[i]);
         ++used;
        }
      if(used>0)
         avgRange/=(double)used;
      const double currentRange=AFBarRange(decisionRates[1]);
      forecast.compression=(avgRange>0.0 ? currentRange/avgRange : 1.0);
      forecast.atrAcceleration=(forecast.atrSlow>0.0 ? forecast.atrFast/forecast.atrSlow : 1.0);
      forecast.impulseCandle=AFBarImpulse(decisionRates[1],forecast.atrFast);

      double rawProb=0.0;
      rawProb+=0.45*AFClamp(forecast.atrAcceleration/config.volExpansionThreshold,0.0,2.0);
      rawProb+=0.35*AFClamp((1.0/MathMax(0.2,forecast.compression)),0.0,2.5);
      rawProb+=0.20*(forecast.impulseCandle ? 1.0 : 0.0);
      forecast.breakoutProbability=AFClamp(rawProb/2.0,0.0,1.0);
      return forecast;
     }
  };

#endif
