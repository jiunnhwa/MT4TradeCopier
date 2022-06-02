using System;
using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Threading;
using System.Threading.Tasks;
using System.Timers;

namespace TerminalFileCopier
{
  internal class Program
  {
    private static string UserName = Environment.UserName;
    private static string MachineName = Environment.MachineName;
    private static string EXEC_DIR = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location.ToString());
    private static string MASTER_DIR = ConfigurationManager.AppSettings[nameof (MASTER_DIR)];
    private static string MASTER_ID = ConfigurationManager.AppSettings[nameof (MASTER_ID)];
    private static string TERMINAL_TOP_DIR = string.Format("C:\\Users\\{0}\\AppData\\Roaming\\MetaQuotes\\Terminal\\", (object) Program.UserName);
    private static List<string> listDistrib = new List<string>();
    private static string SOURCE_CSV = "OrdersReport.csv";
    private static System.Timers.Timer timer1;
    private static DateTime LastCopyTime = DateTime.MinValue;
    private static int HEART_BEAT_INT = 10;
    private static string MasterSourceCSV;

    private static void Main(string[] args)
    {
      string masterDir = Program.GetMasterDir(Program.TERMINAL_TOP_DIR, Program.MASTER_ID);
      if (string.IsNullOrEmpty(masterDir))
      {
        Console.WriteLine(string.Format("Terminal Master {0} not found. Program Stop.", (object) Program.MASTER_ID));
        Console.ReadKey();
      }
      else
      {
        Program.MasterSourceCSV = Path.Combine(masterDir, Program.SOURCE_CSV);
        Program.listDistrib = Program.GetListDistrib();
        Program.DrawScreen();
        Program.StartTimer();
        do
          ;
        while (Console.ReadKey(true).Key != ConsoleKey.Escape);
        Program.StopTimer();
      }
    }

    private static void DrawScreen()
    {
      Console.WriteLine("START:");
      for (int index = 0; index < Program.listDistrib.Count; ++index)
        Console.WriteLine(string.Format("DistribList[{0}]: {1}", (object) index, (object) Program.listDistrib[index]));
    }

    private static void CopyToFollowers(string SourceFile, List<string> tgtdirs) => Parallel.ForEach<string>((IEnumerable<string>) tgtdirs, (Action<string>) (tgtPath =>
    {
      try
      {
        int num1 = 0;
        if (File.Exists(SourceFile))
        {
          DateTime lastWriteTime = File.GetLastWriteTime(SourceFile);
          Console.WriteLine(string.Format("OrderReport.csv Age(s):{0}. LastWriteTime={1}", (object) DateTime.Now.Subtract(lastWriteTime).Seconds, (object) lastWriteTime));
          for (int index = 0; index < 3 && Program.IsFileLocked(new FileInfo(SourceFile)); ++index)
            Thread.Sleep(50);
        }
        string str = Path.Combine(tgtPath, Program.SOURCE_CSV);
        if (File.Exists(str))
        {
          Console.WriteLine(string.Format("{0}: TargetFile Exists! {1} ... Wait Target Delete, Sleep (100)", (object) DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"), (object) str));
          Thread.Sleep(100);
        }
        bool flag1 = File.Exists(SourceFile);
        bool flag2 = File.Exists(str);
        if (flag1 && !flag2)
        {
          File.Copy(SourceFile, str, true);
          int num2;
          Console.WriteLine(string.Format("{0}:COPY OK! Tries:{1} SRC:{2} -> TGT:{3}", (object) DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss"), (object) (num2 = num1 + 1), (object) Program.SOURCE_CSV, (object) str));
        }
        else
        {
          DateTime now;
          if (flag1)
          {
            now = DateTime.Now;
            Console.WriteLine(string.Format("{0}: COPY FAIL! NO SOURCE CSV.", (object) now.ToString("yyyy-MM-dd HH:mm:ss")));
          }
          if (flag2)
          {
            now = DateTime.Now;
            Console.WriteLine(string.Format("{0}: COPY FAIL! TGT CSV EXISTS.", (object) now.ToString("yyyy-MM-dd HH:mm:ss")));
          }
        }
      }
      catch (Exception ex)
      {
        Console.WriteLine(ex.ToString());
      }
    }));

    public static bool IsFileLocked(FileInfo file)
    {
      FileStream fileStream = (FileStream) null;
      try
      {
        fileStream = file.Open(FileMode.Open, FileAccess.Read, FileShare.None);
      }
      catch (IOException ex)
      {
        return true;
      }
      finally
      {
        fileStream?.Close();
      }
      return false;
    }

    private static void StartTimer(int ms = 1000)
    {
      Program.timer1 = new System.Timers.Timer((double) ms);
      Program.timer1.Enabled = true;
      Program.timer1.Elapsed += new ElapsedEventHandler(Program.OnTimer_Handler);
    }

    private static void StopTimer(int ms = 1000)
    {
      Program.timer1.Enabled = false;
      Program.timer1.Elapsed -= new ElapsedEventHandler(Program.OnTimer_Handler);
    }

    private static void OnTimer_Handler(object sender, ElapsedEventArgs e)
    {
      Console.WriteLine(string.Format("{0}: OnTimer()", (object) DateTime.Now.ToString("yyyy-MM-dd HH:mm:ss")));
      if (DateTime.Now.Subtract(Program.LastCopyTime) < TimeSpan.FromSeconds((double) Program.HEART_BEAT_INT))
        return;
      Program.CopyToFollowers(Program.MasterSourceCSV, Program.listDistrib);
      Program.LastCopyTime = DateTime.Now;
    }

    private static string GetMasterDir(string TerminalsDir, string MasterID)
    {
      string searchPattern = string.Format("CopyMaster-{0}.txt", (object) MasterID);
      string[] files = Directory.GetFiles(TerminalsDir, searchPattern, SearchOption.AllDirectories);
      if (files.Length == 1)
      {
        Console.WriteLine(string.Format("GetMasterDir() FOUND:{0}", (object) searchPattern));
        return new FileInfo(files[0].ToString()).DirectoryName;
      }
      Console.WriteLine(string.Format("GetMasterDir() NOT FOUND: {0}", (object) searchPattern));
      return "";
    }

    private static List<string> GetListDistrib()
    {
      List<string> listClientTerminals = Program.GetListClientTerminals(Program.TERMINAL_TOP_DIR);
      List<string> listFollowers = Program.GetListFollowers();
      listClientTerminals.AddRange((IEnumerable<string>) listFollowers);
      return listClientTerminals.Distinct<string>().ToList<string>();
    }

    private static List<string> GetListClientTerminals(
      string TerminalsDir,
      string SearchPattern = "CopyClient*.txt")
    {
      string[] files = Directory.GetFiles(TerminalsDir, SearchPattern, SearchOption.AllDirectories);
      List<string> listClientTerminals = new List<string>();
      foreach (string fileName in files)
      {
        FileInfo fileInfo = new FileInfo(fileName);
        listClientTerminals.Add(fileInfo.DirectoryName);
      }
      return listClientTerminals;
    }

    private static List<string> GetListFollowers(string filename = "Followers.txt") => !File.Exists(Path.Combine(Program.EXEC_DIR, filename)) ? new List<string>() : ((IEnumerable<string>) File.ReadAllLines(Path.Combine(Program.EXEC_DIR, filename))).ToList<string>();
  }
}
