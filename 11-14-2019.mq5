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

//+---------------------
CisNewBar current_chart;
enum signal {buy, sell, none, closeBuy, closeSell};
//--- EA inputs
input string   EAinputs = "EA inputs";                                         // EA inputs
input double   order_volume = 0.1;                                            // Lot size
input double   MaximumRisk_ = 0.01;                                             // Maximum Risk
//--- Trading timespan
input string   Tradingtimespan = "Trading timespan";                           // Trading timespan
input char     time_h_start = 0;                                               // Trading start time
input char     time_h_stop = 24;                                               // Trading stop time
input bool     mon = true;                                                     // Work on Monday
input bool     tue = true;                                                    // Work on Tuesday
input bool     wen = true;                                                     // Work on Wednesday
input bool     thu = true;                                                     // Work on Thursday
input bool     fri = true;                                                     // Work on Friday
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
int stotal = 1;
signal lastSignal;
signal UpT;
double SYMBOLVOLUMEMIN = 0;
double SYMBOLVOLUMEMAX = 0;
double SYMBOLVOLUMESTEP = 0;
bool started = false;
CArrayLong       TSList;
CAccountInfo myaccount;
//+---------------------------------------------+
int OnInit() {
   SYMBOLVOLUMEMIN = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   SYMBOLVOLUMEMAX = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   SYMBOLVOLUMESTEP = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   symbolName = "EURUSD";
   lastSignal = none;
   UpT = none;
   iCustom(symbolName, PERIOD_M30, "ehlers fisher original", EhlersFisher, PRICE_CLOSE);
   MaximumRisk = MaximumRisk_;
   cvolume = lotsOptimized(order_volume);
   trade.SetExpertMagicNumber(939393);
   InitBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}
double lotsOptimized(double locallot = 0.0) {
   double lot;
   if(locallot == 0.0)
      lot = NormalizeDouble(locallot * MaximumRisk * _Point, 2);
   else
      lot = NormalizeDouble(myaccount.FreeMargin() * MaximumRisk * _Point, 2);
   double volume_step = SYMBOLVOLUMESTEP;
   int ratio = (int)MathRound(lot / volume_step);
   if(MathAbs(ratio * volume_step - lot) > 0.0000001)
      lot = ratio * volume_step;
   lot = MathMax(SYMBOLVOLUMEMIN, MathMin(SYMBOLVOLUMEMAX, lot));
   /*if(lot<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(lot>SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);*/
   return(lot);
}
signal Brain(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14) {
   return ehlers(symbol, period, shrtMA);
}
signal ehlers(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 25, double min = 0.5, double max = 0.5) {
   int Fisher;
   Fisher = iCustom(symbol, period, "ehlers_fisher_transform", shrtMA);
   double FValue[];
   double TValue[];
   ArraySetAsSeries(FValue, true);
   CopyBuffer(Fisher, 0, 0, 1, FValue);
   ArraySetAsSeries(TValue, true);
   CopyBuffer(Fisher, 1, 0, 1, TValue);
   if ((TValue[0] == 2.0 && FValue[0] > max) && UpT == sell) return sell;
   else if ((TValue[0] == 1.0 && FValue[0] < min) && UpT == buy) return buy;
   return none;
}
signal Horizon(string symbol, ENUM_TIMEFRAMES period, double step = 0.05, double maximum = 0.4) {
   int parab = iSAR(symbol, period, step, maximum);
   double SARIndex[];
   double HighIndex = iHigh(symbol, period, 1), LowIndex = iLow(symbol, period, 1);
   ArraySetAsSeries(SARIndex, true);
   CopyBuffer(parab, 0, 1, 3, SARIndex);
   ArraySetAsSeries(SARIndex, true);
   if (HighIndex <= SARIndex[0]) return sell;
   else if (LowIndex >= SARIndex[0]) return buy;
   return none;
}
void SetUpT(string symbol) {
   UpT = Horizon(symbol, PeriodOverview);
   Comment(EnumToString(UpT));
}
void RiskMan() {
   double Balance = myaccount.Balance();
   if(Balance > InitBalance) {
      MaximumRisk = (((MaximumRisk_ * Balance) / InitBalance) - (MaximumRisk_ / 10)) + MaximumRisk_;
   } else {
      MaximumRisk = MaximumRisk_;
   }
}
//+------------------------------------------------------------------+
void OnTick() {
   if (!started) {
      Comment("Aiden is sleeping");
      TimeCurrent(time_now_str);
      if (time_now_str.hour == 0 && time_now_str.min == 0 && time_now_str.sec == 0) {
         started = true;
      } else {
         return;
      }
   }
   static int CD = 0;
   bool NCC = false;
   bool NCD = false;
   bool NCH = false;
   bool work = false;
   datetime  timeCurrent = TimeCurrent(time_now_str);
   int period_seconds = PeriodSeconds(PeriodCalculation);
   datetime new_time = timeCurrent / period_seconds * period_seconds;
   if(current_chart.isNewBar(new_time)) {
      CD++;
      NCC = true;
   }
   if(CD == 48) {
      CD = 0;
      NCD = true;
      NCH = true;
   }
   signal CurrentSignal = none;
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
         CurrentSignal = Brain(symbol, PeriodCalculation, EhlersFisher);
      }
      if(CurrentSignal != none) {
         cvolume = lotsOptimized(cvolume);
      }
      Comment("Current Signal is: ", EnumToString(CurrentSignal), "\n", "Horizon is: ", EnumToString(UpT));
      if(CurrentSignal == buy) {
         if(lastSignal == sell) {
            CloseAllPositions(true);
         }
         double price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
         if(trade.Buy(cvolume, symbol, price_ask, 0, price_ask + (500 * _Point), symbol)) {
            lastSignal = buy;
         }
      } else if(CurrentSignal == sell) {
         if(lastSignal == buy) {
            CloseAllPositions(true);
         }
         double price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
         if(trade.Sell(cvolume, symbol, price_bid, 0, price_bid - (500 * _Point), symbol)) {
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
//+------------------------------------------------------------------+
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
