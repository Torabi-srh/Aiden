//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.01"
#include<Trade\Trade.mqh>
#include <LibCisNewBar.mqh>
#include <Generic\SortedMap.mqh>

CisNewBar current_chart;
//+---------------------
enum signal {buy,sell,none,closeBuy,closeSell};
//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input long     magic_number=143893;                                            // Magic number
input double   order_volume=0.01;                                              // Lot size

//--- Trading timespan
input string   Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=1;                                                 // Trading start time
input char     time_h_stop=24;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday 

//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
signal OpenSignal;
bool work_day=true;
double InitBalance;
//+---------------------------------------------+
int OnInit()
  {
   iDeMarker(_Symbol,_Period,14);
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnTick()
  {
   bool NC=false;
   int period_seconds=PeriodSeconds(_Period);                     // Number of seconds in current chart period
   datetime new_time=TimeCurrent()/period_seconds*period_seconds; // Time of bar opening on current chart
   if(current_chart.isNewBar(new_time)) NC=true;
   double Balance= AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   if(Equity>=InitBalance*1.5) CloseAllBuyPositions();
//bool NC2=IsNewCandle(TradeSymbol);

   int pos=PositionsTotal();

   double price_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   signal CurrentSignal=none;

   if(NC) CurrentSignal=DeM();

//---
   time_now_var=TimeCurrent(time_now_str);      // current time
   bool work=false;

   switch(time_now_str.day_of_week)
     {
      case 1: if(mon==false){work_day=false;}
      else {work_day=true;}
      break;
      case 2: if(tue==false){work_day=false;}
      else {work_day=true;}
      break;
      case 3: if(wen==false){work_day=false;}
      else {work_day=true;}
      break;
      case 4: if(thu==false){work_day=false;}
      else {work_day=true;}
      break;
      case 5: if(fri==false){work_day=false;}
      else {work_day=true;}
      break;
     }

//--- check the working time
   if(time_h_start>time_h_stop) // work with transition to the next day
     {
      if(time_now_str.hour>=time_h_start || time_now_str.hour<=time_h_stop)
        {
         work=true;                              // pass the flag enabling the work 
        }
     }
   else                                          // work during the day
     {
      if(time_now_str.hour>=time_h_start && time_now_str.hour<=time_h_stop)
        {
         work=true;                              // pass the flag enabling the work
        }
     }
   if(pos>0)
     {
      if(OpenSignal==buy)
        {
         CloseAllSellPositions();
        }
      else if(OpenSignal==sell)
        {
         CloseAllBuyPositions();
        }
     }
   if(work==true && work_day==true) // work enabled
     {
      if(CurrentSignal==buy)
        {
         trade.Buy(0.01,_Symbol,price_ask,0,0,NULL);
         OpenSignal=buy;
        }
      else if(CurrentSignal==sell)
        {
         trade.Sell(0.01,_Symbol,price_bid,0,0,NULL);
         OpenSignal=sell;
        }
     }
  }
//+------------------------------------------------------------------+
signal DeM()
  {
   int brs=iBars(_Symbol,_Period);
   if(brs<60) return none;
   int Dem=iDeMarker(_Symbol,_Period,14);

   double DemValue[];

   ArraySetAsSeries(DemValue,true);
   CopyBuffer(Dem,0,0,3,DemValue);

   if(DemValue[0]>0.75)
     {
      return sell;
     }
   else if(DemValue[0]<0.25)
     {
      return buy;
     }
   return none;
  }
//+------------------------------------------------------------------+
void CloseAllBuyPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      ENUM_POSITION_TYPE optype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ticket>0 && optype==POSITION_TYPE_BUY)
        {
         trade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
void CloseAllSellPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      ENUM_POSITION_TYPE optype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
      if(ticket>0 && optype==POSITION_TYPE_SELL)
        {
         trade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
