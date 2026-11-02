// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Security.Cryptography;
// File-only update engine. It can be tested with dummy files without installing
// an application, running an executable, creating shortcuts or touching registry.
public static class UpdateFiles {
    static readonly string[] Names= {
        "PracticasFP.exe","Desinstalar.exe"
    };
    public static string Hash(byte[] bytes) {
        using(var hash=SHA256.Create())return BitConverter.ToString(hash.ComputeHash(bytes));
    }
    static void Atomic(string target,byte[] bytes) {
        string temp=target+".nuevo";
        try {
            File.WriteAllBytes(temp,bytes);
            if(File.Exists(target))File.Replace(temp,target,null);
            else File.Move(temp,target);
        }finally {if(File.Exists(temp))File.Delete(temp);}
    }
    static void Clean(string folder) {
        foreach(string name in Names) {
            foreach(string prefix in new[] {
                "old-","new-"
            }) {
                string file=Path.Combine(folder,prefix+name);
                if(File.Exists(file))File.Delete(file);
            }
        }
        foreach(string name in new[] {
            "prepared","committed","existing.txt"
        }) {
            string file=Path.Combine(folder,name);
            if(File.Exists(file))File.Delete(file);
        }
        if(Directory.GetFileSystemEntries(folder).Length==0)Directory.Delete(folder);
    }
    static void Rollback(string root,string transaction) {
        string[] existing=File.ReadAllLines(Path.Combine(transaction,"existing.txt"));
        if(existing.Any(x=>!Names.Contains(x)))throw new IOException("Registro de actualización no válido. Se conservan los respaldos en "+transaction);
        foreach(string name in Names) {
            string target=Path.Combine(root,name),old=Path.Combine(transaction,"old-"+name);
            if(existing.Contains(name)) {
                if(!File.Exists(old))throw new IOException("Falta el respaldo para recuperar "+name);
                Atomic(target,File.ReadAllBytes(old));
            }
            else if(File.Exists(target))File.Delete(target);
        }
    }
    public static void Recover(string root) {
        if(!Directory.Exists(root))return;
        foreach(string transaction in Directory.GetDirectories(root,".actualizacion-*",SearchOption.TopDirectoryOnly)) {
            if(File.Exists(Path.Combine(transaction,"prepared"))&&!File.Exists(Path.Combine(transaction,"committed")))Rollback(root,transaction);
            Clean(transaction);
        }
    }
    public static void Install(string root,Dictionary<string,byte[]> payload,Action integrate,Action rollbackIntegration,Action<string> checkpoint=null) {
        if(payload.Count!=Names.Length||Names.Any(x=>!payload.ContainsKey(x)))throw new ArgumentException("La actualización debe contener los dos ejecutables.");
        Directory.CreateDirectory(root);
        Recover(root);
        // Fail before replacing anything if either executable is still in use.
        foreach(string name in Names) {
            string file=Path.Combine(root,name);
            if(File.Exists(file))using(var probe=new FileStream(file,FileMode.Open,FileAccess.ReadWrite,FileShare.None)) {
            }
        }
        string transaction=Path.Combine(root,".actualizacion-"+Guid.NewGuid().ToString("N"));
        Directory.CreateDirectory(transaction);
        bool prepared=false,integrationStarted=false,committed=false;
        try {
            var existing=new List<string>();
            foreach(string name in Names) {
                string target=Path.Combine(root,name);
                if(File.Exists(target)) {
                    File.Copy(target,Path.Combine(transaction,"old-"+name));
                    existing.Add(name);
                }
                string staged=Path.Combine(transaction,"new-"+name);
                File.WriteAllBytes(staged,payload[name]);
                if(Hash(File.ReadAllBytes(staged))!=Hash(payload[name]))throw new IOException("No se ha verificado el archivo "+name);
            }
            File.WriteAllLines(Path.Combine(transaction,"existing.txt"),existing.ToArray());
            File.WriteAllText(Path.Combine(transaction,"prepared"),"1");
            prepared=true;
            foreach(string name in Names) {
                Atomic(Path.Combine(root,name),File.ReadAllBytes(Path.Combine(transaction,"new-"+name)));
                if(checkpoint!=null)checkpoint(name);
            }
            integrationStarted=true;
            integrate();
            string previous=Path.Combine(root,"VersionAnterior");
            Directory.CreateDirectory(previous);
            foreach(string name in existing)File.Copy(Path.Combine(transaction,"old-"+name),Path.Combine(previous,name),true);
            File.WriteAllText(Path.Combine(transaction,"committed"),"1");
            committed=true;
        }
        catch(Exception original) {
            try {
                if(prepared)Rollback(root,transaction);
                if(integrationStarted)rollbackIntegration();
            }
            catch(Exception recovery) {
                throw new IOException("La actualización ha fallado y no se ha completado la recuperación. Conserva los respaldos en "+transaction+". "+recovery.Message,original);
            }
            Clean(transaction);
            throw;
        }
        // Cleanup failures do not turn a committed installation into a failure.
        if(committed) {
            try {
                Clean(transaction);
            }
            catch(IOException) {
            }
            catch(UnauthorizedAccessException) {
            }
        }
    }
}
