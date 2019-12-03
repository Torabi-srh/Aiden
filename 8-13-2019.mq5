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
input double NumberDeviation=0.0;
input double DecreaseFactor=3; //lot size divisor(reducer) during loss streak
input double PreVolum=0.01;
input double PreMaximumRisk=1;
input int Positions=3;
input int NumberOfSkipDay=1;
input double ISL=750;
int SkipDay=1;
CTrade iTrade;
string iComment="";
int iIndicator[];

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
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   SkipDay=NumberOfSkipDay;
   iLossRisk=ISL;
   if(PreVolum!=0) tradeVolume=PreVolum;
   if(PreMaximumRisk!=0) MaximumRisk=PreMaximumRisk;
   iBalance=balance;

   ArrayResize(iIndicator,10);
//iIndicator[2] = iMA(_Symbol,_Period,5,0,MODE_EMA,PRICE_CLOSE);
//iIndicator[3] = iMA(_Symbol,_Period,5,5,MODE_EMA,PRICE_CLOSE);
   iIndicator[1]=iStochastic(_Symbol,_Period,3,6,13,MODE_EMA,STO_CLOSECLOSE);

//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
double sdOnNumber(double n1,double n2)
  {
   return MathAbs(n1-n2)/MathSqrt(2);
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
//|              Stochastic function                                 |
//+------------------------------------------------------------------+
string Stochastic()
  {
   double KArray[];
   double DArray[];

   ArraySetAsSeries(KArray,true);
   ArraySetAsSeries(DArray,true);

   CopyBuffer(iIndicator[1],0,0,3,KArray);
   CopyBuffer(iIndicator[1],1,0,3,DArray);

   double KValue0=KArray[0];
   double DValue0=DArray[0];

   double KValue1=KArray[1];
   double DValue1=DArray[1];

   double sdn=sdOnNumber(KValue0,80);
   double sdn2=sdOnNumber(DValue0,80);
   double lsdn=sdOnNumber(KValue0,20);
   double lsdn2=sdOnNumber(DValue0,20);

// if(KValue0>=80 && DValue1>=80)
//  {
   if(sdn<=3 && sdn2<=3)
     {
      return "sell";
     }
//  }
//else if(KValue0<=20 && DValue1<=20)
//  {
   if(lsdn<=3 && lsdn2<=3)
     {
      return "sell";
     }
// }

   return "";
  }
//+------------------------------------------------------------------+
//|              ShiftedMovingAverage function                       |
//+------------------------------------------------------------------+
string ShiftedMovingAverage(double Ask,double Bid)
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
   double sdn=NormalizeDouble(sdOnNumber(MAV0,SAV0),3);

   if(sdn<=NumberDeviation)
     {
      if(MAV0<Ask)
        {
         if(oSignal=="sell") return "";
         return "sell";
        }
      if(MAV0>Bid)
        {
         if(oSignal=="buy") return "";
         return "buy";
        }
     }
/*if(SAV0>SAV1 && MAV0<MAV1)
     {
      if(sdn<=NumberDeviation)
        {
         return "buy";
        }
     }
   else if(SAV0<SAV1 && MAV0>MAV1)
     {
      if(sdn<=NumberDeviation)
        {
         return "sell";
        }
     }*/
   return "";
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

      //iSignal=ShiftedMovingAverage(Ask,Bid);
      iSignal=Stochastic();

      if(iSignal=="sell")
        {
         //CalculatLoss(Bid,ORDER_TYPE_SELL);
         SL=NormalizeDouble(Bid+iLossRisk*_Point,_Digits);
         if(iTrade.Sell(tradeVolume,_Symbol,Bid,SL,0,NULL)) //Opens a long position 
           {
           }
        }
      else if(iSignal=="buy")
        {
         //CalculatLoss(Ask,ORDER_TYPE_BUY);
         SL=NormalizeDouble(Ask-iLossRisk*_Point,_Digits);
         if(iTrade.Buy(tradeVolume,_Symbol,Ask,SL,0,NULL)) //Opens a short position 
           {
           }
        }
     }
  }
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void trailing(int trailstop)
  {
   double stop;
   double take;
   int trail=trailstop;
   if(Digits()==3 || 5)
      trail=trail*10;
   if(PositionSelect(Symbol())==true && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_BUY)
     {
      stop = PositionGetDouble(POSITION_SL);
      take = PositionGetDouble(POSITION_TP);
      if(SymbolInfoDouble(Symbol(),SYMBOL_ASK)-trail*Point()>stop)
        {
         iTrade.sl=SymbolInfoDouble(Symbol(),SYMBOL_ASK)-trail*Point();
         iTrade.action=TRADE_ACTION_SLTP;
         iTrade.deviation=0;
         iTrade.symbol=Symbol();
         if(OrderSend(trade,info)==false)
            Print("OrderSend failed with error #",GetLastError());
        }
     }
   if(PositionSelect(Symbol())==true && PositionGetInteger(POSITION_TYPE)==POSITION_TYPE_SELL)
     {
      stop = PositionGetDouble(POSITION_SL);
      take = PositionGetDouble(POSITION_TP);
      if(SymbolInfoDouble(Symbol(),SYMBOL_BID)+trail*Point()<stop)
        {
         iTrade.sl=SymbolInfoDouble(Symbol(),SYMBOL_BID)+trail*Point();
         iTrade.action=TRADE_ACTION_SLTP;
         iTrade.deviation=0;
         iTrade.symbol=Symbol();
         if(OrderSend(trade,info)==false)
            Print("OrderSend failed with error #",GetLastError());
        }
     }
  }
//+------------------------------------------------------------------+
void CheckTrailingStop(double Ask,double Bid)
  {

   double l=0;
   int nl=0;
   int nw=0;
   double w=0;
   for(int ii=PositionsTotal()-1;ii>=0;ii--)
     {
      ulong ticket=PositionGetTicket(ii);
      double pdasr= PositionGetDouble(POSITION_PROFIT);
      if(pdasr>=0)
        {
         w+=MathAbs(pdasr);
         nw++;
        }
      else
        {
         l+=MathAbs(pdasr);
         nl++;
        }
     }

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
            //CalculatLoss(Bid,CurrentOrderType);
            SL=NormalizeDouble(Ask-(iLossRisk+((nw*w)-(nl*l)))*_Point,_Digits);
            if(CurrentStopLoss<SL)
              {
               iTrade.PositionModify(PositionTicket,SL,0);
              }
              } else {
            //CalculatLoss(Ask,CurrentOrderType);
            SL=NormalizeDouble(Bid+(iLossRisk+((nw*w)-(nl*l)))*_Point,_Digits);
            if(CurrentStopLoss>SL)
              {
               iTrade.PositionModify(PositionTicket,SL,0);
              }
           }
        }
     }
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
