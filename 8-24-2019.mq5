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

//--- RSI-Bollinger Bands Strategy
input string   RSIBollingerStrategy="RSI-Bollinger Bands Strategy";            // RSI-Bollinger Bands Strategy
input int      RSIlength=9;                                                   // RSI Period
input int      RSIoverSold=25;                                                // RSI Down Level
input int      RSIoverBought=75;                                              // RSI Upper Level
input int      BBlength=200;                                                  // Bollinger Bands Period
input int      BBmult=2;                                                      // Bollinger Bands deviation 

//--- Multi TimeFrame TrailingStop
input string   MultiTimeFrameTrailingStop_="Multi TimeFrame TrailingStop";     // Multi TimeFrame TrailingStop
input bool     MultiTimeFrameTrailingStop=true;                                // Enable/disable Multi TimeFrame TrailingStop (if enable normal trailing stop enable automatically)
input double      breath=113;                                                       // Breath between positions
input int      BreathLevel_M1=389;                                               // 1 Minutes TimeFrame     
input int      BreathLevel_M5=157;                                               // 5 Minutes TimeFrame         
input int      BreathLevel_M10=352;                                              // 10 Minutes TimeFrame
input int      BreathLevel_M15=38;                                              // 15 Minutes TimeFrame
input int      BreathLevel_M30=385;                                             // 30 Minutes TimeFrame

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
   int bsad=iMA(AnalyseSymbol,PERIOD_D1,50,0,MODE_EMA,PRICE_CLOSE);
   int bsae=iMA(AnalyseSymbol,PERIOD_D1,200,0,MODE_EMA,PRICE_CLOSE);
//--- 
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
   
//---

    bsad=iMA(AnalyseSymbol,PERIOD_D1,50,0,MODE_EMA,PRICE_CLOSE);
    bsae=iMA(AnalyseSymbol,PERIOD_D1,200,0,MODE_EMA,PRICE_CLOSE);
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
   CurrentSignal=BBRSISignal(price_ask,price_bid,mainPeriod);
   FiftyTwoHundred(price_ask,price_bid);

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
         double VOL=calculateVolume(order_volume,CurrentSL,5);
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
         double VOL=calculateVolume(order_volume,CurrentSL,5);
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
   if(pos>0 && MultiTimeFrameTrailingStop && NC) MultiTimeFrameCalculator(price_ask,price_bid);
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

   double iclose=iClose(AnalyseSymbol,period,1);
   double ihigh=iHigh(AnalyseSymbol,period,1);
   double ilow=iLow(AnalyseSymbol,period,1);

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
signal FiftyTwoHundred(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_D1)
  {
   processType price=close;

   double BBArray[];
   GetRateByType(BBArray,price,50,period);
   double ema=EMA(BBArray,50);
   double ema2=EMA(BBArray,200);
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
   return;
   ENUM_TIMEFRAMES period_M1=PERIOD_M1;
   ENUM_TIMEFRAMES period_M5=PERIOD_M5;
   ENUM_TIMEFRAMES period_M10=PERIOD_M10;
   ENUM_TIMEFRAMES period_M15=PERIOD_M15;
   ENUM_TIMEFRAMES period_M30=PERIOD_M30;
   signal s_M1=ParabolicSAR(5,period_M1),
   s_M5=none,//ParabolicSAR(5,period_M5),
   s_M10=none,//ParabolicSAR(5,period_M10),
   s_M15=none,//ParabolicSAR(5,period_M15),
   s_M30=none;//ParabolicSAR(5,period_M30);

   if(s_M1==OpenSignal)
     {
      breathLevel+=MathPow(BreathLevel_M1,1.5);
     }
   else if(s_M1!=none)
     {
      breathLevel-=MathPow(BreathLevel_M1,2);
     }

// madrid-dobai- sql kole hotel ha - qiyami
// log api method jadid

   if(s_M5==OpenSignal)
     {
      breathLevel+=BreathLevel_M5;
     }
   else if(s_M5!=none)
     {
      breathLevel-=MathPow(BreathLevel_M5,2);
     }

   if(s_M10==OpenSignal)
     {
      breathLevel+=BreathLevel_M10;
     }
   else if(s_M5!=none)
     {
      breathLevel-=MathPow(BreathLevel_M10,2);
     }

   if(s_M15==OpenSignal)
     {
      breathLevel+=BreathLevel_M15;
     }
   else if(s_M5!=none)
     {
      breathLevel-=MathPow(BreathLevel_M15,2);
     }

   if(s_M30==OpenSignal)
     {
      breathLevel+=BreathLevel_M30;
     }
   else if(s_M5!=none)
     {
      breathLevel-=MathPow(BreathLevel_M30,2);
     }
   TrailingStop(price_ask,price_bid);
  }
//+------------------------------------------------------------------+
signal ParabolicSAR(int length,ENUM_TIMEFRAMES period)
  {
   double iaf=0.02,maxaf=0.2;
   double psarbull[],psarbear[],iclose[],ihigh[],ilow[],psar[];
   ArrayResize(psarbull,length);
   ArrayResize(psarbear,length);
   GetRateByType(psar,close,length,period);
   GetRateByType(iclose,close,length,period);
   GetRateByType(ihigh,high,length,period);
   GetRateByType(ilow,low,length,period);

   bool bull=true;
   double  af=iaf,
   ep = ilow[0],
   hp = ihigh[0],
   lp = ilow[0];

   for(int i=2;i<length;i++)
     {
      if(bull)
         psar[i]=psar[i-1]+af*(hp-psar[i-1]);
      else
         psar[i]=psar[i-1]+af*(lp-psar[i-1]);
      bool reverse=false;
      if(bull)
        {
         if(ilow[i]<psar[i])
           {
            bull=false;
            reverse = true;
            psar[i] = hp;
            lp = ilow[i];
            af = iaf;
           }
        }
      else
        {
         if(ihigh[i]>psar[i])
           {
            bull=true;
            reverse = true;
            psar[i] = lp;
            hp = ihigh[i];
            af = iaf;
           }
        }

      if(!reverse)
        {
         if(bull)
           {
            if(ihigh[i]>hp)
              {
               hp = ihigh[i];
               af = MathMin(af + iaf, maxaf);
              }
            if(ilow[i-1]<psar[i])
               psar[i]=ilow[i-1];
            if(ilow[i-2]<psar[i])
               psar[i]=ilow[i-2];
           }
         else
           {
            if(ilow[i]<lp)
              {
               lp = ilow[i];
               af = MathMin(af + iaf, maxaf);
              }
            if(ihigh[i-1]>psar[i])
               psar[i]=ihigh[i-1];
            if(ihigh[i-2]>psar[i])
               psar[i]=ihigh[i-2];
           }
         if(bull)
            psarbull[i]=psar[i];
         else
            psarbear[i]=psar[i];
        }
     }

   double iclosez=iClose(AnalyseSymbol,period,1);
   double ihighz=iHigh(AnalyseSymbol,period,1);
   double ilowz=iLow(AnalyseSymbol,period,1);
   if(iclosez<psar[length-1])
     {
      return sell;
     }
   if(iclosez>psar[length-1])
     {
      return buy;
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
         double _MSL=CurrentSL+breathLevel;
         double _MPL=CurrentTP+(breathLevel/2);
         double _SL=_MSL-(_MSL*0.2);
         double _TP=_MPL+(_MPL*0.5);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            //double novoSL=NormalizeDouble(StopLossCorrente+stepTS,_Digits);
            double NewSL=NormalizeDouble(price_ask-(_SL*_Point),_Digits);
            double NewTP=NormalizeDouble(price_ask+(_TP*_Point),_Digits);
            if(NewSL>StopLossCorrente || 1==1)
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
         else if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
           {
            //double novoSL=NormalizeDouble(StopLossCorrente-stepTS,_Digits);
            double NewSL=NormalizeDouble(price_bid+(_SL*_Point),_Digits);
            double NewTP=NormalizeDouble(price_bid-(_TP*_Point),_Digits);
            if(NewSL<StopLossCorrente || 1==1)
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
