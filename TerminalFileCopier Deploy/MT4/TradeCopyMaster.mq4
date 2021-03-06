//+------------------------------------------------------------------+
//|                                              TradeCopyMaster.mq4 |
//|                                            Copyright 2017, Jiunn |
//|                                            https://www.jiunn.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Jiunn"
#property link      "https://www.jiunn.com"
#property version   "1.03"
#property strict

#define TCM "CopyMaster"
string TCMfilename; 

#define CSV "OrdersReport.csv"
#define HEART_BEAT_INTERVAL 30

/*
CHANGELOG:

//ADDED 20180808: WriteCopyMasterFlagFile()
//20180813: OnDeinit Destroy Flag File(TCMfilename), Prevent Pushing OrderCSV from TerminalFileCopier if this TCM EA not running
//20180909: Added TimerIntervalSecs
*/


input int TimerIntervalSecs = 3; //3 secs 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   EventSetTimer(TimerIntervalSecs);

   GetAcctInfo();      
   Print(    "company=",company, " name=", name, " login=",login, " server=",server);
   
   TCMfilename = TCM +"-"+ login +".txt";
   WriteCopyMasterFlagFile();
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//--- destroy timer
   EventKillTimer();
   
   //Destroy Flag File
   if(FileIsExist(TCMfilename)) {FileDelete (TCMfilename);};
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   //if(iVolume(NULL,PERIOD_M1,0)<=1/*new minute*/) //Force a Refresh Evey Min
   
   static int LastAlertBar=0;
   if(iBars(NULL,PERIOD_M1)!=LastAlertBar)
   {
      LastAlertBar=iBars(NULL,PERIOD_M1);
      ForceWriteBook();
   }
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{
   RUN();
}

datetime LastWriteBrokerTime = 0;
int HeartBeat=HEART_BEAT_INTERVAL;

int CurrTotalOrders,LastTotalOrders;
int LastOrderPos, LastOrderNumber;
void RUN()
  {
//---

   if(TerminalInfoInteger(TERMINAL_TRADE_ALLOWED)==0)   {return;} //AUTO TRADING DISABLED CLICKED.
   
   if((HeartBeat--)<0){HeartBeat=HEART_BEAT_INTERVAL;}     //Update HeartBeat, Force a recount evey 60s
 
   
   //CHECK MASTER STATE
   //+------------------------------------------------------------------+
   COMPUTE_MASTER_STATE();
   
   //PUB DELTA
   CheckForFileKillCSV();                                                        //Force Re-write
   if(BookHasChanged & OrdersTotal()>0){ForceWriteBook();}                       //  
   if(LASTSTATE_BOOK==BOOK_RECOUNT)    {handleBOOK_BOOK_RECOUNT(); }
   if(CURRSTATE_BOOK==LASTSTATE_BOOK)  {handleBOOK_NO_CHANGE(); }
   if(CURRSTATE_BOOK==BOOK_EMPTY)      {handleBOOK_EMPTY();}
   //if(CURRSTATE_BOOK==BOOK_NO_CHANGE)  {handleBOOK_NO_CHANGE();}
   if(CURRSTATE_BOOK==BOOK_HAS_CHANGE) {handleBOOK_HAS_CHANGE();}

  
   //+------------------------------------------------------------------+
   
   
   //REPORT
   REPORT();
//   Comment
//   (
//      "OrderHash(Last/Curr): ", LastOrderHash , " / ", CurrOrderHash, " STATE(Last/Curr):",EnumToString(LASTSTATE_BOOK), " / ",   EnumToString(CURRSTATE_BOOK), "\n"
//      "HeartBeat: "+HeartBeat, "\n",      
//      "CurrTotalOrders: ", CurrTotalOrders 
//   
//   );
   //+------------------------------------------------------------------+
   

  
    
  }
//+------------------------------------------------------------------+
//| ChartEvent function                                              |
//+------------------------------------------------------------------+
void OnChartEvent(const int id,
                  const long &lparam,
                  const double &dparam,
                  const string &sparam)
  {
//---
   
  }
//+------------------------------------------------------------------+

void WriteEmptyBook(string filename="OrdersReport.csv")
{
   
   if(FileIsExist(filename)) {FileDelete(filename);}
   
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV,"\t"); 
   if(handle>0)
   {
      // write header 
      //FileWrite(handle,"#","symbol","lots","TP","SL"); 
      //FileWrite(handle,OrderTicket()+"|"+OrderSymbol()+"|"+OrderType()+"|"+OrderLots()+"|"+OrderTakeProfit()+"|"+OrderStopLoss()+"|"+OrderOpenTime()+"|"+OrderOpenPrice()); 
      FileWrite(handle,-1+"|NONE|-1|0|0|0|0|0"); // -1|NONE to denote EmptyMasterBook
      FileClose(handle);
   }
}




void WriteOrderBook(string filename="OrdersReport.csv")
{

   if(FileIsExist(filename)) {FileDelete(filename);}
   
   int handle=FileOpen(filename,FILE_WRITE|FILE_CSV,"\t"); 
   if(handle>0)
   {
      // write header 
      //FileWrite(handle,"#","symbol","lots","TP","SL"); 
      int total=OrdersTotal(); 
      // write open orders 
      for(int pos=0;pos<total;pos++) 
      { 
         if(OrderSelect(pos,SELECT_BY_POS)==false) continue; 
         if(OrderType()==OP_SELL||OrderType()==OP_BUY)            //Only Open Orders are For-Copy
         {
            OrderPrint();
            //FileWrite(handle,login+":"+OrderTicket()+"|"+OrderSymbol()+"|"+OrderType()+"|"+OrderLots()+"|"+OrderTakeProfit()+"|"+OrderStopLoss()); 
            FileWrite(handle,OrderTicket()+"|"+OrderSymbol()+"|"+OrderType()+"|"+OrderLots()+"|"+OrderTakeProfit()+"|"+OrderStopLoss()+"|"+OrderOpenTime()+"|"+OrderOpenPrice()); 
         
         }
      } 
      FileClose(handle);
   
   }
}

string company;
string name;
long login;
string server;
void GetAcctInfo()
{
   company=AccountInfoString(ACCOUNT_COMPANY); 
   name=AccountInfoString(ACCOUNT_NAME);      
   login=AccountInfoInteger(ACCOUNT_LOGIN);   
   server=AccountInfoString(ACCOUNT_SERVER); 
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

void COMPUTE_MASTER_STATE()
{
   BookHasChanged = IsOrdersTotalChanged();
   ComputeOpenOrders();
   if((ORDERTOTAL.TYPE[OP_SELL]+ORDERTOTAL.TYPE[OP_BUY])==0)
   {
      CURRSTATE_BOOK = BOOK_EMPTY; 
   }
   else
   {
      CURRSTATE_BOOK = CheckOrderNumHash();
   }

   if(HeartBeat<=0) {LASTSTATE_BOOK=BOOK_RECOUNT;}//Force a recount evey 60s
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int LastOrderHash,CurrOrderHash;
enum state_masterbook             {BOOK_ERR=-3,BOOK_LOCK=-2,BOOK_INIT=-1,BOOK_EMPTY,BOOK_NO_CHANGE,BOOK_HAS_CHANGE,BOOK_RECOUNT};



state_masterbook CURRSTATE_BOOK=BOOK_INIT;
state_masterbook LASTSTATE_BOOK=BOOK_INIT;
state_masterbook CheckOrderNumHash()
{
   //Returns True if OrderNumHash has changed.
   //static string OrderTypes[6] = {"OP_BUY", "OP_SELL", "OP_BUYLIMIT", "OP_SELLLIMIT", "OP_BUYSTOP",  "OP_SELLSTOP" };  
   static bool fLock=false;                                                         //function locker
   
   //Returns False if NoOrders, or if NoChange
   if(OrdersTotal()==0) {CurrOrderHash=0;return BOOK_EMPTY;}                     //return false if no orders
   if(fLock==true)      {return BOOK_LOCK;}                      //return false if Locked
   fLock=true;                                                   //LOCK
   
   CurrOrderHash=0;
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)            return BOOK_ERR;      //abandon
      CurrOrderHash+=OrderTicket();                                    //Hash by Summing Up Ticket#
   }//---------------------------
   
   fLock=false;                                                                     //un-LOCK
   
   //tri-state
   if(LastOrderHash==CurrOrderHash)    {                             return BOOK_NO_CHANGE;}  
   if(LastOrderHash!=CurrOrderHash)    {LastOrderHash=CurrOrderHash; return BOOK_HAS_CHANGE;}
   return ( BOOK_ERR );                                                             //ABEND
}
//
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleBOOK_EMPTY()
{
   //static datetime LastWriteBrokerTime = 0;
   //Print("handleBOOK_EMPTY->LastWriteBrokerTime:",LastWriteBrokerTime, " Elapsed: ", TimeGetElapsedDurationInSecs( LastWriteBrokerTime,TimeCurrent() ));
   //if(TimeGetElapsedDurationInSecs( LastWriteBrokerTime,TimeCurrent())>=HEART_BEAT_INTERVAL|| !FileIsExist(CSV) /*||BookHasChanged */  )
   if( !FileIsExist(CSV))
   { 
      WriteEmptyBook(CSV);
      LASTSTATE_BOOK=CURRSTATE_BOOK; 
      LastWriteBrokerTime = TimeLocal();  
   }  
   
   

}
//
void handleBOOK_BOOK_RECOUNT()
{
   //if(FileIsExist(CSV) ) {FileDelete(CSV);};    //Force a rewrite
   //if(CURRSTATE_BOOK==BOOK_EMPTY)      {handleBOOK_EMPTY();}
   //if(CURRSTATE_BOOK==BOOK_HAS_CHANGE) {handleBOOK_HAS_CHANGE();}   
   LASTSTATE_BOOK=CURRSTATE_BOOK;
}
//
void handleBOOK_NO_CHANGE()
{

}
//
void handleBOOK_HAS_CHANGE()
{
   //static datetime LastWriteBrokerTime = 0;
   //if(TimeGetElapsedDurationInSecs( LastWriteBrokerTime,TimeCurrent())>=HEART_BEAT_INTERVAL|| !FileIsExist(CSV) /*||BookHasChanged */ )
   if( !FileIsExist(CSV))
   { 
      WriteOrderBook(CSV);
      LASTSTATE_BOOK=CURRSTATE_BOOK; 
      LastWriteBrokerTime = TimeCurrent();  
   }     
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
struct orderstotal
  {
   int TotalOrders;
   int TotalOpenOrders,TotalOpenSellOrders,TotalOpenBuyOrders;
   int TYPE[6]; // = {0,0,0,0,0,0};           //Update total orders by ordertypes {"OP_BUY", "OP_SELL", "OP_BUYLIMIT", "OP_SELLLIMIT", "OP_BUYSTOP",  "OP_SELLSTOP" };
  };
orderstotal ORDERTOTAL;
void ComputeOpenOrders()
{
   //+------------------------------------------------------------------+
   for(int i=0;i<OrdersTotal();i++)
   {      
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)      continue;
      //+------------------------------------------------------------------+
      ORDERTOTAL.TYPE[OrderType()]++;                                         //no of occurrences of that ordertype
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void REPORT()
{
   Comment
   (
      "OrderHash(Last/Curr): ", LastOrderHash , " / ", CurrOrderHash, " STATE(Last/Curr):",EnumToString(LASTSTATE_BOOK), " / ",   EnumToString(CURRSTATE_BOOK), "\n"
      "HeartBeat: "+HeartBeat, "\n",      
      "CurrTotalOrders: ", CurrTotalOrders 
   
   );
   
}   


double TimeGetElapsedDurationInSecs(datetime t0, datetime t1)//t0=earlier time. else wrong datetime error
{
   return ((double)( t1-t0));
}

bool BookHasChanged;
bool IsOrdersTotalChanged()
{
   CurrTotalOrders = OrdersTotal();
   if(CurrTotalOrders!=LastTotalOrders)
   {
      LastTotalOrders=CurrTotalOrders;
      return true;
   }
   return false;
}


void KillCSV()
{
   if(FileIsExist(CSV)) {FileDelete(CSV);}
}

void CheckForFileKillCSV()
{
   //State is Stale, Force Re-write
   if(BookHasChanged)                                                                           {KillCSV(); return;}    
   if(TimeGetElapsedDurationInSecs( LastWriteBrokerTime,TimeCurrent())>=HEART_BEAT_INTERVAL)    {KillCSV(); return;}    
}


void ForceWriteBook()
{
   WriteOrderBook(CSV);
   LASTSTATE_BOOK=CURRSTATE_BOOK; 
   LastWriteBrokerTime = TimeCurrent();  
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//ADDED 20180808: WriteCopyMasterFlagFile()
void WriteCopyMasterFlagFile()
{

   if(FileIsExist(TCMfilename)) {FileDelete (TCMfilename);};
   int handle=FileOpen(TCMfilename,FILE_WRITE|FILE_TXT,"\t"); 
   if(handle>0)
   {
      // write header 
      FileWrite(handle,login); 
      FileClose(handle);
   }
}
