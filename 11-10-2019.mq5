//+------------------------------------------------------------------+
//|                                                                  |
//|       implament Fibbonachi retrasement as mid point trade        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.50"
#property tester_file "optimize.csv"
#include<Trade\Trade.mqh>
#include <LibCisNewBar.mqh>
#include <Trade\AccountInfo.mqh>
#include <Generic\ArrayList.mqh>

//+---------------------
CisNewBar current_chart;
CisNewBar d1_chart;
CisNewBar h1_chart;
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
input string InpFileName = "optimize.csv"; // optimize file name

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

//+---------------------------------------------+
int OnInit() {
   symbolName = "EURUSD";
   lastSignal = none;
   UpT = none;
   MaximumRisk = MaximumRisk_;
   cvolume = lotsOptimized(MaximumRisk, order_volume);
   trade.SetExpertMagicNumber(939393);
   InitBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
}
//+------------------------------------------------------------------+
double lotsOptimized(double LocalMaximumRisk, double locallot = 0.0) {
   double lot;
   LocalMaximumRisk = RandD(MaximumRisk_, LocalMaximumRisk);
   if(MQLInfoInteger(MQL_OPTIMIZATION) == true) {
      lot = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
      return lot;
   }
   CAccountInfo myaccount;
   SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   if(locallot == 0.0)
      lot = NormalizeDouble(locallot * LocalMaximumRisk * _Point, 2);
   else
      lot = NormalizeDouble(myaccount.FreeMargin() * LocalMaximumRisk * _Point, 2);
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   int ratio = (int)MathRound(lot / volume_step);
   if(MathAbs(ratio * volume_step - lot) > 0.0000001)
      lot = ratio * volume_step;
   lot = MathMax(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX), lot));
   /*if(lot<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(lot>SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);*/
   return(lot);
}
//+------------------------------------------------------------------+
void CloseAllPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         trade.PositionClose(ticket);
      }
   }
}
//+------------------------------------------------------------------+
signal Brain_lame(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14, int LognMA = 30, int cpn = 10, bool UpTf = false) {
   int Shrt = iMA(symbol, period, shrtMA, 0, MODE_SMA, PRICE_CLOSE);
   int Logn = iMA(symbol, period, LognMA, 0, MODE_SMA, PRICE_CLOSE);
   double SValue[];
   double LValue[];
   double fopen = iOpen(symbol, period, 1), fclose = iClose(symbol, period, 1);
   if(fopen == fclose) return none;
   ArraySetAsSeries(SValue, true);
   CopyBuffer(Shrt, 0, 0, cpn, SValue);
   ArraySetAsSeries(LValue, true);
   CopyBuffer(Logn, 0, 0, cpn, LValue);
   cpn = ArraySize(LValue) - 2;
   for(int i = 0; i < cpn; i++) {
      if (SValue[i + 1] != LValue[i + 1]) continue;
      double ihigh = iHigh(symbol, period, i), ilow = iLow(symbol, period, i);
      if(fopen > fclose) {
         if(SValue[i] < LValue[i] && SValue[i + 2] > LValue[i + 2]) {
            if (UpT == sell || UpTf) return sell;
         }
      } else if(fopen < fclose) {
         if(SValue[i] > LValue[i] && SValue[i + 2] < LValue[i + 2]) {
            if (UpT == buy || UpTf) return buy;
         }
      }
   }
   return none;
}
signal Brain(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14) {
   return ehlers(symbol, period, shrtMA);
}
signal ehlers(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 25, double min = 0.0, double max = 0.0) {
   int Fisher;
   Fisher = iCustom(symbol, period, "ehlers_fisher_transform", shrtMA);
   double FValue[];
   double TValue[];
   ArraySetAsSeries(TValue, true);
   CopyBuffer(Fisher, 1, 0, 1, TValue);
   ArraySetAsSeries(FValue, true);
   CopyBuffer(Fisher, 0, 0, 1, FValue);
   if (TValue[0] == 2.0 && FValue[0] > max) return sell;
   else if (TValue[0] == 1.0 && FValue[0] < min) return buy;
   return none;
}
void SetUpT(string symbol, int shrtMA = 25) {
   UpT = ehlers(symbol, PERIOD_D1, shrtMA, -2.0, 2.0);
   Comment(EnumToString(UpT));
}
//+------------------------------------------------------------------+
void RiskMan() {
   double Balance = AccountInfoDouble(ACCOUNT_BALANCE);
   if(Balance > InitBalance) {
      MaximumRisk = (((MaximumRisk_ * Balance) / InitBalance) - (MaximumRisk_ / 10)) + MaximumRisk_;
   } else {
      MaximumRisk = MaximumRisk_;
   }
}

//+------------------------------------------------------------------+
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
      if (NCD)
         SetUpT(symbol);
      if (NCC)
         CurrentSignal = Brain(symbol, _Period);
      if(CurrentSignal != none)
         cvolume = lotsOptimized(MaximumRisk, cvolume);
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
   }
   if (NCH) {
      TrailingStop(price_ask, price_bid);
      RiskMan();
   }
}
//+------------------------------------------------------------------+
double RandD(const double min, const double max) {
   double f = (MathRand() / 32768.0);
   return min + (double)(f * (max - min));
}
//+------------------------------------------------------------------+
void TrailingStop(double price_ask, double price_bid) {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      string symbol = PositionGetSymbol(i);
      if(symbol == symbolName) {
         ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
         double SLC = PositionGetDouble(POSITION_SL);
         double R3, S3, R1, S1, R2, S2, PP;
         double ihigh = iHigh(symbol, PERIOD_H12, 1), ilow = iLow(symbol, PERIOD_H12, 1), iclose = iClose(symbol, PERIOD_H12, 1);
         PP = (ihigh + ilow + iclose) / 3;
         R3 = ihigh + 2 * (PP - ilow);
         S3 = ilow  - 2 * (ihigh - PP);
         R2 = PP + (ihigh - ilow);
         S2 = PP - (ihigh - ilow);
         R1 = (2 * PP) - ilow;
         S1 = (2 * PP) - ihigh;
         if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_BUY) {
            double NSLB = NormalizeDouble(S3, _Digits);
            double NSLS = NormalizeDouble(S1, _Digits);
            if(UpT == buy) {
               if(trade.PositionModify(PositionTicket, NSLB, 0) && NSLB > SLC) {
                  Print("ok");
               }
            } else {
               if(trade.PositionModify(PositionTicket, NSLS, 0) && NSLS > SLC) {
                  Print("ok");
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
}
//+------------------------------------------------------------------+
//+------------------------------------------------------------------+
