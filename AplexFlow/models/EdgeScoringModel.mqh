#ifndef APLEXFLOW_MODELS_EDGESCORINGMODEL_MQH
#define APLEXFLOW_MODELS_EDGESCORINGMODEL_MQH

#include "../core/Context.mqh"

class EdgeScoringModel
  {
public:
   double             Score(const double &weights[],AFSignalCandidate &candidate) const
     {
      double weighted=0.0;
      double absWeight=0.0;
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
        {
         weighted+=(candidate.features[i]*weights[i]);
         absWeight+=MathAbs(weights[i]);
        }
      const double normalized=(absWeight>0.0 ? weighted/absWeight : 0.0);
      const double dedicatedBoost=(candidate.dedicatedAlpha ? 0.08*candidate.alphaStrength : 0.0);
      candidate.edgeScore=AFClamp(AFSigmoid((normalized-0.5)*5.0)+dedicatedBoost,0.0,1.0);
      candidate.confidence=AFClamp(candidate.edgeScore+(candidate.dedicatedAlpha ? 0.03*candidate.alphaStrength : 0.0),0.0,1.0);
      return candidate.edgeScore;
     }
  };

#endif
