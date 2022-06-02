// Decompiled with JetBrains decompiler
// Type: TermStarter.Form1
// Assembly: TermStarter, Version=1.0.6806.24920, Culture=neutral, PublicKeyToken=null
// MVID: 76B98BA6-2734-4523-BFD7-1762AD689123
// Assembly location: C:\Users\FX1\Downloads\TermStarter.exe

using System;
using System.Collections.Generic;
using System.ComponentModel;
using System.Configuration;
using System.Diagnostics;
using System.Drawing;
using System.IO;
using System.Reflection;
using System.Threading;
using System.Timers;
using System.Windows.Forms;
using TermStarter.MODEL;

namespace TermStarter
{
  public class Form1 : Form
  {
    private static string MachineName = Environment.MachineName;
    private static string AppVersion = Application.ProductVersion;
    private PerformanceCounter cpuCounter = new PerformanceCounter("Processor", "% Processor Time", "_Total");
    private PerformanceCounter ramCounter = new PerformanceCounter("Memory", "Available MBytes");
    private static string EXEC_DIR = Path.GetDirectoryName(Assembly.GetExecutingAssembly().Location.ToString());
    private static List<string> TERMS;
    private static string TERMPATH_MASTER = ConfigurationManager.AppSettings[nameof (TERMPATH_MASTER)];
    private static string TERMPATH_FILESERVER = ConfigurationManager.AppSettings[nameof (TERMPATH_FILESERVER)];
    private static string TERMPATH_FILECOPIER = ConfigurationManager.AppSettings[nameof (TERMPATH_FILECOPIER)];
    private Button[] btnArrayActivate;
    private Button[] btnArrayStart;
    private string[] Students = new string[5]
    {
      "813410",
      "814376",
      "815573",
      "99999",
      "8888"
    };
    private List<Follower> Followers = new List<Follower>();
    private IContainer components = (IContainer) null;
    private TabControl tabControl1;
    private TabPage tabActivate;
    private TabPage tabStart;
    private Button button1;
    private FlowLayoutPanel flowLayoutActivate;
    private FlowLayoutPanel flowLayoutPanel1;
    private Button button2;
    private Button button3;
    private FlowLayoutPanel flowLayoutStart;
    private LinkLabel linkLabelTerminals;
    private Label label1;
    private System.Windows.Forms.Timer timer1;
    private Label lblVersion;
    private Button cmdStartAll;

    public Form1() => this.InitializeComponent();

    private void button1_Click(object sender, EventArgs e)
    {
      Helper.KillProcess("terminal-master");
      Helper.StartProcess("C:\\Program Files (x86)\\City Index – MT4 Terminal\\terminal-master.exe");
    }

    private void button2_Click(object sender, EventArgs e)
    {
      Helper.KillProcess("FileServer");
      Helper.StartProcess(Form1.TERMPATH_FILESERVER);
    }

    private void button3_Click(object sender, EventArgs e)
    {
      Helper.KillProcess("TerminalTradeFileMonCopier");
      Helper.StartProcess(Form1.TERMPATH_FILECOPIER);
    }

    private void CreateButtons()
    {
      int length = this.Students.Length;
    }

    private void CreateButtonsActivate()
    {
      try
      {
        this.btnArrayActivate = new Button[this.Followers.Count];
        int index = 0;
        foreach (Follower follower in this.Followers)
        {
          this.btnArrayActivate[index] = new Button();
          this.btnArrayActivate[index].Name = "btn" + (index + 1).ToString();
          this.btnArrayActivate[index].Tag = (object) index;
          this.btnArrayActivate[index].Width = 100;
          this.btnArrayActivate[index].Height = 50;
          this.btnArrayActivate[index].Text = this.Followers[index].LoginID.ToString();
          this.btnArrayActivate[index].Visible = true;
          this.flowLayoutActivate.Controls.Add((Control) this.btnArrayActivate[index]);
          this.btnArrayActivate[index].Click += new EventHandler(this.ClickButtonActivate);
          ++index;
        }
      }
      catch (Exception ex)
      {
        throw;
      }
    }

    private void CreateButtonsStart()
    {
      try
      {
        this.btnArrayStart = new Button[this.Followers.Count];
        int index = 0;
        foreach (Follower follower in this.Followers)
        {
          this.btnArrayStart[index] = new Button();
          this.btnArrayStart[index].Name = "btn" + (index + 1).ToString();
          this.btnArrayStart[index].Tag = (object) index;
          this.btnArrayStart[index].Width = 100;
          this.btnArrayStart[index].Height = 50;
          this.btnArrayStart[index].Text = this.Followers[index].LoginID.ToString();
          this.btnArrayStart[index].Visible = true;
          this.flowLayoutStart.Controls.Add((Control) this.btnArrayStart[index]);
          this.btnArrayStart[index].Click += new EventHandler(this.ClickButtonStart);
          ++index;
        }
      }
      catch (Exception ex)
      {
        throw;
      }
    }

    private void Form1_Load(object sender, EventArgs e)
    {
      this.TopMost = true;
      this.MaximizeBox = false;
      this.Text = string.Format("[{0} - Term Starter", (object) Form1.MachineName);
      this.lblVersion.Text = string.Format("Ver: {0}", (object) Form1.AppVersion);
      this.linkLabelTerminals.Links.Add(0, this.linkLabelTerminals.Text.Length, (object) Program.GetUserGuideLoc());
      Form1.TERMS = MT4Terminals.GetListStarter();
      foreach (string str in Form1.TERMS)
      {
        string[] strArray = str.Split('-');
        this.Followers.Add(new Follower()
        {
          LoginID = this.Sanitize(strArray[1].Replace(".exe", "")),
          ExecFilePath = str
        });
      }
      this.CreateButtonsActivate();
      this.CreateButtonsStart();
    }

    private void Timer1_Elapsed(object sender, ElapsedEventArgs e) => this.Text = DateTime.Now.ToString();

    private string Sanitize(string f) => f.Trim().Replace("'", "");

    public void ClickButton(object sender, EventArgs e)
    {
      Button button = (Button) sender;
      int num = (int) MessageBox.Show("You clicked character [" + button.Name + ", " + button.Tag.ToString() + "]");
      button.Visible = false;
      this.button1.PerformClick();
    }

    public void ClickButtonStart(object sender, EventArgs e)
    {
      Button button = (Button) sender;
      Helper.ProcessKillByWindowTitle("terminal", this.Followers[(int) button.Tag].LoginID);
      Helper.StartProcess(this.Followers[(int) button.Tag].ExecFilePath);
    }

    public void ClickButtonActivate(object sender, EventArgs e) => Helper.SetForegroundWindowByWindowTitle("terminal", this.Followers[(int) ((Control) sender).Tag].LoginID);

    private void tabStart_Click(object sender, EventArgs e)
    {
    }

    private void linkLabelTerminals_LinkClicked(object sender, LinkLabelLinkClickedEventArgs e) => Process.Start(e.Link.LinkData as string);

    private void timer1_Tick(object sender, EventArgs e)
    {
      int num = 0;
      int index = 0;
      foreach (Follower follower in this.Followers)
      {
        if (Helper.ProcessFindByWindowTitle("terminal", this.Followers[index].LoginID))
        {
          this.btnArrayActivate[index].BackColor = Color.LimeGreen;
          this.btnArrayStart[index].BackColor = Color.LimeGreen;
          ++num;
        }
        else
        {
          this.btnArrayActivate[index].BackColor = Color.Yellow;
          this.btnArrayStart[index].BackColor = Color.Yellow;
        }
        ++index;
      }
      this.Text = string.Format("[{0} - TERM STARTER] {1} CPU:{2}% RAM:{3}MB - FOLLOWERS: {4}/{5}", (object) Form1.MachineName, (object) DateTime.Now.ToString(), (object) this.cpuCounter.NextValue().ToString("0"), (object) this.ramCounter.NextValue(), (object) num, (object) this.Followers.Count);
    }

    private void cmdStartAll_Click(object sender, EventArgs e)
    {
      int index = 0;
      foreach (Follower follower in this.Followers)
      {
        Helper.ProcessKillByWindowTitle("terminal", this.Followers[index].LoginID);
        Helper.StartProcess(this.Followers[index].ExecFilePath);
        ++index;
        Thread.Sleep(1000);
      }
    }

    protected override void Dispose(bool disposing)
    {
      if (disposing && this.components != null)
        this.components.Dispose();
      base.Dispose(disposing);
    }

    private void InitializeComponent()
    {
      this.components = (IContainer) new Container();
      this.tabControl1 = new TabControl();
      this.tabActivate = new TabPage();
      this.flowLayoutActivate = new FlowLayoutPanel();
      this.tabStart = new TabPage();
      this.cmdStartAll = new Button();
      this.label1 = new Label();
      this.flowLayoutStart = new FlowLayoutPanel();
      this.button1 = new Button();
      this.flowLayoutPanel1 = new FlowLayoutPanel();
      this.button2 = new Button();
      this.button3 = new Button();
      this.linkLabelTerminals = new LinkLabel();
      this.timer1 = new System.Windows.Forms.Timer(this.components);
      this.lblVersion = new Label();
      this.tabControl1.SuspendLayout();
      this.tabActivate.SuspendLayout();
      this.tabStart.SuspendLayout();
      this.SuspendLayout();
      this.tabControl1.Controls.Add((Control) this.tabActivate);
      this.tabControl1.Controls.Add((Control) this.tabStart);
      this.tabControl1.Location = new Point(1, 1);
      this.tabControl1.Name = "tabControl1";
      this.tabControl1.SelectedIndex = 0;
      this.tabControl1.Size = new Size(608, 369);
      this.tabControl1.TabIndex = 0;
      this.tabActivate.Controls.Add((Control) this.flowLayoutActivate);
      this.tabActivate.Location = new Point(4, 22);
      this.tabActivate.Name = "tabActivate";
      this.tabActivate.Padding = new Padding(3);
      this.tabActivate.Size = new Size(600, 343);
      this.tabActivate.TabIndex = 0;
      this.tabActivate.Text = "Activate";
      this.tabActivate.UseVisualStyleBackColor = true;
      this.flowLayoutActivate.Location = new Point(11, 6);
      this.flowLayoutActivate.Name = "flowLayoutActivate";
      this.flowLayoutActivate.Size = new Size(583, 331);
      this.flowLayoutActivate.TabIndex = 0;
      this.tabStart.Controls.Add((Control) this.cmdStartAll);
      this.tabStart.Controls.Add((Control) this.label1);
      this.tabStart.Controls.Add((Control) this.flowLayoutStart);
      this.tabStart.Location = new Point(4, 22);
      this.tabStart.Name = "tabStart";
      this.tabStart.Padding = new Padding(3);
      this.tabStart.Size = new Size(600, 343);
      this.tabStart.TabIndex = 1;
      this.tabStart.Text = "Start";
      this.tabStart.UseVisualStyleBackColor = true;
      this.tabStart.Click += new EventHandler(this.tabStart_Click);
      this.cmdStartAll.Location = new Point(330, 0);
      this.cmdStartAll.Name = "cmdStartAll";
      this.cmdStartAll.Size = new Size(109, 23);
      this.cmdStartAll.TabIndex = 3;
      this.cmdStartAll.Text = "Start All";
      this.cmdStartAll.UseVisualStyleBackColor = true;
      this.cmdStartAll.Click += new EventHandler(this.cmdStartAll_Click);
      this.label1.AutoSize = true;
      this.label1.Font = new Font("Microsoft Sans Serif", 8.25f, FontStyle.Bold, GraphicsUnit.Point, (byte) 0);
      this.label1.ForeColor = Color.Coral;
      this.label1.Location = new Point(44, 6);
      this.label1.Name = "label1";
      this.label1.Size = new Size(221, 13);
      this.label1.TabIndex = 2;
      this.label1.Text = "Warning: Clicking will restart terminal.";
      this.flowLayoutStart.Location = new Point(3, 22);
      this.flowLayoutStart.Name = "flowLayoutStart";
      this.flowLayoutStart.Size = new Size(591, 315);
      this.flowLayoutStart.TabIndex = 1;
      this.button1.Location = new Point(377, 423);
      this.button1.Name = "button1";
      this.button1.Size = new Size(143, 23);
      this.button1.TabIndex = 1;
      this.button1.Text = "Term-Master";
      this.button1.UseVisualStyleBackColor = true;
      this.button1.Click += new EventHandler(this.button1_Click);
      this.flowLayoutPanel1.Location = new Point(16, 376);
      this.flowLayoutPanel1.Name = "flowLayoutPanel1";
      this.flowLayoutPanel1.Size = new Size(529, 26);
      this.flowLayoutPanel1.TabIndex = 2;
      this.button2.Location = new Point(35, 423);
      this.button2.Name = "button2";
      this.button2.Size = new Size(122, 23);
      this.button2.TabIndex = 3;
      this.button2.Text = "FileServer";
      this.button2.UseVisualStyleBackColor = true;
      this.button2.Click += new EventHandler(this.button2_Click);
      this.button3.Location = new Point(178, 423);
      this.button3.Name = "button3";
      this.button3.Size = new Size(136, 23);
      this.button3.TabIndex = 4;
      this.button3.Text = "TermTradeCopier";
      this.button3.UseVisualStyleBackColor = true;
      this.button3.Click += new EventHandler(this.button3_Click);
      this.linkLabelTerminals.AutoSize = true;
      this.linkLabelTerminals.Location = new Point(615, 41);
      this.linkLabelTerminals.Name = "linkLabelTerminals";
      this.linkLabelTerminals.Size = new Size(36, 13);
      this.linkLabelTerminals.TabIndex = 5;
      this.linkLabelTerminals.TabStop = true;
      this.linkLabelTerminals.Text = "Terms";
      this.linkLabelTerminals.LinkClicked += new LinkLabelLinkClickedEventHandler(this.linkLabelTerminals_LinkClicked);
      this.timer1.Enabled = true;
      this.timer1.Interval = 1000;
      this.timer1.Tick += new EventHandler(this.timer1_Tick);
      this.lblVersion.AutoSize = true;
      this.lblVersion.Location = new Point(615, 9);
      this.lblVersion.Name = "lblVersion";
      this.lblVersion.Size = new Size(35, 13);
      this.lblVersion.TabIndex = 6;
      this.lblVersion.Text = "label2";
      this.AutoScaleDimensions = new SizeF(6f, 13f);
      this.AutoScaleMode = AutoScaleMode.Font;
      this.ClientSize = new Size(728, 452);
      this.Controls.Add((Control) this.lblVersion);
      this.Controls.Add((Control) this.linkLabelTerminals);
      this.Controls.Add((Control) this.button3);
      this.Controls.Add((Control) this.button2);
      this.Controls.Add((Control) this.flowLayoutPanel1);
      this.Controls.Add((Control) this.button1);
      this.Controls.Add((Control) this.tabControl1);
      this.FormBorderStyle = FormBorderStyle.FixedDialog;
      this.Name = nameof (Form1);
      this.Text = nameof (Form1);
      this.Load += new EventHandler(this.Form1_Load);
      this.tabControl1.ResumeLayout(false);
      this.tabActivate.ResumeLayout(false);
      this.tabStart.ResumeLayout(false);
      this.tabStart.PerformLayout();
      this.ResumeLayout(false);
      this.PerformLayout();
    }
  }
}
