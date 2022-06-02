// Decompiled with JetBrains decompiler
// Type: TermStarter.MODEL.Follower
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

namespace TermStarter.MODEL
{
  public class Follower
  {
    public string LoginID { get; set; }

    public string PW { get; set; }

    public string ExecFilePath { get; set; }

    public string DataFolder { get; set; }

    public string Type { get; set; } = "CLIENT";

    public string BrokerName { get; set; }

    public string BrokerServer { get; set; }

    public string HostName { get; set; }

    public string StartDate { get; set; }
  }
}
