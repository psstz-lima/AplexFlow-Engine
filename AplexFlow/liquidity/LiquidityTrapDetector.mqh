#ifndef APLEXFLOW_LIQUIDITY_LIQUIDITYTRAPDETECTOR_MQH
#define APLEXFLOW_LIQUIDITY_LIQUIDITYTRAPDETECTOR_MQH

#include "../core/Context.mqh"

class LiquidityTrapDetector
  {
public:
   double             ScoreTrap(const AFSignalCandidate &sweepCandidate,const MqlRates &microRates[]) const
     {
      if(!sweepCandidate.valid || ArraySize(microRates)<8)
         return 0.0;

      int adverseBursts=0;
      int favorableBursts=0;
      for(int i=1; i<=6 && i<ArraySize(microRates); ++i)
        {
         const double impulse=microRates[i].close-microRates[i].open;
         if(sweepCandidate.direction==DIR_LONG)
           {
            if(impulse>0.0)
               favorableBursts++;
            else
               adverseBursts++;
           }
         else if(sweepCandidate.direction==DIR_SHORT)
           {
            if(impulse<0.0)
               favorableBursts++;
            else
               adverseBursts++;
           }
        }

      const double score=(double)(favorableBursts-adverseBursts)/6.0;
      return AFClamp(0.5+(0.5*score),0.0,1.0);
     }
  };

#endif
