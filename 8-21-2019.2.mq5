//+------------------------------------------------------------------+
//|                                                                  |
//|                                                                  |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "Soroush.trb"
#property link      ""
#property version   "1.01"
#include<Trade\Trade.mqh>
//+---------------------
enum signal {buy,sell,none,closeBuy,closeSell};
enum processType {open,high,low,close};

//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input int      take_profit=14;                                                // Take Profit
input int      stop_loss=659;                                                  // Stop Loss
input long     magic_number=939393;                                            // Magic number
input double   order_volume=0.01;                                              // Lot size
input int      order_deviation=105;                                            // Deviation by position opening
input ENUM_TIMEFRAMES      mainPeriod=PERIOD_CURRENT;                                // Main Time Frame

//--- Trading timespan
input string   Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=0;                                                 // Trading start time
input char     time_h_stop=24;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday 

//--- RSI-Bollinger Bands Strategy
input string   RSIBollingerStrategy="RSI-Bollinger Bands Strategy";            // RSI-Bollinger Bands Strategy
input int      RSIlength=9;                                                   // RSI Period
input int      RSIoverSold=25;                                                // RSI Down Level
input int      RSIoverBought=75;                                              // RSI Upper Level
input int      BBlength=200;                                                  // Bollinger Bands Period
input int      BBmult=2;                                                      // Bollinger Bands deviation 

//--- Variable
double CurrentSL,CurrentTP;
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
signal CurrentSignal;
bool work_day=true;
double Strike;
double LAST_TRADE_PROFIT=0;     // global variable
double GLOBAL_TRADE_PROFIT=0;     // global variable
double InitBalance=0;     // global variable 
static datetime _lastBarTime=0;
//+---------------------------------------------+
int OnInit()
  {
//--- 
   _lastBarTime=iTime(Symbol(),mainPeriod,0);
   CurrentSL = stop_loss;
   CurrentTP = take_profit;
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(order_deviation);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   CurrentSignal=none;
   Strike=20;
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
//---
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
   double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
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
   int pos=PositionsTotal();

   double price_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);
   double CurrentBalance=AccountInfoDouble(ACCOUNT_BALANCE);

   CurrentSignal=BBRSISignal(price_ask,price_bid,mainPeriod);
   if(work==true && work_day==true && IsNewCandle()) // work enabled
     {
      if(CurrentSignal==buy)
        {
         StopLossByPivotPoint(price_ask,price_bid,mainPeriod,POSITION_TYPE_BUY);
         double VOL=calculateVolume(order_volume,CurrentSL,5);
         if(pos<1) trade.Buy(VOL,_Symbol,price_ask,(price_ask-(CurrentSL*_Point)),(price_ask+(CurrentTP*_Point)),"");
        }
      else
        {
         CloseAllBuyPositions();
        }
      if(CurrentSignal==sell)
        {
         StopLossByPivotPoint(price_ask,price_bid,mainPeriod,POSITION_TYPE_SELL);
         double VOL=calculateVolume(order_volume,CurrentSL,5);
         if(pos<1) trade.Sell(VOL,_Symbol,price_bid,(price_bid+(CurrentSL*_Point)),(price_bid-(CurrentTP*_Point)),"");
        }
      else
        {
         CloseAllSellPositions();
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
double calculateSD(double &data[])
  {
   double sum=0.0,mean,standardDeviation=0.0;
   int i;
   for(i=0; i<10;++i)
     {
      sum+=data[i];
     }
   mean=sum/10;
   for(i=0; i<10;++i)
      standardDeviation+=pow(data[i]-mean,2);
   return sqrt(standardDeviation / 10);
  }
//+------------------------------------------------------------------+
double RSI(int length,ENUM_TIMEFRAMES period)
  {
   double RS;
   double Array[];
   GetRateByType(Array,close,length,period);

   static double AverageGain;
   static double AverageLoss;
   if(AverageGain==0)
     {
      for(int i=length-1;i>0;i--)
        {
         double p=Array[i-1]-Array[i];
         if(p>0) AverageGain+=p;
         else if(p<0) AverageLoss+=MathAbs(p);
        }
      AverageGain /= length;
      AverageLoss /= length;
      RS=AverageGain/AverageLoss;
     }
   else
     {
      double p=Array[0]-Array[1];
      RS=((AverageGain*13+(p>0?p:0))/14)/((AverageLoss*13+(p<0?p:0))/14);
     }
   return 100 - (100 / (1+RS));
  }
//+------------------------------------------------------------------+
signal LRSignal(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_M1)
  {
   int hndlr=iCustom(_Symbol,period,"LinearRegSlope_V2",MODE_SMA,12,15,PRICE_CLOSE,0,1);
   return none;
  }
//+------------------------------------------------------------------+
signal BBRSISignal(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_M1)
  {
   processType price=close;
   double vrsi=RSI(RSIlength,period);
   double BBArray[];
   GetRateByType(BBArray,price,BBlength,period);
   double BBbasis=SMA(BBArray,BBlength);
   double BBdev=BBmult*calculateSD(BBArray);
   double BBupper = BBbasis + BBdev;
   double BBlower = BBbasis - BBdev;

   double iclose=iClose(_Symbol,period,0);
   double ihigh=iHigh(_Symbol,period,0);
   double ilow=iLow(_Symbol,period,0);

   bool buyEntry=(ilow<=BBlower && iclose>BBlower)?true:false;
   bool sellEntry=(ihigh>=BBupper && iclose<BBupper)?true:false;

   double RSIMidPoint=(RSIoverSold+RSIoverBought)/2;

   if(vrsi<RSIoverSold && buyEntry)
     {
      return buy;
     }
   if(vrsi>RSIoverBought && sellEntry)
     {
      return sell;
     }

   return none;
  }
//+------------------------------------------------------------------+
void StopLossByPivotPoint(double Ask,double Bid,ENUM_TIMEFRAMES period,ENUM_POSITION_TYPE tp)
  {
   double iclose=iClose(_Symbol,period,0);
   double ihigh=iHigh(_Symbol,period,0);
   double ilow=iLow(_Symbol,period,0);
   double P,R1,R2,S1,S2;
   P=(ihigh+ilow+iclose)/3;
   R1 = (P*2)-ilow;
   R2 = P+(ihigh-ilow);
   S1 = (P*2)-ihigh;
   S2 = P-(ihigh-ilow);

   if(tp==POSITION_TYPE_SELL)
     {
      CurrentSL=MathAbs((R2-Bid)/_Point)+30;
      CurrentTP=MathAbs((S2-Bid)/_Point)+30;
     }
   else if(tp==POSITION_TYPE_BUY)
     {
      CurrentSL=MathAbs((Ask-S2)/_Point)+30;
      CurrentTP=MathAbs((Ask-R2)/_Point)+30;
     }
  }
//+------------------------------------------------------------------+
double SMA(double &CArray[],int length)
  {
   return ArraySum(CArray)/length;
  }
//+------------------------------------------------------------------+
void GetRateByType(double &CArray[],processType pType,int length,ENUM_TIMEFRAMES period=PERIOD_M1)
  {
   MqlRates rates[];
   ArrayResize(rates,length);
   if(!CopyRates(_Symbol,period,0,length,rates)) return;
   ArrayResize(CArray,length);
   for(int i=0;i<length;i++)
     {
      switch(pType)
        {
         case close:
            CArray[i]=rates[i].close;break;
         case low:
            CArray[i]=rates[i].low;break;
         case high:
            CArray[i]=rates[i].high;break;
         case open:
            CArray[i]=rates[i].open;break;
        }
     }
  }
//+------------------------------------------------------------------+
double ArraySum(double &rates[])
  {
   double SM=0;
   for(int i=0;i<ArraySize(rates);i++)
     {
      SM+=rates[i];
     }
   return SM;
  }
//+------------------------------------------------------------------+
double normalizeVolume(double value)
  {
   double min = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_Symbol, SYMBOL_VOLUME_MAX);
   double step= SymbolInfoDouble(_Symbol,SYMBOL_VOLUME_STEP);
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
//|                                                                  |
//+------------------------------------------------------------------+
double calculateVolume(double Entry,double SL,double Percent)
  {
   double AccountBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   double AmountToRisk=AccountBalance*Percent/100;

   double ValuePp=SymbolInfoDouble(_Symbol,SYMBOL_TRADE_TICK_VALUE);

   double Difference=MathAbs((Entry-SL)/_Point);
   Difference=Difference*ValuePp;

   if(Difference==0)
      return 0;

   return normalizeVolume(AmountToRisk/Difference);
  }
//+------------------------------------------------------------------+
bool IsNewCandle()
  {
   if(iTime(Symbol(),Period(),0)!=_lastBarTime)
     {
      _lastBarTime=iTime(_Symbol,mainPeriod,0);

      return (true);
     }
   else
      return (false);
  }
//+------------------------------------------------------------------+
