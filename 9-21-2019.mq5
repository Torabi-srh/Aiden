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
   symbols.Add("low","EURCAD_i");
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
   string LS,MS,HS;
   symbols.TryGetValue("low",LS);
   symbols.TryGetValue("high",HS);
   symbols.TryGetValue("mid",MS);

   double Hprice_bid=SymbolInfoDouble(HS,SYMBOL_BID);
   double Lprice_bid=SymbolInfoDouble(LS,SYMBOL_BID);
   double Mprice_bid=SymbolInfoDouble(MS,SYMBOL_BID);

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

   if(NC) LCurrentSignal=Archer(LS);
   if(NC) HCurrentSignal=Archer(HS);
   if(NC) MCurrentSignal=Archer(MS);

   if(LCurrentSignal==buy || HCurrentSignal==buy || MCurrentSignal==buy)
     {
      CurrentSignal=buy;
     }
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
      TrailingStop();
     }
   if(work==true && work_day==true && NC) // work enabled
     {
      if(pos<1)
        {
         if(CurrentSignal==buy)
           {
            double h_point=SymbolInfoDouble(HS,SYMBOL_POINT);
            int h_digits=(int)SymbolInfoInteger(HS,SYMBOL_DIGITS);
            double l_point=SymbolInfoDouble(LS,SYMBOL_POINT);
            int l_digits=(int)SymbolInfoInteger(LS,SYMBOL_DIGITS);
            double m_point=SymbolInfoDouble(MS,SYMBOL_POINT);
            int m_digits=(int)SymbolInfoInteger(MS,SYMBOL_DIGITS);

            double HHSL,HMSL,HLSL;
            double HHV,HMV,HLV;

            double LHSL,LMSL,LLSL;
            double LHV,LMV,LLV;

            double MHSL,MMSL,MLSL;
            double MHV,MMV,MLV;

            CSortedMap<string,double>HASL;
            CSortedMap<string,double>HMVL;
            CSortedMap<string,double>MASL;
            CSortedMap<string,double>MMVL;
            CSortedMap<string,double>LASL;
            CSortedMap<string,double>LMVL;

            RSL(HS,Hprice_ask,HASL);
            VSL(HS,HMVL);

            RSL(LS,Lprice_ask,LASL);
            VSL(LS,LMVL);

            RSL(MS,Mprice_ask,MASL);
            VSL(MS,MMVL);

            HASL.TryGetValue("low",HLSL);
            HASL.TryGetValue("mid",HMSL);
            HASL.TryGetValue("high",HHSL);
            HMVL.TryGetValue("low",HLV);
            HMVL.TryGetValue("mid",HMV);
            HMVL.TryGetValue("high",HHV);

            MASL.TryGetValue("low",MLSL);
            MASL.TryGetValue("mid",MMSL);
            MASL.TryGetValue("high",MHSL);
            MMVL.TryGetValue("low",MLV);
            MMVL.TryGetValue("mid",MMV);
            MMVL.TryGetValue("high",MHV);

            LASL.TryGetValue("low",LLSL);
            LASL.TryGetValue("mid",LMSL);
            LASL.TryGetValue("high",LHSL);
            LMVL.TryGetValue("low",LLV);
            LMVL.TryGetValue("mid",LMV);
            LMVL.TryGetValue("high",LHV);

            double LTP = MathRound(HHL/l_point);
            double MTP = MathRound(HHC/m_point);
            double HTP = MathRound(HHH/h_point);

            double LSL = LLSL;
            double MSL = MMSL;
            double HSL = HHSL;

            LTP=Lprice_ask+LTP*l_point;
            MTP=Mprice_ask+MTP*m_point;
            HTP=Hprice_ask+HTP*h_point;

            double l_stoplevel=(double)SymbolInfoInteger(LS,SYMBOL_TRADE_STOPS_LEVEL);
            double h_stoplevel=(double)SymbolInfoInteger(HS,SYMBOL_TRADE_STOPS_LEVEL);
            double m_stoplevel=(double)SymbolInfoInteger(MS,SYMBOL_TRADE_STOPS_LEVEL);

            l_stoplevel = Lprice_ask-l_stoplevel*l_point;
            m_stoplevel = Mprice_ask-m_stoplevel*m_point;
            h_stoplevel = Hprice_ask-h_stoplevel*h_point;

            if(MSL>m_stoplevel) MSL = m_stoplevel;
            if(LTP>l_stoplevel) LSL = l_stoplevel;
            if(HSL>h_stoplevel) HSL = h_stoplevel;

            if(Mprice_ask-Mprice_ask*0.1>MSL) MSL = Mprice_ask-Mprice_ask*0.1;
            if(Hprice_ask-Hprice_ask*0.1>HSL) HSL = Hprice_ask-Hprice_ask*0.1;
            if(Lprice_ask-Lprice_ask*0.1>LSL) LSL = Lprice_ask-Lprice_ask*0.1;

            MSL = NormalizeDouble(MSL, m_digits);
            LSL = NormalizeDouble(LSL, l_digits);
            HSL = NormalizeDouble(HSL, h_digits);
            MTP = NormalizeDouble(MTP, m_digits);
            LTP = NormalizeDouble(LTP, l_digits);
            HTP = NormalizeDouble(HTP, h_digits);

            trade.Buy(MMV, MS, Mprice_ask, MSL, MTP,"mid");
            trade.Buy(LLV, LS, Lprice_ask, LSL, LTP,"low");
            trade.Buy(HHV, HS, Hprice_ask, HSL, HTP,"high");
            OpenSignal=buy;
           }
        }
     }
  }
//+------------------------------------------------------------------+
signal Archer(string _symbol,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   int HighEMA=iMA(_symbol,period,86,0,MODE_EMA,PRICE_CLOSE);//86
   int LowEMA=iMA(_symbol,period,21,0,MODE_EMA,PRICE_CLOSE);//21
   int Momentum=iMomentum(_symbol,period,8,PRICE_CLOSE);
   HeikenAshi=iCustom(_symbol,period,"heiken_ashi_smoothed");
/*
   Close = (Open+High+Low+Close)/4
   Open = [Open (previous bar) + Close (previous bar)]/2
   High = Max (High,Open,Close)
   Low = Min (Low,Open, Close)
*/
   int Stochastic=iStochastic(_symbol,period,8,3,3,MODE_SMA,STO_CLOSECLOSE);

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
void TrailingStop(ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   string LS,MS,HS;
   symbols.TryGetValue("low",LS);
   symbols.TryGetValue("high",HS);
   symbols.TryGetValue("mid",MS);

   double l_point=SymbolInfoDouble(LS,SYMBOL_POINT);
   int l_digits=(int)SymbolInfoInteger(LS,SYMBOL_DIGITS);
   double h_point=SymbolInfoDouble(HS,SYMBOL_POINT);
   int h_digits=(int)SymbolInfoInteger(HS,SYMBOL_DIGITS);
   double m_point=SymbolInfoDouble(MS,SYMBOL_POINT);
   int m_digits=(int)SymbolInfoInteger(MS,SYMBOL_DIGITS);

   int _digits=h_digits;
   double Hprice_ask=SymbolInfoDouble(HS,SYMBOL_ASK);
   double Hprice_bid=SymbolInfoDouble(HS,SYMBOL_BID);

   double Mprice_ask=SymbolInfoDouble(MS,SYMBOL_ASK);
   double Mprice_bid=SymbolInfoDouble(MS,SYMBOL_BID);

   double Lprice_ask=SymbolInfoDouble(LS,SYMBOL_ASK);
   double Lprice_bid=SymbolInfoDouble(LS,SYMBOL_BID);

   double HeikenAshiValue[];
   ArraySetAsSeries(HeikenAshiValue,true);
   CopyBuffer(HeikenAshi,2,0,3,HeikenAshiValue);//low

   for(int i=PositionsTotal()-1; i>=0; i--)
     {
      string symbol=PositionGetSymbol(i);
      ulong magic=PositionGetInteger(POSITION_MAGIC);
      if(magic==magic_number)//symbol==_Symbol &&
        {
         if(symbol==LS) _digits=l_digits;
         else if(symbol==MS) _digits=m_digits;
         else if(symbol==HS) _digits=h_digits;

         ulong PT=PositionGetInteger(POSITION_TICKET);
         datetime TM=(datetime)PositionGetInteger(POSITION_TIME);
         double PRC=PositionGetDouble(POSITION_PRICE_OPEN);
         double CTP=PositionGetDouble(POSITION_TP);
         int start = iBarShift(symbol,period,TM);
         double THHC=0,THHL=0,THHH=0;
         for(int j=0;j<=start;j++)
           {
            THHC=MathMax(THHC, iClose(symbol,period,j));
            THHL=MathMax(THHL, iLow(symbol,period,j));
            THHH=MathMax(THHH, iHigh(symbol,period,j));
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
            double NSL=NormalizeDouble(CSL+(HeikenAshiValue[0]-AchillesKnee),_digits);//NormalizeDouble(price_ask-(50*_Point),_Digits);
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
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|          Volume Soroush lines                                    |
//+------------------------------------------------------------------+
void VSL(string _symbol,CSortedMap<string,double>&Risk)
  {
   double _point=SymbolInfoDouble(_symbol,SYMBOL_POINT);
   int _digits=(int)SymbolInfoInteger(_symbol,SYMBOL_DIGITS);
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double VVH=(_point*(((HR*DHR*Balance)/10000)+((SPLR/100)*HP))),
   VVM=(_point*(((MR*DMR*Balance)/10000)+((SPLR/100)*MP))),
   VVL=(_point*(((LR*DLR*Balance)/10000)+((SPLR/100)*LP)));
/*
   while(VVH<0.01) VVH+=0.001;
   while(VVM<0.01) VVM+=0.001;
   while(VVL<0.01) VVL+=0.001;
   */
   VVH=normalizeVolume(_symbol,VVH);
   VVM=normalizeVolume(_symbol,VVM);
   VVL=normalizeVolume(_symbol,VVL);

   VVL=NormalizeDouble(VVL,_digits);
   VVM=NormalizeDouble(VVM,_digits);
   VVH=NormalizeDouble(VVH,_digits);
   Risk.Add("high",VVH);
   Risk.Add("mid",VVM);
   Risk.Add("low",VVL);
  }
//+------------------------------------------------------------------+
//|          Risk Soroush lines                                      |
//+------------------------------------------------------------------+
void RSL(string _symbol,double In,CSortedMap<string,double>&Risk)
  {
   double Balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double _point=SymbolInfoDouble(_symbol,SYMBOL_POINT);
   int _digits=(int)SymbolInfoInteger(_symbol,SYMBOL_DIGITS);
   double rates[];
   GetRateByType(rates,low,1000,_symbol);
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
      double NewSL=NormalizeDouble(In-(50*_point),_digits);
      SLL=NormalizeDouble((NewSL+((((LR+DLR)*Balance)/10000)+1)*_point),_digits);
      SLM=NormalizeDouble((NewSL+((((MR+DMR)*Balance)/10000)+1)*_point),_digits);
      SLH=NormalizeDouble((NewSL+((((HR+DHR)*Balance)/10000)+1)*_point),_digits);
     }
   else
     {
      SLL=NormalizeDouble((keys[im]-((((LR+DLR)*Balance)/10000)+1)*_point),_digits);
      SLM=NormalizeDouble((keys[im]-((((MR+DMR)*Balance)/10000)+1)*_point),_digits);
      SLH=NormalizeDouble((keys[im]-((((HR+DHR)*Balance)/10000)+1)*_point),_digits);
     }
   SLL=NormalizeDouble(SLL,_digits);
   SLM=NormalizeDouble(SLM,_digits);
   SLH=NormalizeDouble(SLH,_digits);
   Risk.Add("high",SLH);
   Risk.Add("mid",SLM);
   Risk.Add("low",SLL);
  }
//+------------------------------------------------------------------+
void GetRateByType(double &CArray[],processType pType,int length,string _symbol,ENUM_TIMEFRAMES period=PERIOD_CURRENT)
  {
   if(period==PERIOD_CURRENT)period=_Period;
   MqlRates rates[];
   ArrayResize(rates,length);
   if(!CopyRates(_symbol,period,0,length,rates)) return;
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
