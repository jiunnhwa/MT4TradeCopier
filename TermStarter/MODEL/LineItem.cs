// Decompiled with JetBrains decompiler
// Type: TermStarter.MODEL.LineItem
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

using System;
using System.Data.OleDb;

namespace TermStarter.MODEL
{
  public class LineItem
  {
    public string ID { get; set; }

    public string Number { get; set; }

    public string NoVoiceCall { get; set; }

    public string Text { get; set; }

    public string Fax { get; set; }

    public string Source { get; set; }

    public DateTime ExpirationDate { get; set; }

    public DateTime JobRunTime { get; set; }

    public long JobID { get; set; }

    public static void ItemAddNew(LineItem feeditem, string connstr)
    {
      string number = feeditem.Number;
      string noVoiceCall = feeditem.NoVoiceCall;
      string text = feeditem.Text;
      string fax = feeditem.Fax;
      string str1 = "";
      DateTime expirationDate = feeditem.ExpirationDate;
      string.Format("{0:yyyy-MMM-dd HH:mm:ss}", (object) feeditem.JobRunTime);
      string str2 = "" + "INSERT INTO [Master] ( [Number], NoVoiceCall, [Text], Fax, Source, ExpirationDate) " + "SELECT " + string.Format("'{0}', ", (object) number) + string.Format("'{0}', ", (object) noVoiceCall) + string.Format("'{0}', ", (object) text) + string.Format("'{0}', ", (object) fax) + string.Format("'{0}', ", (object) str1) + string.Format("#{0}# ", (object) expirationDate) + "; ";
    }

    public static void ItemUpdate(LineItem feeditem, string connstr)
    {
      string number = feeditem.Number;
      string noVoiceCall = feeditem.NoVoiceCall;
      string text = feeditem.Text;
      string fax = feeditem.Fax;
      string str1 = "";
      DateTime expirationDate = feeditem.ExpirationDate;
      string.Format("{0:yyyy-MMM-dd HH:mm:ss}", (object) feeditem.JobRunTime);
      string str2 = "" + "UPDATE [Master] " + "SET " + string.Format("[Number] = {0}, NoVoiceCall = '{1}', [Text] ='{2}', Fax = '{3}', Source = '{4}', ExpirationDate = #{5}# ", (object) number, (object) noVoiceCall, (object) text, (object) fax, (object) str1, (object) expirationDate) + string.Format(" WHERE(((Number) = {0})) ", (object) number) + "; ";
    }

    public static bool ItemExists(string key, string connstr)
    {
      using (OleDbConnection connection = new OleDbConnection(connstr))
      {
        OleDbCommand oleDbCommand = new OleDbCommand(string.Format("SELECT Number FROM Master WHERE(((Number) = {0}));", (object) key), connection);
        connection.Open();
        return oleDbCommand.ExecuteReader().HasRows;
      }
    }
  }
}
