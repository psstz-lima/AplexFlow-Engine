#ifndef APLEXFLOW_PORTFOLIO_CORRELATIONMANAGER_MQH
#define APLEXFLOW_PORTFOLIO_CORRELATIONMANAGER_MQH

#include "../core/Context.mqh"

class CorrelationManager
  {
private:
   int                SymbolIndex(const AFConfig &config,const string symbol) const
     {
      for(int i=0; i<config.symbolCount; ++i)
        {
         if(config.symbols[i]==symbol)
            return i;
        }
      return -1;
     }

public:
   void               Update(const AFConfig &config,AFPortfolioSnapshot &snapshot) const
     {
      for(int i=0; i<config.symbolCount; ++i)
        {
         MqlRates leftRates[];
         if(!AFCopyRates(config.symbols[i],config.decisionTf,config.correlationLookback+4,leftRates))
            continue;
         snapshot.correlationMatrix[i][i]=1.0;
         for(int j=i+1; j<config.symbolCount; ++j)
           {
            MqlRates rightRates[];
            if(!AFCopyRates(config.symbols[j],config.decisionTf,config.correlationLookback+4,rightRates))
               continue;
            const double corr=AFReturnsCorrelation(leftRates,rightRates,config.correlationLookback);
            snapshot.correlationMatrix[i][j]=corr;
            snapshot.correlationMatrix[j][i]=corr;
           }
        }
     }

   double             Penalty(const AFConfig &config,const AFPortfolioSnapshot &snapshot,const AFSignalCandidate &candidate,const AFPositionPlan &plans[],const int planCount) const
     {
      const int candidateIndex=SymbolIndex(config,candidate.rationale=="" ? "" : "");
      double penalty=0.0;
      for(int i=0; i<planCount; ++i)
        {
         if(!plans[i].active)
            continue;
         const int openIndex=SymbolIndex(config,plans[i].symbol);
         const int localCandidateIndex=SymbolIndex(config,plans[i].symbol);
         const int desiredIndex=(candidateIndex>=0 ? candidateIndex : SymbolIndex(config,plans[i].symbol));
         const int useIndex=(desiredIndex>=0 ? desiredIndex : localCandidateIndex);
         if(useIndex<0 || openIndex<0)
            continue;
         const double corr=MathAbs(snapshot.correlationMatrix[useIndex][openIndex]);
         if(plans[i].direction==candidate.direction)
            penalty=MathMax(penalty,corr);
         else
            penalty=MathMax(penalty,corr*0.4);
        }
      return AFClamp(penalty,0.0,1.0);
     }

   double             PenaltyForSymbol(const AFConfig &config,const AFPortfolioSnapshot &snapshot,const string symbol,const AFDirection direction,const AFPositionPlan &plans[],const int planCount) const
     {
      const int symbolIndex=SymbolIndex(config,symbol);
      if(symbolIndex<0)
         return 0.0;
      double penalty=0.0;
      for(int i=0; i<planCount; ++i)
        {
         if(!plans[i].active)
            continue;
         const int openIndex=SymbolIndex(config,plans[i].symbol);
         if(openIndex<0)
            continue;
         const double corr=MathAbs(snapshot.correlationMatrix[symbolIndex][openIndex]);
        penalty=MathMax(penalty,(plans[i].direction==direction ? corr : corr*0.35));
        }
      return AFClamp(penalty,0.0,1.0);
     }

   int                HighlyCorrelatedCount(const AFConfig &config,const AFPortfolioSnapshot &snapshot,const string symbol,const AFDirection direction,const AFPositionPlan &plans[],const int planCount,const double threshold) const
     {
      const int symbolIndex=SymbolIndex(config,symbol);
      if(symbolIndex<0 || threshold<=0.0)
         return 0;

      int count=0;
      for(int i=0; i<planCount; ++i)
        {
         if(!plans[i].active || plans[i].direction!=direction)
            continue;
         const int openIndex=SymbolIndex(config,plans[i].symbol);
         if(openIndex<0)
            continue;
         if(MathAbs(snapshot.correlationMatrix[symbolIndex][openIndex])>=threshold)
            ++count;
        }
      return count;
     }
  };

#endif
