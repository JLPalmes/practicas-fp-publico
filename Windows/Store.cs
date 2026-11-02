// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections;
using System.Collections.Generic;
using System.Globalization;
using System.Web.Script.Serialization;
namespace PracticasFP {
    public class Store {
        public Dictionary<string,object> Db;
        public readonly string Folder;
        public string FilePath {
            get {
                return Path.Combine(Folder,"datos.json");
            }
        }
        public string Backups {
            get {
                return Path.Combine(Folder,"Copias");
            }
        }
        readonly List<HistoryEntry> undo=new List<HistoryEntry>(),redo=new List<HistoryEntry>();
        public bool Blocked;
        public string Error;
        public long Revision {
            get;
            private set;
        }
        public readonly QueryCache Queries;
        public long HistoryBytes {
            get {
                return undo.Sum(x=>x.Bytes)+redo.Sum(x=>x.Bytes);
            }
        }
        public Store(string folder) {
            Folder=folder;
            Db=Model.Empty();
            Queries=new QueryCache(this);
            try {
                Directory.CreateDirectory(Backups);
                if(File.Exists(FilePath)) {
                    Db=Model.Decode(File.ReadAllText(FilePath));
                    Backup();
                }
            }
            catch(Exception ex) {
                Blocked=true;
                Error="No se han cargado los datos. El archivo original está protegido. "+ex.Message;
            }
        }
        public void Backup() {
            if(File.Exists(FilePath))File.Copy(FilePath,Path.Combine(Backups,"Copia-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+"-"+Guid.NewGuid().ToString("N").Substring(0,6)+".json"));
        }
        void TrimHistory() {
            while(undo.Count>1&&(undo.Count>50||HistoryBytes>16*1024*1024))undo.RemoveAt(0);
        }
        public void Change(Action action) {
            if(Blocked)throw new Exception(Error);
            string before=J.Json(Db);
            try {
                action();
                string after=J.Json(Db);
                if(after==before)return;
                Model.Decode(after);
                var entry=HistoryEntry.Between(J.Parse(before),Db);
                J.Atomic(FilePath,after);
                undo.Add(entry);
                redo.Clear();
                TrimHistory();
                Revision++;
            }
            catch {
                Db=J.Parse(before);
                Revision++;
                throw;
            }
        }
        public void Undo(bool forward) {
            if(Blocked)throw new Exception(Error);
            var source=forward?redo:undo;
            var target=forward?undo:redo;
            if(source.Count==0)return;
            var entry=source[source.Count-1];
            var updated=J.Clone(Db);
            entry.Apply(updated,forward);
            string value=J.Json(updated);
            Model.Decode(value);
            J.Atomic(FilePath,value);
            target.Add(entry);
            source.RemoveAt(source.Count-1);
            Db=updated;
            Revision++;
        }
        public void Export(string path) {
            if(Blocked)throw new Exception(Error);
            string value=J.Json(Db);
            Model.Decode(value);
            J.Atomic(path,value);
            if(File.ReadAllText(path)!=value)throw new Exception("La copia no se ha verificado.");
        }
        public void Restore(Dictionary<string,object> db) {
            var valid=Model.Decode(J.Json(db));
            var entry=HistoryEntry.Between(Db,valid);
            Backup();
            J.Atomic(FilePath,J.Json(valid));
            undo.Add(entry);
            redo.Clear();
            TrimHistory();
            Db=valid;
            Blocked=false;
            Error=null;
            Revision++;
        }
        public void Archive(string course) {
            if(string.IsNullOrWhiteSpace(course)||course==J.S(Db,"course"))throw new Exception("Indica un curso nuevo distinto del actual.");
            Backup();
            Change(()=> {
                var snapshot=J.Clone(Db);
                snapshot.Remove("archivedCourses");
                J.EditArray(Db,"archivedCourses").Add(J.Obj("id",J.Id(),"title",J.S(Db,"course"),"archivedOn",J.Stamp(J.Today),"snapshot",Convert.ToBase64String(Encoding.UTF8.GetBytes(J.Json(snapshot)))));
                Db["course"]=course;
                Db["students"]=new List<object>();
                Db["exclusions"]=new List<object>();
                Db["instituteDaysConfirmed"]=false;
                int year;
                if(int.TryParse(course.Substring(0,Math.Min(4,course.Length)),out year)&&year>=1900&&year<9999) {
                    Db["calendarFrom"]=J.Stamp(new DateTime(year,9,1));
                    Db["calendarTo"]=J.Stamp(new DateTime(year+1,6,30));
                }
                foreach(var c in Model.Items(Db,"companies"))foreach(string key in new[] {
                    "monthlyContacts","capacity","response","contactedOn","respondedOn"
                })c.Remove(key);
            });
        }
    }
}
