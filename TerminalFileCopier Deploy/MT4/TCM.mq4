//+------------------------------------------------------------------+
//|                                                          TCM.mq4 |
//|                                            Copyright 2018, Jiunn |
//|                                            https://www.jiunn.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Jiunn"
#property link      "https://www.jiunn.com"
#property version   "1.00"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

/*

20181510


*/
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

#include <TradeCopy\File.mqh>
#include <TradeCopy\Info.mqh>
#include <TradeCopy\Orders.mqh>
#include <TradeCopy\TimeDate.mqh>
#include <TradeCopy\Timer.mqh>
#include <TradeCopy\WebGet.mqh>

#define TCM "CopyMaster"

#define CSV "OrdersReport.csv"
//#define CSV "OrderBook.csv"

#define OBS "OrderBookState"  //OrderTicketSumHash: OrderBookState-2550238018.txt

#define TIMER_INTERVAL_SECS   1
#define HEART_BEAT_INTERVAL   30
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

string TCMfilename; 
int HeartBeat=HEART_BEAT_INTERVAL;
datetime LastWriteBrokerTime = 0;
datetime LastWriteLocalTime = 0;
long COUNTER = -1;
datetime BOOK_HAS_CHANGE_FILE_WRITE_TIME;
string BOOK_HAS_CHANGE_FILENAME;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

#define WRITE_ORDERBOOKSTATE_ZERO   WriteFlagFile((OBS +"-"+ OrdersTotal() + "-"+ 0 +".txt")                     ,login); //OrderTicketSumHash: OrderBookState-0-0.txt
#define WRITE_ORDERBOOKSTATE_HASH   WriteFlagFile((OBS +"-"+ OrdersTotal() + "-"+ CurrOrderTicketSumHash +".txt"),login); //OrderTicketSumHash: OrderBookState-3-2550238018.txt

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   TrySetTimer(TIMER_INTERVAL_SECS); //EventSetTimer(TIMER_INTERVAL_SECS);

   GetAcctInfo();      
   Print(    "company=",company, " name=", name, " login=",login, " server=",server);
   
   TCMfilename = TCM +"-"+ login +".txt";
   WriteFlagFile(TCMfilename,login); //CopyMaster-2089970835.txt
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   EventKillTimer();
   KillFile(TCMfilename);
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
  {
      //+------------------------------------------------------------------+
      static bool fLock=false;                                             //function locker
      if(fLock==true)      {return ;}                                      //return if Locked
      fLock=true;     
      //+------------------------------------------------------------------+
      
      //+------------------------------------------------------------------+
      //
      COUNTER--;
      RUN();   
      //
      //+------------------------------------------------------------------+
      
      
      //+------------------------------------------------------------------+
      fLock=false;              
      //+------------------------------------------------------------------+
  }
//+------------------------------------------------------------------+







//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void RUN()
  {
//---

   //+------------------------------------------------------------------+
   //AUTO TRADING DISABLED CLICKED.
   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0)   {return;} 
   
   //+------------------------------------------------------------------+
   //COUNT HEARTBEAT
   //if((HeartBeat--)<0){HeartBeat=HEART_BEAT_INTERVAL;}     //Update HeartBeat, Force a recount evey 60s
    
   //+------------------------------------------------------------------+
   //CHECK STATE
   COMPUTE_BOOK_STATE();

   //+------------------------------------------------------------------+   
   MOD_BOOK_STATE();
   
   //+------------------------------------------------------------------+   
   //HANDLE STATE
   HANDLE_BOOK_STATE();
  
   //+------------------------------------------------------------------+
   //REPORT
   REPORT();

   //+------------------------------------------------------------------+
    
  }
  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void COMPUTE_BOOK_STATE()
{
   //+------------------------------------------------------------------+
   ComputeOpenOrders();
   
   //+------------------------------------------------------------------+
   BookHasChanged = IsOrdersTotalChanged()||IsLastOrderTicketChanged()||IsFirstOrderTicketChanged();
   
   //+------------------------------------------------------------------+
   if((ORDERTOTAL.TYPE[OP_SELL]+ORDERTOTAL.TYPE[OP_BUY])==0)
   {
      CURRSTATE_BOOK = BOOK_EMPTY; 
   }
   else
   {
      CURRSTATE_BOOK = CheckOrderNumHash(); //Can have issue if ordernum is too long
   }

   if(COUNTER<0) {CURRSTATE_BOOK=BOOK_STALE;} //No new orders, and last order is Older than 1 minute.
   
   //+------------------------------------------------------------------+   
   //if(HeartBeat<=0) {LASTSTATE_BOOK=BOOK_RECOUNT;}//Force a recount evey 60s
   //if((COUNTER>=0) && (COUNTER%10==0)  ) {LASTSTATE_BOOK=BOOK_RECOUNT;}//Force a recount evey 60s
    
}  
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void MOD_BOOK_STATE()
{
   if(BookHasChanged||CURRSTATE_BOOK==BOOK_HAS_CHANGE)
   {
      //Set Pump for 60 seconds in intervals of 10 when BOOK_NO_CHANGE
      COUNTER=60; 
      BOOK_HAS_CHANGE_FILE_WRITE_TIME = TimeLocal();
      BOOK_HAS_CHANGE_FILENAME =  GetOrderReportFileName(BOOK_HAS_CHANGE_FILE_WRITE_TIME,CurrOrderTicketSumHash); //OrderBook-20181015184701-123456.csv
      CURRSTATE_BOOK==BOOK_HAS_CHANGE;
      return;
   }

   //if IS NOT (BOOK_HAS_CHANGE) REPEAT BROADCAST for the 1st 60secs
   //if(COUNTER>=50)
   //{
   //   if(COUNTER  ==58)  {CURRSTATE_BOOK=BOOK_REPEAT_BROADCAST; return;}   
   //   if(COUNTER%3==0 )  {CURRSTATE_BOOK=BOOK_REPEAT_BROADCAST; return;}   
   //}
   if(COUNTER>=30)
   {
      if(COUNTER%5==0)  {CURRSTATE_BOOK=BOOK_REPEAT_BROADCAST; return;}   
   } 
   if(COUNTER>=0)
   {
      if(COUNTER%10==0) {CURRSTATE_BOOK=BOOK_REPEAT_BROADCAST; return;}   
   }        

   //if((COUNTER>=0)   && (COUNTER%10==0)  ){ForceWriteBook(CSV); return;}   
   ////else   
   //if(BookHasChanged && (OrdersTotal()>0)){ForceWriteBook(CSV);  return;}  

}
//---

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
ulong LastOrderTicketSumHash,CurrOrderTicketSumHash;
enum state_masterbook             {BOOK_ERR=-3,BOOK_LOCK=-2,BOOK_INIT=-1,BOOK_EMPTY,BOOK_NO_CHANGE,BOOK_HAS_CHANGE,BOOK_RECOUNT,BOOK_REPEAT_BROADCAST,BOOK_STALE/*More than a minute*/};



state_masterbook CURRSTATE_BOOK=BOOK_INIT;
state_masterbook LASTSTATE_BOOK=BOOK_INIT;
state_masterbook CheckOrderNumHash()
{
   //Returns True if OrderNumHash has changed.
   //static string OrderTypes[6] = {"OP_BUY", "OP_SELL", "OP_BUYLIMIT", "OP_SELLLIMIT", "OP_BUYSTOP",  "OP_SELLSTOP" };  
   static bool fLock=false;                                                               //function locker
   
   //Returns False if NoOrders, or if NoChange
   //********************************
   if(OrdersTotal()==0) {CurrOrderTicketSumHash=0;return BOOK_EMPTY;}                     //return false if no orders
   //********************************
   
   if(fLock==true)      {return BOOK_LOCK;}                                               //return false if Locked
   fLock=true;                                                                            //LOCK
   
   CurrOrderTicketSumHash=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)            return BOOK_ERR;     //abandon
      if(OrderType()==OP_BUY||OrderType()==OP_SELL)                                       //ONLY OPEN ORDERS ********************************
      {
         CurrOrderTicketSumHash+=OrderTicket();                                           //Hash by Summing Up Ticket#
      }
   }//---------------------------
   
   fLock=false;                                                                           //un-LOCK
   
   //tri-state
   if(LastOrderTicketSumHash==CurrOrderTicketSumHash)    {                                               return BOOK_NO_CHANGE;}  
   if(LastOrderTicketSumHash!=CurrOrderTicketSumHash)    {LastOrderTicketSumHash=CurrOrderTicketSumHash; return BOOK_HAS_CHANGE;}
   return ( BOOK_ERR );                                                                   //ABEND
}
//
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void HANDLE_BOOK_STATE()
{
   if(CURRSTATE_BOOK==BOOK_HAS_CHANGE)          {handleBOOK_HAS_CHANGE();}                 
   if(CURRSTATE_BOOK==LASTSTATE_BOOK)           {handleBOOK_NO_CHANGE(); }
   if(LASTSTATE_BOOK==BOOK_RECOUNT)             {handleBOOK_BOOK_RECOUNT(); }
   if(CURRSTATE_BOOK==BOOK_EMPTY)               {handleBOOK_EMPTY();}
   if(CURRSTATE_BOOK==BOOK_REPEAT_BROADCAST)    {handleBOOK_REPEAT_BROADCAST();}
   if(CURRSTATE_BOOK==BOOK_STALE)               {handleBOOK_STALE();}
}
//+------------------------------------------------------------------+
void handleBOOK_HAS_CHANGE()
{
   //if(COUNTER<55) //make sure immediate write if new
   //{
   //   if(FileIsExist(CSV)) return; //already there
   //}
   
   //KillFile(BOOK_HAS_CHANGE_FILENAME);//KillFile(CSV);
   //WriteOrderBook(BOOK_HAS_CHANGE_FILENAME);//WriteOrderBook(CSV);
   //WRITE_ORDERBOOKSTATE_HASH; 
   
   KillFile(CSV);
   WriteOrderBook(CSV);
   UpdateStateLastWrite();
}

//+------------------------------------------------------------------+
void handleBOOK_NO_CHANGE(){}
//+------------------------------------------------------------------+
void handleBOOK_BOOK_RECOUNT()
{
   LASTSTATE_BOOK=CURRSTATE_BOOK;
}
//+------------------------------------------------------------------+
void handleBOOK_EMPTY()    //WRITE A (-1) OrderBook.csv to force client to CloseAll
{
   //if(FileIsExist(CSV)) return; //already there
   if(COUNTER%5==0)  
   {
      WriteEmptyBook(BOOK_HAS_CHANGE_FILENAME); //WriteEmptyBook(CSV);
      WRITE_ORDERBOOKSTATE_ZERO; 
      
      UpdateStateLastWrite();
   }   
}
//+------------------------------------------------------------------+
void handleBOOK_REPEAT_BROADCAST()
{
   
   //KillFile(BOOK_HAS_CHANGE_FILENAME);//KillFile(CSV);
   //WriteOrderBook(BOOK_HAS_CHANGE_FILENAME);//WriteOrderBook(CSV);
   //WRITE_ORDERBOOKSTATE_HASH; 
   
   KillFile(CSV);
   WriteOrderBook(CSV);
   UpdateStateLastWrite();

}
//+------------------------------------------------------------------+
void handleBOOK_STALE()
{
   //KillFile(BOOK_HAS_CHANGE_FILENAME);
   KillFile(CSV);
}





//void ForceWriteBook(string filename="OrderBook.csv")
//{
//   WriteOrderBook(filename);
//   WRITE_ORDERBOOKSTATE_HASH; 
//   
//   UpdateStateLastWrite();
//}


void UpdateStateLastWrite()
{
   LASTSTATE_BOOK=CURRSTATE_BOOK; 
   LastWriteBrokerTime = TimeCurrent();  
   LastWriteLocalTime = TimeLocal();
}











//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void REPORT()
{
   Comment
   (
      "COUNTER: ",COUNTER,   "CurrTotalOrders: ",CurrTotalOrders,       "\n",
      "STATE(Last/Curr):",EnumToString(LASTSTATE_BOOK), " / ",   EnumToString(CURRSTATE_BOOK), "\n",
      "##Hash(Last/Curr): ", LastOrderTicketSumHash , " / ", CurrOrderTicketSumHash,  "\n",       
      "LastWriteLocalTime:", TimeToStr( LastWriteLocalTime,TIME_DATE|TIME_SECONDS)
   
   );
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+


