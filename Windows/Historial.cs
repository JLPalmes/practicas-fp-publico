// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.Collections.Generic;
using System.Linq;
using System.Text;
namespace PracticasFP {
    // A history entry holds changed leaves only. Unchanged archived-course snapshots
    // are never copied into each undo step. Array insertions/deletions use one patch.
    public sealed class HistoryEntry {
        sealed class Patch {
            public string[] Path;
            public bool HadBefore, HasAfter;
            public object Before, After;
        }
        readonly List<Patch> patches=new List<Patch>();
        public long Bytes {
            get;
            private set;
        }
        public bool Empty {
            get {
                return patches.Count==0;
            }
        }
        static object Copy(object value) {
            if(value==null)return null;
            return J.Get(J.Parse(J.Json(J.Obj("value",value))),"value");
        }
        public static HistoryEntry Between(object before,object after) {
            var result=new HistoryEntry();
            result.Compare(before,after,new string[0],true,true);
            return result;
        }
        void Compare(object before,object after,string[] path,bool hadBefore,bool hasAfter) {
            var a=before as Dictionary<string,object>;
            var b=after as Dictionary<string,object>;
            if(hadBefore&&hasAfter&&a!=null&&b!=null) {
                foreach(string key in a.Keys.Union(b.Keys)) {
                    object av,bv;
                    bool ah=a.TryGetValue(key,out av),bh=b.TryGetValue(key,out bv);
                    Compare(av,bv,path.Concat(new[] {
                        key
                    }).ToArray(),ah,bh);
                }
                return;
            }
            var al=before as List<object>;
            var bl=after as List<object>;
            if(hadBefore&&hasAfter&&al!=null&&bl!=null&&al.Count==bl.Count) {
                for(int i=0;
                i<al.Count;
                i++)Compare(al[i],bl[i],path.Concat(new[] {
                    i.ToString()
                }).ToArray(),true,true);
                return;
            }
            if(hadBefore==hasAfter&&object.Equals(before,after))return;
            if(hadBefore==hasAfter&&J.Json(before)==J.Json(after))return;
            patches.Add(new Patch {
                Path=path,HadBefore=hadBefore,HasAfter=hasAfter,Before=Copy(before),After=Copy(after)
            });
            Bytes+=Encoding.UTF8.GetByteCount(J.Json(before))+Encoding.UTF8.GetByteCount(J.Json(after))+path.Sum(x=>x.Length*2)+64;
        }
        public void Apply(Dictionary<string,object> db,bool forward) {
            foreach(var p in patches) {
                object parent=db;
                for(int i=0;
                i<p.Path.Length-1;
                i++) {
                    var list=parent as List<object>;
                    parent=list!=null?list[int.Parse(p.Path[i])]:J.D(parent)[p.Path[i]];
                }
                string key=p.Path.Last();
                object value=Copy(forward?p.After:p.Before);
                var array=parent as List<object>;
                if(array!=null)array[int.Parse(key)]=value;
                else if(forward?p.HasAfter:p.HadBefore)J.D(parent)[key]=value;
                else J.D(parent).Remove(key);
            }
        }
    }
    // Calculations are shared within one saved revision and one Canary calendar day.
    // Every successful edit, undo, redo or restore invalidates this cache.
    public sealed class QueryCache {
        readonly Store store;
        long revision=-1;
        DateTime day;
        readonly Dictionary<string,Calculation> calculations=new Dictionary<string,Calculation>();
        readonly Dictionary<string,List<Period>> periods=new Dictionary<string,List<Period>>();
        readonly Dictionary<string,List<Dictionary<string,object>>> contacts=new Dictionary<string,List<Dictionary<string,object>>>();
        readonly Dictionary<string,int> occupied=new Dictionary<string,int>();
        public int CalculationRuns {
            get;
            private set;
        }
        public QueryCache(Store value) {
            store=value;
        }
        void Check() {
            if(revision==store.Revision&&day==J.Today)return;
            revision=store.Revision;
            day=J.Today;
            calculations.Clear();
            periods.Clear();
            contacts.Clear();
            occupied.Clear();
        }
        public Calculation Calculate(object student) {
            Check();
            string id=J.S(student,"id");
            Calculation value;
            if(!calculations.TryGetValue(id,out value)) {
                value=Model.Calculate(student,store.Db,day);
                calculations[id]=value;
                CalculationRuns++;
            }
            return value;
        }
        public List<Period> Periods(object student) {
            Check();
            string id=J.S(student,"id");
            List<Period> value;
            if(!periods.TryGetValue(id,out value)) {
                value=Model.Periods(student,store.Db,Calculate(student));
                periods[id]=value;
            }
            return value;
        }
        public List<Dictionary<string,object>> Contacts(Dictionary<string,object> company) {
            Check();
            string id=J.S(company,"id");
            List<Dictionary<string,object>> value;
            if(!contacts.TryGetValue(id,out value)) {
                value=Model.Contacts(store.Db,company,Calculate);
                contacts[id]=value;
            }
            return value;
        }
        public int Occupied(string id) {
            Check();
            int value;
            if(!occupied.TryGetValue(id,out value)) {
                value=Model.Occupied(store.Db,id);
                occupied[id]=value;
            }
            return value;
        }
    }
}
