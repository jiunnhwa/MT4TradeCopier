// Decompiled with JetBrains decompiler
// Type: TermStarter.Helper
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

using System;
using System.Diagnostics;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace TermStarter
{
  public class Helper
  {
    public static void StartProcess(string FileName, string Arg = "")
    {
      ProcessStartInfo startInfo = new ProcessStartInfo();
      startInfo.FileName = FileName;
      startInfo.Arguments = Arg;
      startInfo.CreateNoWindow = false;
      startInfo.UseShellExecute = false;
      startInfo.WindowStyle = ProcessWindowStyle.Hidden;
      try
      {
        Process.Start(startInfo);
      }
      catch (Exception ex)
      {
        Console.WriteLine(ex.ToString());
        int num = (int) MessageBox.Show(ex.ToString(), string.Format("StartProcess Error: {0}", (object) FileName));
      }
    }

    [DllImport("user32.dll")]
    private static extern bool SetForegroundWindow(IntPtr hWnd);

    public static void SetForegroundWindowByWindowTitle(string processname, string title)
    {
      foreach (Process process in Process.GetProcesses())
      {
        if (process.ProcessName.Contains(processname) && process.MainWindowTitle.Contains(title))
          Helper.SetForegroundWindow(process.MainWindowHandle);
      }
    }

    public static void ProcessKillByWindowTitle(string processname, string title)
    {
      foreach (Process process in Process.GetProcesses())
      {
        if (process.ProcessName.Contains(processname) && process.MainWindowTitle.Contains(title))
          process.Kill();
      }
    }

    public static bool ProcessFindByWindowTitle(string processname, string title)
    {
      foreach (Process process in Process.GetProcesses())
      {
        if (process.ProcessName.Contains(processname) && process.MainWindowTitle.Contains(title))
          return true;
      }
      return false;
    }

    public static void KillProcess(string processName)
    {
      foreach (Process process in Process.GetProcesses())
      {
        if (process.ProcessName.ToLower().Equals(processName.ToLower()))
          process.Kill();
      }
    }
  }
}
