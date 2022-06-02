// Decompiled with JetBrains decompiler
// Type: TermStarter.Program
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

using System;
using System.IO;
using System.Windows.Forms;

namespace TermStarter
{
  internal static class Program
  {
    public static string GetUserGuideLoc() => Path.Combine(Path.GetDirectoryName(Application.ExecutablePath).ToString(), "");

    [STAThread]
    private static void Main()
    {
      Application.EnableVisualStyles();
      Application.SetCompatibleTextRenderingDefault(false);
      Application.Run((Form) new Form1());
    }
  }
}
