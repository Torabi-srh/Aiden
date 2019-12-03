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

CisNewBar current_chart;
//+---------------------
enum signal {buy, sell, none, closeBuy, closeSell};
//--- EA inputs
input string   EAinputs = "EA inputs";                                         // EA inputs
input double   order_volume = 0.1;                                            // Lot size
input int   POSITIONS = 1;
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
string symbolName[];
int stotal = 1;
signal lastSignal;
//+---------------------------------------------+
int OnInit() {
   ArrayResize(symbolName, stotal);
   symbolName[0] = "GBPUSD";/*
   symbolName[1] = "AUDUSD";
   symbolName[2] = "USDJPY";
   symbolName[3] = "NZDUSD";
   symbolName[4] = "EURUSD";
   symbolName[5] = "USDCHF";
   symbolName[6] = "USDCAD";
   symbolName[7] = "USDTRY";
   symbolName[8] = "USDHKD";
   symbolName[9] = "USDSEK";
   symbolName[10] = "USDNOK";
   symbolName[11] = "USDMXN";
   symbolName[12] = "USDZAR";
   symbolName[13] = "GBPJPY";
   symbolName[14] = "GBPCHF";
   symbolName[15] = "GBPNZD";
   symbolName[16] = "GBPAUD";
   symbolName[17] = "GBPCAD";
   symbolName[18] = "EURGBP";
   symbolName[19] = "EURJPY";
   symbolName[20] = "EURCHF";
   symbolName[21] = "EURNZD";
   symbolName[22] = "EURAUD";
   symbolName[23] = "EURCAD";
   symbolName[24] = "AUDJPY";
   symbolName[25] = "AUDCHF";
   symbolName[26] = "AUDNZD";
   symbolName[27] = "AUDCAD";
   symbolName[28] = "CADJPY";
   symbolName[29] = "CADCHF";
   symbolName[30] = "NZDCAD";
   symbolName[31] = "CHFJPY";
   symbolName[32] = "NZDCHF";
   symbolName[33] = "NZDJPY";
   symbolName[34] = "XAGAUD";
   symbolName[35] = "XAGCAD";
   symbolName[36] = "XAGCHF";
   symbolName[37] = "XAGEUR";
   symbolName[38] = "XAGHKD";
   symbolName[39] = "XAGJPY";
   symbolName[40] = "XAGMXN";
   symbolName[41] = "XAGTRY";
   symbolName[42] = "XAGUSD";
   symbolName[43] = "XAGZAR";
   symbolName[44] = "XAUAUD";
   symbolName[45] = "XAUCAD";
   symbolName[46] = "XAUCHF";
   symbolName[47] = "XAUEUR";
   symbolName[48] = "XAUGBP";
   symbolName[49] = "XAUHKD";
   symbolName[50] = "XAUJPY";
   symbolName[51] = "XAUMXN";
   symbolName[52] = "XAUTRY";
   symbolName[53] = "XAUUSD";
   symbolName[54] = "XAUZAR";*/
   SetCorrelationCoefficient(2000);
   lastSignal = none;
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
void SetSymbols() {
}
void SetCorrelationCoefficient(int period) {
   string symbol = _Symbol;
   int CrC[55][55] = {0};
   for(int sisx = 0; sisx < stotal; sisx++) {
      MqlRates RateArrayX[];
      ArrayResize(RateArrayX, period);
      if(!CopyRates(symbolName[sisx], _Period, 0, period, RateArrayX))
         continue;
      for(int sisy = 0; sisy < stotal; sisy++) {
         MqlRates RateArrayY[];
         ArrayResize(RateArrayY, period);
         if(!CopyRates(symbolName[sisy], _Period, 0, period, RateArrayY))
            continue;
         CrC[sisx][sisy] = (int)(Correlation(RateArrayX, RateArrayY) * 100);
         CrC[sisx][sisy] = (CrC[sisx][sisy] < -100 ? 0 : (CrC[sisx][sisy] > 100 ? 0 : CrC[sisx][sisy]));
      }
   }
   int file_handle = FileOpen("correli.csv", FILE_READ | FILE_WRITE | FILE_CSV, ";");
   if(file_handle != INVALID_HANDLE) {
      PrintFormat("%s file is available for writing", "correli.csv");
      PrintFormat("File path: %s\\Files\\", TerminalInfoString(TERMINAL_DATA_PATH));
      string Line = "#;";
      for(int y = 0; y < stotal; y++) {
         Line += (string)symbolName[y] + (y == stotal - 1 ? "" : ";");
      }
      FileWrite(file_handle, Line);
      for(int xx = 0; xx < stotal; xx++) {
         Line = (string)symbolName[xx] + ";";
         for(int y = 0; y < stotal; y++) {
            Line += (string)CrC[xx][y] + (y == stotal - 1 ? "" : ";");
         }
         FileWrite(file_handle, Line);
      }
      FileClose(file_handle);
      FileClose(file_handle);
      PrintFormat("Data is written, %s file is closed", "correli.csv");
   }
}
signal BollingerBands(string _symbol, ENUM_TIMEFRAMES _period, int period, double Deviation) {
   MqlRates RateArray[];
   ArrayResize(RateArray, period);
   if(!CopyRates(_symbol, _period, 0, period, RateArray))
      return none;
   double MidBand = SMARate(RateArray);
   double UppBand = MidBand + (Stdev(RateArray) * Deviation);
   double LowBand = MidBand - (Stdev(RateArray) * Deviation);
   double ilowwer = iLow(_symbol, _period, 1);
   double ihigher = iHigh(_symbol, _period, 1);
   if(ilowwer < LowBand)
      return buy;
   if(ihigher > UppBand)
      return sell;
   return none;
   
}
//+------------------------------------------------------------------+
signal Brain(string symbol, ENUM_TIMEFRAMES period) {
//int BBoi=iBands(symbol,period,20,0,2.0,PRICE_CLOSE);//86
   int RSIi = iRSI(symbol, period, 14, PRICE_CLOSE); //21
   int Stoc = iStochastic(symbol, period, 14, 3, 3, MODE_SMA, STO_CLOSECLOSE);
//double BBoiU[];
//double BBoiL[];
   double RSIiV[];
   double StocV[];
   double StocS[];
//ArraySetAsSeries(BBoiU,true);
//CopyBuffer(BBoi,0,0,10,BBoiU);
//ArraySetAsSeries(BBoiL,true);
//CopyBuffer(BBoi,1,0,10,BBoiL);
   ArraySetAsSeries(RSIiV, true);
   CopyBuffer(RSIi, 0, 0, 10, RSIiV);
   ArraySetAsSeries(StocV, true);
   CopyBuffer(Stoc, 0, 0, 10, StocV);
   ArraySetAsSeries(StocS, true);
   CopyBuffer(Stoc, 1, 0, 10, StocS);
   double fopen = iOpen(symbol, period, 1), fclose = iClose(symbol, period, 1);
   if(fopen == fclose)
      return none;
   for(int i = 2; i < 10; i++) {
      double ihigh = iHigh(symbol, period, i), ilow = iLow(symbol, period, i);
      if(fopen > fclose) {
         if(RSIiV[i] > 70.0) {
            if(StocS[i] > 80 && StocV[i] > 80) {
               if(BollingerBands(symbol, period, 20, 2.0) == sell)
                  return sell;
            }
         }
      }
      if(fopen < fclose) {
         if(RSIiV[i] < 30.0) {
            if(StocS[i] < 20 && StocV[i] < 20) {
               if(BollingerBands(symbol, period, 20, 2.0) == buy)
                  return buy;
            }
         }
      }
   }
   return none;
}
//+------------------------------------------------------------------+
void OnTick() {
   bool NC = false;
   int period_seconds = PeriodSeconds(_Period);
   datetime new_time = TimeCurrent() / period_seconds * period_seconds;
   if(current_chart.isNewBar(new_time))
      NC = true;
   double Balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double price_ask = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
   double price_bid = SymbolInfoDouble(_Symbol, SYMBOL_BID);
   signal CurrentSignal = none;
//---
   time_now_var = TimeCurrent(time_now_str);
   bool work = false;
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
   Comment("\nBuy Volume: ", cvolume, "\nSell Volume: ", cvolume, "\n Max Risk: ", MaximumRisk);
   if(time_h_start > time_h_stop) {
      if(time_now_str.hour >= time_h_start || time_now_str.hour <= time_h_stop) {
         work = true;
      }
   } else {
      if(time_now_str.hour >= time_h_start && time_now_str.hour <= time_h_stop) {
         work = true;
      }
   }
   if(PositionsTotal() < POSITIONS) {
      double rdn = RandD(0, 10);
      if(rdn < 5) {
         if(Equity > Balance) {
            MaximumRisk += MaximumRisk_;
         } else {
            MaximumRisk = MaximumRisk_;
         }
      } else {
         if(Balance < InitBalance) {
            MaximumRisk *= 2;
         } else {
            MaximumRisk = MaximumRisk_;
         }
      }
   }
   if(work == true && work_day == true && NC) {
      string symbol = _Symbol;
      for(int sis = 0; sis < stotal; sis++) {
         symbol = symbolName[sis];
         CurrentSignal = Brain(symbol, _Period);
         if(CurrentSignal != none)
            Print(symbol, ":", EnumToString(CurrentSignal));
         if(CurrentSignal != none)
            cvolume = lotsOptimized(MaximumRisk, cvolume);
         if(CurrentSignal == buy) {
            if(lastSignal == sell)
               CloseAllPositions();
            if(POSITIONS > PositionsTotal()) {
               if(trade.Buy(cvolume, symbol, price_ask, 0, 0, symbol)) {
                  lastSignal = buy;
                  Print(symbol, ": bought on ", price_ask);
               }
            }
         } else if(CurrentSignal == sell) {
            if(lastSignal == buy)
               CloseAllPositions();
            if(POSITIONS > PositionsTotal()) {
               if(trade.Sell(cvolume, symbol, price_bid, 0, 0, symbol)) {
                  lastSignal = sell;
                  Print(symbol, ": sold for ", price_bid);
               }
            }
         }
      }
   }
}
//+------------------------------------------------------------------+
double Correlation(MqlRates &X[], MqlRates &Y[]) {
   double sum_X = 0, sum_Y = 0, sum_XY = 0;
   double squareSum_X = 0, squareSum_Y = 0;
   int n = ArraySize(X);
   for(int i = 0; i < n; i++) {
      // sum of elements of array X.
      sum_X = sum_X + X[i].close;
      // sum of elements of array Y.
      sum_Y = sum_Y + Y[i].close;
      // sum of X[i] * Y[i].
      sum_XY = sum_XY + X[i].close * Y[i].close;
      // sum of square of array elements.
      squareSum_X = squareSum_X + X[i].close * X[i].close;
      squareSum_Y = squareSum_Y + Y[i].close * Y[i].close;
   }
// use formula for calculating correlation coefficient.
   double div = sqrt((n * squareSum_X - sum_X * sum_X)
                     * (n * squareSum_Y - sum_Y * sum_Y));
   double corr;
   corr = (div == 0 ? 0 : (double)(n * sum_XY - sum_X * sum_Y)
           / div);
   return corr;
}
//+------------------------------------------------------------------+
double Stdev(MqlRates &data[]) {
   double sum = 0.0, mean, standardDeviation = 0.0;
   int i;
   for(i = 0; i < ArraySize(data); ++i) {
      sum += data[i].close;
   }
   mean = sum / ArraySize(data);
   for(i = 0; i < ArraySize(data); ++i)
      standardDeviation += pow(data[i].close - mean, 2);
   return sqrt(standardDeviation / ArraySize(data));
}
//+------------------------------------------------------------------+
double SMARate(MqlRates &CArray[]) {
   return ArraySumRate(CArray) / ArraySize(CArray);
}
//+------------------------------------------------------------------+
double ArraySumRate(MqlRates &rates[]) {
   double SM = 0;
   for(int i = 0; i < ArraySize(rates); i++) {
      SM += (rates[i].low + rates[i].high + rates[i].close) / 3;
   }
   return SM;
}
//+------------------------------------------------------------------+
signal HeikenAshi(string _symbol, ENUM_TIMEFRAMES _period = PERIOD_H1) {
   MqlRates RateArray[];
   ArrayResize(RateArray, 3);
   if(!CopyRates(_symbol, _period, 0, 3, RateArray))
      return none;
   double HAC = (RateArray[0].open + RateArray[0].high + RateArray[0].low + RateArray[0].close) / 4;
   double HAO = (RateArray[1].open + RateArray[1].close) / 2;
   if(HAO < HAC)
      return buy;
   else
      return sell;
   return none;
}
//+------------------------------------------------------------------+
double RandD(const double min, const double max) {
   double f = (MathRand() / 32768.0);
   return min + (double)(f * (max - min));
}
//+------------------------------------------------------------------+