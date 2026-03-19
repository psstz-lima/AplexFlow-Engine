#ifndef APLEXFLOW_CORE_SYMBOLALPHAPROFILEENGINE_MQH
#define APLEXFLOW_CORE_SYMBOLALPHAPROFILEENGINE_MQH

#include "Context.mqh"

class SymbolAlphaProfileEngine
  {
private:
   bool              IsFxMajor(const string symbol) const
     {
      return (symbol=="EURUSD" || symbol=="GBPUSD" || symbol=="USDJPY" || symbol=="AUDUSD" || symbol=="USDCAD");
     }

public:
   void              Adapt(const AFConfig &baseConfig,const string symbol,AFConfig &symbolConfig,double &riskBias) const
     {
      symbolConfig=baseConfig;
      riskBias=1.0;
      const string canonical=AFCanonicalSymbol(symbol);
      const bool xauDedicated=(AFDedicatedXauEnabled(baseConfig) && AFIsXauSymbol(canonical));
      const bool us500Dedicated=(AFDedicatedUs500Enabled(baseConfig) && AFIsUs500Symbol(canonical));
      if(!baseConfig.enableSymbolAlphaProfiles && !xauDedicated && !us500Dedicated)
         return;

      if(AFIsXauSymbol(canonical))
        {
         const double edgeDiscount=(xauDedicated ? 0.03 : 0.01);
         symbolConfig.edgeThreshold=MathMax(0.60,baseConfig.edgeThreshold-edgeDiscount);
         symbolConfig.breakoutBufferAtr=baseConfig.breakoutBufferAtr*(xauDedicated ? 0.86 : 0.90);
         symbolConfig.momentumCloseStrengthMin=MathMax(0.53,baseConfig.momentumCloseStrengthMin-(xauDedicated ? 0.03 : 0.02));
         symbolConfig.momentumMicroImpulseMin=MathMax(0.22,baseConfig.momentumMicroImpulseMin-(xauDedicated ? 0.05 : 0.03));
         symbolConfig.maxSpreadAtrFrac=MathMax(baseConfig.maxSpreadAtrFrac,(xauDedicated ? 0.24 : 0.20));
         symbolConfig.spreadEmergencyPoints=MathMax(baseConfig.spreadEmergencyPoints,(xauDedicated ? 90.0 : 80.0));
         symbolConfig.maxPerSymbolRiskPct=baseConfig.maxPerSymbolRiskPct*(xauDedicated ? 1.14 : 1.10);
         symbolConfig.maxTradesPerDayPerSymbol=MathMax(baseConfig.maxTradesPerDayPerSymbol,(xauDedicated ? 5 : 4));
         symbolConfig.maxClusterEntries=MathMax(baseConfig.maxClusterEntries,3);
         symbolConfig.trailStartR=MathMin(baseConfig.trailStartR,(xauDedicated ? 1.58 : 1.65));
         riskBias=(xauDedicated ? 1.07 : 1.05);
         return;
        }

      if(AFIsUs500Symbol(canonical))
        {
         const double edgeDiscount=(us500Dedicated ? 0.03 : 0.01);
         symbolConfig.edgeThreshold=MathMax(0.60,baseConfig.edgeThreshold-edgeDiscount);
         symbolConfig.breakoutBufferAtr=baseConfig.breakoutBufferAtr*(us500Dedicated ? 0.84 : 0.90);
         symbolConfig.momentumCloseStrengthMin=MathMax(0.52,baseConfig.momentumCloseStrengthMin-(us500Dedicated ? 0.04 : 0.02));
         symbolConfig.momentumMicroImpulseMin=MathMax(0.20,baseConfig.momentumMicroImpulseMin-(us500Dedicated ? 0.06 : 0.03));
         symbolConfig.maxSpreadAtrFrac=MathMax(baseConfig.maxSpreadAtrFrac,(us500Dedicated ? 0.85 : 0.60));
         symbolConfig.spreadEmergencyPoints=MathMax(baseConfig.spreadEmergencyPoints,(us500Dedicated ? 360.0 : 250.0));
         symbolConfig.maxPerSymbolRiskPct=baseConfig.maxPerSymbolRiskPct*(us500Dedicated ? 1.14 : 1.08);
         symbolConfig.maxTradesPerDayPerSymbol=MathMax(baseConfig.maxTradesPerDayPerSymbol,4);
         symbolConfig.maxClusterEntries=MathMax(baseConfig.maxClusterEntries,3);
         symbolConfig.trailStartR=MathMin(baseConfig.trailStartR,(us500Dedicated ? 1.58 : 1.65));
         riskBias=(us500Dedicated ? 1.06 : 1.04);
         return;
        }
     }

   double            StrategyEdgeBias(const AFConfig &config,const string symbol,const AFStrategyId strategy) const
     {
      if(!config.enableSymbolAlphaProfiles)
         return 0.0;

      const string canonical=AFCanonicalSymbol(symbol);
      if(AFIsXauSymbol(canonical))
        {
         if(strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
            return 0.03;
         if(strategy==STRATEGY_VOLATILITY_BREAKOUT || strategy==STRATEGY_MOMENTUM_CONTINUATION || strategy==STRATEGY_XAU_SESSION_BREAKOUT)
            return 0.02;
         if(strategy==STRATEGY_LIQUIDITY_SWEEP)
            return 0.01;
         return -0.02;
        }

      if(AFIsUs500Symbol(canonical))
        {
         if(strategy==STRATEGY_US500_IMPULSE_PULLBACK)
            return 0.03;
         if(strategy==STRATEGY_VOLATILITY_BREAKOUT || strategy==STRATEGY_MOMENTUM_CONTINUATION || strategy==STRATEGY_US500_OPEN_DRIVE)
            return 0.02;
         if(strategy==STRATEGY_LIQUIDITY_SWEEP)
            return 0.01;
         return -0.02;
        }
      return 0.0;
     }

   double            DedicatedStrategyBias(const string symbol,const AFSignalCandidate &candidate) const
     {
      const string canonical=AFCanonicalSymbol(symbol);
      if(AFIsXauSymbol(canonical))
        {
         if(candidate.strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM)
            return 0.06+(0.03*candidate.alphaStrength);
         if(candidate.strategy==STRATEGY_XAU_SESSION_BREAKOUT)
            return 0.04+(0.02*candidate.alphaStrength);
         if(candidate.strategy==STRATEGY_LIQUIDITY_SWEEP)
            return -0.05;
         return 0.0;
        }

      if(AFIsUs500Symbol(canonical))
        {
         if(candidate.strategy==STRATEGY_US500_IMPULSE_PULLBACK)
            return 0.06+(0.03*candidate.alphaStrength);
         if(candidate.strategy==STRATEGY_US500_OPEN_DRIVE)
            return 0.05+(0.02*candidate.alphaStrength);
         if(candidate.strategy==STRATEGY_LIQUIDITY_SWEEP)
            return -0.06;
         if(candidate.strategy==STRATEGY_MOMENTUM_CONTINUATION && !candidate.dedicatedAlpha)
            return -0.04;
         return 0.0;
        }
      return 0.0;
     }
  };

#endif
