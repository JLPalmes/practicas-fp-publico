// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Drawing;
using System.Windows.Forms;
using System.Reflection;
using Microsoft.Win32;
using System.Linq;
using System.Collections.Generic;
static class Installer {
#if TAURI
    const string Product="Prácticas FP";
    const string ProductId="PracticasFP-Tauri";
    const string Version="2.1.9";
    const string DataFolder="PracticasFP-Tauri-Piloto";
    static readonly string[] Files={"PracticasFP.exe","motor.exe","Desinstalar.exe"};
#else
    const string Product="Prácticas FP 2";
    const string ProductId="PracticasFP2";
    const string Version="2.0.3";
    const string DataFolder="PracticasFP2";
    static readonly string[] Files={"PracticasFP.exe","Desinstalar.exe"};
#endif
    static readonly string Folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs",ProductId);
    const string Key="Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\"+ProductId;
    [STAThread] static void Main(string[] args) {
        Application.EnableVisualStyles();
        try {
            if(Array.IndexOf(args,"--uninstall")>=0) {
                Uninstall();
                return;
            }
            using(var f=new Form {
                Text="Instalar "+Product+" para Windows",Size=new Size(590,310),StartPosition=FormStartPosition.CenterScreen,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,Font=new Font("Segoe UI",10)
            }) {
                var label=new Label {
                    Left=22,Top=20,Width=535,Height=160,Text=Product+" · "+Version+"\nWindows de 64 bits\n\nSe instalará para tu usuario en:\n"+Folder+"\n\nLos datos y copias se guardan por separado y se conservan al desinstalar."
                };
                var install=new Button {
                    Text="Instalar",Left=330,Top=205,Width=105,Height=35
                };
                var cancel=new Button {
                    Text="Cancelar",Left=445,Top=205,Width=105,Height=35
                };
                cancel.Click+=(s,e)=>f.Close();
                install.Click+=(s,e)=> {
                    try {
                        Install();
                        MessageBox.Show(f,"Instalación terminada. Puedes abrir Prácticas FP desde el menú Inicio o el escritorio.","Prácticas FP");
                        f.Close();
                    }
                    catch(Exception ex) {
                        MessageBox.Show(f,"No se ha completado la instalación. Cierra Prácticas FP antes de volver a intentarlo.\n"+ex.Message,"Prácticas FP");
                    }
                };
                f.Icon=System.Drawing.Icon.ExtractAssociatedIcon(Application.ExecutablePath);
                f.Controls.Add(label);
                f.Controls.Add(install);
                f.Controls.Add(cancel);
                Application.Run(f);
            }
        }
        catch(Exception ex) {
            MessageBox.Show(ex.Message,"Prácticas FP");
        }
    }
    static void Shortcut(string path,string target) {
        Type t=Type.GetTypeFromProgID("WScript.Shell");
        dynamic shell=Activator.CreateInstance(t);
        dynamic shortcut=shell.CreateShortcut(path);
        shortcut.TargetPath=target;
        shortcut.WorkingDirectory=Folder;
        shortcut.Description="Prácticas FP";
        shortcut.Save();
    }
    static string Menu {
        get {
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),Product);
        }
    }
    static void Install() {
#if TAURI
        const string runtime=@"Software\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}";
        string machine=Registry.GetValue(@"HKEY_LOCAL_MACHINE\Software\WOW6432Node\Microsoft\EdgeUpdate\Clients\{F3017226-FE2A-4295-8BDF-00C3A9A7E4C5}","pv",null) as string;
        string user=Registry.GetValue(@"HKEY_CURRENT_USER\"+runtime,"pv",null) as string;
        if(new[]{machine,user}.All(value=>String.IsNullOrWhiteSpace(value)||value=="0.0.0.0"))
            throw new InvalidOperationException("Instala primero Microsoft Edge WebView2 Runtime desde developer.microsoft.com/microsoft-edge/webview2/.");
#endif
        string app=Path.Combine(Folder,"PracticasFP.exe");
        string uninstall=Path.Combine(Folder,"Desinstalar.exe");
        var payload=new Dictionary<string,byte[]>();
        foreach(string name in Files.Where(name=>name!="Desinstalar.exe"))
            using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream(name)) using(var buffer=new MemoryStream()) {
                stream.CopyTo(buffer);
                payload[name]=buffer.ToArray();
            }
        payload["Desinstalar.exe"]=File.ReadAllBytes(Assembly.GetExecutingAssembly().Location);
        var links=new[] {
            Path.Combine(Menu,Product+".lnk"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk")
        };
        var legacyLinks=new string[0];
#if TAURI
        legacyLinks=new[] {
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),"Prácticas FP Tauri","Prácticas FP Tauri.lnk"),
            Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"Prácticas FP Tauri.lnk")
        };
#endif
        var oldLinks=links.Concat(legacyLinks).ToDictionary(x=>x,x=>File.Exists(x)?File.ReadAllBytes(x):null);
        var oldRegistry=new Dictionary<string,object>();
        var oldKinds=new Dictionary<string,RegistryValueKind>();
        bool hadRegistry;
        using(var key=Registry.CurrentUser.OpenSubKey(Key)) {
            hadRegistry=key!=null;
            if(key!=null)foreach(string name in key.GetValueNames()) {
                oldRegistry[name]=key.GetValue(name,null,RegistryValueOptions.DoNotExpandEnvironmentNames);
                oldKinds[name]=key.GetValueKind(name);
            }
        }
        UpdateFiles.Install(Folder,payload,()=> {
            foreach(string name in new[]{"LICENSE","AVISO-LICENCIA.txt"}) {
                using(var source=Assembly.GetExecutingAssembly().GetManifestResourceStream(name))
                using(var destination=File.Create(Path.Combine(Folder,name)))source.CopyTo(destination);
            }
            Directory.CreateDirectory(Menu);
            foreach(string link in links)Shortcut(link,app);
            foreach(string link in legacyLinks)if(File.Exists(link))File.Delete(link);
            using(var k=Registry.CurrentUser.CreateSubKey(Key)) {
                k.SetValue("DisplayName",Product+" para Windows");
                k.SetValue("DisplayVersion",Version);
                k.SetValue("Publisher","Prácticas FP");
                k.SetValue("InstallLocation",Folder);
                k.SetValue("DisplayIcon",app);
                k.SetValue("UninstallString","\""+uninstall+"\" --uninstall");
                k.SetValue("NoModify",1);
                k.SetValue("NoRepair",1);
            }
        },()=> {
            foreach(var link in oldLinks) {
                if(link.Value==null) {
                    if(File.Exists(link.Key))File.Delete(link.Key);
                }
                else File.WriteAllBytes(link.Key,link.Value);
            }
            if(hadRegistry)using(var key=Registry.CurrentUser.CreateSubKey(Key)) {
                foreach(string name in key.GetValueNames())key.DeleteValue(name,false);
                foreach(var pair in oldRegistry)key.SetValue(pair.Key,pair.Value,oldKinds[pair.Key]);
            }
            else Registry.CurrentUser.DeleteSubKeyTree(Key,false);
        },null,Files);
    }
    static void Uninstall() {
        if(MessageBox.Show("¿Desinstalar Prácticas FP? Los datos y copias se conservarán.","Prácticas FP",MessageBoxButtons.YesNo,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)!=DialogResult.Yes)return;
        foreach(string name in Files.Where(name=>name!="Desinstalar.exe")) {
            string app=Path.Combine(Folder,name);
            if(File.Exists(app))File.Delete(app);
        }
        string previous=Path.Combine(Folder,"VersionAnterior");
        foreach(string name in Files) {
            string file=Path.Combine(previous,name);if(File.Exists(file))File.Delete(file);
        }
        if(Directory.Exists(previous)&&Directory.GetFileSystemEntries(previous).Length==0)Directory.Delete(previous);
        foreach(string link in new[] {
            Path.Combine(Menu,Product+".lnk"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),Product+".lnk")
        })if(File.Exists(link))File.Delete(link);
        if(Directory.Exists(Menu)&&Directory.GetFileSystemEntries(Menu).Length==0)Directory.Delete(Menu);
        Registry.CurrentUser.DeleteSubKeyTree(Key,false);
        MessageBox.Show("Aplicación desinstalada. Los datos se conservan en la carpeta "+DataFolder+" de tus datos locales. Puedes eliminar el archivo Desinstalar.exe restante cuando cierres esta ventana.","Prácticas FP");
    }
}
