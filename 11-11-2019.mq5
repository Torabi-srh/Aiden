//+------------------------------------------------------------------+
//|                                                                  |
//|       implament Fibbonachi retrasement as mid point trade        |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.50"
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
int Zigzag;
//+---------------------------------------------+
int OnInit() {
   symbolName = "EURUSD";
   lastSignal = none;
   UpT = none;
   MaximumRisk = MaximumRisk_;
   cvolume = lotsOptimized(MaximumRisk, order_volume);
   trade.SetExpertMagicNumber(939393);
   InitBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   Zigzag = iCustom(symbolName, PERIOD_D1, "ZigzagColor", 12, 5, 3);
   return(INIT_SUCCEEDED);
}
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
void CloseAllPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      if(ticket > 0) {
         trade.PositionClose(ticket);
      }
   }
}
signal Brain(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14) {
   return ehlers(symbol, period, shrtMA);
}
signal ehlers(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 25, double min = 0.0, double max = 0.0) {
   int Force;
   Force = iForce(symbol, period, 13, MODE_SMA, VOLUME_TICK);
   double FCValue[];
   ArraySetAsSeries(FCValue, true);
   CopyBuffer(Force, 0, 0, 1, FCValue);
   if (FCValue[0] < 0.1 || FCValue[0] > -0.1) return none;
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
signal Zigzag(string symbol, ENUM_TIMEFRAMES period, int ExtDepth = 12, double ExtDeviation = 5, double ExtBackStep = 3) {
   Zigzag = iCustom(symbol, period, "ZigzagColor", ExtDepth, ExtDeviation, ExtBackStep);
   double ZValue[];
   double XValue[];
   double CValue[];
   double VValue[];
   double BValue[];
   ArraySetAsSeries(BValue, true);
   CopyBuffer(Zigzag, 0, 0, 10, BValue);
   ArraySetAsSeries(VValue, true);
   CopyBuffer(Zigzag, 1, 0, 10, VValue);
   ArraySetAsSeries(XValue, true);
   CopyBuffer(Zigzag, 2, 0, 10, XValue);
   ArraySetAsSeries(CValue, true);
   CopyBuffer(Zigzag, 3, 0, 10, CValue);
   ArraySetAsSeries(ZValue, true);
   CopyBuffer(Zigzag, 4, 0, 10, ZValue);
   if (ZValue[0] == 2.0) return sell;
   else if (ZValue[0] == 1.0) return buy;
   return none;
}
void SetUpT(string symbol, int shrtMA = 25) {
   UpT = Zigzag(symbol, PERIOD_D1, shrtMA, -2.0, 2.0);
   Comment(EnumToString(UpT));
}
void RiskMan() {
   double Balance = AccountInfoDouble(ACCOUNT_BALANCE);
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
double RandD(const double min, const double max) {
   double f = (MathRand() / 32768.0);
   return min + (double)(f * (max - min));
}
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
