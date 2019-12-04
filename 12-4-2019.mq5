//+------------------------------------------------------------------+
//|                                                                  |
//|       Aiden                                                      |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.50"
#include<Trade\Trade.mqh>
#include <Trade\AccountInfo.mqh>
#include <Arrays\ArrayLong.mqh>

enum signal {buy, sell, none, closeBuy, closeSell};
//--- EA inputs
input string   EAinputs = "EA inputs";                                         // EA inputs
input double   MaximumRisk_ = 1;                                               // Maximum Risk
//--- Trading timespan
input string   Tradingtimespan = "Trading timespan";                           // Trading timespan
input char     time_h_start = 0;                                               // Trading start time
input char     time_h_stop = 24;                                               // Trading stop time
input bool     mon = true;                                                     // Work on Monday
input bool     tue = true;                                                     // Work on Tuesday
input bool     wen = true;                                                     // Work on Wednesday
input bool     thu = true;                                                     // Work on Thursday
input bool     fri = true;                                                     // Work on Friday                                                     // Work on Friday
input int      VerticalCount = 162;                                             // Vertical Period
input int      HorizonCount = 33;                                              // Horizon Period
input ENUM_TIMEFRAMES VerticalTimeFrame = PERIOD_H1;                                   // Vertical Timeframe
input ENUM_TIMEFRAMES HorizonTimeFrame = PERIOD_M30;                                // Horizon Timeframe
input ENUM_TIMEFRAMES PeriodTrailingStop = PERIOD_H1;                                // TrailingStop Timeframe

double cvolume = 0.0;
double MaximumRisk = 0.0;
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
bool work_day = true;
double InitBalance;
signal lastSignal;
signal UpT;

CArrayLong       TSList;
CAccountInfo myaccount;
double CurrentLot;

int Gann, PCI;
int MACD;

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int OnInit() {
   if (VerticalCount < HorizonCount) return (INIT_FAILED);
   if (VerticalTimeFrame < HorizonTimeFrame) return (INIT_FAILED);
   isNewBar(_Symbol, VerticalTimeFrame);
   isNewBar1(_Symbol, HorizonTimeFrame);
   isNewBar2(_Symbol, PeriodTrailingStop);
   lastSignal = none;
   UpT = none;
   MaximumRisk = MaximumRisk_;
   cvolume = 0.01;
   CurrentLot = lotsOptimized();
   trade.SetExpertMagicNumber(939393);
   InitBalance = AccountInfoDouble(ACCOUNT_BALANCE);
   setVertical(_Symbol, VerticalTimeFrame, VerticalCount);
   setHorizon(_Symbol, HorizonTimeFrame, HorizonCount);
   return(INIT_SUCCEEDED);
}
double lotsOptimized() {
   double lot;
   long leverage = myaccount.Leverage();
   double margin = myaccount.FreeMargin();
   double equity = myaccount.Equity();
   lot = ((MaximumRisk * margin) / 100) * _Point * (margin / equity * leverage);
   if(margin * leverage - (lot * _Point) < 0.0)
      lot = NormalizeDouble(0.01, 2);
   else
      lot = NormalizeDouble(lot, 2);
   double volume_step = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_STEP);
   int ratio = (int)MathRound(lot / volume_step);
   if(MathAbs(ratio * volume_step - lot) > _Point)
      lot = ratio * volume_step;
   lot = MathMax(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN), MathMin(SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX), lot));
   return(lot);
}
void CloseAllPositions() {
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      double POFF = PositionGetDouble(POSITION_PROFIT);
      if(ticket > 0) {
         bool ACC = true;
         if (POFF < 0) {
            ACC = false;
            if (TSList.SearchLinear(ticket) == -1) TSList.Add(ticket);
            TrailingStop(i);
         }
         if (ACC) {
            if(!trade.PositionClose(ticket)) {
               Print("error");
            }
         }
      }
   }
}
signal Brain(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 14) {
   return Horizon(symbol, period, shrtMA);
}
signal CandleTrend(string symbol, ENUM_TIMEFRAMES period, int count = 1) {
   int direction = 0;
   for (int i = 0; i < count; i++) {
      double ic = iClose(Symbol(), period, i);
      double io = iOpen(Symbol(), period, i);
      if (ic > io) direction++;
      if (ic < io) direction--;
   }
   if (direction > 0) return buy;
   if (direction < 0) return sell;
   return none;
}
signal Vertical(string symbol, ENUM_TIMEFRAMES period, int count = 22) {
   double GannColor[]; // 1 = buy && 2 = sell
   ArraySetAsSeries(GannColor, true);
   CopyBuffer(Gann, 4, 0, 2, GannColor);
   if (GannColor[0] == 1) return buy;
   if (GannColor[0] == 2) return sell;
   return none;
}
signal Horizon(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 22) {
   double MACDValue[];
   double MACDSignal[];
   ArraySetAsSeries(MACDValue, true);
   CopyBuffer(MACD, 0, 0, 2, MACDValue);
   ArraySetAsSeries(MACDSignal, true);
   CopyBuffer(MACD, 1, 0, 2, MACDSignal);
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
   if (LValue[0] > ilow && MValue[0] > iclose) {
      if (MACDValue[0] < 0.0 && MACDSignal[0] < 0.0) {
      if (MACDValue[0] > MACDValue[1]) {
         return buy;
         }
      }
   } else if (HValue[0] < ihigh && MValue[0] < iclose) {
      if (MACDValue[0] > 0.0 && MACDSignal[0] > 0.0) {
      if (MACDValue[0] < MACDValue[1]) {
         return sell;
         }
      }
   }
   return none;
}
void setVertical(string symbol, ENUM_TIMEFRAMES period, int count = 22) {
   Gann = iCustom(symbol, period, "Gann", period, count);
}
void setHorizon(string symbol, ENUM_TIMEFRAMES period, int count = 22) {
   PCI = iCustom(symbol, period, "PCI", count);
   MACD = iMACD(symbol, period, 12, count, 9, PRICE_CLOSE);
}
void SetUpT(string symbol, ENUM_TIMEFRAMES period, int shrtMA = 22) {
   UpT = Vertical(symbol, period, shrtMA);
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
   bool work = false;
   bool NCD = isNewBar(_Symbol, VerticalTimeFrame);
   bool NCC = isNewBar1(_Symbol, HorizonTimeFrame);
   bool NCH = isNewBar2(_Symbol, PeriodTrailingStop);
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
      if (NCD) {
         SetUpT(symbol, VerticalTimeFrame, VerticalCount);
      }
      if (NCC) {
         CurrentSignal = Brain(symbol, HorizonTimeFrame);
      }
      Comment("Last Signal was: ", EnumToString(lastSignal), "\n", "Current Signal is: ", EnumToString(CurrentSignal), "\n", "Horizon is: ", EnumToString(UpT));
      if (CurrentLot > 0.0 && CurrentSignal != none) {
         double R3, S3, R1, S1, R2, S2, PP;
         double ihigh = iHigh(symbol, PeriodTrailingStop, 1), ilow = iLow(symbol, PeriodTrailingStop, 1), iclose = iClose(symbol, PeriodTrailingStop, 1);
         PP = (ihigh + ilow + iclose) / 3;
         R3 = ihigh + 2 * (PP - ilow);
         S3 = ilow  - 2 * (ihigh - PP);
         R2 = PP + (ihigh - ilow);
         S2 = PP - (ihigh - ilow);
         R1 = (2 * PP) - ilow;
         S1 = (2 * PP) - ihigh;
         if(CurrentSignal == buy) {
            if(lastSignal == sell)
               CloseAllPositions();
            if(trade.Buy(cvolume, symbol, price_ask, 0, R3, symbol)) {
               CurrentLot -= cvolume;
               lastSignal = buy;
            }
         } else if(CurrentSignal == sell) {
            if(lastSignal == buy)
               CloseAllPositions();
            if(trade.Sell(cvolume, symbol, price_bid, 0, S3, symbol)) {
               CurrentLot -= cvolume;
               lastSignal = sell;
            }
         }
      }
   } else {
      Comment("Aiden is sleeping");
   }
   if(CurrentLot <= 0.0) {
      CurrentLot = lotsOptimized();
   }
   if (NCH) {
      TrailingStopAll();
      RiskMan();
      CleanUpList();
   }
}
void TrailingStopAll() {
   double SPROF = 0;
   for(int i = PositionsTotal() - 1; i >= 0; i--) {
      ulong ticket = PositionGetTicket(i);
      double POFF = PositionGetDouble(POSITION_PROFIT);
      SPROF += POFF;
      if(ticket > 0) {
         if (POFF < 100) {
            if (TSList.SearchLinear(ticket) == -1) TSList.Add(ticket);
            TrailingStop(i);
         }
      }
   }
   if (SPROF <= -50.0) {
      CloseAllPositions();
   }
}
void CleanUpList() {
   if (PositionsTotal() < 1 && TSList.Total() > 0) {
      TSList.Shutdown();
   }
}
void TrailingStop(int i) {
   string symbol = PositionGetSymbol(i);
   if(symbol == _Symbol) {
      ulong PositionTicket = PositionGetInteger(POSITION_TICKET);
      if (TSList.SearchLinear(PositionTicket) == -1) {
         return;
      }
      double SLC = PositionGetDouble(POSITION_SL);
      double TPC = PositionGetDouble(POSITION_TP);
      double R3, S3, R1, S1, R2, S2, PP;
      double ihigh = iHigh(symbol, PeriodTrailingStop, 1), ilow = iLow(symbol, PeriodTrailingStop, 1), iclose = iClose(symbol, PeriodTrailingStop, 1);
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
            if (NSLB > SLC || SLC == 0.0) {
               if(!trade.PositionModify(PositionTicket, NSLB * 1.5, TPC)) {
                  Print("error");
               }
            }
         } else {
            if (NSLS > SLC || SLC == 0.0) {
               if(!trade.PositionModify(PositionTicket, NSLS, TPC)) {
                  Print("error");
               }
            }
         }
      } else if(PositionGetInteger(POSITION_TYPE) == POSITION_TYPE_SELL) {
         double NSLB = NormalizeDouble(R3, _Digits);
         double NSLS = NormalizeDouble(R1, _Digits);
         if(UpT == sell) {
            if (NSLB < SLC || SLC == 0.0) {
               if(!trade.PositionModify(PositionTicket, NSLB * 1.5, 0)) {
                  Print("error");
               }
            }
         } else {
            if (NSLS < SLC || SLC == 0.0) {
               if(!trade.PositionModify(PositionTicket, NSLS, 0)) {
                  Print("error");
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
bool isNewBar(string symbol, ENUM_TIMEFRAMES period) {
   static long lastBarCount = -1;
   long currentBarCount =  Bars(symbol, period);
   if(lastBarCount != currentBarCount) {
      lastBarCount = currentBarCount;
      return true;
   } else {
      return false;
   }
}
//+------------------------------------------------------------------+
bool isNewBar1(string symbol, ENUM_TIMEFRAMES period) {
   static long lastBarCount = -1;
   long currentBarCount =  Bars(symbol, period);
   if(lastBarCount != currentBarCount) {
      lastBarCount = currentBarCount;
      return true;
   } else {
      return false;
   }
}
//+------------------------------------------------------------------+
bool isNewBar2(string symbol, ENUM_TIMEFRAMES period) {
   static long lastBarCount = -1;
   long currentBarCount =  Bars(symbol, period);
   if(lastBarCount != currentBarCount) {
      lastBarCount = currentBarCount;
      return true;
   } else {
      return false;
   }
}
//+------------------------------------------------------------------+
