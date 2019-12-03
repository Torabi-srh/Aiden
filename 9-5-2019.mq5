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

//--- Multi TimeFrame TrailingStop
input string   MultiTimeFrameTrailingStop_="Multi TimeFrame TrailingStop";     // Multi TimeFrame TrailingStop
input enum_trailingStop     TrailingStopMode=MTFTS;                                // Trailing Stop Mode
input double   breath=113;                                                       // Breath between positions
input int      BreathLevel_M1=3;                                               // 1 Minutes TimeFrame     
input int      BreathLevel_M5=15;                                               // 5 Minutes TimeFrame         
input int      BreathLevel_M30=90;                                             // 30 Minutes TimeFrame

//----
input int iGann=50;                                                   // Gann period
input int MACD_FAST=23;                                               // MACD fast ema
input int MACD_PERIOD=50;                                             // MACD period
input int MACD_SIGNAL=17;                                             // MACD Signal
input double paraStep=0.04;                                             // ParabolicSAR Step
input double paraMax=0.1;                                             // ParabolicSAR Max
//--- Variable
CPositionInfo     iPosition;
double CurrentSL,CurrentTP;
double breathLevel=3;
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
signal LastSignal;
signal OpenSignal;
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
   _lastBarTime=iTime(TradeSymbol,mainPeriod,0);
   CurrentSL = stop_loss;
   CurrentTP = take_profit;
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(order_deviation);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   CurrentSignal=none;
   LastSignal=CurrentSignal;
   Strike=20;
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   breathLevel=breath;
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
   bool NC=IsNewCandle(TradeSymbol);

   int pos=PositionsTotal();
   double price_ask=SymbolInfoDouble(TradeSymbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(TradeSymbol,SYMBOL_BID);

   if(NC) CurrentSignal=GannStrategy(price_ask,price_bid);
//CurrentSignal=FiftyTwoHundred(price_ask,price_bid);

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
   if(pos<1) breathLevel=breath;
/* Comment("New Candle: ",NC,"\n","Work: ",(work && work_day ? "true":"false"),"\n","Signal: ",EnumToString(CurrentSignal),"\n","Last Sigal: ",EnumToString(LastSignal)
           ,"\n","Open Sigal: ",EnumToString(OpenSignal)
           ,"\n","Breath level: ",breathLevel);*/
   if(work==true && work_day==true && NC) // work enabled
     {
      if(LastSignal==buy)
        {
         StopLossByPivotPoint(price_ask,price_bid,mainPeriod,POSITION_TYPE_BUY);
         double VOL=calculateVolume(order_volume,CurrentSL,10);
         if(pos<1)
           {
            trade.Buy(VOL,TradeSymbol,price_ask,(price_ask-(CurrentSL*_Point)),(price_ask+(CurrentTP*_Point)),"");
            OpenSignal=buy;
           }
        }
      else
        {
         //CloseAllBuyPositions();
        }
      if(LastSignal==sell)
        {
         StopLossByPivotPoint(price_ask,price_bid,mainPeriod,POSITION_TYPE_SELL);
         double VOL=calculateVolume(order_volume,CurrentSL,10);
         if(pos<1)
           {
            trade.Sell(VOL,TradeSymbol,price_bid,(price_bid+(CurrentSL*_Point)),(price_bid-(CurrentTP*_Point)),"");
            OpenSignal=sell;
           }
        }
      else
        {
         //CloseAllSellPositions();
        }
     }
   if(LastSignal!=CurrentSignal) LastSignal=CurrentSignal;
   if(pos>0 && NC)
     {
      if(TrailingStopMode==MTFTS)
        {
         MultiTimeFrameCalculator(price_ask,price_bid);
        }
      else if(TrailingStopMode==STS)
        {
         SimpleTrailingStop(price_ask,price_bid);
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
double Stdev(double &data[])
  {
   double sum=0.0,mean,standardDeviation=0.0;
   int i;
   for(i=0; i<ArraySize(data);++i)
     {
      sum+=data[i];
     }
   mean=sum/ArraySize(data);
   for(i=0; i<ArraySize(data);++i)
      standardDeviation+=pow(data[i]-mean,2);
   return sqrt(standardDeviation / ArraySize(data));
  }
//+------------------------------------------------------------------+
double Stdev2(double data1,double data2)
  {
   double sum=0.0,mean,standardDeviation=0.0;
   sum=data1+data2;
   mean=sum/2;
   standardDeviation+=pow(data1-mean,2);
   standardDeviation+=pow(data2-mean,2);
   return sqrt(standardDeviation / 2);
  }
//+------------------------------------------------------------------+
signal GannStrategy(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   double GannColorArray[];
   double MACDArray[];

   int Gann=iCustom(_Symbol,period,"GannOP",period,iGann);
   int MACD=iMACD(_Symbol,period,MACD_FAST,MACD_PERIOD,MACD_SIGNAL,PRICE_CLOSE);

   CopyBuffer(MACD,0,0,3,MACDArray);
   CopyBuffer(Gann,4,0,1,GannColorArray);

   if(GannColorArray[0]==1 && MACDArray[0]>0)
     {
      return buy;
     }
   else if(GannColorArray[0]==2 && MACDArray[0]<0)
     {
      return sell;
     }
   return none;
  }
//+------------------------------------------------------------------+
signal FiftyTwoHundred(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   double ZigZagArray[];

   int ZigZag=iCustom(_Symbol,period,"ZigzagColor",period,12,5,3); 
    
   ArraySetAsSeries(ZigZagArray,true); 
   CopyBuffer(ZigZag,0,0,3,ZigZagArray);  
   
   double std=Stdev2(FiftyArray[1],TwoHundredArray[1]);
   if(FiftyArray[0]==0 && TwoHundredArray[0]==0) return none;
   if((ic>FiftyArray[1] && ic>TwoHundredArray[1]) && std<=0.00001)
     {
      return buy;
     }
   else if((ic<FiftyArray[0] && ic<TwoHundredArray[0]) && std<=0.00001)
     {
      return sell;
     }
   return none;
  }
//+------------------------------------------------------------------+
signal ZigZagStrength(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   double FiftyArray[],TwoHundredArray[];

   int Fifty=iMA(_Symbol,period,25,0,MODE_EMA,PRICE_CLOSE);
   int TwoHundred=iMA(_Symbol,period,50,0,MODE_EMA,PRICE_CLOSE);

   ArraySetAsSeries(FiftyArray,true);
   ArraySetAsSeries(TwoHundredArray,true);
   CopyBuffer(Fifty,0,0,3,FiftyArray);
   CopyBuffer(TwoHundred,0,0,3,TwoHundredArray);

   double ic = iClose(_Symbol,period,1);
   double std=Stdev2(FiftyArray[1],TwoHundredArray[1]);
   if(FiftyArray[0]==0 && TwoHundredArray[0]==0) return none;
   if((ic>FiftyArray[1] && ic>TwoHundredArray[1]) && std<=0.00001)
     {
      return buy;
     }
   else if((ic<FiftyArray[0] && ic<TwoHundredArray[0]) && std<=0.00001)
     {
      return sell;
     }
   return none;
  }
//+------------------------------------------------------------------+
void StopLossByPivotPoint(double Ask,double Bid,ENUM_TIMEFRAMES period,ENUM_POSITION_TYPE tp)
  {
   double iclose=iClose(TradeSymbol,period,1);
   double ihigh=iHigh(TradeSymbol,period,1);
   double ilow=iLow(TradeSymbol,period,1);
   double P,R1,R2,S1,S2;
   P=(ihigh+ilow+iclose)/3;
   R1 = (P*2)-ilow;
   R2 = P+(ihigh-ilow);
   S1 = (P*2)-ihigh;
   S2 = P-(ihigh-ilow);

   if(tp==POSITION_TYPE_SELL)
     {
      CurrentSL=MathAbs((R2-Bid)/_Point)+100;
      CurrentTP=MathAbs((S2-Bid)/_Point)+100;
     }
   else if(tp==POSITION_TYPE_BUY)
     {
      CurrentSL=MathAbs((Ask-S2)/_Point)+100;
      CurrentTP=MathAbs((Ask-R2)/_Point)+100;
     }
  }
//+------------------------------------------------------------------+
double SMA(double &CArray[],int length)
  {
   return ArraySum(CArray)/length;
  }
//+------------------------------------------------------------------+
double EMA(double &CArray[],int length)
  {
   static double ema;
   double k=2/(length+1);
   if(ema==0) ema=SMA(CArray,length);
   double cema=CArray[0]*k+ema*(1-k);
   ema=cema;
   return ema;
  }
//+------------------------------------------------------------------+
void GetRateByType(double &CArray[],processType pType,int length,ENUM_TIMEFRAMES period=PERIOD_M1)
  {
   MqlRates rates[];
   ArrayResize(rates,length);
   if(!CopyRates(AnalyseSymbol,period,0,length,rates)) return;
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
bool IsNewCandle(string symb)
  {
   if(iTime(symb,Period(),0)!=_lastBarTime)
     {
      _lastBarTime=iTime(symb,mainPeriod,0);

      return (true);
     }
   else
      return (false);
  }
//+------------------------------------------------------------------+
void MultiTimeFrameCalculator(double price_ask,double price_bid)
  {
   ENUM_TIMEFRAMES period_M1=PERIOD_M1;
   ENUM_TIMEFRAMES period_M5=PERIOD_M5;
   ENUM_TIMEFRAMES period_M30=PERIOD_M30;
   
   
   signal s_M1=ParabolicSAR(paraStep,paraMax,period_M1),
   s_M5=ParabolicSAR(paraStep,paraMax,period_M5),
   s_M30=ParabolicSAR(paraStep,paraMax,period_M30);

   if(s_M1==OpenSignal)
     {
      breathLevel+=BreathLevel_M1;
     }
   else if(s_M1!=none)
     {
      breathLevel/=BreathLevel_M1;
     }

   if(s_M5==OpenSignal)
     {
      breathLevel+=BreathLevel_M5;
     }
   else if(s_M5!=none)
     {
      breathLevel/=BreathLevel_M5;
     }

   if(s_M30==OpenSignal)
     {
      breathLevel+=BreathLevel_M30;
     }
   else if(s_M30!=none)
     {
      breathLevel/=BreathLevel_M30;
     }
   TrailingStop(price_ask,price_bid);
  }
//+------------------------------------------------------------------+
signal ParabolicSAR(double step,double maximum,ENUM_TIMEFRAMES period)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   double ParabArray[];

   int Parab=iCustom(_Symbol,period,"asar",0,PRICE_CLOSE,0.02,step,maximum,0,0);

   ArraySetAsSeries(ParabArray,true);
   CopyBuffer(Parab,4,0,3,ParabArray);
   if(ParabArray[0]==0 && ParabArray[1]==0) return none;
   if(ParabArray[0]==-1 && ParabArray[1]==-1 && ParabArray[2]==-1)
     {
      return buy;
     }
   else if(ParabArray[0]==1 && ParabArray[1]==1 && ParabArray[2]==1)
     {
      return sell;
     }
   return none;
  }
//+------------------------------------------------------------------+
void TrailingStop(double price_ask,double price_bid)
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
         double PositionPrice=PositionGetDouble(POSITION_PRICE_OPEN);
         double CPositionPrice=PositionGetDouble(POSITION_PRICE_CURRENT);
         datetime PositionTime=(datetime)PositionGetInteger(POSITION_TIME);
         ENUM_POSITION_TYPE tp=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         StopLossByPivotPoint(price_ask,price_bid,_Period,tp);
         double barNum=iBarShift(_Symbol,_Period,PositionTime); //OLD iBars
         /*double barNum=1;
         double barNumX = MathPow(iBarShift(_Symbol, _Period, PositionTime),2);
         double barNumY = MathPow(CPositionPrice-PositionPrice,2);
         barNum=MathSqrt(barNumX+barNumY);
         barNum=breathLevel/barNum;*/
        
         double mid=(1+2*barNum);
         double _MSL=breathLevel*(1+MathCos(MathPow(CurrentSL,mid)/mid));
         double _MPL=breathLevel*(1+MathCos(MathPow(CurrentTP,mid)/mid));
         double _SL=_MSL-(_MSL*0.2);
         double _TP=_MPL+(_MPL*0.5);
         
         if(tp==POSITION_TYPE_BUY)
           {
            double NewSL=NormalizeDouble(price_ask-(_SL*_Point),_Digits);
            double NewTP=NormalizeDouble(price_ask+(_TP*_Point),_Digits);
            if(NewSL>StopLossCorrente && NewTP>TakeProfitCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,NewTP))
                 {
                  //breathLevel+=1;
                  Print("ok");
                 }
               else
                 {
                  Print("error");
                 }
              }
           }
         else if(tp==POSITION_TYPE_SELL)
           {
            //double novoSL=NormalizeDouble(StopLossCorrente-stepTS,_Digits);
            double NewSL=NormalizeDouble(price_bid+(_SL*_Point),_Digits);
            double NewTP=NormalizeDouble(price_bid-(_TP*_Point),_Digits); 
            if(NewSL<StopLossCorrente && NewTP<TakeProfitCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,NewTP))
                 {
                  //breathLevel+=1;
                  Print("ok");
                 }
               else
                 {
                  Print("error");
                 }
              }
           }
        }
     }
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
         StopLossByPivotPoint(price_ask,price_bid,_Period,tp);
         int barNum=iBarShift(_Symbol,_Period,PositionTime);
         if(tp==POSITION_TYPE_BUY)
           {
            double NewSL=NormalizeDouble(price_ask-(100*_Point),_Digits);
            if(NewSL>StopLossCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,TakeProfitCorrente))
                 {
                 }
              }
           }
         else if(tp==POSITION_TYPE_SELL)
           {
            double NewSL=NormalizeDouble(price_bid+(100*_Point),_Digits);
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
