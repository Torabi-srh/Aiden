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
CisNewBar current_chart2;
//+---------------------
enum signal {buy,sell,none,closeBuy,closeSell};
//--- EA inputs
input string   EAinputs="EA inputs";                                           // EA inputs
input double   order_volume=0.1;                                              // Lot size
input int   POSITIONS=1;
input double   MaximumRisk_=0.01;                                               // Maximum Risk
//--- Trading timespan
input string   Tradingtimespan="Trading timespan";                             // Trading timespan
input char     time_h_start=1;                                                 // Trading start time
input char     time_h_stop=23;                                                 // Trading stop time
input bool     mon=true;                                                       // Work on Monday
input bool     tue=true;                                                      // Work on Tuesday
input bool     wen=true;                                                       // Work on Wednesday
input bool     thu=true;                                                       // Work on Thursday
input bool     fri=true;                                                       // Work on Friday
input string InpFileName="optimize.csv";  // optimize file name
input int DPO=0;//Useless value for optimize dynamic program

double cvolumeB=0.0;
double cvolumeS=0.0;
double MaximumRisk=0.0;
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
CTrade trade2;
signal OpenSignal;
bool work_day=true;
double InitBalance;
double OPZ[51];
int TradePerDay=0;
MqlDateTime lastOptimize;
CArrayList<ulong>oList;
int CIN=14;
int SL=100,TP=100;
//+---------------------------------------------+
int OnInit()
  {
   if(false==ReadFileToArrayCSV(InpFileName,OPZ))
     {
      for(int i=0; i<50; i++)
        {
         OPZ[i]=1;
        }
     }
   OPZ[26]+=2;
   MaximumRisk=MaximumRisk_;
   TimeToStruct(TimeCurrent(),lastOptimize);
   Optimize();
   CINSelect();
   cvolumeB=lotsOptimized(MaximumRisk,order_volume);
   cvolumeS=cvolumeB;
   trade.SetExpertMagicNumber(939393);
   trade2.SetExpertMagicNumber(46);
   InitBalance=AccountInfoDouble(ACCOUNT_BALANCE);
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
bool ReadFileToArrayCSV(string FileName,double &Lines[])
  {
   ResetLastError();
   int h=FileOpen(FileName,FILE_READ|FILE_CSV,";");
   if(h==INVALID_HANDLE)
     {
      int ErrNum=GetLastError();
      printf("Error opening file %s # %i",FileName,ErrNum);
      return(false);
     }

   while(!FileIsEnding(h))
     {
      int key=(int)FileReadString(h);
      while(!FileIsLineEnding(h))
        {
         double value=(double)FileReadString(h);
         Lines[key]=value;
        }
     }
   FileClose(h);
   return(true);
  }
//+------------------------------------------------------------------+
void  OnDeinit(const int  reason)
  {
   WriteToFile();
  }
//+------------------------------------------------------------------+
void WriteToFile()
  {
   int file_handle=FileOpen(InpFileName,FILE_WRITE|FILE_CSV,";");
   if(file_handle!=INVALID_HANDLE)
     {
      PrintFormat("%s file is available for writing",InpFileName);
      PrintFormat("File path: %s\\Files\\",TerminalInfoString(TERMINAL_DATA_PATH));
      for(int i=0; i<ArraySize(OPZ); i++)
         FileWrite(file_handle,i,OPZ[i]);
      FileClose(file_handle);
      PrintFormat("Data is written, %s file is closed",InpFileName);
     }
   else
      PrintFormat("Failed to open %s file, Error code = %d",InpFileName,GetLastError());
  }
//+------------------------------------------------------------------+
void Optimize()
  {
   MqlDateTime currentOptimize;
   TimeToStruct(TimeCurrent(),currentOptimize);
   if(TradePerDay==0)
      return;
   if(currentOptimize.hour!=0)
      return;
   /*if(currentOptimize.day_of_year>lastOptimize.day_of_year+1) return;*/
   HistorySelect(0,TimeCurrent());
   if(HistoryDealsTotal()<50)
      return;
   double sdprofit=0;
   for(int i=HistoryDealsTotal()-1; i>=0; i--)
     {
      ulong dticket=HistoryDealGetTicket(i);
      if(oList.Contains(dticket))
         continue;
      else
         oList.Add(dticket);
      long dmagic=HistoryDealGetInteger(dticket,DEAL_MAGIC);
      double dprofit=HistoryDealGetDouble(dticket,DEAL_PROFIT);
      ENUM_DEAL_ENTRY dentry=(ENUM_DEAL_ENTRY)HistoryDealGetInteger(dticket,DEAL_ENTRY);
      datetime dtime=(datetime)HistoryDealGetInteger(dticket,DEAL_TIME);
      ENUM_DEAL_TYPE dtype=(ENUM_DEAL_TYPE)HistoryDealGetInteger(dticket,DEAL_TYPE);
      if(dmagic==939393)
        {
         sdprofit+=dprofit;
        }
     }
   double ProfitPerTrade=sdprofit/TradePerDay;
   double ProfitPerHour=sdprofit/24;
   TradePerDay=0;
   OPZ[CIN]+=(ProfitPerTrade+ProfitPerHour)/2;
   CINSelect();
   TimeToStruct(TimeCurrent(),lastOptimize);
  }
//+------------------------------------------------------------------+
double lotsOptimized(double LocalMaximumRisk, double locallot=0.0)
  {
   double lot;
   LocalMaximumRisk = Rand(MaximumRisk_,LocalMaximumRisk);
   if(MQLInfoInteger(MQL_OPTIMIZATION)==true)
     {
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
      return lot;
     }
   CAccountInfo myaccount;
   SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);

   lot=NormalizeDouble(myaccount.FreeMargin()*LocalMaximumRisk*_Point,2);
   if(LocalMaximumRisk<0.0)
      locallot=locallot+lot;
   if(locallot!=0.0)
      lot=locallot;
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   int ratio=(int)MathRound(lot/volume_step);
   if(MathAbs(ratio*volume_step-lot)>0.0000001)
      lot=ratio*volume_step;

   if(lot<SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   if(lot>SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX))
      lot=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   return(lot);
  }
//+------------------------------------------------------------------+
void CINSelect()
  {
   double rc=Rand(0,50);
   double cr=0;
   for(int i=5; i<50; i++)
     {
      if(rc<OPZ[i]+cr)
        {
         CIN=i+1;
         break;
        }
      cr+=OPZ[i];
      if(i==49)
        {
         rc=Rand(0,50);
         i=1;
        }
     }
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
signal ParaSignal()
  {
   int iCCi=iCCI(_Symbol,PERIOD_D1,30,PRICE_TYPICAL);

   double iCCv[];

   ArraySetAsSeries(iCCv,true);
   CopyBuffer(iCCi,0,0,3,iCCv);

   if(iCCv[0]<-100)
      return sell;
   else
      if(iCCv[0]>100)
         return sell;
      else
         return none;
  }
//+------------------------------------------------------------------+
signal SwayTrade()
  {
   static double MACDMN;
   static double MACDMX;

   int BBoi=iBands(_Symbol,PERIOD_D1,6,0,2.0,PRICE_CLOSE);//86
   int RSIi=iRSI(_Symbol,PERIOD_D1,3,PRICE_CLOSE);//21
   int OBVi=iOBV(_Symbol,PERIOD_D1,VOLUME_TICK);
   int MACD=iMACD(_Symbol,PERIOD_D1,9,6,3,PRICE_CLOSE);
   int Stoc=iStochastic(_Symbol,PERIOD_D1,5,3,3,MODE_EMA,STO_LOWHIGH);

   double BBoiV[];
   double RSIiV[];
   double OBViV[];
   double MACDV[];
   double StocV[];
   double StocS[];

   ArraySetAsSeries(BBoiV,true);
   CopyBuffer(BBoi,0,0,3,BBoiV);

   ArraySetAsSeries(RSIiV,true);
   CopyBuffer(RSIi,0,0,3,RSIiV);

   ArraySetAsSeries(OBViV,true);
   CopyBuffer(OBVi,0,0,3,OBViV);

   ArraySetAsSeries(MACDV,true);
   CopyBuffer(MACD,0,0,3,MACDV);

   ArraySetAsSeries(StocV,true);
   CopyBuffer(Stoc,0,0,3,StocV);

   ArraySetAsSeries(StocS,true);
   CopyBuffer(Stoc,1,0,3,StocS);

   double H=iHigh(_Symbol,PERIOD_D1,0),
          L=iLow(_Symbol,PERIOD_D1,0),
          C=iClose(_Symbol,PERIOD_D1,0),
          O=iOpen(_Symbol,PERIOD_D1,0);

   MACDMX=MathMax(MACDMX,MACDV[0]);
   MACDMN=MathMin(MACDMN,MACDV[0]);

   bool BBvO = BBoiV[0]>O;
   bool BBvC = BBoiV[0]<C;
   bool BBvL = BBoiV[0]>L;
   bool BBvH = BBoiV[0]<H;
   bool FGBB = BBvO && BBvL;
   bool SGBB = BBvC && BBvH;
   if(FGBB && SGBB)
     {
      bool RSIvSL=RSIiV[0]>RSIiV[1];
      if(RSIiV[1]>75 && RSIvSL)
        {
         bool OBVvOBV=OBViV[0]>OBViV[1];
         if(OBViV[1]>OBViV[2] && OBVvOBV)
           {
            bool MACDvMACD=MACDV[0]<MACDV[1];
            if(MACDvMACD && MACDV[1]<MACDMX)
              {
               bool FGSTOC = StocV[0] > 70;
               bool SGSTOC = (StocV[1] > 50)  && (StocV[0] > 50);
               bool AGSTOC = FGSTOC && SGSTOC;
               if(StocV[0]>StocV[1] && AGSTOC)
                 {
                  return buy;
                 }
              }
           }
        }
     }

   BBvO = BBoiV[0]<O;
   BBvC = BBoiV[0]>C;
   BBvL = BBoiV[0]<L;
   BBvH = BBoiV[0]>H;
   FGBB = BBvO && BBvL;
   SGBB = BBvC && BBvH;
   if(FGBB && SGBB)
     {
      bool RSIvSL=RSIiV[0]<RSIiV[1];
      if(RSIiV[1]<25 && RSIvSL)
        {
         bool OBVvOBV=OBViV[0]<OBViV[1];
         if(OBViV[1]<OBViV[2] && OBVvOBV)
           {
            bool MACDvMACD=MACDV[0]<MACDV[1];
            if(MACDvMACD && MACDV[1]>MACDMN)
              {
               bool FGSTOC = StocV[0] > 30;
               bool SGSTOC = (StocV[1] < 50) && (StocV[0] < 50);
               bool AGSTOC = FGSTOC && SGSTOC;
               if(StocV[0]>StocV[1] && AGSTOC)
                 {
                  return buy;
                 }
              }
           }
        }
     }
   return none;
  }
//+------------------------------------------------------------------+
signal DayTrade()
  {
   static double MACDMN;
   static double MACDMX;

   int BBoi=iBands(_Symbol,PERIOD_D1,6,0,2.0,PRICE_CLOSE);//86
   int RSIi=iRSI(_Symbol,PERIOD_D1,3,PRICE_CLOSE);//21
   int OBVi=iOBV(_Symbol,PERIOD_D1,VOLUME_TICK);
   int MACD=iMACD(_Symbol,PERIOD_D1,9,6,3,PRICE_CLOSE);
   int Stoc=iStochastic(_Symbol,PERIOD_D1,5,3,3,MODE_EMA,STO_LOWHIGH);

   double BBoiV[];
   double RSIiV[];
   double OBViV[];
   double MACDV[];
   double StocV[];
   double StocS[];

   ArraySetAsSeries(BBoiV,true);
   CopyBuffer(BBoi,0,0,3,BBoiV);

   ArraySetAsSeries(RSIiV,true);
   CopyBuffer(RSIi,0,0,3,RSIiV);

   ArraySetAsSeries(OBViV,true);
   CopyBuffer(OBVi,0,0,3,OBViV);

   ArraySetAsSeries(MACDV,true);
   CopyBuffer(MACD,0,0,3,MACDV);

   ArraySetAsSeries(StocV,true);
   CopyBuffer(Stoc,0,0,3,StocV);

   ArraySetAsSeries(StocS,true);
   CopyBuffer(Stoc,1,0,3,StocS);

   double H=iHigh(_Symbol,PERIOD_D1,0),
          L=iLow(_Symbol,PERIOD_D1,0),
          C=iClose(_Symbol,PERIOD_D1,0),
          O=iOpen(_Symbol,PERIOD_D1,0);

   MACDMX=MathMax(MACDMX,MACDV[0]);
   MACDMN=MathMin(MACDMN,MACDV[0]);

   bool BBvO = BBoiV[0]>O;
   bool BBvC = BBoiV[0]<C;
   bool BBvL = BBoiV[0]>L;
   bool BBvH = BBoiV[0]<H;
   bool FGBB = BBvO && BBvL;
   bool SGBB = BBvC && BBvH;
   if(FGBB && SGBB)
     {
      bool RSIvSL=RSIiV[0]>RSIiV[1];
      if(RSIiV[1]>75 && RSIvSL)
        {
         bool OBVvOBV=OBViV[0]>OBViV[1];
         if(OBViV[1]>OBViV[2] && OBVvOBV)
           {
            bool MACDvMACD=MACDV[0]<MACDV[1];
            if(MACDvMACD && MACDV[1]<MACDMX)
              {
               bool FGSTOC = StocV[0] > 70;
               bool SGSTOC = (StocV[1] > 50)  && (StocV[0] > 50);
               bool AGSTOC = FGSTOC && SGSTOC;
               if(StocV[0]>StocV[1] && AGSTOC)
                 {
                  return buy;
                 }
              }
           }
        }
     }

   BBvO = BBoiV[0]<O;
   BBvC = BBoiV[0]>C;
   BBvL = BBoiV[0]<L;
   BBvH = BBoiV[0]>H;
   FGBB = BBvO && BBvL;
   SGBB = BBvC && BBvH;
   if(FGBB && SGBB)
     {
      bool RSIvSL=RSIiV[0]<RSIiV[1];
      if(RSIiV[1]<25 && RSIvSL)
        {
         bool OBVvOBV=OBViV[0]<OBViV[1];
         if(OBViV[1]<OBViV[2] && OBVvOBV)
           {
            bool MACDvMACD=MACDV[0]<MACDV[1];
            if(MACDvMACD && MACDV[1]>MACDMN)
              {
               bool FGSTOC = StocV[0] > 30;
               bool SGSTOC = (StocV[1] < 50) && (StocV[0] < 50);
               bool AGSTOC = FGSTOC && SGSTOC;
               if(StocV[0]>StocV[1] && AGSTOC)
                 {
                  return buy;
                 }
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
   bool NCH1=false;
   int period_seconds=PeriodSeconds(_Period);
   int period_secondsH1=PeriodSeconds(PERIOD_D1);
   datetime new_time=TimeCurrent()/period_seconds*period_seconds;
   datetime new_time2=TimeCurrent()/period_secondsH1*period_secondsH1;
   if(current_chart.isNewBar(new_time))
      NC=true;
   if(current_chart2.isNewBar(new_time2))
      NCH1=true;
   double Balance= AccountInfoDouble(ACCOUNT_BALANCE);
   double Equity = AccountInfoDouble(ACCOUNT_EQUITY);
   int pos=PositionsTotal();
   Optimize();
   double price_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
   double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

   signal CurrentSignal=none;
   signal BigCurrentSignal=none;
   signal HA=none;
   if(NCH1)
     {
      BigCurrentSignal=DayTrade();
     }
   if(NC)
     {
      CurrentSignal=ManualDem(CIN);
      HA=CurrentSignal;
     }

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

   Comment("\nDem: ",CIN,"\nBuy Volume: ",cvolumeB,"\nSell Volume: ",cvolumeS,"\n Signal big: ",EnumToString(BigCurrentSignal),
           "\n Signal small: ",EnumToString(CurrentSignal),"\n Max Risk: ",MaximumRisk);

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
   if(NC && pos>0)
     {
      TrailingStop(price_ask,price_bid);
     }
   if(NCH1 && pos>0)
     {
      TrailingStopH1(price_ask,price_bid);
     }

   if(CurrentSignal!=none && pos<POSITIONS)
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
      signal parasit = ParaSignal();
      cvolumeB=lotsOptimized(MaximumRisk*(parasit==buy?1.8:(parasit==sell?-1.1:1)),cvolumeB);
      cvolumeS=lotsOptimized(MaximumRisk*(parasit==sell?1.8:(parasit==buy?-1.1:1)),cvolumeS);
     }
   if(work==true && work_day==true)
     {
      if(CurrentSignal==buy && HA==buy)
        {
         if(pos<POSITIONS)
           {
            if(trade.Buy(cvolumeB,_Symbol,price_ask,price_ask-SL*_Point,price_ask+TP*_Point,""))
              {
               OpenSignal=buy;
               TradePerDay++;
              }
           }
        }
      else
         if(CurrentSignal==sell && HA==sell)
           {
            if(pos<POSITIONS)
              {
               if(trade.Sell(cvolumeS,_Symbol,price_bid,price_bid+SL*_Point,price_bid-TP*_Point,""))
                 {
                  OpenSignal=sell;
                  TradePerDay++;
                 }
              }
           }
      if(BigCurrentSignal==buy)
        {
         if(pos<POSITIONS+1)
           {
            if(trade2.Buy(cvolumeB,_Symbol,price_ask,price_ask-(SL*500)*_Point,price_ask+(TP*500)*_Point,"AR"))
              {
               OpenSignal=buy;
              }
           }
        }
      else
         if(BigCurrentSignal==sell)
           {
            if(pos<POSITIONS+1)
              {
               if(trade2.Sell(cvolumeS,_Symbol,price_bid,price_bid+(SL*500)*_Point,price_bid-(TP*500)*_Point,"AR"))
                 {
                  OpenSignal=sell;
                 }
              }
           }
     }
   if(InitBalance>=Equity)
     {
      SL = MathMax(SL/2,50);
      TP = MathMax(TP/2,50);
     }
   else
     {
      SL = (int)MathMin(SL*1.2,1000);
      TP = (int)MathMin(TP*1.2,1000);
     }
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
double lastv=0.0;
//+------------------------------------------------------------------+
signal ManualDem(int len)
  {
   MqlRates RateArray[];
   double DeMax[],DeMin[];
   ArrayResize(RateArray,len);
   ArrayResize(DeMax,len);
   ArrayResize(DeMin,len);
   if(!CopyRates(_Symbol,_Period,0,len,RateArray))
      return none;

   static double LMA;
   double MA=SMARate(RateArray);

   for(int i=1; i<ArraySize(RateArray); i++)
     {
      DeMax[i-1]=RateArray[i].high-RateArray[i-1].high;
      DeMax[i-1]=(DeMax[i-1]>0?DeMax[i-1]:0);
      DeMin[i-1]=RateArray[i-1].low-RateArray[i].low;
      DeMin[i-1]=(DeMin[i-1]>0?DeMin[i-1]:0);
     }
   double MADeMax=SMA(DeMax);
   double MADeMin=SMA(DeMin);
   double root=MADeMax+MADeMin;
   double DeM;
   root=NormalizeDouble(root,5);
   if(root!=0.0)
     {
      DeM=MADeMax/root;
      bool UT=false;
      double std=Stdev(MA,LMA);
      if(MA>LMA)
        {
         UT=true;
         LMA=MA;
        }

      if(DeM>0.7 && !UT)
        {
         lastv = MathMax(DeM,lastv);
         if(DeM<lastv)
           {
            return sell;
           }
        }
      else
         if(DeM<0.3 && UT)
           {
            lastv = MathMin(DeM,lastv);
            if(DeM>lastv)
              {
               return buy;
              }
           }
     }
   lastv=DeM;
   return none;
  }
double MathRandRange(double x,double y) { return(x+MathMod(MathRand(),MathAbs(x-y))); }
//+------------------------------------------------------------------+
double Stdev(double a,double b)
  {
   return MathSqrt(MathPow(a-b,2))/2;
  }
//+------------------------------------------------------------------+
double SMA(double &CArray[])
  {
   return ArraySum(CArray)/ArraySize(CArray);
  }
//+------------------------------------------------------------------+
double ArraySum(double &rates[])
  {
   double SM=0;
   for(int i=0; i<ArraySize(rates); i++)
     {
      SM+=rates[i];
     }
   return SM;
  }
//+------------------------------------------------------------------+
double SMARate(MqlRates &CArray[])
  {
   return ArraySumRate(CArray)/ArraySize(CArray);
  }
//+------------------------------------------------------------------+
double ArraySumRate(MqlRates &rates[])
  {
   double SM=0;
   for(int i=0; i<ArraySize(rates); i++)
     {
      SM+=(rates[i].low+rates[i].high+rates[i].close)/3;
     }
   return SM;
  }
//+------------------------------------------------------------------+
void TrailingStopH1(double price_ask,double price_bid)
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
         if(MGC==939393)
            continue;
         if(CMC==NULL && CMC=="")
            continue;
         if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
           {
            double NSL=NormalizeDouble(price_ask-1000*_Point,_Digits);
            double NSL2=NormalizeDouble(price_ask-100*_Point,_Digits);
            if(NSL>SLC)
              {
               if(trade.PositionModify(PositionTicket,NSL,TPC+200*_Point))
                 {
                  Print("error");
                 }
              }
            else
               if(NSL2<SLC)
                 {
                  if(trade.PositionModify(PositionTicket,NSL2,TPC-100*_Point))
                    {
                     Print("error");
                    }
                 }
           }
         else
            if(PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
              {
               double NSL=NormalizeDouble(price_ask+500*_Point,_Digits);
               double NSL2=NormalizeDouble(price_ask+50*_Point,_Digits);
               if(NSL<SLC)
                 {
                  if(!trade.PositionModify(PositionTicket,NSL,TPC-200*_Point))
                    {
                     Print("error");
                    }
                 }
               else
                  if(NSL2<SLC)
                    {
                     if(!trade.PositionModify(PositionTicket,NSL2,TPC+100*_Point))
                       {
                        Print("error");
                       }
                    }
              }
        }
     }
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
