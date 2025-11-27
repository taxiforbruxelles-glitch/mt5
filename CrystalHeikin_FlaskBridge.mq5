//+------------------------------------------------------------------+
//|                                    CrystalHeikin_FlaskBridge.mq5 |
//|                                         Crystal Flask Bridge     |
//|                     Multi-Symboles - Lit indicateurs sur N actifs|
//+------------------------------------------------------------------+
#property copyright "Crystal Flask Bridge 2025"
#property link      ""
#property version   "3.00"
#property strict

//--- Paramètres d'entrée
input string   FlaskServerURL = "http://127.0.0.1:5000";  // URL du serveur Flask
input int      UpdateInterval = 1;     // Intervalle de mise à jour (secondes)
input bool     SendOnNewBar = true;    // Envoyer sur nouvelle bougie
input bool     SendOnTick = false;     // Envoyer sur chaque tick
input bool     EnableTrading = true;   // Activer les commandes de trading
input double   DefaultLotSize = 0.01;  // Lot par défaut
input int      Slippage = 10;          // Slippage autorisé

//--- MULTI-SYMBOLES
input string   Sep0 = "=== MULTI-SYMBOLES ===";  // --- Multi-Symboles ---
input bool     EnableMultiSymbol = true;          // Activer multi-symboles
input string   WatchSymbols = "EURUSD,GBPUSD,USDJPY,XAUUSD,BTCUSD"; // Symboles à surveiller (séparés par virgule)
input ENUM_TIMEFRAMES WatchTimeframe = PERIOD_M15; // Timeframe pour tous les symboles

//--- Indicateurs à utiliser
input string   Sep1 = "=== INDICATEURS ===";  // --- Indicateurs ---
input bool     UseHeikinAshi = true;          // Utiliser Crystal Heikin Ashi
input string   HeikinAshiName = "Market\\Crystal Heikin Ashi";
input bool     UseCriticalZones = true;       // Critical Zones MT5
input string   CriticalZonesName = "Market\\Critical Zones MT5";
input bool     UseSupplyDemand = false;       // Basic Supply Demand MT5 (LENT)
input string   SupplyDemandName = "Market\\Basic Supply Demand MT5";
input bool     UseVWAP = false;               // Full VWAP (LENT)
input string   VWAPName = "Market\\Full VWAP";
input bool     UseAnchoredVWAP = false;       // Anchored VWAP indicator
input string   AnchoredVWAPName = "Market\\Anchored VWAP indicator";
input bool     UseVolumeProfile = false;      // Crystal Volume Profile Auto POC (LENT)
input string   VolumeProfileName = "Market\\Crystal Volume Profile Auto POC";
input bool     UseHarmonicPattern = false;    // Basic Harmonic Pattern MT5 (LENT)
input string   HarmonicPatternName = "Market\\Basic Harmonic Pattern MT5";
input bool     UseSuperTrend = true;          // LT Super Trend
input string   SuperTrendName = "Market\\LT Super Trend";
input bool     UseFiboExpansion = true;       // Auto Fibo MT5
input string   FiboExpansionName = "Market\\Auto Fibo MT5";
input bool     UseDrawFibPro = false;         // WH DrawFib Pro MT5
input string   DrawFibProName = "Market\\WH DrawFib Pro MT5";
input bool     UseCandlestickPatterns = false; // Basic Candlestick Patterns MT5
input string   CandlestickPatternsName = "Market\\Basic Candlestick Patterns MT5";
input bool     UseBollingerRSI = false;       // Bollinger RSI ReEntry
input string   BollingerRSIName = "Market\\Bollinger RSI ReEntry";
input bool     UseFVG = false;                // Haven FVG Indicator
input string   FVGName = "Market\\Haven FVG Indicator";
input bool     UseMACDIntraday = false;       // MACD Intraday Trend
input string   MACDIntradayName = "Market\\MACD Intraday Trend";
input bool     UseProSupportResistance = false; // Pro Support Resistance MT5
input string   ProSupportResistanceName = "Market\\Pro Support Resistance MT5";

//--- Structure pour stocker les données d'un symbole
struct SymbolData
{
    string symbol;
    int heikinHandle;
    int criticalZonesHandle;
    int supplyDemandHandle;
    int vwapHandle;
    int anchoredVwapHandle;
    int volumeProfileHandle;
    int harmonicHandle;
    int superTrendHandle;
    int fiboExpansionHandle;
    int drawFibProHandle;
    int candlestickPatternsHandle;
    int bollingerRSIHandle;
    int fvgHandle;
    int macdIntradayHandle;
    int proSupportResistanceHandle;
    datetime lastBarTime;
};

//--- Tableau des symboles surveillés
SymbolData g_symbols[];
int g_symbolCount = 0;

//--- Variables globales
datetime g_lastUpdateTime = 0;

//+------------------------------------------------------------------+
//| Expert initialization function                                     |
//+------------------------------------------------------------------+
int OnInit()
{
    Print("===========================================");
    Print("Crystal Flask Bridge v3.0 - Multi-Symboles");
    Print("Serveur: ", FlaskServerURL);
    Print("===========================================");
    
    //--- Parser les symboles à surveiller
    string symbolList[];
    int count = 0;
    
    if(EnableMultiSymbol && WatchSymbols != "")
    {
        count = StringSplit(WatchSymbols, ',', symbolList);
    }
    
    //--- Toujours ajouter le symbole du graphique actuel
    bool currentFound = false;
    for(int i = 0; i < count; i++)
    {
        StringTrimLeft(symbolList[i]);
        StringTrimRight(symbolList[i]);
        if(symbolList[i] == _Symbol) currentFound = true;
    }
    
    if(!currentFound)
    {
        ArrayResize(symbolList, count + 1);
        symbolList[count] = _Symbol;
        count++;
    }
    
    //--- Initialiser les handles pour chaque symbole
    ArrayResize(g_symbols, count);
    g_symbolCount = 0;
    
    for(int i = 0; i < count; i++)
    {
        string sym = symbolList[i];
        
        //--- Vérifier que le symbole existe
        if(!SymbolSelect(sym, true))
        {
            Print("[WARN] Symbole ", sym, " non disponible - ignore");
            continue;
        }
        
        g_symbols[g_symbolCount].symbol = sym;
        g_symbols[g_symbolCount].lastBarTime = 0;
        
        //--- Créer les handles pour ce symbole
        InitSymbolHandles(g_symbolCount, sym);
        
        g_symbolCount++;
        Print("[OK] Symbole ", sym, " ajoute");
    }
    
    ArrayResize(g_symbols, g_symbolCount);
    
    Print("===========================================");
    Print("Total: ", g_symbolCount, " symboles surveilles");
    Print("Timeframe: ", EnumToString(WatchTimeframe));
    Print("===========================================");
    
    //--- Envoyer immédiatement un signal de test pour chaque symbole
    Print("[INIT] Envoi des signaux initiaux...");
    for(int i = 0; i < g_symbolCount; i++)
    {
        Print("[INIT] Traitement ", g_symbols[i].symbol);
        ProcessSymbol(i);
    }
    Print("[INIT] Signaux initiaux envoyes");
    
    return(INIT_SUCCEEDED);
}

//+------------------------------------------------------------------+
//| Initialiser les handles d'indicateurs pour un symbole             |
//+------------------------------------------------------------------+
void InitSymbolHandles(int idx, string sym)
{
    ENUM_TIMEFRAMES tf = WatchTimeframe;
    
    //--- Heikin Ashi
    g_symbols[idx].heikinHandle = INVALID_HANDLE;
    if(UseHeikinAshi)
    {
        g_symbols[idx].heikinHandle = iCustom(sym, tf, HeikinAshiName);
        if(g_symbols[idx].heikinHandle == INVALID_HANDLE)
            Print("[", sym, "] Heikin Ashi non charge");
    }
    
    //--- Critical Zones
    g_symbols[idx].criticalZonesHandle = INVALID_HANDLE;
    if(UseCriticalZones)
    {
        g_symbols[idx].criticalZonesHandle = iCustom(sym, tf, CriticalZonesName);
        if(g_symbols[idx].criticalZonesHandle == INVALID_HANDLE)
            Print("[", sym, "] Critical Zones non charge");
    }
    
    //--- Supply Demand
    g_symbols[idx].supplyDemandHandle = INVALID_HANDLE;
    if(UseSupplyDemand)
    {
        g_symbols[idx].supplyDemandHandle = iCustom(sym, tf, SupplyDemandName);
        if(g_symbols[idx].supplyDemandHandle == INVALID_HANDLE)
            Print("[", sym, "] Supply Demand non charge");
    }
    
    //--- VWAP
    g_symbols[idx].vwapHandle = INVALID_HANDLE;
    if(UseVWAP)
    {
        g_symbols[idx].vwapHandle = iCustom(sym, tf, VWAPName);
        if(g_symbols[idx].vwapHandle == INVALID_HANDLE)
            Print("[", sym, "] Full VWAP non charge");
    }
    
    //--- Anchored VWAP
    g_symbols[idx].anchoredVwapHandle = INVALID_HANDLE;
    if(UseAnchoredVWAP)
    {
        g_symbols[idx].anchoredVwapHandle = iCustom(sym, tf, AnchoredVWAPName);
        if(g_symbols[idx].anchoredVwapHandle == INVALID_HANDLE)
            Print("[", sym, "] Anchored VWAP non charge");
    }
    
    //--- Volume Profile
    g_symbols[idx].volumeProfileHandle = INVALID_HANDLE;
    if(UseVolumeProfile)
    {
        g_symbols[idx].volumeProfileHandle = iCustom(sym, tf, VolumeProfileName);
        if(g_symbols[idx].volumeProfileHandle == INVALID_HANDLE)
            Print("[", sym, "] Volume Profile non charge");
    }
    
    //--- Harmonic Pattern
    g_symbols[idx].harmonicHandle = INVALID_HANDLE;
    if(UseHarmonicPattern)
    {
        g_symbols[idx].harmonicHandle = iCustom(sym, tf, HarmonicPatternName);
        if(g_symbols[idx].harmonicHandle == INVALID_HANDLE)
            Print("[", sym, "] Harmonic Pattern non charge");
    }
    
    //--- Super Trend
    g_symbols[idx].superTrendHandle = INVALID_HANDLE;
    if(UseSuperTrend)
    {
        g_symbols[idx].superTrendHandle = iCustom(sym, tf, SuperTrendName);
        if(g_symbols[idx].superTrendHandle == INVALID_HANDLE)
            Print("[", sym, "] Super Trend non charge");
    }
    
    //--- Fibo Expansion (Auto Fibo MT5)
    g_symbols[idx].fiboExpansionHandle = INVALID_HANDLE;
    if(UseFiboExpansion)
    {
        g_symbols[idx].fiboExpansionHandle = iCustom(sym, tf, FiboExpansionName);
        if(g_symbols[idx].fiboExpansionHandle == INVALID_HANDLE)
            Print("[", sym, "] Auto Fibo MT5 non charge");
    }
    
    //--- DrawFib Pro
    g_symbols[idx].drawFibProHandle = INVALID_HANDLE;
    if(UseDrawFibPro)
    {
        g_symbols[idx].drawFibProHandle = iCustom(sym, tf, DrawFibProName);
        if(g_symbols[idx].drawFibProHandle == INVALID_HANDLE)
            Print("[", sym, "] WH DrawFib Pro non charge");
    }
    
    //--- Candlestick Patterns
    g_symbols[idx].candlestickPatternsHandle = INVALID_HANDLE;
    if(UseCandlestickPatterns)
    {
        g_symbols[idx].candlestickPatternsHandle = iCustom(sym, tf, CandlestickPatternsName);
        if(g_symbols[idx].candlestickPatternsHandle == INVALID_HANDLE)
            Print("[", sym, "] Candlestick Patterns non charge");
    }
    
    //--- Bollinger RSI ReEntry
    g_symbols[idx].bollingerRSIHandle = INVALID_HANDLE;
    if(UseBollingerRSI)
    {
        g_symbols[idx].bollingerRSIHandle = iCustom(sym, tf, BollingerRSIName);
        if(g_symbols[idx].bollingerRSIHandle == INVALID_HANDLE)
            Print("[", sym, "] Bollinger RSI non charge");
    }
    
    //--- FVG (Fair Value Gap)
    g_symbols[idx].fvgHandle = INVALID_HANDLE;
    if(UseFVG)
    {
        g_symbols[idx].fvgHandle = iCustom(sym, tf, FVGName);
        if(g_symbols[idx].fvgHandle == INVALID_HANDLE)
            Print("[", sym, "] Haven FVG non charge");
    }
    
    //--- MACD Intraday Trend
    g_symbols[idx].macdIntradayHandle = INVALID_HANDLE;
    if(UseMACDIntraday)
    {
        g_symbols[idx].macdIntradayHandle = iCustom(sym, tf, MACDIntradayName);
        if(g_symbols[idx].macdIntradayHandle == INVALID_HANDLE)
            Print("[", sym, "] MACD Intraday non charge");
    }
    
    //--- Pro Support Resistance
    g_symbols[idx].proSupportResistanceHandle = INVALID_HANDLE;
    if(UseProSupportResistance)
    {
        g_symbols[idx].proSupportResistanceHandle = iCustom(sym, tf, ProSupportResistanceName);
        if(g_symbols[idx].proSupportResistanceHandle == INVALID_HANDLE)
            Print("[", sym, "] Pro Support Resistance non charge");
    }
}

//+------------------------------------------------------------------+
//| Expert deinitialization function                                   |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
{
    for(int i = 0; i < g_symbolCount; i++)
    {
        if(g_symbols[i].heikinHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].heikinHandle);
        if(g_symbols[i].criticalZonesHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].criticalZonesHandle);
        if(g_symbols[i].supplyDemandHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].supplyDemandHandle);
        if(g_symbols[i].vwapHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].vwapHandle);
        if(g_symbols[i].anchoredVwapHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].anchoredVwapHandle);
        if(g_symbols[i].volumeProfileHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].volumeProfileHandle);
        if(g_symbols[i].harmonicHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].harmonicHandle);
        if(g_symbols[i].superTrendHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].superTrendHandle);
        if(g_symbols[i].fiboExpansionHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].fiboExpansionHandle);
        if(g_symbols[i].drawFibProHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].drawFibProHandle);
        if(g_symbols[i].candlestickPatternsHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].candlestickPatternsHandle);
        if(g_symbols[i].bollingerRSIHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].bollingerRSIHandle);
        if(g_symbols[i].fvgHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].fvgHandle);
        if(g_symbols[i].macdIntradayHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].macdIntradayHandle);
        if(g_symbols[i].proSupportResistanceHandle != INVALID_HANDLE) IndicatorRelease(g_symbols[i].proSupportResistanceHandle);
    }
    Print("Crystal Flask Bridge arrete");
}

//+------------------------------------------------------------------+
//| Expert tick function                                               |
//+------------------------------------------------------------------+
void OnTick()
{
    //--- Vérifier si on doit mettre à jour
    datetime currentTime = TimeCurrent();
    bool shouldUpdate = false;
    
    //--- Update sur intervalle de temps
    if((currentTime - g_lastUpdateTime) >= UpdateInterval)
    {
        shouldUpdate = true;
        g_lastUpdateTime = currentTime;
    }
    
    //--- Update sur nouvelle bougie
    if(SendOnNewBar)
    {
        for(int i = 0; i < g_symbolCount; i++)
        {
            datetime barTime = iTime(g_symbols[i].symbol, WatchTimeframe, 0);
            if(barTime > g_symbols[i].lastBarTime)
            {
                g_symbols[i].lastBarTime = barTime;
                shouldUpdate = true;
            }
        }
    }
    
    //--- Update sur chaque tick
    if(SendOnTick)
    {
        shouldUpdate = true;
    }
    
    if(shouldUpdate)
    {
        Print("[TICK] Mise a jour de ", g_symbolCount, " symboles...");
        //--- Traiter chaque symbole
        for(int i = 0; i < g_symbolCount; i++)
        {
            Print("[TICK] Traitement ", g_symbols[i].symbol, "...");
            ProcessSymbol(i);
            Print("[TICK] ", g_symbols[i].symbol, " termine");
        }
        Print("[TICK] Tous les symboles traites");
    }
    
    //--- Vérifier les trades en attente
    if(EnableTrading)
    {
        static datetime lastTradeCheck = 0;
        if((currentTime - lastTradeCheck) >= 1)
        {
            lastTradeCheck = currentTime;
            CheckPendingTrades();
        }
    }
}

//+------------------------------------------------------------------+
//| Traiter un symbole et envoyer les signaux                         |
//+------------------------------------------------------------------+
void ProcessSymbol(int idx)
{
    string sym = g_symbols[idx].symbol;
    
    //--- Buffers temporaires
    double haOpen[], haHigh[], haLow[], haClose[], haColor[];
    double resistance[], support[];
    double supply[], demand[];
    double vwap[], vwapUp[], vwapDown[];
    double poc[];
    double harmonic[];
    double stUp[], stDown[];
    double fibo1[], fibo2[], fibo3[];
    double anchoredVwapBuf[];
    double drawFibBuf[];
    double candleBuf[];
    double bollingerBuf[];
    double fvgBuf[];
    double macdBuf[];
    double proSRBuf[];
    
    //--- Initialiser les valeurs
    double ha_open = 0, ha_high = 0, ha_low = 0, ha_close = 0;
    string trend = "NEUTRAL";
    int momentum_shift = 0;
    double resistanceVal = 0, supportVal = 0;
    double supplyVal = 0, demandVal = 0;
    double vwapVal = 0, vwapUpperVal = 0, vwapLowerVal = 0;
    double pocVal = 0;
    string harmonicPattern = "NONE";
    string pricePosition = "NEUTRAL";
    double superTrendUp = 0, superTrendDown = 0;
    string superTrendDir = "NEUTRAL";
    double fiboLevel1 = 0, fiboLevel2 = 0, fiboLevel3 = 0;
    
    // Nouveaux indicateurs
    double anchoredVwapVal = 0;
    double drawFibVal1 = 0, drawFibVal2 = 0, drawFibVal3 = 0;
    string candlePattern = "NONE";
    double bollingerSignal = 0;
    string bollingerDir = "NEUTRAL";
    double fvgHigh = 0, fvgLow = 0;
    string fvgType = "NONE";
    double macdMain = 0, macdSignal = 0;
    string macdTrend = "NEUTRAL";
    double proResistance = 0, proSupport = 0;
    
    //--- Lire Heikin Ashi
    if(g_symbols[idx].heikinHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].heikinHandle, 0, 0, 2, haOpen) > 0)
            ha_open = haOpen[0];
        if(CopyBuffer(g_symbols[idx].heikinHandle, 1, 0, 2, haHigh) > 0)
            ha_high = haHigh[0];
        if(CopyBuffer(g_symbols[idx].heikinHandle, 2, 0, 2, haLow) > 0)
            ha_low = haLow[0];
        if(CopyBuffer(g_symbols[idx].heikinHandle, 3, 0, 2, haClose) > 0)
            ha_close = haClose[0];
        if(CopyBuffer(g_symbols[idx].heikinHandle, 4, 0, 2, haColor) > 0)
        {
            if(haColor[0] == 0) trend = "BULLISH";
            else if(haColor[0] == 1) trend = "BEARISH";
            
            if(ArraySize(haColor) >= 2 && haColor[0] != haColor[1])
                momentum_shift = 1;
        }
    }
    
    //--- Lire Critical Zones
    if(g_symbols[idx].criticalZonesHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].criticalZonesHandle, 0, 0, 1, resistance) > 0)
            resistanceVal = resistance[0];
        if(CopyBuffer(g_symbols[idx].criticalZonesHandle, 1, 0, 1, support) > 0)
            supportVal = support[0];
    }
    
    //--- Lire Supply Demand
    if(g_symbols[idx].supplyDemandHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].supplyDemandHandle, 0, 0, 1, supply) > 0)
            supplyVal = supply[0];
        if(CopyBuffer(g_symbols[idx].supplyDemandHandle, 1, 0, 1, demand) > 0)
            demandVal = demand[0];
    }
    
    //--- Lire VWAP
    if(g_symbols[idx].vwapHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].vwapHandle, 0, 0, 1, vwap) > 0)
            vwapVal = vwap[0];
        if(CopyBuffer(g_symbols[idx].vwapHandle, 1, 0, 1, vwapUp) > 0)
            vwapUpperVal = vwapUp[0];
        if(CopyBuffer(g_symbols[idx].vwapHandle, 2, 0, 1, vwapDown) > 0)
            vwapLowerVal = vwapDown[0];
        
        double currentPrice = SymbolInfoDouble(sym, SYMBOL_BID);
        if(vwapVal > 0)
        {
            if(currentPrice > vwapVal) pricePosition = "ABOVE_VWAP";
            else if(currentPrice < vwapVal) pricePosition = "BELOW_VWAP";
        }
    }
    
    //--- Lire Volume Profile (POC)
    if(g_symbols[idx].volumeProfileHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].volumeProfileHandle, 0, 0, 1, poc) > 0)
            pocVal = poc[0];
    }
    
    //--- Lire Harmonic Pattern
    if(g_symbols[idx].harmonicHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].harmonicHandle, 0, 0, 1, harmonic) > 0)
        {
            if(harmonic[0] > 0) harmonicPattern = "BULLISH";
            else if(harmonic[0] < 0) harmonicPattern = "BEARISH";
            else if(harmonic[0] != 0 && harmonic[0] != EMPTY_VALUE) harmonicPattern = "DETECTED";
        }
    }
    
    //--- Lire Super Trend
    if(g_symbols[idx].superTrendHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].superTrendHandle, 0, 0, 1, stUp) > 0)
            superTrendUp = stUp[0];
        if(CopyBuffer(g_symbols[idx].superTrendHandle, 1, 0, 1, stDown) > 0)
            superTrendDown = stDown[0];
        
        double currentPrice = SymbolInfoDouble(sym, SYMBOL_BID);
        if(superTrendUp > 0 && superTrendUp != EMPTY_VALUE && currentPrice > superTrendUp)
            superTrendDir = "BULLISH";
        else if(superTrendDown > 0 && superTrendDown != EMPTY_VALUE && currentPrice < superTrendDown)
            superTrendDir = "BEARISH";
    }
    
    //--- Lire Fibo Expansion
    if(g_symbols[idx].fiboExpansionHandle != INVALID_HANDLE)
    {
        // Debug: tester tous les buffers
        double testBuf[];
        ArrayResize(testBuf, 1);
        for(int b = 0; b < 10; b++)
        {
            if(CopyBuffer(g_symbols[idx].fiboExpansionHandle, b, 0, 1, testBuf) > 0)
            {
                if(testBuf[0] != 0 && testBuf[0] != EMPTY_VALUE)
                    Print("[FIBO] ", sym, " Buffer[", b, "] = ", testBuf[0]);
            }
        }
        
        if(CopyBuffer(g_symbols[idx].fiboExpansionHandle, 0, 0, 1, fibo1) > 0)
            fiboLevel1 = fibo1[0];
        if(CopyBuffer(g_symbols[idx].fiboExpansionHandle, 1, 0, 1, fibo2) > 0)
            fiboLevel2 = fibo2[0];
        if(CopyBuffer(g_symbols[idx].fiboExpansionHandle, 2, 0, 1, fibo3) > 0)
            fiboLevel3 = fibo3[0];
    }
    
    //--- Lire Anchored VWAP
    if(g_symbols[idx].anchoredVwapHandle != INVALID_HANDLE)
    {
        if(CopyBuffer(g_symbols[idx].anchoredVwapHandle, 0, 0, 1, anchoredVwapBuf) > 0)
            anchoredVwapVal = anchoredVwapBuf[0];
    }
    
    //--- Lire DrawFib Pro
    if(g_symbols[idx].drawFibProHandle != INVALID_HANDLE)
    {
        double buf[];
        if(CopyBuffer(g_symbols[idx].drawFibProHandle, 0, 0, 1, buf) > 0)
            drawFibVal1 = buf[0];
        if(CopyBuffer(g_symbols[idx].drawFibProHandle, 1, 0, 1, buf) > 0)
            drawFibVal2 = buf[0];
        if(CopyBuffer(g_symbols[idx].drawFibProHandle, 2, 0, 1, buf) > 0)
            drawFibVal3 = buf[0];
    }
    
    //--- Lire Candlestick Patterns
    if(g_symbols[idx].candlestickPatternsHandle != INVALID_HANDLE)
    {
        double buf[];
        if(CopyBuffer(g_symbols[idx].candlestickPatternsHandle, 0, 0, 1, buf) > 0)
        {
            if(buf[0] > 0) candlePattern = "BULLISH";
            else if(buf[0] < 0) candlePattern = "BEARISH";
        }
    }
    
    //--- Lire Bollinger RSI
    if(g_symbols[idx].bollingerRSIHandle != INVALID_HANDLE)
    {
        double buf[];
        if(CopyBuffer(g_symbols[idx].bollingerRSIHandle, 0, 0, 1, buf) > 0)
        {
            bollingerSignal = buf[0];
            if(buf[0] > 0) bollingerDir = "BULLISH";
            else if(buf[0] < 0) bollingerDir = "BEARISH";
        }
    }
    
    //--- Lire FVG
    if(g_symbols[idx].fvgHandle != INVALID_HANDLE)
    {
        double bufHigh[], bufLow[], bufType[];
        if(CopyBuffer(g_symbols[idx].fvgHandle, 0, 0, 1, bufHigh) > 0)
            fvgHigh = bufHigh[0];
        if(CopyBuffer(g_symbols[idx].fvgHandle, 1, 0, 1, bufLow) > 0)
            fvgLow = bufLow[0];
        if(CopyBuffer(g_symbols[idx].fvgHandle, 2, 0, 1, bufType) > 0)
        {
            if(bufType[0] > 0) fvgType = "BULLISH";
            else if(bufType[0] < 0) fvgType = "BEARISH";
        }
    }
    
    //--- Lire MACD Intraday
    if(g_symbols[idx].macdIntradayHandle != INVALID_HANDLE)
    {
        double bufMain[], bufSignal[];
        if(CopyBuffer(g_symbols[idx].macdIntradayHandle, 0, 0, 1, bufMain) > 0)
            macdMain = bufMain[0];
        if(CopyBuffer(g_symbols[idx].macdIntradayHandle, 1, 0, 1, bufSignal) > 0)
            macdSignal = bufSignal[0];
        
        if(macdMain > macdSignal) macdTrend = "BULLISH";
        else if(macdMain < macdSignal) macdTrend = "BEARISH";
    }
    
    //--- Lire Pro Support Resistance
    if(g_symbols[idx].proSupportResistanceHandle != INVALID_HANDLE)
    {
        double bufRes[], bufSup[];
        if(CopyBuffer(g_symbols[idx].proSupportResistanceHandle, 0, 0, 1, bufRes) > 0)
            proResistance = bufRes[0];
        if(CopyBuffer(g_symbols[idx].proSupportResistanceHandle, 1, 0, 1, bufSup) > 0)
            proSupport = bufSup[0];
    }
    
    //--- Récupérer prix bid/ask
    double bid = SymbolInfoDouble(sym, SYMBOL_BID);
    double ask = SymbolInfoDouble(sym, SYMBOL_ASK);
    double spread = (ask - bid) / SymbolInfoDouble(sym, SYMBOL_POINT);
    
    //--- Construire le JSON
    string json = "{";
    json += "\"symbol\":\"" + sym + "\",";
    json += "\"timeframe\":\"" + EnumToString(WatchTimeframe) + "\",";
    json += "\"signal_type\":\"INDICATOR\",";
    json += "\"ha_open\":" + DoubleToString(ha_open, 5) + ",";
    json += "\"ha_high\":" + DoubleToString(ha_high, 5) + ",";
    json += "\"ha_low\":" + DoubleToString(ha_low, 5) + ",";
    json += "\"ha_close\":" + DoubleToString(ha_close, 5) + ",";
    json += "\"trend\":\"" + trend + "\",";
    json += "\"momentum_shift\":" + IntegerToString(momentum_shift) + ",";
    json += "\"bid\":" + DoubleToString(bid, 5) + ",";
    json += "\"ask\":" + DoubleToString(ask, 5) + ",";
    json += "\"spread\":" + DoubleToString(spread, 1) + ",";
    json += "\"resistance\":" + DoubleToString(resistanceVal, 5) + ",";
    json += "\"support\":" + DoubleToString(supportVal, 5) + ",";
    json += "\"supply_zone\":" + DoubleToString(supplyVal, 5) + ",";
    json += "\"demand_zone\":" + DoubleToString(demandVal, 5) + ",";
    json += "\"vwap\":" + DoubleToString(vwapVal, 5) + ",";
    json += "\"vwap_upper\":" + DoubleToString(vwapUpperVal, 5) + ",";
    json += "\"vwap_lower\":" + DoubleToString(vwapLowerVal, 5) + ",";
    json += "\"anchored_vwap\":" + DoubleToString(anchoredVwapVal, 5) + ",";
    json += "\"poc\":" + DoubleToString(pocVal, 5) + ",";
    json += "\"harmonic_pattern\":\"" + harmonicPattern + "\",";
    json += "\"price_position\":\"" + pricePosition + "\",";
    json += "\"supertrend_up\":" + DoubleToString(superTrendUp, 5) + ",";
    json += "\"supertrend_down\":" + DoubleToString(superTrendDown, 5) + ",";
    json += "\"supertrend_direction\":\"" + superTrendDir + "\",";
    json += "\"fibo_level1\":" + DoubleToString(fiboLevel1, 5) + ",";
    json += "\"fibo_level2\":" + DoubleToString(fiboLevel2, 5) + ",";
    json += "\"fibo_level3\":" + DoubleToString(fiboLevel3, 5) + ",";
    json += "\"drawfib_level1\":" + DoubleToString(drawFibVal1, 5) + ",";
    json += "\"drawfib_level2\":" + DoubleToString(drawFibVal2, 5) + ",";
    json += "\"drawfib_level3\":" + DoubleToString(drawFibVal3, 5) + ",";
    json += "\"candle_pattern\":\"" + candlePattern + "\",";
    json += "\"bollinger_signal\":" + DoubleToString(bollingerSignal, 5) + ",";
    json += "\"bollinger_direction\":\"" + bollingerDir + "\",";
    json += "\"fvg_high\":" + DoubleToString(fvgHigh, 5) + ",";
    json += "\"fvg_low\":" + DoubleToString(fvgLow, 5) + ",";
    json += "\"fvg_type\":\"" + fvgType + "\",";
    json += "\"macd_main\":" + DoubleToString(macdMain, 5) + ",";
    json += "\"macd_signal\":" + DoubleToString(macdSignal, 5) + ",";
    json += "\"macd_trend\":\"" + macdTrend + "\",";
    json += "\"pro_resistance\":" + DoubleToString(proResistance, 5) + ",";
    json += "\"pro_support\":" + DoubleToString(proSupport, 5);
    json += "}";
    
    //--- Envoyer au serveur Flask
    SendToFlask(json);
}

//+------------------------------------------------------------------+
//| Envoyer les données au serveur Flask                              |
//+------------------------------------------------------------------+
void SendToFlask(string json)
{
    string url = FlaskServerURL + "/api/signal";
    string headers = "Content-Type: application/json\r\n";
    char postData[];
    char result[];
    string resultHeaders;
    
    StringToCharArray(json, postData, 0, StringLen(json));
    ArrayResize(postData, StringLen(json));
    
    Print("[HTTP] Envoi vers: ", url);
    
    int timeout = 10000;  // 10 secondes
    int res = WebRequest("POST", url, headers, timeout, postData, result, resultHeaders);
    
    if(res == -1)
    {
        int error = GetLastError();
        Print("[ERROR] WebRequest erreur code: ", error);
        if(error == 4060)
        {
            Print("[ERROR] WebRequest non autorise!");
            Print("[ERROR] Outils > Options > Expert Advisors");
            Print("[ERROR] Cocher 'Autoriser WebRequest pour ces URL'");
            Print("[ERROR] Ajouter: ", FlaskServerURL);
        }
        else if(error == 4014)
        {
            Print("[ERROR] Fonction WebRequest non autorisee pour cet EA");
        }
    }
    else if(res == 200)
    {
        int symStart = StringFind(json, "\"symbol\":\"") + 10;
        int symEnd = StringFind(json, "\"", symStart);
        string sym = StringSubstr(json, symStart, symEnd - symStart);
        Print("[SENT] Signal ", sym, " OK");
    }
    else
    {
        string response = CharArrayToString(result);
        Print("[WARN] HTTP ", res, " - ", StringSubstr(response, 0, 100));
    }
}

//+------------------------------------------------------------------+
//| Vérifier les trades en attente                                     |
//+------------------------------------------------------------------+
void CheckPendingTrades()
{
    string url = FlaskServerURL + "/api/pending_trades";
    string headers = "";
    char postData[];
    char result[];
    string resultHeaders;
    
    int res = WebRequest("GET", url, headers, 3000, postData, result, resultHeaders);
    
    if(res != 200) return;
    
    string response = CharArrayToString(result);
    
    if(StringFind(response, "\"trades\": []") >= 0 || StringFind(response, "\"trades\":[]") >= 0)
        return;
    
    int tradesStart = StringFind(response, "[");
    int tradesEnd = StringFind(response, "]");
    
    if(tradesStart < 0 || tradesEnd < 0) return;
    
    string tradesJson = StringSubstr(response, tradesStart, tradesEnd - tradesStart + 1);
    ParseAndExecuteTrades(tradesJson);
}

//+------------------------------------------------------------------+
//| Parser et exécuter les trades                                      |
//+------------------------------------------------------------------+
void ParseAndExecuteTrades(string tradesJson)
{
    Print("[DEBUG] Parsing trades: ", tradesJson);
    
    //--- Extraire l'ID du trade
    int idPos = StringFind(tradesJson, "\"id\":");
    if(idPos < 0) return;
    
    int idStart = idPos + 5;
    int idEnd = StringFind(tradesJson, ",", idStart);
    if(idEnd < 0) idEnd = StringFind(tradesJson, "}", idStart);
    string idStr = StringSubstr(tradesJson, idStart, idEnd - idStart);
    StringTrimLeft(idStr);
    StringTrimRight(idStr);
    int tradeId = (int)StringToInteger(idStr);
    
    //--- Extraire l'action
    int actionPos = StringFind(tradesJson, "\"action\":");
    if(actionPos < 0) return;
    
    int actionStart = StringFind(tradesJson, "\"", actionPos + 9) + 1;
    int actionEnd = StringFind(tradesJson, "\"", actionStart);
    string action = StringSubstr(tradesJson, actionStart, actionEnd - actionStart);
    
    Print("[TRADE] ID=", tradeId, " Action=", action);
    
    //--- Extraire le symbole (pour BUY/SELL)
    string symbol = _Symbol;
    int symPos = StringFind(tradesJson, "\"symbol\":");
    if(symPos >= 0)
    {
        int symStart = StringFind(tradesJson, "\"", symPos + 9) + 1;
        int symEnd = StringFind(tradesJson, "\"", symStart);
        if(symEnd > symStart)
        {
            string parsedSymbol = StringSubstr(tradesJson, symStart, symEnd - symStart);
            if(parsedSymbol != "" && parsedSymbol != "null" && StringLen(parsedSymbol) > 2)
            {
                // Le symbole peut contenir le ticket pour CLOSE, vérifier si c'est numérique
                bool isNumeric = true;
                for(int i = 0; i < StringLen(parsedSymbol); i++)
                {
                    ushort c = StringGetCharacter(parsedSymbol, i);
                    if(c < '0' || c > '9') { isNumeric = false; break; }
                }
                
                if(!isNumeric && SymbolSelect(parsedSymbol, true))
                {
                    symbol = parsedSymbol;
                }
            }
        }
    }
    
    //--- Extraire le volume
    double volume = DefaultLotSize;
    int volPos = StringFind(tradesJson, "\"volume\":");
    if(volPos >= 0)
    {
        int volStart = volPos + 9;
        int volEnd = StringFind(tradesJson, ",", volStart);
        if(volEnd < 0) volEnd = StringFind(tradesJson, "}", volStart);
        string volStr = StringSubstr(tradesJson, volStart, volEnd - volStart);
        StringTrimLeft(volStr);
        StringTrimRight(volStr);
        double parsedVol = StringToDouble(volStr);
        if(parsedVol > 0) volume = parsedVol;
    }
    
    bool success = false;
    
    //--- Exécuter l'action
    if(action == "BUY")
    {
        double sl = ExtractDouble(tradesJson, "\"sl\":");
        double tp = ExtractDouble(tradesJson, "\"tp\":");
        success = ExecuteBuy(symbol, volume, sl, tp);
    }
    else if(action == "SELL")
    {
        double sl = ExtractDouble(tradesJson, "\"sl\":");
        double tp = ExtractDouble(tradesJson, "\"tp\":");
        success = ExecuteSell(symbol, volume, sl, tp);
    }
    else if(action == "CLOSE")
    {
        Print("[DEBUG] Traitement CLOSE - JSON: ", tradesJson);
        
        //--- Extraire le ticket - chercher dans "ticket": d'abord
        ulong closeTicket = 0;
        int ticketPos = StringFind(tradesJson, "\"ticket\":");
        
        if(ticketPos >= 0)
        {
            int ticketStart = ticketPos + 9;
            int ticketEnd = StringFind(tradesJson, ",", ticketStart);
            if(ticketEnd < 0) ticketEnd = StringFind(tradesJson, "}", ticketStart);
            string ticketStr = StringSubstr(tradesJson, ticketStart, ticketEnd - ticketStart);
            StringTrimLeft(ticketStr);
            StringTrimRight(ticketStr);
            Print("[DEBUG] ticketStr brut = '", ticketStr, "'");
            
            //--- Nettoyer le ticketStr (enlever null, guillemets, etc)
            StringReplace(ticketStr, "null", "0");
            StringReplace(ticketStr, "\"", "");
            StringTrimLeft(ticketStr);
            StringTrimRight(ticketStr);
            
            Print("[DEBUG] ticketStr nettoye = '", ticketStr, "'");
            closeTicket = (ulong)StringToInteger(ticketStr);
            Print("[DEBUG] closeTicket = ", closeTicket);
        }
        
        //--- Si ticket non trouvé dans "ticket", essayer dans "symbol" (backup)
        if(closeTicket == 0 && symPos >= 0)
        {
            int symStart = StringFind(tradesJson, "\"", symPos + 9) + 1;
            int symEnd = StringFind(tradesJson, "\"", symStart);
            if(symEnd > symStart)
            {
                string symTicket = StringSubstr(tradesJson, symStart, symEnd - symStart);
                Print("[DEBUG] Essai ticket depuis symbol = '", symTicket, "'");
                ulong tryTicket = (ulong)StringToInteger(symTicket);
                if(tryTicket > 0) closeTicket = tryTicket;
            }
        }
        
        if(closeTicket > 0)
        {
            Print("[TRADE] Fermeture position #", closeTicket);
            success = ClosePosition(closeTicket);
        }
        else
        {
            Print("[ERROR] Ticket invalide pour CLOSE");
        }
    }
    else if(action == "CLOSE_ALL")
    {
        Print("[TRADE] Fermeture TOUTES les positions");
        success = CloseAllPositions();
    }
    else if(action == "MODIFY")
    {
        ulong modTicket = (ulong)ExtractDouble(tradesJson, "\"ticket\":");
        double newSL = ExtractDouble(tradesJson, "\"sl\":");
        double newTP = ExtractDouble(tradesJson, "\"tp\":");
        
        if(modTicket > 0)
        {
            success = ModifyPosition(modTicket, newSL, newTP);
        }
    }
    
    //--- Confirmer le trade
    ConfirmTrade(tradeId, success ? "executed" : "failed");
}

//+------------------------------------------------------------------+
//| Extraire une valeur double du JSON                                |
//+------------------------------------------------------------------+
double ExtractDouble(string json, string key)
{
    int pos = StringFind(json, key);
    if(pos < 0) return 0;
    
    int start = pos + StringLen(key);
    int end = StringFind(json, ",", start);
    if(end < 0) end = StringFind(json, "}", start);
    
    string valStr = StringSubstr(json, start, end - start);
    StringTrimLeft(valStr);
    StringTrimRight(valStr);
    StringReplace(valStr, "null", "0");
    
    return StringToDouble(valStr);
}

//+------------------------------------------------------------------+
//| Confirmer un trade au serveur Flask                               |
//+------------------------------------------------------------------+
void ConfirmTrade(int tradeId, string status)
{
    string url = FlaskServerURL + "/api/confirm_trade/" + IntegerToString(tradeId);
    string headers = "Content-Type: application/json\r\n";
    string json = "{\"status\":\"" + status + "\"}";
    
    char postData[];
    char result[];
    string resultHeaders;
    
    StringToCharArray(json, postData, 0, StringLen(json));
    ArrayResize(postData, StringLen(json));
    
    WebRequest("POST", url, headers, 3000, postData, result, resultHeaders);
    Print("[CONFIRM] Trade #", tradeId, " - ", status);
}

//+------------------------------------------------------------------+
//| Exécuter un achat                                                  |
//+------------------------------------------------------------------+
bool ExecuteBuy(string symbol, double volume, double slPips, double tpPips)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    double ask = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = volume;
    request.type = ORDER_TYPE_BUY;
    request.price = ask;
    request.deviation = Slippage;
    request.magic = 123456;
    
    if(slPips > 0) request.sl = NormalizeDouble(ask - slPips * point, digits);
    if(tpPips > 0) request.tp = NormalizeDouble(ask + tpPips * point, digits);
    
    long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        request.type_filling = ORDER_FILLING_FOK;
    else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        request.type_filling = ORDER_FILLING_IOC;
    else
        request.type_filling = ORDER_FILLING_RETURN;
    
    ResetLastError();
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("[BUY] ", symbol, " ", volume, " lots @ ", ask, " - Ticket: ", result.order);
            return true;
        }
    }
    
    Print("[ERROR] BUY ", symbol, " - ", ResultRetcodeDescription(result.retcode));
    return false;
}

//+------------------------------------------------------------------+
//| Exécuter une vente                                                 |
//+------------------------------------------------------------------+
bool ExecuteSell(string symbol, double volume, double slPips, double tpPips)
{
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    double bid = SymbolInfoDouble(symbol, SYMBOL_BID);
    double point = SymbolInfoDouble(symbol, SYMBOL_POINT);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = volume;
    request.type = ORDER_TYPE_SELL;
    request.price = bid;
    request.deviation = Slippage;
    request.magic = 123456;
    
    if(slPips > 0) request.sl = NormalizeDouble(bid + slPips * point, digits);
    if(tpPips > 0) request.tp = NormalizeDouble(bid - tpPips * point, digits);
    
    long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        request.type_filling = ORDER_FILLING_FOK;
    else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        request.type_filling = ORDER_FILLING_IOC;
    else
        request.type_filling = ORDER_FILLING_RETURN;
    
    ResetLastError();
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("[SELL] ", symbol, " ", volume, " lots @ ", bid, " - Ticket: ", result.order);
            return true;
        }
    }
    
    Print("[ERROR] SELL ", symbol, " - ", ResultRetcodeDescription(result.retcode));
    return false;
}

//+------------------------------------------------------------------+
//| Fermer une position                                                |
//+------------------------------------------------------------------+
bool ClosePosition(ulong ticket)
{
    if(!PositionSelectByTicket(ticket))
    {
        Print("[ERROR] Position #", ticket, " non trouvee");
        return false;
    }
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    double volume = PositionGetDouble(POSITION_VOLUME);
    ENUM_POSITION_TYPE posType = (ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
    
    request.action = TRADE_ACTION_DEAL;
    request.symbol = symbol;
    request.volume = volume;
    request.type = posType == POSITION_TYPE_BUY ? ORDER_TYPE_SELL : ORDER_TYPE_BUY;
    request.position = ticket;
    request.price = posType == POSITION_TYPE_BUY ? 
                    SymbolInfoDouble(symbol, SYMBOL_BID) : 
                    SymbolInfoDouble(symbol, SYMBOL_ASK);
    request.deviation = Slippage;
    request.magic = 123456;
    
    long filling = SymbolInfoInteger(symbol, SYMBOL_FILLING_MODE);
    if((filling & SYMBOL_FILLING_FOK) == SYMBOL_FILLING_FOK)
        request.type_filling = ORDER_FILLING_FOK;
    else if((filling & SYMBOL_FILLING_IOC) == SYMBOL_FILLING_IOC)
        request.type_filling = ORDER_FILLING_IOC;
    else
        request.type_filling = ORDER_FILLING_RETURN;
    
    ResetLastError();
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("[CLOSE] Position #", ticket, " fermee");
            return true;
        }
    }
    
    Print("[ERROR] Fermeture #", ticket, " - ", ResultRetcodeDescription(result.retcode));
    return false;
}

//+------------------------------------------------------------------+
//| Fermer toutes les positions                                        |
//+------------------------------------------------------------------+
bool CloseAllPositions()
{
    int closed = 0;
    int total = PositionsTotal();
    
    for(int i = total - 1; i >= 0; i--)
    {
        ulong ticket = PositionGetTicket(i);
        if(ticket > 0 && ClosePosition(ticket))
        {
            closed++;
        }
    }
    
    Print("[CLOSE_ALL] ", closed, "/", total, " positions fermees");
    return closed > 0;
}

//+------------------------------------------------------------------+
//| Modifier une position                                              |
//+------------------------------------------------------------------+
bool ModifyPosition(ulong ticket, double newSL, double newTP)
{
    if(!PositionSelectByTicket(ticket))
    {
        Print("[ERROR] Position #", ticket, " non trouvee");
        return false;
    }
    
    MqlTradeRequest request = {};
    MqlTradeResult result = {};
    
    string symbol = PositionGetString(POSITION_SYMBOL);
    int digits = (int)SymbolInfoInteger(symbol, SYMBOL_DIGITS);
    
    request.action = TRADE_ACTION_SLTP;
    request.symbol = symbol;
    request.position = ticket;
    request.sl = newSL > 0 ? NormalizeDouble(newSL, digits) : PositionGetDouble(POSITION_SL);
    request.tp = newTP > 0 ? NormalizeDouble(newTP, digits) : PositionGetDouble(POSITION_TP);
    
    ResetLastError();
    if(OrderSend(request, result))
    {
        if(result.retcode == TRADE_RETCODE_DONE)
        {
            Print("[MODIFY] Position #", ticket, " modifiee - SL:", request.sl, " TP:", request.tp);
            return true;
        }
    }
    
    Print("[ERROR] Modification #", ticket, " - ", ResultRetcodeDescription(result.retcode));
    return false;
}

//+------------------------------------------------------------------+
//| Description du code retour                                         |
//+------------------------------------------------------------------+
string ResultRetcodeDescription(uint retcode)
{
    switch(retcode)
    {
        case TRADE_RETCODE_REQUOTE:           return "Requote";
        case TRADE_RETCODE_REJECT:            return "Rejete";
        case TRADE_RETCODE_CANCEL:            return "Annule";
        case TRADE_RETCODE_PLACED:            return "Place";
        case TRADE_RETCODE_DONE:              return "OK";
        case TRADE_RETCODE_DONE_PARTIAL:      return "Partiel";
        case TRADE_RETCODE_ERROR:             return "Erreur";
        case TRADE_RETCODE_TIMEOUT:           return "Timeout";
        case TRADE_RETCODE_INVALID:           return "Invalide";
        case TRADE_RETCODE_INVALID_VOLUME:    return "Volume invalide";
        case TRADE_RETCODE_INVALID_PRICE:     return "Prix invalide";
        case TRADE_RETCODE_INVALID_STOPS:     return "Stops invalides";
        case TRADE_RETCODE_TRADE_DISABLED:    return "Trading desactive";
        case TRADE_RETCODE_MARKET_CLOSED:     return "Marche ferme";
        case TRADE_RETCODE_NO_MONEY:          return "Fonds insuffisants";
        case TRADE_RETCODE_PRICE_CHANGED:     return "Prix change";
        case TRADE_RETCODE_PRICE_OFF:         return "Prix non disponible";
        case TRADE_RETCODE_INVALID_EXPIRATION: return "Expiration invalide";
        case TRADE_RETCODE_ORDER_CHANGED:     return "Ordre modifie";
        case TRADE_RETCODE_TOO_MANY_REQUESTS: return "Trop de requetes";
        default:                              return "Code " + IntegerToString(retcode);
    }
}
//+------------------------------------------------------------------+
