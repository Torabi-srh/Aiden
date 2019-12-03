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
enum processType {open,high,low,close};
enum enum_trailingStop {STS,MTFTS,NTS};
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

double LAST_TRADE_PROFIT=0;     // global variable
double GLOBAL_TRADE_PROFIT=0;     // global variable
double InitBalance=0;     // global variable  
double AchillesKnee=0;
double DLR=5,DMR=5,DHR=5;

int HW=0,HL=0,HR=50,SPHR=10;
int MW=0,ML=0,MR=40,SPMR=40;
int LW=0,LL=0,LR=10,SPLR=50;
double HP=0,MP=0,LP=0;
double HSP=0,LSP=0,MSP=0;
double MaxTP=20;

double HHC = 0.002;
double HHL = 0.004;
double HHH = 0.008;
CSortedMap<string,string>symbols;

int HeikenAshi;
//+---------------------------------------------+
int OnInit()
  {
   symbols.Add("high","EURUSD_i");
   symbols.Add("low","GBPUSD_i");
   symbols.Add("mid","EURJPY_i");
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(10);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
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
      string LAST_TRADE_SYMBOL=HistoryDealGetString(temp_Ticket,DEAL_SYMBOL);
      GLOBAL_TRADE_PROFIT+=LAST_TRADE_PROFIT;

      string LS,MS,HS;
      symbols.TryGetValue("low",LS);
      symbols.TryGetValue("high",HS);
      symbols.TryGetValue("mid",MS);

      if(LAST_TRADE_PROFIT>0)
        {
         if(LAST_TRADE_SYMBOL==LS)
           {
            LW++;
            LP+=LAST_TRADE_PROFIT;
           }
         if(LAST_TRADE_SYMBOL==MS)
           {
            MW++;
            MP+=LAST_TRADE_PROFIT;
           }
         if(LAST_TRADE_SYMBOL==HS)
           {
            HW++;
            HP+=LAST_TRADE_PROFIT;
           }
        }
      else
        {
         if(LAST_TRADE_SYMBOL==LS)
           {
            LL++;
            LP+=LAST_TRADE_PROFIT;
           }
         if(LAST_TRADE_SYMBOL==MS)
           {
            ML++;
            MP+=LAST_TRADE_PROFIT;
           }
         if(LAST_TRADE_SYMBOL==HS)
           {
            HL++;
            HP+=LAST_TRADE_PROFIT;
           }
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

   string LS,MS,HS;
   symbols.TryGetValue("low",LS);
   symbols.TryGetValue("high",HS);
   symbols.TryGetValue("mid",MS);

   double Hprice_ask=SymbolInfoDouble(HS,SYMBOL_ASK);
   double Hprice_bid=SymbolInfoDouble(HS,SYMBOL_BID);

   double Mprice_ask=SymbolInfoDouble(MS,SYMBOL_ASK);
   double Mprice_bid=SymbolInfoDouble(MS,SYMBOL_BID);

   double Lprice_ask=SymbolInfoDouble(LS,SYMBOL_ASK);
   double Lprice_bid=SymbolInfoDouble(LS,SYMBOL_BID);

   signal CurrentSignal=none;
   signal HCurrentSignal=none;
   signal LCurrentSignal=none;
   signal MCurrentSignal=none;

   if(NC) LCurrentSignal=Archer(LS,Hprice_ask,Hprice_bid);
   if(NC) HCurrentSignal=Archer(HS,Hprice_ask,Hprice_bid);
   if(NC) MCurrentSignal=Archer(MS,Hprice_ask,Hprice_bid);
   
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

   if(pos>0 && NC)
     {
      TrailingStop(Hprice_ask,Hprice_ask);
     }
   if(work==true && work_day==true && NC) // work enabled
     {
      if(pos<1)
        {
         if(CurrentSignal==buy)
           {
            double HSL,MSL,LSL;
            double HV,MV,LV;
            CSortedMap<string,double>ASL;
            CSortedMap<string,double>MVL;

            RSL(Hprice_ask,ASL);
            VSL(_symbol,MVL);

            ASL.TryGetValue("low",LSL);
            ASL.TryGetValue("mid",MSL);
            ASL.TryGetValue("high",HSL);
            MVL.TryGetValue("low",LV);
            MVL.TryGetValue("mid",MV);
            MVL.TryGetValue("high",HV);

            double LTP = MathRound(HHL/_Point);
            double MTP = MathRound(HHC/_Point);
            double HTP = MathRound(HHH/_Point);

            trade.Buy(MV,MS,Mprice_ask,Mprice_ask-MSL*_Point,Mprice_ask+MTP*_Point,"mid");
            trade.Buy(LV,LS,Lprice_ask,Lprice_ask-LSL*_Point,Lprice_ask+LTP*_Point,"low");
            trade.Buy(HV,HS,Hprice_ask,Hprice_ask-HSL*_Point,Hprice_ask+HTP*_Point,"high");
            OpenSignal=buy;
           }
        }
     }
  }
//+------------------------------------------------------------------+
signal Archer(string _symbol,double Ask,double Bid,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   int HighEMA=iMA(_symbol,_Period,86,0,MODE_EMA,PRICE_CLOSE);
   int LowEMA=iMA(_symbol,_Period,21,0,MODE_EMA,PRICE_CLOSE);
   int Momentum=iMomentum(_symbol,_Period,8,PRICE_CLOSE);
   HeikenAshi=iCustom(_symbol,_Period,"heiken_ashi_smoothed");
/*
   Close = (Open+High+Low+Close)/4
   Open = [Open (previous bar) + Close (previous bar)]/2
   High = Max (High,Open,Close)
   Low = Min (Low,Open, Close)
*/
   int Stochastic=iStochastic(_symbol,_Period,8,3,3,MODE_SMA,STO_CLOSECLOSE);

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

   if(HeikenAshiValue[0]==0)
     {
      if(LowEMAValue[2]<HighEMAValue[2] && LowEMAValue[0]>HighEMAValue[0])
        {
         if(MomentumValue[0]>100)
           {
            if(StochasticValue[0]>40 && StochasticValue[0]<StochasticSignal[0])
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
double normalizeVolume(string _symbol,double value)
  {
   double min = SymbolInfoDouble(_symbol, SYMBOL_VOLUME_MIN);
   double max = SymbolInfoDouble(_symbol, SYMBOL_VOLUME_MAX);
   double step= SymbolInfoDouble(_symbol,SYMBOL_VOLUME_STEP);

   if(value<0) value=order_volume;
   else if(value<min) value=min;
   else if(value>max) value=max;

   value=MathRound(value/step)*step;

   if(step>=0.1) value=NormalizeDouble(value,1);
   else value=NormalizeDouble(value,2);

   return value;
  }
//+------------------------------------------------------------------+
void TrailingStop(double price_ask,double price_bid)
  {

   double HeikenAshiValue[];
   ArraySetAsSeries(HeikenAshiValue,true);
   CopyBuffer(HeikenAshi,2,0,3,HeikenAshiValue);//low

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      ulong magic=PositionGetInteger(POSITION_MAGIC);
      if(magic==magic_number)//symbol==_Symbol &&
        {
         ulong PT=PositionGetInteger(POSITION_TICKET);
         datetime TM=PositionGetInteger(POSITION_TIME);
         double PRC=PositionGetDouble(POSITION_PRICE_OPEN);
         double CTP=PositionGetDouble(POSITION_TP);
         int start = iBarShift(symbol,_Period,TM);
         double THHC=0,THHL=0,THHH=0;
         for(int j=0;j<=start;j++)
           {
            THHC=MathMax(THHC, iClose(symbol,_Period,j));
            THHL=MathMax(THHL, iLow(symbol,_Period,j));
            THHH=MathMax(THHH, iHigh(symbol,_Period,j));
           }

         HHL = THHL-PRC;
         HHC = THHC-PRC;
         HHH = THHH-PRC;
         if(HHL<0) HHL = 0;
         if(HHC<0) HHC = 0;
         if(HHH<0) HHH = 0;

         long  SVL=SymbolInfoInteger(symbol,SYMBOL_TRADE_STOPS_LEVEL);
         double CSL=PositionGetDouble(POSITION_SL);
         ENUM_POSITION_TYPE tp=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
         if(tp==POSITION_TYPE_BUY)
           {
            if(AchillesKnee==0) AchillesKnee=HeikenAshiValue[0];
            double NSL=NormalizeDouble(CSL+(HeikenAshiValue[0]-AchillesKnee),_Digits);//NormalizeDouble(price_ask-(50*_Point),_Digits);
                                                                                      //if (SVL*_Point>NSL)return;
            if(NSL>CSL)
              {
               if(trade.PositionModify(PT,NSL,CTP))
                 {
                  AchillesKnee=HeikenAshiValue[0];
                  printf((string)PT+": Modified.");
                 }
              }
           }
         else if(tp==POSITION_TYPE_SELL)
           {
            double NSL=NormalizeDouble(price_bid+(50*_Point),_Digits);
            if(NSL<NSL)
              {

              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|          Volume Soroush lines                                    |
//+------------------------------------------------------------------+
void VSL(string _symbol,CSortedMap<string,double>&Risk)
  {
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double VVH=(_Point*(((HR*DHR*Balance)/10000)+((SPLR/100)*HP))),
   VVM=(_Point*(((MR*DMR*Balance)/10000)+((SPLR/100)*MP))),
   VVL=(_Point*(((LR*DLR*Balance)/10000)+((SPLR/100)*LP)));
/*
   while(VVH<0.01) VVH+=0.001;
   while(VVM<0.01) VVM+=0.001;
   while(VVL<0.01) VVL+=0.001;
   */
   VVH=normalizeVolume(_symbol,VVH);
   VVM=normalizeVolume(_symbol,VVM);
   VVL=normalizeVolume(_symbol,VVL);

   VVL=NormalizeDouble(VVL,_Digits);
   VVM=NormalizeDouble(VVM,_Digits);
   VVH=NormalizeDouble(VVH,_Digits);
   Risk.Add("high",VVH);
   Risk.Add("mid",VVM);
   Risk.Add("low",VVL);
  }
//+------------------------------------------------------------------+
//|          Risk Soroush lines                                      |
//+------------------------------------------------------------------+
void RSL(double In,CSortedMap<string,double>&Risk)
  {
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double rates[];
   GetRateByType(rates,low,500);
   CSortedMap<double,int>d;
   for(int i=0;i<500;i++)
     {
      if(d.ContainsKey(rates[i]))
        {
         int v;
         d.TryGetValue(rates[i],v);
         d.TrySetValue(rates[i],v+1);
        }
      else
        {
         d.Add(rates[i],1);
        }
     }

   double keys[];
   int values[];
   d.CopyTo(keys,values);

   int v0=values[0];
   int im=0;
   int I = ArrayBsearch(keys,In);
   for(int i=0;i<=I;i++)
     {
      if(v0<values[i])
        {
         v0=values[i];
         im=i;
        }
     }

   DHR+=((HW*HL)/1+HW+HL)-1;
   DMR+=((MW*ML)/1+MW+ML)-1;
   DLR+=((LW*LL)/1+LW+LL)-1;
   if(DHR<=0) DHR=1;
   if(DMR<=0) DMR=1;
   if(DLR<=0) DLR=1;
   double SLL=0,SLM=0,SLH=0;
   if(In<keys[im])
     {
      double NewSL=NormalizeDouble(In-(50*_Point),_Digits);
      SLL=NormalizeDouble((NewSL*(((LR*DLR*Balance)/10000)+1)),_Digits);
      SLM=NormalizeDouble((NewSL*(((MR*DMR*Balance)/10000)+1)),_Digits);
      SLH=NormalizeDouble((NewSL*(((HR*DHR*Balance)/10000)+1)),_Digits);
     }
   else
     {
      SLL=NormalizeDouble((keys[im]*(((LR*DLR*Balance)/10000)+1)),_Digits);
      SLM=NormalizeDouble((keys[im]*(((MR*DMR*Balance)/10000)+1)),_Digits);
      SLH=NormalizeDouble((keys[im]*(((HR*DHR*Balance)/10000)+1)),_Digits);
     }
   SLL=NormalizeDouble(SLL,_Digits);
   SLM=NormalizeDouble(SLM,_Digits);
   SLH=NormalizeDouble(SLH,_Digits);
   Risk.Add("high",SLH);
   Risk.Add("mid",SLM);
   Risk.Add("low",SLL);
  }
//+------------------------------------------------------------------+
void GetRateByType(double &CArray[],processType pType,int length,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
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
