//+------------------------------------------------------------------+
//|                                                       ORB QQ.mq5 |
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
#include "time.mqh";


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
input int            InpXMinuteAfterOpen = 5;             // Minutes after Opening
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

double CalculateStopLoss(double entry, string bias) {
   Print("CalculateStopLoss");
   switch(InpSLMode) {
      case SL_FIXED_TIME:
         return CalculateFixedTimeSL(entry);
      
      case SL_ATR_PERCENT:
         Print("CalculateStopLoss SL_ATR_PERCENT");
         return CalculateAtrPercentSL(entry, bias);
      
      default:
         return 0;
   }
}

double CalculateFixedTimeSL(double entry) {
   // Stop Loss at 9:30
   //datetime currentTime = TimeCurrent();
   //datetime todayStart = StringToTime(TimeToString(currentTime, TIME_DATE) + " 09:30");
   
   // If current time is past 9:30, return 0 (no SL)
   //if(currentTime >= todayStart) return 0;
   
   // Assuming long position - adjust for short
   return entry;
}

double CalculateAtrPercentSL(double entry, string bias) {
   double atr[];
   ArraySetAsSeries(atr, true);
   
   int atrHandle = iATR(_Symbol, PERIOD_D1, InpAtrPeriod);
   Print("CalculateAtrPercentSL, atrHandle: ", atrHandle);
   if(atrHandle == INVALID_HANDLE) {
      Print("Failed to create ATR indicator");
      return entry;
   }
   
   int atrCopied = CopyBuffer(atrHandle, 0, 0, 1, atr);
   IndicatorRelease(atrHandle);
   
   Print("atrCopied: ", atrCopied, " with value atr[0]: ", atr[0]);
   
   if(atrCopied <= 0) return entry;
   
   double slDistance = atr[0] * (InpAtrPercent / 100.0);
   
   // Assuming long position - adjust for short
   double sl = 0;
   if (bias == "BUY"){
     sl = entry - slDistance;
   }else {
     sl = entry + slDistance;
   }
   Print("SL", sl);  
   return sl;
}

double CalculateTakeProfit(double entry, double stopLoss, string bias) {
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
      
      // Close trade at end of day
      if(is_about_1559_est()) {
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

bool IsNewBar() {
   static datetime lastBar = 0;
   datetime currentBar = iTime(_Symbol, PERIOD_CURRENT, 0);
   if(lastBar != currentBar) {
      lastBar = currentBar;
      return true;
   }
   return false;
}

void OnTick() {
   if(!IsNewBar()) return;
   // Check and close EOD trade if applicable
   CheckAndCloseEODTrade();
   
   // Only open a trade if no trade is currently open
   // !tradeOpen && 
   if(is_about_x_minute_after930_est(InpXMinuteAfterOpen)) {
      
     // compare close of the last candle in the opening range (OHLC[or_candles-1, 3]) to the open of the first candle
      Print("not entry, finding entry condition");
      bool prices_are_different = false;
      string bias = "";
      is_price_different(prices_are_different, bias);
      //as retail, can only buy will high price -> ask price
      double entry = SymbolInfoDouble(_Symbol, SYMBOL_ASK);      
      // and sell with low price -> bid
      if (bias == "SELL") {
         entry = SymbolInfoDouble(_Symbol, SYMBOL_BID);
      }
      double stopLoss = CalculateStopLoss(entry, bias);
      double takeProfit = CalculateTakeProfit(entry, stopLoss, bias);
      
      // Add your trade execution logic
      // This is a placeholder - replace with your specific trade entry conditions
      Print("bias: ", bias);
      Print("entry: ", entry);
      Print("stopLoss: ", stopLoss);
      Print("takeProfit: ", takeProfit);
      if(bias == "BUY") {
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
      // sell
      if(bias == "SELL") {
         // Calculate position size based on risk
         double positionSize = CalculatePositionSize(entry, stopLoss);
         
         // Using CTrade to send order
         if(trade.Sell(positionSize, _Symbol, entry, stopLoss, takeProfit, "HCVT Trade")) {
            tradeOpen = true;
            tradeTicket = trade.ResultOrder();
            Print("Trade opened successfully. Ticket: ", tradeTicket, " Position Size: ", positionSize);
         } else {
            Print("Trade opening failed. Error: ", trade.ResultRetcode());
         }
      }
      
   }
}

// only entry if 
void is_price_different(bool &prices_are_different, string &bias) {
   // Add your specific entry logic here
   double open_price = get_est_930am_open_price(_Symbol, InpXMinuteAfterOpen);
   // Print("open_price: ", open_price);
   // note: caching price: https://www.notion.so/hoanglg/MQL5-caching-OHLC-price-1d7391b340a8802db71ef3c8092ebbec
   double closing_price = get_close_price_at_x_minutes_after_930(_Symbol, InpXMinuteAfterOpen);   
   // Print("closing_price: ", closing_price, " after ", InpXMinuteAfterOpen, " minutes from 9:30" );
   
   
    // Define minimum difference to consider prices different
   double min_diff = SymbolInfoDouble(_Symbol, SYMBOL_TRADE_TICK_SIZE); // Use tick size
   
   // Check if prices are different by comparing their absolute difference
   prices_are_different = (MathAbs(open_price - closing_price) > min_diff);
   
   // Log the result
   if(prices_are_different) {
      Print("Prices are different: Open=", open_price, ", Close=", closing_price, 
            ", Diff=", MathAbs(open_price - closing_price));
   } else {
      Print("Prices are the same or within minimum difference threshold");
   }
   if (closing_price - open_price > 0) {
      bias = "BUY";
   }else{
      bias = "SELL";
   }
   Print("prices_are_different: ", prices_are_different);   
}