//+------------------------------------------------------------------+
//|                                         TradeCopyClientLocal.mq4 |
//|                                            Copyright 2018, Jiunn |
//|                                            https://www.jiunn.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2018, Jiunn"
#property link      "https://www.jiunn.com"
#property version   "1.03"
#property strict

#include <stderror.mqh> 
#include <stdlib.mqh> 


/*
CHANGELOG:
20180719:handleCLIENT_BOOK_IS_DIFF(); ignore MANUAL trades *******************
20180804: Random Sleep 100-300 ms to prevent concurrency
//ADDED Line 82: 20180806 Retry cannot set timer error
//ADDED 20180808: WriteCopyClientFlagFile()
//20180813: OnDeinit Destroy Flag File(TCCfilename), Prevent Taking OrderCSV from TerminalFileCopier if this TCC EA not running
//ADDED 20180908 Prevent jamming with Sleep Random range from 0.5s to 1.0s 
*/

/*
// -1|NONE to denote EmptyMasterBook
Ordercomment with Master's orderticket
useminlot
usewebget; filecopy
OPENTIME_TOO_FAR(staleness=60s), close orders will not re-open
Manual Trades Not Allowed, will be deleted upon sync to Master.
Master cannot do partial close - ordernum becomes different, will trigger a full close in client, but no new partial opens as Master(OrderNum is diff, but OpenTime is oldtime)

*/


/*
Logging of MarginLevels, OrderBook, OrderSend

*/

//mql OrderSend failed with error #149  -- NO HEDGING

#define TCC "CopyClient"
string TCCfilename; 


#define TIMER_INTERVAL_SECS   1

#define MAX_ORDER_OPEN_STALE_SECS 60

input bool UseWebGet = false;
input bool UseMinLot = false;
/*input*/ bool UseNoLateOpen = true;
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#define CSV "OrdersReport.csv"
//enum state_masterbook            {BOOK_ERR=-3,BOOK_LOCK=-2,BOOK_INIT=-1,BOOK_EMPTY,BOOK_NO_CHANGE,BOOK_HAS_CHANGE};
enum copy_state                  {NEW,EXIST,NOTFOUND,MODIFIED,DELETED,CLOSED,OPENPRICE_TOO_FAR,OPENTIME_TOO_FAR};

struct order
  {
       string Key; //PK,FK
       int ticket; //PK,FK
       string symbol; 
       int cmd;
       double lots; 
       double   TP;
       double SL; 
       datetime OpenTime;
       double OpenPrice;       
       
  }SOURCE_ORDER;
  
order MASTER_ORDERS[];

int CurrTotalOrders,LastTotalOrders;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//--- create timer
   //EventSetTimer(1);
   //EventSetMillisecondTimer(500);
   
   
   //ADDED: 20180806 Retry cannot set timer error
   //https://www.mql5.com/ru/forum/167394 mql cannot set timer error
   int error=-1;
   int counter=1;
   do
   {
      ResetLastError();
      EventSetTimer(TIMER_INTERVAL_SECS); //every 1secs
      
      error=GetLastError();
      Print("EventSetTimer. Attempt=",counter," Error=",error, " ", ErrorDescription(error));
      if(error!=0) Sleep(1000);
      if(counter++>10)
      {
         Alert("Error", ErrorDescription(error),"(",error,") Tries=",counter );      
         break;
      }
      
   }
   while(error!=0 && !IsStopped());
   
   
   GetAcctInfo();     
   Print(    "company=",company, " name=", name, " login=",login, " server=",server, "IsRightBroker=",IsRightBroker("AXI"));
   
   TCCfilename = TCC +"-"+ login +".txt";
   WriteCopyClientFlagFile();
   
      
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
   
   //20180813: Destroy Flag File, Prevent Taking OrderCSV if this EA not running
   if(FileIsExist(TCCfilename)) {FileDelete (TCCfilename);};
      
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
//---


   RUN_COPYCLIENT();
   

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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

int MASTER_BOOK_SIZE;
string CommStr;

void RUN_COPYCLIENT()
{
   static bool fLock=false;                                             //function locker
   if(fLock==true)      {return ;}                                      //return if Locked
   fLock=true;                                                          //LOCK   
   //+------------------------------------------------------------------+
   //INIT
   //checkbroker

   //ADDED 20180908 Prevent jamming with Sleep Random range from 0.5s to 1.5s 
   Sleep(MathRandomRange(500,1000)); //Sleep Random range from 0.5s to 1.0s
   
   //+------------------------------------------------------------------+
   //CLEAN
   ArrayFree(MASTER_ORDERS);
   MASTER_BOOK_SIZE=0;
   CommStr = "";
   
   //+------------------------------------------------------------------+
   //WEB FETCH?
   if(UseWebGet)
   {
      if(WebGet()==false)return;//Fetch, abend if err(false)   
   }
   
   //+------------------------------------------------------------------+
   //CHECK STATE
   COMPUTE_CLIENT_STATE();
   
   
   
   if(CURRCLIENT_STATE==CLIENT_NO_CSV)          {;}//DO nothing if CSV not found.
   if(CURRCLIENT_STATE==CLIENT_EMPTY_CSV)       {;}//DO nothing if CSV is empty.
   
   if(CURRCLIENT_STATE==CLIENT_BOOK_EMPTY)      {handleCLIENT_BOOK_EMPTY();}//CLOSEALL
   if(CURRCLIENT_STATE==CLIENT_BOOK_IS_SAME)    {;}
   if(CURRCLIENT_STATE==CLIENT_BOOK_IS_DIFF)    {handleCLIENT_BOOK_IS_DIFF();}
   
   //+------------------------------------------------------------------+
   //REPORT
   Comment
   (
     "MASTER_BOOK_SIZE=",MASTER_BOOK_SIZE + "\n",
     "OrderHas(Master/Client): ", MasterHash , " / ", ClientHash, " STATE:",EnumToString(CURRCLIENT_STATE) + "\n",
     "CurrTotalOrders: ", CurrTotalOrders,"\n",
     CommStr
   
   );
   
   //+------------------------------------------------------------------+
   //DONE AND DELETE 
   if(FileIsExist(CSV)) {FileDelete (CSV);};
   fLock=false;                                                                     //un-LOCK
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int MASTER_BOOK[6] = {0,0,0,0,0,0};  
copy_state CheckOrderExistOnMasterTable(int orderNumOfMaster)
{
   //check if client order is found on the CSV file 
   for(int j=0;j<ArraySize(MASTER_ORDERS);j++)
   {
       if(MASTER_ORDERS[j].ticket==orderNumOfMaster) return EXIST;
   }
   return NOTFOUND;
   
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
copy_state CheckOrderFollowed(int orderNumMaster)
{
   for(int i=0;i<OrdersTotal();i++) 
   { 
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES))
      {
       //Print("OrderMagicNumber="+OrderMagicNumber() + " == " + "orderNumMaster=" +orderNumMaster + "?"+OrderMagicNumber()==orderNumMaster );
       if(OrderMagicNumber()==orderNumMaster) return EXIST;
      }
   } 
   return NEW;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//void OrderCopySend(string key, string symbol ,int cmd, double lots,int slippage,double stoploss,double takeprofit,string comment="",int magicnum=0,datetime  expiration=0,color clrArrow=clrBlack)
void OrderCopySend(int ticket, string symbol ,int cmd, double lots,int slippage,double stoploss,double takeprofit,string comment="",int magicnum=0,datetime  expiration=0,color clrArrow=clrBlack)
{

   //Uses Source OrderTicket as PK for Ref, and writes it to MagicNum.
   RefreshRates();
   //Print("OrderCopySend:SOURCE_ORDER.ticket="+SOURCE_ORDER.ticket);
   double price = cmd == 0 ? Ask:Bid;
   if(UseMinLot) { lots = MarketInfo(Symbol(),MODE_MINLOT); }
   
   //int ticket=OrderSend(SOURCE_ORDER.symbol,SOURCE_ORDER.cmd,SOURCE_ORDER.lots,NormalizeDouble(price,(int)MarketInfo(SOURCE_ORDER.symbol,MODE_DIGITS)),3,SOURCE_ORDER.SL,SOURCE_ORDER.TP,SOURCE_ORDER.ticket,SOURCE_ORDER.ticket,0,clrGreen); 
   //Print(symbol,cmd,lots,NormalizeDouble(price,(int)MarketInfo(symbol,MODE_DIGITS)) ,slippage,stoploss,takeprofit,(string)ticket,ticket,expiration,clrArrow); 
   int newticket =OrderSend(symbol,cmd,lots,NormalizeDouble(price,(int)MarketInfo(symbol,MODE_DIGITS)) ,slippage,stoploss,takeprofit,(string)ticket,ticket,expiration,clrArrow); 
   
   
   //Print(symbol,cmd,lots,NormalizeDouble(price,(int)MarketInfo(symbol,MODE_DIGITS)) ,slippage,stoploss,takeprofit,key,(int) GetTicketNumberFromKey(key, ":"),expiration,clrArrow); 
   //int ticket=OrderSend(symbol,cmd,lots,NormalizeDouble(price,(int)MarketInfo(symbol,MODE_DIGITS)) ,slippage,stoploss,takeprofit,key,(int) GetTicketNumberFromKey(key, ":"),expiration,clrArrow); 

   
   if(newticket<0) 
   { 
   Print("OrderSend failed with error #",GetLastError()); 
   } 
   else 
   Print("OrderSend placed successfully"); 

}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//extern string FileName = "OrdersReport.csv";
int ReadCSV()
{
   int row=0;
   int hnd=FileOpen(CSV,FILE_CSV|FILE_READ,"|");
   if(hnd>0)
   {
     while(True)
     {
      

      
      string field1 = FileReadString (hnd);
      if(StringLen(field1)>0)
      {
         int size=ArraySize(MASTER_ORDERS);
         ArrayResize(MASTER_ORDERS,size+1);           //resize
      
         MASTER_ORDERS[size].ticket = (int)field1; // FileReadString (hnd);   //--- read first column
         //MASTER_ORDERS[size].Key = field1; // FileReadString (hnd);   //--- read first column
         //MASTER_ORDERS[size].ticket =(int) GetTicketNumberFromKey(field1, ":"); // FileReadString (hnd);   //--- read first column
         MASTER_ORDERS[size].symbol = FileReadString (hnd);   //--- read second column
         MASTER_ORDERS[size].cmd = (int) FileReadString (hnd);   //--- read third column
         MASTER_ORDERS[size].lots = (double)FileReadString (hnd);   //--- read fourth column
         MASTER_ORDERS[size].TP =  (double) FileReadString (hnd);   //--- read fifth column
         MASTER_ORDERS[size].SL = (double)FileReadString (hnd);   //--- read sixth column       
         MASTER_ORDERS[size].OpenTime =  StringToTime(FileReadString (hnd));   //--- read seventh column
         MASTER_ORDERS[size].OpenPrice = (double)FileReadString (hnd);   //--- read eight column         
      }


       
       
        
       if(FileIsEnding(hnd)) break;
       if(FileIsLineEnding(hnd))
       {
         row++;
       }
     }
     FileClose(hnd);
     

   }
   else
   {
     Comment("File "+CSV+" not found, the last error is ", GetLastError());
     
   }
   
   return ArraySize(MASTER_ORDERS);
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
bool WebGet() 
  { 
   string cookie=NULL,headers; 
   char post[],result[]; 
   int res; 
//--- to enable access to the server, you should add URL "https://www.google.com/finance" 
//--- in the list of allowed URLs (Main Menu->Tools->Options, tab "Expert Advisors"): 
   string google_url="http://209.50.53.212/OrdersReport.csv"; 
   //string google_url="http://127.0.0.1/OrdersReport.csv"; 
//--- Reset the last error code 
   ResetLastError(); 
//--- Loading a html page from Google Finance 
   int timeout=5000; //--- Timeout below 1000 (1 sec.) is not enough for slow Internet connection 
   res=WebRequest("GET",google_url,cookie,NULL,timeout,post,0,result,headers); 
   //res=WebRequest("GET",google_url,cookie,"http://limpei/\r\nCache-Control: no-cache, no-store, must-revalidate\r\n",timeout,post,0,result,headers); 
//--- Checking errors 
   if(res==-1) 
     { 
      int errcode = GetLastError();
      string errtxt = "Error in WebRequest:"+ ErrorDescription(errcode) + "("+(string)errcode+")";
      Print("Error in WebRequest. Error code  =",errcode); 
      //--- Perhaps the URL is not listed, display a message about the necessity to add the address 
      MessageBox("login:"+(string)login+"\r\nAdd the address '"+google_url+"' in the list of allowed URLs on tab 'Expert Advisors'",errtxt,MB_ICONINFORMATION);
      return false; 
     } 
   else 
     { 
      //--- Load successfully 
      PrintFormat("The file has been successfully loaded, File size =%d bytes.",ArraySize(result)); 
      //--- Save the data to a file 
      int filehandle=FileOpen("OrdersReport.csv",FILE_WRITE|FILE_BIN); 
      //--- Checking errors 
      if(filehandle!=INVALID_HANDLE) 
        { 
         //--- Save the contents of the result[] array to a file 
         FileWriteArray(filehandle,result,0,ArraySize(result)); 
         //--- Close the file 
         FileClose(filehandle); 
        } 
      else Print("Error in FileOpen. Error code=",GetLastError()); 
     } 
     
     
     return true; //success
  }


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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


bool IsRightBroker(string rb="AXI")
{
   //string rb = "AIMS";
   StringToUpper(server);
   StringToUpper(rb);
   int pos = StringFind(server,rb,0);  
   return (pos>-1);
}


string GetTicketNumberFromKey(string str, string SepCharStr = ":")
{
      string result[];                        // An array to get strings
      ushort u_sep;
      //-------------------------
      u_sep=StringGetCharacter(SepCharStr,0); //--- Get the separator code
      int j=StringSplit(str,u_sep,result);
      if(j>0)
      {
         return result[1]; //2202020:123456, Login:Ticket
      }
      return str;
}

double TimeGetElapsedDurationInSecs(datetime t0, datetime t1)//t0=earlier time. else wrong datetime error
{
   return ((double)( t1-t0));
}


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+

struct orderhash
  {
      int LastOrderHash,CurrOrderHash;   
  };


enum state_clientbook            {CLIENT_EMPTY_CSV=-11,CLIENT_NO_CSV=-10,CLIENT_BOOK_ERR=-3,CLIENT_BOOK_LOCK=-2,CLIENT_INIT=-1,CLIENT_BOOK_EMPTY,CLIENT_BOOK_IS_SAME,CLIENT_BOOK_IS_DIFF,CLIENT_BOOK_MORE,CLIENT_BOOK_LESS, };

orderhash CLIENT;
state_clientbook CURRCLIENT_STATE=CLIENT_INIT;
state_clientbook CheckOrderMagicNumHash()
{
   //Returns True if OrderNumHash has changed.
   //static string OrderTypes[6] = {"OP_BUY", "OP_SELL", "OP_BUYLIMIT", "OP_SELLLIMIT", "OP_BUYSTOP",  "OP_SELLSTOP" };  
   static bool fLock=false;                                                         //function locker

   //Returns False if NoOrders, or if NoChange
   if(OrdersTotal()==0) {return CLIENT_BOOK_EMPTY;}                     //return false if no orders
   if(fLock==true)      {return CLIENT_BOOK_LOCK;}                      //return false if Locked
   fLock=true;                                                   //LOCK
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false)            return CLIENT_BOOK_ERR;      //abandon
      CLIENT.CurrOrderHash+=OrderMagicNumber();                             //Hash by Summing Up OrderMagicNumber
   }//---------------------------
   
   fLock=false;                                                                     //un-LOCK
   
   //tri-state
   if(CLIENT.CurrOrderHash==CLIENT.LastOrderHash)    {                                             return CLIENT_BOOK_IS_SAME; }  
   if(CLIENT.CurrOrderHash!=CLIENT.LastOrderHash)    {                                             return CLIENT_BOOK_IS_DIFF;} 
   //if(CLIENT.CurrOrderHash> CLIENT.LastOrderHash)    {CLIENT.LastOrderHash=CLIENT.CurrOrderHash;   return CLIENT_BOOK_MORE;}
   //if(CLIENT.CurrOrderHash< CLIENT.LastOrderHash)    {CLIENT.LastOrderHash=CLIENT.CurrOrderHash;   return CLIENT_BOOK_LESS;}
   return ( CLIENT_BOOK_ERR );                                                                            //ABEND
}
//


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int ClientHash,MasterHash;
void COMPUTE_CLIENT_STATE()
{

   BookHasChanged = IsOrdersTotalChanged();
   
   if(FileIsExist(CSV)==false)                     {CURRCLIENT_STATE=CLIENT_NO_CSV;return;}
   
   //+------------------------------------------------------------------+
   //READ CSV if exist
   MASTER_BOOK_SIZE=ReadCSV();//Parse
   
   //IF EMPTY CSV
   if(MASTER_BOOK_SIZE==0 ||MASTER_BOOK_SIZE==NULL){CURRCLIENT_STATE=CLIENT_EMPTY_CSV;return;}   
   //+------------------------------------------------------------------+
   
   //IF CLIENT_BOOK_EMPTY, NO MASTER ORDERS
   if(MASTER_ORDERS[0].ticket==-1)                 {CURRCLIENT_STATE=CLIENT_BOOK_EMPTY;return;}   // -1|NONE to denote EmptyMasterBook
   
   //+------------------------------------------------------------------+
   //IF NON-EMPTY, check for Master-Client Book Diff   
   ClientHash = CalcOrderMagicNumHash();
   MasterHash = CalcMasterOrderNumHash();
   //+------------------------------------------------------------------+
   //CURRCLIENT_STATE = CLIENT_BOOK_IS_SAME,CLIENT_BOOK_MORE,CLIENT_BOOK_LESS,CLIENT_BOOK_ERR;
   if(ClientHash!=MasterHash)                      {CURRCLIENT_STATE=CLIENT_BOOK_IS_DIFF;return;}
   if(ClientHash==MasterHash)                      {CURRCLIENT_STATE=CLIENT_BOOK_IS_SAME; return;}
  
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int CalcOrderMagicNumHash()
{
   static bool fLock=false;                                             //function locker
   int sum=0;
   
   if(OrdersTotal()==0) {return 0;  }                                   //return 0 if no orders
   if(fLock==true)      {return -1; }                                   //return -1 if Locked
   fLock=true;                                                          //LOCK
   for(int i=0;i<OrdersTotal();i++)
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) return -1;    //abandon
      sum+=OrderMagicNumber();                                          //Hash by Summing Up OrderMagicNumber
   }//---------------------------
   fLock=false;                                                         //un-LOCK
   return(sum);
}
//

int CalcMasterOrderNumHash()
{
   //MASTER_BOOK_SIZE=ArraySize(MASTER_ORDERS);
   int sum=-1;
   for(int jj=0;jj<MASTER_BOOK_SIZE;jj++)
   {
       CommStr += (string)MASTER_ORDERS[jj].ticket+"\n";
       sum     += MASTER_ORDERS[jj].ticket;
   }
   return sum;
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleCLIENT_BOOK_EMPTY()
{
   CloseAllOpenEATrades();
   //CloseAllOpenTrades();
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void handleCLIENT_BOOK_IS_DIFF()
{

   //+------------------------------------------------------------------+
   //DELETE EXCESS POSITIONS IN FOLLOWER CURRBOOK
   for(int j=0;j<OrdersTotal();j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
      {
         if(OrderMagicNumber()==0)continue; //20180719:ignore MANUAL trades ********************************
         copy_state OrderCopyState =  CheckOrderExistOnMasterTable(OrderMagicNumber());
         if(OrderCopyState ==NOTFOUND) { bool b = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble((Bid+Ask)/2,(int)MarketInfo(OrderSymbol(),MODE_DIGITS)),5 ); }
      }
   }
   
   //+------------------------------------------------------------------+
   //SYNC MASTER TO CLIENT
   for(int i=0;i<MASTER_BOOK_SIZE;i++)
   {   
     copy_state OrderCopyState =  CheckOrderFollowed(MASTER_ORDERS[i].ticket);
     if(OrderCopyState ==NEW) 
     { 
         if(UseNoLateOpen)
         {
            if(TimeGetElapsedDurationInSecs( MASTER_ORDERS[i].OpenTime,TimeCurrent())>MAX_ORDER_OPEN_STALE_SECS/*1 Min Late*/){ continue;}  //Skip Orders OpenTimeTooFar         
         }

         //Added 20180804: Random Sleep 100-300 ms to prevent concurrency
         Sleep(MathRandomRange()*100); //Added 20180804

         //Send
         OrderCopySend(MASTER_ORDERS[i].ticket,MASTER_ORDERS[i].symbol,MASTER_ORDERS[i].cmd,NormalizeDouble( MASTER_ORDERS[i].lots,2),3,MASTER_ORDERS[i].SL,MASTER_ORDERS[i].TP ); 
     }
   }
   
   //+------------------------------------------------------------------+
   //DONE AND DELETE 
   if(FileIsExist(CSV)) {FileDelete (CSV);};
   

}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllOpenTrades()
{
   //Print("CloseAllOpenTrades");
   for(int i=OrdersTotal()-1;i>=0;i--)     
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderType()==OP_BUY||OrderType()==OP_SELL)
      {
         //bool b = OrderClose(OrderTicket(),OrderLots(),(OrderType()==OP_BUY?Bid:Ask),3,clrNONE);
         bool b = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble((Bid+Ask)/2,(int)MarketInfo(OrderSymbol(),MODE_DIGITS)),5 ); 
      }
      //Print(__FUNCTION__, " LastError = " + ErrorDescription(GetLastError()) + " for " + OrderTicket()+ " of " + OrdType2S( OrderType()));
   }
}
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void CloseAllOpenEATrades()
{
   //Print("CloseAllOpenTrades");
   for(int i=OrdersTotal()-1;i>=0;i--)     
   {
      if(OrderSelect(i,SELECT_BY_POS,MODE_TRADES)==false) continue;
      if(OrderMagicNumber()==0)continue; //20180719:ignore MANUAL trades ********************************
      if(OrderType()==OP_BUY||OrderType()==OP_SELL)
      {
         //bool b = OrderClose(OrderTicket(),OrderLots(),(OrderType()==OP_BUY?Bid:Ask),3,clrNONE);
         bool b = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble((Bid+Ask)/2,(int)MarketInfo(OrderSymbol(),MODE_DIGITS)),5 ); 
      }
      //Print(__FUNCTION__, " LastError = " + ErrorDescription(GetLastError()) + " for " + OrderTicket()+ " of " + OrdType2S( OrderType()));
   }
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
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


//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
//ADDED 20180808: WriteCopyClientFlagFile()
void WriteCopyClientFlagFile()
{
   
   if(FileIsExist(TCCfilename)) {FileDelete (TCCfilename);};
   int handle=FileOpen(TCCfilename,FILE_WRITE|FILE_TXT,"\t"); 
   if(handle>0)
   {
      // write header 
      FileWrite(handle,login); 
      FileClose(handle);
   }
}

//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
int      MathRandomRange(int min=1,int max=3){int value=(min+(max)*MathRand()/32768);return(value>=max?max:(value<=min?min:value));} //Returns range from 1 to 3 by default