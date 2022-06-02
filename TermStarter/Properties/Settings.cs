// Decompiled with JetBrains decompiler
// Type: TermStarter.Properties.Settings
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

using System.CodeDom.Compiler;
using System.Configuration;
using System.Runtime.CompilerServices;

namespace TermStarter.Properties
{
  [CompilerGenerated]
  [GeneratedCode("Microsoft.VisualStudio.Editors.SettingsDesigner.SettingsSingleFileGenerator", "11.0.0.0")]
  internal sealed class Settings : ApplicationSettingsBase
  {
    private static Settings defaultInstance = (Settings) SettingsBase.Synchronized((SettingsBase) new Settings());

    public static Settings Default
    {
      get
      {
        Settings defaultInstance = Settings.defaultInstance;
        return defaultInstance;
      }
    }
  }
}
