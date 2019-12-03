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
input string  EAinputs="EA inputs";                                           // EA inputs
input bool     work_alt=true;                                                 // Work with a position in case of an opposite signal
input int      take_profit=14;                                                // Take Profit
input int      stop_loss=659;                                                  // Stop Loss
input long     magic_number=939393;                                            // Magic number
input double   order_volume=0.74;                                              // Lot size
input int      order_deviation=100;                                            // Deviation by position opening
input int      breath=55;                                                       // Breath between positions
//--- Bollinger Bands Strategy
input string  BollingerStrategy="Bollinger Bands Strategy";                   // Bollinger Bands Strategy
input bool     BollingerBandsStrategy=true;                                   // Enable/disable Bollinger Bands Strategy
input int      bands_period=11;                                                // Bollinger Bands period
input int      bands_shift=0;                                                  // Bollinger Bands shift
input double   bands_diviation=2;                                              // Bollinger Bands deviations
input double   div_work=12;                                                    // Deviation from signal
input double   div_signal=13;                                                  // Undervaluation of the main signal
//--- Trading timespan
input string  Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=8;                                                 // Trading start time
input char     time_h_stop=4;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday 
//--- RSI-Bollinger Bands Strategy
input string  RSIBollingerStrategy="RSI-Bollinger Bands Strategy";            // RSI-Bollinger Bands Strategy
input bool     RSIBollingerBandsStrategy=true;                                 // Enable/disable RSI-Bollinger Bands Strategy
input int      RSIlength=6;
input int      RSIoverSold=50;
input int      RSIoverBought=50;
input int      BBlength=200;
input int      BBmult=2;
//--- Multi TimeFrame TrailingStop
input string  MultiTimeFrameTrailingStop_="Multi TimeFrame TrailingStop";     // Multi TimeFrame TrailingStop
input bool     MultiTimeFrameTrailingStop=false;                                // Enable/disable Multi TimeFrame TrailingStop (if enable normal trailing stop enable automatically)
input int      BreathLevel_M5=16;                                               // 5 Minutes TimeFrame         
input int      BreathLevel_M10=39;                                              // 10 Minutes TimeFrame
input int      BreathLevel_M15=49;                                              // 15 Minutes TimeFrame
input int      BreathLevel_M30=73;                                             // 30 Minutes TimeFrame
//--- Normal TrailingStop
input string  NormalTrailingStop_="Normal TrailingStop";                      // Normal TrailingStop
input bool NormalTrailingStop=true;                                            // Enable/disable Multi TimeFrame TrailingStop

//--- Variable
double CurrentSL,CurrentTP;
MqlDateTime time_now_str;
datetime time_now_var;
datetime time_last_open;
int breathLevel=3;
CTrade trade;
int bb_handle;
double bb_base_line[3];
double bb_upper_line[3];
double bb_lower_line[3];
bool work_day=true;
double Strike;
double LAST_TRADE_PROFIT=0;     // global variable
double GLOBAL_TRADE_PROFIT=0;     // global variable
signal LastSignal;
signal CurrentSignal;
//+---------------------------------------------+
int OnInit()
  {
//---
   breathLevel=breath;
   time_last_open=TimeCurrent();
   CurrentSL = stop_loss;
   CurrentTP = take_profit;
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(order_deviation);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   CurrentSignal=none;
   Strike=20;
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
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

   if(pos>0 && (NormalTrailingStop || MultiTimeFrameTrailingStop))
     {
      TrailingStop(price_ask,price_bid);
     }
   signal s1=none,s2=none,s3=none;
   s1=(BollingerBandsStrategy?BollingerBandSignal(price_bid,price_ask):none);
   s2=(RSIBollingerBandsStrategy?SorSignal(price_ask,price_bid, _Period):none);
   s3=(MultiTimeFrameTrailingStop?MultiTimeFrameCalculator(price_ask,price_bid):none);
   int _Buy=0,_Sell=0;
   _Buy += (s1==buy?1:0);
   _Buy -= (s1==sell?-1:0);
   _Buy += (s2==buy?1:0);
   _Buy -= (s2==sell?-1:0);
   _Buy += (s3==buy?1:0);
   _Buy -= (s3==sell?-1:0);

   CurrentSignal=SorSignal(price_ask,price_bid,PERIOD_M1);
   double VOL=order_volume;
   double CuH=MathAbs(time_now_var-time_last_open)/60;
   if(pos==0 && CuH>breathLevel)
     {
      breathLevel=breath;
     }
   if(work==true && work_day==true) // work enabled
     {
      if(pos<1 && CuH>=breathLevel)
        {
         if(CurrentSignal==sell) // sell signal
           {
            VOL=calculateVolume(VOL,(price_bid+(CurrentSL*_Point)),Strike);
            trade.Sell(VOL,_Symbol,price_bid,(price_bid+(CurrentSL*_Point)),(price_bid-(CurrentTP*_Point)),"");
            LastSignal=sell;
            time_last_open=time_now_var;
           }
         if(CurrentSignal==buy) // buy signal
           {
            VOL=calculateVolume(VOL,(price_ask-(CurrentSL*_Point)),Strike);
            trade.Buy(VOL,_Symbol,price_ask,(price_ask-(CurrentSL*_Point)),(price_ask+(CurrentTP*_Point)),"");
            LastSignal=buy;
            time_last_open=time_now_var;
           }
        }
      if(pos>0 && work_alt==true && CuH>=breathLevel)
        {
         if(trade.RequestType()==ORDER_TYPE_BUY) // if there was a buy order before that
            if(CurrentSignal==sell) // sell signal
              {
               VOL=calculateVolume(VOL,(price_bid+(CurrentSL*_Point)),Strike);
               if (!NormalTrailingStop) trade.PositionClose(_Symbol,order_deviation);
               trade.Sell(VOL,_Symbol,price_bid,(price_bid+(CurrentSL*_Point)),(price_bid-(CurrentTP*_Point)),"");
               LastSignal=sell;
               time_last_open=time_now_var;
              }
         if(trade.RequestType()==ORDER_TYPE_SELL) // if there was a sell order before that
            if(CurrentSignal==buy) // buy signal
              {
               VOL=calculateVolume(VOL,(price_ask-(CurrentSL*_Point)),Strike);
               if (!NormalTrailingStop) trade.PositionClose(_Symbol,order_deviation);
               trade.Buy(VOL,_Symbol,price_ask,(price_ask-(CurrentSL*_Point)),(price_ask+(CurrentTP*_Point)),"");
               LastSignal=buy;
               time_last_open=time_now_var;
              }
        }
     }
   else
     {
      if(pos>0 && CuH>=breathLevel)
        {
         if (!NormalTrailingStop) trade.PositionClose(_Symbol,order_deviation);
         LastSignal=none;
        }
     }
  }
//+------------------------------------------------------------------+
signal MultiTimeFrameCalculator(double price_ask,double price_bid)
  {
   ENUM_TIMEFRAMES period=PERIOD_M1;
   ENUM_TIMEFRAMES period_M5=PERIOD_M5;
   ENUM_TIMEFRAMES period_M10=PERIOD_M10;
   ENUM_TIMEFRAMES period_M15=PERIOD_M15;
   ENUM_TIMEFRAMES period_M30=PERIOD_M30;

   signal s1gnal=SorSignal(price_ask,price_bid,period),
   s_M5=SorSignal(price_ask,price_bid,period_M5),
   s_M10=SorSignal(price_ask,price_bid,period_M10),
   s_M15=SorSignal(price_ask,price_bid,period_M15),
   s_M30=SorSignal(price_ask,price_bid,period_M30);

   if(s_M5==LastSignal)
     {
      breathLevel+=BreathLevel_M5;
     }
   else
     {
      breathLevel-=BreathLevel_M5;
     }

   if(s_M10==LastSignal)
     {
      breathLevel+=BreathLevel_M10;
     }
   else
     {
      breathLevel-=BreathLevel_M10;
     }

   if(s_M15==LastSignal)
     {
      breathLevel+=BreathLevel_M15;
     }
   else
     {
      breathLevel-=BreathLevel_M15;
     }

   if(s_M30==LastSignal)
     {
      breathLevel+=BreathLevel_M30;
     }
   else
     {
      breathLevel-=BreathLevel_M30;
     }

   return s1gnal;
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
//|                                                                  |
//+------------------------------------------------------------------+
signal SorSignal(double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_M1)
  {
///////////// RSI
///////////// Bollinger Bands
   processType price=close;
   double vrsi=RSI(RSIlength,period);
   double BBArray[];
   GetRateByType(BBArray,price,BBlength,period);
   double BBbasis=SMA(BBArray,BBlength);
   double BBdev=BBmult*calculateSD(BBArray);
   double BBupper = BBbasis + BBdev;
   double BBlower = BBbasis - BBdev;

   double source=iClose(_Symbol,period,0);
   bool buyEntry=source>BBlower?true:false;
   bool sellEntry=source<BBupper?true:false;

   if((vrsi>RSIoverSold) && buyEntry)
     {
      CurrentSL=MathAbs((Ask-BBlower)/_Point);
      CurrentTP=MathAbs((Ask-BBupper)/_Point);
      return buy;
     }
   if((vrsi<RSIoverBought) && sellEntry)
     {
      CurrentSL=MathAbs((BBupper-Bid)/_Point);
      CurrentTP=MathAbs((BBlower-Bid)/_Point);
      return sell;
     }

   return none;
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
signal BollingerBandSignal(double price_bid,double price_ask)
  {
   bb_handle=iBands(_Symbol,_Period,bands_period,bands_shift,bands_diviation,PRICE_CLOSE);       // find out the Bollinger Bands handle
   int i_bl=CopyBuffer(bb_handle,0,0,3,bb_base_line);
   int i_ul=CopyBuffer(bb_handle,1,0,3,bb_upper_line);
   int i_ll=CopyBuffer(bb_handle,2,0,3,bb_lower_line);
   if(i_bl==-1 || i_ul==-1 || i_ll==-1)
     {
      Alert("Error of copy iBands: base line=",i_bl,", upper band=",i_ul,", lower band=",i_ll);
      return none;
     } // check the copied data

   if((price_ask-(div_signal*_Point))>=bb_upper_line[2]-(div_work*_Point) && (price_ask-(div_signal*_Point))<=bb_upper_line[2]+(div_work*_Point)) // sell signal
     {
      return sell;
     }

   if((price_bid+(div_signal*_Point))<=bb_lower_line[2]+(div_work*_Point) && (price_bid+(div_signal*_Point))>=bb_lower_line[2]-(div_work*_Point)) // buy signal
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
      if(symbol==_Symbol && magic==magic_number)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double StopLossCorrente=PositionGetDouble(POSITION_SL);
         double TakeProfitCorrente=PositionGetDouble(POSITION_TP);
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            //double novoSL=NormalizeDouble(StopLossCorrente+stepTS,_Digits);
            double NewSL=NormalizeDouble(price_ask-((CurrentSL+breathLevel)*_Point),_Digits);
            double NewTP=NormalizeDouble(price_ask+((CurrentTP+breathLevel)*_Point),_Digits);
            if(NewSL>StopLossCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,NewTP))
                 {
                  breathLevel+=1;
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
            double NewSL=NormalizeDouble(price_bid+((CurrentSL+breathLevel)*_Point),_Digits);
            double NewTP=NormalizeDouble(price_bid-((CurrentTP+breathLevel)*_Point),_Digits);
            if(NewSL<StopLossCorrente)
              {
               if(trade.PositionModify(PositionTicket,NewSL,NewTP))
                 {
                  breathLevel+=1;
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
double normalizeVolume(double value)
  {
   double min = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(Symbol(), SYMBOL_VOLUME_MAX);
   double step= SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
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
