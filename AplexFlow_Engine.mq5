#property strict
#property version   "1.03"
#property description "AplexFlow Engine"

#include <Trade/Trade.mqh>

enum RiskProfile { Safe=0, Aggressive=1 };
input RiskProfile Profile = Safe;

enum StrategyMode { Core=0, Pullback=1, Quantum=2, Defensive=3, Adaptive=4 };
input StrategyMode Mode = Pullback;

const int ADAPT_CONFIRM_BARS = 2;
const int ADAPT_MIN_BARS_BETWEEN_CHANGES = 4;
const int ADAPT_MAX_CHANGES_PER_DAY = 6;
const int ADAPT_MIN_OUTCOME_SAMPLES = 12;
const double ADAPT_FALLBACK_DD_FRAC = 0.70;

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
   bool onePosPerSymbol;
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

Params P;
PullbackSetup g_setup;
CTrade g_trade;

int g_atrHandle = INVALID_HANDLE;
datetime g_lastBarTime = 0;

int g_dayKey = 0;
double g_dayStartEquity = 0.0;
int g_tradesToday = 0;
int g_consecLosses = 0;
bool g_killSwitch = false;

int g_outcomes[];
long g_processedPositionIds[];
const long MAGIC_NUMBER = 26022026;
Params g_baseParams;
StrategyMode g_runtimeMode = Pullback;

enum MarketRegime { RegimeBase=0, RegimeTrend=1, RegimeChoppy=2, RegimeDefense=3 };
int g_activeRegime = RegimeBase;
int g_candidateRegime = RegimeBase;
int g_candidateRegimeBars = 0;
datetime g_lastRegimeChangeBar = 0;
int g_adaptChangesToday = 0;

string RiskProfileToString(const RiskProfile profile)
{
   return (profile == Safe ? "Safe" : "Aggressive");
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
      default:        return "Unknown";
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

ENUM_TIMEFRAMES ResolveSelectedTimeframe()
{
   const ENUM_TIMEFRAMES chartTf = (ENUM_TIMEFRAMES)_Period;
   if(PeriodSeconds(chartTf) > 0)
      return chartTf;

   return PERIOD_H1;
}

double ClampValue(const double value, const double minValue, const double maxValue)
{
   return MathMax(minValue, MathMin(maxValue, value));
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
         params.useFibo = true;
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

void ConfigureParams()
{
   ZeroMemory(P);
   P.tf = ResolveSelectedTimeframe();

   P.fibo1 = 0.382;
   P.fibo2 = 0.500;
   P.fibo3 = 0.618;

   P.swingLookback = 30;
   P.fiboTolAtr = 0.15;
   P.fiboMaxBarsToTrigger = 8;

   P.useProbRiskAdjust = true;
   P.winrateLen = 40;
   P.seqLossProbMax = 0.25;
   P.minRiskFactor = 0.40;

   P.useTakeProfit = true;
   P.tpAtrMult = 2.8;
   P.useBreakEven = true;
   P.breakEvenAtrTrigger = 1.0;
   P.breakEvenOffsetPoints = 10;
   P.trailStartAtr = 0.8;

   P.minTrendStrengthAtr = 0.05;
   P.breakoutBodyAtrMin = 0.15;
   P.breakoutCloseStrengthMin = 0.55;
   P.maxSpreadAtrFrac = 0.12;

   P.slippagePoints = 20;
   P.onePosPerSymbol = true;

   if(Profile == Safe)
   {
      P.riskPct = 0.5;
      P.maxTradesPerDay = 10;
      P.maxConsecLosses = 2;
      P.maxDailyDDPct = 1.5;
      P.atrPeriod = 14;
      P.atrMaLen = 50;
      P.atrFilterMult = 1.05;
      P.lookback = 20;
      P.pascalLenPrice = 5;
      P.pascalLenATR = 5;
      P.stopAtrMult = 1.7;
      P.useTakeProfit = true;
      P.tpAtrMult = 3.2;
      P.useBreakEven = true;
      P.breakEvenAtrTrigger = 1.0;
      P.breakEvenOffsetPoints = 12;
      P.trailStartAtr = 1.1;
      P.trailAtrMult = 2.5;
      P.useSessionFilter = true;
      P.tradeStartHour = 6;
      P.tradeEndHour = 22;
      P.onePosPerSymbol = true;

      P.minTrendStrengthAtr = 0.07;
      P.breakoutBodyAtrMin = 0.20;
      P.breakoutCloseStrengthMin = 0.57;
      P.maxSpreadAtrFrac = 0.11;

      P.hurstMin = 0.55;
      P.autocorrLen = 80;
      P.autocorrMinAbs = 0.10;
      P.entropyLen = 100;
      P.entropyMax = 0.85;
   }
   else
   {
      P.riskPct = 1.0;
      if(P.riskPct > 1.25)
         P.riskPct = 1.25;
      P.maxTradesPerDay = 4;
      P.maxConsecLosses = 3;
      P.maxDailyDDPct = 3.0;
      P.atrPeriod = 14;
      P.atrMaLen = 50;
      P.atrFilterMult = 0.90;
      P.lookback = 14;
      P.pascalLenPrice = 5;
      P.pascalLenATR = 5;
      P.stopAtrMult = 1.3;
      P.useTakeProfit = true;
      P.tpAtrMult = 2.4;
      P.useBreakEven = true;
      P.breakEvenAtrTrigger = 0.8;
      P.breakEvenOffsetPoints = 8;
      P.trailStartAtr = 0.9;
      P.trailAtrMult = 2.0;
      P.useSessionFilter = true;
      P.tradeStartHour = 7;
      P.tradeEndHour = 20;
      P.onePosPerSymbol = true;

      P.minTrendStrengthAtr = 0.06;
      P.breakoutBodyAtrMin = 0.18;
      P.breakoutCloseStrengthMin = 0.55;
      P.maxSpreadAtrFrac = 0.15;

      P.swingLookback = 20;
      P.fiboTolAtr = 0.20;
      P.fiboMaxBarsToTrigger = 6;
      P.winrateLen = 30;
      P.seqLossProbMax = 0.35;
      P.minRiskFactor = 0.35;

      P.hurstMin = 0.53;
      P.autocorrLen = 64;
      P.autocorrMinAbs = 0.10;
      P.entropyLen = 100;
      P.entropyMax = 0.85;
   }

   StrategyMode baseMode = Mode;
   if(baseMode == Adaptive)
      baseMode = Pullback;

   ApplyStrategyModeToParams(P, baseMode);
   g_runtimeMode = baseMode;
}

void LogConfig()
{
   PrintFormat("AplexFlow Engine | PROFILE=%s | MODE=%s | runtimeMode=%s",
               RiskProfileToString(Profile),
               StrategyModeToString(Mode),
               StrategyModeToString(g_runtimeMode));

   PrintFormat("Timeframe detectado | chart=%s(%d) | operacional=%s(%d)",
               EnumToString((ENUM_TIMEFRAMES)_Period),
               (int)_Period,
               EnumToString(P.tf),
               (int)P.tf);

   if(Mode == Adaptive)
      Print("Modo Adaptive ativo: o EA alterna automaticamente entre Core/Pullback/Quantum/Defensive conforme regime.");

   PrintFormat("Modulos ativos | Fibo=%s | Hurst=%s | Entropy=%s | Autocorr=%s | ProbRisk=%s",
               (P.useFibo ? "ON" : "OFF"),
               (P.useHurst ? "ON" : "OFF"),
               (P.useEntropy ? "ON" : "OFF"),
               (P.useAutocorr ? "ON" : "OFF"),
               (P.useProbRiskAdjust ? "ON" : "OFF"));

   PrintFormat("Risk profile interno | TF=%d | riskPct=%.2f | maxTrades/day=%d | maxConsecLosses=%d | maxDailyDD=%.2f%%",
               (int)P.tf, P.riskPct, P.maxTradesPerDay, P.maxConsecLosses, P.maxDailyDDPct);

   PrintFormat("Execucao | TP=%s(%.2f ATR) | BreakEven=%s(%.2f ATR, %d pts) | Trail start=%.2f ATR, dist=%.2f ATR",
               (P.useTakeProfit ? "ON" : "OFF"),
               P.tpAtrMult,
               (P.useBreakEven ? "ON" : "OFF"),
               P.breakEvenAtrTrigger,
               P.breakEvenOffsetPoints,
               P.trailStartAtr,
               P.trailAtrMult);

   PrintFormat("Filtros de qualidade | minSlope=%.3f ATR | bodyBreakout=%.3f ATR | closeStrength=%.2f | maxSpread=%.2f ATR",
               P.minTrendStrengthAtr,
               P.breakoutBodyAtrMin,
               P.breakoutCloseStrengthMin,
               P.maxSpreadAtrFrac);

   PrintFormat("Adaptive interno | confirmadoEm=%d barras | minIntervalo=%d barras | maxTrocasDia=%d | minAmostras=%d | fallbackDD=%.2f",
               ADAPT_CONFIRM_BARS,
               ADAPT_MIN_BARS_BETWEEN_CHANGES,
               ADAPT_MAX_CHANGES_PER_DAY,
               ADAPT_MIN_OUTCOME_SAMPLES,
               ADAPT_FALLBACK_DD_FRAC);
}

void ResetPullbackSetup(const string reason)
{
   if(g_setup.active)
      PrintFormat("Setup Fibonacci cancelado: %s", reason);

   ZeroMemory(g_setup);
}

void ResetDailyCounters(const bool force)
{
   datetime now = TimeTradeServer();
   if(now <= 0)
      now = TimeCurrent();

   const int key = BuildDayKey(now);
   if(!force && key == g_dayKey)
      return;

   g_dayKey = key;
   g_dayStartEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   g_tradesToday = 0;
   g_consecLosses = 0;
   g_killSwitch = false;
   g_adaptChangesToday = 0;
   g_candidateRegimeBars = 0;
   g_candidateRegime = RegimeBase;
   g_activeRegime = RegimeBase;
   g_lastRegimeChangeBar = 0;
   P = g_baseParams;
   g_runtimeMode = (Mode == Adaptive ? Pullback : Mode);
   ApplyStrategyModeToParams(P, g_runtimeMode);

   if(P.useFibo)
      ResetPullbackSetup("Novo dia de trading");

   PrintFormat("Reset diario realizado | dayKey=%d | equity inicial=%.2f",
               g_dayKey, g_dayStartEquity);
}

void UpdateDailyKillSwitch()
{
   if(g_killSwitch || g_dayStartEquity <= 0.0)
      return;

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double ddPct = ((g_dayStartEquity - equity) / g_dayStartEquity) * 100.0;

   if(ddPct >= P.maxDailyDDPct)
   {
      g_killSwitch = true;
      PrintFormat("Kill switch acionado | DD diario=%.2f%% >= limite %.2f%%",
                  ddPct, P.maxDailyDDPct);

      if(P.useFibo)
         ResetPullbackSetup("Kill switch diario");
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
   if(P.maxSpreadAtrFrac <= 0.0)
      return true;
   if(atr <= 0.0)
      return false;

   const double spread = CurrentSpreadPrice();
   if(spread <= 0.0)
   {
      Print("Bloqueio: spread invalido.");
      return false;
   }

   const double maxSpread = atr * P.maxSpreadAtrFrac;
   if(spread > maxSpread)
   {
      PrintFormat("Bloqueio: spread alto | spread=%.5f | max=%.5f", spread, maxSpread);
      return false;
   }

   return true;
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

   const double equity = AccountInfoDouble(ACCOUNT_EQUITY);
   const double ddPct = ((g_dayStartEquity - equity) / g_dayStartEquity) * 100.0;
   return MathMax(0.0, ddPct);
}

bool IsAdaptiveFallbackTriggered()
{
   if(ADAPT_FALLBACK_DD_FRAC <= 0.0 || g_baseParams.maxDailyDDPct <= 0.0)
      return false;

   const double threshold = g_baseParams.maxDailyDDPct * ADAPT_FALLBACK_DD_FRAC;
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
   if(spreadFrac > spreadBase * 1.30)
      return RegimeDefense;

   const double volRatio = atr / pascalAtr;
   const double trendStrength = MathAbs(slope) / atr;
   const bool strongTrend = (trendDir != 0 && trendStrength >= g_baseParams.minTrendStrengthAtr * 1.15);
   const bool weakTrend = (trendStrength < g_baseParams.minTrendStrengthAtr * 0.65);
   const bool highVol = (volRatio >= g_baseParams.atrFilterMult * 1.00);

   if(outcomeSamples >= ADAPT_MIN_OUTCOME_SAMPLES)
   {
      if(winrate < 0.35)
         return RegimeDefense;

      if(winrate > 0.58 && strongTrend && spreadFrac <= spreadBase * 1.05)
         return RegimeTrend;
   }

   if(strongTrend && highVol && spreadFrac <= spreadBase * 1.20)
      return RegimeTrend;

   if(weakTrend || volRatio < 0.90)
      return RegimeChoppy;

   return RegimeBase;
}

void BuildAdaptiveParamsForRegime(const int regime, const StrategyMode strategyMode, Params &outP)
{
   outP = g_baseParams;
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
         riskMult = 1.10;
         atrFilterMult = 0.95;
         trendMult = 0.90;
         bodyMult = 0.90;
         closeDelta = -0.03;
         spreadMult = 1.10;
         tpMult = 1.15;
         beTriggerMult = 0.90;
         trailStartMult = 0.85;
         trailDistMult = 0.92;
         maxTradesMult = 1.30;
         break;

      case RegimeChoppy:
         riskMult = 0.90;
         atrFilterMult = 1.03;
         trendMult = 1.05;
         bodyMult = 1.05;
         closeDelta = 0.01;
         spreadMult = 0.95;
         tpMult = 1.00;
         beTriggerMult = 1.00;
         trailStartMult = 1.05;
         trailDistMult = 1.05;
         maxTradesMult = 1.10;
         break;

      case RegimeDefense:
         riskMult = 0.60;
         atrFilterMult = 1.20;
         trendMult = 1.35;
         bodyMult = 1.35;
         closeDelta = 0.07;
         spreadMult = 0.75;
         tpMult = 0.90;
         beTriggerMult = 1.00;
         trailStartMult = 1.20;
         trailDistMult = 1.15;
         maxTradesMult = 0.80;
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
   const int adaptiveMinTrades = (Profile == Safe ? 2 : 1);
   outP.maxTradesPerDay = MathMax(adaptiveMinTrades, maxTrades);
}

bool CanCommitAdaptiveChange()
{
   if(g_adaptChangesToday >= ADAPT_MAX_CHANGES_PER_DAY)
      return false;

   const int barsSince = BarsSinceBarTime(g_lastRegimeChangeBar);
   if(barsSince < ADAPT_MIN_BARS_BETWEEN_CHANGES)
      return false;

   return true;
}

void UpdateAdaptiveParams(const double atr, const double pascalAtr, const double slope, const int trendDir)
{
   P = g_baseParams;

   if(Mode != Adaptive)
   {
      g_runtimeMode = Mode;
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

   const bool confirmed = (g_candidateRegimeBars >= ADAPT_CONFIRM_BARS);

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
                     ADAPT_MAX_CHANGES_PER_DAY,
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
      g_runtimeMode = nextMode;
      ResetPullbackSetup("Troca de modo adaptativo");
      PrintFormat("Adaptive mode switch | %s -> %s | regime=%s",
                  StrategyModeToString(oldMode),
                  StrategyModeToString(g_runtimeMode),
                  MarketRegimeToString(g_activeRegime));
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
            if(magic != MAGIC_NUMBER)
               continue;
         }
         return true;
      }
   }
   return false;
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

      if((long)HistoryDealGetInteger(dealTicket, DEAL_MAGIC) != MAGIC_NUMBER)
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
         Print("Bloqueio: ", reason);
         return false;
      }

      PrintFormat("Filtro Hurst | valor=%.4f | minimo=%.4f", hurst, P.hurstMin);
      if(hurst < P.hurstMin)
      {
         reason = "Hurst abaixo do minimo";
         Print("Bloqueio: ", reason);
         return false;
      }
   }

   if(P.useEntropy)
   {
      entropy = CalcDirectionEntropy(P.entropyLen, 1);
      if(entropy == EMPTY_VALUE)
      {
         reason = "Entropy indisponivel";
         Print("Bloqueio: ", reason);
         return false;
      }

      PrintFormat("Filtro Entropy | valor=%.4f | maximo=%.4f", entropy, P.entropyMax);
      if(entropy > P.entropyMax)
      {
         reason = "Entropy acima do maximo";
         Print("Bloqueio: ", reason);
         return false;
      }
   }

   if(P.useAutocorr)
   {
      autocorr = CalcAutocorrLag1(P.autocorrLen, 1);
      if(autocorr == EMPTY_VALUE)
      {
         reason = "Autocorrelacao indisponivel";
         Print("Bloqueio: ", reason);
         return false;
      }

      PrintFormat("Filtro Autocorr | valor=%.4f | minimo abs=%.4f",
                  autocorr, P.autocorrMinAbs);
      if(MathAbs(autocorr) < P.autocorrMinAbs)
      {
         reason = "Autocorrelacao abaixo do minimo";
         Print("Bloqueio: ", reason);
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

   const double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   const double tickSize  = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   const double volMin    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   const double volMax    = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   const double volStep   = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);

   if(tickValue <= 0.0 || tickSize <= 0.0 || volMin <= 0.0 || volStep <= 0.0)
      return 0.0;

   const double stopDist = MathAbs(entryPrice - stopPrice);
   if(stopDist <= 0.0)
      return 0.0;

   const double lossPerLot = (stopDist / tickSize) * tickValue;
   if(lossPerLot <= 0.0)
      return 0.0;

   double lot = riskMoney / lossPerLot;
   if(lot < volMin) lot = volMin;
   if(lot > volMax) lot = volMax;

   const double steps = MathFloor((lot - volMin) / volStep + 1e-9);
   lot = volMin + steps * volStep;
   if(lot < volMin) lot = volMin;
   if(lot > volMax) lot = volMax;

   const int volDigits = VolumeDigitsFromStep(volStep);
   return NormalizeDouble(lot, volDigits);
}

double EnforceStopDistance(const int direction, const double entry, double stop)
{
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double freezeLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_FREEZE_LEVEL) * point;
   const double minDist = MathMax(stopLevel, freezeLevel);

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
   const double point = SymbolInfoDouble(_Symbol, SYMBOL_POINT);
   const double stopLevel = (double)SymbolInfoInteger(_Symbol, SYMBOL_TRADE_STOPS_LEVEL) * point;
   const double minDist = MathMax(stopLevel, point);

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

bool CanOpenTradeNow()
{
   if(g_killSwitch)
   {
      Print("Bloqueio: kill switch diario ativo.");
      return false;
   }

   if(g_tradesToday >= P.maxTradesPerDay)
   {
      PrintFormat("Bloqueio: limite de trades diarios atingido (%d).", P.maxTradesPerDay);
      return false;
   }

   if(g_consecLosses >= P.maxConsecLosses)
   {
      PrintFormat("Bloqueio: limite de perdas consecutivas atingido (%d).", P.maxConsecLosses);
      return false;
   }

   if(!IsInSession())
   {
      Print("Bloqueio: fora da janela de sessao.");
      return false;
   }

   if(P.onePosPerSymbol && HasOpenPositionOnSymbol(true))
   {
      Print("Bloqueio: ja existe posicao bloqueante no simbolo.");
      return false;
   }

   if(!TerminalInfoInteger(TERMINAL_TRADE_ALLOWED) || !MQLInfoInteger(MQL_TRADE_ALLOWED))
   {
      Print("Bloqueio: trading nao permitido pelo terminal/EA.");
      return false;
   }

   return true;
}

bool ExecuteEntry(const int direction, const double atr, const string origin)
{
   if(direction == 0 || atr <= 0.0)
      return false;

   double winrate = 0.0, seqLossProb = 0.0;
   const double factor = RiskFactorFromProbability(winrate, seqLossProb);
   const double baseRisk = P.riskPct;
   double effRisk = baseRisk * factor;

   if(effRisk > baseRisk)
      effRisk = baseRisk;
   if(Profile == Aggressive && effRisk > 1.25)
      effRisk = 1.25;

   PrintFormat("Ajuste probabilistico | winrate=%.2f%% | p(seqLoss)=%.4f | fator=%.4f | risco final=%.4f%%",
               winrate * 100.0, seqLossProb, factor, effRisk);

   const double ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   const double bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   const double entry = (direction > 0 ? ask : bid);
   const double stopDist = atr * P.stopAtrMult;

   double stop = (direction > 0 ? entry - stopDist : entry + stopDist);
   stop = EnforceStopDistance(direction, entry, stop);

   double target = 0.0;
   if(P.useTakeProfit)
   {
      target = (direction > 0 ? entry + (atr * P.tpAtrMult)
                              : entry - (atr * P.tpAtrMult));
      target = EnforceTargetDistance(direction, entry, target);
   }

   const double lot = CalcVolumeByRisk(effRisk, entry, stop);
   if(lot <= 0.0)
   {
      Print("Bloqueio: lote calculado invalido.");
      return false;
   }

   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(P.slippagePoints);

   bool ok = false;
   if(direction > 0)
      ok = g_trade.Buy(lot, _Symbol, 0.0, stop, target, "AplexFlow Engine");
   else
      ok = g_trade.Sell(lot, _Symbol, 0.0, stop, target, "AplexFlow Engine");

   if(!ok)
   {
      PrintFormat("Falha na entrada | origem=%s | retcode=%d | msg=%s",
                  origin, g_trade.ResultRetcode(), g_trade.ResultRetcodeDescription());
      return false;
   }

   g_tradesToday++;
   PrintFormat("Entrada executada | origem=%s | dir=%s | lote=%.2f | SL=%.5f | TP=%.5f | tradesHoje=%d",
               origin, (direction > 0 ? "BUY" : "SELL"), lot, stop, target, g_tradesToday);

   if(P.useFibo)
      ResetPullbackSetup("Entrada enviada");

   return true;
}

void ManageTrailingStops()
{
   const double atr = GetATR(0);
   if(atr == EMPTY_VALUE || atr <= 0.0)
      return;

   const double trailDist = atr * P.trailAtrMult;
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
      if(magic != MAGIC_NUMBER)
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

void TryTradingFlowOnNewBar()
{
   if(!HasEnoughData())
   {
      Print("Bloqueio: dados insuficientes para calculos.");
      return;
   }

   const double atr = GetATR(1);
   const double pascalAtr = PascalMA_ATR(1);
   if(atr == EMPTY_VALUE || pascalAtr == EMPTY_VALUE || atr <= 0.0 || pascalAtr <= 0.0)
   {
      Print("Bloqueio: ATR/PascalATR indisponivel.");
      return;
   }

   double slope = 0.0;
   const int trend = TrendDirection(slope);
   UpdateAdaptiveParams(atr, pascalAtr, slope, trend);

   if(!IsSpreadAcceptable(atr))
      return;

   PrintFormat("ATR vs PascalATR | ATR=%.5f | PascalATR=%.5f | limite=%.5f",
               atr, pascalAtr, pascalAtr * P.atrFilterMult);

   if(P.useFibo)
      AgePullbackSetup();

   if(!CanOpenTradeNow())
      return;

   if(atr <= pascalAtr * P.atrFilterMult)
   {
      Print("Bloqueio: regime de volatilidade nao aprovado.");
      return;
   }

   PrintFormat("Tendencia PascalMA | slope=%.6f | dir=%d", slope, trend);

   if(trend == 0)
   {
      Print("Bloqueio: tendencia neutra.");
      return;
   }

   if(MathAbs(slope) < (atr * P.minTrendStrengthAtr))
   {
      PrintFormat("Bloqueio: tendencia fraca | absSlope=%.6f | minimo=%.6f",
                  MathAbs(slope), atr * P.minTrendStrengthAtr);
      return;
   }

   if(P.useFibo && g_setup.active)
   {
      if(g_setup.direction != trend)
      {
         Print("Bloqueio: setup fibo em direcao oposta a tendencia atual.");
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
         PrintFormat("Bloqueio: %s.", breakoutReason);
         return;
      }

      if(breakout != trend)
      {
         Print("Bloqueio: breakout contra a tendencia.");
         return;
      }

      if(P.useFibo)
      {
         if(!BuildPullbackSetup(breakout))
            Print("Bloqueio: falha ao criar setup Fibonacci.");
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
   g_baseParams = P;
   g_activeRegime = RegimeBase;
   g_candidateRegime = RegimeBase;
   g_candidateRegimeBars = 0;
   g_adaptChangesToday = 0;
   g_lastRegimeChangeBar = 0;

   LogConfig();

   g_atrHandle = iATR(_Symbol, P.tf, P.atrPeriod);
   if(g_atrHandle == INVALID_HANDLE)
   {
      Print("Falha ao criar handle ATR.");
      return INIT_FAILED;
   }

   g_trade.SetExpertMagicNumber(MAGIC_NUMBER);
   g_trade.SetDeviationInPoints(P.slippagePoints);

   g_lastBarTime = iTime(_Symbol, P.tf, 0);
   ResetDailyCounters(true);
   return INIT_SUCCEEDED;
}

void OnDeinit(const int reason)
{
   if(g_atrHandle != INVALID_HANDLE)
      IndicatorRelease(g_atrHandle);
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
   if(trans.type != TRADE_TRANSACTION_DEAL_ADD)
      return;

   if(!HistoryDealSelect(trans.deal))
      return;

   if(HistoryDealGetString(trans.deal, DEAL_SYMBOL) != _Symbol)
      return;

   const long magic = HistoryDealGetInteger(trans.deal, DEAL_MAGIC);
   if(magic != MAGIC_NUMBER)
      return;

   const ENUM_DEAL_ENTRY dealEntry = (ENUM_DEAL_ENTRY)HistoryDealGetInteger(trans.deal, DEAL_ENTRY);
   if(dealEntry != DEAL_ENTRY_OUT && dealEntry != DEAL_ENTRY_OUT_BY && dealEntry != DEAL_ENTRY_INOUT)
      return;

   const long positionId = HistoryDealGetInteger(trans.deal, DEAL_POSITION_ID);
   if(positionId <= 0)
      return;

   TryUpdateOutcomeFromClosedPosition(positionId);
}
