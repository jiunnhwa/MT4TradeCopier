//+------------------------------------------------------------------+
//|                                              TradeCopyClient.mq4 |
//|                                            Copyright 2017, Jiunn |
//|                                            https://www.jiunn.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2017, Jiunn"
#property link      "https://www.jiunn.com"
#property version   "1.01"
#property strict
//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
#include <stderror.mqh> 
#include <stdlib.mqh> 
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

#define SLIPPAGE 3
int OnInit()
  {
//--- create timer
   EventSetTimer(1);
   //EventSetMillisecondTimer(500);
   
   GetAcctInfo();     
   Print(    "company=",company, " name=", name, " login=",login, " server=",server, "IsRightBroker=",IsRightBroker("AXI"));
      
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
      
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---

   RUN();


   
  }
//+------------------------------------------------------------------+
//| Timer function                                                   |
//+------------------------------------------------------------------+
void OnTimer()
{}

int MASTER_BOOK_SIZE;
void RUN()
  {
//---
   //INIT
   //checkbroker
   
   //CLEAN
   ArrayFree(SOURCE_ORDERS);

   //FETCH
   if(WebGet()==false)return;//Fetch, abend if err(false)
   
   //READ
   ReadCSV();//Parse
   MASTER_BOOK_SIZE=ArraySize(SOURCE_ORDERS);
   Comment("MASTER_BOOK_SIZE=",MASTER_BOOK_SIZE);   
   
   //IF EMPTY CSV
   if(MASTER_BOOK_SIZE==0 ||MASTER_BOOK_SIZE==NULL){return;}
   
   //DELETE EXCESS POSITIONS IN FOLLOWER CURRBOOK
   for(int j=0;j<OrdersTotal();j++)
   {
      if(OrderSelect(j,SELECT_BY_POS,MODE_TRADES))
      {
         copy_state OrderCopyState =  CheckOrderOnMasterTable(OrderMagicNumber());
         if(OrderCopyState ==NOTFOUND) { bool b = OrderClose(OrderTicket(),OrderLots(),NormalizeDouble((Bid+Ask)/2,(int)MarketInfo(OrderSymbol(),MODE_DIGITS)),5 ); }
      }
   }
   
   //SYNC MASTER TO CLIENT
   for(int i=0;i<MASTER_BOOK_SIZE;i++)
   {   
     copy_state OrderCopyState =  CheckOrderFollowed(SOURCE_ORDERS[i].ticket);
     if(OrderCopyState ==NEW) { OrderCopySend(SOURCE_ORDERS[i].ticket,SOURCE_ORDERS[i].symbol,SOURCE_ORDERS[i].cmd,NormalizeDouble( SOURCE_ORDERS[i].lots,2),SLIPPAGE,SOURCE_ORDERS[i].SL,SOURCE_ORDERS[i].TP ); }
   }
   
   //DONE AND DELETE 
   if(FileIsExist(FileName)) {FileDelete (FileName);};
   
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
enum copy_state             {NEW,EXIST,NOTFOUND,MODIFIED,DELETED,CLOSED};


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
  
order SOURCE_ORDERS[];
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
void CloseClientOrder()
{

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
int MASTER_BOOK[6] = {0,0,0,0,0,0};  
copy_state CheckOrderOnMasterTable(int orderNumClient)
{
   //check if client order is on 
   for(int j=0;j<ArraySize(SOURCE_ORDERS);j++)
   {
       if(SOURCE_ORDERS[j].ticket==orderNumClient) return EXIST;
   }
   return NOTFOUND;
   
}



//+------------------------------------------------------------------+
//|                                                                  |
//+------------------------------------------------------------------+
void ReadSource()
{
   int pos = 0;
  string txt;
  int hnd = FileOpen ("OrdersReport.csv", FILE_CSV|FILE_READ|FILE_CSV, "|");
  if (hnd > 0)                                           //--- read the file if only hnd is > 0
     {
     //Print ("File MASTER_BOOK_SIZE ",FileSize(hnd));
     //while (FileTell (hnd)< FileSize(hnd))
     while (FileIsEnding (hnd) == false)
       {
       pos ++;
       //Print ("Loop number ",pos);  //--- read row number
       //Print ("start file pointer at ", FileTell (hnd),". File size ",FileSize(hnd));

       SOURCE_ORDER.ticket =(int) FileReadString (hnd);   //--- read first column
       //Print (txt);
     
       SOURCE_ORDER.symbol = FileReadString (hnd);   //--- read second column
       //Print (txt);
       
       SOURCE_ORDER.cmd = (int) FileReadString (hnd);   //--- read third column
       //Print (txt);
       
       
       SOURCE_ORDER.lots = (double)FileReadString (hnd);   //--- read fourth column
       //Print (txt);
       
       SOURCE_ORDER.TP =  (double) FileReadString (hnd);   //--- read fifth column
       //Print (txt);
       
       SOURCE_ORDER.SL = (double)FileReadString (hnd);   //--- read sixth column
       //Print (txt);
       
       SOURCE_ORDER.OpenTime = StringToTime(FileReadString (hnd));   //--- read seventh column
       //Print (txt);

       SOURCE_ORDER.OpenPrice = (double)FileReadString (hnd);   //--- read eight column
       //Print (txt);         
  
  
      // Print (SOURCE_ORDER.ticket + "+" + SOURCE_ORDER.symbol );
       
       //Print ("End file pointer at ", FileTell (hnd),". File size ",FileSize(hnd));   
       
       if (FileIsEnding (hnd) == false)
          Print ("File is not ending. More to come");
       }
     
     
     FileClose (hnd);                                      //--- and so close the file if only hnd is > 0
   }
}

extern string FileName = "OrdersReport.csv";
void ReadCSV()
{
   int row=0;
   int hnd=FileOpen(FileName,FILE_CSV|FILE_READ,"|");
   if(hnd>0)
   {
     while(True)
     {
      

      
      string field1 = FileReadString (hnd);
      if(StringLen(field1)>0)
      {
         int size=ArraySize(SOURCE_ORDERS);
         ArrayResize(SOURCE_ORDERS,size+1);           //resize
      
         SOURCE_ORDERS[size].ticket = field1; // FileReadString (hnd);   //--- read first column
         //SOURCE_ORDERS[size].Key = field1; // FileReadString (hnd);   //--- read first column
         //SOURCE_ORDERS[size].ticket =(int) GetTicketNumberFromKey(field1, ":"); // FileReadString (hnd);   //--- read first column
         SOURCE_ORDERS[size].symbol = FileReadString (hnd);   //--- read second column
         SOURCE_ORDERS[size].cmd = (int) FileReadString (hnd);   //--- read third column
         SOURCE_ORDERS[size].lots = (double)FileReadString (hnd);   //--- read fourth column
         SOURCE_ORDERS[size].TP =  (double) FileReadString (hnd);   //--- read fifth column
         SOURCE_ORDERS[size].SL = (double)FileReadString (hnd);   //--- read sixth column       
         SOURCE_ORDERS[size].OpenTime =  StringToTime(FileReadString (hnd));   //--- read seventh column
         SOURCE_ORDERS[size].OpenPrice = (double)FileReadString (hnd);   //--- read eight column
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
     Comment("File "+FileName+" not found, the last error is ", GetLastError());
     
   }
   

}

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
//--- Name of the client 
   name=AccountInfoString(ACCOUNT_NAME); 
//--- Account number 
   login=AccountInfoInteger(ACCOUNT_LOGIN); 
//--- Name of the server 
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