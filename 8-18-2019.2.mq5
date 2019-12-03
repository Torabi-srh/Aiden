//+------------------------------------------------------------------+
//|                                                                  |
//|                           ALPARI OP                              |
//|                                                                  |
//+------------------------------------------------------------------+
/*
Name     : soroush trb
Type     : demo.ecn.mt5 (USD)
 Login: 50459234
 Password: 6LO3bi4DY
 Server: Alpari-MT5-Demo
Investor : idvy0cxn
*/
#property copyright ""
#property link      ""
#property version   "1.01"
#include<Trade\Trade.mqh>
//--- input parameters
input char     time_h_start=9;             // Trading start time
input char     time_h_stop=22;             // Trading stop time
input int      bands_period=1;             // Bollinger Bands period
input int      bands_shift=1;              // Bollinger Bands shift
input double   bands_diviation=32.3;       // Bollinger Bands deviations
input double   div_work=34.6;               // Deviation from signal
input double   div_signal=41.95;            // Undervaluation of the main signal
input bool     work_alt=true;              // Work with a position in case of an opposite signal
input int      take_profit=380;             // Take Profit
input int      stop_loss=900;              // Stop Loss
input double   minimum_balance=-1;        // Minimum balance to work if between 0 and 1 work as percentage
//---
input bool     mon=true;                   // Work on Monday
input bool     tue=true;                   // Work on Tuesday
input bool     wen=true;                   // Work on Wednesday
input bool     thu=true;                   // Work on Thursday
input bool     fri=false;                   // Work on Friday
//---
input long     magic_number=65758473787389;// Magic number
input double   order_volume=1.43;          // Lot size
input int      order_deviation=196;        // Deviation by position opening
//--- Variable
MqlDateTime time_now_str;
datetime time_now_var;
CTrade trade;
int bb_handle;
double bb_base_line[3];
double bb_upper_line[3];
double bb_lower_line[3];
bool work_day=true;
double start_balance;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   int chartPeriod = ChartPeriod(0);
   ChartSetSymbolPeriod(0, NULL, PERIOD_M1);
   ChartSetSymbolPeriod(0, NULL, chartPeriod);
   
   ChartOpen("EURUSD",0);
   trade.SetExpertMagicNumber(magic_number);
   trade.SetDeviationInPoints(order_deviation);
   trade.SetTypeFilling(ORDER_FILLING_FOK);
   trade.SetAsyncMode(false);
   start_balance=AccountInfoDouble(ACCOUNT_BALANCE);
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   double balance=AccountInfoDouble(ACCOUNT_BALANCE);
   if(minimum_balance<1 && minimum_balance>0)
     {
      if(start_balance<=balance*minimum_balance)
        {
         CloseAllPositions();
         return;
        }
        } else if(minimum_balance>=0) {
      if(start_balance<=minimum_balance)
        {
         CloseAllPositions();
         return;
        }
     }
//minimum_balance
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

   if(work==true && work_day==true) // work enabled
     {
      bb_handle=iBands(_Symbol,_Period,bands_period,bands_shift,bands_diviation,PRICE_CLOSE);       // find out the Bollinger Bands handle
      int i_bl=CopyBuffer(bb_handle,0,0,3,bb_base_line);
      int i_ul=CopyBuffer(bb_handle,1,0,3,bb_upper_line);
      int i_ll=CopyBuffer(bb_handle,2,0,3,bb_lower_line);
      if(i_bl==-1 || i_ul==-1 || i_ll==-1)
        {Alert("Error of copy iBands: base line=",i_bl,", upper band=",i_ul,", lower band=",i_ll);} // check the copied data

      double price_ask=SymbolInfoDouble(_Symbol,SYMBOL_ASK);
      double price_bid=SymbolInfoDouble(_Symbol,SYMBOL_BID);

      if(pos<1)
        {
         if((price_ask-(div_signal*_Point))>=bb_upper_line[2]-(div_work*_Point) && (price_ask-(div_signal*_Point))<=bb_upper_line[2]+(div_work*_Point)) // sell signal
           {
            trade.Sell(order_volume,_Symbol,price_bid,(price_bid+(stop_loss*_Point)),(price_bid-(take_profit*_Point)),"pos<1_sell");
           }
         if((price_bid+(div_signal*_Point))<=bb_lower_line[2]+(div_work*_Point) && (price_bid+(div_signal*_Point))>=bb_lower_line[2]-(div_work*_Point)) // buy signal
           {
            trade.Buy(order_volume,_Symbol,price_ask,(price_ask-(stop_loss*_Point)),(price_ask+(take_profit*_Point)),"pos<1_buy");
           }
        }
      if(pos>0 && work_alt==true)
        {
         if(trade.RequestType()==ORDER_TYPE_BUY)                                                                                                           // if there was a buy order before that
            if((price_ask-(div_signal*_Point))>=bb_upper_line[2]-(div_work*_Point) && (price_ask-(div_signal*_Point))<=bb_upper_line[2]+(div_work*_Point)) // sell signal
              {
               trade.PositionClose(_Symbol,order_deviation);
               trade.Sell(order_volume,_Symbol,price_bid,(price_bid+(stop_loss*_Point)),(price_bid-(take_profit*_Point)),"pos>0_sell");
              }
         if(trade.RequestType()==ORDER_TYPE_SELL)                                                                                                          // if there was a sell order before that
            if((price_bid+(div_signal*_Point))<=bb_lower_line[2]+(div_work*_Point) && (price_bid+(div_signal*_Point))>=bb_lower_line[2]-(div_work*_Point)) // buy signal
              {
               trade.PositionClose(_Symbol,order_deviation);
               trade.Buy(order_volume,_Symbol,price_ask,(price_ask-(stop_loss*_Point)),(price_ask+(take_profit*_Point)),"pos>0_buy");
              }
        }
     }
   else
     {
      if(pos>0)
        {
         trade.PositionClose(_Symbol,order_deviation);
        }
     }
  }
//+------------------------------------------------------------------+
void CloseAllPositions()
  {
   for(int i=PositionsTotal()-1;i>=0;i--)
     {
      ulong ticket=PositionGetTicket(i);
      trade.PositionClose(i);
     }
  }
//+------------------------------------------------------------------+
