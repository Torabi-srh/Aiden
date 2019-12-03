//+------------------------------------------------------------------+
//|                                                     8-6-2019.mq5 |
//|                                     Copyright 2019, Soroush.trb. |
//|                                           https://www.wsafar.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2019, Soroush.trb."
#property link      "https://www.wsafar.com"
#property version   "1.00" 
#include <Trade\Trade.mqh>

//+------------------------------------------------------------------+
//| Overall                                                          |
//+------------------------------------------------------------------+
//--- input parameters
input double NumberDeviation=0.15;
input double RSIDeviation=0.5;
input double DecreaseFactor=3; //lot size divisor(reducer) during loss streak
input double BuyZigZagChance=12.5;
input double BuyStochasticChance=12.5;
input double BuyShiftedMovingAverageChance=12.5;
input double BuyParabolicSARChance=12.5;
input double BuyRSIChance=12.5;
input double BuyMACDChance=12.5;
input double BuyCrossOverChance=12.5;
input double BuyMomentumChance=12.5;
input double SellZigZagChance=12.5;
input double SellStochasticChance=12.5;
input double SellShiftedMovingAverageChance=12.5;
input double SellParabolicSARChance=12.5;
input double SellRSIChance=12.5;
input double SellMACDChance=12.5;
input double SellCrossOverChance=12.5;
input double SellMomentumChance=12.5;
input double PreVolum=0.01;
input double PreMaximumRisk=1;
input int Positions=1;
input int NumberOfSkipDay=1;

int SkipDay=1;
CTrade iTrade;
string iComment="";
int iIndicator[];
double iIndicatorChance[];
string iIndicatorLastSignal[];
string iIndicatorBreath[];

double iBuyZigZagChance=0.01;
double iBuyStochasticChance=0.01;
double iBuyShiftedMovingAverageChance=0.01;
double iBuyParabolicSARChance=0.01;
double iBuyRSIChance=0.01;
double iBuyMACDChance=0.01;
double iBuyCrossOverChance=0.01;
double iBuyMomentumChance=0.01;
double iSellZigZagChance=0.01;
double iSellStochasticChance=0.01;
double iSellShiftedMovingAverageChance=0.01;
double iSellParabolicSARChance=0.01;
double iSellRSIChance=0.01;
double iSellMACDChance=0.01;
double iSellCrossOverChance=0.01;
double iSellMomentumChance=0.01;

int iDirection[];
double iDirectionChance[];
string iDirectionLastSignal[];
string iDirectionBreath[];

double iLossRisk;
double iProfitRisk;
double iBuyVolume;
double iSellVolume;
double iStopLoss;
double iTakeProfit;
string iSignal;
string oSignal;
bool RemoveEA=false;

double tradeVolume;
double MaximumRisk;
double TP;
double SL;
double iBalance;
datetime tradingAllowed=0;
//+------------------------------------------------------------------+
//| ZigZag                                                           |
//+------------------------------------------------------------------+
//--- input parameters
input int ExtDepth=12;
input int ExtDeviation=5;
input int ExtBackstep=3;

//--- indicator buffers
double ZigzagBuffer[];      // main buffer
double HighMapBuffer[];     // highs
double LowMapBuffer[];      // lows
int level=3;             // recounting depth
double iDeviation;           // deviation in points
//+------------------------------------------------------------------+
class iDeal
  {
public:
   int               ticket;
   string            comment;
   bool              proccessed;
   iDeal            *next;
   iDeal            *previews;
  };
iDeal *iList;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| define                                                           |
//+------------------------------------------------------------------+
#define ZigzagHandle iIndicator[0]
#define StochasticHandle iIndicator[1]
#define MA5_0Handle iIndicator[2]
#define MA5_5Handle iIndicator[3]
#define MA3_0Handle iIndicator[4]
#define SARHandle iIndicator[5]
#define RSIHandle iIndicator[6]
#define MACDHandle iIndicator[7]
#define IchimokuHandle iIndicator[8]
#define MomentumHandle iIndicator[9]

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   SkipDay=NumberOfSkipDay;
   iList=new iDeal;
   iList.previews=NULL;
   iList.next=NULL;
   EventSetTimer(60);
   if(PreVolum!=0) tradeVolume=PreVolum;
   if(PreMaximumRisk!=0) MaximumRisk=PreMaximumRisk;
   iBalance=balance;
//--- indicator buffers mapping
   SetIndexBuffer(0,ZigzagBuffer,INDICATOR_DATA);
   SetIndexBuffer(1,HighMapBuffer,INDICATOR_CALCULATIONS);
   SetIndexBuffer(2,LowMapBuffer,INDICATOR_CALCULATIONS);

   ArrayResize(iIndicator,10);
   iIndicator[0] = iCustom(_Symbol,_Period,"Examples\\ZigZag",ExtDepth,ExtDeviation,ExtBackstep);
   iIndicator[1] = iStochastic(_Symbol,_Period,3,13,6,MODE_EMA,STO_CLOSECLOSE);
   iIndicator[2] = iMA(_Symbol,_Period,5,0,MODE_EMA,PRICE_CLOSE);
   iIndicator[3] = iMA(_Symbol,_Period,5,5,MODE_EMA,PRICE_CLOSE);
   iIndicator[4] = iMA(_Symbol,_Period,3,0,MODE_EMA,PRICE_CLOSE);
   iIndicator[5] = iSAR(_Symbol,_Period,0.2,2);
   iIndicator[6] = iRSI(_Symbol,_Period,5,PRICE_CLOSE);
   iIndicator[7] = iMACD(_Symbol,_Period,3,6,2,PRICE_CLOSE);
   iIndicator[8] = iMomentum(_Symbol,_Period,5,PRICE_CLOSE);

   iBuyZigZagChance=BuyZigZagChance;
   iBuyStochasticChance=BuyStochasticChance;
   iBuyShiftedMovingAverageChance=BuyShiftedMovingAverageChance;
   iBuyParabolicSARChance=BuyParabolicSARChance;
   iBuyRSIChance=BuyRSIChance;
   iBuyMACDChance=BuyMACDChance;
   iBuyCrossOverChance=BuyCrossOverChance;
   iBuyMomentumChance=BuyMomentumChance;
   iSellZigZagChance=SellZigZagChance;
   iSellStochasticChance=SellStochasticChance;
   iSellShiftedMovingAverageChance=SellShiftedMovingAverageChance;
   iSellParabolicSARChance=SellParabolicSARChance;
   iSellRSIChance=SellRSIChance;
   iSellMACDChance=SellMACDChance;
   iSellCrossOverChance=SellCrossOverChance;
   iSellMomentumChance=SellMomentumChance;

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//|               Momentum function                                  |
//+------------------------------------------------------------------+
string Momentum()
  {
   double PA[];

   ArraySetAsSeries(PA,true);
   CopyBuffer(iIndicator[8],0,0,3,PA);

   double MV=NormalizeDouble(PA[0],2);

   if(MV<100.0)
     {
      return "buy";
     }
   if(MV>100)
     {
      return "sell";
     }

   return "";
  }
//+------------------------------------------------------------------+
//|      moving average convergence/divergence function              |
//+------------------------------------------------------------------+
string MACD()
  {
//--- 0 - MAIN_LINE, 1 - SIGNAL_LINE
   double m0 = iMACDGet(MAIN_LINE,0);
   double s0 = iMACDGet(SIGNAL_LINE,0);
   double m1 = iMACDGet(MAIN_LINE,1);
   double s1 = iMACDGet(SIGNAL_LINE,1);

   if(s0<0 && s0<s1)
     {
      if(m0<s0) return "sell";
     }
   if(s0>0 && s0>s1)
     {
      if(m0>s0) return "buy";
     }
   return "";
  }
//+------------------------------------------------------------------+
double iMACDGet(const int buffer,const int index)
  {
   double MACD[1];
//--- reset error code 
   ResetLastError();
//--- fill a part of the iMACDBuffer array with values from the indicator buffer that has 0 index 
   if(CopyBuffer(iIndicator[7],buffer,index,1,MACD)<0)
     {
      //--- if the copying fails, tell the error code 
      PrintFormat("Failed to copy data from the iMACD indicator, error code %d",GetLastError());
      //--- quit with zero result - it means that the indicator is considered as not calculated 
      return(0.0);
     }
   return(MACD[0]);
  }
//+------------------------------------------------------------------+
//|              Relative strength index function                    |
//+------------------------------------------------------------------+
string RSI()
  {
   double RSIA[];

   CopyBuffer(iIndicator[6],0,0,3,RSIA);

   double RSIV=NormalizeDouble(RSIA[0],2);
   double bs=sdOnNumber(RSIV,70);
   double ss=sdOnNumber(RSIV,30);

   if(RSIV>70)
     {
      if(bs>RSIDeviation) return "sell";
     }
   if(RSIV<30)
     {
      if(ss>RSIDeviation) return "buy";
     }
   return "";
  }
//+------------------------------------------------------------------+
//|              ParabolicSAR function                               |
//+------------------------------------------------------------------+
string ParabolicSAR()
  {
   MqlRates PA[];
   double SARA[];

   ArraySetAsSeries(PA,true);

   int Data=CopyRates(_Symbol,_Period,0,3,PA);

   ArraySetAsSeries(SARA,true);
   CopyBuffer(iIndicator[5],0,0,3,SARA);

   double SARV=NormalizeDouble(SARA[1],5);

   if(SARV<PA[1].close)
     {
      return "buy";
     }
   if(SARV>PA[1].close)
     {
      return "sell";
     }

   return "";
  }
//+------------------------------------------------------------------+
//|              CrossOver function                                  |
//+------------------------------------------------------------------+
string CrossOver()
  {
   double SEMA[],BEMA[];

   CopyBuffer(iIndicator[4],0,0,3,SEMA);
   CopyBuffer(iIndicator[2],0,0,3,BEMA);

   if(BEMA[1]>SEMA[1])
     {
      if(BEMA[2]<SEMA[2])
        {
         return "buy";
        }
     }
   if(BEMA[1]<SEMA[1])
     {
      if(BEMA[2]>SEMA[2])
        {
         return "sell";
        }
     }
   return "";
  }
//+------------------------------------------------------------------+
//|              ShiftedMovingAverage function                       |
//+------------------------------------------------------------------+
string ShiftedMovingAverage()
  {
   double MAA[];
   double SAA[];

   ArraySetAsSeries(MAA,true);
   ArraySetAsSeries(SAA,true);

   CopyBuffer(iIndicator[2],0,0,3,MAA);
   CopyBuffer(iIndicator[3],0,0,3,SAA);

   double MAV0=MAA[0];
   double SAV0=SAA[0];
   double MAV1=MAA[1];
   double SAV1=SAA[1];
   double sdn=sdOnNumber(MAV0,SAV0);

   if(SAV0>SAV1 && MAV0<MAV1)
     {
      if(sdn<=NumberDeviation)
        {
         return "sell";
        }
     }
   else if(SAV0<SAV1 && MAV0>MAV1)
     {
      if(sdn<=NumberDeviation)
        {
         return "buy";
        }
     }
   return "";
  }
//+------------------------------------------------------------------+
//|              Stochastic function                                 |
//+------------------------------------------------------------------+
string Stochastic()
  {
   double KArray[];
   double DArray[];

   ArraySetAsSeries(KArray,true);
   ArraySetAsSeries(DArray,true);

   CopyBuffer(StochasticHandle,0,0,3,KArray);
   CopyBuffer(StochasticHandle,1,0,3,DArray);

   double KValue0=KArray[0];
   double DValue0=DArray[0];

   double KValue1=KArray[1];
   double DValue1=DArray[1];

   double sdn=sdOnNumber(KValue0,DValue0);
   if(KValue0>KValue1)
     {
      if(sdn<=NumberDeviation)
        {
         return "buy";
        }
     }
   else if(KValue0<KValue1)
     {
      if(sdn<=NumberDeviation)
        {
         return "sell";
        }
     }

   return "";
  }
//+------------------------------------------------------------------+
double sdOnNumber(double n1,double n2)
  {
   return MathAbs(n1-n2)/MathSqrt(2);
  }
//+------------------------------------------------------------------+
//|               ZigZag function                                    |
//+------------------------------------------------------------------+
string ZigZag()
  {
   double High[];      //array for higher prices
   double Low[];       //array for Lower prices

   static datetime Old_Time;
   datetime New_Time[1];
   bool IsNewBar=false;

// copying the last bar time to the element New_Time[0]
   int copied=CopyTime(_Symbol,_Period,0,1,New_Time);
   if(copied>0) // ok, the data has been copied successfully
     {
      if(Old_Time!=New_Time[0]) // if old time isn't equal to new bar time
        {
         IsNewBar=true;   // if it isn't a first call, the new bar has appeared
         Old_Time=New_Time[0];            // saving bar time
        }
     }
   else
     {
      Print("Error in copying historical times data, error =",GetLastError());
      ResetLastError();
      return "";
     }

//--- EA should only check for new trade if we have a new bar
   if(IsNewBar==false)
     {
      return "";
     }
   ArraySetAsSeries(High,true); //set High[] array as timeseries
   ArraySetAsSeries(Low,true); //set Low[] array as timeseries

   ArraySetAsSeries(ZigzagBuffer,true);
   ArraySetAsSeries(HighMapBuffer,true);
   ArraySetAsSeries(LowMapBuffer,true);

   CopyHigh(_Symbol,_Period,0,11,High);//filling the High[] array with current values
   CopyLow(_Symbol,_Period,0,11,Low);//filling the Low[] array with current values

   if(CopyBuffer(ZigzagHandle,0,0,3,ZigzagBuffer)<=0)
     {
      Print("Getting ZigzagBuffer is failed! Error",GetLastError());
      return "";
     }

   if(CopyBuffer(ZigzagHandle,1,0,3,HighMapBuffer)<=0)
     {
      Print("Getting HighMapBuffer is failed! Error",GetLastError());
      return "";
     }

   if(CopyBuffer(ZigzagHandle,2,0,3,LowMapBuffer)<=0)
     {
      Print("Getting LowMapBuffer is failed! Error",GetLastError());
      return "";
     }

   if(ZigzagBuffer[1]==High[1])
     {
      return "sell";
     }

   if(ZigzagBuffer[1]==Low[1])
     {
      return "buy";
     }
   return "";
  }
//+------------------------------------------------------------------+
string IndicatorProcess()
  {
   string Signal="";
   double Buy=0;
   double Sell=0;
   string zigzag=ZigZag();
   string stochastic=Stochastic();
   string shiftedmovingaverage=ShiftedMovingAverage();
   string crossover=CrossOver();
   string parabolicsar=ParabolicSAR();
   string rsi=RSI();
   string macd=MACD();
   string momentum=Momentum();
   iComment = zigzag+"|"+stochastic+"|"+shiftedmovingaverage+"|"+crossover+"|"+parabolicsar+"|"+rsi+"|"+macd+"|"+momentum;
   if(zigzag=="buy") Buy+=iBuyZigZagChance;
   else if(zigzag=="sell") Sell+=iSellZigZagChance;
   if(stochastic=="buy") Buy+=iBuyStochasticChance;
   else if(stochastic=="sell") Sell+=iSellStochasticChance;
   if(shiftedmovingaverage=="buy") Buy+=iBuyShiftedMovingAverageChance;
   else if(shiftedmovingaverage=="sell") Sell+=iSellShiftedMovingAverageChance;
   if(crossover=="buy") Buy+=iBuyCrossOverChance;
   else if(crossover=="sell") Sell+=iSellCrossOverChance;
   if(parabolicsar=="buy") Buy+=iBuyParabolicSARChance;
   else if(parabolicsar=="sell") Sell+=iSellParabolicSARChance;
   if(rsi=="buy") Buy+=iBuyRSIChance;
   else if(rsi=="sell") Sell+=iSellRSIChance;
   if(macd=="buy") Buy+=iBuyMACDChance;
   else if(macd=="sell") Sell+=iSellMACDChance;
   if(momentum=="buy") Buy+=iBuyMomentumChance;
   else if(momentum=="sell") Sell+=iSellMomentumChance;

   if(Sell<Buy) Signal="buy";
   else if(Sell>Buy) Signal="sell";

   return Signal;
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();

  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   if(RemoveEA) return;
   double Ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   double equity=AccountInfoDouble(ACCOUNT_EQUITY);
   double swapLongTrades=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_LONG);
   double swapShortTrades=SymbolInfoDouble(_Symbol,SYMBOL_SWAP_SHORT);
   string account_currency=AccountInfoString(ACCOUNT_CURRENCY);
   bool iSkip=false;
   int PST=PositionsTotal();
   if(PST>Positions-1)
     {
      iSkip=true;
     }
   else
     {
      iSkip=false;
     }
   if(balance<=(iBalance)*0.90)
     {
      CloseAllPositions();
      tradingAllowed=Tomorrow();
     }
   if(balance<=(iBalance)*0.75)
     {
      CloseAllPositions();
      RemoveEA=true;
      ExpertRemove();
      return;
     }
   if(TimeCurrent()<tradingAllowed)
     {
      iSkip=true;
     }

   CheckTrailingStop(Ask,Bid);
   VolumeOptimize();
   ChanceTweak();
//if(iSignal!=oSignal) if(iSignal=="sell") CloseAllBuyPositions(); else if(iSignal=="buy") CloseAllSellPositions();
   if(iSignal=="" || oSignal!=iSignal) oSignal=iSignal;

   if(!iSkip)
     {
      if(SkipDay>0)
        {
         tradingAllowed=Tomorrow();
         SkipDay--;
         return;
        }
      if(iSignal=="sell")
        {
         CalculatLoss(Ask,ORDER_TYPE_SELL);
         if(iTrade.Sell(tradeVolume,_Symbol,Ask,SL,TP,NULL)) //Opens a long position 
           {
            iDeal *dl=new iDeal;
            dl.comment=iComment;
            dl.proccessed=false;
            dl.ticket=PositionsTotal()-1;
            dl.next=NULL;
            dl.previews=iList;
            iList.next=dl;
            iList=iList.next;
           }
        }
      else if(iSignal=="buy")
        {
         CalculatLoss(Bid,ORDER_TYPE_BUY);
         if(iTrade.Buy(tradeVolume,_Symbol,Bid,SL,TP,NULL)) //Opens a short position 
           {
            iDeal *dl=new iDeal;
            dl.comment=iComment;
            dl.proccessed=false;
            dl.ticket=PositionsTotal()-1;
            dl.next=NULL;
            dl.previews=iList;
            iList.next=dl;
            iList=iList.next;
           }
        }
     }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
//---
   iSignal=IndicatorProcess();
  }
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      iTrade.PositionClose(i);
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
         iTrade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
void SetiListToFirstNode()
  {
   while(iList.previews!=NULL) iList=iList.previews;
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
double CTCLC(string IndicatorDir,string OpenDir,double profitable)
  {
   if(profitable>0)
     {
      if(IndicatorDir==OpenDir)
        {
         return +0.5;
        }
      else
        {
         return -0.1;
        }
     }
   else if(profitable<0)
     {
      if(IndicatorDir==OpenDir)
        {
         return -0.1;
        }
      else
        {
         return +0.5;
        }
     }
   else
     {
      if(IndicatorDir==OpenDir)
        {
         return -0.1;
        }
      else
        {
         return -0.1;
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ChanceTweak()
  {
   SetiListToFirstNode();
   do
     {
      iDeal idl=iList;
      if(!idl.proccessed)
        {
         ulong ticket=PositionGetTicket(idl.ticket);
         if(ticket>0)
           {
            ENUM_POSITION_TYPE optype=(ENUM_POSITION_TYPE)PositionGetInteger(POSITION_TYPE);
            double prf=PositionGetDouble(POSITION_PROFIT);
            string cmt[];
            StringSplit(idl.comment,StringGetCharacter("|",0),cmt);
            if(ArraySize(cmt)>0)
              {
               iBuyZigZagChance+=CTCLC(cmt[0],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellZigZagChance+=CTCLC(cmt[0],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyStochasticChance+=CTCLC(cmt[1],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellStochasticChance+=CTCLC(cmt[1],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyShiftedMovingAverageChance+=CTCLC(cmt[2],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellShiftedMovingAverageChance+=CTCLC(cmt[2],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyCrossOverChance+=CTCLC(cmt[3],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellCrossOverChance+=CTCLC(cmt[3],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyParabolicSARChance+=CTCLC(cmt[4],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellParabolicSARChance+=CTCLC(cmt[4],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyRSIChance+=CTCLC(cmt[5],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellRSIChance+=CTCLC(cmt[5],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyMACDChance+=CTCLC(cmt[6],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellMACDChance+=CTCLC(cmt[6],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iBuyMomentumChance+=CTCLC(cmt[7],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
               iSellMomentumChance+=CTCLC(cmt[7],(optype==POSITION_TYPE_BUY?"buy":"sell"),prf);
              }
            iBuyZigZagChance=(iBuyZigZagChance<0?1:iBuyZigZagChance);
            iSellZigZagChance=(iSellZigZagChance<0?1:iSellZigZagChance);
            iBuyStochasticChance=(iBuyStochasticChance<0?1:iBuyStochasticChance);
            iSellStochasticChance=(iSellStochasticChance<0?1:iSellStochasticChance);
            iBuyShiftedMovingAverageChance=(iBuyShiftedMovingAverageChance<0?1:iBuyShiftedMovingAverageChance);
            iSellShiftedMovingAverageChance=(iSellShiftedMovingAverageChance<0?1:iSellShiftedMovingAverageChance);
            iBuyCrossOverChance=(iBuyCrossOverChance<0?1:iBuyCrossOverChance);
            iSellCrossOverChance=(iSellCrossOverChance<0?1:iSellCrossOverChance);
            iBuyParabolicSARChance=(iBuyParabolicSARChance<0?1:iBuyParabolicSARChance);
            iSellParabolicSARChance=(iSellParabolicSARChance<0?1:iSellParabolicSARChance);
            iBuyRSIChance=(iBuyRSIChance<0?1:iBuyRSIChance);
            iSellRSIChance = (iSellRSIChance<0?1:iSellRSIChance);
            iBuyMACDChance = (iBuyMACDChance<0?1:iBuyMACDChance);
            iSellMACDChance=(iSellMACDChance<0?1:iSellMACDChance);
            iBuyMomentumChance=(iBuyMomentumChance<0?1:iBuyMomentumChance);
            iSellMomentumChance=(iSellMomentumChance<0?1:iSellMomentumChance);

            iBuyZigZagChance=(iBuyZigZagChance>100?100:iBuyZigZagChance);
            iSellZigZagChance=(iSellZigZagChance>100?100:iSellZigZagChance);
            iBuyStochasticChance=(iBuyStochasticChance>100?100:iBuyStochasticChance);
            iSellStochasticChance=(iSellStochasticChance>100?100:iSellStochasticChance);
            iBuyShiftedMovingAverageChance=(iBuyShiftedMovingAverageChance>100?100:iBuyShiftedMovingAverageChance);
            iSellShiftedMovingAverageChance=(iSellShiftedMovingAverageChance>100?100:iSellShiftedMovingAverageChance);
            iBuyCrossOverChance=(iBuyCrossOverChance>100?100:iBuyCrossOverChance);
            iSellCrossOverChance=(iSellCrossOverChance>100?100:iSellCrossOverChance);
            iBuyParabolicSARChance=(iBuyParabolicSARChance>100?100:iBuyParabolicSARChance);
            iSellParabolicSARChance=(iSellParabolicSARChance>100?100:iSellParabolicSARChance);
            iBuyRSIChance=(iBuyRSIChance>100?100:iBuyRSIChance);
            iSellRSIChance = (iSellRSIChance>100?100:iSellRSIChance);
            iBuyMACDChance = (iBuyMACDChance>100?100:iBuyMACDChance);
            iSellMACDChance=(iSellMACDChance>100?100:iSellMACDChance);
            iBuyMomentumChance=(iBuyMomentumChance>100?100:iBuyMomentumChance);
            iSellMomentumChance=(iSellMomentumChance>100?100:iSellMomentumChance);
           }
        }
      if(iList.next!=NULL) iList=iList.next;
     }
   while(iList.next!=NULL);
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
         iTrade.PositionClose(i);
        }
     }
  }
//+------------------------------------------------------------------+
string GetEquityProfit(double balance,double equity,string account_currency)
  {
   double calc=balance-equity;
   if(calc<0) return "profit";
   else if(calc>SL) return "loss";
   else return "profit";
  }
//+------------------------------------------------------------------+
void CalculatLoss(double Inp,ENUM_ORDER_TYPE type)
  {
   double high= iHigh(Symbol(),Period(),10);
   double low = iLow(Symbol(),Period(),10);
   double close=iClose(Symbol(),Period(),10);
   double open = iOpen(Symbol(),Period(),10);

   double PP = (high+low+close)/3;
   double R1 = (2*PP-low);
   double S1 = (2*PP-high);
   double R2 = (PP+(high-low));
   double S2 = (PP-(high-low));
   double R3 = (high+2*(PP-low));
   double S3 = (low-2*(high-PP));
   double R4 = (PP*101/100);
   double R5 = (PP*105/100);
   double R6 = (PP*110/100);
   double R7 = (PP*115/100);
   double R8 = (PP*120/100);
   double S4 = (PP*98/100);
   double S5 = (PP*95/100);
   double S6 = (PP*90/100);
   double S7 = (PP*85/100);
   double S8 = (PP*80/100);

   double tp=NormalizeDouble((Inp+150*_Point),_Digits);
   double sl=0;
   double a=80;
   double st = NormalizeDouble(double(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_STOPS_LEVEL)), 0);
   double sp = NormalizeDouble(double(SymbolInfoInteger(Symbol(), SYMBOL_SPREAD)), 0);
   double fr = NormalizeDouble(double(SymbolInfoInteger(Symbol(), SYMBOL_TRADE_FREEZE_LEVEL)), 0);
   int temp=int(NormalizeDouble(MathMax(MathMax(st,sp),fr),0));

   if(type==ORDER_TYPE_BUY)
     {
      TP = R3+st*_Point;
      SL = S3-st*_Point;
     }
   else if(type==ORDER_TYPE_SELL)
     {
      TP = S3-st*_Point;
      SL = R3+st*_Point;
     }
   TP = NormalizeDouble(TP,_Digits);
   SL = NormalizeDouble(SL,_Digits);
//CheckStopLoss_Takeprofit(type,SL,TP);
  }
//+------------------------------------------------------------------+
void CheckTrailingStop(double Ask,double Bid)
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      string symbol=PositionGetSymbol(i);
      if(_Symbol==symbol)
        {
         ulong PositionTicket=PositionGetInteger(POSITION_TICKET);
         double CurrentStopLoss=PositionGetDouble(POSITION_SL);
         double CurrentTakeProfit=PositionGetDouble(POSITION_TP);
         ENUM_ORDER_TYPE CurrentOrderType=(ENUM_ORDER_TYPE)PositionGetInteger(POSITION_TYPE);
         if(CurrentOrderType==ORDER_TYPE_BUY)
           {
            CalculatLoss(Bid,CurrentOrderType);
            if(CurrentStopLoss<SL)
              {
               iTrade.PositionModify(PositionTicket,SL,TP);
              }
              } else {
            CalculatLoss(Ask,CurrentOrderType);
            if(CurrentStopLoss>SL)
              {
               iTrade.PositionModify(PositionTicket,SL,TP);
              }
           }
        }
     }
  }
//+------------------------------------------------------------------+
bool CheckStopLoss_Takeprofit(ENUM_ORDER_TYPE type,double sl,double tp)
  {
   double Ask=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_ASK),_Digits);
   double Bid=NormalizeDouble(SymbolInfoDouble(_Symbol,SYMBOL_BID),_Digits);
   int stops_level=(int)SymbolInfoInteger(_Symbol,SYMBOL_TRADE_STOPS_LEVEL);
   bool SL_check=false,TP_check=false;
   switch(type)
     {
      case  ORDER_TYPE_BUY:
        {
         SL_check=(Bid-sl>stops_level*_Point);
         TP_check=(tp-Bid>stops_level*_Point);
         return(SL_check&&TP_check);
        }
      case  ORDER_TYPE_SELL:
        {
         SL_check=(sl-Ask>stops_level*_Point);
         TP_check=(Ask-TP>stops_level*_Point);
         return(TP_check&&SL_check);
        }
      break;
     }
   return false;
  }
//+------------------------------------------------------------------+
void VolumeOptimize()
  {
   double min_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MIN);
   double max_volume=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_MAX);
   double volume_step=SymbolInfoDouble(Symbol(),SYMBOL_VOLUME_STEP);
   double FreeMargin=AccountInfoDouble(ACCOUNT_MARGIN_FREE);
   int losses=0;
   tradeVolume=NormalizeDouble(FreeMargin*MaximumRisk/1000.0,2);

   int ratio=(int)MathRound(tradeVolume/volume_step);
   if(MathAbs(ratio*volume_step-tradeVolume)>0.0000001)
     {
      tradeVolume=ratio*volume_step;
     }

   if(DecreaseFactor>0)
     {
      for(int i=PositionsTotal()-1;i>=0;i--)
        {
         ulong ticket=PositionGetTicket(i);
         if(PositionGetDouble(POSITION_PROFIT)>=0) continue;
         else losses++;
        }

      if(losses>1) tradeVolume=NormalizeDouble(tradeVolume-tradeVolume*losses/DecreaseFactor,2);
     }
   if(PositionsTotal()-1<=0) tradeVolume=min_volume;
   tradeVolume = MathMin(max_volume,tradeVolume);
   tradeVolume = MathMax(min_volume,tradeVolume);
  }
//+------------------------------------------------------------------+
static int HR2400=PERIOD_D1*60; // 86400 = 24 * 3600
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
datetime TimeOfDay(datetime when=0)
  {
   return(when==0 ? TimeCurrent() : when)%HR2400;
  }
//+------------------------------------------------------------------+
datetime DateOfDay(datetime when=0)
  {
   return(when==0 ? TimeCurrent() : when)-TimeOfDay(when);
  }
//+------------------------------------------------------------------+
datetime Tomorrow(datetime when=0)
  {
   return DateOfDay(when==0 ? TimeCurrent() : when)+HR2400;
  }
//+------------------------------------------------------------------+
datetime Yesterday(datetime when=0)
  {
   datetime today = DateOfDay(when == 0 ? TimeCurrent() : when);
   int      iD1   = iBarShift(NULL, PERIOD_D1,  today - 1);
   return iTime(NULL,PERIOD_D1,iD1);
  }
//+------------------------------------------------------------------+
