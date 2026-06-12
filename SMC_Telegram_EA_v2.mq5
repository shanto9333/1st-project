//+------------------------------------------------------------------+
//| SMC Telegram Signal EA with Trade Analytics + Psychology Engine |
//| Smart Money Concept (SMC) Automated Trading System              |
//| MetaTrader 5 Expert Advisor                                     |
//+------------------------------------------------------------------+

#property copyright "Smart Money Concepts Trading System"
#property link      "https://t.me/YourTradingChannel"
#property version   "2.0"
#property strict
#property description "Professional SMC EA with Telegram Integration"

#include <Trade\Trade.mqh>
#include <Trade\OrderInfo.mqh>
#include <Trade\DealInfo.mqh>
#include <Trade\HistoryOrderInfo.mqh>

//--- TELEGRAM SETTINGS
input string TelegramBotToken = "YOUR_BOT_TOKEN";
input string TelegramChatID = "YOUR_CHAT_ID";
input bool EnableTelegram = true;

//--- TRADING PARAMETERS
input double RiskPercentage = 2.0;
input int MaxOpenTrades = 1;
input ENUM_TIMEFRAME AnalysisTimeframe = PERIOD_H1;
input ENUM_TIMEFRAME ConfirmationTimeframe = PERIOD_M5;
input double MinProfitTP1 = 20;
input double MinProfitTP2 = 40;

//--- SMC PARAMETERS
input int LiquiditySwingBars = 20;
input int OrderBlockBars = 10;
input int FVGMinPips = 5;
input bool UseDXYFilter = false;
input double DXYStrengthThreshold = 1.5;

//--- PSYCHOLOGY ENGINE
input bool EnablePsychologyMessages = true;
input int PsychologyMessageFrequency = 120;

//--- TRADING JOURNAL
struct TradeRecord {
    ulong   ticket;
    string  symbol;
    double  entryPrice;
    double  stopLoss;
    double  tp1;
    double  tp2;
    double  lot;
    int     reason;
    datetime openTime;
    bool    isClosed;
    double  closePrice;
    double  profit;
    int     closeReason;
};

TradeRecord tradeJournal[];
int totalTrades = 0;
int winTrades = 0;
int lossTrades = 0;
double totalProfit = 0;
datetime lastPsychologyMessageTime = 0;

//--- GLOBAL VARIABLES
CTrade trade;
COrderInfo orderInfo;
CDealInfo dealInfo;
CHistoryOrderInfo historyOrderInfo;

int smcConfirmations = 0;
bool liquidityGrabDetected = false;
bool orderBlockConfirmed = false;
bool fvgDetected = false;
bool multiTimeframeAligned = false;

double liquidity_level = 0;
double orderblock_level = 0;
double fvg_level = 0;

//--- CHART DRAWING OBJECTS
string drawingPrefix = "SMC_";

//+------------------------------------------------------------------+
//| Expert initialization function                                  |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("=== SMC Telegram EA Initialized ===");
    Print("Account: ", AccountInfoString(ACCOUNT_COMPANY));
    Print("Balance: ", AccountInfoDouble(ACCOUNT_BALANCE), " ", AccountInfoString(ACCOUNT_CURRENCY));
    
    trade.SetExpertMagicNumber(123456);
    
    ArrayResize(tradeJournal, 100);
    
    EventSetTimer(60);
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    EventKillTimer();
    Comment("");
    Print("SMC EA Deinitialized");
}

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
{
    UpdateTradeTracking();
    CheckClosedTrades();
    AnalyzeMarketStructure();
    
    if(CountOpenTrades() < MaxOpenTrades)
    {
        CheckForEntry();
    }
    
    UpdateDashboard();
    SendPsychologyMessages();
}

//+------------------------------------------------------------------+
//| MARKET STRUCTURE ANALYSIS                                        |
//+------------------------------------------------------------------+
void AnalyzeMarketStructure()
{
    smcConfirmations = 0;
    liquidityGrabDetected = false;
    orderBlockConfirmed = false;
    fvgDetected = false;
    multiTimeframeAligned = false;
    
    bool structureValid = DetectMarketStructure();
    if(structureValid) smcConfirmations++;
    
    liquidityGrabDetected = DetectLiquidity();
    if(liquidityGrabDetected) smcConfirmations++;
    
    orderBlockConfirmed = DetectOrderBlock();
    if(orderBlockConfirmed) smcConfirmations++;
    
    fvgDetected = DetectFVG();
    if(fvgDetected) smcConfirmations++;
    
    multiTimeframeAligned = CheckMultiTimeframeAlignment();
    if(multiTimeframeAligned) smcConfirmations++;
}

//+------------------------------------------------------------------+
//| DETECT MARKET STRUCTURE (HH, HL, LH, LL)                        |
//+------------------------------------------------------------------+
bool DetectMarketStructure()
{
    int bars = LiquiditySwingBars;
    double currentHigh = High[0];
    double currentLow = Low[0];
    double previousHigh = 0;
    double previousLow = 0;
    
    for(int i = 1; i < bars; i++)
    {
        if(High[i] > currentHigh && (previousHigh == 0 || High[i] > previousHigh))
        {
            previousHigh = High[i];
        }
        if(Low[i] < currentLow && (previousLow == 0 || Low[i] < previousLow))
        {
            previousLow = Low[i];
        }
    }
    
    if(currentHigh > previousHigh && currentLow > previousLow)
    {
        DrawStructure("HH", currentHigh, clrGreen);
        return true;
    }
    
    if(currentLow < previousLow && currentHigh < previousHigh)
    {
        DrawStructure("LL", currentLow, clrRed);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| DETECT LIQUIDITY ZONES                                           |
//+------------------------------------------------------------------+
bool DetectLiquidity()
{
    int bars = LiquiditySwingBars;
    double tolerance = 5 * Point;
    int equalCount = 0;
    
    for(int i = 1; i < bars - 1; i++)
    {
        for(int j = i + 1; j < bars; j++)
        {
            if(MathAbs(High[i] - High[j]) < tolerance)
            {
                equalCount++;
                liquidity_level = High[i];
            }
            if(MathAbs(Low[i] - Low[j]) < tolerance)
            {
                equalCount++;
                liquidity_level = Low[i];
            }
        }
    }
    
    if(equalCount >= 2)
    {
        DrawLiquidityZone(liquidity_level);
        return true;
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| DETECT ORDER BLOCKS                                              |
//+------------------------------------------------------------------+
bool DetectOrderBlock()
{
    int bars = OrderBlockBars;
    
    for(int i = 1; i < bars; i++)
    {
        if(Close[i] < Open[i] && Close[i-1] > Open[i-1] && 
           High[i] > High[i-1] && Close[i] > Open[i-1])
        {
            orderblock_level = High[i];
            DrawOrderBlock(orderblock_level, true);
            return true;
        }
        
        if(Close[i] > Open[i] && Close[i-1] < Open[i-1] && 
           Low[i] < Low[i-1] && Close[i] < Open[i-1])
        {
            orderblock_level = Low[i];
            DrawOrderBlock(orderblock_level, false);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| DETECT FAIR VALUE GAPS (FVG)                                    |
//+------------------------------------------------------------------+
bool DetectFVG()
{
    int minPips = FVGMinPips;
    
    if(Low[0] > High[2])
    {
        double gap = (Low[0] - High[2]) / Point;
        if(gap >= minPips)
        {
            fvg_level = Low[0] - (gap / 2) * Point;
            DrawFVG(fvg_level, true);
            return true;
        }
    }
    
    if(High[0] < Low[2])
    {
        double gap = (Low[2] - High[0]) / Point;
        if(gap >= minPips)
        {
            fvg_level = High[0] + (gap / 2) * Point;
            DrawFVG(fvg_level, false);
            return true;
        }
    }
    
    return false;
}

//+------------------------------------------------------------------+
//| MULTI-TIMEFRAME ALIGNMENT                                        |
//+------------------------------------------------------------------+
bool CheckMultiTimeframeAlignment()
{
    double ma_h1_fast = iMA(Symbol(), PERIOD_H1, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma_h1_slow = iMA(Symbol(), PERIOD_H1, 50, 0, MODE_SMA, PRICE_CLOSE, 0);
    double close_h1 = iClose(Symbol(), PERIOD_H1, 0);
    
    bool h1_uptrend = (ma_h1_fast > ma_h1_slow) && (close_h1 > ma_h1_fast);
    bool h1_downtrend = (ma_h1_fast < ma_h1_slow) && (close_h1 < ma_h1_fast);
    
    double ma_m5_fast = iMA(Symbol(), PERIOD_M5, 10, 0, MODE_SMA, PRICE_CLOSE, 0);
    double ma_m5_slow = iMA(Symbol(), PERIOD_M5, 20, 0, MODE_SMA, PRICE_CLOSE, 0);
    double close_m5 = iClose(Symbol(), PERIOD_M5, 0);
    
    bool m5_uptrend = (ma_m5_fast > ma_m5_slow) && (close_m5 > ma_m5_fast);
    bool m5_downtrend = (ma_m5_fast < ma_m5_slow) && (close_m5 < ma_m5_fast);
    
    return (h1_uptrend && m5_uptrend) || (h1_downtrend && m5_downtrend);
}

//+------------------------------------------------------------------+
//| CHECK FOR ENTRY SIGNALS                                          |
//+------------------------------------------------------------------+
void CheckForEntry()
{
    if(smcConfirmations < 2 || !liquidityGrabDetected)
        return;
    
    if(!DetectMarketStructure())
        return;
    
    double rsi = iRSI(Symbol(), PERIOD_M5, 14, PRICE_CLOSE, 0);
    
    if(liquidityGrabDetected && orderBlockConfirmed && multiTimeframeAligned && rsi > 50)
    {
        ExecuteBuyTrade();
    }
    
    if(liquidityGrabDetected && orderBlockConfirmed && multiTimeframeAligned && rsi < 50)
    {
        ExecuteSellTrade();
    }
}

//+------------------------------------------------------------------+
//| EXECUTE BUY TRADE                                                |
//+------------------------------------------------------------------+
void ExecuteBuyTrade()
{
    if(CountOpenTrades() >= MaxOpenTrades)
        return;
    
    double ask = SymbolInfoDouble(Symbol(), SYMBOL_ASK);
    double stopLoss = liquidity_level - (10 * Point);
    double risk = ask - stopLoss;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercentage / 100);
    double lot = NormalizeDouble(riskAmount / (risk / Point / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE)), 2);
    
    lot = MathMin(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX));
    lot = MathMax(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN));
    
    double tp1 = ask + (MinProfitTP1 * Point);
    double tp2 = ask + (MinProfitTP2 * Point);
    
    if(trade.Buy(lot, Symbol(), ask, stopLoss, tp1, "BUY - SMC"))
    {
        RecordTrade(trade.ResultOrder(), Symbol(), ask, stopLoss, tp1, tp2, lot, 1);
        SendTelegramSignal("BUY", ask, stopLoss, tp1, tp2, true);
        DrawTradeSetup(ask, stopLoss, tp1, tp2, true);
    }
}

//+------------------------------------------------------------------+
//| EXECUTE SELL TRADE                                               |
//+------------------------------------------------------------------+
void ExecuteSellTrade()
{
    if(CountOpenTrades() >= MaxOpenTrades)
        return;
    
    double bid = SymbolInfoDouble(Symbol(), SYMBOL_BID);
    double stopLoss = liquidity_level + (10 * Point);
    double risk = stopLoss - bid;
    
    double accountBalance = AccountInfoDouble(ACCOUNT_BALANCE);
    double riskAmount = accountBalance * (RiskPercentage / 100);
    double lot = NormalizeDouble(riskAmount / (risk / Point / SymbolInfoDouble(Symbol(), SYMBOL_TRADE_TICK_VALUE)), 2);
    
    lot = MathMin(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX));
    lot = MathMax(lot, SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN));
    
    double tp1 = bid - (MinProfitTP1 * Point);
    double tp2 = bid - (MinProfitTP2 * Point);
    
    if(trade.Sell(lot, Symbol(), bid, stopLoss, tp1, "SELL - SMC"))
    {
        RecordTrade(trade.ResultOrder(), Symbol(), bid, stopLoss, tp1, tp2, lot, -1);
        SendTelegramSignal("SELL", bid, stopLoss, tp1, tp2, false);
        DrawTradeSetup(bid, stopLoss, tp1, tp2, false);
    }
}

//+------------------------------------------------------------------+
//| RECORD TRADE                                                     |
//+------------------------------------------------------------------+
void RecordTrade(ulong ticket, string symbol, double entry, double sl, double tp1, double tp2, double lot, int reason)
{
    if(totalTrades >= ArraySize(tradeJournal) - 1)
        ArrayResize(tradeJournal, ArraySize(tradeJournal) + 50);
    
    tradeJournal[totalTrades].ticket = ticket;
    tradeJournal[totalTrades].symbol = symbol;
    tradeJournal[totalTrades].entryPrice = entry;
    tradeJournal[totalTrades].stopLoss = sl;
    tradeJournal[totalTrades].tp1 = tp1;
    tradeJournal[totalTrades].tp2 = tp2;
    tradeJournal[totalTrades].lot = lot;
    tradeJournal[totalTrades].reason = reason;
    tradeJournal[totalTrades].openTime = TimeCurrent();
    tradeJournal[totalTrades].isClosed = false;
    
    totalTrades++;
}

//+------------------------------------------------------------------+
//| UPDATE TRADE TRACKING                                            |
//+------------------------------------------------------------------+
void UpdateTradeTracking()
{
    // Placeholder for trade tracking updates
}

//+------------------------------------------------------------------+
//| CHECK CLOSED TRADES                                              |
//+------------------------------------------------------------------+
void CheckClosedTrades()
{
    // Placeholder for checking closed trades and sending results
}

//+------------------------------------------------------------------+
//| COUNT OPEN TRADES                                                |
//+------------------------------------------------------------------+
int CountOpenTrades()
{
    int count = 0;
    for(int i = 0; i < PositionsTotal(); i++)
    {
        if(PositionSelect(i) && PositionGetString(POSITION_SYMBOL) == Symbol())
        {
            if(PositionGetInteger(POSITION_MAGIC) == 123456)
                count++;
        }
    }
    return count;
}

//+------------------------------------------------------------------+
//| SEND TELEGRAM SIGNAL                                             |
//+------------------------------------------------------------------+
void SendTelegramSignal(string direction, double entry, double sl, double tp1, double tp2, bool isBuy)
{
    if(!EnableTelegram)
        return;
    
    string message = "🔔 NEW SIGNAL\n";
    message += "====================\n";
    message += "📊 PAIR: " + Symbol() + "\n";
    message += "📈 DIRECTION: " + direction + "\n\n";
    message += "💰 ENTRY: " + DoubleToString(entry, 5) + "\n";
    message += "🛑 STOP LOSS: " + DoubleToString(sl, 5) + "\n";
    message += "✅ TP1: " + DoubleToString(tp1, 5) + "\n";
    message += "✅ TP2: " + DoubleToString(tp2, 5) + "\n\n";
    message += "🧠 WHY THIS SIGNAL:\n";
    
    if(liquidityGrabDetected)
        message += "✓ Liquidity sweep detected\n";
    if(orderBlockConfirmed)
        message += "✓ Order Block confirmed\n";
    if(DetectMarketStructure())
        message += "✓ Market structure shift\n";
    if(multiTimeframeAligned)
        message += "✓ Multi-timeframe aligned\n";
    
    message += "\n⚠️ DISCIPLINE IS EDGE";
    
    SendTelegram(message);
    TakeScreenshot();
}

//+------------------------------------------------------------------+
//| SEND TELEGRAM RESULT                                             |
//+------------------------------------------------------------------+
void SendTelegramResult(TradeRecord &trade, bool isWin)
{
    if(!EnableTelegram)
        return;
    
    string message = isWin ? "🎯 WIN!\n" : "❌ LOSS\n";
    message += "====================\n";
    message += "📊 PAIR: " + trade.symbol + "\n";
    message += "💵 PROFIT: " + DoubleToString(trade.profit, 2) + " USD\n\n";
    message += isWin ? "💡 Good execution!\n" : "💡 Loss is learning!\n";
    
    SendTelegram(message);
}

//+------------------------------------------------------------------+
//| SEND PSYCHOLOGY MESSAGES                                         |
//+------------------------------------------------------------------+
void SendPsychologyMessages()
{
    if(!EnablePsychologyMessages)
        return;
    
    datetime currentTime = TimeCurrent();
    
    if(currentTime - lastPsychologyMessageTime > PsychologyMessageFrequency * 60)
    {
        lastPsychologyMessageTime = currentTime;
        
        int randomMessage = MathRand() % 5;
        string message = "";
        
        switch(randomMessage)
        {
            case 0:
                message = "🧠 Patience is a superpower.\nWait for high-probability setups.";
                break;
            case 1:
                message = "⚠️ Quality over quantity.\nMore trades = More risk.";
                break;
            case 2:
                message = "📈 Small edge, consistent application,\nbig wealth.";
                break;
            case 3:
                message = "💪 Ignore noise. Follow structure.";
                break;
            case 4:
                message = "🎯 Every loss teaches. Every win reinforces.";
                break;
        }
        
        SendTelegram(message);
    }
}

//+------------------------------------------------------------------+
//| SEND TELEGRAM                                                    |
//+------------------------------------------------------------------+
void SendTelegram(string message)
{
    if(!EnableTelegram || TelegramBotToken == "YOUR_BOT_TOKEN")
        return;
    
    string url = "https://api.telegram.org/bot" + TelegramBotToken + "/sendMessage";
    string data = "chat_id=" + TelegramChatID + "&text=" + message;
    
    char result[];
    string result_str = "";
    
    int res = WebRequest("POST", url, NULL, NULL, 5000, data, result, result_str);
}

//+------------------------------------------------------------------+
//| TAKE SCREENSHOT                                                  |
//+------------------------------------------------------------------+
void TakeScreenshot()
{
    string filename = "SMC_" + Symbol() + "_" + TimeToString(TimeCurrent()) + ".png";
    ChartScreenShot(0, filename, 1920, 1080);
}

//+------------------------------------------------------------------+
//| DRAW TRADE SETUP                                                 |
//+------------------------------------------------------------------+
void DrawTradeSetup(double entry, double sl, double tp1, double tp2, bool isBuy)
{
    ObjectCreate(0, drawingPrefix + "Entry", OBJ_HLINE, 0, 0, entry);
    ObjectSetInteger(0, drawingPrefix + "Entry", OBJPROP_COLOR, clrBlue);
    
    ObjectCreate(0, drawingPrefix + "SL", OBJ_HLINE, 0, 0, sl);
    ObjectSetInteger(0, drawingPrefix + "SL", OBJPROP_COLOR, clrRed);
    ObjectSetInteger(0, drawingPrefix + "SL", OBJPROP_STYLE, STYLE_DASHDOT);
    
    ObjectCreate(0, drawingPrefix + "TP1", OBJ_HLINE, 0, 0, tp1);
    ObjectSetInteger(0, drawingPrefix + "TP1", OBJPROP_COLOR, clrGreen);
    
    ObjectCreate(0, drawingPrefix + "TP2", OBJ_HLINE, 0, 0, tp2);
    ObjectSetInteger(0, drawingPrefix + "TP2", OBJPROP_COLOR, clrGreen);
}

//+------------------------------------------------------------------+
//| DRAW STRUCTURE                                                   |
//+------------------------------------------------------------------+
void DrawStructure(string structure, double price, color clr)
{
    ObjectCreate(0, drawingPrefix + structure + "_" + TimeCurrent(), OBJ_TEXT, 0, TimeCurrent(), price);
    ObjectSetString(0, drawingPrefix + structure + "_" + TimeCurrent(), OBJPROP_TEXT, structure);
    ObjectSetInteger(0, drawingPrefix + structure + "_" + TimeCurrent(), OBJPROP_COLOR, clr);
}

//+------------------------------------------------------------------+
//| DRAW LIQUIDITY ZONE                                              |
//+------------------------------------------------------------------+
void DrawLiquidityZone(double level)
{
    ObjectCreate(0, drawingPrefix + "Liquidity", OBJ_HLINE, 0, 0, level);
    ObjectSetInteger(0, drawingPrefix + "Liquidity", OBJPROP_COLOR, clrYellow);
    ObjectSetInteger(0, drawingPrefix + "Liquidity", OBJPROP_STYLE, STYLE_DOT);
}

//+------------------------------------------------------------------+
//| DRAW ORDER BLOCK                                                 |
//+------------------------------------------------------------------+
void DrawOrderBlock(double level, bool isBullish)
{
    ObjectCreate(0, drawingPrefix + "OB_" + TimeCurrent(), OBJ_RECTANGLE, 0,
                 TimeCurrent() - 3600, level - 50*Point, TimeCurrent(), level + 50*Point);
    ObjectSetInteger(0, drawingPrefix + "OB_" + TimeCurrent(), OBJPROP_COLOR, isBullish ? clrGreen : clrRed);
    ObjectSetInteger(0, drawingPrefix + "OB_" + TimeCurrent(), OBJPROP_FILL, true);
}

//+------------------------------------------------------------------+
//| DRAW FVG                                                         |
//+------------------------------------------------------------------+
void DrawFVG(double level, bool isBullish)
{
    ObjectCreate(0, drawingPrefix + "FVG_" + TimeCurrent(), OBJ_RECTANGLE, 0,
                 TimeCurrent() - 3600, level - 20*Point, TimeCurrent(), level + 20*Point);
    ObjectSetInteger(0, drawingPrefix + "FVG_" + TimeCurrent(), OBJPROP_COLOR, clrCyan);
    ObjectSetInteger(0, drawingPrefix + "FVG_" + TimeCurrent(), OBJPROP_FILL, true);
}

//+------------------------------------------------------------------+
//| UPDATE DASHBOARD                                                 |
//+------------------------------------------------------------------+
void UpdateDashboard()
{
    double winRate = totalTrades > 0 ? (double)winTrades / totalTrades * 100 : 0;
    string riskStatus = totalProfit > 0 ? "SAFE ✓" : "CAUTION ⚠";
    
    string dashboard = "╔════════════════════════════════╗\n";
    dashboard += "║   SMC TRADING DASHBOARD        ║\n";
    dashboard += "╠════════════════════════════════╣\n";
    dashboard += "║ WIN RATE: " + DoubleToString(winRate, 1) + "%              ║\n";
    dashboard += "║ TOTAL TRADES: " + IntegerToString(totalTrades) + "              ║\n";
    dashboard += "║ WINS: " + IntegerToString(winTrades) + " | LOSSES: " + IntegerToString(lossTrades) + "         ║\n";
    dashboard += "║ DAILY PNL: " + DoubleToString(totalProfit, 2) + " USD       ║\n";
    dashboard += "║ RISK STATUS: " + riskStatus + "      ║\n";
    dashboard += "║ MODE: LIVE                     ║\n";
    dashboard += "╚════════════════════════════════╝";
    
    Comment(dashboard);
}

//+------------------------------------------------------------------+
//| TIMER EVENT                                                      |
//+------------------------------------------------------------------+
void OnTimer()
{
    UpdateDashboard();
}

//+------------------------------------------------------------------+
