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
    static readonly string Folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"Programs","PracticasFP");
    const string Key="Software\\Microsoft\\Windows\\CurrentVersion\\Uninstall\\PracticasFP";
    [STAThread] static void Main(string[] args) {
        Application.EnableVisualStyles();
        try {
            if(Array.IndexOf(args,"--uninstall")>=0) {
                Uninstall();
                return;
            }
            using(var f=new Form {
                Text="Instalar Prácticas FP para Windows",Size=new Size(590,310),StartPosition=FormStartPosition.CenterScreen,FormBorderStyle=FormBorderStyle.FixedDialog,MaximizeBox=false,Font=new Font("Segoe UI",10)
            }) {
                var label=new Label {
                    Left=22,Top=20,Width=535,Height=160,Text="Prácticas FP · 1.8.5\nVersión de pruebas para Windows de 64 bits\n\nSe instalará para tu usuario en:\n"+Folder+"\n\nLos datos y copias se guardan por separado y se conservan al desinstalar."
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
            return Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.Programs),"Prácticas FP");
        }
    }
    static void Install() {
        string app=Path.Combine(Folder,"PracticasFP.exe");
        string uninstall=Path.Combine(Folder,"Desinstalar.exe");
        var payload=new Dictionary<string,byte[]>();
        using(var stream=Assembly.GetExecutingAssembly().GetManifestResourceStream("PracticasFP.exe")) using(var buffer=new MemoryStream()) {
            stream.CopyTo(buffer);
            payload["PracticasFP.exe"]=buffer.ToArray();
        }
        payload["Desinstalar.exe"]=File.ReadAllBytes(Assembly.GetExecutingAssembly().Location);
        var links=new[] {
            Path.Combine(Menu,"Prácticas FP.lnk"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"Prácticas FP.lnk")
        };
        var oldLinks=links.ToDictionary(x=>x,x=>File.Exists(x)?File.ReadAllBytes(x):null);
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
            using(var k=Registry.CurrentUser.CreateSubKey(Key)) {
                k.SetValue("DisplayName","Prácticas FP para Windows");
                k.SetValue("DisplayVersion","1.8.5");
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
        });
    }
    static void Uninstall() {
        if(MessageBox.Show("¿Desinstalar Prácticas FP? Los datos y copias se conservarán.","Prácticas FP",MessageBoxButtons.YesNo,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)!=DialogResult.Yes)return;
        string app=Path.Combine(Folder,"PracticasFP.exe");
        if(File.Exists(app))File.Delete(app);
        string previous=Path.Combine(Folder,"VersionAnterior");
        foreach(string name in new[]{"PracticasFP.exe","Desinstalar.exe"}) {
            string file=Path.Combine(previous,name);if(File.Exists(file))File.Delete(file);
        }
        if(Directory.Exists(previous)&&Directory.GetFileSystemEntries(previous).Length==0)Directory.Delete(previous);
        foreach(string link in new[] {
            Path.Combine(Menu,"Prácticas FP.lnk"),Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.DesktopDirectory),"Prácticas FP.lnk")
        })if(File.Exists(link))File.Delete(link);
        if(Directory.Exists(Menu)&&Directory.GetFileSystemEntries(Menu).Length==0)Directory.Delete(Menu);
        Registry.CurrentUser.DeleteSubKeyTree(Key,false);
        MessageBox.Show("Aplicación desinstalada. Los datos se conservan en la carpeta PracticasFP de tus datos locales. Puedes eliminar el archivo Desinstalar.exe restante cuando cierres esta ventana.","Prácticas FP");
    }
}
