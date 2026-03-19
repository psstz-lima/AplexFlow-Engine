#ifndef APLEXFLOW_MODELS_ONLINELEARNINGMODEL_MQH
#define APLEXFLOW_MODELS_ONLINELEARNINGMODEL_MQH

#include "../core/Context.mqh"

class OnlineLearningModel
  {
private:
   double             m_weights[AF_FEATURE_COUNT];
   double             m_featureMemory[AF_MAX_OUTCOME_MEMORY][AF_FEATURE_COUNT];
   int                m_labels[AF_MAX_OUTCOME_MEMORY];
   int                m_cursor;
   int                m_count;
   int                m_memoryLimit;
   double             m_learningRate;

   void               NormalizeWeights(void)
     {
      double total=0.0;
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         total+=MathAbs(m_weights[i]);
      if(total<=0.0)
         total=1.0;
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         m_weights[i]=AFClamp(m_weights[i]/total,0.02,0.45);
     }

public:
                     OnlineLearningModel(void)
     {
      m_cursor=0;
      m_count=0;
      m_memoryLimit=100;
      m_learningRate=0.08;
     }

   void              Initialize(const AFConfig &config)
     {
      const double defaults[AF_FEATURE_COUNT]={0.20,0.16,0.15,0.14,0.13,0.10,0.12};
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         m_weights[i]=defaults[i];
      m_cursor=0;
      m_count=0;
      m_memoryLimit=MathMax(32,MathMin(AF_MAX_OUTCOME_MEMORY,config.learningMemory));
      m_learningRate=config.learningRate;
     }

   void              Snapshot(double &weights[]) const
     {
      ArrayResize(weights,AF_FEATURE_COUNT);
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         weights[i]=m_weights[i];
     }

   void              ApplyOutcome(const AFTradeOutcome &outcome)
     {
      if(!outcome.valid)
         return;

      for(int i=0; i<AF_FEATURE_COUNT; ++i)
         m_featureMemory[m_cursor][i]=outcome.features[i];
      m_labels[m_cursor]=outcome.label;

      const double signedTarget=(double)outcome.label;
      for(int i=0; i<AF_FEATURE_COUNT; ++i)
        {
         const double centered=outcome.features[i]-0.5;
         m_weights[i]+=m_learningRate*signedTarget*centered;
        }
      NormalizeWeights();

      m_cursor=(m_cursor+1)%m_memoryLimit;
      m_count=MathMin(m_count+1,m_memoryLimit);
     }
  };

#endif
