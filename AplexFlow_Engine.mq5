#property strict
#property version   "1.03"
#property description "AplexFlow Engine"

#include <Trade/Trade.mqh>

#define LQ_COMMENT "AplexFlow LQ"
#define LQ_MAGIC_SUFFIX 105

enum RiskProfile { Safe=0, Aggressive=1 };
RiskProfile Profile = Safe;

enum StrategyMode { Core=0, Pullback=1, Quantum=2, Defensive=3, Adaptive=4, LiquidityScalp=5 };
// UI exposta: apenas ADAPTIVE ou LIQUIDITY.
enum TradingModeUI { TM_ADAPTIVE=0, TM_LIQUIDITY=1 };
input TradingModeUI InpTradingMode = TM_ADAPTIVE;
enum ShieldMode { SHIELD_OFF=0, SHIELD_ON=1 };
input ShieldMode Shield = SHIELD_ON;
enum DebugLevel { DBG_OFF=0, DBG_SIGNALS=1, DBG_SIGNALS_SHIELD=2, DBG_VERBOSE=3 };
input DebugLevel Debug = DBG_SIGNALS;
enum ConfigTemplate { CFG_MANUAL=0, CFG_XAUUSD_M1_RBFX_ECN=1, CFG_XAUUSD_M5_RBFX_STD=2, CFG_SCALP_PREMIUM=3, CFG_SCALP_DEFENSIVE=4, CFG_SCALP_AGGRESSIVE=5, CFG_XAUUSD_M5_247_LIVE=6, CFG_XAUUSD_M5_FUSION=7, CFG_XAUUSD_M5_HP_247=8, CFG_XAUUSD_M1_MICRO_BURST=9 };
input group "Runtime Switches"
input ConfigTemplate InpConfigTemplate = CFG_XAUUSD_M5_RBFX_STD;
input bool InpUseSpreadFilter = true;
input group "Logging"
input int InpBlockLogThrottleSec = 60;

enum LqState { LQ_IDLE=0, LQ_SWEEP=1, LQ_DISPLACED=2, LQ_MSS=3, LQ_ORDERED=4 };
enum LqEntryMode { MARKET_ON_MSS=0, LIMIT_RETEST=1, HYBRID=2 };
enum ExecProfileState { EP_DEFENSIVE=0, EP_NORMAL=1, EP_AGGRESSIVE=2 };
enum Live247LqProfile { L247_BASE=0, L247_PUSH=1 };

input group "Preset Control"
input bool InpModeForceModules = false;

input group "Timeframe"
input bool InpUseChartTimeframe = true;
input ENUM_TIMEFRAMES InpManualTimeframe = PERIOD_M5;
input bool InpClampTimeframeToM15 = true;

input group "Core Filters"
input int InpLookback = 8;
input int InpAtrPeriod = 14;
input int InpAtrMaLen = 34;
input double InpAtrFilterMult = 1.02;
input int InpPascalLenPrice = 4;
input int InpPascalLenATR = 4;
input double InpMinTrendStrengthAtr = 0.035;
input double InpBreakoutBodyAtrMin = 0.11;
input double InpBreakoutCloseStrengthMin = 0.53;
input double InpMaxSpreadAtrFrac = 0.10;

input group "Fibonacci / Pullback"
input bool InpUseFibo = true;
input int InpSwingLookback = 12;
input double InpFibo1 = 0.382;
input double InpFibo2 = 0.500;
input double InpFibo3 = 0.618;
input double InpFiboTolAtr = 0.10;
input int InpFiboMaxBarsToTrigger = 4;

input group "Quant Modules"
input bool InpUseHurst = false;
input double InpHurstMin = 0.53;
input bool InpUseEntropy = false;
input int InpEntropyLen = 64;
input double InpEntropyMax = 0.85;
input bool InpUseAutocorr = false;
input int InpAutocorrLen = 48;
input double InpAutocorrMinAbs = 0.10;

input group "Risk Model"
input bool InpUseProbRiskAdjust = true;
input int InpWinrateLen = 24;
input double InpSeqLossProbMax = 0.35;
input double InpMinRiskFactor = 0.50;
input double InpRiskPct = 0.20;
input int InpMaxTradesPerDay = 10;
input int InpMaxConsecLosses = 3;
input double InpMaxDailyDDPct = 2.5;

input group "Trade Management"
input double InpStopAtrMult = 0.80;
input bool InpUseTakeProfit = true;
input double InpTpAtrMult = 1.05;
input bool InpUseBreakEven = true;
input double InpBreakEvenAtrTrigger = 0.35;
input int InpBreakEvenOffsetPoints = 6;
input double InpTrailStartAtr = 0.55;
input double InpTrailAtrMult = 1.15;

input group "Execution"
input bool InpUseSessionFilter = true;
input int InpTradeStartHour = 7;
input int InpTradeEndHour = 20;
input int InpSlippagePoints = 6;
input int InpMaxDeviationPoints = 6;
input bool InpOnePosPerSymbol = true;
input bool InpUseDynamicSpreadGate = true;
input int InpSpreadMedianLen = 200;
input double InpSpreadMedianMult = 2.00;
input double InpStopSpreadBufferMult = 2.00;
input bool InpUseTwoStepExecutionFallback = true;

input group "LiquidityScalp"
input int InpLqSwingLookback = 30;
input double InpLqSweepBufferAtr = 0.10;
input int InpLqSweepMaxAgeBars = 5;
input double InpLqMinDisplacementAtr = 0.95;
input int InpLqMssLookback = 6;
input double InpLqStopBufferAtr = 0.24;
input double InpLqTpR = 1.05;
input LqEntryMode InpLqEntryMode = HYBRID;
input int InpLqRetestMaxAgeBars = 3;
input double InpLqRetestTolAtr = 0.06;
input bool InpLqAllowStopFallback = false;
input bool InpLqUseStructuralTrail = true;
input double InpLqStructuralTrailAtr = 0.40;

input group "Execution Shield"
input int InpShieldSpreadMaLen = 34;
input double InpShieldSpreadSpikeMult = 1.45;
input int InpShieldMaxSpreadPoints = 18;
input double InpShieldAtrShockMult = 1.70;
input double InpShieldCandleShockMult = 1.90;
input int InpShieldCooldownBars = 9;
input int InpShieldSlippageLimitPoints = 6;

input group "Adaptive Controller"
input int InpAdaptConfirmBars = 2;
input int InpAdaptMinBarsBetweenChanges = 2;
input int InpAdaptMaxChangesPerDay = 20;
input int InpAdaptMinOutcomeSamples = 16;
input double InpAdaptFallbackDdFrac = 0.70;

input group "Regime & Performance Control"
input bool InpUseAtrRegimeGate = true;
input int InpRegimeAtrMaLen = 100;
input double InpRegimeAtrMult = 1.00;
input bool InpUseAutoPause = true;
input int InpAutoPauseWindowTrades = 30;
input double InpAutoPausePfStop = 1.05;
input double InpAutoPauseDdStopPct = 1.50;
input int InpAutoPauseHours = 24;
input double InpAutoPausePfResume = 1.15;
input bool InpUseRiskLadder = true;
input int InpRiskLadderWindowTrades = 30;
input double InpRiskLadderLowPf = 1.10;
input double InpRiskLadderMidPf = 1.25;
input double InpRiskLadderHighPf = 1.40;
input double InpRiskLadderMidWinrate = 55.0;
input double InpRiskLadderHighWinrate = 55.0;
input double InpRiskLadderHighDdMaxPct = 1.00;
input double InpRiskLadderLowScale = 0.85;
input double InpRiskLadderMidScale = 1.20;
input double InpRiskLadderHighScale = 1.45;
input double InpRiskLadderMaxScale = 1.50;

struct Params {
   ENUM_TIMEFRAMES tf;

   int lookback;
   int atrPeriod;
   int atrMaLen;
   double atrFilterMult;

   int pascalLenPrice;
   int pascalLenATR;

   bool useFibo;
   int swingLookback;
   double fibo1, fibo2, fibo3;
   double fiboTolAtr;
   int fiboMaxBarsToTrigger;

   bool useHurst;
   double hurstMin;

   bool useEntropy;
   int entropyLen;
   double entropyMax;

   bool useAutocorr;
   int autocorrLen;
   double autocorrMinAbs;

   bool useProbRiskAdjust;
   int winrateLen;
   double seqLossProbMax;
   double minRiskFactor;

   double stopAtrMult;
   bool useTakeProfit;
   double tpAtrMult;
   bool useBreakEven;
   double breakEvenAtrTrigger;
   int breakEvenOffsetPoints;
   double trailStartAtr;
   double trailAtrMult;

   double minTrendStrengthAtr;
   double breakoutBodyAtrMin;
   double breakoutCloseStrengthMin;
   double maxSpreadAtrFrac;

   double riskPct;

   int maxTradesPerDay;
   int maxConsecLosses;
   double maxDailyDDPct;

   bool useSessionFilter;
   int tradeStartHour;
   int tradeEndHour;

   int slippagePoints;
   int maxDeviationPoints;
   bool onePosPerSymbol;
   bool useDynamicSpreadGate;
   int spreadMedianLen;
   double spreadMedianMult;
   double stopSpreadBufferMult;
   bool useTwoStepExecutionFallback;

   int lqSwingLookback;
   double lqSweepBufferAtr;
   int lqSweepMaxAgeBars;
   double lqMinDisplacementAtr;
   int lqMssLookback;
   double lqStopBufferAtr;
   double lqTpR;
   int lqEntryMode;
   int lqRetestMaxAgeBars;
   double lqRetestTolAtr;
   bool lqAllowStopFallback;
   bool lqUseStructuralTrail;
   double lqStructuralTrailAtr;

   int shieldSpreadMaLen;
   double shieldSpreadSpikeMult;
   int shieldMaxSpreadPoints;
   double shieldAtrShockMult;
   double shieldCandleShockMult;
   int shieldCooldownBars;
   int shieldSlippageLimitPoints;

   bool useAtrRegimeGate;
   int regimeAtrMaLen;
   double regimeAtrMult;

   bool useAutoPause;
   int autoPauseWindowTrades;
   double autoPausePfStop;
   double autoPauseDdStopPct;
   int autoPauseHours;
   double autoPausePfResume;

   bool useRiskLadder;
   int riskLadderWindowTrades;
   double riskLadderLowPf;
   double riskLadderMidPf;
   double riskLadderHighPf;
   double riskLadderMidWinrate;
   double riskLadderHighWinrate;
   double riskLadderHighDdMaxPct;
   double riskLadderLowScale;
   double riskLadderMidScale;
   double riskLadderHighScale;
   double riskLadderMaxScale;
};

struct PullbackSetup {
   bool active;
   int direction;
   datetime createdBarTime;
   int barsElapsed;
   double level1;
   double level2;
   double level3;
   double swingHigh;
   double swingLow;
};

struct LiquidityContext {
   int state;
   int direction;
   double swingLevel;
   double sweepExtreme;
   double microLevel;
   double entryPrice;
   double slPrice;
   double tpPrice;
   int barsSinceSweep;
   datetime sweepTime;
   datetime mssTime;
   bool valid;
   double displacementSizeAtr;
   ulong pendingTicket;
   int pendingBarsElapsed;
   double pendingPrice;
   bool hasPending;
   int entryModeUsed;
   datetime lastEntryBarTime;
};

struct SoftAdjustments {
   double riskMult;
   double displacementMult;
   bool preferLimitEntry;
   double tpRMult;
};

struct FusionContext {
   int dayKey;
   bool rangeReady;
   double rangeHigh;
   double rangeLow;
   bool breakoutLongDone;
   bool breakoutShortDone;
   datetime lastSignalBarTime;
};

struct MicroBurstContext {
   datetime lastSignalBarTime;
   datetime lastTrendSignalBarTime;
   datetime lastReversionSignalBarTime;
   int trendTradesToday;
   int reversionTradesToday;
};

struct Telemetry {
   int tradesOpenedToday;
   int tradesClosedToday;
   int winsToday;
   int lossesToday;

   int lqSignalsFound;
   int lqSweeps;
   int lqDisplacements;
   int lqMSS;
   int lqPendingsPlaced;
   int lqPendingsExpired;
   int lqHybridFallbackMarket;

   int shieldBlocksSpread;
   int shieldBlocksATR;
   int shieldBlocksCandle;
   int shieldBlocksSlippage;
   int regimeBlocks;
   int autoPauseBlocks;
   int autoPauseTriggers;
   int killSwitchBlocks;
   bool killSwitchTriggered;
   datetime killSwitchTriggeredAt;

   double grossProfitToday;
   double grossLossToday;
   double netToday;

   datetime dayAnchor;
};

Params P;
PullbackSetup g_setup;
LiquidityContext g_lq;
FusionContext g_fusion;
MicroBurstContext g_microBurst;
int g_live247ScaleInsToday = 0;
Telemetry g_tel;
CTrade g_trade;

int g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;

int g_dayKey = 0;
double g_dayStartEquity = 0.0;
int g_tradesToday = 0;
int g_consecLosses = 0;
bool g_killSwitch = false;
bool g_useProfilePreset = false;

int g_outcomes[];
long g_processedPositionIds[];
double g_closedPnls[];
const long MAGIC_NUMBER = 26022026;
const long LQ_MAGIC_NUMBER = MAGIC_NUMBER + LQ_MAGIC_SUFFIX;
const string DEBUG_LOG_TARGET_DIR = "D:\\ps_st\\AplexFlow-Engine\\logs";
const string DEBUG_LOG_COMMON_DIR = "AplexFlow-Engine\\logs";
Params g_baseParams;
StrategyMode Mode = Adaptive; // Modo interno definido via InpTradingMode
StrategyMode g_runtimeMode = Pullback;
bool g_adaptiveEnabled = true;
bool g_lqEnabled = false;
datetime g_shieldBlockedUntil = 0;
double g_lastExecSlippagePoints = 0.0;
int g_debugLogHandle = INVALID_HANDLE;
string g_debugLogPath = "";
bool g_debugLogUsingCommon = false;
bool g_debugLogInitTried = false;
string g_lastBlockReason = "";
datetime g_lastBlockLogAt = 0;

enum MarketRegime { RegimeBase=0, RegimeTrend=1, RegimeChoppy=2, RegimeDefense=3 };
int g_activeRegime = RegimeBase;
int g_candidateRegime = RegimeBase;
int g_candidateRegimeBars = 0;
datetime g_lastRegimeChangeBar = 0;
int g_adaptChangesToday = 0;
datetime g_autoPauseUntil = 0;
int g_execProfile = EP_NORMAL;
int g_execProfileLockBars = 0;
int g_execProfileNormConfirm = 0;
int g_execProfileAggrConfirm = 0;
int g_execProfileDefConfirm = 0;
int g_adxHandle = INVALID_HANDLE;
int g_live247Profile = L247_BASE;
int g_live247ProfileLockBars = 0;
int g_live247ProfileBaseConfirm = 0;
int g_live247ProfilePushConfirm = 0;

bool ComputeRecentPerformance(const int windowTrades,
                              double &pf,
                              double &winrate,
                              double &localDdPct,
                              int &samples);
double ComputePerformanceRiskScale(double &pf, double &winrate, double &localDdPct, int &samples);

string RiskProfileToString(const RiskProfile profile)
{
   return (profile == Safe ? "Safe" : "Aggressive");
}

bool IsOurMagic(const long magic)
{
   return (magic == MAGIC_NUMBER || magic == LQ_MAGIC_NUMBER);
}

bool IsPendingOrderType(const ENUM_ORDER_TYPE type)
{
   return (type == ORDER_TYPE_BUY_LIMIT ||
           type == ORDER_TYPE_SELL_LIMIT ||
           type == ORDER_TYPE_BUY_STOP ||
           type == ORDER_TYPE_SELL_STOP ||
           type == ORDER_TYPE_BUY_STOP_LIMIT ||
           type == ORDER_TYPE_SELL_STOP_LIMIT);
}

bool IsLiquidityPendingOrderTicket(const ulong ticket)
{
   if(ticket == 0 || !OrderSelect(ticket))
      return false;

   if(OrderGetString(ORDER_SYMBOL) != _Symbol)
      return false;

   if((long)OrderGetInteger(ORDER_MAGIC) != LQ_MAGIC_NUMBER)
      return false;

   if(OrderGetString(ORDER_COMMENT) != LQ_COMMENT)
      return false;

   const ENUM_ORDER_TYPE type = (ENUM_ORDER_TYPE)OrderGetInteger(ORDER_TYPE);
   return IsPendingOrderType(type);
}

string StrategyModeToString(const StrategyMode mode)
{
   switch(mode)
   {
      case Core:      return "Core";
      case Pullback:  return "Pullback";
      case Quantum:   return "Quantum";
      case Defensive: return "Defensive";
      case Adaptive:  return "Adaptive";
      case LiquidityScalp: return "LiquidityScalp";
      default:        return "Unknown";
   }
}

string ShieldModeToString(const ShieldMode mode)
{
   return (mode == SHIELD_ON ? "ON" : "OFF");
}

string TradingModeUIToString(const TradingModeUI mode)
{
   return (mode == TM_LIQUIDITY ? "LIQUIDITY" : "ADAPTIVE");
}

string ConfigTemplateToString(const ConfigTemplate cfg)
{
   switch(cfg)
   {
      case CFG_XAUUSD_M1_RBFX_ECN:return "XAUUSD_M1_RoboForex_ECN";
      case CFG_XAUUSD_M5_RBFX_STD:return "XAUUSD_M5_RoboForex_StdPro";
      case CFG_XAUUSD_M5_247_LIVE:return "XAUUSD_M5_24x7_Live";
      case CFG_XAUUSD_M5_FUSION:return "XAUUSD_M5_Fusion";
      case CFG_XAUUSD_M5_HP_247:return "XAUUSD_M5_HighProfit_24x7";
      case CFG_XAUUSD_M1_MICRO_BURST:return "XAUUSD_M1_MicroBurst";
      case CFG_SCALP_PREMIUM:   return "ScalpPremium";
      case CFG_SCALP_DEFENSIVE: return "ScalpDefensive";
      case CFG_SCALP_AGGRESSIVE:return "ScalpAggressive";
      default:                  return "Manual";
   }
}

bool IsXauUsdM5ManagedTemplate(const ConfigTemplate cfg)
{
   return (cfg == CFG_XAUUSD_M5_RBFX_STD ||
           cfg == CFG_XAUUSD_M5_247_LIVE ||
           cfg == CFG_XAUUSD_M5_HP_247);
}

bool IsLive247LiquidityTemplate()
{
   return (InpConfigTemplate == CFG_XAUUSD_M5_247_LIVE && InpTradingMode == TM_LIQUIDITY && P.tf == PERIOD_M5);
}

bool IsHighProfit247LiquidityTemplate()
{
   return (InpConfigTemplate == CFG_XAUUSD_M5_HP_247 && InpTradingMode == TM_LIQUIDITY && P.tf == PERIOD_M5);
}

bool IsDynamicLiquidityOverlayTemplate()
{
   return IsLive247LiquidityTemplate();
}

bool IsFusionLiquidityTemplate()
{
   return (InpConfigTemplate == CFG_XAUUSD_M5_FUSION && InpTradingMode == TM_LIQUIDITY && P.tf == PERIOD_M5);
}

bool IsMicroBurstLiquidityTemplate()
{
   return (InpConfigTemplate == CFG_XAUUSD_M1_MICRO_BURST && InpTradingMode == TM_LIQUIDITY && P.tf == PERIOD_M1);
}

string LqStateToString(const int state)
{
   switch(state)
   {
      case LQ_IDLE:      return "IDLE";
      case LQ_SWEEP:     return "SWEEP";
      case LQ_DISPLACED: return "DISPLACED";
      case LQ_MSS:       return "MSS";
      case LQ_ORDERED:   return "ORDERED";
      default:           return "UNKNOWN";
   }
}

string MarketRegimeToString(const int regime)
{
   switch(regime)
   {
      case RegimeBase:    return "Base";
      case RegimeTrend:   return "Trend";
      case RegimeChoppy:  return "Choppy";
      case RegimeDefense: return "Defense";
      default:            return "Unknown";
   }
}

string ExecProfileToString(const int profile)
{
   switch(profile)
   {
      case EP_DEFENSIVE:  return "DEFENSIVE";
      case EP_NORMAL:     return "NORMAL";
      case EP_AGGRESSIVE: return "AGGRESSIVE";
      default:            return "UNKNOWN";
   }
}

string Live247ProfileToString(const int profile)
{
   switch(profile)
   {
      case L247_BASE: return "BASE";
      case L247_PUSH: return "PUSH";
      default:        return "UNKNOWN";
   }
}

ENUM_TIMEFRAMES ResolveSelectedTimeframe()
{
   ENUM_TIMEFRAMES tf = (InpUseChartTimeframe ? (ENUM_TIMEFRAMES)_Period : InpManualTimeframe);
   const int tfSec = PeriodSeconds(tf);
   if(tfSec <= 0)
      return PERIOD_M5;

   // Scalping guardrail can be enabled/disabled from inputs.
   if(InpClampTimeframeToM15 && tfSec > PeriodSeconds(PERIOD_M15))
      return PERIOD_M15;

   return tf;
}

double ClampValue(const double value, const double minValue, const double maxValue)
{
   return MathMax(minValue, MathMin(maxValue, value));
}

bool IsDebugAtLeast(const DebugLevel level)
{
   return ((int)Debug >= (int)level);
}

string SanitizeFileToken(const string raw)
{
   string out = raw;
   StringReplace(out, ":", "-");
   StringReplace(out, "/", "-");
   StringReplace(out, "\\", "-");
   StringReplace(out, " ", "_");
   StringReplace(out, ".", "_");
   return out;
}

datetime CurrentTimeSafe()
{
   datetime now = TimeCurrent();
   if(now <= 0)
      now = TimeTradeServer();
   if(now <= 0)
      now = TimeLocal();
   return now;
}

string BuildDebugLogFileName()
{
   const datetime now = CurrentTimeSafe();
   MqlDateTime dt;
   TimeToStruct(now, dt);

   const string symbolPart = SanitizeFileToken(_Symbol);
   const string tfPart = SanitizeFileToken(EnumToString(P.tf));
   return StringFormat("AplexFlow_Debug_%s_%s_%04d%02d%02d_%02d%02d%02d.log",
                       symbolPart,
                       tfPart,
                       dt.year,
                       dt.mon,
                       dt.day,
                       dt.hour,
                       dt.min,
                       dt.sec);
}

bool OpenDebugLogFile()
{
   if(g_debugLogHandle != INVALID_HANDLE)
      return true;

   if(g_debugLogInitTried)
      return false;
   g_debugLogInitTried = true;

   const int flags = FILE_READ | FILE_WRITE | FILE_TXT | FILE_ANSI | FILE_SHARE_READ | FILE_SHARE_WRITE;
   const string fileName = BuildDebugLogFileName();
   const string targetPath = DEBUG_LOG_TARGET_DIR + "\\" + fileName;

   // Try requested workspace folder first.
   FolderCreate(DEBUG_LOG_TARGET_DIR);
   ResetLastError();
   g_debugLogHandle = FileOpen(targetPath, flags);
   int errTarget = GetLastError();
   if(g_debugLogHandle != INVALID_HANDLE)
   {
      g_debugLogPath = targetPath;
      g_debugLogUsingCommon = false;
      FileSeek(g_debugLogHandle, 0, SEEK_END);
      return true;
   }

   // Fallback to terminal common files sandbox if absolute path is blocked.
   FolderCreate("AplexFlow-Engine", FILE_COMMON);
   FolderCreate(DEBUG_LOG_COMMON_DIR, FILE_COMMON);
   const string commonRelativePath = DEBUG_LOG_COMMON_DIR + "\\" + fileName;
   ResetLastError();
   g_debugLogHandle = FileOpen(commonRelativePath, flags | FILE_COMMON);
   const int errCommon = GetLastError();
   if(g_debugLogHandle != INVALID_HANDLE)
   {
      g_debugLogUsingCommon = true;
      g_debugLogPath = TerminalInfoString(TERMINAL_COMMONDATA_PATH) + "\\Files\\" + commonRelativePath;
      FileSeek(g_debugLogHandle, 0, SEEK_END);
      PrintFormat("Debug file fallback ativo | destino=%s | errTarget=%d",
                  g_debugLogPath,
                  errTarget);
      return true;
   }

   PrintFormat("Falha ao abrir arquivo de debug | target=%s errTarget=%d | errCommon=%d",
               targetPath,
               errTarget,
               errCommon);
   return false;
}

void CloseDebugLogFile()
{
   if(g_debugLogHandle != INVALID_HANDLE)
   {
      FileFlush(g_debugLogHandle);
      FileClose(g_debugLogHandle);
      g_debugLogHandle = INVALID_HANDLE;
   }
}

void WriteDebugLogLine(const string message)
{
   if(message == "")
      return;

   if(g_debugLogHandle == INVALID_HANDLE && !OpenDebugLogFile())
      return;

   if(g_debugLogHandle == INVALID_HANDLE)
      return;

   const string stamp = TimeToString(CurrentTimeSafe(), TIME_DATE | TIME_MINUTES | TIME_SECONDS);
   FileWriteString(g_debugLogHandle, stamp + " | " + message + "\r\n");
   FileFlush(g_debugLogHandle);
}

void DebugLog(const DebugLevel level, const string message)
{
   if(!IsDebugAtLeast(level))
      return;

   Print(message);
   WriteDebugLogLine(message);
}

void LogAndPersist(const string message)
{
   Print(message);
   WriteDebugLogLine(message);
}

bool ShouldLogBlockedReason(const string reasonKey)
{
   if(reasonKey == "")
      return false;

   if(!IsDebugAtLeast(DBG_SIGNALS_SHIELD))
      return false;

   const datetime now = CurrentTimeSafe();
   const int throttleSec = MathMax(0, InpBlockLogThrottleSec);

   if(reasonKey != g_lastBlockReason)
   {
      g_lastBlockReason = reasonKey;
      g_lastBlockLogAt = now;
      return true;
   }

   if(throttleSec <= 0)
   {
      g_lastBlockLogAt = now;
      return true;
   }

   if(g_lastBlockLogAt <= 0 || (now - g_lastBlockLogAt) >= throttleSec)
   {
      g_lastBlockLogAt = now;
      return true;
   }

   return false;
}

void LogBlockThrottled(const string reasonKey, const string details = "")
{
   if(!ShouldLogBlockedReason(reasonKey))
      return;

   string message = reasonKey;
   if(details != "")
      message = reasonKey + " | " + details;

   DebugLog(DBG_SIGNALS_SHIELD, message);
}

void ResetBlockLogThrottleState()
{
   g_lastBlockReason = "";
   g_lastBlockLogAt = 0;
}

StrategyMode StrategyModeFromRegime(const int regime)
{
   switch(regime)
   {
      case RegimeTrend:   return Quantum;
      case RegimeChoppy:  return Core;
      case RegimeDefense: return Defensive;
      default:            return Pullback;
   }
}

RiskProfile ProfileFromRegime(const int regime)
{
   if(regime == RegimeTrend)
      return Aggressive;
   return Safe;
}

bool StrategyModeUsesPullbackSetup(const StrategyMode mode)
{
   switch(mode)
   {
      case Pullback:
      case Quantum:
      case Defensive:
      case Adaptive:
         return true;
      default:
         return false;
   }
}

void ApplyStrategyModeToParams(Params &params, const StrategyMode mode)
{
   params.useFibo = false;
   params.useHurst = false;
   params.useEntropy = false;
   params.useAutocorr = false;
   params.useProbRiskAdjust = true;

   switch(mode)
   {
      case Core:
         break;

      case Pullback:
         params.useFibo = true;
         break;

      case Quantum:
         // Quantum opera breakout direto com filtros quant para aproveitar regime de tendencia.
         params.useFibo = false;
         params.useHurst = true;
         params.useAutocorr = true;
         params.hurstMin = (Profile == Safe ? 0.55 : 0.53);
         params.autocorrMinAbs = 0.10;
         break;

      case Defensive:
         params.useFibo = true;
         params.useHurst = true;
         params.useEntropy = true;
         params.entropyLen = 100;
         params.entropyMax = 0.85;
         break;

      case Adaptive:
         // The runtime mode is selected automatically by regime; default baseline is Pullback.
         params.useFibo = true;
         break;

      case LiquidityScalp:
         // Structural entries are handled by the liquidity state machine.
         break;
   }
}

int BuildDayKey(const datetime t)
{
   MqlDateTime dt;
   TimeToStruct(t, dt);
   return (dt.year * 10000 + dt.mon * 100 + dt.day);
}

double NormalizePrice(const double price)
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   return NormalizeDouble(price, digits);
}

double NormalizeVolume(const double lots)
{
   const double volMin  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volMax  = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volStep = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   if(volMin <= 0.0 || volMax <= 0.0 || volStep <= 0.0)
      return 0.0;

   double v = lots;
   if(v < volMin) v = volMin;
   if(v > volMax) v = volMax;

   const double steps = MathFloor((v - volMin) / volStep + 1e-9);
   v = volMin + steps * volStep;
   if(v < volMin) v = volMin;
   if(v > volMax) v = volMax;

   const int volDigits = VolumeDigitsFromStep(volStep);
   return NormalizeDouble(v, volDigits);
}

int VolumeDigitsFromStep(const double step)
{
   if(step <= 0.0)
      return 2;

   int digits = 0;
   double v = step;
   while(digits < 8 && MathAbs(v - MathRound(v)) > 1e-8)
   {
      v *= 10.0;
      digits++;
   }
   return digits;
}

bool IsHedgingAccount()
{
   const long marginMode = AccountInfoInteger(ACCOUNT_MARGIN_MODE);
   return (marginMode == ACCOUNT_MARGIN_MODE_RETAIL_HEDGING);
}

bool BuildPascalWeights(const int len, double &weights[])
{
   if(len < 1)
      return false;

   ArrayResize(weights, len);
   weights[0] = 1.0;

   for(int i = 1; i < len; i++)
      weights[i] = weights[i - 1] * ((double)(len - i) / (double)i);

   double sum = 0.0;
   for(int i = 0; i < len; i++)
      sum += weights[i];

   if(sum <= 0.0)
      return false;

   for(int i = 0; i < len; i++)
      weights[i] /= sum;

   return true;
}

void ApplyConfigTemplatePreset(Params &params, const ConfigTemplate cfg)
{
   switch(cfg)
   {
      case CFG_XAUUSD_M1_RBFX_ECN:
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.97;
         params.maxSpreadAtrFrac = 0.25;

         params.riskPct = 0.15;
         params.maxTradesPerDay = 12;
         params.maxConsecLosses = 3;
         params.maxDailyDDPct = 3.5;
         params.onePosPerSymbol = true;
         params.useSessionFilter = true;
         params.tradeStartHour = 7;
         params.tradeEndHour = 17;
         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 2.00;
         params.stopSpreadBufferMult = 2.00;
         params.useTwoStepExecutionFallback = true;

         params.stopAtrMult = 0.80;
         params.useTakeProfit = true;
         params.tpAtrMult = 1.05;
         params.useBreakEven = true;
         params.breakEvenAtrTrigger = 0.35;
         params.breakEvenOffsetPoints = 8;
         params.trailStartAtr = 0.55;
         params.trailAtrMult = 1.10;

         params.lqSwingLookback = 24;
         params.lqSweepBufferAtr = 0.08;
         params.lqSweepMaxAgeBars = 10;
         params.lqMinDisplacementAtr = 0.75;
         params.lqMssLookback = 8;
         params.lqStopBufferAtr = 0.24;
         params.lqTpR = 1.08;
         params.lqEntryMode = HYBRID;
         params.lqRetestMaxAgeBars = 12;
         params.lqRetestTolAtr = 0.10;
         params.lqAllowStopFallback = true;
         params.lqUseStructuralTrail = true;

         params.shieldSpreadMaLen = 34;
         params.shieldMaxSpreadPoints = 140;
         params.shieldSpreadSpikeMult = 1.90;
         params.shieldAtrShockMult = 1.70;
         params.shieldCandleShockMult = 2.00;
         params.shieldCooldownBars = 5;
         params.shieldSlippageLimitPoints = 14;

         params.slippagePoints = 12;
         params.maxDeviationPoints = 12;

         params.useAtrRegimeGate = true;
         params.regimeAtrMaLen = 100;
         params.regimeAtrMult = 1.25;

         params.useAutoPause = true;
         params.autoPauseWindowTrades = 30;
         params.autoPausePfStop = 1.05;
         params.autoPauseDdStopPct = 1.50;
         params.autoPauseHours = 24;
         params.autoPausePfResume = 1.15;

         params.useRiskLadder = true;
         params.riskLadderWindowTrades = 30;
         params.riskLadderLowPf = 1.10;
         params.riskLadderMidPf = 1.25;
         params.riskLadderHighPf = 1.40;
         params.riskLadderMidWinrate = 55.0;
         params.riskLadderHighWinrate = 55.0;
         params.riskLadderHighDdMaxPct = 1.00;
         params.riskLadderLowScale = 0.85;
         params.riskLadderMidScale = 1.20;
         params.riskLadderHighScale = 1.45;
         params.riskLadderMaxScale = 1.50;
         break;

      case CFG_XAUUSD_M5_RBFX_STD:
         params.tf = PERIOD_M5;
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.97;
         params.maxSpreadAtrFrac = 0.25;

         // XAUUSD M5 respondeu melhor com swing mais curto e setup objetivo.
         params.swingLookback = 10;
         params.fiboTolAtr = 0.10;
         params.fiboMaxBarsToTrigger = 3;

         params.stopAtrMult = 2.20;
         params.useTakeProfit = true;
         params.tpAtrMult = 1.50;
         params.useBreakEven = true;
         params.breakEvenAtrTrigger = 0.55;
         params.breakEvenOffsetPoints = 30;
         params.trailStartAtr = 0.90;
         params.trailAtrMult = 1.00;

         params.useSessionFilter = true;
         params.tradeStartHour = 7;
         params.tradeEndHour = 17;
         params.onePosPerSymbol = true;
         params.maxConsecLosses = 3;
         params.maxTradesPerDay = 8;
         params.maxDailyDDPct = 2.5;

         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 2.00;
         params.stopSpreadBufferMult = 2.00;
         params.useTwoStepExecutionFallback = true;

         params.shieldSpreadMaLen = 34;
         params.shieldMaxSpreadPoints = 400;
         params.shieldSpreadSpikeMult = 1.90;
         params.shieldAtrShockMult = 1.25;
         params.shieldCandleShockMult = 2.00;
         params.shieldCooldownBars = 5;
         params.shieldSlippageLimitPoints = 14;
         params.slippagePoints = 12;
         params.maxDeviationPoints = 12;

         params.lqSwingLookback = 24;
         params.lqSweepBufferAtr = 0.60;
         params.lqSweepMaxAgeBars = 10;
         params.lqMinDisplacementAtr = 0.80;
         params.lqMssLookback = 8;
         params.lqStopBufferAtr = 0.24;
         params.lqTpR = 1.08;
         params.lqEntryMode = HYBRID;
         params.lqRetestMaxAgeBars = 8;
         params.lqRetestTolAtr = 0.10;
         params.lqAllowStopFallback = true;
         params.lqUseStructuralTrail = true;

         params.useAtrRegimeGate = true;
         params.regimeAtrMaLen = 100;
         params.regimeAtrMult = 1.00;

         params.useAutoPause = true;
         params.autoPauseWindowTrades = 30;
         params.autoPausePfStop = 1.20;
         params.autoPauseDdStopPct = 1.50;
         params.autoPauseHours = 24;
         params.autoPausePfResume = 1.20;

         params.useRiskLadder = true;
         params.riskLadderWindowTrades = 30;
         params.riskLadderLowPf = 1.20;
         params.riskLadderMidPf = 1.30;
         params.riskLadderHighPf = 1.45;
         params.riskLadderMidWinrate = 55.0;
         params.riskLadderHighWinrate = 58.0;
         params.riskLadderHighDdMaxPct = 1.50;
         params.riskLadderLowScale = 0.85;
         params.riskLadderMidScale = 1.20;
         params.riskLadderHighScale = 1.35;
         params.riskLadderMaxScale = 1.35;

         if(InpTradingMode == TM_LIQUIDITY)
         {
            // Liquidity em XAUUSD M5 precisa de janela mais curta e stop estrutural
            // mais largo para evitar micro-alvos engolidos por spread/latencia.
            params.riskPct = 0.10;
            params.maxTradesPerDay = 80;
            params.maxConsecLosses = 5;
            params.maxDailyDDPct = 4.0;

            params.atrFilterMult = 0.60;
            params.useSessionFilter = true;
            params.tradeStartHour = 6;
            params.tradeEndHour = 21;
            params.onePosPerSymbol = true;

            params.useDynamicSpreadGate = false;
            params.maxSpreadAtrFrac = 0.35;
            params.slippagePoints = 30;
            params.maxDeviationPoints = 30;

            params.lqSwingLookback = 6;
            params.lqSweepBufferAtr = 0.00;
            params.lqSweepMaxAgeBars = 6;
            params.lqMinDisplacementAtr = 0.30;
            params.lqStopBufferAtr = 0.30;
            params.lqTpR = 1.35;
            params.lqEntryMode = HYBRID;
            params.lqRetestMaxAgeBars = 2;
            params.lqRetestTolAtr = 0.08;
            params.lqAllowStopFallback = true;
            params.lqUseStructuralTrail = true;
            params.lqStructuralTrailAtr = 0.20;

            params.useBreakEven = false;
            params.trailStartAtr = 1.20;
            params.trailAtrMult = 1.00;

            params.useAtrRegimeGate = false;
            params.useAutoPause = false;

            params.shieldSpreadSpikeMult = 4.00;
            params.shieldMaxSpreadPoints = 1200;
            params.shieldAtrShockMult = 4.00;
            params.shieldCandleShockMult = 5.00;
            params.shieldCooldownBars = 1;
            params.shieldSlippageLimitPoints = 80;
         }
         else
         {
            // Base unica para o preset M5; a agressividade e controlada dinamicamente pelo AutoAggression.
            params.riskPct = 0.60;
            params.maxTradesPerDay = 8;
            params.maxDailyDDPct = 3.0;
            params.autoPauseDdStopPct = 1.50;
         }
         break;

      case CFG_XAUUSD_M5_247_LIVE:
         params.tf = PERIOD_M5;
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.98;
         params.maxSpreadAtrFrac = 0.18;

         params.swingLookback = 10;
         params.fiboTolAtr = 0.10;
         params.fiboMaxBarsToTrigger = 3;

         params.stopAtrMult = 0.80;
         params.useTakeProfit = true;
         params.tpAtrMult = 1.05;
         params.useBreakEven = true;
         params.breakEvenAtrTrigger = 0.45;
         params.breakEvenOffsetPoints = 5;
         params.trailStartAtr = 1.00;
         params.trailAtrMult = 1.20;

         params.useSessionFilter = true;
         params.tradeStartHour = 5;
         params.tradeEndHour = 21;
         params.onePosPerSymbol = true;
         params.maxTradesPerDay = 30;
         params.maxConsecLosses = 3;
         params.maxDailyDDPct = 4.0;

         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 1.80;
         params.stopSpreadBufferMult = 2.00;
         params.useTwoStepExecutionFallback = true;

         params.lqSwingLookback = 12;
         params.lqSweepBufferAtr = 0.08;
         params.lqSweepMaxAgeBars = 4;
         params.lqMinDisplacementAtr = 0.80;
         params.lqStopBufferAtr = 0.24;
         params.lqTpR = 1.23;
         params.lqEntryMode = HYBRID;
         params.lqRetestMaxAgeBars = 2;
         params.lqRetestTolAtr = 0.07;
         params.lqAllowStopFallback = true;
         params.lqUseStructuralTrail = true;
         params.lqStructuralTrailAtr = 0.30;

         params.shieldSpreadMaLen = 34;
         params.shieldSpreadSpikeMult = 1.60;
         params.shieldMaxSpreadPoints = 24;
         params.shieldAtrShockMult = 1.70;
         params.shieldCandleShockMult = 1.90;
         params.shieldCooldownBars = 9;
         params.shieldSlippageLimitPoints = 6;
         params.slippagePoints = 6;
         params.maxDeviationPoints = 6;

         params.useAtrRegimeGate = true;
         params.regimeAtrMaLen = 100;
         params.regimeAtrMult = 1.00;

         params.useAutoPause = true;
         params.autoPauseWindowTrades = 30;
         params.autoPausePfStop = 1.05;
         params.autoPauseDdStopPct = 1.50;
         params.autoPauseHours = 24;
         params.autoPausePfResume = 1.15;

         params.useRiskLadder = true;
         params.riskLadderWindowTrades = 30;
         params.riskLadderLowPf = 1.10;
         params.riskLadderMidPf = 1.25;
         params.riskLadderHighPf = 1.40;
         params.riskLadderMidWinrate = 55.0;
         params.riskLadderHighWinrate = 55.0;
         params.riskLadderHighDdMaxPct = 1.00;
         params.riskLadderLowScale = 0.85;
         params.riskLadderMidScale = 1.20;
         params.riskLadderHighScale = 1.45;
         params.riskLadderMaxScale = 1.50;

         if(InpTradingMode == TM_LIQUIDITY)
         {
            params.riskPct = 1.25;
            params.useBreakEven = false;
            params.trailStartAtr = 1.30;
            params.trailAtrMult = 1.00;
            params.useAutoPause = false;
         }
         else
         {
            params.riskPct = 0.55;
            params.maxTradesPerDay = 10;
            params.maxDailyDDPct = 3.0;
         }
         break;

      case CFG_XAUUSD_M5_FUSION:
         params.tf = PERIOD_M5;
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.72;
         params.maxSpreadAtrFrac = 0.18;

         params.stopAtrMult = 1.00;
         params.useTakeProfit = true;
         params.tpAtrMult = 1.20;
         params.useBreakEven = false;
         params.breakEvenAtrTrigger = 0.60;
         params.breakEvenOffsetPoints = 5;
         params.trailStartAtr = 1.10;
         params.trailAtrMult = 1.00;

         params.useSessionFilter = true;
         params.tradeStartHour = 0;
         params.tradeEndHour = 20;
         params.onePosPerSymbol = true;
         params.maxTradesPerDay = 12;
         params.maxConsecLosses = 3;
         params.maxDailyDDPct = 3.0;
         params.riskPct = 0.35;

         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 1.70;
         params.stopSpreadBufferMult = 2.00;
         params.useTwoStepExecutionFallback = true;

         params.shieldSpreadMaLen = 34;
         params.shieldSpreadSpikeMult = 2.00;
         params.shieldMaxSpreadPoints = 40;
         params.shieldAtrShockMult = 2.20;
         params.shieldCandleShockMult = 2.60;
         params.shieldCooldownBars = 3;
         params.shieldSlippageLimitPoints = 10;
         params.slippagePoints = 10;
         params.maxDeviationPoints = 10;

         params.useAtrRegimeGate = true;
         params.regimeAtrMaLen = 80;
         params.regimeAtrMult = 0.95;
         params.useAutoPause = true;
         params.autoPauseWindowTrades = 12;
         params.autoPausePfStop = 0.95;
         params.autoPauseDdStopPct = 1.20;
         params.autoPauseHours = 24;
         params.autoPausePfResume = 1.05;
         params.useRiskLadder = true;
         params.riskLadderWindowTrades = 24;
         params.riskLadderLowPf = 1.00;
         params.riskLadderMidPf = 1.15;
         params.riskLadderHighPf = 1.35;
         params.riskLadderMidWinrate = 52.0;
         params.riskLadderHighWinrate = 56.0;
         params.riskLadderHighDdMaxPct = 1.20;
         params.riskLadderLowScale = 0.80;
         params.riskLadderMidScale = 1.10;
         params.riskLadderHighScale = 1.30;
         params.riskLadderMaxScale = 1.35;
         break;

      case CFG_XAUUSD_M5_HP_247:
         params.tf = PERIOD_M5;
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.60;
         params.maxSpreadAtrFrac = 0.12;

         params.swingLookback = 10;
         params.fiboTolAtr = 0.10;
         params.fiboMaxBarsToTrigger = 3;

         params.stopAtrMult = 2.20;
         params.useTakeProfit = true;
         params.tpAtrMult = 1.50;
         params.useBreakEven = false;
         params.breakEvenAtrTrigger = 0.60;
         params.breakEvenOffsetPoints = 5;
         params.trailStartAtr = 1.20;
         params.trailAtrMult = 1.00;

         params.useSessionFilter = true;
         params.tradeStartHour = 7;
         params.tradeEndHour = 20;
         params.onePosPerSymbol = true;
         params.maxTradesPerDay = 80;
         params.maxConsecLosses = 3;
         params.maxDailyDDPct = 2.0;

         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 1.65;
         params.stopSpreadBufferMult = 2.00;
         params.useTwoStepExecutionFallback = true;

         params.lqSwingLookback = 6;
         params.lqSweepBufferAtr = 0.00;
         params.lqSweepMaxAgeBars = 6;
         params.lqMinDisplacementAtr = 0.30;
         params.lqStopBufferAtr = 0.30;
         params.lqTpR = 1.35;
         params.lqEntryMode = HYBRID;
         params.lqRetestMaxAgeBars = 2;
         params.lqRetestTolAtr = 0.08;
         params.lqAllowStopFallback = true;
         params.lqUseStructuralTrail = true;
         params.lqStructuralTrailAtr = 0.20;

         params.shieldSpreadMaLen = 34;
         params.shieldSpreadSpikeMult = 2.40;
         params.shieldMaxSpreadPoints = 80;
         params.shieldAtrShockMult = 2.60;
         params.shieldCandleShockMult = 3.20;
         params.shieldCooldownBars = 2;
         params.shieldSlippageLimitPoints = 18;
         params.slippagePoints = 18;
         params.maxDeviationPoints = 18;

         params.useAtrRegimeGate = true;
         params.regimeAtrMaLen = 60;
         params.regimeAtrMult = 0.95;

         params.useAutoPause = true;
         params.autoPauseWindowTrades = 8;
         params.autoPausePfStop = 0.90;
         params.autoPauseDdStopPct = 0.70;
         params.autoPauseHours = 48;
         params.autoPausePfResume = 1.05;

         params.useRiskLadder = true;
         params.riskLadderWindowTrades = 10;
         params.riskLadderLowPf = 1.00;
         params.riskLadderMidPf = 1.10;
         params.riskLadderHighPf = 1.25;
         params.riskLadderMidWinrate = 50.0;
         params.riskLadderHighWinrate = 54.0;
         params.riskLadderHighDdMaxPct = 0.90;
         params.riskLadderLowScale = 0.60;
         params.riskLadderMidScale = 1.00;
         params.riskLadderHighScale = 1.15;
         params.riskLadderMaxScale = 1.15;

         if(InpTradingMode == TM_LIQUIDITY)
         {
            params.riskPct = 0.10;
         }
         else
         {
            params.riskPct = 0.45;
            params.maxTradesPerDay = 10;
            params.maxDailyDDPct = 2.5;
         }
         break;

      case CFG_XAUUSD_M1_MICRO_BURST:
         params.tf = PERIOD_M1;
         params.atrPeriod = 14;
         params.atrMaLen = 34;
         params.atrFilterMult = 0.55;
         params.maxSpreadAtrFrac = 0.40;

         params.lookback = 60;
         params.stopAtrMult = 0.70;
         params.useTakeProfit = true;
         params.tpAtrMult = 0.95;
         params.useBreakEven = false;
         params.breakEvenAtrTrigger = 0.45;
         params.breakEvenOffsetPoints = 4;
         params.trailStartAtr = 0.85;
         params.trailAtrMult = 0.85;

         params.useSessionFilter = true;
         params.tradeStartHour = 0;
         params.tradeEndHour = 21;
         params.onePosPerSymbol = true;
         params.maxTradesPerDay = 80;
         params.maxConsecLosses = 6;
         params.maxDailyDDPct = 4.0;
         params.riskPct = 0.35;

         params.useDynamicSpreadGate = true;
         params.spreadMedianLen = 200;
         params.spreadMedianMult = 2.40;
         params.stopSpreadBufferMult = 2.20;
         params.useTwoStepExecutionFallback = true;

         params.shieldSpreadMaLen = 34;
         params.shieldSpreadSpikeMult = 2.60;
         params.shieldMaxSpreadPoints = 180;
         params.shieldAtrShockMult = 2.80;
         params.shieldCandleShockMult = 3.20;
         params.shieldCooldownBars = 2;
         params.shieldSlippageLimitPoints = 30;
         params.slippagePoints = 20;
         params.maxDeviationPoints = 20;

         params.useAtrRegimeGate = false;
         params.useAutoPause = false;
         params.autoPauseWindowTrades = 20;
         params.autoPausePfStop = 0.92;
         params.autoPauseDdStopPct = 2.00;
         params.autoPauseHours = 12;
         params.autoPausePfResume = 1.05;
         params.useRiskLadder = false;
         break;

      case CFG_SCALP_PREMIUM:
         // Matches the default premium scalp profile currently used in inputs.
         break;

      case CFG_SCALP_DEFENSIVE:
         params.atrPeriod = 14;
         params.atrMaLen = 40;
         params.atrFilterMult = 1.05;
         params.maxSpreadAtrFrac = 0.08;
         params.riskPct = 0.12;
         params.maxTradesPerDay = 6;
         params.maxConsecLosses = 2;
         params.maxDailyDDPct = 2.0;
         params.stopAtrMult = 0.85;
         params.tpAtrMult = 1.00;
         params.breakEvenAtrTrigger = 0.30;
         params.breakEvenOffsetPoints = 7;
         params.trailStartAtr = 0.50;
         params.trailAtrMult = 1.20;
         params.tradeStartHour = 7;
         params.tradeEndHour = 19;
         params.slippagePoints = 5;
         params.maxDeviationPoints = 5;

         params.lqSwingLookback = 32;
         params.lqSweepBufferAtr = 0.11;
         params.lqSweepMaxAgeBars = 4;
         params.lqMinDisplacementAtr = 1.05;
         params.lqStopBufferAtr = 0.26;
         params.lqTpR = 1.00;
         params.lqRetestMaxAgeBars = 2;
         params.lqRetestTolAtr = 0.05;
         params.lqAllowStopFallback = false;

         params.shieldSpreadMaLen = 34;
         params.shieldSpreadSpikeMult = 1.35;
         params.shieldMaxSpreadPoints = 16;
         params.shieldAtrShockMult = 1.60;
         params.shieldCandleShockMult = 1.80;
         params.shieldCooldownBars = 10;
         params.shieldSlippageLimitPoints = 5;
         break;

      case CFG_SCALP_AGGRESSIVE:
         params.atrPeriod = 12;
         params.atrMaLen = 28;
         params.atrFilterMult = 0.98;
         params.maxSpreadAtrFrac = 0.12;
         params.riskPct = 0.30;
         params.maxTradesPerDay = 14;
         params.maxConsecLosses = 4;
         params.maxDailyDDPct = 3.0;
         params.stopAtrMult = 0.75;
         params.tpAtrMult = 1.10;
         params.breakEvenAtrTrigger = 0.30;
         params.breakEvenOffsetPoints = 4;
         params.trailStartAtr = 0.50;
         params.trailAtrMult = 1.05;
         params.tradeStartHour = 6;
         params.tradeEndHour = 21;
         params.slippagePoints = 8;
         params.maxDeviationPoints = 8;

         params.lqSwingLookback = 24;
         params.lqSweepBufferAtr = 0.09;
         params.lqSweepMaxAgeBars = 6;
         params.lqMinDisplacementAtr = 0.85;
         params.lqStopBufferAtr = 0.22;
         params.lqTpR = 1.10;
         params.lqRetestMaxAgeBars = 4;
         params.lqRetestTolAtr = 0.07;
         params.lqAllowStopFallback = true;

         params.shieldSpreadMaLen = 28;
         params.shieldSpreadSpikeMult = 1.55;
         params.shieldMaxSpreadPoints = 22;
         params.shieldAtrShockMult = 1.80;
         params.shieldCandleShockMult = 2.00;
         params.shieldCooldownBars = 7;
         params.shieldSlippageLimitPoints = 8;
         break;

      default:
         break;
   }
}

void ConfigureParams()
{
   ZeroMemory(P);
   const ENUM_TIMEFRAMES chartTf = (ENUM_TIMEFRAMES)_Period;
   P.tf = ResolveSelectedTimeframe();

   P.lookback = InpLookback;
   P.atrPeriod = InpAtrPeriod;
   P.atrMaLen = InpAtrMaLen;
   P.atrFilterMult = InpAtrFilterMult;
   P.pascalLenPrice = InpPascalLenPrice;
   P.pascalLenATR = InpPascalLenATR;

   P.useFibo = InpUseFibo;
   P.swingLookback = InpSwingLookback;
   P.fibo1 = InpFibo1;
   P.fibo2 = InpFibo2;
   P.fibo3 = InpFibo3;
   P.fiboTolAtr = InpFiboTolAtr;
   P.fiboMaxBarsToTrigger = InpFiboMaxBarsToTrigger;

   P.useHurst = InpUseHurst;
   P.hurstMin = InpHurstMin;
   P.useEntropy = InpUseEntropy;
   P.entropyLen = InpEntropyLen;
   P.entropyMax = InpEntropyMax;
   P.useAutocorr = InpUseAutocorr;
   P.autocorrLen = InpAutocorrLen;
   P.autocorrMinAbs = InpAutocorrMinAbs;

   P.useProbRiskAdjust = InpUseProbRiskAdjust;
   P.winrateLen = InpWinrateLen;
   P.seqLossProbMax = InpSeqLossProbMax;
   P.minRiskFactor = InpMinRiskFactor;

   P.stopAtrMult = InpStopAtrMult;
   P.useTakeProfit = InpUseTakeProfit;
   P.tpAtrMult = InpTpAtrMult;
   P.useBreakEven = InpUseBreakEven;
   P.breakEvenAtrTrigger = InpBreakEvenAtrTrigger;
   P.breakEvenOffsetPoints = InpBreakEvenOffsetPoints;
   P.trailStartAtr = InpTrailStartAtr;
   P.trailAtrMult = InpTrailAtrMult;

   P.minTrendStrengthAtr = InpMinTrendStrengthAtr;
   P.breakoutBodyAtrMin = InpBreakoutBodyAtrMin;
   P.breakoutCloseStrengthMin = InpBreakoutCloseStrengthMin;
   P.maxSpreadAtrFrac = InpMaxSpreadAtrFrac;

   P.riskPct = InpRiskPct;
   P.maxTradesPerDay = InpMaxTradesPerDay;
   P.maxConsecLosses = InpMaxConsecLosses;
   P.maxDailyDDPct = InpMaxDailyDDPct;

   P.useSessionFilter = InpUseSessionFilter;
   P.tradeStartHour = InpTradeStartHour;
   P.tradeEndHour = InpTradeEndHour;
   P.slippagePoints = InpSlippagePoints;
   P.maxDeviationPoints = InpMaxDeviationPoints;
   P.onePosPerSymbol = InpOnePosPerSymbol;
   P.useDynamicSpreadGate = InpUseDynamicSpreadGate;
   P.spreadMedianLen = InpSpreadMedianLen;
   P.spreadMedianMult = InpSpreadMedianMult;
   P.stopSpreadBufferMult = InpStopSpreadBufferMult;
   P.useTwoStepExecutionFallback = InpUseTwoStepExecutionFallback;

   P.lqSwingLookback = InpLqSwingLookback;
   P.lqSweepBufferAtr = InpLqSweepBufferAtr;
   P.lqSweepMaxAgeBars = InpLqSweepMaxAgeBars;
   P.lqMinDisplacementAtr = InpLqMinDisplacementAtr;
   P.lqMssLookback = InpLqMssLookback;
   P.lqStopBufferAtr = InpLqStopBufferAtr;
   P.lqTpR = InpLqTpR;
   P.lqEntryMode = (int)InpLqEntryMode;
   P.lqRetestMaxAgeBars = InpLqRetestMaxAgeBars;
   P.lqRetestTolAtr = InpLqRetestTolAtr;
   P.lqAllowStopFallback = InpLqAllowStopFallback;
   P.lqUseStructuralTrail = InpLqUseStructuralTrail;
   P.lqStructuralTrailAtr = InpLqStructuralTrailAtr;

   P.shieldSpreadMaLen = InpShieldSpreadMaLen;
   P.shieldSpreadSpikeMult = InpShieldSpreadSpikeMult;
   P.shieldMaxSpreadPoints = InpShieldMaxSpreadPoints;
   P.shieldAtrShockMult = InpShieldAtrShockMult;
   P.shieldCandleShockMult = InpShieldCandleShockMult;
   P.shieldCooldownBars = InpShieldCooldownBars;
   P.shieldSlippageLimitPoints = InpShieldSlippageLimitPoints;

   P.useAtrRegimeGate = InpUseAtrRegimeGate;
   P.regimeAtrMaLen = InpRegimeAtrMaLen;
   P.regimeAtrMult = InpRegimeAtrMult;

   P.useAutoPause = InpUseAutoPause;
   P.autoPauseWindowTrades = InpAutoPauseWindowTrades;
   P.autoPausePfStop = InpAutoPausePfStop;
   P.autoPauseDdStopPct = InpAutoPauseDdStopPct;
   P.autoPauseHours = InpAutoPauseHours;
   P.autoPausePfResume = InpAutoPausePfResume;

   P.useRiskLadder = InpUseRiskLadder;
   P.riskLadderWindowTrades = InpRiskLadderWindowTrades;
   P.riskLadderLowPf = InpRiskLadderLowPf;
   P.riskLadderMidPf = InpRiskLadderMidPf;
   P.riskLadderHighPf = InpRiskLadderHighPf;
   P.riskLadderMidWinrate = InpRiskLadderMidWinrate;
   P.riskLadderHighWinrate = InpRiskLadderHighWinrate;
   P.riskLadderHighDdMaxPct = InpRiskLadderHighDdMaxPct;
   P.riskLadderLowScale = InpRiskLadderLowScale;
   P.riskLadderMidScale = InpRiskLadderMidScale;
   P.riskLadderHighScale = InpRiskLadderHighScale;
   P.riskLadderMaxScale = InpRiskLadderMaxScale;

   if(g_useProfilePreset)
   {
      if(Profile == Safe)
      {
         P.riskPct = 0.35;
         P.maxTradesPerDay = 25;
         P.maxConsecLosses = 4;
         P.maxDailyDDPct = 1.8;
         P.atrPeriod = 10;
         P.atrMaLen = 24;
         P.atrFilterMult = 0.95;
         P.lookback = 8;
         P.pascalLenPrice = 4;
         P.pascalLenATR = 4;
         P.stopAtrMult = 0.90;
         P.useTakeProfit = true;
         P.tpAtrMult = 1.25;
         P.useBreakEven = true;
         P.breakEvenAtrTrigger = 0.45;
         P.breakEvenOffsetPoints = 4;
         P.trailStartAtr = 0.60;
         P.trailAtrMult = 1.10;
         P.useSessionFilter = true;
         P.tradeStartHour = 6;
         P.tradeEndHour = 22;
         P.onePosPerSymbol = true;
         P.maxDeviationPoints = 8;

         P.minTrendStrengthAtr = 0.035;
         P.breakoutBodyAtrMin = 0.11;
         P.breakoutCloseStrengthMin = 0.53;
         P.maxSpreadAtrFrac = 0.15;

         P.swingLookback = 12;
         P.fiboTolAtr = 0.10;
         P.fiboMaxBarsToTrigger = 4;
         P.winrateLen = 24;
         P.seqLossProbMax = 0.35;
         P.minRiskFactor = 0.50;

         P.hurstMin = 0.53;
         P.autocorrLen = 48;
         P.autocorrMinAbs = 0.10;
         P.entropyLen = 64;
         P.entropyMax = 0.85;

         P.lqSwingLookback = 24;
         P.lqSweepBufferAtr = 0.09;
         P.lqSweepMaxAgeBars = 7;
         P.lqMinDisplacementAtr = 0.80;
         P.lqMssLookback = 6;
         P.lqStopBufferAtr = 0.22;
         P.lqTpR = 1.10;
         P.lqEntryMode = HYBRID;
         P.lqRetestMaxAgeBars = 5;
         P.lqRetestTolAtr = 0.07;
         P.lqAllowStopFallback = false;
         P.lqUseStructuralTrail = true;
         P.lqStructuralTrailAtr = 0.40;

         P.shieldSpreadMaLen = 24;
         P.shieldSpreadSpikeMult = 1.55;
         P.shieldMaxSpreadPoints = 24;
         P.shieldAtrShockMult = 1.80;
         P.shieldCandleShockMult = 2.10;
         P.shieldCooldownBars = 7;
         P.shieldSlippageLimitPoints = 8;
      }
      else
      {
         P.riskPct = 0.75;
         if(P.riskPct > 1.25)
            P.riskPct = 1.25;
         P.maxTradesPerDay = 40;
         P.maxConsecLosses = 5;
         P.maxDailyDDPct = 3.5;
         P.atrPeriod = 8;
         P.atrMaLen = 20;
         P.atrFilterMult = 0.90;
         P.lookback = 6;
         P.pascalLenPrice = 4;
         P.pascalLenATR = 4;
         P.stopAtrMult = 0.75;
         P.useTakeProfit = true;
         P.tpAtrMult = 1.05;
         P.useBreakEven = true;
         P.breakEvenAtrTrigger = 0.35;
         P.breakEvenOffsetPoints = 3;
         P.trailStartAtr = 0.45;
         P.trailAtrMult = 0.95;
         P.useSessionFilter = true;
         P.tradeStartHour = 5;
         P.tradeEndHour = 23;
         P.onePosPerSymbol = true;
         P.maxDeviationPoints = 14;

         P.minTrendStrengthAtr = 0.03;
         P.breakoutBodyAtrMin = 0.09;
         P.breakoutCloseStrengthMin = 0.51;
         P.maxSpreadAtrFrac = 0.18;

         P.swingLookback = 10;
         P.fiboTolAtr = 0.12;
         P.fiboMaxBarsToTrigger = 3;
         P.winrateLen = 18;
         P.seqLossProbMax = 0.45;
         P.minRiskFactor = 0.55;

         P.hurstMin = 0.51;
         P.autocorrLen = 40;
         P.autocorrMinAbs = 0.10;
         P.entropyLen = 56;
         P.entropyMax = 0.85;

         P.lqSwingLookback = 18;
         P.lqSweepBufferAtr = 0.12;
         P.lqSweepMaxAgeBars = 5;
         P.lqMinDisplacementAtr = 0.65;
         P.lqMssLookback = 4;
         P.lqStopBufferAtr = 0.18;
         P.lqTpR = 1.25;
         P.lqEntryMode = MARKET_ON_MSS;
         P.lqRetestMaxAgeBars = 3;
         P.lqRetestTolAtr = 0.10;
         P.lqAllowStopFallback = true;
         P.lqUseStructuralTrail = true;
         P.lqStructuralTrailAtr = 0.50;

         P.shieldSpreadMaLen = 18;
         P.shieldSpreadSpikeMult = 2.00;
         P.shieldMaxSpreadPoints = 40;
         P.shieldAtrShockMult = 2.30;
         P.shieldCandleShockMult = 2.80;
         P.shieldCooldownBars = 3;
         P.shieldSlippageLimitPoints = 14;
      }
   }

   if(InpConfigTemplate != CFG_MANUAL)
      ApplyConfigTemplatePreset(P, InpConfigTemplate);

   if(P.tf != chartTf)
   {
      PrintFormat("Scalping timeframe clamp | chart=%s(%d) -> operacional=%s(%d)",
                  EnumToString(chartTf),
                  (int)chartTf,
                  EnumToString(P.tf),
                  (int)P.tf);
   }

   if(InpTradingMode == TM_LIQUIDITY)
   {
      Mode = LiquidityScalp;
      g_adaptiveEnabled = false;
      g_lqEnabled = true;
      Profile = Safe;
   }
   else
   {
      Mode = Adaptive;
      g_adaptiveEnabled = true;
      g_lqEnabled = false;
      Profile = ProfileFromRegime(RegimeBase);
   }

   StrategyMode baseMode = Mode;
   if(baseMode == Adaptive)
      baseMode = Pullback;

   if(InpModeForceModules)
      ApplyStrategyModeToParams(P, baseMode);
   g_runtimeMode = baseMode;
}

void LogConfig()
{
   PrintFormat("AplexFlow Engine | PROFILE=%s | TradingModeUI=%s | MODE=%s | runtimeMode=%s",
               RiskProfileToString(Profile),
               TradingModeUIToString(InpTradingMode),
               StrategyModeToString(Mode),
               StrategyModeToString(g_runtimeMode));
   PrintFormat("Controle de inputs | configTemplate=%s | modeForceModules=%s | tfSource=%s | clampM15=%s | spreadFilter=%s | lqEnabled=%s | adaptiveEnabled=%s",
               ConfigTemplateToString(InpConfigTemplate),
               (InpModeForceModules ? "ON" : "OFF"),
               (InpUseChartTimeframe ? "chart" : "manual"),
               (InpClampTimeframeToM15 ? "ON" : "OFF"),
               (InpUseSpreadFilter ? "ON" : "OFF"),
               (g_lqEnabled ? "ON" : "OFF"),
               (g_adaptiveEnabled ? "ON" : "OFF"));
   Print("Perfil operacional: SCALPING");

   PrintFormat("Timeframe detectado | chart=%s(%d) | operacional=%s(%d)",
               EnumToString((ENUM_TIMEFRAMES)_Period),
               (int)_Period,
               EnumToString(P.tf),
               (int)P.tf);

   if(Mode == Adaptive)
      Print("Modo Adaptive ativo: o EA alterna automaticamente entre Core/Pullback/Quantum/Defensive conforme regime.");
   if(Mode == LiquidityScalp)
      Print("Modo LiquidityScalp ativo: pipeline SWING -> SWEEP -> DISPLACEMENT -> MSS -> ENTRY.");

   PrintFormat("Modulos ativos | Fibo=%s | Hurst=%s | Entropy=%s | Autocorr=%s | ProbRisk=%s",
               (P.useFibo ? "ON" : "OFF"),
               (P.useHurst ? "ON" : "OFF"),
               (P.useEntropy ? "ON" : "OFF"),
               (P.useAutocorr ? "ON" : "OFF"),
               (P.useProbRiskAdjust ? "ON" : "OFF"));

   PrintFormat("Risk profile interno | TF=%d | riskPct=%.2f | maxTrades/day=%d | maxConsecLosses=%d | maxDailyDD=%.2f%%",
               (int)P.tf, P.riskPct, P.maxTradesPerDay, P.maxConsecLosses, P.maxDailyDDPct);

   PrintFormat("Execucao | TP=%s(%.2f ATR) | BreakEven=%s(%.2f ATR, %d pts) | Trail start=%.2f ATR, dist=%.2f ATR | deviation=%d pts | dynSpread=%s(len=%d,mult=%.2f) | stopSpreadBuf=%.2f | 2step=%s",
               (P.useTakeProfit ? "ON" : "OFF"),
               P.tpAtrMult,
               (P.useBreakEven ? "ON" : "OFF"),
               P.breakEvenAtrTrigger,
               P.breakEvenOffsetPoints,
               P.trailStartAtr,
               P.trailAtrMult,
               P.maxDeviationPoints,
               (P.useDynamicSpreadGate ? "ON" : "OFF"),
               P.spreadMedianLen,
               P.spreadMedianMult,
               P.stopSpreadBufferMult,
               (P.useTwoStepExecutionFallback ? "ON" : "OFF"));

   PrintFormat("Filtros de qualidade | minSlope=%.3f ATR | bodyBreakout=%.3f ATR | closeStrength=%.2f | maxSpread=%.2f ATR",
               P.minTrendStrengthAtr,
               P.breakoutBodyAtrMin,
               P.breakoutCloseStrengthMin,
               P.maxSpreadAtrFrac);

   PrintFormat("Adaptive interno | confirmadoEm=%d barras | minIntervalo=%d barras | maxTrocasDia=%d | minAmostras=%d | fallbackDD=%.2f",
               InpAdaptConfirmBars,
               InpAdaptMinBarsBetweenChanges,
               InpAdaptMaxChangesPerDay,
               InpAdaptMinOutcomeSamples,
               InpAdaptFallbackDdFrac);

   PrintFormat("LiquidityScalp interno | swingLb=%d | sweepBuffer=%.2f ATR | sweepMaxAge=%d | minDisp=%.2f ATR | mssLb=%d | stopBuffer=%.2f ATR | tpR=%.2f | entryMode=%d | stopFallback=%s",
               P.lqSwingLookback,
               P.lqSweepBufferAtr,
               P.lqSweepMaxAgeBars,
               P.lqMinDisplacementAtr,
               P.lqMssLookback,
               P.lqStopBufferAtr,
               P.lqTpR,
               P.lqEntryMode,
               (P.lqAllowStopFallback ? "ON" : "OFF"));

   PrintFormat("Shield interno | mode=%s | spreadMA=%d | spikeMult=%.2f | maxSpreadPts=%d | atrShock=%.2f | candleShock=%.2f | cooldownBars=%d | maxSlippagePts=%d",
               ShieldModeToString(Shield),
               P.shieldSpreadMaLen,
               P.shieldSpreadSpikeMult,
               P.shieldMaxSpreadPoints,
               P.shieldAtrShockMult,
               P.shieldCandleShockMult,
               P.shieldCooldownBars,
               P.shieldSlippageLimitPoints);

   PrintFormat("Regime gate | ATRGate=%s | atrMaLen=%d | atrMult=%.2f | autoPause=%s(window=%d,pfStop=%.2f,ddStop=%.2f%%,hours=%d,pfResume=%.2f)",
               (P.useAtrRegimeGate ? "ON" : "OFF"),
               P.regimeAtrMaLen,
               P.regimeAtrMult,
               (P.useAutoPause ? "ON" : "OFF"),
               P.autoPauseWindowTrades,
               P.autoPausePfStop,
               P.autoPauseDdStopPct,
               P.autoPauseHours,
               P.autoPausePfResume);
   PrintFormat("Risk ladder | enabled=%s | window=%d | lowPf=%.2f midPf=%.2f highPf=%.2f | scales=%.2f/%.2f/%.2f | maxScale=%.2f",
               (P.useRiskLadder ? "ON" : "OFF"),
               P.riskLadderWindowTrades,
               P.riskLadderLowPf,
               P.riskLadderMidPf,
               P.riskLadderHighPf,
               P.riskLadderLowScale,
               P.riskLadderMidScale,
               P.riskLadderHighScale,
               P.riskLadderMaxScale);
   PrintFormat("Execution profile dinamico | ativo=%s | current=%s | confirmBars=3 | lockBars=6",
               (IsXauUsdM5ManagedTemplate(InpConfigTemplate) ? "ON" : "OFF"),
               ExecProfileToString(g_execProfile));
   if(IsLive247LiquidityTemplate())
      PrintFormat("Live247 overlay | current=%s | confirmBars=2 | lockBars=8",
                  Live247ProfileToString(g_live247Profile));
}

void LogSymbolExecutionSpec()
{
   const int digits = (int)SymbolInfoInteger(_Symbol, SYMBOL_DIGITS);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const long stopLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const long freezeLevelPts = SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double spreadPts = CurrentSpreadPoints();
   const double spreadPrice = CurrentSpreadPrice();
   const double minProtectPrice = ComputeMinProtectionDistancePrice();
   const double minProtectPts = PriceDistanceToPoints(minProtectPrice);

   LogAndPersist(StringFormat("[SYMBOL_SPEC] symbol=%s | digits=%d | point=%.5f | tickSize=%.5f | stopLevel=%d pts | freezeLevel=%d pts | spreadNow=%.1f pts (%.5f) | stopSpreadBuf=%.2f | minProtect=%.1f pts",
                              _Symbol,
                              digits,
                              point,
                              tickSize,
                              (int)stopLevelPts,
                              (int)freezeLevelPts,
                              spreadPts,
                              spreadPrice,
                              P.stopSpreadBufferMult,
                              minProtectPts));
}

void ResetTelemetryForDay(const datetime anchor)
{
   ZeroMemory(g_tel);
   g_tel.dayAnchor = anchor;
}

void PrintDailyTelemetry(const string reason)
{
   if(g_tel.dayAnchor <= 0)
      return;

   const int closed = g_tel.tradesClosedToday;
   const double winrate = (closed > 0 ? (100.0 * (double)g_tel.winsToday / (double)closed) : 0.0);
   const double convSweepDisp = (g_tel.lqSweeps > 0 ? (100.0 * (double)g_tel.lqDisplacements / (double)g_tel.lqSweeps) : 0.0);
   const double convDispMss = (g_tel.lqDisplacements > 0 ? (100.0 * (double)g_tel.lqMSS / (double)g_tel.lqDisplacements) : 0.0);
   const double convMssTrade = (g_tel.lqMSS > 0 ? (100.0 * (double)g_tel.tradesOpenedToday / (double)g_tel.lqMSS) : 0.0);
   const int totalBlocks = g_tel.shieldBlocksSpread
                         + g_tel.shieldBlocksATR
                         + g_tel.shieldBlocksCandle
                         + g_tel.shieldBlocksSlippage
                         + g_tel.regimeBlocks
                         + g_tel.autoPauseBlocks
                         + g_tel.killSwitchBlocks;

   string topBlocker = "none";
   int topCount = 0;
   if(g_tel.shieldBlocksSpread > topCount) { topCount = g_tel.shieldBlocksSpread; topBlocker = "spread"; }
   if(g_tel.shieldBlocksATR > topCount) { topCount = g_tel.shieldBlocksATR; topBlocker = "atr"; }
   if(g_tel.shieldBlocksCandle > topCount) { topCount = g_tel.shieldBlocksCandle; topBlocker = "candle"; }
   if(g_tel.shieldBlocksSlippage > topCount) { topCount = g_tel.shieldBlocksSlippage; topBlocker = "slippage"; }
   if(g_tel.regimeBlocks > topCount) { topCount = g_tel.regimeBlocks; topBlocker = "regime"; }
   if(g_tel.autoPauseBlocks > topCount) { topCount = g_tel.autoPauseBlocks; topBlocker = "autopause"; }
   if(g_tel.killSwitchBlocks > topCount) { topCount = g_tel.killSwitchBlocks; topBlocker = "kill"; }

   const string telSummary = StringFormat("[TEL] reason=%s | day=%s | opened=%d | closed=%d | wins=%d | losses=%d | winrate=%.2f%% | net=%.2f | grossProfit=%.2f | grossLoss=%.2f",
                                          reason,
                                          TimeToString(g_tel.dayAnchor, TIME_DATE),
                                          g_tel.tradesOpenedToday,
                                          g_tel.tradesClosedToday,
                                          g_tel.winsToday,
                                          g_tel.lossesToday,
                                          winrate,
                                          g_tel.netToday,
                                          g_tel.grossProfitToday,
                                          g_tel.grossLossToday);
   LogAndPersist(telSummary);

   const string telLq = StringFormat("[TEL] lq | signals=%d | sweeps=%d | disp=%d | mss=%d | pendingPlaced=%d | pendingExpired=%d | hybridFallbackMkt=%d | convSweepDisp=%.2f%% | convDispMss=%.2f%% | convMssTrade=%.2f%%",
                                     g_tel.lqSignalsFound,
                                     g_tel.lqSweeps,
                                     g_tel.lqDisplacements,
                                     g_tel.lqMSS,
                                     g_tel.lqPendingsPlaced,
                                     g_tel.lqPendingsExpired,
                                     g_tel.lqHybridFallbackMarket,
                                     convSweepDisp,
                                     convDispMss,
                                     convMssTrade);
   LogAndPersist(telLq);

   const string telShield = StringFormat("[TEL] shield | spread=%d | atr=%d | candle=%d | slippage=%d | regime=%d | autoPauseBlocks=%d | autoPauseTriggers=%d",
                                         g_tel.shieldBlocksSpread,
                                         g_tel.shieldBlocksATR,
                                         g_tel.shieldBlocksCandle,
                                         g_tel.shieldBlocksSlippage,
                                         g_tel.regimeBlocks,
                                         g_tel.autoPauseBlocks,
                                         g_tel.autoPauseTriggers);
   LogAndPersist(telShield);

   double perfPf = 1.0;
   double perfWr = 0.50;
   double perfDd = 0.0;
   int perfSamples = 0;
   const int perfWindow = MathMax(MathMax(5, P.autoPauseWindowTrades), MathMax(5, P.riskLadderWindowTrades));
   const bool perfOk = ComputeRecentPerformance(perfWindow, perfPf, perfWr, perfDd, perfSamples);
   const string telPerf = StringFormat("[TEL] perf | window=%d | samples=%d | pf=%.2f | winrate=%.2f%% | ddLocal=%.2f%% | autoPauseActive=%s",
                                       perfWindow,
                                       perfSamples,
                                       perfPf,
                                       perfWr * 100.0,
                                       perfDd,
                                       (g_autoPauseUntil > CurrentTimeSafe() ? "true" : "false"));
   if(perfOk)
      LogAndPersist(telPerf);
   else
      LogAndPersist("[TEL] perf | sem amostra suficiente para estatistica recente.");

   const string killAt = (g_tel.killSwitchTriggeredAt > 0
                          ? TimeToString(g_tel.killSwitchTriggeredAt, TIME_DATE | TIME_MINUTES | TIME_SECONDS)
                          : "-");
   const string autoPauseUntil = (g_autoPauseUntil > 0
                                  ? TimeToString(g_autoPauseUntil, TIME_DATE | TIME_MINUTES)
                                  : "-");
   const string telBlocks = StringFormat("[TEL] blocks | total=%d | killSwitchTriggered=%s | killAt=%s | killBlocks=%d | autoPauseUntil=%s | autoPauseTriggers=%d | top=%s(%d)",
                                         totalBlocks,
                                         (g_tel.killSwitchTriggered ? "true" : "false"),
                                         killAt,
                                         g_tel.killSwitchBlocks,
                                         autoPauseUntil,
                                         g_tel.autoPauseTriggers,
                                         topBlocker,
                                         topCount);
   LogAndPersist(telBlocks);
}

void ResetPullbackSetup(const string reason)
{
   if(g_setup.active)
      PrintFormat("Setup Fibonacci cancelado: %s", reason);

   ZeroMemory(g_setup);
}

void ResetDailyCounters(const bool force)
{
   datetime now = TimeCurrent();
   if(now <= 0)
      now = TimeTradeServer();
   if(now <= 0)
      now = TimeLocal();

   const int key = BuildDayKey(now);
   if(!force && key == g_dayKey)
      return;

   if(!force && g_dayKey != 0 && g_tel.dayAnchor > 0)
      PrintDailyTelemetry("day rollover");

   g_dayKey = key;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(g_dayStartEquity <= 0.0)
      g_dayStartEquity = AccountInfoDouble(ACCOUNT_BALANCE);
   g_tradesToday = 0;
   g_consecLosses = 0;
   g_killSwitch = false;
   g_adaptChangesToday = 0;
   g_candidateRegimeBars = 0;
   g_candidateRegime = RegimeBase;
   g_activeRegime = RegimeBase;
   g_lastRegimeChangeBar = 0;
   g_shieldBlockedUntil = 0;
   g_lastExecSlippagePoints = 0.0;
   g_execProfile = EP_NORMAL;
   g_execProfileLockBars = 0;
   g_execProfileNormConfirm = 0;
   g_execProfileAggrConfirm = 0;
   g_execProfileDefConfirm = 0;
   g_live247ScaleInsToday = 0;
   P = g_baseParams;
   g_runtimeMode = (Mode == Adaptive ? Pullback : Mode);
   if(InpModeForceModules)
      ApplyStrategyModeToParams(P, g_runtimeMode);
   ZeroMemory(g_lq);
   g_lq.state = LQ_IDLE;
   ZeroMemory(g_fusion);
   ZeroMemory(g_microBurst);
   ResetTelemetryForDay(now);
   ResetBlockLogThrottleState();

   if(P.useFibo)
      ResetPullbackSetup("Novo dia de trading");

   PrintFormat("Reset diario realizado | dayKey=%d | equity inicial=%.2f",
               g_dayKey, g_dayStartEquity);
}

void UpdateDailyKillSwitch()
{
   if(g_killSwitch || g_dayStartEquity <= 0.0)
      return;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0.0)
      return;

   const double ddRaw = ((g_dayStartEquity - equity) / g_dayStartEquity) * 100.0;
   const double ddPct = MathMax(0.0, ddRaw);
   const double eps = 1e-6;

   if(ddPct > (P.maxDailyDDPct + eps))
   {
      g_killSwitch = true;
      g_tel.killSwitchTriggered = true;
      g_tel.killSwitchTriggeredAt = CurrentTimeSafe();
      LogAndPersist(StringFormat("Kill switch acionado | DD diario=%.2f%% > limite %.2f%%",
                                 ddPct,
                                 P.maxDailyDDPct));

      if(P.useFibo)
         ResetPullbackSetup("Kill switch diario");

      if(Mode == LiquidityScalp || g_runtimeMode == LiquidityScalp)
      {
         HardResetLiquidity("Kill switch diario");
      }
   }
}

bool IsNewBar()
{
   const datetime currentBar = iTime(_Symbol, P.tf, 0);
   if(currentBar <= 0)
      return false;

   if(currentBar != g_lastBarTime)
   {
      g_lastBarTime = currentBar;
      return true;
   }
   return false;
}

bool IsInSession()
{
   if(!P.useSessionFilter)
      return true;

   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();

   MqlDateTime dt;
   TimeToStruct(now, dt);
   const int h = dt.hour;

   if(P.tradeStartHour == P.tradeEndHour)
      return true;

   if(P.tradeStartHour < P.tradeEndHour)
      return (h >= P.tradeStartHour && h < P.tradeEndHour);

   return (h >= P.tradeStartHour || h < P.tradeEndHour);
}

double CurrentSpreadPrice()
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0 || ask < bid)
      return 0.0;
   return (ask - bid);
}

bool IsSpreadAcceptable(const double atr)
{
   if(!InpUseSpreadFilter)
      return true;

   if(P.maxSpreadAtrFrac <= 0.0)
      return true;
   if(atr <= 0.0)
   {
      LogBlockThrottled("Bloqueio: ATR invalido para avaliacao de spread.");
      return false;
   }

   const double spread = CurrentSpreadPrice();
   if(spread <= 0.0)
   {
      g_tel.shieldBlocksSpread++;
      LogBlockThrottled("Bloqueio: spread invalido.");
      return false;
   }

   const double maxSpread = atr * P.maxSpreadAtrFrac;
   if(spread > maxSpread)
   {
      g_tel.shieldBlocksSpread++;
      LogBlockThrottled("Bloqueio: spread alto",
                        StringFormat("spread=%.5f | max=%.5f", spread, maxSpread));
      return false;
   }

   if(P.useDynamicSpreadGate)
   {
      const double spreadPoints = CurrentSpreadPoints();
      const double medianPoints = SpreadMedianPoints(P.spreadMedianLen, 1);
      const double mult = MathMax(1.0, P.spreadMedianMult);
      const double limitPoints = medianPoints * mult;
      if(spreadPoints > limitPoints)
      {
         g_tel.shieldBlocksSpread++;
         LogBlockThrottled("Bloqueio: spread dinamico alto",
                           StringFormat("spread=%.1f pts | median=%.1f pts | mult=%.2f | limit=%.1f pts",
                                        spreadPoints,
                                        medianPoints,
                                        mult,
                                        limitPoints));
         return false;
      }
   }

   return true;
}

double CurrentSpreadPoints()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   return (CurrentSpreadPrice() / point);
}

double PriceDistanceToPoints(const double distancePrice)
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;
   return (distancePrice / point);
}

double SpreadMAPoints(const int len, const int startShift)
{
   const int useLen = MathMax(1, len);
   int count = 0;
   double acc = 0.0;

   for(int i = startShift; i < startShift + useLen; i++)
   {
      const long sp = iSpread(_Symbol, P.tf, i);
      if(sp < 0)
         continue;
      acc += (double)sp;
      count++;
   }

   if(count <= 0)
      return CurrentSpreadPoints();

   return (acc / (double)count);
}

double SpreadMedianPoints(const int len, const int startShift)
{
   const int useLen = MathMax(5, len);
   double values[];
   ArrayResize(values, useLen);

   int count = 0;
   for(int i = startShift; i < startShift + useLen; i++)
   {
      const long sp = iSpread(_Symbol, P.tf, i);
      if(sp < 0)
         continue;
      values[count] = (double)sp;
      count++;
   }

   if(count <= 0)
      return CurrentSpreadPoints();

   ArrayResize(values, count);
   ArraySort(values);

   if((count % 2) == 1)
      return values[count / 2];

   const int hi = count / 2;
   const int lo = hi - 1;
   return ((values[lo] + values[hi]) * 0.5);
}

int CooldownBarsRemaining(const datetime blockedUntil)
{
   if(blockedUntil <= 0)
      return 0;

   datetime now = TimeCurrent();
   if(now >= blockedUntil)
      return 0;

   const int sec = PeriodSeconds(P.tf);
   if(sec <= 0)
      return 1;

   return (int)MathCeil((double)(blockedUntil - now) / (double)sec);
}

void ActivateShieldCooldown(const string reason, const int barsToBlock)
{
   const int bars = MathMax(1, barsToBlock);
   const int sec = PeriodSeconds(P.tf);
   datetime now = TimeCurrent();
   if(now <= 0)
      now = TimeTradeServer();
   if(now <= 0)
      now = TimeLocal();

   const datetime until = now + ((sec > 0 ? sec : 60) * bars);
   if(until > g_shieldBlockedUntil)
      g_shieldBlockedUntil = until;
}

bool ExecutionShieldAllowsEntry(const double atr, const double pascalAtr, string &reason)
{
   reason = "";
   if(Shield != SHIELD_ON)
      return true;

   datetime now = TimeCurrent();
   if(now <= 0)
      now = TimeTradeServer();

   if(g_shieldBlockedUntil > now)
   {
      reason = StringFormat("cooldown ativo (%d bars restantes)", CooldownBarsRemaining(g_shieldBlockedUntil));
      LogBlockThrottled("[SHIELD_BLOCK] cooldown", reason);
      return false;
   }

   const double spreadNow = CurrentSpreadPoints();
   const double spreadMA = SpreadMAPoints(P.shieldSpreadMaLen, 1);
   if(spreadMA > 0.0 && spreadNow > spreadMA * P.shieldSpreadSpikeMult)
   {
      g_tel.shieldBlocksSpread++;
      reason = StringFormat("spread spike | atual=%.1f | ma=%.1f | mult=%.2f",
                            spreadNow, spreadMA, P.shieldSpreadSpikeMult);
      LogBlockThrottled("[SHIELD_BLOCK] spread spike", reason);
      ActivateShieldCooldown(reason, P.shieldCooldownBars);
      return false;
   }

   if(P.shieldMaxSpreadPoints > 0 && spreadNow > (double)P.shieldMaxSpreadPoints)
   {
      g_tel.shieldBlocksSpread++;
      reason = StringFormat("spread absoluto alto | atual=%.1f | max=%d",
                            spreadNow, P.shieldMaxSpreadPoints);
      LogBlockThrottled("[SHIELD_BLOCK] spread max", reason);
      ActivateShieldCooldown(reason, P.shieldCooldownBars);
      return false;
   }

   if(atr > 0.0 && pascalAtr > 0.0 && atr > (pascalAtr * P.shieldAtrShockMult))
   {
      g_tel.shieldBlocksATR++;
      reason = StringFormat("ATR shock | ATR=%.5f | ATR_MA=%.5f | mult=%.2f",
                            atr, pascalAtr, P.shieldAtrShockMult);
      LogBlockThrottled("[SHIELD_BLOCK] atr shock", reason);
      ActivateShieldCooldown(reason, P.shieldCooldownBars);
      return false;
   }

   const double barRange = iHigh(_Symbol, P.tf, 1) - iLow(_Symbol, P.tf, 1);
   if(atr > 0.0 && barRange > (atr * P.shieldCandleShockMult))
   {
      g_tel.shieldBlocksCandle++;
      reason = StringFormat("candle shock | range=%.5f | limite=%.5f",
                            barRange, atr * P.shieldCandleShockMult);
      LogBlockThrottled("[SHIELD_BLOCK] candle shock", reason);
      ActivateShieldCooldown(reason, P.shieldCooldownBars);
      return false;
   }

   if(P.shieldSlippageLimitPoints > 0 && g_lastExecSlippagePoints > (double)P.shieldSlippageLimitPoints)
   {
      g_tel.shieldBlocksSlippage++;
      reason = StringFormat("slippage alto na ultima execucao | slippage=%.1f pts | limite=%d pts",
                            g_lastExecSlippagePoints, P.shieldSlippageLimitPoints);
      LogBlockThrottled("[SHIELD_BLOCK] slippage", reason);
      ActivateShieldCooldown(reason, P.shieldCooldownBars);
      g_lastExecSlippagePoints = 0.0;
      return false;
   }

   return true;
}

void HardResetLiquidity(const string reason)
{
   if(g_lq.hasPending && g_lq.pendingTicket > 0)
   {
      if(IsLiquidityPendingOrderTicket(g_lq.pendingTicket))
      {
         const bool deleted = g_trade.OrderDelete(g_lq.pendingTicket);
         DebugLog(DBG_SIGNALS,
                  StringFormat("[LQ_PENDING] cleanup on reset | ticket=%I64u | deleted=%s | retcode=%d | msg=%s",
                               g_lq.pendingTicket,
                               (deleted ? "true" : "false"),
                               g_trade.ResultRetcode(),
                               g_trade.ResultRetcodeDescription()));
      }
      else
      {
         DebugLog(DBG_SIGNALS,
                  StringFormat("[LQ_PENDING] cleanup skipped (nao elegivel) | ticket=%I64u",
                               g_lq.pendingTicket));
      }
   }

   if(g_lq.valid || g_lq.hasPending || IsDebugAtLeast(DBG_VERBOSE))
      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_RESET] state=%s | reason=%s", LqStateToString(g_lq.state), reason));

   ZeroMemory(g_lq);
   g_lq.state = LQ_IDLE;
}

void ClearLiquidityPendingState()
{
   g_lq.pendingTicket = 0;
   g_lq.pendingBarsElapsed = 0;
   g_lq.pendingPrice = 0.0;
   g_lq.hasPending = false;
}

void MarkLiquidityEntryOnCurrentBar()
{
   datetime barTime = iTime(_Symbol, P.tf, 0);
   if(barTime <= 0)
      barTime = g_lastBarTime;
   if(barTime <= 0)
      barTime = TimeCurrent();

   g_lq.lastEntryBarTime = barTime;
}

double ComputeEffectiveRiskPct(const double softRiskMult, double &winrate, double &seqLossProb, double &factor)
{
   winrate = 0.0;
   seqLossProb = 0.0;
   factor = RiskFactorFromProbability(winrate, seqLossProb);

   const double baseRisk = P.riskPct;
   const double softMult = ClampValue(softRiskMult, 0.25, 1.50);
   double perfPf = 1.0, perfWr = 0.50, perfDdPct = 0.0;
   int perfSamples = 0;
   const double perfScale = ComputePerformanceRiskScale(perfPf, perfWr, perfDdPct, perfSamples);

   double effRisk = baseRisk * factor * softMult * perfScale;
   const double capScale = (P.useRiskLadder ? MathMax(1.0, P.riskLadderMaxScale) : 1.0);
   const double riskCap = baseRisk * capScale;
   if(effRisk > riskCap)
      effRisk = riskCap;
   if(Profile == Aggressive && effRisk > 1.25)
      effRisk = 1.25;

   if(IsDebugAtLeast(DBG_VERBOSE) && P.useRiskLadder)
   {
      DebugLog(DBG_VERBOSE,
               StringFormat("[RISK_LADDER] scale=%.3f | pf=%.2f | winrate=%.2f%% | ddLocal=%.2f%% | samples=%d",
                            perfScale,
                            perfPf,
                            perfWr * 100.0,
                            perfDdPct,
                            perfSamples));
   }

   return effRisk;
}

int ResolveLiquidityEntryMode(const SoftAdjustments &soft)
{
   int mode = P.lqEntryMode;
   if(mode < MARKET_ON_MSS || mode > HYBRID)
      mode = HYBRID;

   if(mode == HYBRID)
      return HYBRID;

   if(!soft.preferLimitEntry)
      return mode;

   if(mode == MARKET_ON_MSS)
      return HYBRID;

   return LIMIT_RETEST;
}

double ComputeLiquidityRetestPrice(const int direction, const double swingLevel, const double atr)
{
   const double tol = atr * MathMax(0.01, P.lqRetestTolAtr);
   const double offset = 2.5 * tol;
   const double rawPrice = (direction > 0 ? swingLevel + offset : swingLevel - offset);
   return NormalizePrice(rawPrice);
}

int ComputeDynamicPendingMaxAge(const double atr, const int direction, const double pendingPrice)
{
   const int base = MathMax(1, P.lqRetestMaxAgeBars);
   if(atr <= 0.0 || direction == 0 || pendingPrice <= 0.0)
      return base;

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(ask <= 0.0 || bid <= 0.0)
      return base;

   const double dist = (direction > 0 ? (ask - pendingPrice) : (pendingPrice - bid));
   if(dist <= 0.0)
      return base;

   const double distAtr = dist / atr;
   const double speedAtrPerBar = 0.35;
   const int needBars = (int)MathCeil(distAtr / speedAtrPerBar);
   return (int)ClampValue((double)MathMax(base, needBars), (double)base, 30.0);
}

bool DetectLiquiditySweep(const double atr, int &direction, double &swingLevel, double &sweepExtreme)
{
   direction = 0;
   swingLevel = 0.0;
   sweepExtreme = 0.0;

   if(atr <= 0.0)
      return false;

   const int lb = MathMax(6, P.lqSwingLookback);
   double swingHigh = -DBL_MAX;
   double swingLow = DBL_MAX;

   for(int i = 2; i < 2 + lb; i++)
   {
      const double h = iHigh(_Symbol, P.tf, i);
      const double l = iLow(_Symbol, P.tf, i);
      if(h > swingHigh)
         swingHigh = h;
      if(l < swingLow)
         swingLow = l;
   }

   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   const double c1 = iClose(_Symbol, P.tf, 1);
   const double buffer = atr * P.lqSweepBufferAtr;

   if(h1 > swingHigh + buffer && c1 < swingHigh)
   {
      direction = -1;
      swingLevel = swingHigh;
      sweepExtreme = h1;
      return true;
   }

   if(l1 < swingLow - buffer && c1 > swingLow)
   {
      direction = 1;
      swingLevel = swingLow;
      sweepExtreme = l1;
      return true;
   }

   return false;
}

bool ConfirmLiquidityDisplacement(const int direction,
                                  const double atr,
                                  const double minDisplacementAtr,
                                  double &displacementAtr)
{
   displacementAtr = 0.0;
   if(direction == 0 || atr <= 0.0)
      return false;

   const double o1 = iOpen(_Symbol, P.tf, 1);
   const double c1 = iClose(_Symbol, P.tf, 1);
   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0)
      return false;

   const bool dirAligned = (direction > 0 ? c1 > o1 : c1 < o1);
   if(!dirAligned)
      return false;

   const double body = MathAbs(c1 - o1);
   const double range = h1 - l1;
   const double threshold = atr * MathMax(0.10, minDisplacementAtr);
   displacementAtr = MathMax(body, range) / atr;

   return (body >= threshold || range >= threshold);
}

bool FindLastPivotHighLow(const int lookback,
                          const int depth,
                          double &lastPivotHigh,
                          int &idxHigh,
                          double &lastPivotLow,
                          int &idxLow)
{
   lastPivotHigh = 0.0;
   lastPivotLow = 0.0;
   idxHigh = -1;
   idxLow = -1;

   const int lb = MathMax(8, lookback);
   const int d = MathMax(1, depth);

   for(int i = d + 1; i <= lb + d; i++)
   {
      const double hi = iHigh(_Symbol, P.tf, i);
      const double lo = iLow(_Symbol, P.tf, i);
      if(hi <= 0.0 || lo <= 0.0)
         continue;

      bool isPivotHigh = true;
      bool isPivotLow = true;
      for(int k = 1; k <= d; k++)
      {
         if(hi <= iHigh(_Symbol, P.tf, i - k) || hi <= iHigh(_Symbol, P.tf, i + k))
            isPivotHigh = false;

         if(lo >= iLow(_Symbol, P.tf, i - k) || lo >= iLow(_Symbol, P.tf, i + k))
            isPivotLow = false;

         if(!isPivotHigh && !isPivotLow)
            break;
      }

      if(isPivotHigh && (idxHigh < 0 || i < idxHigh))
      {
         idxHigh = i;
         lastPivotHigh = hi;
      }

      if(isPivotLow && (idxLow < 0 || i < idxLow))
      {
         idxLow = i;
         lastPivotLow = lo;
      }
   }

   return (idxHigh > 0 || idxLow > 0);
}

bool ConfirmLiquidityMSSRangeFallback(const int direction, const int lookback, double &microLevel)
{
   microLevel = 0.0;
   const int lb = MathMax(3, lookback);
   const double c1 = iClose(_Symbol, P.tf, 1);
   if(c1 <= 0.0)
      return false;

   if(direction > 0)
   {
      double microHigh = -DBL_MAX;
      for(int i = 2; i < 2 + lb; i++)
      {
         const double h = iHigh(_Symbol, P.tf, i);
         if(h > microHigh)
            microHigh = h;
      }

      if(c1 > microHigh)
      {
         microLevel = microHigh;
         return true;
      }
      return false;
   }

   if(direction < 0)
   {
      double microLow = DBL_MAX;
      for(int i = 2; i < 2 + lb; i++)
      {
         const double l = iLow(_Symbol, P.tf, i);
         if(l < microLow)
            microLow = l;
      }

      if(c1 < microLow)
      {
         microLevel = microLow;
         return true;
      }
      return false;
   }

   return false;
}

bool ConfirmLiquidityMSS(const int direction,
                         const int lookback,
                         const int pivotDepth,
                         double &microLevel,
                         bool &usedFallback)
{
   microLevel = 0.0;
   usedFallback = false;

   const double c1 = iClose(_Symbol, P.tf, 1);
   if(c1 <= 0.0)
      return false;

   double pivotHigh = 0.0, pivotLow = 0.0;
   int idxHigh = -1, idxLow = -1;
   const int pivotLookback = MathMax(lookback * 3, 12);
   const bool hasPivot = FindLastPivotHighLow(pivotLookback, pivotDepth, pivotHigh, idxHigh, pivotLow, idxLow);
   const int sweepAge = MathMax(1, g_lq.barsSinceSweep);
   const int relevanceMaxShift = sweepAge + MathMax(3, lookback + pivotDepth);

   if(direction > 0 && hasPivot && idxHigh > 0 && idxHigh <= relevanceMaxShift)
   {
      if(c1 > pivotHigh)
      {
         microLevel = pivotHigh;
         return true;
      }
      return false;
   }

   if(direction < 0 && hasPivot && idxLow > 0 && idxLow <= relevanceMaxShift)
   {
      if(c1 < pivotLow)
      {
         microLevel = pivotLow;
         return true;
      }
      return false;
   }

   usedFallback = true;
   DebugLog(DBG_SIGNALS,
            StringFormat("[LQ_MSS_FALLBACK] dir=%d | reason=%s | idxHigh=%d | idxLow=%d | sweepAge=%d",
                         direction,
                         (hasPivot ? "pivot_irrelevante" : "pivot_indisponivel"),
                         idxHigh,
                         idxLow,
                         sweepAge));
   return ConfirmLiquidityMSSRangeFallback(direction, lookback, microLevel);
}

void BuildLiquidityTradeLevels(const int direction,
                               const double atr,
                               const SoftAdjustments &soft,
                               const double preferredEntry,
                               double &entry,
                               double &stop,
                               double &target)
{
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   if(preferredEntry > 0.0)
      entry = preferredEntry;
   else
      entry = (direction > 0 ? ask : bid);
   entry = NormalizePrice(entry);

   const double stopBuffer = atr * MathMax(0.01, P.lqStopBufferAtr);
   if(direction > 0)
      stop = g_lq.sweepExtreme - stopBuffer;
   else
      stop = g_lq.sweepExtreme + stopBuffer;

   stop = EnforceStopDistance(direction, entry, stop);

   const double rr = ClampValue(P.lqTpR * soft.tpRMult, 0.80, 4.00);
   const double riskDist = MathAbs(entry - stop);
   if(direction > 0)
      target = entry + (riskDist * rr);
   else
      target = entry - (riskDist * rr);

   target = EnforceTargetDistance(direction, entry, target);
}

bool PlaceLiquidityPendingOrder(int dir, double price, double sl, double tp, double lots, int expireBars)
{
   if(dir == 0 || price <= 0.0 || lots <= 0.0)
   {
      if(lots <= 0.0)
         LogAndPersist("[LQ_PENDING] abortado: lote invalido (<= 0) antes de enviar pendente.");
      return false;
   }

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(ask <= 0.0 || bid <= 0.0 || point <= 0.0)
      return false;

   const double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   const double minDist = MathMax(MathMax(stopLevel, freezeLevel), point);

   bool useStopOrder = false;
   price = NormalizePrice(price);
   if(dir > 0)
   {
      if(price >= (ask - minDist))
      {
         if(!P.lqAllowStopFallback)
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[LQ_NO_STOP_FALLBACK] BuyLimit invalida no contexto atual | price=%.5f | ask=%.5f | minDist=%.5f",
                                  price, ask, minDist));
            return false;
         }

         useStopOrder = true;
         price = NormalizePrice(MathMax(price, ask + minDist));
      }
      else
      {
         price = NormalizePrice(MathMin(price, ask - minDist));
      }
   }
   else
   {
      if(price <= (bid + minDist))
      {
         if(!P.lqAllowStopFallback)
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[LQ_NO_STOP_FALLBACK] SellLimit invalida no contexto atual | price=%.5f | bid=%.5f | minDist=%.5f",
                                  price, bid, minDist));
            return false;
         }

         useStopOrder = true;
         price = NormalizePrice(MathMin(price, bid - minDist));
      }
      else
      {
         price = NormalizePrice(MathMax(price, bid + minDist));
      }
   }

   sl = EnforceStopDistance(dir, price, sl);
   if(tp > 0.0)
      tp = EnforceTargetDistance(dir, price, tp);

   g_trade.SetExpertMagicNumber(LQ_MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(P.maxDeviationPoints);

   bool ok = false;
   if(dir > 0)
      ok = (useStopOrder
            ? g_trade.BuyStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, LQ_COMMENT)
            : g_trade.BuyLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, LQ_COMMENT));
   else
      ok = (useStopOrder
            ? g_trade.SellStop(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, LQ_COMMENT)
            : g_trade.SellLimit(lots, price, _Symbol, sl, tp, ORDER_TIME_GTC, 0, LQ_COMMENT));

   if(!ok)
   {
      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_PENDING] falha ao colocar | dir=%d | tipo=%s | price=%.5f | lot=%.2f | retcode=%d | msg=%s",
                            dir,
                            (useStopOrder ? "STOP_FALLBACK" : "LIMIT"),
                            price,
                            lots,
                            g_trade.ResultRetcode(),
                            g_trade.ResultRetcodeDescription()));
      return false;
   }

   g_lq.pendingTicket = g_trade.ResultOrder();
   g_lq.pendingBarsElapsed = 0;
   g_lq.pendingPrice = price;
   g_lq.hasPending = true;
   g_lq.state = LQ_ORDERED;
   g_tel.lqPendingsPlaced++;
   MarkLiquidityEntryOnCurrentBar();

   DebugLog(DBG_SIGNALS,
            StringFormat("[LQ_PENDING] ordem colocada | dir=%d | tipo=%s | ticket=%I64u | price=%.5f | sl=%.5f | tp=%.5f | barsExpire=%d",
                         dir,
                         (useStopOrder ? "STOP_FALLBACK" : "LIMIT"),
                         g_lq.pendingTicket,
                         price,
                         sl,
                         tp,
                         MathMax(1, expireBars)));
   return true;
}

double RegimeScore()
{
   int parts = 0;
   double score = 0.0;

   const double wr = RollingWinrate();
   score += ClampValue(wr, 0.0, 1.0);
   parts++;

   const int hurstLen = (Profile == Safe ? 96 : 72);
   const double hurst = CalcHurstRS(hurstLen, 1);
   if(hurst != EMPTY_VALUE)
   {
      score += ClampValue((hurst - 0.45) / 0.25, 0.0, 1.0);
      parts++;
   }

   const int entropyLen = MathMax(32, P.entropyLen);
   const double entropy = CalcDirectionEntropy(entropyLen, 1);
   if(entropy != EMPTY_VALUE)
   {
      score += ClampValue(1.0 - entropy, 0.0, 1.0);
      parts++;
   }

   const int acLen = MathMax(24, P.autocorrLen);
   const double autocorr = CalcAutocorrLag1(acLen, 1);
   if(autocorr != EMPTY_VALUE)
   {
      score += ClampValue(MathAbs(autocorr), 0.0, 1.0);
      parts++;
   }

   if(parts <= 0)
      return 0.50;

   return ClampValue(score / (double)parts, 0.0, 1.0);
}

void ApplySoftAdjustments(const double score, SoftAdjustments &outAdjust)
{
   outAdjust.riskMult = 1.0;
   outAdjust.displacementMult = 1.0;
   outAdjust.preferLimitEntry = false;
   outAdjust.tpRMult = 1.0;

   if(score < 0.35)
   {
      outAdjust.riskMult = 0.65;
      outAdjust.displacementMult = 1.25;
      outAdjust.preferLimitEntry = true;
      outAdjust.tpRMult = 0.90;
   }
   else if(score < 0.50)
   {
      outAdjust.riskMult = 0.80;
      outAdjust.displacementMult = 1.12;
      outAdjust.preferLimitEntry = true;
      outAdjust.tpRMult = 0.95;
   }
   else if(score < 0.70)
   {
      outAdjust.riskMult = 0.95;
      outAdjust.displacementMult = 1.02;
      outAdjust.preferLimitEntry = (Profile == Safe);
      outAdjust.tpRMult = 1.00;
   }
   else
   {
      outAdjust.riskMult = 1.05;
      outAdjust.displacementMult = 0.92;
      outAdjust.preferLimitEntry = false;
      outAdjust.tpRMult = 1.08;
   }

   DebugLog(DBG_VERBOSE,
            StringFormat("[RISK_ADJUST] score=%.3f | riskMult=%.2f | dispMult=%.2f | preferLimit=%s | tpRMult=%.2f",
                         score,
                         outAdjust.riskMult,
                         outAdjust.displacementMult,
                         (outAdjust.preferLimitEntry ? "true" : "false"),
                         outAdjust.tpRMult));
}

double ComputeLive247OpportunityScore(const double atr,
                                      const double pascalAtr,
                                      const double slope,
                                      const int trendDir,
                                      double &adxOut,
                                      double &spreadRatioOut,
                                      double &volRatioOut)
{
   adxOut = GetADXMain(1);
   if(adxOut == EMPTY_VALUE || adxOut < 0.0)
      adxOut = 0.0;

   const double spreadMedian = SpreadMedianPoints(MathMax(50, P.spreadMedianLen), 1);
   const double spreadNow = CurrentSpreadPoints();
   spreadRatioOut = (spreadMedian > 0.0 ? spreadNow / spreadMedian : 1.0);
   volRatioOut = (pascalAtr > 0.0 ? atr / pascalAtr : 1.0);

   double score = 0.0;
   int parts = 0;

   score += (trendDir != 0 ? 1.0 : 0.0);
   parts++;

   const double trendStrength = (atr > 0.0 ? MathAbs(slope) / atr : 0.0);
   score += ClampValue((trendStrength - 0.035) / 0.030, 0.0, 1.0);
   parts++;

   score += ClampValue((adxOut - 18.0) / 12.0, 0.0, 1.0);
   parts++;

   if(spreadRatioOut <= 1.0)
      score += 1.0;
   else
      score += ClampValue(1.0 - ((spreadRatioOut - 1.0) / 0.50), 0.0, 1.0);
   parts++;

   score += ClampValue(1.0 - (MathAbs(volRatioOut - 1.18) / 0.50), 0.0, 1.0);
   parts++;

   const double hurst = CalcHurstRS(72, 1);
   if(hurst != EMPTY_VALUE)
   {
      score += ClampValue((hurst - 0.50) / 0.10, 0.0, 1.0);
      parts++;
   }

   const double entropy = CalcDirectionEntropy(MathMax(32, P.entropyLen), 1);
   if(entropy != EMPTY_VALUE)
   {
      score += ClampValue((0.82 - entropy) / 0.20, 0.0, 1.0);
      parts++;
   }

   const double autocorr = CalcAutocorrLag1(MathMax(24, P.autocorrLen), 1);
   if(autocorr != EMPTY_VALUE)
   {
      score += ClampValue((MathAbs(autocorr) - 0.08) / 0.12, 0.0, 1.0);
      parts++;
   }

   if(parts <= 0)
      return 0.0;

   return ClampValue(score / (double)parts, 0.0, 1.0);
}

double PascalMA_CloseTF(const ENUM_TIMEFRAMES tf, const int pascalLen, const int shift)
{
   double w[];
   if(!BuildPascalWeights(pascalLen, w))
      return EMPTY_VALUE;

   double acc = 0.0;
   for(int i = 0; i < pascalLen; i++)
   {
      const double c = iClose(_Symbol, tf, shift + i);
      if(c <= 0.0)
         return EMPTY_VALUE;
      acc += c * w[i];
   }
   return acc;
}

int TrendDirectionTF(const ENUM_TIMEFRAMES tf, const int pascalLen, double &slope)
{
   const double ma1 = PascalMA_CloseTF(tf, pascalLen, 1);
   const double ma2 = PascalMA_CloseTF(tf, pascalLen, 2);

   if(ma1 == EMPTY_VALUE || ma2 == EMPTY_VALUE)
   {
      slope = 0.0;
      return 0;
   }

   slope = (ma1 - ma2);
   if(slope > 0.0)
      return 1;
   if(slope < 0.0)
      return -1;
   return 0;
}

double ATR_OnTF(const ENUM_TIMEFRAMES tf, const int len, const int shift)
{
   const int useLen = MathMax(3, len);
   double sum = 0.0;
   int count = 0;

   for(int i = shift; i < shift + useLen; i++)
   {
      const double h = iHigh(_Symbol, tf, i);
      const double l = iLow(_Symbol, tf, i);
      const double cp = iClose(_Symbol, tf, i + 1);
      if(h <= 0.0 || l <= 0.0 || cp <= 0.0)
         continue;

      const double tr1 = h - l;
      const double tr2 = MathAbs(h - cp);
      const double tr3 = MathAbs(l - cp);
      sum += MathMax(tr1, MathMax(tr2, tr3));
      count++;
   }

   if(count <= 0)
      return EMPTY_VALUE;

   return (sum / (double)count);
}

void ApplyLive247LiquidityProfile(Params &params, const int profile)
{
   if(!IsDynamicLiquidityOverlayTemplate())
      return;

   if(profile != L247_PUSH)
      return;

   if(IsHighProfit247LiquidityTemplate())
   {
      params.riskPct = 0.10;
      params.maxTradesPerDay = 80;
      params.maxConsecLosses = 5;
      params.maxDailyDDPct = 4.0;

      params.atrFilterMult = 0.60;
      params.useSessionFilter = true;
      params.tradeStartHour = 6;
      params.tradeEndHour = 21;
      params.onePosPerSymbol = true;

      params.useDynamicSpreadGate = false;
      params.maxSpreadAtrFrac = 0.35;
      params.spreadMedianMult = 2.00;
      params.slippagePoints = 30;
      params.maxDeviationPoints = 30;

      params.lqSwingLookback = 6;
      params.lqSweepBufferAtr = 0.00;
      params.lqSweepMaxAgeBars = 6;
      params.lqMinDisplacementAtr = 0.30;
      params.lqStopBufferAtr = 0.30;
      params.lqTpR = 1.35;
      params.lqEntryMode = HYBRID;
      params.lqRetestMaxAgeBars = 2;
      params.lqRetestTolAtr = 0.08;
      params.lqAllowStopFallback = true;
      params.lqUseStructuralTrail = true;
      params.lqStructuralTrailAtr = 0.20;

      params.useBreakEven = false;
      params.trailStartAtr = 1.20;
      params.trailAtrMult = 1.00;

      params.useAtrRegimeGate = false;
      params.regimeAtrMaLen = 80;
      params.regimeAtrMult = 1.02;
      params.useAutoPause = true;
      params.autoPauseWindowTrades = 16;
      params.autoPausePfStop = 1.00;
      params.autoPauseDdStopPct = 1.20;
      params.autoPauseHours = 18;
      params.autoPausePfResume = 1.08;

      params.shieldSpreadSpikeMult = 4.00;
      params.shieldMaxSpreadPoints = 1200;
      params.shieldAtrShockMult = 4.00;
      params.shieldCandleShockMult = 5.00;
      params.shieldCooldownBars = 1;
      params.shieldSlippageLimitPoints = 80;
      return;
   }

   params.riskPct = 0.45;
   params.maxTradesPerDay = 50;
   params.maxConsecLosses = 4;
   params.maxDailyDDPct = 4.0;

   params.atrFilterMult = 0.78;
   params.useSessionFilter = true;
   params.tradeStartHour = 7;
   params.tradeEndHour = 20;
   params.onePosPerSymbol = true;

   params.useDynamicSpreadGate = true;
   params.maxSpreadAtrFrac = 0.24;
   params.spreadMedianMult = 2.10;
   params.slippagePoints = 18;
   params.maxDeviationPoints = 18;

   params.lqMinDisplacementAtr = 0.45;
   params.lqStopBufferAtr = 0.28;
   params.lqTpR = 1.28;
   params.lqEntryMode = HYBRID;
   params.lqRetestMaxAgeBars = 2;
   params.lqRetestTolAtr = 0.08;
   params.lqAllowStopFallback = true;
   params.lqUseStructuralTrail = true;
   params.lqStructuralTrailAtr = 0.24;

   params.useBreakEven = false;
   params.trailStartAtr = 1.10;
   params.trailAtrMult = 1.00;

   params.useAtrRegimeGate = false;
   params.useAutoPause = false;

   params.shieldSpreadSpikeMult = 2.30;
   params.shieldMaxSpreadPoints = 80;
   params.shieldAtrShockMult = 2.40;
   params.shieldCandleShockMult = 3.20;
   params.shieldCooldownBars = 1;
   params.shieldSlippageLimitPoints = 18;
}

void UpdateLive247LiquidityProfile(const double atr,
                                   const double pascalAtr,
                                   const double slope,
                                   const int trendDir)
{
   if(!IsDynamicLiquidityOverlayTemplate())
   {
      g_live247Profile = L247_BASE;
      g_live247ProfileLockBars = 0;
      g_live247ProfileBaseConfirm = 0;
      g_live247ProfilePushConfirm = 0;
      return;
   }

   double adx = 0.0;
   double spreadRatio = 1.0;
   double volRatio = 1.0;
   const double score = ComputeLive247OpportunityScore(atr, pascalAtr, slope, trendDir, adx, spreadRatio, volRatio);

   const double trendStrength = (atr > 0.0 ? MathAbs(slope) / atr : 0.0);
   double m15Slope = 0.0;
   double h1Slope = 0.0;
   const int m15Dir = TrendDirectionTF(PERIOD_M15, MathMax(3, P.pascalLenPrice), m15Slope);
   const int h1Dir = TrendDirectionTF(PERIOD_H1, MathMax(3, P.pascalLenPrice), h1Slope);
   double d1Slope = 0.0;
   const int d1Dir = TrendDirectionTF(PERIOD_D1, MathMax(3, P.pascalLenPrice), d1Slope);
   const double m15Atr = ATR_OnTF(PERIOD_M15, 14, 1);
   const double h1Atr = ATR_OnTF(PERIOD_H1, 14, 1);
   const double d1Atr = ATR_OnTF(PERIOD_D1, 14, 1);
   const double m15TrendStrength = (m15Atr > 0.0 ? MathAbs(m15Slope) / m15Atr : 0.0);
   const double h1TrendStrength = (h1Atr > 0.0 ? MathAbs(h1Slope) / h1Atr : 0.0);
   const double d1TrendStrength = (d1Atr > 0.0 ? MathAbs(d1Slope) / d1Atr : 0.0);

   double pfRecent = 1.0;
   double wrRecent = 0.50;
   double localDdPct = 0.0;
   int perfSamples = 0;
   const bool hasPerf = ComputeRecentPerformance(16, pfRecent, wrRecent, localDdPct, perfSamples);
   const bool recentHealthy = (!hasPerf ||
                               perfSamples < 10 ||
                               (pfRecent >= 1.02 && localDdPct <= 1.25));
   const bool recentHot = (hasPerf &&
                           perfSamples >= 10 &&
                           pfRecent >= 1.12 &&
                           wrRecent >= 0.50 &&
                           localDdPct <= 0.90);
   const bool recentWeak = (hasPerf &&
                            perfSamples >= 10 &&
                            (pfRecent < 1.00 || localDdPct > 1.50));

   bool macroAligned = false;
   bool macroStrong = false;
   bool pushCond = false;
   bool baseCond = false;

   if(IsHighProfit247LiquidityTemplate())
   {
      macroAligned = (trendDir != 0 &&
                      trendDir == m15Dir &&
                      h1Dir != -trendDir &&
                      d1Dir != -trendDir);
      macroStrong = (m15TrendStrength >= 0.020 &&
                     h1TrendStrength >= 0.010);

      pushCond = (trendDir != 0 &&
                  macroAligned &&
                  macroStrong &&
                  trendStrength >= 0.060 &&
                  adx >= 22.0 &&
                  spreadRatio <= 1.25 &&
                  volRatio >= 0.90 &&
                  volRatio <= 1.55 &&
                  score >= 0.68 &&
                  !recentWeak &&
                  (!hasPerf || perfSamples < 10 || recentHealthy || recentHot));

      baseCond = (!pushCond &&
                  (!macroAligned ||
                   !macroStrong ||
                   score <= 0.56 ||
                   trendDir == 0 ||
                   adx < 18.0 ||
                   spreadRatio > 1.35 ||
                   volRatio > 1.70 ||
                   recentWeak));
   }
   else
   {
      macroAligned = (trendDir != 0 && trendDir == m15Dir && h1Dir != -trendDir);
      macroStrong = (m15TrendStrength >= 0.025 && h1TrendStrength >= 0.015);

      pushCond = (trendDir != 0 &&
                  macroAligned &&
                  macroStrong &&
                  trendStrength >= 0.080 &&
                  adx >= 28.00 &&
                  spreadRatio <= 1.20 &&
                  volRatio >= 0.96 &&
                  volRatio <= 1.45 &&
                  score >= 0.70);
      baseCond = (!pushCond &&
                  (!macroAligned ||
                   !macroStrong ||
                   score <= 0.60 ||
                   trendDir == 0 ||
                   adx < 20.0 ||
                   spreadRatio > 1.35 ||
                   volRatio > 1.65));
   }

   if(pushCond)
   {
      g_live247ProfilePushConfirm++;
      g_live247ProfileBaseConfirm = 0;
   }
   else if(baseCond)
   {
      g_live247ProfileBaseConfirm++;
      g_live247ProfilePushConfirm = 0;
   }
   else
   {
      g_live247ProfileBaseConfirm = 0;
      g_live247ProfilePushConfirm = 0;
   }

   if(g_live247ProfileLockBars > 0)
      g_live247ProfileLockBars--;

   int targetProfile = g_live247Profile;
   const int pushConfirmNeeded = (IsHighProfit247LiquidityTemplate() ? 1 : 2);
   const int baseConfirmNeeded = 2;
   if(g_live247ProfileLockBars <= 0)
   {
      if(g_live247ProfilePushConfirm >= pushConfirmNeeded)
         targetProfile = L247_PUSH;
      else if(g_live247ProfileBaseConfirm >= baseConfirmNeeded)
         targetProfile = L247_BASE;
   }

   if(targetProfile != g_live247Profile)
   {
      const int oldProfile = g_live247Profile;
      g_live247Profile = targetProfile;
      g_live247ProfileLockBars = (IsHighProfit247LiquidityTemplate() ? 6 : 8);
      g_live247ProfileBaseConfirm = 0;
      g_live247ProfilePushConfirm = 0;

      LogAndPersist(StringFormat("[L247] switch %s -> %s | score=%.2f | trend=%.3f | adx=%.1f | spreadRatio=%.2f | volRatio=%.2f",
                                 Live247ProfileToString(oldProfile),
                                 Live247ProfileToString(g_live247Profile),
                                 score,
                                 trendStrength,
                                 adx,
                                 spreadRatio,
                                 volRatio));
   }

   ApplyLive247LiquidityProfile(P, g_live247Profile);

   DebugLog(DBG_VERBOSE,
            StringFormat("[L247] state=%s | lock=%d | score=%.2f | trend=%.3f | m15=%.3f | h1=%.3f | d1=%.3f | adx=%.1f | spreadRatio=%.2f | volRatio=%.2f | pf=%.2f | dd=%.2f%%",
                         Live247ProfileToString(g_live247Profile),
                         g_live247ProfileLockBars,
                         score,
                         trendStrength,
                         m15TrendStrength,
                         h1TrendStrength,
                         d1TrendStrength,
                         adx,
                         spreadRatio,
                         volRatio,
                         pfRecent,
                         localDdPct));
}

bool ComputeCloseMeanStd(const int len, const int startShift, double &mean, double &stddev)
{
   mean = 0.0;
   stddev = 0.0;

   const int useLen = MathMax(5, len);
   double values[];
   ArrayResize(values, useLen);

   int count = 0;
   for(int i = startShift; i < startShift + useLen; i++)
   {
      const double c = iClose(_Symbol, P.tf, i);
      if(c <= 0.0)
         continue;
      values[count] = c;
      count++;
   }

   if(count < 5)
      return false;

   for(int i = 0; i < count; i++)
      mean += values[i];
   mean /= (double)count;

   double var = 0.0;
   for(int i = 0; i < count; i++)
   {
      const double diff = values[i] - mean;
      var += (diff * diff);
   }

   stddev = MathSqrt(var / (double)count);
   return (stddev > 0.0);
}

int ExtractHour(const datetime when)
{
   MqlDateTime dt;
   ZeroMemory(dt);
   if(!TimeToStruct(when, dt))
      return -1;
   return dt.hour;
}

int ExtractWeekday(const datetime when)
{
   MqlDateTime dt;
   ZeroMemory(dt);
   if(!TimeToStruct(when, dt))
      return -1;
   return dt.day_of_week;
}

int ComputePreviousDayBias(double &strengthOut)
{
   strengthOut = 0.0;

   const double prevOpen = iOpen(_Symbol, PERIOD_D1, 1);
   const double prevHigh = iHigh(_Symbol, PERIOD_D1, 1);
   const double prevLow = iLow(_Symbol, PERIOD_D1, 1);
   const double prevClose = iClose(_Symbol, PERIOD_D1, 1);
   if(prevOpen <= 0.0 || prevHigh <= 0.0 || prevLow <= 0.0 || prevClose <= 0.0)
      return 0;

   const double prevRange = prevHigh - prevLow;
   if(prevRange <= 0.0)
      return 0;

   double avgRange = 0.0;
   int count = 0;
   for(int i = 2; i < 12; i++)
   {
      const double dHigh = iHigh(_Symbol, PERIOD_D1, i);
      const double dLow = iLow(_Symbol, PERIOD_D1, i);
      if(dHigh <= 0.0 || dLow <= 0.0 || dHigh <= dLow)
         continue;
      avgRange += (dHigh - dLow);
      count++;
   }

   if(count <= 0)
      return 0;

   avgRange /= (double)count;
   if(avgRange <= 0.0)
      return 0;

   const double body = prevClose - prevOpen;
   const double closePos = (prevClose - prevLow) / prevRange;
   strengthOut = MathAbs(body) / avgRange;

   const bool upExhaust = (body > 0.0 && closePos >= 0.78 && strengthOut >= 0.55);
   const bool downExhaust = (body < 0.0 && closePos <= 0.22 && strengthOut >= 0.55);

   if(upExhaust)
      return -1;
   if(downExhaust)
      return 1;

   return 0;
}

bool ComputeFusionOpeningRange(const int startHour,
                               const int endHour,
                               double &rangeHigh,
                               double &rangeLow,
                               int &barsCount)
{
   rangeHigh = -DBL_MAX;
   rangeLow = DBL_MAX;
   barsCount = 0;

   if(g_dayKey == 0)
      return false;

   for(int i = 1; i < 400; i++)
   {
      const datetime barTime = iTime(_Symbol, P.tf, i);
      if(barTime <= 0)
         break;

      if(BuildDayKey(barTime) != g_dayKey)
         break;

      const int hour = ExtractHour(barTime);
      if(hour < startHour || hour > endHour)
         continue;

      const double hi = iHigh(_Symbol, P.tf, i);
      const double lo = iLow(_Symbol, P.tf, i);
      if(hi <= 0.0 || lo <= 0.0 || hi <= lo)
         continue;

      if(hi > rangeHigh)
         rangeHigh = hi;
      if(lo < rangeLow)
         rangeLow = lo;
      barsCount++;
   }

   return (barsCount > 0 && rangeHigh > rangeLow);
}

bool EvaluateFusionBreakoutSignal(const double atr,
                                  int &direction,
                                  double &stop,
                                  double &target,
                                  string &origin)
{
   direction = 0;
   stop = 0.0;
   target = 0.0;
   origin = "";

   const datetime barTime = iTime(_Symbol, P.tf, 1);
   if(barTime <= 0)
      return false;

   const int hour = ExtractHour(barTime);
   if(hour < 6 || hour > 20)
      return false;

   double rangeHigh = 0.0;
   double rangeLow = 0.0;
   int rangeBars = 0;
   if(!ComputeFusionOpeningRange(0, 5, rangeHigh, rangeLow, rangeBars))
      return false;

   g_fusion.rangeReady = true;
   g_fusion.rangeHigh = rangeHigh;
   g_fusion.rangeLow = rangeLow;

   const double rangeWidth = rangeHigh - rangeLow;
   if(rangeWidth < atr * 0.40 || rangeWidth > atr * 4.00)
      return false;

   double m15Slope = 0.0;
   double h1Slope = 0.0;
   double d1Slope = 0.0;
   const int m15Dir = TrendDirectionTF(PERIOD_M15, MathMax(3, P.pascalLenPrice), m15Slope);
   const int h1Dir = TrendDirectionTF(PERIOD_H1, MathMax(3, P.pascalLenPrice), h1Slope);
   const int d1Dir = TrendDirectionTF(PERIOD_D1, MathMax(3, P.pascalLenPrice), d1Slope);
   const double adx = GetADXMain(1);
   const double m15Atr = ATR_OnTF(PERIOD_M15, 14, 1);
   const double h1Atr = ATR_OnTF(PERIOD_H1, 14, 1);
   const double m15TrendStrength = (m15Atr > 0.0 ? MathAbs(m15Slope) / m15Atr : 0.0);
   const double h1TrendStrength = (h1Atr > 0.0 ? MathAbs(h1Slope) / h1Atr : 0.0);
   const int weekday = ExtractWeekday(barTime);
   const double adxMin = (weekday == 2 ? 26.0 : 23.0);
   const double breakBufferAtr = (weekday == 2 ? 0.12 : 0.08);
   const double targetFactor = (weekday == 5 ? 1.50 : 1.25);

   double prevBiasStrength = 0.0;
   const int prevDayBias = ComputePreviousDayBias(prevBiasStrength);

   const double o1 = iOpen(_Symbol, P.tf, 1);
   const double c1 = iClose(_Symbol, P.tf, 1);
   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   const double barRange = MathMax(_Point, h1 - l1);
   const double closeStrengthLong = (c1 - l1) / barRange;
   const double closeStrengthShort = (h1 - c1) / barRange;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(!g_fusion.breakoutLongDone &&
      c1 > (rangeHigh + atr * breakBufferAtr) &&
      c1 > o1 &&
      closeStrengthLong >= 0.60 &&
      m15Dir > 0 &&
      h1Dir >= 0 &&
      d1Dir >= 0 &&
      m15TrendStrength >= 0.020 &&
      h1TrendStrength >= 0.010 &&
      adx >= adxMin &&
      prevDayBias >= 0)
   {
      direction = 1;
      stop = MathMin(l1 - atr * 0.15, rangeHigh - atr * 0.30);
      target = ask + MathMax(rangeWidth * targetFactor, atr * 1.30);
      origin = "Fusion Breakout Long";
      return true;
   }

   if(!g_fusion.breakoutShortDone &&
      c1 < (rangeLow - atr * breakBufferAtr) &&
      c1 < o1 &&
      closeStrengthShort >= 0.60 &&
      m15Dir < 0 &&
      h1Dir <= 0 &&
      d1Dir <= 0 &&
      m15TrendStrength >= 0.020 &&
      h1TrendStrength >= 0.010 &&
      adx >= adxMin &&
      prevDayBias <= 0)
   {
      direction = -1;
      stop = MathMax(h1 + atr * 0.15, rangeLow + atr * 0.30);
      target = bid - MathMax(rangeWidth * targetFactor, atr * 1.30);
      origin = "Fusion Breakout Short";
      return true;
   }

   return false;
}

bool EvaluateFusionReversalSignal(const double atr,
                                  int &direction,
                                  double &stop,
                                  double &target,
                                  string &origin)
{
   direction = 0;
   stop = 0.0;
   target = 0.0;
   origin = "";

   const datetime barTime = iTime(_Symbol, P.tf, 1);
   if(barTime <= 0)
      return false;

   const int hour = ExtractHour(barTime);
   if(hour < 0 || hour > 5)
      return false;

   double mean = 0.0;
   double stddev = 0.0;
   if(!ComputeCloseMeanStd(24, 1, mean, stddev))
      return false;

   const double c1 = iClose(_Symbol, P.tf, 1);
   const double o1 = iOpen(_Symbol, P.tf, 1);
   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   double h1Slope = 0.0;
   TrendDirectionTF(PERIOD_H1, MathMax(3, P.pascalLenPrice), h1Slope);
   const double h1Atr = ATR_OnTF(PERIOD_H1, 14, 1);
   const double h1TrendStrength = (h1Atr > 0.0 ? MathAbs(h1Slope) / h1Atr : 0.0);
   const double adx = GetADXMain(1);
   const double zScore = (c1 - mean) / stddev;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(adx > 20.0 || h1TrendStrength > 0.018)
      return false;

   if(zScore >= 1.80 &&
      c1 < o1)
   {
      direction = -1;
      stop = h1 + atr * 0.25;
      target = MathMin(mean, bid - atr * 0.80);
      origin = "Fusion Asia Reversal Short";
      return true;
   }

   if(zScore <= -1.80 &&
      c1 > o1)
   {
      direction = 1;
      stop = l1 - atr * 0.25;
      target = MathMax(mean, ask + atr * 0.80);
      origin = "Fusion Asia Reversal Long";
      return true;
   }

   return false;
}

void OnNewBarFusion(const double atr, const double pascalAtr)
{
   const datetime currentBar = iTime(_Symbol, P.tf, 0);
   if(currentBar <= 0)
      return;

   if(g_fusion.lastSignalBarTime == currentBar)
      return;

   if(!CanPassTradeContextGuards(atr))
      return;

   if(!IsSpreadAcceptable(atr))
      return;

   string shieldReason = "";
   if(!ExecutionShieldAllowsEntry(atr, pascalAtr, shieldReason))
      return;

   int direction = 0;
   double customStop = 0.0;
   double customTarget = 0.0;
   string origin = "";

   const int signalHour = ExtractHour(iTime(_Symbol, P.tf, 1));
   bool hasSignal = false;
   if(signalHour >= 0 && signalHour <= 5)
   {
      hasSignal = EvaluateFusionReversalSignal(atr, direction, customStop, customTarget, origin);
      if(!hasSignal)
         hasSignal = EvaluateFusionBreakoutSignal(atr, direction, customStop, customTarget, origin);
   }
   else
   {
      hasSignal = EvaluateFusionBreakoutSignal(atr, direction, customStop, customTarget, origin);
      if(!hasSignal)
         hasSignal = EvaluateFusionReversalSignal(atr, direction, customStop, customTarget, origin);
   }
   if(!hasSignal)
      return;

   if(!ExecuteEntry(direction, atr, origin, true, customStop, customTarget, 1.0))
      return;

   g_fusion.lastSignalBarTime = currentBar;
   if(StringFind(origin, "Breakout Long") >= 0)
      g_fusion.breakoutLongDone = true;
   else if(StringFind(origin, "Breakout Short") >= 0)
      g_fusion.breakoutShortDone = true;
}

bool EvaluateMicroBurstTrendSignal(const double atr,
                                   int &direction,
                                   double &stop,
                                   double &target,
                                   string &origin)
{
   direction = 0;
   stop = 0.0;
   target = 0.0;
   origin = "";

   const datetime barTime = iTime(_Symbol, P.tf, 1);
   if(barTime <= 0)
      return false;

   const int hour = ExtractHour(barTime);
   if(hour < 6 || hour > 20)
      return false;

   if(g_microBurst.trendTradesToday >= 24)
      return false;

   if(g_microBurst.lastTrendSignalBarTime > 0 && BarsSinceBarTime(g_microBurst.lastTrendSignalBarTime) < 3)
      return false;

   double mean = 0.0;
   double stddev = 0.0;
   if(!ComputeCloseMeanStd(30, 1, mean, stddev))
      return false;

   const double o1 = iOpen(_Symbol, P.tf, 1);
   const double c1 = iClose(_Symbol, P.tf, 1);
   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || h1 <= l1)
      return false;

   double m15Slope = 0.0;
   double h1Slope = 0.0;
   const int m15Dir = TrendDirectionTF(PERIOD_M15, MathMax(3, P.pascalLenPrice), m15Slope);
   const int h1Dir = TrendDirectionTF(PERIOD_H1, MathMax(3, P.pascalLenPrice), h1Slope);
   const double m15Atr = ATR_OnTF(PERIOD_M15, 14, 1);
   const double h1Atr = ATR_OnTF(PERIOD_H1, 14, 1);
   const double m15TrendStrength = (m15Atr > 0.0 ? MathAbs(m15Slope) / m15Atr : 0.0);
   const double h1TrendStrength = (h1Atr > 0.0 ? MathAbs(h1Slope) / h1Atr : 0.0);
   const double adx = GetADXMain(1);
   const double zScore = (c1 - mean) / stddev;
   const double barRange = MathMax(_Point, h1 - l1);
   const double closeStrengthLong = (c1 - l1) / barRange;
   const double closeStrengthShort = (h1 - c1) / barRange;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(m15Dir > 0 &&
      h1Dir >= 0 &&
      m15TrendStrength >= 0.012 &&
      h1TrendStrength >= 0.005 &&
      adx >= 12.0 &&
      zScore <= -0.30 &&
      c1 > o1 &&
      closeStrengthLong >= 0.54)
   {
      direction = 1;
      stop = l1 - atr * 0.35;
      target = ask + atr * 1.05;
      origin = "MicroBurst Trend Long";
      return true;
   }

   if(m15Dir < 0 &&
      h1Dir <= 0 &&
      m15TrendStrength >= 0.012 &&
      h1TrendStrength >= 0.005 &&
      adx >= 12.0 &&
      zScore >= 0.30 &&
      c1 < o1 &&
      closeStrengthShort >= 0.54)
   {
      direction = -1;
      stop = h1 + atr * 0.35;
      target = bid - atr * 1.05;
      origin = "MicroBurst Trend Short";
      return true;
   }

   return false;
}

bool EvaluateMicroBurstReversionSignal(const double atr,
                                       int &direction,
                                       double &stop,
                                       double &target,
                                       string &origin)
{
   direction = 0;
   stop = 0.0;
   target = 0.0;
   origin = "";

   const datetime barTime = iTime(_Symbol, P.tf, 1);
   if(barTime <= 0)
      return false;

   if(g_microBurst.reversionTradesToday >= 24)
      return false;

   if(g_microBurst.lastReversionSignalBarTime > 0 && BarsSinceBarTime(g_microBurst.lastReversionSignalBarTime) < 5)
      return false;

   double mean = 0.0;
   double stddev = 0.0;
   if(!ComputeCloseMeanStd(MathMax(40, P.lookback), 1, mean, stddev))
      return false;

   const double o1 = iOpen(_Symbol, P.tf, 1);
   const double c1 = iClose(_Symbol, P.tf, 1);
   const double h1 = iHigh(_Symbol, P.tf, 1);
   const double l1 = iLow(_Symbol, P.tf, 1);
   if(o1 <= 0.0 || c1 <= 0.0 || h1 <= 0.0 || l1 <= 0.0 || h1 <= l1)
      return false;

   double h1Slope = 0.0;
   TrendDirectionTF(PERIOD_H1, MathMax(3, P.pascalLenPrice), h1Slope);
   const double h1Atr = ATR_OnTF(PERIOD_H1, 14, 1);
   const double h1TrendStrength = (h1Atr > 0.0 ? MathAbs(h1Slope) / h1Atr : 0.0);
   const double adx = GetADXMain(1);
   const double zScore = (c1 - mean) / stddev;
   const double barRange = MathMax(_Point, h1 - l1);
   const double closeStrengthLong = (c1 - l1) / barRange;
   const double closeStrengthShort = (h1 - c1) / barRange;
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);

   if(adx > 24.0 || h1TrendStrength > 0.025)
      return false;

   if(zScore >= 0.95 &&
      c1 < o1 &&
      closeStrengthShort >= 0.52)
   {
      direction = -1;
      stop = h1 + atr * 0.40;
      target = MathMin(mean, bid - atr * 0.60);
      origin = "MicroBurst Reversion Short";
      return true;
   }

   if(zScore <= -0.95 &&
      c1 > o1 &&
      closeStrengthLong >= 0.52)
   {
      direction = 1;
      stop = l1 - atr * 0.40;
      target = MathMax(mean, ask + atr * 0.60);
      origin = "MicroBurst Reversion Long";
      return true;
   }

   return false;
}

void OnNewBarMicroBurst(const double atr, const double pascalAtr)
{
   const datetime currentBar = iTime(_Symbol, P.tf, 0);
   if(currentBar <= 0)
      return;

   if(g_microBurst.lastSignalBarTime == currentBar)
      return;

   if(!CanPassTradeContextGuards(atr))
      return;

   if(!IsSpreadAcceptable(atr))
      return;

   string shieldReason = "";
   if(!ExecutionShieldAllowsEntry(atr, pascalAtr, shieldReason))
      return;

   int direction = 0;
   double customStop = 0.0;
   double customTarget = 0.0;
   string origin = "";

   bool hasSignal = EvaluateMicroBurstTrendSignal(atr, direction, customStop, customTarget, origin);
   if(!hasSignal)
      hasSignal = EvaluateMicroBurstReversionSignal(atr, direction, customStop, customTarget, origin);
   if(!hasSignal)
      return;

   if(!ExecuteEntry(direction, atr, origin, true, customStop, customTarget, 1.0))
      return;

   g_microBurst.lastSignalBarTime = currentBar;
   if(StringFind(origin, "Trend") >= 0)
   {
      g_microBurst.lastTrendSignalBarTime = currentBar;
      g_microBurst.trendTradesToday++;
   }
   else
   {
      g_microBurst.lastReversionSignalBarTime = currentBar;
      g_microBurst.reversionTradesToday++;
   }
}

bool EvaluateLiquidityScalpSignal(const double atr,
                                  const SoftAdjustments &soft,
                                  int &direction,
                                  double &entryPrice,
                                  double &stop,
                                  double &target,
                                  bool &usePendingOrder,
                                  string &origin)
{
   direction = 0;
   entryPrice = 0.0;
   stop = 0.0;
   target = 0.0;
   usePendingOrder = false;
   origin = "";

   if(atr <= 0.0)
      return false;

   if(!g_lq.valid)
      g_lq.state = LQ_IDLE;

   if(g_lq.valid && g_lq.sweepTime > 0)
   {
      g_lq.barsSinceSweep = BarsSinceBarTime(g_lq.sweepTime);
      if(g_lq.barsSinceSweep > MathMax(1, P.lqSweepMaxAgeBars))
      {
         HardResetLiquidity("Sweep expirado");
         return false;
      }
   }

   if(g_lq.state == LQ_IDLE)
   {
      int sweepDir = 0;
      double swingLevel = 0.0;
      double sweepExtreme = 0.0;
      if(!DetectLiquiditySweep(atr, sweepDir, swingLevel, sweepExtreme))
         return false;

      g_lq.valid = true;
      g_lq.state = LQ_SWEEP;
      g_lq.direction = sweepDir;
      g_lq.swingLevel = swingLevel;
      g_lq.sweepExtreme = sweepExtreme;
      g_lq.sweepTime = iTime(_Symbol, P.tf, 1);
      g_lq.barsSinceSweep = 0;
      g_tel.lqSweeps++;

      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_SWEEP] dir=%d | swing=%.5f | extreme=%.5f | buffer=%.2f ATR",
                            g_lq.direction,
                            g_lq.swingLevel,
                            g_lq.sweepExtreme,
                            P.lqSweepBufferAtr));
      return false;
   }

   if(g_lq.state == LQ_SWEEP)
   {
      double dispAtr = 0.0;
      const double minDisp = P.lqMinDisplacementAtr * soft.displacementMult;
      if(ConfirmLiquidityDisplacement(g_lq.direction, atr, minDisp, dispAtr))
      {
         g_lq.state = LQ_DISPLACED;
         g_lq.displacementSizeAtr = dispAtr;
         g_tel.lqDisplacements++;
         DebugLog(DBG_SIGNALS,
                  StringFormat("[LQ_DISP] dir=%d | displacement=%.2f ATR | min=%.2f ATR",
                               g_lq.direction,
                               g_lq.displacementSizeAtr,
                               minDisp));
      }
      return false;
   }

   if(g_lq.state == LQ_DISPLACED)
   {
      double micro = 0.0;
      bool usedFallback = false;
      if(!ConfirmLiquidityMSS(g_lq.direction, P.lqMssLookback, 2, micro, usedFallback))
      {
         const double minDisp = P.lqMinDisplacementAtr * soft.displacementMult;
         const bool strongFallback = (g_lq.barsSinceSweep >= 1 &&
                                      g_lq.displacementSizeAtr >= (minDisp * 1.25));
         if(!strongFallback)
            return false;

         BuildLiquidityTradeLevels(g_lq.direction, atr, soft, 0.0, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
         direction = g_lq.direction;
         entryPrice = g_lq.entryPrice;
         stop = g_lq.slPrice;
         target = g_lq.tpPrice;
         origin = "LiquidityScalp Displacement Fallback";
         g_tel.lqSignalsFound++;
         g_tel.lqHybridFallbackMarket++;
         DebugLog(DBG_SIGNALS,
                  StringFormat("[LQ_DISP_FALLBACK] dir=%d | disp=%.2f ATR | min=%.2f ATR | barsSinceSweep=%d",
                               g_lq.direction,
                               g_lq.displacementSizeAtr,
                               minDisp,
                               g_lq.barsSinceSweep));
         return true;
      }

      g_lq.state = LQ_MSS;
      g_lq.microLevel = micro;
      g_lq.mssTime = iTime(_Symbol, P.tf, 1);
      g_lq.entryModeUsed = ResolveLiquidityEntryMode(soft);
      g_tel.lqMSS++;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double tol = atr * MathMax(0.01, P.lqRetestTolAtr);
      g_lq.pendingPrice = ComputeLiquidityRetestPrice(g_lq.direction, g_lq.swingLevel, atr);

      const double distToRetest = (g_lq.direction > 0
                                   ? (ask - g_lq.pendingPrice)
                                   : (g_lq.pendingPrice - bid));
      const bool farEnoughForPending = (distToRetest > tol);

      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_MSS] dir=%d | microLevel=%.5f | entryMode=%d | pendingPrice=%.5f | dist=%.5f | tol=%.5f",
                            g_lq.direction,
                            g_lq.microLevel,
                            g_lq.entryModeUsed,
                            g_lq.pendingPrice,
                            distToRetest,
                            tol));

      if(g_lq.entryModeUsed == MARKET_ON_MSS)
      {
         BuildLiquidityTradeLevels(g_lq.direction, atr, soft, 0.0, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
         direction = g_lq.direction;
         entryPrice = g_lq.entryPrice;
         stop = g_lq.slPrice;
         target = g_lq.tpPrice;
         origin = "LiquidityScalp MSS";
         g_tel.lqSignalsFound++;
         return true;
      }

      if(!farEnoughForPending)
      {
         if(g_lq.entryModeUsed == HYBRID)
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[LQ_HYBRID] reteste muito proximo para pendente | dist=%.5f | tol=%.5f | fallback=market",
                                  distToRetest, tol));
            BuildLiquidityTradeLevels(g_lq.direction, atr, soft, 0.0, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
            direction = g_lq.direction;
            entryPrice = g_lq.entryPrice;
            stop = g_lq.slPrice;
            target = g_lq.tpPrice;
            origin = "LiquidityScalp Hybrid Immediate Market";
            g_tel.lqSignalsFound++;
            return true;
         }

         // LIMIT puro: espera distanciamento para evitar preenchimento instantaneo.
         return false;
      }

      BuildLiquidityTradeLevels(g_lq.direction, atr, soft, g_lq.pendingPrice, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
      direction = g_lq.direction;
      entryPrice = g_lq.entryPrice;
      stop = g_lq.slPrice;
      target = g_lq.tpPrice;
      usePendingOrder = true;
      origin = (g_lq.entryModeUsed == HYBRID ? "LiquidityScalp Hybrid Pending" : "LiquidityScalp Limit Retest");
      g_tel.lqSignalsFound++;
      return true;
   }

   if(g_lq.state == LQ_MSS && !g_lq.hasPending)
   {
      const int barsSinceMss = BarsSinceBarTime(g_lq.mssTime);
      if(barsSinceMss > MathMax(1, P.lqRetestMaxAgeBars))
      {
         HardResetLiquidity("MSS expirado sem ordem");
         return false;
      }

      if(g_lq.entryModeUsed == MARKET_ON_MSS)
         return false;

      const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      const double tol = atr * MathMax(0.01, P.lqRetestTolAtr);
      const double pendingPx = (g_lq.pendingPrice > 0.0
                                ? g_lq.pendingPrice
                                : ComputeLiquidityRetestPrice(g_lq.direction, g_lq.swingLevel, atr));
      const double distToRetest = (g_lq.direction > 0
                                   ? (ask - pendingPx)
                                   : (pendingPx - bid));
      const bool farEnoughForPending = (distToRetest > tol);

      if(!farEnoughForPending)
      {
         if(g_lq.entryModeUsed == HYBRID)
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[LQ_HYBRID] pendente ainda proxima | dist=%.5f | tol=%.5f | market fallback",
                                  distToRetest, tol));
            BuildLiquidityTradeLevels(g_lq.direction, atr, soft, 0.0, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
            direction = g_lq.direction;
            entryPrice = g_lq.entryPrice;
            stop = g_lq.slPrice;
            target = g_lq.tpPrice;
            origin = "LiquidityScalp Hybrid Market Retry";
            g_tel.lqSignalsFound++;
            return true;
         }
         return false;
      }

      g_lq.pendingPrice = pendingPx;
      BuildLiquidityTradeLevels(g_lq.direction, atr, soft, g_lq.pendingPrice, g_lq.entryPrice, g_lq.slPrice, g_lq.tpPrice);
      direction = g_lq.direction;
      entryPrice = g_lq.entryPrice;
      stop = g_lq.slPrice;
      target = g_lq.tpPrice;
      usePendingOrder = true;
      origin = (g_lq.entryModeUsed == HYBRID ? "LiquidityScalp Hybrid Pending Retry" : "LiquidityScalp Limit Retest Retry");
      g_tel.lqSignalsFound++;
      return true;
   }

   return false;
}

int BarsSinceBarTime(const datetime barTime)
{
   if(barTime <= 0 || g_lastBarTime <= 0)
      return 1000000;

   const int sec = PeriodSeconds(P.tf);
   if(sec <= 0)
      return 1000000;

   int bars = (int)((g_lastBarTime - barTime) / sec);
   if(bars < 0)
      bars = 0;
   return bars;
}

double CurrentDailyDDPct()
{
   if(g_dayStartEquity <= 0.0)
      return 0.0;

   double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      equity = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equity <= 0.0)
      return 0.0;

   const double ddPct = ((g_dayStartEquity - equity) / g_dayStartEquity) * 100.0;
   return MathMax(0.0, ddPct);
}

bool IsAdaptiveFallbackTriggered()
{
   if(InpAdaptFallbackDdFrac <= 0.0 || g_baseParams.maxDailyDDPct <= 0.0)
      return false;

   const double threshold = g_baseParams.maxDailyDDPct * InpAdaptFallbackDdFrac;
   return (CurrentDailyDDPct() >= threshold);
}

int EvaluateMarketRegime(const double atr,
                         const double pascalAtr,
                         const double slope,
                         const int trendDir,
                         const double spreadFrac,
                         const double winrate,
                         const int outcomeSamples,
                         const bool ddStress)
{
   if(ddStress)
      return RegimeDefense;

   if(g_consecLosses >= MathMax(2, g_baseParams.maxConsecLosses - 1))
      return RegimeDefense;

   if(atr <= 0.0 || pascalAtr <= 0.0)
      return RegimeBase;

   const double spreadBase = (g_baseParams.maxSpreadAtrFrac > 0.0 ? g_baseParams.maxSpreadAtrFrac : 0.12);
   if(spreadFrac > spreadBase * 1.45)
      return RegimeDefense;

   const double volRatio = atr / pascalAtr;
   const double trendStrength = MathAbs(slope) / atr;
   const bool strongTrend = (trendDir != 0 && trendStrength >= g_baseParams.minTrendStrengthAtr * 1.00);
   const bool weakTrend = (trendStrength < g_baseParams.minTrendStrengthAtr * 0.55);
   const bool highVol = (volRatio >= g_baseParams.atrFilterMult * 0.95);

   if(outcomeSamples >= InpAdaptMinOutcomeSamples)
   {
      if(winrate < 0.30)
         return RegimeDefense;

      if(winrate > 0.55 && strongTrend && spreadFrac <= spreadBase * 1.10)
         return RegimeTrend;
   }

   if(strongTrend && highVol && spreadFrac <= spreadBase * 1.30)
      return RegimeTrend;

   if(weakTrend || volRatio < 0.82)
      return RegimeChoppy;

   return RegimeBase;
}

void BuildAdaptiveParamsForRegime(const int regime, const StrategyMode strategyMode, Params &outP)
{
   outP = g_baseParams;
   // No modo Adaptive, o runtime mode precisa efetivamente trocar os modulos.
   if(Mode == Adaptive || InpModeForceModules)
      ApplyStrategyModeToParams(outP, strategyMode);

   double riskMult = 1.0;
   double atrFilterMult = 1.0;
   double trendMult = 1.0;
   double bodyMult = 1.0;
   double closeDelta = 0.0;
   double spreadMult = 1.0;
   double tpMult = 1.0;
   double beTriggerMult = 1.0;
   double trailStartMult = 1.0;
   double trailDistMult = 1.0;
   double maxTradesMult = 1.0;

   switch(regime)
   {
      case RegimeTrend:
         riskMult = 1.05;
         atrFilterMult = 0.90;
         trendMult = 0.85;
         bodyMult = 0.85;
         closeDelta = -0.04;
         spreadMult = 1.12;
         tpMult = 1.10;
         beTriggerMult = 0.80;
         trailStartMult = 0.80;
         trailDistMult = 0.90;
         maxTradesMult = 1.40;
         break;

      case RegimeChoppy:
         riskMult = 0.95;
         atrFilterMult = 0.98;
         trendMult = 0.95;
         bodyMult = 0.95;
         closeDelta = -0.01;
         spreadMult = 1.00;
         tpMult = 0.95;
         beTriggerMult = 0.90;
         trailStartMult = 0.90;
         trailDistMult = 0.95;
         maxTradesMult = 1.20;
         break;

      case RegimeDefense:
         riskMult = 0.50;
         atrFilterMult = 1.10;
         trendMult = 1.15;
         bodyMult = 1.10;
         closeDelta = 0.02;
         spreadMult = 0.90;
         tpMult = 0.85;
         beTriggerMult = 0.85;
         trailStartMult = 0.95;
         trailDistMult = 0.95;
         maxTradesMult = 0.70;
         break;

      default:
         break;
   }

   const double riskCap = (Profile == Aggressive ? 1.25 : 0.80);
   outP.riskPct = ClampValue(outP.riskPct * riskMult, 0.10, MathMin(riskCap, g_baseParams.riskPct * 1.20));
   outP.atrFilterMult = ClampValue(outP.atrFilterMult * atrFilterMult, 0.70, 1.80);
   outP.minTrendStrengthAtr = ClampValue(outP.minTrendStrengthAtr * trendMult, 0.02, 0.40);
   outP.breakoutBodyAtrMin = ClampValue(outP.breakoutBodyAtrMin * bodyMult, 0.05, 0.80);
   outP.breakoutCloseStrengthMin = ClampValue(outP.breakoutCloseStrengthMin + closeDelta, 0.45, 0.85);
   outP.maxSpreadAtrFrac = ClampValue(outP.maxSpreadAtrFrac * spreadMult, 0.05, 0.35);
   outP.tpAtrMult = ClampValue(outP.tpAtrMult * tpMult, 0.80, 6.00);
   outP.breakEvenAtrTrigger = ClampValue(outP.breakEvenAtrTrigger * beTriggerMult, 0.30, 3.00);
   outP.trailStartAtr = ClampValue(outP.trailStartAtr * trailStartMult, 0.30, 4.00);
   outP.trailAtrMult = ClampValue(outP.trailAtrMult * trailDistMult, 0.80, 6.00);

   const int maxTrades = (int)MathRound((double)g_baseParams.maxTradesPerDay * maxTradesMult);
   const int adaptiveMinTrades = (Profile == Safe ? 3 : 2);
   outP.maxTradesPerDay = MathMax(adaptiveMinTrades, maxTrades);
}

bool CanCommitAdaptiveChange()
{
   if(g_adaptChangesToday >= InpAdaptMaxChangesPerDay)
      return false;

   const int barsSince = BarsSinceBarTime(g_lastRegimeChangeBar);
   if(barsSince < InpAdaptMinBarsBetweenChanges)
      return false;

   return true;
}

void UpdateAdaptiveParams(const double atr, const double pascalAtr, const double slope, const int trendDir)
{
   P = g_baseParams;

   if(Mode != Adaptive)
   {
      g_runtimeMode = Mode;
      if(InpModeForceModules)
         ApplyStrategyModeToParams(P, g_runtimeMode);
      return;
   }

   if(!g_adaptiveEnabled)
   {
      g_runtimeMode = Pullback;
      if(InpModeForceModules)
         ApplyStrategyModeToParams(P, g_runtimeMode);
      return;
   }

   const double spread = CurrentSpreadPrice();
   const double spreadFrac = (atr > 0.0 ? spread / atr : 0.0);
   const int outcomeSamples = ArraySize(g_outcomes);
   const double winrate = RollingWinrate();
   const bool ddStress = IsAdaptiveFallbackTriggered();
   const double ddPct = CurrentDailyDDPct();
   const double trendStrength = (atr > 0.0 ? MathAbs(slope) / atr : 0.0);
   const double volRatio = (pascalAtr > 0.0 ? atr / pascalAtr : 1.0);

   int regime = EvaluateMarketRegime(atr,
                                     pascalAtr,
                                     slope,
                                     trendDir,
                                     spreadFrac,
                                     winrate,
                                     outcomeSamples,
                                     ddStress);

   if(regime != g_candidateRegime)
   {
      g_candidateRegime = regime;
      g_candidateRegimeBars = 1;
   }
   else
   {
      g_candidateRegimeBars++;
   }

   const bool confirmed = (g_candidateRegimeBars >= InpAdaptConfirmBars);

   int targetRegime = g_activeRegime;
   if(confirmed)
      targetRegime = regime;

   if(targetRegime != g_activeRegime)
   {
      const bool forceDefense = (targetRegime == RegimeDefense);
      if(forceDefense || CanCommitAdaptiveChange())
      {
         g_activeRegime = targetRegime;
         g_lastRegimeChangeBar = g_lastBarTime;
         if(!forceDefense)
            g_adaptChangesToday++;

         PrintFormat("Adaptive live | regime=%s | changesToday=%d/%d | spreadATR=%.3f | trendATR=%.3f | volRatio=%.3f | winrate=%.2f%% | dd=%.2f%%",
                     MarketRegimeToString(g_activeRegime),
                     g_adaptChangesToday,
                     InpAdaptMaxChangesPerDay,
                     spreadFrac,
                     trendStrength,
                     volRatio,
                     winrate * 100.0,
                     ddPct);
      }
   }

   const StrategyMode nextMode = StrategyModeFromRegime(g_activeRegime);
   if(nextMode != g_runtimeMode)
   {
      const StrategyMode oldMode = g_runtimeMode;
      const bool preservePullbackSetup = (g_setup.active &&
                                          StrategyModeUsesPullbackSetup(oldMode) &&
                                          StrategyModeUsesPullbackSetup(nextMode));
      g_runtimeMode = nextMode;
      if(!preservePullbackSetup)
      {
         ResetPullbackSetup("Troca de modo adaptativo");
      }
      else
      {
         PrintFormat("Setup Fibonacci preservado | modo=%s -> %s | dir=%d | barras=%d/%d",
                     StrategyModeToString(oldMode),
                     StrategyModeToString(g_runtimeMode),
                     g_setup.direction,
                     g_setup.barsElapsed,
                     P.fiboMaxBarsToTrigger);
      }
      PrintFormat("Adaptive mode switch | %s -> %s | regime=%s",
                  StrategyModeToString(oldMode),
                  StrategyModeToString(g_runtimeMode),
                  MarketRegimeToString(g_activeRegime));
   }

   const RiskProfile newProfile = ProfileFromRegime(g_activeRegime);
   if(newProfile != Profile)
   {
      const RiskProfile oldProfile = Profile;
      Profile = newProfile;
      LogAndPersist(StringFormat("[PROFILE_INTERNAL] %s -> %s | regime=%s",
                                 RiskProfileToString(oldProfile),
                                 RiskProfileToString(Profile),
                                 MarketRegimeToString(g_activeRegime)));
   }

   BuildAdaptiveParamsForRegime(g_activeRegime, g_runtimeMode, P);
   PrintFormat("Adaptive state | regime=%s | mode=%s | risk=%.3f | atrFilter=%.3f | minSlope=%.3f | body=%.3f | close=%.2f | spread=%.3f",
               MarketRegimeToString(g_activeRegime),
               StrategyModeToString(g_runtimeMode),
               P.riskPct,
               P.atrFilterMult,
               P.minTrendStrengthAtr,
               P.breakoutBodyAtrMin,
               P.breakoutCloseStrengthMin,
               P.maxSpreadAtrFrac);
}

bool HasOpenPositionOnSymbol(const bool onlyOurMagic)
{
   const bool hedging = IsHedgingAccount();

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) == _Symbol)
      {
         if(onlyOurMagic && hedging)
         {
            const long magic = PositionGetInteger(POSITION_MAGIC);
            if(!IsOurMagic(magic))
               continue;
         }
         return true;
      }
   }
   return false;
}

int CountOurOpenPositionsOnSymbol(const int direction)
{
   int count = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(magic))
         continue;

      if(direction > 0 && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_BUY)
         continue;
      if(direction < 0 && PositionGetInteger(POSITION_TYPE) != POSITION_TYPE_SELL)
         continue;

      count++;
   }

   return count;
}

bool IsLiquidityScaleInEligible(const int direction, const double atr)
{
   if(!IsLive247LiquidityTemplate() || g_live247Profile != L247_PUSH)
      return false;
   if(direction == 0 || atr <= 0.0)
      return false;
   if(g_live247ScaleInsToday >= 2)
      return false;

   int sameDirCount = 0;
   bool profitableWinner = false;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(magic))
         continue;

      const long posType = PositionGetInteger(POSITION_TYPE);
      const int posDir = (posType == POSITION_TYPE_BUY ? 1 : -1);
      if(posDir != direction)
         return false;

      sameDirCount++;
      if(sameDirCount > 1)
         return false;

      const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double profitDist = (direction > 0 ? (bid - openPrice) : (openPrice - ask));
      if(profitDist >= (atr * 0.80))
         profitableWinner = true;
   }

   return (sameDirCount == 1 && profitableWinner);
}

bool IsPositionAlreadyProcessed(const long positionId)
{
   const int total = ArraySize(g_processedPositionIds);
   for(int i = 0; i < total; i++)
   {
      if(g_processedPositionIds[i] == positionId)
         return true;
   }
   return false;
}

void MarkPositionProcessed(const long positionId)
{
   const int oldSize = ArraySize(g_processedPositionIds);
   ArrayResize(g_processedPositionIds, oldSize + 1);
   g_processedPositionIds[oldSize] = positionId;

   const int keep = 2000;
   const int now = ArraySize(g_processedPositionIds);
   if(now <= keep)
      return;

   const int drop = now - keep;
   for(int i = 0; i < keep; i++)
      g_processedPositionIds[i] = g_processedPositionIds[i + drop];

   ArrayResize(g_processedPositionIds, keep);
}

bool IsPositionStillOpen(const long positionId)
{
   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      const long identifier = PositionGetInteger(POSITION_IDENTIFIER);
      if(identifier == positionId)
         return true;
   }
   return false;
}

bool ComputeClosedPositionProfit(const long positionId, double &profit)
{
   profit = 0.0;
   if(positionId <= 0)
      return false;

   if(!HistorySelectByPosition((ulong)positionId))
      return false;

   bool found = false;
   const int dealsTotal = HistoryDealsTotal();
   for(int i = 0; i < dealsTotal; i++)
   {
      const ulong dealTicket = HistoryDealGetTicket(i);
      if(dealTicket == 0)
         continue;

      if(!IsOurMagic((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC)))
         continue;
      if(HistoryDealGetString(dealTicket, DEAL_SYMBOL) != _Symbol)
         continue;

      const ENUM_DEAL_TYPE dealType = (ENUM_DEAL_TYPE)HistoryDealGetInteger(dealTicket, DEAL_TYPE);
      if(dealType != DEAL_TYPE_BUY && dealType != DEAL_TYPE_SELL)
         continue;

      profit += HistoryDealGetDouble(dealTicket, DEAL_PROFIT)
              + HistoryDealGetDouble(dealTicket, DEAL_SWAP)
              + HistoryDealGetDouble(dealTicket, DEAL_COMMISSION);
      found = true;
   }

   return found;
}

bool TryUpdateOutcomeFromClosedPosition(const long positionId)
{
   if(positionId <= 0)
      return false;
   if(IsPositionAlreadyProcessed(positionId))
      return false;
   if(IsPositionStillOpen(positionId))
      return false;

   double profit = 0.0;
   if(!ComputeClosedPositionProfit(positionId, profit))
   {
      PrintFormat("Falha ao consolidar resultado da posicao %I64d.", positionId);
      return false;
   }

   const bool win = (profit > 0.0);
   AppendOutcome(win ? 1 : 0);
   AppendClosedPnl(profit);

   if(win)
      g_consecLosses = 0;
   else
      g_consecLosses++;

   MarkPositionProcessed(positionId);
   PrintFormat("Resultado consolidado | posId=%I64d | lucro=%.2f | win=%s | perdasConsec=%d",
               positionId, profit, (win ? "true" : "false"), g_consecLosses);
   return true;
}

int RequiredBars()
{
   int n = P.lookback + 10;
   n = MathMax(n, P.atrMaLen + 10);
   n = MathMax(n, P.swingLookback + 10);
   n = MathMax(n, P.entropyLen + 10);
   n = MathMax(n, P.autocorrLen + 10);
   n = MathMax(n, P.pascalLenPrice + 10);
   n = MathMax(n, P.pascalLenATR + 10);
   if(P.useAtrRegimeGate)
      n = MathMax(n, P.regimeAtrMaLen + 10);
   if(P.useDynamicSpreadGate)
      n = MathMax(n, P.spreadMedianLen + 10);
   return n;
}

bool HasEnoughData()
{
   return (Bars(_Symbol, P.tf) >= RequiredBars());
}

double GetATR(const int shift)
{
   if(g_atrHandle == INVALID_HANDLE)
      return EMPTY_VALUE;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, shift, 1, buf) != 1)
      return EMPTY_VALUE;

   return buf[0];
}

double ATR_SMA_Long(const int len, const int shift)
{
   const int useLen = MathMax(1, len);
   if(g_atrHandle == INVALID_HANDLE)
      return EMPTY_VALUE;

   double buf[];
   ArrayResize(buf, useLen);
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_atrHandle, 0, shift, useLen, buf) < useLen)
      return EMPTY_VALUE;

   double sum = 0.0;
   for(int i = 0; i < useLen; i++)
      sum += buf[i];

   return (sum / (double)useLen);
}

double GetADXMain(const int shift)
{
   if(g_adxHandle == INVALID_HANDLE)
      return EMPTY_VALUE;

   double buf[];
   ArraySetAsSeries(buf, true);
   if(CopyBuffer(g_adxHandle, 0, shift, 1, buf) != 1)
      return EMPTY_VALUE;

   return buf[0];
}

double PascalMA_Close(const int shift)
{
   double w[];
   if(!BuildPascalWeights(P.pascalLenPrice, w))
      return EMPTY_VALUE;

   double acc = 0.0;
   for(int i = 0; i < P.pascalLenPrice; i++)
   {
      const double c = iClose(_Symbol, P.tf, shift + i);
      if(c <= 0.0)
         return EMPTY_VALUE;
      acc += c * w[i];
   }
   return acc;
}

double PascalMA_ATR(const int shift)
{
   if(g_atrHandle == INVALID_HANDLE)
      return EMPTY_VALUE;

   double w[];
   if(!BuildPascalWeights(P.pascalLenATR, w))
      return EMPTY_VALUE;

   const int need = shift + P.pascalLenATR;
   double atrBuf[];
   ArrayResize(atrBuf, need);
   ArraySetAsSeries(atrBuf, true);

   if(CopyBuffer(g_atrHandle, 0, 0, need, atrBuf) < need)
      return EMPTY_VALUE;

   double acc = 0.0;
   for(int i = 0; i < P.pascalLenATR; i++)
      acc += atrBuf[shift + i] * w[i];

   return acc;
}

int TrendDirection(double &slope)
{
   const double ma1 = PascalMA_Close(1);
   const double ma2 = PascalMA_Close(2);

   if(ma1 == EMPTY_VALUE || ma2 == EMPTY_VALUE)
   {
      slope = 0.0;
      return 0;
   }

   slope = (ma1 - ma2);
   if(slope > 0.0)
      return 1;
   if(slope < 0.0)
      return -1;
   return 0;
}

int DetectBreakoutDirection(const double atr, string &reason)
{
   reason = "";
   const int lb = P.lookback;

   double refHigh = -DBL_MAX;
   double refLow = DBL_MAX;

   for(int i = 2; i < 2 + lb; i++)
   {
      const double h = iHigh(_Symbol, P.tf, i);
      const double l = iLow(_Symbol, P.tf, i);
      if(h > refHigh)
         refHigh = h;
      if(l < refLow)
         refLow = l;
   }

   const double bh = iHigh(_Symbol, P.tf, 1);
   const double bl = iLow(_Symbol, P.tf, 1);
   const double bo = iOpen(_Symbol, P.tf, 1);
   const double bc = iClose(_Symbol, P.tf, 1);

   const bool upBreak = (bh > refHigh);
   const bool dnBreak = (bl < refLow);

   int direction = 0;
   if(upBreak && !dnBreak)
      direction = 1;
   else if(dnBreak && !upBreak)
      direction = -1;
   else if(upBreak && dnBreak)
      direction = (bc >= bo ? 1 : -1);
   else
   {
      reason = "sem breakout valido";
      return 0;
   }

   const double barRange = (bh - bl);
   if(barRange <= (_Point * 2.0))
   {
      reason = "barra de breakout sem range util";
      return 0;
   }

   const double body = MathAbs(bc - bo);
   if(atr > 0.0 && body < (atr * P.breakoutBodyAtrMin))
   {
      reason = "corpo do breakout fraco";
      return 0;
   }

   if(direction > 0 && bc < bo)
   {
      reason = "breakout de alta fechou em baixa";
      return 0;
   }

   if(direction < 0 && bc > bo)
   {
      reason = "breakout de baixa fechou em alta";
      return 0;
   }

   double closeStrength = 0.0;
   if(direction > 0)
      closeStrength = (bc - bl) / barRange;
   else
      closeStrength = (bh - bc) / barRange;

   if(closeStrength < P.breakoutCloseStrengthMin)
   {
      reason = "fechamento fraco no breakout";
      return 0;
   }

   return direction;
}

bool BuildPullbackSetup(const int direction)
{
   const int swingN = MathMax(P.swingLookback, 5);

   if(direction > 0)
   {
      double swingLow = DBL_MAX;
      for(int i = 2; i < 2 + swingN; i++)
      {
         const double l = iLow(_Symbol, P.tf, i);
         if(l < swingLow)
            swingLow = l;
      }

      const double swingHigh = iHigh(_Symbol, P.tf, 1);
      const double range = swingHigh - swingLow;
      if(range <= (_Point * 10.0))
         return false;

      g_setup.active = true;
      g_setup.direction = 1;
      g_setup.createdBarTime = iTime(_Symbol, P.tf, 1);
      g_setup.barsElapsed = 0;
      g_setup.swingHigh = swingHigh;
      g_setup.swingLow = swingLow;
      g_setup.level1 = swingHigh - range * P.fibo1;
      g_setup.level2 = swingHigh - range * P.fibo2;
      g_setup.level3 = swingHigh - range * P.fibo3;
   }
   else
   {
      double swingHigh = -DBL_MAX;
      for(int i = 2; i < 2 + swingN; i++)
      {
         const double h = iHigh(_Symbol, P.tf, i);
         if(h > swingHigh)
            swingHigh = h;
      }

      const double swingLow = iLow(_Symbol, P.tf, 1);
      const double range = swingHigh - swingLow;
      if(range <= (_Point * 10.0))
         return false;

      g_setup.active = true;
      g_setup.direction = -1;
      g_setup.createdBarTime = iTime(_Symbol, P.tf, 1);
      g_setup.barsElapsed = 0;
      g_setup.swingHigh = swingHigh;
      g_setup.swingLow = swingLow;
      g_setup.level1 = swingLow + range * P.fibo1;
      g_setup.level2 = swingLow + range * P.fibo2;
      g_setup.level3 = swingLow + range * P.fibo3;
   }

   PrintFormat("Setup Fibonacci criado | dir=%d | L38=%.5f | L50=%.5f | L61=%.5f",
               g_setup.direction, g_setup.level1, g_setup.level2, g_setup.level3);
   return true;
}

void AgePullbackSetup()
{
   if(!g_setup.active)
      return;

   g_setup.barsElapsed++;
   if(g_setup.barsElapsed > P.fiboMaxBarsToTrigger)
      ResetPullbackSetup("Expirou sem trigger");
}

bool IsLevelTouched(const double level, const double atr)
{
   const double tol = atr * P.fiboTolAtr;
   const double zl = level - tol;
   const double zh = level + tol;

   const double barLow = iLow(_Symbol, P.tf, 1);
   const double barHigh = iHigh(_Symbol, P.tf, 1);

   return (barHigh >= zl && barLow <= zh);
}

bool IsPullbackTriggered(const double atr)
{
   if(!g_setup.active)
      return false;

   if(IsLevelTouched(g_setup.level1, atr))
      return true;
   if(IsLevelTouched(g_setup.level2, atr))
      return true;
   if(IsLevelTouched(g_setup.level3, atr))
      return true;
   return false;
}

double CalcHurstRS(const int len, const int shift)
{
   if(len < 20)
      return EMPTY_VALUE;

   const int need = len + shift + 2;
   double closeBuf[];
   ArrayResize(closeBuf, need);
   ArraySetAsSeries(closeBuf, true);

   if(CopyClose(_Symbol, P.tf, 0, need, closeBuf) < need)
      return EMPTY_VALUE;

   const int n = len - 1;
   if(n < 10)
      return EMPTY_VALUE;

   double mean = 0.0;
   for(int i = 0; i < n; i++)
      mean += (closeBuf[shift + i] - closeBuf[shift + i + 1]);
   mean /= (double)n;

   double cum = 0.0;
   double maxCum = -DBL_MAX;
   double minCum = DBL_MAX;
   double var = 0.0;

   for(int i = 0; i < n; i++)
   {
      const double r = (closeBuf[shift + i] - closeBuf[shift + i + 1]) - mean;
      cum += r;
      if(cum > maxCum)
         maxCum = cum;
      if(cum < minCum)
         minCum = cum;
      var += (r * r);
   }

   const double R = maxCum - minCum;
   const double S = MathSqrt(var / (double)n);
   if(R <= 0.0 || S <= 0.0)
      return 0.5;

   double H = MathLog(R / S) / MathLog((double)n);
   if(H < 0.0) H = 0.0;
   if(H > 1.0) H = 1.0;
   return H;
}

double EntropyPart(const double p)
{
   if(p <= 0.0)
      return 0.0;
   return -(p * MathLog(p));
}

double CalcDirectionEntropy(const int len, const int shift)
{
   if(len < 10)
      return EMPTY_VALUE;

   const int need = len + shift + 2;
   double openBuf[], closeBuf[];
   ArrayResize(openBuf, need);
   ArrayResize(closeBuf, need);
   ArraySetAsSeries(openBuf, true);
   ArraySetAsSeries(closeBuf, true);

   if(CopyOpen(_Symbol, P.tf, 0, need, openBuf) < need)
      return EMPTY_VALUE;
   if(CopyClose(_Symbol, P.tf, 0, need, closeBuf) < need)
      return EMPTY_VALUE;

   int up = 0, down = 0, flat = 0;
   for(int i = shift; i < shift + len; i++)
   {
      const double d = closeBuf[i] - openBuf[i];
      if(d > (_Point * 0.1))
         up++;
      else if(d < (-_Point * 0.1))
         down++;
      else
         flat++;
   }

   const double pUp = (double)up / (double)len;
   const double pDn = (double)down / (double)len;
   const double pFl = (double)flat / (double)len;

   const double h = EntropyPart(pUp) + EntropyPart(pDn) + EntropyPart(pFl);
   const double hNorm = h / MathLog(3.0);
   return hNorm;
}

double CalcAutocorrLag1(const int len, const int shift)
{
   if(len < 10)
      return EMPTY_VALUE;

   const int need = len + shift + 3;
   double closeBuf[];
   ArrayResize(closeBuf, need);
   ArraySetAsSeries(closeBuf, true);

   if(CopyClose(_Symbol, P.tf, 0, need, closeBuf) < need)
      return EMPTY_VALUE;

   const int n = len;
   double xMean = 0.0;
   double yMean = 0.0;

   for(int i = 0; i < n; i++)
   {
      const double x = closeBuf[shift + i] - closeBuf[shift + i + 1];
      const double y = closeBuf[shift + i + 1] - closeBuf[shift + i + 2];
      xMean += x;
      yMean += y;
   }
   xMean /= (double)n;
   yMean /= (double)n;

   double cov = 0.0;
   double vx = 0.0;
   double vy = 0.0;

   for(int i = 0; i < n; i++)
   {
      const double x = (closeBuf[shift + i] - closeBuf[shift + i + 1]) - xMean;
      const double y = (closeBuf[shift + i + 1] - closeBuf[shift + i + 2]) - yMean;
      cov += (x * y);
      vx += (x * x);
      vy += (y * y);
   }

   if(vx <= 0.0 || vy <= 0.0)
      return 0.0;

   double corr = cov / MathSqrt(vx * vy);
   if(corr > 1.0) corr = 1.0;
   if(corr < -1.0) corr = -1.0;
   return corr;
}

bool CheckQuantFilters(double &hurst, double &entropy, double &autocorr, string &reason)
{
   hurst = -1.0;
   entropy = -1.0;
   autocorr = -1.0;
   reason = "";

   if(P.useHurst)
   {
      const int hurstLen = (Profile == Safe ? 128 : 96);
      hurst = CalcHurstRS(hurstLen, 1);
      if(hurst == EMPTY_VALUE)
      {
         reason = "Hurst indisponivel";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }

      PrintFormat("Filtro Hurst | valor=%.4f | minimo=%.4f", hurst, P.hurstMin);
      if(hurst < P.hurstMin)
      {
         reason = "Hurst abaixo do minimo";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }
   }

   if(P.useEntropy)
   {
      entropy = CalcDirectionEntropy(P.entropyLen, 1);
      if(entropy == EMPTY_VALUE)
      {
         reason = "Entropy indisponivel";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }

      PrintFormat("Filtro Entropy | valor=%.4f | maximo=%.4f", entropy, P.entropyMax);
      if(entropy > P.entropyMax)
      {
         reason = "Entropy acima do maximo";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }
   }

   if(P.useAutocorr)
   {
      autocorr = CalcAutocorrLag1(P.autocorrLen, 1);
      if(autocorr == EMPTY_VALUE)
      {
         reason = "Autocorrelacao indisponivel";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }

      PrintFormat("Filtro Autocorr | valor=%.4f | minimo abs=%.4f",
                  autocorr, P.autocorrMinAbs);
      if(MathAbs(autocorr) < P.autocorrMinAbs)
      {
         reason = "Autocorrelacao abaixo do minimo";
         LogBlockThrottled("Bloqueio: " + reason);
         return false;
      }
   }

   PrintFormat("Quant values | Hurst=%.4f | Entropy=%.4f | Autocorr=%.4f",
               hurst, entropy, autocorr);

   return true;
}

void AppendOutcome(const int win)
{
   const int oldSize = ArraySize(g_outcomes);
   ArrayResize(g_outcomes, oldSize + 1);
   g_outcomes[oldSize] = (win > 0 ? 1 : 0);

   const int keep = 1000;
   const int now = ArraySize(g_outcomes);
   if(now <= keep)
      return;

   const int drop = now - keep;
   for(int i = 0; i < keep; i++)
      g_outcomes[i] = g_outcomes[i + drop];

   ArrayResize(g_outcomes, keep);
}

void AppendClosedPnl(const double pnl)
{
   const int oldSize = ArraySize(g_closedPnls);
   ArrayResize(g_closedPnls, oldSize + 1);
   g_closedPnls[oldSize] = pnl;

   const int keep = 2000;
   const int now = ArraySize(g_closedPnls);
   if(now <= keep)
      return;

   const int drop = now - keep;
   for(int i = 0; i < keep; i++)
      g_closedPnls[i] = g_closedPnls[i + drop];

   ArrayResize(g_closedPnls, keep);
}

bool ComputeRecentPerformance(const int windowTrades,
                              double &pf,
                              double &winrate,
                              double &localDdPct,
                              int &samples)
{
   pf = 1.0;
   winrate = 0.50;
   localDdPct = 0.0;
   samples = 0;

   const int nAll = ArraySize(g_closedPnls);
   if(nAll <= 0)
      return false;

   const int window = MathMax(1, windowTrades);
   const int n = MathMin(window, nAll);
   const int start = nAll - n;
   samples = n;

   double grossProfit = 0.0;
   double grossLossAbs = 0.0;
   int wins = 0;

   double equityCurve = 0.0;
   double peakCurve = 0.0;
   double maxDdCash = 0.0;

   for(int i = start; i < nAll; i++)
   {
      const double pnl = g_closedPnls[i];
      if(pnl > 0.0)
      {
         grossProfit += pnl;
         wins++;
      }
      else if(pnl < 0.0)
      {
         grossLossAbs += (-pnl);
      }

      equityCurve += pnl;
      if(equityCurve > peakCurve)
         peakCurve = equityCurve;

      const double ddNow = peakCurve - equityCurve;
      if(ddNow > maxDdCash)
         maxDdCash = ddNow;
   }

   winrate = ((double)wins / (double)n);
   if(grossLossAbs > 0.0)
      pf = grossProfit / grossLossAbs;
   else if(grossProfit > 0.0)
      pf = 99.0;

   double equityRef = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equityRef <= 0.0)
      equityRef = AccountInfoDouble(ACCOUNT_BALANCE);
   if(equityRef <= 0.0)
      equityRef = 1.0;

   localDdPct = (maxDdCash / equityRef) * 100.0;
   return true;
}

double RollingWinrate()
{
   const int nAll = ArraySize(g_outcomes);
   if(nAll <= 0)
      return 0.50;

   const int n = MathMin(P.winrateLen, nAll);
   int wins = 0;
   for(int i = nAll - n; i < nAll; i++)
      wins += g_outcomes[i];

   return ((double)wins / (double)n);
}

double RiskFactorFromProbability(double &winrate, double &seqLossProb)
{
   winrate = RollingWinrate();
   const int streakLen = MathMax(1, P.maxConsecLosses);
   seqLossProb = MathPow(1.0 - winrate, streakLen);

   double factor = 1.0;
   if(P.useProbRiskAdjust && seqLossProb > P.seqLossProbMax)
      factor = (P.seqLossProbMax / seqLossProb);

   if(factor > 1.0) factor = 1.0;
   if(factor < P.minRiskFactor) factor = P.minRiskFactor;
   return factor;
}

double CalcVolumeByRisk(const double riskPct, const double entryPrice, const double stopPrice)
{
   if(riskPct <= 0.0)
      return 0.0;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(equity <= 0.0)
      return 0.0;

   const double riskMoney = equity * riskPct * 0.01;

   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE_LOSS);
   if(tickValue <= 0.0)
      tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   if(tickValue <= 0.0 || tickSize <= 0.0)
      return 0.0;

   const double stopDist = MathAbs(entryPrice - stopPrice);
   if(stopDist <= 0.0)
      return 0.0;

   const double lossPerLot = (stopDist / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   const double rawLot = (riskMoney / lossPerLot);
   return NormalizeVolume(rawLot);
}

double ComputeMinProtectionDistancePrice()
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(point <= 0.0)
      return 0.0;

   const double stopLevelPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL);
   const double freezeLevelPts = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL);
   const double spreadPts = CurrentSpreadPoints();
   const double spreadBufferPts = MathMax(0.0, spreadPts * MathMax(0.0, P.stopSpreadBufferMult));
   const double minDistPts = MathMax(1.0, stopLevelPts + freezeLevelPts + spreadBufferPts);
   return (minDistPts * point);
}

double EnforceStopDistance(const int direction, const double entry, double stop)
{
   const double minDist = ComputeMinProtectionDistancePrice();

   if(direction > 0)
   {
      if((entry - stop) < minDist)
         stop = entry - minDist;
   }
   else
   {
      if((stop - entry) < minDist)
         stop = entry + minDist;
   }

   return NormalizePrice(stop);
}

double EnforceTargetDistance(const int direction, const double entry, double target)
{
   const double minDist = ComputeMinProtectionDistancePrice();

   if(direction > 0)
   {
      if((target - entry) < minDist)
         target = entry + minDist;
   }
   else
   {
      if((entry - target) < minDist)
         target = entry - minDist;
   }

   return NormalizePrice(target);
}

bool ModifyPositionStops(const ulong ticket,
                         const string symbol,
                         const double sl,
                         const double tp,
                         int &retcode,
                         string &comment)
{
   retcode = 0;
   comment = "";

   MqlTradeRequest req;
   MqlTradeResult res;
   ZeroMemory(req);
   ZeroMemory(res);

   req.action = TRADE_ACTION_SLTP;
   req.symbol = symbol;
   req.position = ticket;
   req.sl = (sl > 0.0 ? NormalizePrice(sl) : 0.0);
   req.tp = (tp > 0.0 ? NormalizePrice(tp) : 0.0);
   req.magic = MAGIC_NUMBER;

   const bool sent = OrderSend(req, res);
   retcode = (int)res.retcode;
   comment = res.comment;

   if(!sent)
      return false;

   return (res.retcode == TRADE_RETCODE_DONE);
}

bool CanPassTradeGuards()
{
   if(g_killSwitch)
   {
      g_tel.killSwitchBlocks++;
      LogBlockThrottled("Bloqueio: kill switch diario ativo.");
      return false;
   }

   if(g_tradesToday >= P.maxTradesPerDay)
   {
      LogBlockThrottled("Bloqueio: limite de trades diarios atingido",
                        StringFormat("max=%d", P.maxTradesPerDay));
      return false;
   }

   if(g_consecLosses >= P.maxConsecLosses)
   {
      LogBlockThrottled("Bloqueio: limite de perdas consecutivas atingido",
                        StringFormat("max=%d", P.maxConsecLosses));
      return false;
   }

   if(!IsInSession())
   {
      LogBlockThrottled("Bloqueio: fora da janela de sessao.");
      return false;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      LogBlockThrottled("Bloqueio: trading nao permitido pelo terminal/EA.");
      return false;
   }

   if(AccountInfoDouble(ACCOUNT_MARGIN_FREE) <= 0.0)
   {
      LogBlockThrottled("Bloqueio: margem livre insuficiente.");
      return false;
   }

   return true;
}

bool CanOpenTradeNow()
{
   if(!CanPassTradeGuards())
      return false;

   if(P.onePosPerSymbol && HasOpenPositionOnSymbol(true))
   {
      LogBlockThrottled("Bloqueio: ja existe posicao bloqueante no simbolo.");
      return false;
   }

   return true;
}

bool IsAtrRegimeGateApproved(const double atr, string &reason)
{
   reason = "";
   if(!P.useAtrRegimeGate)
      return true;

   if(atr <= 0.0)
   {
      reason = "ATR invalido";
      return false;
   }

   const int maLen = MathMax(10, P.regimeAtrMaLen);
   const double atrLong = ATR_SMA_Long(maLen, 1);
   if(atrLong == EMPTY_VALUE || atrLong <= 0.0)
   {
      reason = StringFormat("ATR_MA(%d) indisponivel", maLen);
      return false;
   }

   const double mult = MathMax(0.10, P.regimeAtrMult);
   const double minAtr = atrLong * mult;
   if(atr <= minAtr)
   {
      reason = StringFormat("ATR=%.5f <= ATR_MA(%d)*%.2f (%.5f)",
                            atr,
                            maLen,
                            mult,
                            minAtr);
      return false;
   }

   return true;
}

bool IsAutoPauseBlocked(string &reason)
{
   reason = "";
   if(!P.useAutoPause)
      return false;

   const datetime now = CurrentTimeSafe();
   const int window = MathMax(5, P.autoPauseWindowTrades);

   double pf = 1.0;
   double winrate = 0.50;
   double localDdPct = 0.0;
   int samples = 0;
   const bool hasPerf = ComputeRecentPerformance(window, pf, winrate, localDdPct, samples);

   if(g_autoPauseUntil > 0 && now >= g_autoPauseUntil)
   {
      g_autoPauseUntil = 0;
      DebugLog(DBG_SIGNALS, "[AUTO_PAUSE] periodo encerrado; trading reabilitado.");
   }

   if(g_autoPauseUntil > now)
   {
      if(hasPerf && samples >= window &&
         pf >= P.autoPausePfResume &&
         localDdPct <= (P.autoPauseDdStopPct * 0.80))
      {
         g_autoPauseUntil = 0;
         DebugLog(DBG_SIGNALS,
                  StringFormat("[AUTO_PAUSE] liberado antecipadamente | pf=%.2f | dd=%.2f%% | winrate=%.2f%% | amostra=%d",
                               pf,
                               localDdPct,
                               winrate * 100.0,
                               samples));
         return false;
      }

      g_tel.autoPauseBlocks++;
      reason = StringFormat("ativo ate %s | pf=%.2f | dd=%.2f%% | amostra=%d",
                            TimeToString(g_autoPauseUntil, TIME_DATE | TIME_MINUTES),
                            pf,
                            localDdPct,
                            samples);
      return true;
   }

   if(!hasPerf || samples < window)
      return false;

   if(pf < P.autoPausePfStop || localDdPct > P.autoPauseDdStopPct)
   {
      const int holdHours = MathMax(1, P.autoPauseHours);
      g_autoPauseUntil = now + (holdHours * 3600);
      g_tel.autoPauseTriggers++;
      g_tel.autoPauseBlocks++;

      reason = StringFormat("trigger pf=%.2f (<%.2f) dd=%.2f%% (>%.2f%%) amostra=%d pausa=%dh",
                            pf,
                            P.autoPausePfStop,
                            localDdPct,
                            P.autoPauseDdStopPct,
                            samples,
                            holdHours);

      LogAndPersist(StringFormat("[AUTO_PAUSE] acionado | %s", reason));
      if(g_lq.hasPending)
         HardResetLiquidity("Auto-pause acionado");
      return true;
   }

   return false;
}

double ComputePerformanceRiskScale(double &pf, double &winrate, double &localDdPct, int &samples)
{
   pf = 1.0;
   winrate = 0.50;
   localDdPct = 0.0;
   samples = 0;

   if(!P.useRiskLadder)
      return 1.0;

   const int window = MathMax(5, P.riskLadderWindowTrades);
   if(!ComputeRecentPerformance(window, pf, winrate, localDdPct, samples) || samples < window)
      return 1.0;

   double scale = 1.0;
   const double wrPct = winrate * 100.0;

   if(pf > P.riskLadderHighPf &&
      wrPct >= P.riskLadderHighWinrate &&
      localDdPct < P.riskLadderHighDdMaxPct)
   {
      scale = P.riskLadderHighScale;
   }
   else if(pf > P.riskLadderMidPf && wrPct >= P.riskLadderMidWinrate)
   {
      scale = P.riskLadderMidScale;
   }
   else if(pf < P.riskLadderLowPf)
   {
      scale = P.riskLadderLowScale;
   }

   const double maxScale = MathMax(1.0, P.riskLadderMaxScale);
   return ClampValue(scale, 0.10, maxScale);
}

bool CanPassTradeContextGuards(const double atr)
{
   if(!CanPassTradeGuards())
      return false;

   string autoPauseReason = "";
   if(IsAutoPauseBlocked(autoPauseReason))
   {
      LogBlockThrottled("Bloqueio: auto-pause por performance", autoPauseReason);
      return false;
   }

   string regimeReason = "";
   if(!IsAtrRegimeGateApproved(atr, regimeReason))
   {
      g_tel.regimeBlocks++;
      LogBlockThrottled("Bloqueio: regime ATR macro nao aprovado", regimeReason);
      return false;
   }

   return true;
}

bool CanOpenTradeNowWithContext(const double atr)
{
   if(!CanPassTradeContextGuards(atr))
      return false;

   if(P.onePosPerSymbol && HasOpenPositionOnSymbol(true))
   {
      LogBlockThrottled("Bloqueio: ja existe posicao bloqueante no simbolo.");
      return false;
   }

   return true;
}

void ApplyExecutionProfileParams(Params &params, const int execProfile)
{
   const double baseRisk = MathMax(0.05, g_baseParams.riskPct);
   const int baseMaxTrades = MathMax(1, g_baseParams.maxTradesPerDay);

   params.onePosPerSymbol = true; // Mantem sem exposicao simultanea no simbolo.

   if(execProfile == EP_AGGRESSIVE)
   {
      params.riskPct = ClampValue(MathMax(baseRisk, 0.90), 0.05, 1.25);
      params.stopAtrMult = 2.00;
      params.tpAtrMult = 1.70;
      params.lqSweepBufferAtr = 0.55;
      params.lqMinDisplacementAtr = 0.75;
      params.regimeAtrMult = 1.35;
      params.shieldAtrShockMult = 1.35;
      params.maxTradesPerDay = MathMax(baseMaxTrades, (int)MathRound((double)baseMaxTrades * 1.50));
      return;
   }

   if(execProfile == EP_DEFENSIVE)
   {
      params.riskPct = ClampValue(MathMin(baseRisk * 0.50, 0.30), 0.05, 1.25);
      params.stopAtrMult = 2.40;
      params.tpAtrMult = 1.30;
      params.lqSweepBufferAtr = 0.70;
      params.lqMinDisplacementAtr = 0.90;
      params.regimeAtrMult = 1.10;
      params.shieldAtrShockMult = 1.10;
      params.maxTradesPerDay = MathMax(3, (int)MathRound((double)baseMaxTrades * 0.50));
      return;
   }

   // EP_NORMAL
   params.riskPct = ClampValue(baseRisk, 0.05, 1.25);
   params.stopAtrMult = 2.20;
   params.tpAtrMult = 1.50;
   params.lqSweepBufferAtr = 0.60;
   params.lqMinDisplacementAtr = 0.80;
   params.regimeAtrMult = 1.25;
   params.shieldAtrShockMult = 1.25;
   params.maxTradesPerDay = baseMaxTrades;
}

void ApplyRuntimeModeTradeTuning(Params &params)
{
   if(!IsXauUsdM5ManagedTemplate(InpConfigTemplate) || params.tf != PERIOD_M5)
      return;

   // Breakouts em Adaptive precisam stop mais curto e gerenciamento menos ansioso
   // para evitar muitas sa??das pequenas enquanto os poucos erros ficam cheios.
   if(Mode == Adaptive)
   {
      if(g_runtimeMode == Quantum)
      {
         params.riskPct = ClampValue(params.riskPct * 0.85, 0.05, 1.25);
         params.stopAtrMult = MathMin(params.stopAtrMult, 1.00);
         params.tpAtrMult = MathMax(params.tpAtrMult, 2.80);
         params.minTrendStrengthAtr = MathMax(params.minTrendStrengthAtr, 0.038);
         params.breakoutBodyAtrMin = MathMax(params.breakoutBodyAtrMin, 0.10);
         params.breakoutCloseStrengthMin = MathMax(params.breakoutCloseStrengthMin, 0.52);
         params.hurstMin = MathMax(params.hurstMin, 0.56);
         params.autocorrMinAbs = MathMax(params.autocorrMinAbs, 0.12);
         params.breakEvenAtrTrigger = MathMax(params.breakEvenAtrTrigger, 1.35);
         params.breakEvenOffsetPoints = MathMin(params.breakEvenOffsetPoints, 5);
         params.trailStartAtr = MathMax(params.trailStartAtr, 1.70);
         params.trailAtrMult = MathMax(params.trailAtrMult, 1.55);
         params.maxTradesPerDay = MathMax(3, (int)MathRound((double)params.maxTradesPerDay * 0.85));
         return;
      }

      if(g_runtimeMode == Core)
      {
         params.riskPct = ClampValue(params.riskPct * 0.90, 0.05, 1.25);
         params.stopAtrMult = MathMin(params.stopAtrMult, 1.45);
         params.tpAtrMult = MathMax(params.tpAtrMult, 1.85);
         params.breakEvenAtrTrigger = MathMax(params.breakEvenAtrTrigger, 0.85);
         params.breakEvenOffsetPoints = MathMin(params.breakEvenOffsetPoints, 10);
         params.trailStartAtr = MathMax(params.trailStartAtr, 1.10);
         params.trailAtrMult = MathMax(params.trailAtrMult, 1.20);
      }
   }
}

void UpdateExecutionProfile(const double atr, const double pascalAtr)
{
   // Perfil dinamico dedicado ao template XAUUSD M5 RoboForex (tambem como camada final quando Mode=Adaptive).
   if(!IsXauUsdM5ManagedTemplate(InpConfigTemplate) || P.tf != PERIOD_M5)
      return;

   double adx = GetADXMain(1);
   if(adx == EMPTY_VALUE || adx < 0.0)
      adx = 0.0;

   double atrRef = ATR_SMA_Long(MathMax(50, P.regimeAtrMaLen), 1);
   if(atrRef == EMPTY_VALUE || atrRef <= 0.0)
      atrRef = (pascalAtr > 0.0 ? pascalAtr : atr);
   const double volRatio = (atrRef > 0.0 ? atr / atrRef : 1.0);

   const double spreadNow = CurrentSpreadPoints();
   const double spreadMedian = SpreadMedianPoints(MathMax(50, P.spreadMedianLen), 1);
   const double spreadRatio = (spreadMedian > 0.0 ? spreadNow / spreadMedian : 1.0);

   double pfRecent = 1.0, wrRecent = 0.50, localDdPct = 0.0;
   int perfSamples = 0;
   const bool hasPerf = ComputeRecentPerformance(MathMax(10, P.autoPauseWindowTrades),
                                                 pfRecent,
                                                 wrRecent,
                                                 localDdPct,
                                                 perfSamples);

   const bool marketAgg = (spreadRatio <= 1.6 && volRatio >= 1.05 && volRatio <= 1.60 && adx >= 22.0);
   const bool marketDef = (spreadRatio > 2.0 || volRatio > 1.8);

   const bool perfForceDef = (g_consecLosses >= 2) ||
                             (hasPerf && perfSamples >= 10 && localDdPct > 1.50);
   const bool perfBlockAgg = (hasPerf && perfSamples >= 10 &&
                              (pfRecent < 1.10 || localDdPct > 1.20 || g_consecLosses >= 2));

   const bool condAgg = (marketAgg && !perfBlockAgg);
   const bool condDef = (marketDef || perfForceDef);
   const bool condNorm = (!condAgg && !condDef);

   if(condAgg)
   {
      g_execProfileAggrConfirm++;
      g_execProfileNormConfirm = 0;
      g_execProfileDefConfirm = 0;
   }
   else if(condDef)
   {
      g_execProfileDefConfirm++;
      g_execProfileNormConfirm = 0;
      g_execProfileAggrConfirm = 0;
   }
   else
   {
      g_execProfileNormConfirm++;
      g_execProfileAggrConfirm = 0;
      g_execProfileDefConfirm = 0;
   }

   if(g_execProfileLockBars > 0)
      g_execProfileLockBars--;

   int targetProfile = g_execProfile;
   if(g_execProfileLockBars <= 0)
   {
      if(g_execProfileDefConfirm >= 3)
         targetProfile = EP_DEFENSIVE;
      else if(g_execProfileAggrConfirm >= 3)
         targetProfile = EP_AGGRESSIVE;
      else if(g_execProfileNormConfirm >= 3)
         targetProfile = EP_NORMAL;
   }

   if(targetProfile != g_execProfile)
   {
      const int oldProfile = g_execProfile;
      g_execProfile = targetProfile;
      g_execProfileLockBars = 6; // 30 minutos no M5.
      g_execProfileNormConfirm = 0;
      g_execProfileAggrConfirm = 0;
      g_execProfileDefConfirm = 0;

      LogAndPersist(StringFormat("[PROFILE] switch %s -> %s | volRatio=%.2f | adx=%.1f | spreadRatio=%.2f | pf=%.2f | ddLocal=%.2f%% | consecLoss=%d",
                                 ExecProfileToString(oldProfile),
                                 ExecProfileToString(g_execProfile),
                                 volRatio,
                                 adx,
                                 spreadRatio,
                                 pfRecent,
                                 localDdPct,
                                 g_consecLosses));
   }

   ApplyExecutionProfileParams(P, g_execProfile);
   ApplyRuntimeModeTradeTuning(P);

   DebugLog(DBG_VERBOSE,
            StringFormat("[PROFILE] state=%s | lock=%d | volRatio=%.2f | adx=%.1f | spreadRatio=%.2f | perfSamples=%d | pf=%.2f | ddLocal=%.2f%% | risk=%.2f",
                         ExecProfileToString(g_execProfile),
                         g_execProfileLockBars,
                         volRatio,
                         adx,
                         spreadRatio,
                         perfSamples,
                         pfRecent,
                         localDdPct,
                         P.riskPct));
}

bool FindLatestPositionTicket(const long magic, const int direction, ulong &ticketOut)
{
   ticketOut = 0;
   long bestTimeMsc = -1;
   const long desiredType = (direction > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      if(PositionGetInteger(POSITION_MAGIC) != magic)
         continue;

      if(PositionGetInteger(POSITION_TYPE) != desiredType)
         continue;

      const long tmsc = PositionGetInteger(POSITION_TIME_MSC);
      if(tmsc >= bestTimeMsc)
      {
         bestTimeMsc = tmsc;
         ticketOut = ticket;
      }
   }

   return (ticketOut > 0);
}

bool ExecuteEntry(const int direction,
                  const double atr,
                  const string origin,
                  const bool useCustomLevels = false,
                  const double customStop = 0.0,
                  const double customTarget = 0.0,
                  const double softRiskMult = 1.0,
                  const string customComment = "")
{
   if(direction == 0 || atr <= 0.0)
      return false;

   double winrate = 0.0, seqLossProb = 0.0, factor = 0.0;
   const double softMult = ClampValue(softRiskMult, 0.25, 1.50);
   const double effRisk = ComputeEffectiveRiskPct(softMult, winrate, seqLossProb, factor);

   DebugLog(DBG_VERBOSE,
            StringFormat("Ajuste probabilistico | winrate=%.2f%% | p(seqLoss)=%.4f | fator=%.4f | softMult=%.3f | risco final=%.4f%%",
                         winrate * 100.0, seqLossProb, factor, softMult, effRisk));

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (direction > 0 ? ask : bid);

   double stop = customStop;
   if(!useCustomLevels || stop <= 0.0)
   {
      const double stopDist = atr * P.stopAtrMult;
      stop = (direction > 0 ? entry - stopDist : entry + stopDist);
   }
   stop = EnforceStopDistance(direction, entry, stop);

   double target = customTarget;
   if(target > 0.0)
   {
      target = EnforceTargetDistance(direction, entry, target);
   }
   else if(P.useTakeProfit)
   {
      target = (direction > 0 ? entry + (atr * P.tpAtrMult)
                              : entry - (atr * P.tpAtrMult));
      target = EnforceTargetDistance(direction, entry, target);
   }
   else
   {
      target = 0.0;
   }

   const double lot = CalcVolumeByRisk(effRisk, entry, stop);
   if(lot <= 0.0)
   {
      LogBlockThrottled("Bloqueio: lote calculado invalido (<= 0) apos normalizacao.");
      return false;
   }

   const bool isLiquidityOrigin = (StringFind(origin, "LiquidityScalp") >= 0);
   g_trade.SetExpertMagicNumber(isLiquidityOrigin ? LQ_MAGIC_NUMBER : MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(P.maxDeviationPoints);

   string orderComment = customComment;
   if(orderComment == "")
      orderComment = (isLiquidityOrigin ? LQ_COMMENT : "AplexFlow Engine");

   bool ok = false;
   bool usedTwoStep = false;
   if(direction > 0)
      ok = g_trade.Buy(lot, _Symbol, 0.0, stop, target, orderComment);
   else
      ok = g_trade.Sell(lot, _Symbol, 0.0, stop, target, orderComment);

   if(!ok)
   {
      const uint retcode = g_trade.ResultRetcode();
      const string retmsg = g_trade.ResultRetcodeDescription();
      PrintFormat("Falha na entrada | origem=%s | retcode=%u | msg=%s",
                  origin, retcode, retmsg);

      const bool tryTwoStep = (P.useTwoStepExecutionFallback &&
                               (stop > 0.0 || target > 0.0) &&
                               (retcode == TRADE_RETCODE_INVALID_STOPS || retcode == TRADE_RETCODE_INVALID_PRICE));
      if(!tryTwoStep)
         return false;

      DebugLog(DBG_SIGNALS,
               StringFormat("[EXEC_2STEP] fallback ativado | origem=%s | retcode=%u | msg=%s",
                            origin,
                            retcode,
                            retmsg));

      if(direction > 0)
         ok = g_trade.Buy(lot, _Symbol, 0.0, 0.0, 0.0, orderComment);
      else
         ok = g_trade.Sell(lot, _Symbol, 0.0, 0.0, 0.0, orderComment);

      if(!ok)
      {
         PrintFormat("[EXEC_2STEP] falha no passo 1 (sem SL/TP) | origem=%s | retcode=%d | msg=%s",
                     origin,
                     g_trade.ResultRetcode(),
                     g_trade.ResultRetcodeDescription());
         return false;
      }

      usedTwoStep = true;
      ulong posTicket = 0;
      const long expectedMagic = (isLiquidityOrigin ? LQ_MAGIC_NUMBER : MAGIC_NUMBER);
      if(FindLatestPositionTicket(expectedMagic, direction, posTicket))
      {
         int modRetcode = 0;
         string modComment = "";
         if(!ModifyPositionStops(posTicket, _Symbol, stop, target, modRetcode, modComment))
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[EXEC_2STEP] passo 2 falhou | ticket=%I64u | retcode=%d | msg=%s | sl=%.5f | tp=%.5f",
                                  posTicket,
                                  modRetcode,
                                  modComment,
                                  stop,
                                  target));
         }
         else
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[EXEC_2STEP] passo 2 OK | ticket=%I64u | sl=%.5f | tp=%.5f",
                                  posTicket,
                                  stop,
                                  target));
         }
      }
      else
      {
         bool modifiedBySymbol = false;
         if(PositionSelect(_Symbol))
         {
            const long posMagic = PositionGetInteger(POSITION_MAGIC);
            const long posType = PositionGetInteger(POSITION_TYPE);
            const long needType = (direction > 0 ? POSITION_TYPE_BUY : POSITION_TYPE_SELL);
            if(posMagic == expectedMagic && posType == needType)
            {
               const ulong symTicket = (ulong)PositionGetInteger(POSITION_TICKET);
               int modRetcode = 0;
               string modComment = "";
               if(ModifyPositionStops(symTicket, _Symbol, stop, target, modRetcode, modComment))
               {
                  modifiedBySymbol = true;
                  DebugLog(DBG_SIGNALS,
                           StringFormat("[EXEC_2STEP] passo 2 OK via symbol-select | ticket=%I64u | sl=%.5f | tp=%.5f",
                                        symTicket,
                                        stop,
                                        target));
               }
            }
         }

         if(!modifiedBySymbol)
         {
            DebugLog(DBG_SIGNALS,
                     StringFormat("[EXEC_2STEP] passo 2 ignorado: ticket nao localizado | origem=%s | magic=%I64d",
                                  origin,
                                  expectedMagic));
         }
      }
   }

   g_tradesToday++;
   const double resultPrice = g_trade.ResultPrice();
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   if(resultPrice > 0.0 && point > 0.0)
      g_lastExecSlippagePoints = MathAbs(resultPrice - entry) / point;

   PrintFormat("Entrada executada | origem=%s | dir=%s | lote=%.2f | SL=%.5f | TP=%.5f | tradesHoje=%d",
               origin, (direction > 0 ? "BUY" : "SELL"), lot, stop, target, g_tradesToday);

    if(usedTwoStep)
      DebugLog(DBG_SIGNALS,
               StringFormat("[EXEC_2STEP] entrada executada com fallback em 2 etapas | origem=%s",
                            origin));

   if(g_lastExecSlippagePoints > 0.0)
   {
      DebugLog(DBG_VERBOSE,
               StringFormat("[LQ_ENTRY] slippage=%.1f pts | esperado=%.5f | executado=%.5f",
                            g_lastExecSlippagePoints,
                            entry,
                            resultPrice));
   }

   if(P.useFibo)
      ResetPullbackSetup("Entrada enviada");

   return true;
}

void ManageTrailingStops()
{
   const double atr = GetATR(0);
   if(atr == EMPTY_VALUE || atr <= 0.0)
      return;

   double trailDist = atr * P.trailAtrMult;
   if((Mode == LiquidityScalp || g_runtimeMode == LiquidityScalp) && P.lqUseStructuralTrail)
      trailDist = MathMin(trailDist, atr * MathMax(0.10, P.lqStructuralTrailAtr));
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);

   for(int i = PositionsTotal() - 1; i >= 0; i--)
   {
      const ulong ticket = PositionGetTicket(i);
      if(ticket == 0 || !PositionSelectByTicket(ticket))
         continue;

      if(PositionGetString(POSITION_SYMBOL) != _Symbol)
         continue;

      const long magic = PositionGetInteger(POSITION_MAGIC);
      if(!IsOurMagic(magic))
         continue;

      const long type = PositionGetInteger(POSITION_TYPE);
      const double openPrice = PositionGetDouble(POSITION_PRICE_OPEN);
      const double oldSL = PositionGetDouble(POSITION_SL);
      const double tp = PositionGetDouble(POSITION_TP);
      const double profitDist = (type == POSITION_TYPE_BUY ? (bid - openPrice) : (openPrice - ask));

      if(profitDist <= 0.0)
         continue;

      double newSL = oldSL;
      bool shouldMove = false;

      if(type == POSITION_TYPE_BUY)
      {
         if(P.useBreakEven && profitDist >= (atr * P.breakEvenAtrTrigger))
         {
            const double beSL = NormalizePrice(openPrice + (P.breakEvenOffsetPoints * point));
            if(oldSL <= 0.0 || beSL > newSL + point)
            {
               const bool stopOk = ((bid - beSL) >= stopLevel);
               const bool freezeOk = (freezeLevel <= 0.0 || oldSL <= 0.0 || (bid - oldSL) > freezeLevel);
               if(stopOk && freezeOk)
               {
                  newSL = beSL;
                  shouldMove = true;
               }
            }
         }

         if(profitDist >= (atr * P.trailStartAtr))
         {
            const double trailSL = NormalizePrice(bid - trailDist);
            if(oldSL <= 0.0 || trailSL > newSL + point)
            {
               const bool stopOk = ((bid - trailSL) >= stopLevel);
               const bool freezeOk = (freezeLevel <= 0.0 || oldSL <= 0.0 || (bid - oldSL) > freezeLevel);
               if(stopOk && freezeOk)
               {
                  newSL = trailSL;
                  shouldMove = true;
               }
            }
         }
      }
      else if(type == POSITION_TYPE_SELL)
      {
         if(P.useBreakEven && profitDist >= (atr * P.breakEvenAtrTrigger))
         {
            const double beSL = NormalizePrice(openPrice - (P.breakEvenOffsetPoints * point));
            if(oldSL <= 0.0 || beSL < newSL - point)
            {
               const bool stopOk = ((beSL - ask) >= stopLevel);
               const bool freezeOk = (freezeLevel <= 0.0 || oldSL <= 0.0 || (oldSL - ask) > freezeLevel);
               if(stopOk && freezeOk)
               {
                  newSL = beSL;
                  shouldMove = true;
               }
            }
         }

         if(profitDist >= (atr * P.trailStartAtr))
         {
            const double trailSL = NormalizePrice(ask + trailDist);
            if(oldSL <= 0.0 || trailSL < newSL - point)
            {
               const bool stopOk = ((trailSL - ask) >= stopLevel);
               const bool freezeOk = (freezeLevel <= 0.0 || oldSL <= 0.0 || (oldSL - ask) > freezeLevel);
               if(stopOk && freezeOk)
               {
                  newSL = trailSL;
                  shouldMove = true;
               }
            }
         }
      }

       if(shouldMove && (oldSL <= 0.0 || MathAbs(newSL - oldSL) > (point * 0.5)))
       {
          int retcode = 0;
          string comment = "";
          if(!ModifyPositionStops(ticket, _Symbol, newSL, tp, retcode, comment))
          {
             if(retcode != TRADE_RETCODE_MARKET_CLOSED)
             {
                PrintFormat("Falha trailing | ticket=%I64u | retcode=%d | msg=%s",
                            ticket, retcode, comment);
             }
          }
       }
   }
}

bool ManageLiquidityPendingLifecycleOnNewBar(const double atr,
                                             const double pascalAtr,
                                             const SoftAdjustments &soft)
{
   if(!g_lq.hasPending)
      return false;

   if(g_lq.pendingTicket == 0 || !IsLiquidityPendingOrderTicket(g_lq.pendingTicket))
   {
      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_PENDING] ticket nao encontrado em aberto | ticket=%I64u", g_lq.pendingTicket));
      ClearLiquidityPendingState();
      if(!HasOpenPositionOnSymbol(true))
      {
         if(g_lq.entryModeUsed == HYBRID && g_lq.valid)
         {
            g_lq.state = LQ_MSS;
            DebugLog(DBG_SIGNALS, "[LQ_HYBRID] pendente ausente; fallback armado para proxima barra.");
         }
         else
         {
            HardResetLiquidity("Pending ausente sem posicao");
         }
      }
      return false;
   }

   const int maxAge = ComputeDynamicPendingMaxAge(atr, g_lq.direction, g_lq.pendingPrice);
   const int barsSincePending = g_lq.pendingBarsElapsed;

   if(barsSincePending < maxAge)
   {
      // Enquanto existe pendente valida, nao processa novo setup.
      return true;
   }

   g_tel.lqPendingsExpired++;

   const ulong ticket = g_lq.pendingTicket;
   bool deleted = true;
   if(ticket > 0)
   {
      if(IsLiquidityPendingOrderTicket(ticket))
         deleted = g_trade.OrderDelete(ticket);
      else
      {
         deleted = false;
         DebugLog(DBG_SIGNALS,
                  StringFormat("[LQ_PENDING_EXPIRE] delete skipped (nao elegivel) | ticket=%I64u | barsSince=%d | maxAge=%d",
                               ticket,
                               barsSincePending,
                               maxAge));
      }
   }

   DebugLog(DBG_SIGNALS,
            StringFormat("[LQ_PENDING_EXPIRE] ticket=%I64u | barsSince=%d | maxAge=%d | deleted=%s | retcode=%d | msg=%s",
                         ticket,
                         barsSincePending,
                         maxAge,
                         (deleted ? "true" : "false"),
                         g_trade.ResultRetcode(),
                         g_trade.ResultRetcodeDescription()));

   ClearLiquidityPendingState();

   const bool stillValid = (g_lq.valid && g_lq.direction != 0 && g_lq.state == LQ_ORDERED &&
                            BarsSinceBarTime(g_lq.sweepTime) <= MathMax(1, P.lqSweepMaxAgeBars));
   const bool isHybrid = (g_lq.entryModeUsed == HYBRID);
   if(!isHybrid || !stillValid)
   {
      HardResetLiquidity("Pending expirada");
      return true;
   }

   DebugLog(DBG_SIGNALS, "[LQ_HYBRID] pendente expirada; tentando fallback para MARKET.");

   if(!CanOpenTradeNowWithContext(atr))
   {
      HardResetLiquidity("Hybrid fallback bloqueado por filtros hard");
      return true;
   }

   if(!IsSpreadAcceptable(atr))
   {
      HardResetLiquidity("Hybrid fallback bloqueado por spread");
      return true;
   }

   string shieldReason = "";
   if(!ExecutionShieldAllowsEntry(atr, pascalAtr, shieldReason))
   {
      DebugLog(DBG_SIGNALS, StringFormat("[LQ_HYBRID] fallback bloqueado pelo Shield | %s", shieldReason));
      HardResetLiquidity("Hybrid fallback bloqueado por shield");
      return true;
   }

   double marketEntry = 0.0, marketStop = 0.0, marketTarget = 0.0;
   BuildLiquidityTradeLevels(g_lq.direction, atr, soft, 0.0, marketEntry, marketStop, marketTarget);
   if(!ExecuteEntry(g_lq.direction,
                    atr,
                    "LiquidityScalp Hybrid Expire Fallback",
                    true,
                    marketStop,
                    marketTarget,
                    soft.riskMult))
   {
      HardResetLiquidity("Hybrid fallback falhou");
      return true;
   }

   HardResetLiquidity("Hybrid fallback market entry");
   MarkLiquidityEntryOnCurrentBar();
   g_tel.lqHybridFallbackMarket++;
   return true;
}

void OnNewBarLiquidity(const double atr, const double pascalAtr)
{
   const datetime currentBar = iTime(_Symbol, P.tf, 0);
   if(currentBar <= 0)
      return;

   if(g_lq.lastEntryBarTime == currentBar)
      return;

   if(g_lq.hasPending)
      g_lq.pendingBarsElapsed++;

   // Toda a state machine de LiquidityScalp roda estritamente no novo candle.
   TryLiquidityScalpFlowOnNewBar(atr, pascalAtr);
}

void TryLiquidityScalpFlowOnNewBar(const double atr, const double pascalAtr)
{
   SoftAdjustments soft;
   const double score = RegimeScore();
   ApplySoftAdjustments(score, soft);

   if(ManageLiquidityPendingLifecycleOnNewBar(atr, pascalAtr, soft))
      return;

   if(!CanOpenTradeNowWithContext(atr))
      return;

   if(!IsSpreadAcceptable(atr))
      return;

   string shieldReason = "";
   if(!ExecutionShieldAllowsEntry(atr, pascalAtr, shieldReason))
      return;

   if(atr <= pascalAtr * P.atrFilterMult)
   {
      DebugLog(DBG_VERBOSE,
               StringFormat("[LQ_STATE] volatilidade insuficiente | ATR=%.5f | ATR_MA=%.5f | filtro=%.3f",
                            atr,
                            pascalAtr,
                            P.atrFilterMult));
      return;
   }

   int direction = 0;
   double entryPrice = 0.0;
   double customStop = 0.0;
   double customTarget = 0.0;
   bool usePendingOrder = false;
   string origin = "";
   if(!EvaluateLiquidityScalpSignal(atr, soft, direction, entryPrice, customStop, customTarget, usePendingOrder, origin))
      return;

   const bool hasBlockingPosition = (P.onePosPerSymbol && HasOpenPositionOnSymbol(true));
   const bool scaleIn = (hasBlockingPosition && IsLiquidityScaleInEligible(direction, atr));
   if(hasBlockingPosition && !scaleIn)
   {
      LogBlockThrottled("Bloqueio: ja existe posicao bloqueante no simbolo.");
      return;
   }

   const double execRiskMult = (scaleIn ? ClampValue(soft.riskMult * 0.55, 0.25, 1.50)
                                        : ClampValue(soft.riskMult, 0.25, 1.50));
   const string execOrigin = (scaleIn ? origin + " ScaleIn" : origin);
   if(scaleIn)
      usePendingOrder = false;

   if(usePendingOrder)
   {
      double winrate = 0.0, seqLossProb = 0.0, factor = 0.0;
      const double effRisk = ComputeEffectiveRiskPct(execRiskMult, winrate, seqLossProb, factor);
      DebugLog(DBG_VERBOSE,
               StringFormat("Ajuste probabilistico | winrate=%.2f%% | p(seqLoss)=%.4f | fator=%.4f | softMult=%.3f | risco final=%.4f%%",
                            winrate * 100.0, seqLossProb, factor, execRiskMult, effRisk));

      const double lots = CalcVolumeByRisk(effRisk, entryPrice, customStop);
      if(lots <= 0.0)
      {
         LogAndPersist("[LQ_PENDING] lote invalido para pendente (<= 0) apos normalizacao; entrada abortada.");
         if(g_lq.entryModeUsed == HYBRID)
         {
            DebugLog(DBG_SIGNALS, "[LQ_HYBRID] fallback para MARKET por lote invalido na pendente.");
            if(ExecuteEntry(direction, atr, "LiquidityScalp Hybrid PendingFail", true, customStop, customTarget, execRiskMult))
            {
               HardResetLiquidity("Hybrid fallback market entry");
               MarkLiquidityEntryOnCurrentBar();
               if(scaleIn)
                  g_live247ScaleInsToday++;
               g_tel.lqHybridFallbackMarket++;
            }
            else
               HardResetLiquidity("Hybrid pending fail fallback failed");
         }
         return;
      }

      const int pendingExpireBars = ComputeDynamicPendingMaxAge(atr, g_lq.direction, g_lq.pendingPrice);
      if(PlaceLiquidityPendingOrder(direction, entryPrice, customStop, customTarget, lots, pendingExpireBars))
         return;

      if(g_lq.entryModeUsed == HYBRID)
      {
         DebugLog(DBG_SIGNALS, "[LQ_HYBRID] falha na pendente; fallback para MARKET.");
         if(ExecuteEntry(direction, atr, "LiquidityScalp Hybrid PendingFail", true, customStop, customTarget, execRiskMult))
         {
            HardResetLiquidity("Hybrid fallback market entry");
            MarkLiquidityEntryOnCurrentBar();
            if(scaleIn)
               g_live247ScaleInsToday++;
            g_tel.lqHybridFallbackMarket++;
         }
         else
            HardResetLiquidity("Hybrid pending fail fallback failed");
      }
      else
         g_lq.state = LQ_MSS;
      return;
   }

   if(!ExecuteEntry(direction, atr, execOrigin, true, customStop, customTarget, execRiskMult))
   {
      if(g_lq.state == LQ_ORDERED)
         g_lq.state = LQ_MSS;
      return;
   }

   HardResetLiquidity("Market entry sent");
   MarkLiquidityEntryOnCurrentBar();
   if(scaleIn)
      g_live247ScaleInsToday++;
}

void TryTradingFlowOnNewBar()
{
   if(!HasEnoughData())
   {
      LogBlockThrottled("Bloqueio: dados insuficientes para calculos.");
      return;
   }

   const double atr = GetATR(1);
   const double pascalAtr = PascalMA_ATR(1);
   if(atr == EMPTY_VALUE || pascalAtr == EMPTY_VALUE || atr <= 0.0 || pascalAtr <= 0.0)
   {
      LogBlockThrottled("Bloqueio: ATR/PascalATR indisponivel.");
      return;
   }

   double slope = 0.0;
   const int trend = TrendDirection(slope);
   if(Mode == Adaptive)
   {
      UpdateAdaptiveParams(atr, pascalAtr, slope, trend);
      UpdateExecutionProfile(atr, pascalAtr);
   }
   else
   {
      P = g_baseParams;
      g_runtimeMode = LiquidityScalp;
      Profile = Safe;
      if(InpModeForceModules)
         ApplyStrategyModeToParams(P, g_runtimeMode);
      UpdateLive247LiquidityProfile(atr, pascalAtr, slope, trend);
   }

   if(IsFusionLiquidityTemplate())
   {
      OnNewBarFusion(atr, pascalAtr);
      return;
   }

   if(IsMicroBurstLiquidityTemplate())
   {
      OnNewBarMicroBurst(atr, pascalAtr);
      return;
   }

   if(g_lqEnabled && (g_runtimeMode == LiquidityScalp || Mode == LiquidityScalp))
   {
      OnNewBarLiquidity(atr, pascalAtr);
      return;
   }

   if(!IsSpreadAcceptable(atr))
      return;

   PrintFormat("ATR vs PascalATR | ATR=%.5f | PascalATR=%.5f | limite=%.5f",
               atr, pascalAtr, pascalAtr * P.atrFilterMult);

   if(P.useFibo)
      AgePullbackSetup();

   if(!CanOpenTradeNowWithContext(atr))
      return;

   if(atr <= pascalAtr * P.atrFilterMult)
   {
      LogBlockThrottled("Bloqueio: regime de volatilidade nao aprovado.");
      return;
   }

   PrintFormat("Tendencia PascalMA | slope=%.6f | dir=%d", slope, trend);

   if(trend == 0)
   {
      LogBlockThrottled("Bloqueio: tendencia neutra.");
      return;
   }

   if(MathAbs(slope) < (atr * P.minTrendStrengthAtr))
   {
      LogBlockThrottled("Bloqueio: tendencia fraca",
                        StringFormat("absSlope=%.6f | minimo=%.6f",
                                     MathAbs(slope), atr * P.minTrendStrengthAtr));
      return;
   }

   if(P.useFibo && g_setup.active)
   {
      if(g_setup.direction != trend)
      {
         LogBlockThrottled("Bloqueio: setup fibo em direcao oposta a tendencia atual.");
      }
      else
      {
         if(IsPullbackTriggered(atr))
         {
            double hurst, entropy, autocorr;
            string reason;
            if(CheckQuantFilters(hurst, entropy, autocorr, reason))
            {
               ExecuteEntry(g_setup.direction, atr, "Fibonacci Pullback");
               return;
            }
         }
         else
         {
            PrintFormat("Aguardando trigger Fibonacci | barras=%d/%d",
                        g_setup.barsElapsed, P.fiboMaxBarsToTrigger);
         }
      }
   }

   if(!g_setup.active)
   {
      string breakoutReason = "";
      const int breakout = DetectBreakoutDirection(atr, breakoutReason);
      if(breakout == 0)
      {
         if(breakoutReason == "")
            breakoutReason = "sem breakout valido";
         LogBlockThrottled("Bloqueio: sem breakout valido", breakoutReason);
         return;
      }

      if(breakout != trend)
      {
         LogBlockThrottled("Bloqueio: breakout contra a tendencia.");
         return;
      }

      if(P.useFibo)
      {
         if(!BuildPullbackSetup(breakout))
            LogBlockThrottled("Bloqueio: falha ao criar setup Fibonacci.");
         return;
      }

      double hurst, entropy, autocorr;
      string reason;
      if(!CheckQuantFilters(hurst, entropy, autocorr, reason))
         return;

      ExecuteEntry(breakout, atr, "Breakout");
   }
}

int OnInit()
{
   ConfigureParams();

   if(OpenDebugLogFile())
   {
      LogAndPersist(StringFormat("[DEBUG_FILE] ativo | path=%s | commonFallback=%s | symbol=%s | tf=%s | mode=%s | profile=%s | debug=%d",
                                 g_debugLogPath,
                                 (g_debugLogUsingCommon ? "true" : "false"),
                                 _Symbol,
                                 EnumToString(P.tf),
                                 StrategyModeToString(Mode),
                                 RiskProfileToString(Profile),
                                 (int)Debug));
   }

   g_baseParams = P;
   g_activeRegime = RegimeBase;
   g_candidateRegime = RegimeBase;
   g_candidateRegimeBars = 0;
   g_adaptChangesToday = 0;
   g_lastRegimeChangeBar = 0;

   LogConfig();
   LogSymbolExecutionSpec();

   g_atrHandle = iATR(_Symbol, P.tf, P.atrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Falha ao criar handle ATR.");
      return INIT_FAILED;
   }

    g_adxHandle = iADX(_Symbol, P.tf, 14);
    if(g_adxHandle == INVALID_HANDLE)
    {
      Print("Falha ao criar handle ADX.");
      return INIT_FAILED;
    }

   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(P.maxDeviationPoints);

   g_lastBarTime = iTime(_Symbol, P.tf, 0);
   ResetDailyCounters(true);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   PrintDailyTelemetry("deinit");

   LogAndPersist(StringFormat("[DEBUG_FILE] deinit | reason=%d", reason));

   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
   if(g_adxHandle != INVALID_HANDLE)
      IndicatorRelease(g_adxHandle);

   CloseDebugLogFile();
}

void OnTick()
{
   ResetDailyCounters(false);
   UpdateDailyKillSwitch();
   ManageTrailingStops();

   if(!IsNewBar())
      return;

   TryTradingFlowOnNewBar();
}

void OnTradeTransaction(const MqlTradeTransaction &trans,
                        const MqlTradeRequest &request,
                        const MqlTradeResult &result)
{
   if((trans.type == TRADE_TRANSACTION_ORDER_DELETE || trans.type == TRADE_TRANSACTION_HISTORY_ADD) &&
      g_lq.hasPending && trans.order == g_lq.pendingTicket)
   {
      const ENUM_ORDER_STATE st = (ENUM_ORDER_STATE)trans.order_state;
      DebugLog(DBG_SIGNALS,
               StringFormat("[LQ_PENDING] ordem removida | ticket=%I64u | state=%d",
                            g_lq.pendingTicket,
                            (int)st));

      const bool canceled = (st == ORDER_STATE_CANCELED || st == ORDER_STATE_EXPIRED || st == ORDER_STATE_REJECTED);
      if(canceled)
      {
         ClearLiquidityPendingState();

         if(!HasOpenPositionOnSymbol(true))
         {
            if(g_lq.entryModeUsed == HYBRID && g_lq.valid)
            {
               g_lq.state = LQ_MSS;
               DebugLog(DBG_SIGNALS, "[LQ_HYBRID] pendente cancelada/expirada; fallback armado para proxima barra.");
            }
            else
            {
               HardResetLiquidity("Pending cancelada/expirada");
            }
         }
      }
      else if(st == ORDER_STATE_FILLED)
      {
         // Mantem estado ate DEAL_ENTRY_IN para consolidar reset e metrica de slippage.
      }
      else if(!IsLiquidityPendingOrderTicket(g_lq.pendingTicket) && !HasOpenPositionOnSymbol(true))
      {
         ClearLiquidityPendingState();
         if(g_lq.entryModeUsed == HYBRID && g_lq.valid)
         {
            g_lq.state = LQ_MSS;
            DebugLog(DBG_SIGNALS, "[LQ_HYBRID] pendente removida sem fill; fallback armado para proxima barra.");
         }
         else
         {
            HardResetLiquidity("Pending removida sem fill");
         }
      }
   }

   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;

   const long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(!IsOurMagic(magic))
      return;

   const ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   const string dealComment = HistoryDealGetString(trans.deal, DEAL_COMMENT);
   const bool isLiquidityDeal = (dealComment == LQ_COMMENT || magic == LQ_MAGIC_NUMBER);

   if(dealEntry == DEAL_ENTRY_IN)
   {
      g_tel.tradesOpenedToday++;

      if(isLiquidityDeal)
      {
         if(g_lq.hasPending && trans.order == g_lq.pendingTicket)
         {
            g_tradesToday++;

            const double fillPrice = HistoryDealGetDouble(trans.deal, DEAL_PRICE);
            const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
            if(point > 0.0 && g_lq.pendingPrice > 0.0)
               g_lastExecSlippagePoints = MathAbs(fillPrice - g_lq.pendingPrice) / point;

            ClearLiquidityPendingState();
         }

         if(magic == LQ_MAGIC_NUMBER)
            HardResetLiquidity("Deal confirmed");
         else
            HardResetLiquidity("Deal entry confirmed");
      }
      return;
   }

   if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY && dealEntry != DEAL_ENTRY_INOUT)
      return;

    const double dealPnl = HistoryDealGetDouble(trans.deal, DEAL_PROFIT)
                         + HistoryDealGetDouble(trans.deal, DEAL_SWAP)
                         + HistoryDealGetDouble(trans.deal, DEAL_COMMISSION);
    g_tel.tradesClosedToday++;
    if(dealPnl > 0.0)
    {
       g_tel.winsToday++;
       g_tel.grossProfitToday += dealPnl;
    }
    else if(dealPnl < 0.0)
    {
       g_tel.lossesToday++;
       g_tel.grossLossToday += dealPnl;
    }
    g_tel.netToday += dealPnl;

   const long positionId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(positionId <= 0)
      return;

   TryUpdateOutcomeFromClosedPosition(positionId);
}



