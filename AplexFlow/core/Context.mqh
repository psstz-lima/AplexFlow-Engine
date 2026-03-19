#ifndef APLEXFLOW_CORE_CONTEXT_MQH
#define APLEXFLOW_CORE_CONTEXT_MQH

#property strict

#include <Trade/Trade.mqh>

#define AF_MAX_SYMBOLS 12
#define AF_MAX_STRATEGIES 8
#define AF_MAX_ACTIVE_PLANS 64
#define AF_MAX_LIQUIDITY_LEVELS 16
#define AF_MAX_OUTCOME_MEMORY 300
#define AF_FEATURE_COUNT 7
#define AF_MAX_CANDIDATES 8

enum AFMarketRegime
  {
   STRONG_TREND=0,
   WEAK_TREND=1,
   RANGE=2,
   VOLATILITY_EXPANSION=3,
   DEFENSIVE=4
  };

enum AFStrategyId
  {
   STRATEGY_VOLATILITY_BREAKOUT=0,
   STRATEGY_MOMENTUM_CONTINUATION=1,
   STRATEGY_MEAN_REVERSION=2,
   STRATEGY_LIQUIDITY_SWEEP=3,
   STRATEGY_XAU_SESSION_BREAKOUT=4,
   STRATEGY_US500_OPEN_DRIVE=5,
   STRATEGY_XAU_LIQUIDITY_RECLAIM=6,
   STRATEGY_US500_IMPULSE_PULLBACK=7
  };

enum AFDirection
  {
   DIR_FLAT=0,
   DIR_LONG=1,
   DIR_SHORT=-1
  };

enum AFExecutionMethod
  {
   EXEC_MARKET=0,
   EXEC_LIMIT=1,
   EXEC_HYBRID=2
  };

enum AFSessionTag
  {
   SESSION_ASIA=0,
   SESSION_LONDON=1,
   SESSION_NEWYORK=2,
   SESSION_OVERLAP=3,
   SESSION_OFF=4
  };

input group "Framework"
input string InpSymbols = "EURUSD,GBPUSD,USDJPY,AUDUSD,USDCAD,XAUUSD,US500";
input ulong InpMagicNumber = 55150315;
input ENUM_TIMEFRAMES InpDecisionTimeframe = PERIOD_M5;
input ENUM_TIMEFRAMES InpMicrostructureTimeframe = PERIOD_M1;
input int InpLookbackBars = 320;
input bool InpEnableTelemetry = true;
input bool InpEnableEvolutionExport = true;
input bool InpEnableSymbolAlphaProfiles = false;
input bool InpEnableDedicatedSymbolAlphas = false;
input bool InpEnableDedicatedXauAlpha = true;
input bool InpEnableDedicatedUs500Alpha = true;
input bool InpEnableDedicatedXauReclaimAlpha = true;
input bool InpEnableDedicatedUs500ImpulsePullbackAlpha = false;

input group "Market Regime"
input int InpAtrPeriod = 14;
input int InpTrendSlopeLength = 24;
input int InpCompressionLookback = 36;
input int InpBreakoutLookback = 20;
input double InpTrendSlopeThreshold = 0.18;
input double InpWeakTrendSlopeThreshold = 0.08;
input double InpCompressionThreshold = 0.72;
input double InpVolExpansionThreshold = 1.20;

input group "Liquidity Intelligence"
input int InpLiquiditySwingWindow = 24;
input int InpPreviousDayBars = 288;
input double InpEqualLevelToleranceAtr = 0.20;
input int InpOrderBlockLookback = 12;
input int InpSweepLookback = 18;
input double InpSweepRejectCloseMin = 0.55;

input group "Opportunity Detection"
input double InpBreakoutBufferAtr = 0.12;
input double InpMomentumCloseStrengthMin = 0.58;
input double InpMomentumMicroImpulseMin = 0.35;
input double InpMeanReversionZScore = 1.80;
input double InpMeanReversionExitZScore = 0.35;
input bool InpEnableBreakout = true;
input bool InpEnableMomentum = true;
input bool InpEnableMeanReversion = false;
input bool InpEnableSweep = true;

input group "Edge Scoring"
input double InpEdgeThreshold = 0.69;
input double InpHardBlockThreshold = 0.55;
input double InpLearningRate = 0.08;
input int InpLearningMemory = 200;

input group "Risk"
input double InpMaxEquityDrawdownPct = 10.0;
input double InpMaxDailyLossPct = 2.0;
input double InpWeeklyProfitLockPct = 5.0;
input double InpWeeklyProfitGivebackPct = 35.0;
input double InpMaxPortfolioRiskPct = 3.5;
input double InpMaxPerSymbolRiskPct = 1.56;
input int InpMaxPositions = 4;
input int InpMaxTradesPerDayPerSymbol = 3;
input int InpMaxClusterEntries = 2;
input bool InpEnableCorrelationHardBlock = true;
input double InpCorrelationHardBlock = 0.80;
input int InpMaxCorrelatedPositions = 1;
input double InpStopAtrFloor = 0.90;
input double InpStopAtrCeiling = 2.40;

input group "Execution"
input double InpMaxSpreadAtrFrac = 0.12;
input double InpSpreadEmergencyPoints = 45.0;
input int InpMaxSlippagePoints = 25;
input bool InpAllowPendingFallback = true;
input int InpPendingExpiryBars = 3;
input int InpBacktestLatencyMs = 200;

input group "Session Intelligence"
input bool InpTradeLondon = true;
input bool InpTradeNewYork = true;
input bool InpReduceAsiaRisk = true;
input int InpLondonOpenUtc = 7;
input int InpLondonCloseUtc = 16;
input int InpNewYorkOpenUtc = 12;
input int InpNewYorkCloseUtc = 21;

input group "Profit Engine"
input double InpTp1R = 1.0;
input double InpTp2R = 2.0;
input double InpTp3R = 4.2;
input double InpBreakEvenAtR = 0.75;
input double InpTrailStartR = 1.70;
input double InpTrailAtrMult = 1.10;
input double InpTrailStepAtr = 0.10;
input int InpMinStopUpdateSeconds = 15;
input int InpEarlyLossBars = 4;
input double InpEarlyLossProgressR = 0.15;

input group "Research"
input int InpCorrelationLookback = 96;
input int InpDegradationWindow = 18;
input double InpMinExpectancyR = -0.03;
input int InpSymbolDegradationWindow = 6;
input double InpMinSymbolExpectancyR = -0.05;
input double InpSymbolMinProfitFactor = 0.80;
input int InpSymbolCooldownMinutes = 360;
input bool InpEnableDrawdownDefense = false;
input double InpDefenseActivationDrawdownPct = 4.0;
input int InpDefenseMinSymbolTrades = 6;
input double InpDefenseMinSymbolExpectancyR = -0.02;
input double InpDefenseMinSymbolProfitFactor = 0.95;
input string InpPresetOutputName = "AplexFlow_Engine.evolved.set";

struct AFLiquidityLevel
  {
   double price;
   double strength;
   int side;
   string tag;
  };

struct AFLiquidityMap
  {
   int count;
   AFLiquidityLevel levels[AF_MAX_LIQUIDITY_LEVELS];
   double nearestAbove;
   double nearestBelow;
   double prevDayHigh;
   double prevDayLow;
   double sessionHigh;
   double sessionLow;
   double orderBlockHigh;
   double orderBlockLow;
   double heatScore;
   bool hasEqualHigh;
   bool hasEqualLow;
  };

struct AFVolatilityForecast
  {
   double atrFast;
   double atrSlow;
   double atrAcceleration;
   double compression;
   double breakoutProbability;
   bool impulseCandle;
  };

struct AFMicrostructureState
  {
   bool stable;
   bool spreadOk;
   bool liquidityOk;
   bool erraticTicks;
   double spreadPoints;
   double spreadAtrFrac;
   double wickNoise;
  };

struct AFSessionState
  {
   AFSessionTag tag;
   double activityScore;
   bool allowAggressive;
  };

struct AFSignalCandidate
  {
   bool valid;
   AFStrategyId strategy;
   AFDirection direction;
   AFExecutionMethod executionMethod;
   double entry;
   double stop;
   double target1;
   double target2;
   double target3;
   double confidence;
   double edgeScore;
   double riskMultiplier;
   bool dedicatedAlpha;
   double alphaStrength;
   int clusterId;
   double features[AF_FEATURE_COUNT];
   string rationale;
  };

struct AFTradeOutcome
  {
   bool valid;
   ulong positionId;
   string symbol;
   AFStrategyId strategy;
   AFMarketRegime regime;
   double profit;
   double profitR;
   int label;
   double features[AF_FEATURE_COUNT];
   datetime closeTime;
  };

struct AFPositionPlan
  {
   bool active;
   ulong positionId;
   ulong orderTicket;
   string symbol;
   AFStrategyId strategy;
   AFMarketRegime regime;
   AFDirection direction;
   double entry;
   double initialStop;
   double target1;
   double target2;
   double target3;
   double riskRPoints;
   double volumeInitial;
   double volumeRemaining;
   bool tp1Done;
   bool tp2Done;
   bool movedBreakEven;
   double lastManagedStop;
   datetime lastStopUpdateTime;
   int clusterId;
   double confidence;
   double features[AF_FEATURE_COUNT];
   datetime openTime;
   string comment;
  };

struct AFStrategyStats
  {
   int trades;
   int wins;
   int losses;
   double grossProfit;
   double grossLoss;
   double expectancyR;
   double rollingScore;
   datetime cooldownUntil;
  };

struct AFSymbolPerformance
  {
   int trades;
   int wins;
   int losses;
   double grossProfit;
   double grossLoss;
   double expectancyR;
   datetime blockedUntil;
  };

struct AFSymbolState
  {
   string symbol;
   bool enabled;
   datetime lastDecisionBar;
   AFMarketRegime regime;
   double lastAtr;
   double lastScore;
   int clusterEntries[AF_MAX_STRATEGIES];
   int clusterIds[AF_MAX_STRATEGIES];
   datetime strategyBlockedUntil[AF_MAX_STRATEGIES];
   AFSymbolPerformance performance;
   int tradesToday;
   int lossesToday;
  };

struct AFPortfolioSnapshot
  {
   double equity;
   double balance;
   double freeMargin;
   double peakEquity;
   double peakWeekEquity;
   double drawdownPct;
   double dailyPnlPct;
   double weeklyPnlPct;
   double totalOpenRiskPct;
   double correlationMatrix[AF_MAX_SYMBOLS][AF_MAX_SYMBOLS];
   bool blockNewRisk;
   string blockReason;
  };

struct AFConfig
  {
   string symbols[AF_MAX_SYMBOLS];
   int symbolCount;
   ulong magicNumber;
   ENUM_TIMEFRAMES decisionTf;
   ENUM_TIMEFRAMES microTf;
   int lookbackBars;
   bool enableSymbolAlphaProfiles;
   bool enableDedicatedSymbolAlphas;
   bool enableDedicatedXauAlpha;
   bool enableDedicatedUs500Alpha;
   bool enableDedicatedXauReclaimAlpha;
   bool enableDedicatedUs500ImpulsePullbackAlpha;
   int atrPeriod;
   int trendSlopeLength;
   int compressionLookback;
   int breakoutLookback;
   double trendSlopeThreshold;
   double weakTrendSlopeThreshold;
   double compressionThreshold;
   double volExpansionThreshold;
   int liquiditySwingWindow;
   int previousDayBars;
   double equalLevelToleranceAtr;
   int orderBlockLookback;
   int sweepLookback;
   double sweepRejectCloseMin;
   double breakoutBufferAtr;
   double momentumCloseStrengthMin;
   double momentumMicroImpulseMin;
   double meanReversionZScore;
   double meanReversionExitZScore;
   bool enableBreakout;
   bool enableMomentum;
   bool enableMeanReversion;
   bool enableSweep;
   double edgeThreshold;
   double hardBlockThreshold;
   double learningRate;
   int learningMemory;
   double maxEquityDrawdownPct;
   double maxDailyLossPct;
   double weeklyProfitLockPct;
   double weeklyProfitGivebackPct;
   double maxPortfolioRiskPct;
   double maxPerSymbolRiskPct;
   int maxPositions;
   int maxTradesPerDayPerSymbol;
   int maxClusterEntries;
   bool enableCorrelationHardBlock;
   double correlationHardBlock;
   int maxCorrelatedPositions;
   double stopAtrFloor;
   double stopAtrCeiling;
   double maxSpreadAtrFrac;
   double spreadEmergencyPoints;
   int maxSlippagePoints;
   bool allowPendingFallback;
   int pendingExpiryBars;
   int backtestLatencyMs;
   bool tradeLondon;
   bool tradeNewYork;
   bool reduceAsiaRisk;
   int londonOpenUtc;
   int londonCloseUtc;
   int newYorkOpenUtc;
   int newYorkCloseUtc;
   double tp1R;
   double tp2R;
   double tp3R;
   double breakEvenAtR;
   double trailStartR;
   double trailAtrMult;
   double trailStepAtr;
   int minStopUpdateSeconds;
   int earlyLossBars;
   double earlyLossProgressR;
   int correlationLookback;
   int degradationWindow;
   double minExpectancyR;
   int symbolDegradationWindow;
   double minSymbolExpectancyR;
   double symbolMinProfitFactor;
   int symbolCooldownMinutes;
   bool enableDrawdownDefense;
   double defenseActivationDrawdownPct;
   int defenseMinSymbolTrades;
   double defenseMinSymbolExpectancyR;
   double defenseMinSymbolProfitFactor;
   bool enableTelemetry;
   bool enableEvolutionExport;
   string presetOutputName;
  };

inline void AFResetFeatures(double &features[])
  {
   ArrayResize(features, AF_FEATURE_COUNT);
   for(int i=0; i<AF_FEATURE_COUNT; ++i)
      features[i]=0.0;
  }

inline double AFClamp(const double value,const double minValue,const double maxValue)
  {
   return MathMax(minValue,MathMin(maxValue,value));
  }

inline double AFSigmoid(const double x)
  {
   if(x>35.0)
      return 1.0;
   if(x<-35.0)
      return 0.0;
   return 1.0/(1.0+MathExp(-x));
  }

inline int AFDirectionSign(const AFDirection direction)
  {
   if(direction==DIR_LONG)
      return 1;
   if(direction==DIR_SHORT)
      return -1;
   return 0;
  }

inline AFDirection AFOppositeDirection(const AFDirection direction)
  {
   if(direction==DIR_LONG)
      return DIR_SHORT;
   if(direction==DIR_SHORT)
      return DIR_LONG;
   return DIR_FLAT;
  }

inline string AFTrim(const string value)
  {
   string trimmed=value;
   StringTrimLeft(trimmed);
   StringTrimRight(trimmed);
   return trimmed;
  }

inline string AFUpper(const string value)
  {
   string upper=value;
   StringToUpper(upper);
   return upper;
  }

inline string AFCanonicalSymbol(const string symbol)
  {
   string canonical=AFUpper(symbol);
   const int csvPos=StringFind(canonical,"_CSV");
   if(csvPos>=0)
      canonical=StringSubstr(canonical,0,csvPos);
   return canonical;
  }

inline bool AFIsXauSymbol(const string symbol)
  {
   return (StringFind(AFCanonicalSymbol(symbol),"XAUUSD")>=0);
  }

inline bool AFIsUs500Symbol(const string symbol)
  {
   const string canonical=AFCanonicalSymbol(symbol);
   return (StringFind(canonical,"US500")>=0 ||
           StringFind(canonical,"SPX")>=0 ||
           StringFind(canonical,"500CASH")>=0);
  }

inline bool AFDedicatedXauEnabled(const AFConfig &config)
  {
   return (config.enableDedicatedSymbolAlphas && config.enableDedicatedXauAlpha);
  }

inline bool AFDedicatedUs500Enabled(const AFConfig &config)
  {
   return (config.enableDedicatedSymbolAlphas && config.enableDedicatedUs500Alpha);
  }

inline bool AFDedicatedXauReclaimEnabled(const AFConfig &config)
  {
   return (AFDedicatedXauEnabled(config) && config.enableDedicatedXauReclaimAlpha);
  }

inline bool AFDedicatedUs500ImpulsePullbackEnabled(const AFConfig &config)
  {
   return (AFDedicatedUs500Enabled(config) && config.enableDedicatedUs500ImpulsePullbackAlpha);
  }

inline bool AFDedicatedAlphaEnabled(const AFConfig &config,const string symbol)
  {
   if(AFIsUs500Symbol(symbol))
      return AFDedicatedUs500Enabled(config);
   if(AFIsXauSymbol(symbol))
      return AFDedicatedXauEnabled(config);
   return false;
  }

inline bool AFIsDedicatedCarrierStrategy(const AFStrategyId strategy)
  {
   return (strategy==STRATEGY_XAU_SESSION_BREAKOUT ||
           strategy==STRATEGY_US500_OPEN_DRIVE ||
           strategy==STRATEGY_XAU_LIQUIDITY_RECLAIM ||
           strategy==STRATEGY_US500_IMPULSE_PULLBACK);
  }

inline bool AFCarrierReserveEligibleSymbol(const AFConfig &config,const string symbol)
  {
   if(AFIsUs500Symbol(symbol))
      return AFDedicatedUs500Enabled(config);
   if(AFIsXauSymbol(symbol))
      return AFDedicatedXauEnabled(config);
   return false;
  }

inline bool AFHasCarrierReserveUniverse(const AFConfig &config)
  {
   if(!config.enableDedicatedSymbolAlphas)
      return false;
   for(int i=0; i<config.symbolCount; ++i)
     {
      if(AFCarrierReserveEligibleSymbol(config,config.symbols[i]))
         return true;
     }
   return false;
  }

inline string AFMarketRegimeName(const AFMarketRegime regime)
  {
   switch(regime)
     {
      case STRONG_TREND: return "STRONG_TREND";
      case WEAK_TREND: return "WEAK_TREND";
      case RANGE: return "RANGE";
      case VOLATILITY_EXPANSION: return "VOLATILITY_EXPANSION";
      default: break;
     }
   return "DEFENSIVE";
  }

inline string AFStrategyCode(const AFStrategyId strategy)
  {
   switch(strategy)
     {
      case STRATEGY_VOLATILITY_BREAKOUT: return "VBO";
      case STRATEGY_MOMENTUM_CONTINUATION: return "MOM";
      case STRATEGY_MEAN_REVERSION: return "MRV";
      case STRATEGY_XAU_SESSION_BREAKOUT: return "XSB";
      case STRATEGY_US500_OPEN_DRIVE: return "UOD";
      case STRATEGY_XAU_LIQUIDITY_RECLAIM: return "XLR";
      case STRATEGY_US500_IMPULSE_PULLBACK: return "UIP";
      default: break;
     }
   return "SWP";
  }

inline string AFStrategyName(const AFStrategyId strategy)
  {
   switch(strategy)
     {
      case STRATEGY_VOLATILITY_BREAKOUT: return "VolatilityBreakout";
      case STRATEGY_MOMENTUM_CONTINUATION: return "MomentumContinuation";
      case STRATEGY_MEAN_REVERSION: return "MeanReversion";
      case STRATEGY_XAU_SESSION_BREAKOUT: return "XauSessionBreakout";
      case STRATEGY_US500_OPEN_DRIVE: return "Us500OpenDrive";
      case STRATEGY_XAU_LIQUIDITY_RECLAIM: return "XauLiquidityReclaim";
      case STRATEGY_US500_IMPULSE_PULLBACK: return "Us500ImpulsePullback";
      default: break;
     }
   return "LiquiditySweep";
  }

inline string AFExecutionMethodName(const AFExecutionMethod method)
  {
   switch(method)
     {
      case EXEC_MARKET: return "market";
      case EXEC_LIMIT: return "limit";
      default: break;
     }
   return "hybrid";
  }

inline string AFComment(const AFSignalCandidate &candidate)
  {
   string side=(candidate.direction==DIR_LONG ? "B" : "S");
   return StringFormat("AFX|%s|%s|%d",AFStrategyCode(candidate.strategy),side,candidate.clusterId);
  }

inline bool AFBuildConfig(AFConfig &config)
  {
   for(int i=0; i<AF_MAX_SYMBOLS; ++i)
      config.symbols[i]="";
   config.magicNumber=InpMagicNumber;
   config.decisionTf=InpDecisionTimeframe;
   config.microTf=InpMicrostructureTimeframe;
   config.lookbackBars=InpLookbackBars;
   config.enableSymbolAlphaProfiles=InpEnableSymbolAlphaProfiles;
   config.enableDedicatedSymbolAlphas=InpEnableDedicatedSymbolAlphas;
   config.enableDedicatedXauAlpha=InpEnableDedicatedXauAlpha;
   config.enableDedicatedUs500Alpha=InpEnableDedicatedUs500Alpha;
   config.enableDedicatedXauReclaimAlpha=InpEnableDedicatedXauReclaimAlpha;
   config.enableDedicatedUs500ImpulsePullbackAlpha=InpEnableDedicatedUs500ImpulsePullbackAlpha;
   config.atrPeriod=InpAtrPeriod;
   config.trendSlopeLength=InpTrendSlopeLength;
   config.compressionLookback=InpCompressionLookback;
   config.breakoutLookback=InpBreakoutLookback;
   config.trendSlopeThreshold=InpTrendSlopeThreshold;
   config.weakTrendSlopeThreshold=InpWeakTrendSlopeThreshold;
   config.compressionThreshold=InpCompressionThreshold;
   config.volExpansionThreshold=InpVolExpansionThreshold;
   config.liquiditySwingWindow=InpLiquiditySwingWindow;
   config.previousDayBars=InpPreviousDayBars;
   config.equalLevelToleranceAtr=InpEqualLevelToleranceAtr;
   config.orderBlockLookback=InpOrderBlockLookback;
   config.sweepLookback=InpSweepLookback;
   config.sweepRejectCloseMin=InpSweepRejectCloseMin;
   config.breakoutBufferAtr=InpBreakoutBufferAtr;
   config.momentumCloseStrengthMin=InpMomentumCloseStrengthMin;
   config.momentumMicroImpulseMin=InpMomentumMicroImpulseMin;
   config.meanReversionZScore=InpMeanReversionZScore;
   config.meanReversionExitZScore=InpMeanReversionExitZScore;
   config.enableBreakout=InpEnableBreakout;
   config.enableMomentum=InpEnableMomentum;
   config.enableMeanReversion=InpEnableMeanReversion;
   config.enableSweep=InpEnableSweep;
   config.edgeThreshold=InpEdgeThreshold;
   config.hardBlockThreshold=InpHardBlockThreshold;
   config.learningRate=InpLearningRate;
   config.learningMemory=MathMax(32,MathMin(AF_MAX_OUTCOME_MEMORY,InpLearningMemory));
   config.maxEquityDrawdownPct=InpMaxEquityDrawdownPct;
   config.maxDailyLossPct=InpMaxDailyLossPct;
   config.weeklyProfitLockPct=InpWeeklyProfitLockPct;
   config.weeklyProfitGivebackPct=InpWeeklyProfitGivebackPct;
   config.maxPortfolioRiskPct=InpMaxPortfolioRiskPct;
   config.maxPerSymbolRiskPct=InpMaxPerSymbolRiskPct;
   config.maxPositions=InpMaxPositions;
   config.maxTradesPerDayPerSymbol=InpMaxTradesPerDayPerSymbol;
   config.maxClusterEntries=InpMaxClusterEntries;
   config.enableCorrelationHardBlock=InpEnableCorrelationHardBlock;
   config.correlationHardBlock=InpCorrelationHardBlock;
   config.maxCorrelatedPositions=InpMaxCorrelatedPositions;
   config.stopAtrFloor=InpStopAtrFloor;
   config.stopAtrCeiling=InpStopAtrCeiling;
   config.maxSpreadAtrFrac=InpMaxSpreadAtrFrac;
   config.spreadEmergencyPoints=InpSpreadEmergencyPoints;
   config.maxSlippagePoints=InpMaxSlippagePoints;
   config.allowPendingFallback=InpAllowPendingFallback;
   config.pendingExpiryBars=InpPendingExpiryBars;
   config.backtestLatencyMs=InpBacktestLatencyMs;
   config.tradeLondon=InpTradeLondon;
   config.tradeNewYork=InpTradeNewYork;
   config.reduceAsiaRisk=InpReduceAsiaRisk;
   config.londonOpenUtc=InpLondonOpenUtc;
   config.londonCloseUtc=InpLondonCloseUtc;
   config.newYorkOpenUtc=InpNewYorkOpenUtc;
   config.newYorkCloseUtc=InpNewYorkCloseUtc;
   config.tp1R=InpTp1R;
   config.tp2R=InpTp2R;
   config.tp3R=InpTp3R;
   config.breakEvenAtR=InpBreakEvenAtR;
   config.trailStartR=InpTrailStartR;
   config.trailAtrMult=InpTrailAtrMult;
    config.trailStepAtr=InpTrailStepAtr;
    config.minStopUpdateSeconds=InpMinStopUpdateSeconds;
   config.earlyLossBars=InpEarlyLossBars;
   config.earlyLossProgressR=InpEarlyLossProgressR;
   config.correlationLookback=InpCorrelationLookback;
   config.degradationWindow=InpDegradationWindow;
   config.minExpectancyR=InpMinExpectancyR;
   config.symbolDegradationWindow=InpSymbolDegradationWindow;
   config.minSymbolExpectancyR=InpMinSymbolExpectancyR;
   config.symbolMinProfitFactor=InpSymbolMinProfitFactor;
   config.symbolCooldownMinutes=InpSymbolCooldownMinutes;
   config.enableDrawdownDefense=InpEnableDrawdownDefense;
   config.defenseActivationDrawdownPct=InpDefenseActivationDrawdownPct;
   config.defenseMinSymbolTrades=InpDefenseMinSymbolTrades;
   config.defenseMinSymbolExpectancyR=InpDefenseMinSymbolExpectancyR;
   config.defenseMinSymbolProfitFactor=InpDefenseMinSymbolProfitFactor;
   config.enableTelemetry=InpEnableTelemetry;
   config.enableEvolutionExport=InpEnableEvolutionExport;
   config.presetOutputName=InpPresetOutputName;

   string rawSymbols[];
   const int count=StringSplit(InpSymbols,',',rawSymbols);
   config.symbolCount=0;
   for(int i=0; i<count && config.symbolCount<AF_MAX_SYMBOLS; ++i)
     {
      string symbol=AFUpper(AFTrim(rawSymbols[i]));
      if(symbol=="")
         continue;
      config.symbols[config.symbolCount]=symbol;
      ++config.symbolCount;
     }
   return (config.symbolCount>0);
  }

inline bool AFCopyRates(const string symbol,const ENUM_TIMEFRAMES timeframe,const int count,MqlRates &rates[])
  {
   ArraySetAsSeries(rates,true);
   const int copied=CopyRates(symbol,timeframe,0,count,rates);
   return (copied>=MathMin(count,8));
  }

inline double AFBarRange(const MqlRates &bar)
  {
   return bar.high-bar.low;
  }

inline double AFTrueRange(const MqlRates &current,const MqlRates &previous)
  {
   const double a=current.high-current.low;
   const double b=MathAbs(current.high-previous.close);
   const double c=MathAbs(current.low-previous.close);
   return MathMax(a,MathMax(b,c));
  }

inline double AFComputeATR(const MqlRates &rates[],const int period,const int startShift=1)
  {
   const int available=ArraySize(rates);
   if(available<=period+startShift)
      return 0.0;
   double sum=0.0;
   int used=0;
   for(int i=startShift; i<startShift+period && (i+1)<available; ++i)
     {
      sum+=AFTrueRange(rates[i],rates[i+1]);
      ++used;
     }
   if(used==0)
      return 0.0;
   return sum/(double)used;
  }

inline double AFComputeMeanClose(const MqlRates &rates[],const int startShift,const int length)
  {
   const int available=ArraySize(rates);
   if(available<=startShift+length-1 || length<=0)
      return 0.0;
   double sum=0.0;
   for(int i=startShift; i<startShift+length; ++i)
      sum+=rates[i].close;
   return sum/(double)length;
  }

inline double AFComputeStdClose(const MqlRates &rates[],const int startShift,const int length)
  {
   if(length<=1)
      return 0.0;
   const double mean=AFComputeMeanClose(rates,startShift,length);
   double sum=0.0;
   for(int i=startShift; i<startShift+length; ++i)
     {
      const double diff=rates[i].close-mean;
      sum+=diff*diff;
     }
   return MathSqrt(sum/(double)(length-1));
  }

inline double AFComputeZScoreClose(const MqlRates &rates[],const int length,const int shift=1)
  {
   const double mean=AFComputeMeanClose(rates,shift,length);
   const double stdDev=AFComputeStdClose(rates,shift,length);
   if(stdDev<=0.0 || ArraySize(rates)<=shift)
      return 0.0;
   return (rates[shift].close-mean)/stdDev;
  }

inline double AFComputeSlope(const MqlRates &rates[],const int length,const int shift=1)
  {
   if(length<2 || ArraySize(rates)<=shift+length)
      return 0.0;
   double sumX=0.0;
   double sumY=0.0;
   double sumXY=0.0;
   double sumXX=0.0;
   for(int i=0; i<length; ++i)
     {
      const double x=(double)i;
      const double y=rates[shift+length-1-i].close;
      sumX+=x;
      sumY+=y;
      sumXY+=(x*y);
      sumXX+=(x*x);
     }
   const double denominator=(length*sumXX)-(sumX*sumX);
   if(MathAbs(denominator)<1e-10)
      return 0.0;
   return ((length*sumXY)-(sumX*sumY))/denominator;
  }

inline double AFHighestHigh(const MqlRates &rates[],const int length,const int shift=1)
  {
   double value=-DBL_MAX;
   for(int i=shift; i<shift+length && i<ArraySize(rates); ++i)
      value=MathMax(value,rates[i].high);
   return (value==-DBL_MAX ? 0.0 : value);
  }

inline double AFLowestLow(const MqlRates &rates[],const int length,const int shift=1)
  {
   double value=DBL_MAX;
   for(int i=shift; i<shift+length && i<ArraySize(rates); ++i)
      value=MathMin(value,rates[i].low);
   return (value==DBL_MAX ? 0.0 : value);
  }

inline double AFCloseStrength(const MqlRates &bar)
  {
   const double range=AFBarRange(bar);
   if(range<=0.0)
      return 0.5;
   return AFClamp((bar.close-bar.low)/range,0.0,1.0);
  }

inline double AFWickNoise(const MqlRates &bar)
  {
   const double range=AFBarRange(bar);
   if(range<=0.0)
      return 0.0;
   const double body=MathAbs(bar.close-bar.open);
   return AFClamp((range-body)/range,0.0,1.0);
  }

inline bool AFGetBidAsk(const string symbol,double &bid,double &ask)
  {
   bid=SymbolInfoDouble(symbol,SYMBOL_BID);
   ask=SymbolInfoDouble(symbol,SYMBOL_ASK);
   if(bid>0.0 && ask>0.0 && ask>=bid)
      return true;

   if(MQLInfoInteger(MQL_TESTER)==0 && MQLInfoInteger(MQL_OPTIMIZATION)==0)
      return false;

   if(StringFind(AFUpper(symbol),"_CSV")<0)
      return false;

   const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point<=0.0)
      return false;

   double syntheticSpreadPoints=(double)SymbolInfoInteger(symbol,SYMBOL_SPREAD);
   if(syntheticSpreadPoints<=0.0)
     {
      if(AFIsUs500Symbol(symbol))
         syntheticSpreadPoints=40.0;
      else if(AFIsXauSymbol(symbol))
         syntheticSpreadPoints=28.0;
      else
         syntheticSpreadPoints=12.0;
     }

   MqlRates fallbackRates[];
   ArraySetAsSeries(fallbackRates,true);
   int copied=CopyRates(symbol,PERIOD_M1,0,2,fallbackRates);
   if(copied<1)
      copied=CopyRates(symbol,PERIOD_M5,0,2,fallbackRates);
   if(copied<1 || ArraySize(fallbackRates)<1)
      return false;

   const double midPrice=(fallbackRates[0].close>0.0 ? fallbackRates[0].close : fallbackRates[0].open);
   if(midPrice<=0.0)
      return false;

   const double halfSpread=0.5*syntheticSpreadPoints*point;
   bid=AFNormalizePrice(symbol,midPrice-halfSpread);
   ask=AFNormalizePrice(symbol,midPrice+halfSpread);
   return (bid>0.0 && ask>0.0 && ask>=bid);
  }

inline double AFSpreadPoints(const string symbol)
  {
   const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   double bid=0.0;
   double ask=0.0;
   if(point<=0.0 || !AFGetBidAsk(symbol,bid,ask))
      return 0.0;
   return (ask-bid)/point;
  }

inline double AFNormalizePrice(const string symbol,const double price)
  {
   const int digits=(int)SymbolInfoInteger(symbol,SYMBOL_DIGITS);
   return NormalizeDouble(price,digits);
  }

inline double AFNormalizeVolume(const string symbol,double volume)
  {
   const double step=SymbolInfoDouble(symbol,SYMBOL_VOLUME_STEP);
   const double minVol=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MIN);
   const double maxVol=SymbolInfoDouble(symbol,SYMBOL_VOLUME_MAX);
   if(step<=0.0)
      return volume;
   volume=MathMax(minVol,MathMin(maxVol,volume));
   volume=MathFloor(volume/step)*step;
   const int digits=(int)MathRound(-MathLog10(step));
   return NormalizeDouble(volume,MathMax(0,digits));
  }

inline double AFRiskVolumeForStop(const string symbol,const double riskMoney,const double entry,const double stop)
  {
   const double tickSize=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_SIZE);
   const double tickValue=SymbolInfoDouble(symbol,SYMBOL_TRADE_TICK_VALUE);
   const double stopDistance=MathAbs(entry-stop);
   if(riskMoney<=0.0 || tickSize<=0.0 || tickValue<=0.0 || stopDistance<=0.0)
      return 0.0;
   const double moneyPerLot=(stopDistance/tickSize)*tickValue;
   if(moneyPerLot<=0.0)
      return 0.0;
   return AFNormalizeVolume(symbol,riskMoney/moneyPerLot);
  }

inline double AFPointsBetween(const string symbol,const double priceA,const double priceB)
  {
   const double point=SymbolInfoDouble(symbol,SYMBOL_POINT);
   if(point<=0.0)
      return 0.0;
   return MathAbs(priceA-priceB)/point;
  }

inline int AFCurrentDayKey(const datetime timeValue)
  {
   MqlDateTime dt;
   TimeToStruct(timeValue,dt);
   return (dt.year*10000)+(dt.mon*100)+dt.day;
  }

inline int AFCurrentWeekKey(const datetime timeValue)
  {
   MqlDateTime dt;
   TimeToStruct(timeValue,dt);
   return (dt.year*100)+dt.day_of_year/7;
  }

inline bool AFIsPositionTypeForDirection(const long positionType,const AFDirection direction)
  {
   if(direction==DIR_LONG)
      return (positionType==POSITION_TYPE_BUY);
   if(direction==DIR_SHORT)
      return (positionType==POSITION_TYPE_SELL);
   return false;
  }

inline double AFUnrealizedR(const AFPositionPlan &plan,const double currentPrice)
  {
   if(!plan.active || plan.riskRPoints<=0.0)
      return 0.0;
   const double directionSign=(double)AFDirectionSign(plan.direction);
   const double move=(currentPrice-plan.entry)*directionSign;
   return move/plan.riskRPoints;
  }

inline int AFExtractClusterId(const string comment)
  {
   string parts[];
   if(StringSplit(comment,'|',parts)<4)
      return 0;
   return (int)StringToInteger(parts[3]);
  }

inline AFStrategyId AFExtractStrategyFromComment(const string comment)
  {
   string parts[];
   if(StringSplit(comment,'|',parts)<2)
      return STRATEGY_VOLATILITY_BREAKOUT;
   const string code=parts[1];
   if(code=="MOM")
      return STRATEGY_MOMENTUM_CONTINUATION;
   if(code=="MRV")
      return STRATEGY_MEAN_REVERSION;
   if(code=="SWP")
      return STRATEGY_LIQUIDITY_SWEEP;
   if(code=="XSB")
      return STRATEGY_XAU_SESSION_BREAKOUT;
   if(code=="UOD")
      return STRATEGY_US500_OPEN_DRIVE;
   if(code=="XLR")
      return STRATEGY_XAU_LIQUIDITY_RECLAIM;
   if(code=="UIP")
      return STRATEGY_US500_IMPULSE_PULLBACK;
   return STRATEGY_VOLATILITY_BREAKOUT;
  }

inline void AFResetLiquidityMap(AFLiquidityMap &map)
  {
   map.count=0;
   map.nearestAbove=0.0;
   map.nearestBelow=0.0;
   map.prevDayHigh=0.0;
   map.prevDayLow=0.0;
   map.sessionHigh=0.0;
   map.sessionLow=0.0;
   map.orderBlockHigh=0.0;
   map.orderBlockLow=0.0;
   map.heatScore=0.0;
   map.hasEqualHigh=false;
   map.hasEqualLow=false;
   for(int i=0; i<AF_MAX_LIQUIDITY_LEVELS; ++i)
     {
      map.levels[i].price=0.0;
      map.levels[i].strength=0.0;
      map.levels[i].side=0;
      map.levels[i].tag="";
     }
  }

inline void AFResetCandidate(AFSignalCandidate &candidate)
  {
   candidate.valid=false;
   candidate.strategy=STRATEGY_VOLATILITY_BREAKOUT;
   candidate.direction=DIR_FLAT;
   candidate.executionMethod=EXEC_MARKET;
   candidate.entry=0.0;
   candidate.stop=0.0;
   candidate.target1=0.0;
   candidate.target2=0.0;
   candidate.target3=0.0;
   candidate.confidence=0.0;
   candidate.edgeScore=0.0;
   candidate.riskMultiplier=1.0;
   candidate.dedicatedAlpha=false;
   candidate.alphaStrength=0.0;
   candidate.clusterId=0;
   for(int i=0; i<AF_FEATURE_COUNT; ++i)
      candidate.features[i]=0.0;
   candidate.rationale="";
  }

inline bool AFBarImpulse(const MqlRates &bar,const double atr)
  {
   if(atr<=0.0)
      return false;
   return (AFBarRange(bar)/atr)>=1.2 && MathAbs(bar.close-bar.open)/atr>=0.65;
  }

inline double AFReturnsCorrelation(const MqlRates &leftRates[],const MqlRates &rightRates[],const int length)
  {
   if(ArraySize(leftRates)<=length+1 || ArraySize(rightRates)<=length+1 || length<8)
      return 0.0;
   double meanLeft=0.0;
   double meanRight=0.0;
   for(int i=1; i<=length; ++i)
     {
      meanLeft+=MathLog(leftRates[i-1].close/leftRates[i].close);
      meanRight+=MathLog(rightRates[i-1].close/rightRates[i].close);
     }
   meanLeft/=(double)length;
   meanRight/=(double)length;

   double cov=0.0;
   double varLeft=0.0;
   double varRight=0.0;
   for(int i=1; i<=length; ++i)
     {
      const double lret=MathLog(leftRates[i-1].close/leftRates[i].close)-meanLeft;
      const double rret=MathLog(rightRates[i-1].close/rightRates[i].close)-meanRight;
      cov+=(lret*rret);
      varLeft+=(lret*lret);
      varRight+=(rret*rret);
     }
   if(varLeft<=0.0 || varRight<=0.0)
      return 0.0;
   return cov/MathSqrt(varLeft*varRight);
  }

inline double AFStopDistanceByAtr(const AFConfig &config,const double atr,const double structuralDistance)
  {
   double stopDistance=MathMax(config.stopAtrFloor*atr,structuralDistance);
   stopDistance=MathMin(stopDistance,config.stopAtrCeiling*atr);
   return stopDistance;
  }

inline double AFProfitFactor(const AFSymbolPerformance &performance)
  {
   if(performance.grossLoss<=0.0)
      return (performance.grossProfit>0.0 ? 99.0 : 0.0);
   return performance.grossProfit/performance.grossLoss;
  }

#endif
