//+------------------------------------------------------------------+
//|                                                                  |
//|       Aiden                                                      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.50"
#include<Trade\Trade.mqh>
#include <LibCisNewBar.mqh>
#include <Trade\AccountInfo.mqh>
#include <Arrays\ArrayLong.mqh> 

CisNewBar current_chart;
CisNewBar d1_chart;
CisNewBar h1_chart;
enum signal {buy, sell, none, closeBuy, closeSell};
//--- EA inputs
input string   EAinputs = "EA inputs";                                         // EA inputs
input double   PipRisk = 200;                                            // Lot size
input double   MaximumRisk_ = 0.01;                                             // Maximum Risk
//--- Trading timespan
input string   Tradingtimespan = "Trading timespan";                           // Trading timespan
input char     time_h_start = 0;                                               // Trading start time
input char     time_h_stop = 24;                                               // Trading stop time
input bool     mon = true;                                                     // Work on Monday
input bool     tue = true;                                                    // Work on Tuesday
input bool     wen = true;                                                     // Work on Wednesday
input bool     thu = true;                                                     // Work on Thursday
input bool     fri = true;                                                     // Work on Friday                                                     // Work on Friday
input int      EhlersFisher = 9;
ENUM_TIMEFRAMES PeriodOverview = PERIOD_D1;
ENUM_TIMEFRAMES PeriodCalculation = PERIOD_M30;
ENUM_TIMEFRAMES PeriodTrailingStop = PERIOD_D1;

double cvolume = 0.0;
double MaximumRisk = 0.0;
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
bool work_day = true;
double InitBalance;
string symbolName;
signal lastSignal;
signal UpT;

bool started = false;
CArrayLong       TSList;
CAccountInfo myaccount;  

int OnInit() {
   symbolName = "EURUSD";
   lastSignal = none;
   UpT = none;
   MaximumRisk = MaximumRisk_;
   cvolume = lotsOptimized();
   trade.SetExpertMagicNumber(939393);
   InitBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
} 
double lotsOptimized() {
   double lot;
   long leverage = myaccount.Leverage();
   double margin = myaccount.FreeMargin();
   lot = ((MaximumRisk * margin) / PipRisk);
   if(margin - (lot*_Point) < 0.0)
      lot = NormalizeDouble(0.01, 2);
   else
      lot = NormalizeDouble(lot*_Point, 2);
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   int ratio = (int)MathRound(lot / volume_step);
   if(MathAbs(ratio * volume_step - lot) > 0.0000001)
      lot = ratio * volume_step;
   lot = MathMax(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX), lot));
   return(lot);
} 
void CloseAllPositions(bool Part = false) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      double POFF = PositionGetDouble(POSITION_PROFIT);
      if(ticket > 0) {
         bool ACC = true;
         if (Part) {
            if (POFF < 0) {
               ACC = false;
               TSList.Add(ticket);
               TrailingStop(i);
            }
         }
         if (ACC) {
            double TPC = PositionGetDouble(POSITION_TP);
            double SLC = PositionGetDouble(POSITION_PRICE_CURRENT);
            if(!trade.PositionModify(ticket, SLC, TPC)) {
               Print("error");
            }
         }
      }
   }
}
signal Brain(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14) {
   return Horizon(symbol, period, shrtMA);
}
signal Brand(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 22) {
   int PCI;
   int ICC;
   ICC = iCCI(symbol, period, shrtMA, shrtMA);
   PCI = iCustom(symbol, period, "PCI", shrtMA);
   double HValue[];
   double MValue[];
   double LValue[];
   double ihigh = iHigh(symbol, period, 1), ilow = iLow(symbol, period, 1), iclose = iClose(symbol, period, 1);
   ArraySetAsSeries(HValue, true);
   CopyBuffer(PCI, 0, 1, 2, HValue);
   ArraySetAsSeries(MValue, true);
   CopyBuffer(PCI, 1, 1, 2, MValue);
   ArraySetAsSeries(LValue, true);
   CopyBuffer(PCI, 2, 1, 2, LValue);
   if (LValue[0] > ilow && MValue[0] > iclose) return buy;
   else if (HValue[0] < ihigh && MValue[0] < iclose) return sell;
   return none;
}
signal Horizon(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 22) {
   int PCI;
   PCI = iCustom(symbol, period, "PCI", shrtMA);
   double HValue[];
   double MValue[];
   double LValue[];
   double ihigh = iHigh(symbol, period, 1), ilow = iLow(symbol, period, 1), iclose = iClose(symbol, period, 1);
   ArraySetAsSeries(HValue, true);
   CopyBuffer(PCI, 0, 1, 2, HValue);
   ArraySetAsSeries(MValue, true);
   CopyBuffer(PCI, 1, 1, 2, MValue);
   ArraySetAsSeries(LValue, true);
   CopyBuffer(PCI, 2, 1, 2, LValue);
   if (LValue[0] > ilow && MValue[0] > iclose) return buy;
   else if (HValue[0] < ihigh && MValue[0] < iclose) return sell;
   return none;
}
void SetUpT(string symbol, int shrtMA = 22) {
   UpT = Horizon(symbol, PERIOD_D1, shrtMA);
}
void RiskMan() {
   double Balance = myaccount.Balance();
   if(Balance > InitBalance) {
      MaximumRisk = (((MaximumRisk_ * Balance) / InitBalance) - (MaximumRisk_ / 10)) + MaximumRisk_;
   } else {
      MaximumRisk = MaximumRisk_;
   }
} 
void OnTick() {
   bool NCC = false;
   bool NCD = false;
   bool NCH = false;
   bool work = false;
   int period_seconds = PeriodSeconds(_Period);
   datetime new_time = TimeCurrent() / period_seconds * period_seconds;
   int d1_seconds = PeriodSeconds(PERIOD_D1);
   datetime d1_new_time = TimeCurrent() / d1_seconds * d1_seconds;
   int h1_seconds = PeriodSeconds(PERIOD_H12);
   datetime h1_new_time = TimeCurrent() / h1_seconds * h1_seconds;
   if(current_chart.isNewBar(new_time))
      NCC = true;
   if(d1_chart.isNewBar(d1_new_time))
      NCD = true;
   if(h1_chart.isNewBar(h1_new_time))
      NCH = true;
   double price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   signal CurrentSignal = none;
   time_now_var = TimeCurrent(time_now_str);
   switch(time_now_str.day_of_week) {
   case 1:
      if(mon == false) {
         work_day = false;
      } else {
         work_day = true;
      }
      break;
   case 2:
      if(tue == false) {
         work_day = false;
      } else {
         work_day = true;
      }
      break;
   case 3:
      if(wen == false) {
         work_day = false;
      } else {
         work_day = true;
      }
      break;
   case 4:
      if(thu == false) {
         work_day = false;
      } else {
         work_day = true;
      }
      break;
   case 5:
      if(fri == false) {
         work_day = false;
      } else {
         work_day = true;
      }
      break;
   }
   if(time_h_start > time_h_stop) {
      if(time_now_str.hour >= time_h_start || time_now_str.hour <= time_h_stop) {
         work = true;
      }
   } else {
      if(time_now_str.hour >= time_h_start && time_now_str.hour <= time_h_stop) {
         work = true;
      }
   }
   if(work == true && work_day == true) {
      string symbol = _Symbol;
      symbol = symbolName;
      if (NCD) {
         SetUpT(symbol);
      }
      if (NCC) {
         CurrentSignal = Brain(symbol, _Period);
      }
      if(CurrentSignal != none) {
         cvolume = lotsOptimized();
      }
      Comment("Current Signal is: ", EnumToString(CurrentSignal), "\n", "Horizon is: ", EnumToString(UpT));
      if(CurrentSignal == buy) {
         if(lastSignal == sell)
            CloseAllPositions();
         if(trade.Buy(cvolume, symbol, price_ask, 0, 0, symbol)) {
            lastSignal = buy;
         }
      } else if(CurrentSignal == sell) {
         if(lastSignal == buy)
            CloseAllPositions();
         if(trade.Sell(cvolume, symbol, price_bid, 0, 0, symbol)) {
            lastSignal = sell;
         }
      }
   } else {
      Comment("Aiden is sleeping");
   }
   if (NCH) {
      TrailingStopAll();
      RiskMan();
      CleanUpList();
   }
} 
void TrailingStopAll() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      TrailingStop(i);
   }
}
bool inList(long find, CArrayLong& inA) {
   for(int i = 0; i < inA.Total(); i++) {
      if (find == inA.At(i)) {
         return true;
      }
   }
   return false;
}
void CleanUpList() {
   for(int i = 0; i < TSList.Total(); i++) {
      for(int j = PositionsTotal() - 1; j >= 0; j--) {
         ulong ticket = PositionGetTicket(i);
         if (ticket == TSList.At(i)) {
            TSList.Delete(i);
         }
      }
   }
}
void TrailingStop(int i) {
   string symbol = PositionGetSymbol(i);
   if(symbol == symbolName) {
      ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
      if (!inList(PositionTicket, TSList)) {
         return;
      }
      double SLC = PositionGetDouble(POSITION_SL);
      double TPC = PositionGetDouble(POSITION_TP);
      double R3, S3, R1, S1, R2, S2, PP;
      double ihigh = iHigh(symbol, PeriodTrailingStop, 0), ilow = iLow(symbol, PeriodTrailingStop, 0), iclose = iClose(symbol, PeriodTrailingStop, 0);
      PP = (ihigh + ilow + iclose) / 3;
      R3 = ihigh + 2 * (PP - ilow);
      S3 = ilow  - 2 * (ihigh - PP);
      R2 = PP + (ihigh - ilow);
      S2 = PP - (ihigh - ilow);
      R1 = (2 * PP) - ilow;
      S1 = (2 * PP) - ihigh;
      if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
         double NSLB = NormalizeDouble(S1, _Digits);
         double NSLS = NormalizeDouble(S3, _Digits);
         if(UpT == buy) {
            if (NSLB > SLC) {
               if(!trade.PositionModify(PositionTicket, NSLB, TPC)) {
                  Print("error");
               }
            }
         } else {
            if (NSLS > SLC) {
               if(!trade.PositionModify(PositionTicket, NSLS, TPC)) {
                  Print("error");
               }
            }
         }
      } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         double NSLB = NormalizeDouble(R3, _Digits);
         double NSLS = NormalizeDouble(R1, _Digits);
         if(UpT == sell) {
            if(!trade.PositionModify(PositionTicket, NSLB, 0) && NSLB < SLC) {
               Print("error");
            }
         } else {
            if(!trade.PositionModify(PositionTicket, NSLS, 0) && NSLS < SLC) {
               Print("error");
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
