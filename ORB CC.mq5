//+------------------------------------------------------------------+
//|                                                       ORB CC.mq5 |
//|                                                         Hoang Le |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
#property copyright "Hoang Le"
#property version   "1.00"
#property strict

#include <Trade\Trade.mqh>



// Enum for Stop Loss Modes
enum ENUM_SL_MODE {
   SL_FIXED_TIME,    // Fixed SL at 9:30
   SL_ATR_PERCENT   // ATR Percentage SL
};

// Enum for Take Profit Modes
enum ENUM_TP_MODE {
   TP_END_OF_DAY,    // End of Day TP
   TP_RISK_REWARD    // Risk-Reward TP
};

// Input Parameters
input ENUM_SL_MODE   InpSLMode = SL_FIXED_TIME;     // Stop Loss Mode
input ENUM_TP_MODE   InpTPMode = TP_END_OF_DAY;     // Take Profit Mode

// Additional Inputs based on selected modes
input double         InpRiskPercent = 1.0;          // Risk Percentage per Trade
input double         InpAtrPercent = 5.0;           // ATR Percentage for SL (when SL_ATR_PERCENT selected)
input int            InpAtrPeriod = 14;             // ATR Period
input double         InpRiskReward = 2.0;           // Risk-Reward Ratio (when TP_RISK_REWARD selected)
input double         InpDefaultTP = 50.0;           // Default Take Profit (R multiple) for EOD

// Global variables
CTrade trade;
bool tradeOpen = false;
ulong tradeTicket = 0;

double CalculatePositionSize(double entry, double stopLoss) {
   // Calculate risk amount based on account equity
   double accountEquity = AccountInfoDouble(ACCOUNT_EQUITY);
   double riskAmount = accountEquity * (InpRiskPercent / 100.0);
   
   // Calculate stop loss distance
   double slDistance = MathAbs(entry - stopLoss);
   
   // Calculate position size
   // Lots = (Risk Amount) / (Stop Loss Distance * Tick Value)
   double tickSize = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE);
   double tickValue = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_VALUE);
   
   // Prevent division by zero
   if(slDistance == 0 || tickSize == 0 || tickValue == 0) return 0;
   
   double positionSize = riskAmount / (slDistance * tickValue / tickSize);
   
   // Normalize position size to broker's min/max lot constraints
   double minLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double maxLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double stepLot = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_STEP);
   
   positionSize = MathMax(minLot, positionSize);
   positionSize = MathMin(maxLot, positionSize);
   
   // Round to nearest step size
   positionSize = MathRound(positionSize / stepLot) * stepLot;
   
   return NormalizeDouble(positionSize, 2);
}

double CalculateStopLoss(double entry) {
   switch(InpSLMode) {
      case SL_FIXED_TIME:
         return CalculateFixedTimeSL(entry);
      
      case SL_ATR_PERCENT:
         return CalculateAtrPercentSL(entry);
      
      default:
         return 0;
   }
}

double CalculateFixedTimeSL(double entry) {
   // Stop Loss at 9:30
   datetime currentTime = TimeCurrent();
   datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE) + " 09:30");
   
   // If current time is past 9:30, return 0 (no SL)
   if(currentTime >= todayStart) return 0;
   
   // Assuming long position - adjust for short
   return entry;
}

double CalculateAtrPercentSL(double entry) {
   double atr[];
   ArraySetAsSeries(atr, true);
   
   int atrHandle = iATR(_Symbol, PERIOD_CURRENT, InpAtrPeriod);
   if(atrHandle == INVALID_HANDLE) {
      Print("Failed to create ATR indicator");
      return entry;
   }
   
   int atrCopied = CopyBuffer(atrHandle, 0, 0, 1, atr);
   IndicatorRelease(atrHandle);
   
   if(atrCopied <= 0) return entry;
   
   double slDistance = atr[0] * (InpAtrPercent / 100.0);
   
   // Assuming long position - adjust for short
   return entry - slDistance;
}

double CalculateTakeProfit(double entry, double stopLoss) {
   switch(InpTPMode) {
      case TP_END_OF_DAY:
         return CalculateEODTP(entry, stopLoss);
      
      case TP_RISK_REWARD:
         return CalculateRiskRewardTP(entry, stopLoss);
      
      default:
         return 0;
   }
}

double CalculateEODTP(double entry, double stopLoss) {
   // Calculate take profit based on 50R
   if(stopLoss == 0) return 0;
   
   double riskAmount = MathAbs(entry - stopLoss);
   return entry + (riskAmount * InpDefaultTP);
}

double CalculateRiskRewardTP(double entry, double stopLoss) {
   if(stopLoss == 0) return 0;
   
   double tpDistance = MathAbs(entry - stopLoss) * InpRiskReward;
   
   // Assuming long position - adjust for short
   return entry + tpDistance;
}

void CheckAndCloseEODTrade() {
   // Check if trade is open and EOD TP mode is selected
   if(tradeOpen && InpTPMode == TP_END_OF_DAY) {
      datetime currentTime = TimeCurrent();
      datetime endOfDay = StringToTime(TimeToString(currentTime, TIME_DATE) + " 23:59:59");
      
      // Close trade at end of day
      if(currentTime >= endOfDay) {
         if(trade.PositionClose(tradeTicket)) {
            tradeOpen = false;
            tradeTicket = 0;
            Print("Trade closed at end of day");
         }
      }
   }
}

int OnInit() {
   // Configure trade settings
   trade.SetExpertMagicNumber(12345);  // Set a unique magic number
   trade.SetDeviationInPoints(10);     // Set acceptable price deviation
   
   return(INIT_SUCCEEDED);
}

void OnDeinit(const int reason) {
   // Cleanup if needed
}

void OnTick() {
   // Check and close EOD trade if applicable
   CheckAndCloseEODTrade();
   
   // Only open a trade if no trade is currently open
   if(!tradeOpen) {
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
      double stopLoss = CalculateStopLoss(entry);
      double takeProfit = CalculateTakeProfit(entry, stopLoss);
      
      // Add your trade execution logic
      // This is a placeholder - replace with your specific trade entry conditions
      if(SomeEntryCondition()) {
         // Calculate position size based on risk
         double positionSize = CalculatePositionSize(entry, stopLoss);
         
         // Using CTrade to send order
         if(trade.Buy(positionSize, _Symbol, entry, stopLoss, takeProfit, "HCVT Trade")) {
            tradeOpen = true;
            tradeTicket = trade.ResultOrder();
            Print("Trade opened successfully. Ticket: ", tradeTicket, " Position Size: ", positionSize);
         } else {
            Print("Trade opening failed. Error: ", trade.ResultRetcode());
         }
      }
   }
}

// Placeholder function - replace with your actual entry condition
bool SomeEntryCondition() {
   // Add your specific entry logic here
   return true;  // Always return true for this example
}