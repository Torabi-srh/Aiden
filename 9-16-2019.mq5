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
CisNewBar current_chart;
//+---------------------
enum signal {buy,sell,none,closeBuy,closeSell};
enum processType {open,high,low,close};
enum enum_trailingStop {STS,MTFTS,NTS};
//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input int      take_profit=150;                                                // Take Profit
input int      stop_loss=100;                                                  // Stop Loss
input long     magic_number=939393;                                            // Magic number
input double   order_volume=0.01;                                              // Lot size
input int      order_deviation=105;                                            // Deviation by position opening
input ENUM_TIMEFRAMES      mainPeriod=PERIOD_M1;                               // Main Time Frame
input string   AnalyseSymbol="EURUSD_i";                                       // Analyse Symbol
input string   TradeSymbol="EURUSD_i";                                         // Trade Symbol

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
CPositionInfo     iPosition;
double CurrentSL,CurrentTP,CurrentVOL;
double PCurrentSL,PCurrentTP;
double breathLevel=3;
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
signal OpenSignal;
signal CurrentSignal;
bool work_day=true;
double Strike;
double LAST_TRADE_PROFIT=0;     // global variable
double GLOBAL_TRADE_PROFIT=0;     // global variable
double GLOBAL_TRADE_PROFIT_LIST[5];     // global variable
double InitBalance=0;     // global variable  
double LastVolume=0;

int HighEMA;
int LowEMA;
int Momentum;
int HeikenAshi;
int Stochastic;

string const symbols2[5][2]=
  {
     {"AUDUSD_i","UP"},{"EURUSD_i","UP"},{"GBPUSD_i","UP"},{"NZDUSD_i","UP"},{"USDJPY_i","UP"}
  };
string const symbols[5]=
  {
   "AUDUSD_i","EURUSD_i","GBPUSD_i","NZDUSD_i","USDJPY_i"
  };
//+---------------------------------------------+
int OnInit()
  {
   LastVolume=order_volume;
   CurrentSL = stop_loss;
   CurrentTP = take_profit;
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(order_deviation);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   CurrentSignal=none;
   Strike=20;
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   GLOBAL_TRADE_PROFIT_LIST[0] = 0;
   GLOBAL_TRADE_PROFIT_LIST[1] = 0;
   GLOBAL_TRADE_PROFIT_LIST[2] = 0;
   GLOBAL_TRADE_PROFIT_LIST[3] = 0;
   GLOBAL_TRADE_PROFIT_LIST[4] = 0;
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
void OnTrade()
  {
   double price_bid=SymbolInfoDouble(TradeSymbol,SYMBOL_BID);
   static int previous_open_positions=0;
   int current_open_positions=PositionsTotal();
   if(current_open_positions<previous_open_positions) // a position just got closed:
     {
      previous_open_positions=current_open_positions;
      HistorySelect(TimeCurrent()-300,TimeCurrent()); // 5 minutes ago
      int All_Deals=HistoryDealsTotal();
      if(All_Deals<1) Print("Some nasty shit error has occurred :s");
      // last deal (should be an DEAL_ENTRY_OUT type):
      ulong temp_Ticket=HistoryDealGetTicket(All_Deals-1);
      // here check some validity factors of the position-closing deal 
      // (symbol, position ID, even MagicNumber if you care...)
      LAST_TRADE_PROFIT=HistoryDealGetDouble(temp_Ticket,DEAL_PROFIT);
      GLOBAL_TRADE_PROFIT+=LAST_TRADE_PROFIT;

      GLOBAL_TRADE_PROFIT_LIST[1] = GLOBAL_TRADE_PROFIT_LIST[2];
      GLOBAL_TRADE_PROFIT_LIST[2] = GLOBAL_TRADE_PROFIT_LIST[3];
      GLOBAL_TRADE_PROFIT_LIST[3] = GLOBAL_TRADE_PROFIT_LIST[4];
      GLOBAL_TRADE_PROFIT_LIST[4] = LAST_TRADE_PROFIT;
      if(LAST_TRADE_PROFIT>0)
        {
         Strike*=2;
           } else {
         Strike=20;
        }
      Print("Last Trade Profit : ",DoubleToString(LAST_TRADE_PROFIT));
     }
   else if(current_open_positions>previous_open_positions) // a position just got opened:
   previous_open_positions=current_open_positions;
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
   if(Equity>=Balance*110) CloseAllBuyPositions();
//bool NC2=IsNewCandle(TradeSymbol);

   int pos=PositionsTotal();
   double price_ask=SymbolInfoDouble(TradeSymbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(TradeSymbol,SYMBOL_BID);

   if(NC) CurrentSignal=Archer(price_ask,price_bid);
   Comment(CurrentSignal);
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
   if(pos<2)
     {
      if(GLOBAL_TRADE_PROFIT_LIST[4]>GLOBAL_TRADE_PROFIT_LIST[3])
        {
         LastVolume=calculateVolume(order_volume,CurrentSL,1)+order_volume;
        }
      else
        {
         LastVolume=order_volume;
        }
     }
   else
     {
      //SimpleTrailingStop(price_ask,price_bid);
     }
   if(work==true && work_day==true && NC) // work enabled
     {
      if(CurrentSignal==buy)
        {
         if(pos<2)
           {
            double P=0;
            if(_Digits==5 || _Digits==3 || _Digits==1) P=10;else P=1; // To account for 5 digit brokers
            double minStopLevel=NormalizeDouble((price_ask-CurrentSL)/_Point,0);
            //CurrentSL = price_ask+minStopLevel * _Point * P;
            //CurrentSL=calculateSL(price_ask,CurrentSL);
            if(price_ask<=CurrentSL) CurrentSL=price_ask+((price_ask-50)*_Point);
            double VOL2=LastVolume;
            trade.Buy(VOL2,TradeSymbol,price_ask,CurrentSL,CurrentTP,"");
            LastVolume=VOL2;
            OpenSignal=buy;
           }
        }
     }
  }
//+------------------------------------------------------------------+
signal Archer(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   int HighEMA=iMA(_Symbol,_Period,86,0,MODE_EMA,PRICE_CLOSE);
   int LowEMA=iMA(_Symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   int Momentum=iMomentum(_Symbol,_Period,8,PRICE_CLOSE);
   int HeikenAshi=iCustom(_Symbol,_Period,"heiken_ashi_smoothed");
   int Stochastic=iStochastic(_Symbol,_Period,8,3,3,MODE_SMA,STO_CLOSECLOSE);

   if(period==PERIOD_CURRENT)period=_Period;
   double HighEMAValue[];
   double LowEMAValue[];
   double MomentumValue[];
   double HeikenAshiValue[];
   double StochasticValue[];
   double StochasticSignal[];

   ArraySetAsSeries(HighEMAValue,true);
   CopyBuffer(HighEMA,0,0,3,HighEMAValue);

   ArraySetAsSeries(LowEMAValue,true);
   CopyBuffer(LowEMA,0,0,3,LowEMAValue);

   ArraySetAsSeries(MomentumValue,true);
   CopyBuffer(Momentum,0,0,3,MomentumValue);

   ArraySetAsSeries(HeikenAshiValue,true);
   CopyBuffer(HeikenAshi,4,0,3,HeikenAshiValue);//0 = up | 1 = down

   ArraySetAsSeries(StochasticValue,true);
   CopyBuffer(Stochastic,0,0,3,StochasticValue);
   
   ArraySetAsSeries(StochasticSignal,true);
   CopyBuffer(Stochastic,1,0,3,StochasticSignal);
   
   if (HeikenAshiValue[0]==0)
   {
      if (LowEMAValue[2]<HighEMAValue[2] && LowEMAValue[0]>HighEMAValue[0]) 
      {
         if (MomentumValue[0] > 100)
         {
            if (StochasticValue[0] > 40 && StochasticValue[0] < StochasticSignal[0])
            {  
            return buy;
            }
         }
      }
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
double normalizeVolume(double value)
  {
   double min = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(TradeSymbol, SYMBOL_VOLUME_MAX);
   double step= SymbolInfoDouble(TradeSymbol,SYMBOL_VOLUME_STEP);
   if(value<0)
      value=order_volume;
   if(value<min)
      value=min;
   if(value>max)
      value=max;

   value=MathRound(value/step)*step;

   if(step >= 0.1)
      value = NormalizeDouble(value, 1);
   else
      value=NormalizeDouble(value,2);

   return value;
  }
//+------------------------------------------------------------------+
double calculateVolume(double Entry,double SL,double Percent)
  {
   double AccountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   double AmountToRisk=AccountBalance*Percent/100;

   double ValuePp=SymbolInfoDouble(TradeSymbol,SYMBOL_TRADE_TICK_VALUE);

   double Difference=MathAbs((Entry-SL)/_Point);
   Difference=Difference*ValuePp;

   if(Difference==0)
      return 0;

   return normalizeVolume(AmountToRisk/Difference);
  }
//+------------------------------------------------------------------+
void SimpleTrailingStop(double price_ask,double price_bid)
  {
   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      ulong magic=PositionGetInteger(POSITION_MAGIC);
      if(symbol==TradeSymbol && magic==magic_number)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double StopLossCorrente=PositionGetDouble(POSITION_SL);
         double TakeProfitCorrente=PositionGetDouble(POSITION_TP);
         datetime PositionTime=(datetime)PositionGetInteger(POSITION_TIME);
         ENUM_POSITION_TYPE tp=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         int barNum=iBarShift(_Symbol,_Period,PositionTime);
         if(tp==POSITION_TYPE_BUY)
           {
            double NewSL=NormalizeDouble(price_ask-(50*_Point),_Digits);
            if(NewSL>StopLossCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,TakeProfitCorrente))
                 {
                 }
              }
           }
         else if(tp==POSITION_TYPE_SELL)
           {
            double NewSL=NormalizeDouble(price_bid+(50*_Point),_Digits);
            if(NewSL<StopLossCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,TakeProfitCorrente))
                 {
                 }
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
