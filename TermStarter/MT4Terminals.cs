using System.Collections.Generic;
using System.Configuration;
using System.IO;
using System.Reflection;

namespace TermStarter
{
  public class MT4Terminals
  {
    private static string EXEC_DIR = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location.ToString());
    private static string TERMINALS_MAIN_DIR = ConfigurationManager.AppSettings[nameof (TERMINALS_MAIN_DIR)];

    public static List<string> GetListStarter() => new DirectoryInfo(MT4Terminals.TERMINALS_MAIN_DIR).Exists ? MT4Terminals.GetListClientTerminals(MT4Terminals.TERMINALS_MAIN_DIR) : new List<string>();

    private static List<string> GetListClientTerminals(
      string TerminalsDir,
      string SearchPattern = "Terminal-*.exe")
    {
      string[] files = Directory.GetFiles(TerminalsDir, SearchPattern, SearchOption.AllDirectories);
      List<string> listClientTerminals = new List<string>();
      foreach (string fileName in files)
      {
        FileInfo fileInfo = new FileInfo(fileName);
        listClientTerminals.Add(fileInfo.FullName);
      }
      return listClientTerminals;
    }
  }
}
