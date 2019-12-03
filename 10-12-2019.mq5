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
enum signal {buy,sell,none,closeBuy,closeSell};
//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input double   order_volume=0.1;                                              // Lot size
input int   POSITIONS=1;
input double   MaximumRisk_=0.01;                                               // Maximum Risk
//--- Trading timespan
input string   Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=0;                                                 // Trading start time
input char     time_h_stop=24;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday
input string InpFileName="optimize.csv";  // optimize file name

double cvolume=0.0;
double MaximumRisk=0.0;
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
bool work_day=true;
double InitBalance;
int SL=100,TP=100;
//+---------------------------------------------+
int OnInit()
  {
   MaximumRisk=MaximumRisk_;
   cvolume=lotsOptimized(MaximumRisk,order_volume);
   trade.SetExpertMagicNumber(939393);
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
double lotsOptimized(double LocalMaximumRisk, double locallot=0.0)
  {
   double lot;
   LocalMaximumRisk = RandD(MaximumRisk_,LocalMaximumRisk);
   if(MQLInfoInteger(MQL_OPTIMIZATION)==true)
     {
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      return lot;
     }
   CAccountInfo myaccount;
   SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);


   if(locallot==0.0)
      lot=NormalizeDouble(locallot*LocalMaximumRisk*_Point,2);
   else
      lot=NormalizeDouble(myaccount.FreeMargin()*LocalMaximumRisk*_Point,2);
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   int ratio=(int)MathRound(lot/volume_step);
   if(MathAbs(ratio*volume_step-lot)>0.0000001)
      lot=ratio*volume_step;

   lot = MathMax(SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN),MathMin(SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX),lot));
   /*if(lot<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(lot>SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);*/
   return(lot);
  }
//+------------------------------------------------------------------+
void CloseAllBuyPositions()
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      ulong ticket=PositionGetTicket(i);
      if(ticket>0)
        {
         trade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
signal Brain(string symbol, ENUM_TIMEFRAMES period)
  {
   int BBoi=iBands(symbol,period,20,0,2.0,PRICE_CLOSE);//86
   int RSIi=iRSI(symbol,period,14,PRICE_CLOSE);//21
   int Stoc=iStochastic(symbol,period,14,3,3,MODE_SMA,STO_CLOSECLOSE);

   double BBoiU[];
   double BBoiL[];
   double RSIiV[];
   double StocV[];
   double StocS[];

   ArraySetAsSeries(BBoiU,true);
   CopyBuffer(BBoi,0,0,10,BBoiU);

   ArraySetAsSeries(BBoiL,true);
   CopyBuffer(BBoi,1,0,10,BBoiL);

   ArraySetAsSeries(RSIiV,true);
   CopyBuffer(RSIi,0,0,10,RSIiV);

   ArraySetAsSeries(StocV,true);
   CopyBuffer(Stoc,0,0,10,StocV);

   ArraySetAsSeries(StocS,true);
   CopyBuffer(Stoc,1,0,10,StocS);

   double fopen=iOpen(symbol,period,0),fclose=iClose(symbol,period,0);
   if(fopen==fclose)
      return none;
   for(int i=1; i<10; i++)
     {
      double ihigh=iHigh(symbol,period,i),ilow=iLow(symbol,period,i);
      if(fopen > fclose)
        {
         if(RSIiV[i]>70.0)
           {
            if(StocS[i]>80 && StocV[i]>80)
              {
               if(ihigh>BBoiU[i])
                  return buy;
              }
           }
        }
      if(fopen < fclose)
        {
         if(RSIiV[i]<30.0)
           {
            if(StocS[i]<20 && StocV[i]<20)
              {
               if(ilow<BBoiL[i])
                  return sell;
              }
           }
        }

     }
   return none;
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   bool NC=false;
   int period_seconds=PeriodSeconds(_Period);
   datetime new_time=TimeCurrent()/period_seconds*period_seconds;
   if(current_chart.isNewBar(new_time))
      NC=true;
   double Balance = AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   double price_ask = SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double price_bid = SymbolInfoDouble(_Symbol,SYMBOL_BID);

   signal CurrentSignal=none;
//---
   time_now_var=TimeCurrent(time_now_str);
   bool work=false;
   switch(time_now_str.day_of_week)
     {
      case 1:
         if(mon==false)
           {
            work_day=false;
           }
         else
           {
            work_day=true;
           }
         break;
      case 2:
         if(tue==false)
           {
            work_day=false;
           }
         else
           {
            work_day=true;
           }
         break;
      case 3:
         if(wen==false)
           {
            work_day=false;
           }
         else
           {
            work_day=true;
           }
         break;
      case 4:
         if(thu==false)
           {
            work_day=false;
           }
         else
           {
            work_day=true;
           }
         break;
      case 5:
         if(fri==false)
           {
            work_day=false;
           }
         else
           {
            work_day=true;
           }
         break;
     }

   Comment("\nBuy Volume: ",cvolume,"\nSell Volume: ",cvolume,"\n Max Risk: ",MaximumRisk);

   if(time_h_start>time_h_stop)
     {
      if(time_now_str.hour>=time_h_start || time_now_str.hour<=time_h_stop)
        {
         work=true;
        }
     }
   else
     {
      if(time_now_str.hour>=time_h_start && time_now_str.hour<=time_h_stop)
        {
         work=true;
        }
     }
   if(NC && PositionsTotal()>0)
     {
      TrailingStop(price_ask,price_bid);
     }

   if(CurrentSignal!=none && PositionsTotal()<POSITIONS)
     {
      double rdn = Rand(0,10);
      if(rdn<5)
        {
         if(Equity>Balance)
           {
            MaximumRisk+=MaximumRisk_;
           }
         else
           {
            MaximumRisk=MaximumRisk_;
           }
        }
      else
        {
         if(Balance<InitBalance)
           {
            MaximumRisk*=2;
           }
         else
           {
            MaximumRisk=MaximumRisk_;
           }
        }
     }
   if(work==true && work_day==true && NC)
     {
      string symbol=_Symbol;
      int stotal=SymbolsTotal(true);
      for(int sis=0; sis<stotal; sis++)
        {
         symbol = SymbolName(sis,true);
         CurrentSignal = Brain(symbol,_Period);
         if(CurrentSignal!=none)
            printf(symbol,":",EnumToString(CurrentSignal));
         if(CurrentSignal!=none)
            cvolume=lotsOptimized(MaximumRisk,cvolume);
         if(CurrentSignal==buy)
           {
            if(POSITIONS<PositionsTotal())
              {
               if(trade.Buy(cvolume,symbol,price_ask,price_ask-SL*_Point,price_ask+TP*_Point,symbol))
                 {
                 }
              }
            else
               if(CurrentSignal==sell)
                 {
                  if(POSITIONS<PositionsTotal())
                    {
                     if(trade.Sell(cvolume,symbol,price_bid,price_bid+SL*_Point,price_bid-TP*_Point,symbol))
                       {
                       }
                    }
                 }
           }
        }
     }
  }
signal BollingerBands(string _symbol,ENUM_TIMEFRAMES _period, int period, double Deviation)
{
   MqlRates RateArray[];
   ArrayResize(RateArray,period);
   if(!CopyRates(_symbol,_period,0,period,RateArray))
      return none;
   
   
   return none;
}
//+------------------------------------------------------------------+
signal HeikenAshi(ENUM_TIMEFRAMES _period=PERIOD_H1)
  {
   MqlRates RateArray[];
   ArrayResize(RateArray,3);
   if(!CopyRates(_Symbol,_period,0,3,RateArray))
      return none;
   double HAC=(RateArray[0].open+RateArray[0].high+RateArray[0].low+RateArray[0].close)/4;
   double HAO=(RateArray[1].open+RateArray[1].close)/2;
   if(HAO<HAC)
      return buy;
   else
      return sell;
   return none;
  }
//+------------------------------------------------------------------+
void TrailingStop(double price_ask,double price_bid)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      if(symbol==_Symbol)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double SLC=PositionGetDouble(POSITION_SL);
         double TPC=PositionGetDouble(POSITION_TP);
         string CMC=PositionGetString(POSITION_COMMENT);
         long MGC=PositionGetInteger(POSITION_MAGIC);
         double PPC=PositionGetDouble(POSITION_PROFIT);
         signal HASHI=HeikenAshi();
         if(MGC==46)
            continue;
         if(CMC!=NULL && CMC!="")
            continue;
         int lSL=50,lSL2=1;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            double NSL=NormalizeDouble(price_ask+(PPC>0?50:20)*_Point,_Digits);
            double NSL2=NormalizeDouble(price_ask-(PPC>0?50:20)*_Point,_Digits);
            if(HASHI==buy)
              {
               if(trade.PositionModify(PositionTicket,NSL,TPC+(PPC>0?10:5)*_Point))
                 {
                  Print("error");
                 }
              }
            else
              {
               if(trade.PositionModify(PositionTicket,NSL2,TPC-(PPC>0?10:2)*_Point))
                 {
                  Print("error");
                 }
              }
           }
         else
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
              {
               double NSL=NormalizeDouble(price_bid-(PPC>0?50:20)*_Point,_Digits);
               double NSL2=NormalizeDouble(price_bid+(PPC>0?50:20)*_Point,_Digits);
               if(HASHI==sell)
                 {
                  if(!trade.PositionModify(PositionTicket,NSL,TPC-(PPC>0?10:5)*_Point))
                    {
                     Print("error");
                    }
                 }
               else
                 {
                  if(!trade.PositionModify(PositionTicket,NSL2,TPC+(PPC>0?10:2)*_Point))
                    {
                     Print("error");
                    }
                 }
              }
        }
     }
  }
//+------------------------------------------------------------------+
double Rand(const double min,const double max)
  {
   double f=(MathRand()/32768.0);

   return min + (int)(f * (max - min));
  }
//+------------------------------------------------------------------+
double RandD(const double min,const double max)
  {
   double f=(MathRand()/32768.0);

   return min + (double)(f * (max - min));
  }
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
