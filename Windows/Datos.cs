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
    // Keep the Swift Codable JSON contract, including unknown fields and numeric dates
    // measured in seconds since 2001-01-01 UTC. Never serialize .NET DateTime values.
    public static class J {
        public static readonly DateTime Epoch = new DateTime(2001,1,1,0,0,0,DateTimeKind.Utc);
        static readonly TimeZoneInfo CanaryZone=TimeZoneInfo.FindSystemTimeZoneById("GMT Standard Time");
        public static JavaScriptSerializer Serializer() {
            return new JavaScriptSerializer {
                MaxJsonLength = 64*1024*1024, RecursionLimit = 200
            };
        }
        public static Dictionary<string,object> Obj(params object[] pairs) {
            var d = new Dictionary<string,object>();
            for(int i=0;
            i<pairs.Length;
            i+=2) d[(string)pairs[i]]=pairs[i+1];
            return d;
        }
        public static Dictionary<string,object> D(object o) {
            return o as Dictionary<string,object> ?? new Dictionary<string,object>();
        }
        public static object Get(object o,string key) {
            object v;
            return D(o).TryGetValue(key,out v)?v:null;
        }
        public static string S(object o,string key) {
            return Convert.ToString(Get(o,key),CultureInfo.InvariantCulture)??"";
        }
        public static double N(object o,string key,double fallback=0) {
            double v;
            return double.TryParse(S(o,key),NumberStyles.Float,CultureInfo.InvariantCulture,out v)?v:fallback;
        }
        public static bool B(object o,string key) {
            return Get(o,key) is bool && (bool)Get(o,key);
        }
        // Reading an absent optional collection must never add it to the database.
        public static List<object> A(object o,string key) {
            return Get(o,key) as List<object> ?? new List<object>();
        }
        public static List<object> EditArray(object o,string key) {
            var owner=D(o);
            var value=Get(o,key);
            if(value!=null && !(value is List<object>))throw new Exception("Se esperaba una lista: "+key);
            if(value==null)owner[key]=new List<object>();
            return (List<object>)owner[key];
        }
        public static string Id() {
            return Guid.NewGuid().ToString().ToUpperInvariant();
        }
        public static double Stamp(DateTime d) {
            return (TimeZoneInfo.ConvertTimeToUtc(DateTime.SpecifyKind(d,DateTimeKind.Unspecified),CanaryZone)-Epoch).TotalSeconds;
        }
        public static DateTime Date(object o,string key) {
            return TimeZoneInfo.ConvertTimeFromUtc(Epoch.AddSeconds(N(o,key,Stamp(Today))),CanaryZone).Date;
        }
        public static DateTime Today {
            get {
                return TimeZoneInfo.ConvertTimeFromUtc(DateTime.UtcNow,CanaryZone).Date;
            }
        }
        public static string Text(DateTime d) {
            return d.ToString("dd/MM/yyyy");
        }
        public static string Json(object o) {
            return Serializer().Serialize(o);
        }
        public static Dictionary<string,object> Parse(string s) {
            return D(Normalize(Serializer().DeserializeObject(s)));
        }
        static object Normalize(object value) {
            var dictionary=value as Dictionary<string,object>;
            if(dictionary!=null) {
                foreach(string key in dictionary.Keys.ToArray())dictionary[key]=Normalize(dictionary[key]);
                return dictionary;
            }
            var array=value as object[];
            return array==null?value:array.Select(Normalize).ToList();
        }
        public static Dictionary<string,object> Clone(object o) {
            return Parse(Json(o));
        }
        public static void Atomic(string path,string data) {
            string temp=path+"."+Guid.NewGuid().ToString("N")+".tmp";
            try {
                using(var f=new FileStream(temp,FileMode.CreateNew,FileAccess.Write,FileShare.None)) {
                    byte[] bytes=new UTF8Encoding(false).GetBytes(data);
                    f.Write(bytes,0,bytes.Length);
                    f.Flush(true);
                }
                if(File.Exists(path))File.Replace(temp,path,null);
                else File.Move(temp,path);
            }
            finally {
                if(File.Exists(temp))File.Delete(temp);
            }
        }
    }
    public class Calculation {
        public DateTime? End;
        public double Last,Elapsed,Manual;
        public string Error;
    }
    public class Period {
        public Dictionary<string,object> Owner;
        public string Company,Tutor;
        public DateTime Start;
        public DateTime? End;
    }
    public static class Model {
        public static readonly string[] StudentSteps= {
            "Certificado de delitos de naturaleza sexual aportado","Anexo I · asignación de tutor a alumna · generado","Anexo I · asignación de tutor a alumna · firmado por mí y remitido a la empresa","Anexo I · asignación de tutor a alumna · devuelto firmado por el tutor","Anexo I · asignación de tutor a alumna · firma de la alumna","Práctica iniciada","Práctica terminada","Anexo II · calificación final de la alumna · generado","Anexo II · calificación final de la alumna · firmado por mí y remitido a la empresa","Anexo II · calificación final de la alumna · devuelto firmado por el tutor"
        };
        public static readonly string[] CompanySteps= {
            "Concierto emitido","Concierto firmado por el director del instituto","Concierto firmado por la empresa","Concierto cargado en la aplicación de gestión"
        };
        public static List<object> Steps(bool company=false) {
            return (company?CompanySteps:StudentSteps).Select(x=>(object)J.Obj("id",J.Id(),"title",x,"done",false,"date",J.Stamp(J.Today))).ToList();
        }
        public static Dictionary<string,object> Student() {
            return J.Obj("id",J.Id(),"name","","group","","dni","","nuss","","email","","phone","","assignment","Pendiente","preferredType","","preferredZone","","preferences","","notes","","hasStart",false,"start",J.Stamp(J.Today),"hours",7.0,"shifts",new List<object>(),"targetHours",500.0,"manualEnd",false,"end",J.Stamp(J.Today),"paperwork",Steps());
        }
        public static Dictionary<string,object> Company() {
            return J.Obj("id",J.Id(),"name","","cif","","address","","contact","","phone","","email","","notes","","paperwork",Steps(true));
        }
        public static Dictionary<string,object> Tutor() {
            return J.Obj("id",J.Id(),"name","","phone","","email","","notes","");
        }
        public static Dictionary<string,object> Exclusion(string title,DateTime from,DateTime to,string kind) {
            return J.Obj("id",J.Id(),"title",title,"from",J.Stamp(from),"to",J.Stamp(to),"kind",kind);
        }
        public static Dictionary<string,object> Empty() {
            var exclusions=new List<object>();
            exclusions.Add(Exclusion("Navidad (BOC, corrección de abril)",new DateTime(2026,12,23),new DateTime(2027,1,8),"Vacaciones"));
            exclusions.Add(Exclusion("Semana Santa",new DateTime(2027,3,22),new DateTime(2027,3,26),"Vacaciones"));
            string[] dates= {
                "2026-09-08","2026-10-12","2026-11-02","2026-12-07","2026-12-08","2027-02-09","2027-05-01","2027-05-30","2027-06-24"
            };
            string[] titles= {
                "Nuestra Señora del Pino","Fiesta Nacional","Todos los Santos","Día del Enseñante y del Estudiante","Inmaculada","Martes de Carnaval · Las Palmas","Fiesta del Trabajo","Día de Canarias","Fundación de la Ciudad"
            };
            for(int i=0;
            i<dates.Length;
            i++) {
                var d=DateTime.ParseExact(dates[i],"yyyy-MM-dd",CultureInfo.InvariantCulture);
                exclusions.Add(Exclusion(titles[i],d,d,"Festivo"));
            }
            return J.Obj("version",4,"students",new List<object>(),"companies",new List<object>(),"tutors",new List<object>(),"course","2026–2027","institute","IES Pérez Galdós","calendarFrom",J.Stamp(new DateTime(2026,9,1)),"calendarTo",J.Stamp(new DateTime(2027,6,30)),"instituteDaysConfirmed",false,"exclusions",exclusions);
        }
        public static IEnumerable<Dictionary<string,object>> Items(object db,string key) {
            return J.A(db,key).Select(J.D);
        }
        public static Dictionary<string,object> Find(object db,string list,string id) {
            return Items(db,list).FirstOrDefault(x=>J.S(x,"id")==id);
        }
        public static string Name(object db,string list,string id) {
            var x=Find(db,list,id);
            return x==null?"Sin asignar":J.S(x,"name");
        }
        public static IEnumerable<string> Companies(object s) {
            return new[] {
                J.S(s,"companyID")
            }
            .Concat(Items(s,"shifts").Select(x=>J.S(x,"companyID"))).Where(x=>x!="").Distinct();
        }
        public static int Occupied(object db,string id) {
            return Items(db,"students").Count(s=>Companies(s).Contains(id));
        }
        public static void Assign(object db,Dictionary<string,object> s,Dictionary<string,object> owner,string id) {
            if(id==J.S(owner,"companyID"))return;
            if(id!=""&&!Companies(s).Contains(id)) {
                var c=Find(db,"companies",id);
                if(c==null||J.S(c,"response")!="accepted"||J.Get(c,"capacity")==null||Occupied(db,id)>=J.N(c,"capacity"))throw new Exception("La empresa no admite alumnas o no dispone de plazas libres.");
            }
            if(id=="") owner.Remove("companyID");
            else owner["companyID"]=id;
            owner.Remove("tutorID");
            if(Object.ReferenceEquals(owner,s)) s["assignment"]=id==""?"Pendiente":"Provisional";
            else if(id!=""&&J.Get(owner,"paperwork")==null)owner["paperwork"]=Steps();
        }
        public static Calculation Calculate(object s,object db,DateTime? today=null) {
            var r=new Calculation();
            double target=J.N(s,"targetHours",500),h=J.N(s,"hours");
            if(target<=0||target>10000||double.IsNaN(target)||double.IsInfinity(target)) {
                r.Error="Las horas objetivo deben estar entre más de 0 y 10.000.";
                return r;
            }
            if(!J.B(s,"hasStart"))return r;
            var changes=Items(s,"shifts").OrderBy(x=>J.Date(x,"from")).ToList();
            if(h<=0||h>24||changes.Any(x=>J.Get(x,"hours")==null||J.N(x,"hours")<=0||J.N(x,"hours")>24)) {
                r.Error="Completa todas las jornadas: más de 0 y hasta 24 horas.";
                return r;
            }
            DateTime start=J.Date(s,"start");
            if(changes.Any(x=>J.Date(x,"from")<start)||changes.Select(x=>J.Date(x,"from")).Distinct().Count()!=changes.Count) {
                r.Error="Los cambios requieren fechas distintas, iguales o posteriores al inicio.";
                return r;
            }
            var exclusions=Items(db,"exclusions").ToList();
            if(exclusions.Any(x=>J.Date(x,"from")>J.Date(x,"to"))) {
                r.Error="Hay un intervalo invertido en Calendario.";
                return r;
            }
            var ranges=exclusions.Select(x=>Tuple.Create(J.Date(x,"from"),J.Date(x,"to"))).ToArray();
            var schedule=changes.Select(x=>Tuple.Create(J.Date(x,"from"),J.N(x,"hours"))).ToArray();
            int changeIndex=0;
            double daily=h;
            double total=0;
            DateTime now=(today??J.Today).Date,manual=J.Date(s,"end"),d=start;
            for(int i=0;
            i<3660;
            i++,d=d.AddDays(1)) {
                while(changeIndex<schedule.Length&&schedule[changeIndex].Item1<=d) {
                    daily=schedule[changeIndex].Item2;
                    changeIndex++;
                }
                if(d.DayOfWeek!=DayOfWeek.Saturday&&d.DayOfWeek!=DayOfWeek.Sunday&&!ranges.Any(x=>d>=x.Item1&&d<=x.Item2)) {
                    if(d<now)r.Elapsed=Math.Min(target,r.Elapsed+daily);
                    if(d<=manual)r.Manual+=daily;
                    if(total<target) {
                        if(total+daily>=target-0.000001) {
                            r.End=d;
                            r.Last=target-total;
                        }
                        total+=daily;
                    }
                }
                if(r.End.HasValue&&(!J.B(s,"manualEnd")||d>=manual)&&d>=now)break;
            }
            if(!r.End.HasValue)r.Error="No se alcanzan las horas objetivo en diez años.";
            return r;
        }
        public static List<Period> Periods(object s,object db,Calculation calculation=null) {
            var c=calculation??Calculate(s,db);
            DateTime? end=c.End.HasValue?(J.B(s,"manualEnd")?J.Date(s,"end"):c.End):null;
            var shifts=Items(s,"shifts").Where(x=>J.S(x,"companyID")!="").OrderBy(x=>J.Date(x,"from")).ToList();
            var result=new List<Period>();
            for(int i=0;
            i<=shifts.Count;
            i++) {
                var owner=i==0?J.D(s):shifts[i-1];
                var e=end;
                if(i<shifts.Count) {
                    var boundary=J.Date(shifts[i],"from").AddDays(-1);
                    e=e.HasValue&&e.Value<boundary?e:boundary;
                }
                result.Add(new Period {
                    Owner=owner,Company=J.S(owner,"companyID"),Tutor=J.S(owner,"tutorID"),Start=J.Date(owner,i==0?"start":"from"),End=e
                });
            }
            return result;
        }
        public static readonly string[] AnnexI= {
            "generated","sentTutor","receivedTutor","sentStudent","receivedStudent","signedByMe","archived"
        };
        public static readonly string[] AnnexII= {
            "generated","sentTutor","receivedTutor","signedByMe","archived"
        };
        public static readonly string[] Agreement= {
            "generated","sentDirector","receivedDirector","sentCompany","receivedCompany","sentCoordinator","uploaded"
        };
        public static string[] Stages(string kind) {
            return kind=="annexI"?AnnexI:kind=="annexII"?AnnexII:Agreement;
        }
        public static string StageTitle(string id) {
            string[] ids= {
                "generated","sentTutor","receivedTutor","sentStudent","receivedStudent","signedByMe","archived","sentDirector","receivedDirector","sentCompany","receivedCompany","sentCoordinator","uploaded"
            };
            string[] names= {
                "Generado","Enviado al tutor","Recibido del tutor","Enviado a la alumna","Recibido de la alumna","Firmado por mí","Archivado","Enviado al director","Recibido del director","Enviado a la empresa","Recibido de la empresa","Enviado al coordinador","Carga confirmada"
            };
            return names[Array.IndexOf(ids,id)];
        }
        static int[] LegacyIndices(string kind) {
            return kind=="annexI"?new[] {
                1,2,3,4
            }
            :kind=="annexII"?new[] {
                7,8,9
            }
            :new[] {
                0,1,2,3
            };
        }
        static string[] LegacyStages(string kind) {
            return kind=="annexI"?new[] {
                "generated","sentTutor","receivedTutor","receivedStudent"
            }
            :kind=="annexII"?new[] {
                "generated","sentTutor","receivedTutor"
            }
            :new[] {
                "generated","receivedDirector","receivedCompany","uploaded"
            };
        }
        public static Dictionary<string,object> Flow(Dictionary<string,object> owner,string kind) {
            var docs=J.A(owner,"documents");
            var flow=docs.Select(J.D).FirstOrDefault(x=>J.S(x,"kind")==kind);
            if(flow!=null)return flow;
            flow=J.Obj("kind",kind,"milestones",Stages(kind).Select(x=>(object)J.Obj("id",x,"completed",false)).ToList());
            var steps=J.A(owner,"paperwork");
            int[] idx=LegacyIndices(kind);
            string[] keys=LegacyStages(kind);
            for(int i=0;
            i<idx.Length;
            i++)if(steps.Count>idx[i]&&J.B(steps[idx[i]],"done"))Complete(flow,keys[i],true,J.Get(steps[idx[i]],"date"));
            if(kind!="agreement") {
                int at=kind=="annexI"?2:8;
                if(steps.Count>at&&J.B(steps[at],"done"))Complete(flow,"signedByMe",true,J.Get(steps[at],"date"));
            }
            return flow;
        }
        public static Dictionary<string,object> EditFlow(Dictionary<string,object> owner,string kind) {
            var documents=J.EditArray(owner,"documents");
            var flow=documents.Select(J.D).FirstOrDefault(x=>J.S(x,"kind")==kind);
            if(flow==null) {
                flow=Flow(owner,kind);
                documents.Add(flow);
            }
            return flow;
        }
        public static bool Done(object flow,string stage) {
            return Items(flow,"milestones").Any(x=>J.S(x,"id")==stage&&J.B(x,"completed"));
        }
        public static void Complete(object flow,string id,bool value,object date) {
            var m=Items(flow,"milestones").First(x=>J.S(x,"id")==id);
            m["completed"]=value;
            m.Remove("date");
            if(value&&date!=null)m["date"]=date;
            string[][] pairs=J.S(flow,"kind")=="agreement"?new[] {
                new[] {
                    "sentDirector","receivedDirector"
                },new[] {
                    "sentCompany","receivedCompany"
                },new[] {
                    "sentCoordinator","uploaded"
                }
            }
            :new[] {
                new[] {
                    "sentTutor","receivedTutor"
                },new[] {
                    "sentStudent","receivedStudent"
                }
            };
            foreach(var p in pairs) {
                var sent=Items(flow,"milestones").FirstOrDefault(x=>J.S(x,"id")==p[0]);
                var received=Items(flow,"milestones").FirstOrDefault(x=>J.S(x,"id")==p[1]);
                if(sent==null||received==null)continue;
                if(id==p[1]&&value&&!J.B(sent,"completed")) {
                    sent["completed"]=true;
                    sent.Remove("date");
                }
                if(id==p[0]&&!value) {
                    received["completed"]=false;
                    received.Remove("date");
                }
            }
        }
        public static void SyncLegacy(Dictionary<string,object> owner,string kind) {
            var flow=Flow(owner,kind);
            var steps=J.A(owner,"paperwork");
            var idx=LegacyIndices(kind);
            var stages=LegacyStages(kind);
            for(int i=0;
            i<idx.Length;
            i++) {
                var step=J.D(steps[idx[i]]);
                var m=Items(flow,"milestones").First(x=>J.S(x,"id")==stages[i]);
                step["done"]=J.B(m,"completed");
                if(J.Get(m,"date")!=null)step["date"]=J.Get(m,"date");
            }
        }
        public static Dictionary<string,object> Decode(string json) {
            var db=J.Parse(json);
            int version=(int)J.N(db,"version");
            if(version<1||version>4)throw new Exception("Formato de datos no compatible (versiones admitidas: 1 a 4).");
            ValidateShape(db);
            foreach(string list in new[] {
                "students","companies","tutors","exclusions"
            }) {
                var items=Items(db,list).ToList();
                if(items.Select(x=>J.S(x,"id")).Distinct().Count()!=items.Count||items.Any(x=>!ValidGuid(J.S(x,"id"))))throw new Exception("Identificadores inválidos en "+list);
            }
            foreach(var c in Items(db,"companies")) {
                if(J.Get(c,"capacity")!=null&&(J.N(c,"capacity")<Occupied(db,J.S(c,"id"))||J.N(c,"capacity")<0))throw new Exception("Cupo de empresa incoherente.");
                CheckSteps(c,4);
                CheckFlows(c,true);
                Unique(Items(c,"monthlyContacts").Select(x=>J.S(x,"id")));
            }
            foreach(var s in Items(db,"students")) {
                CheckSteps(s,10);
                CheckFlows(s,false);
                Unique(Items(s,"shifts").Select(x=>J.S(x,"id")));
                foreach(var shift in Items(s,"shifts")) {
                    if(J.Get(shift,"paperwork")!=null)CheckSteps(shift,10);
                    CheckFlows(shift,false);
                }
            }
            if(version==1) {
                foreach(var s in Items(db,"students"))foreach(int i in new[] {
                    2,8
                })J.D(J.A(s,"paperwork")[i])["done"]=false;
                foreach(var c in Items(db,"companies"))if(J.Get(c,"response")==null&&(Occupied(db,J.S(c,"id"))>0||J.N(c,"capacity")>0))c["response"]="accepted";
            }
            foreach(var s in Items(db,"students")) {
                MigrateSteps(s);
                foreach(var shift in Items(s,"shifts"))if(J.Get(shift,"paperwork")!=null)MigrateSteps(shift);
            }
            db["version"]=4;
            return db;
        }
        static bool ValidGuid(string s) {
            Guid g;
            return Guid.TryParse(s,out g);
        }
        static void Require(bool valid,string field) {
            if(!valid)throw new Exception("Datos incompletos o de tipo incorrecto: "+field);
        }
        static bool IsNumber(object v) {
            return v is int||v is long||v is double||v is decimal||v is float;
        }
        static void Strings(object o,params string[] keys) {
            foreach(string k in keys)Require(J.Get(o,k) is string,k);
        }
        static void Numbers(object o,params string[] keys) {
            foreach(string k in keys)Require(IsNumber(J.Get(o,k))&&!double.IsNaN(J.N(o,k))&&!double.IsInfinity(J.N(o,k)),k);
        }
        static void Dates(object o,params string[] keys) {
            Numbers(o,keys);
            foreach(string k in keys) {
                var ignored=J.Date(o,k);
                Require(ignored.Year>=1900&&ignored.Year<=9998,k);
            }
        }
        static void Bools(object o,params string[] keys) {
            foreach(string k in keys)Require(J.Get(o,k) is bool,k);
        }
        static void ArrayField(object o,string key,bool optional=false) {
            var value=J.Get(o,key);
            if(value==null&&optional)return;
            Require(value is object[]||value is List<object>,key);
            foreach(var item in J.A(o,key))Require(item is Dictionary<string,object>,key);
        }
        static void OptionalId(object o,string key) {
            if(J.Get(o,key)!=null)Require(J.Get(o,key) is string&&ValidGuid(J.S(o,key)),key);
        }
        static void ValidateShape(object db) {
            Strings(db,"course","institute");
            Dates(db,"calendarFrom","calendarTo");
            Bools(db,"instituteDaysConfirmed");
            foreach(string list in new[] {
                "students","companies","tutors","exclusions"
            })ArrayField(db,list);
            foreach(var s in Items(db,"students")) {
                Strings(s,"name","group","dni","nuss","email","phone","assignment","preferredType","preferredZone","preferences","notes");
                Bools(s,"hasStart","manualEnd");
                Dates(s,"start","end");
                Numbers(s,"hours");
                if(J.Get(s,"targetHours")!=null)Numbers(s,"targetHours");
                OptionalId(s,"companyID");
                OptionalId(s,"tutorID");
                ValidateWorkflow(s);
                ArrayField(s,"shifts");
                foreach(var p in Items(s,"shifts")) {
                    Require(ValidGuid(J.S(p,"id")),"id de periodo");
                    Dates(p,"from");
                    if(J.Get(p,"hours")!=null)Numbers(p,"hours");
                    OptionalId(p,"companyID");
                    OptionalId(p,"tutorID");
                    ValidateWorkflow(p,true);
                }
            }
            foreach(var c in Items(db,"companies")) {
                Strings(c,"name","cif","address","contact","phone","email","notes");
                if(J.Get(c,"capacity")!=null) {
                    Numbers(c,"capacity");
                    Require(J.N(c,"capacity")==Math.Truncate(J.N(c,"capacity")),"capacity");
                }
                if(J.Get(c,"response")!=null)Require(new[] {
                    "uncontacted","waiting","accepted","rejected"
                }
                .Contains(J.S(c,"response")),"response");
                foreach(string key in new[] {
                    "contactedOn","respondedOn"
                })if(J.Get(c,key)!=null)Dates(c,key);
                ValidateWorkflow(c);
                ArrayField(c,"monthlyContacts",true);
                foreach(var m in Items(c,"monthlyContacts")) {
                    Strings(m,"id","notes");
                    Bools(m,"completed");
                    Dates(m,"plannedDate","completedOn");
                    var names=J.Get(m,"studentNames");
                    Require(names is object[]||names is List<object>,"studentNames");
                    Require(J.A(m,"studentNames").All(x=>x is string),"studentNames");
                }
            }
            foreach(var t in Items(db,"tutors")) {
                Strings(t,"name","phone","email","notes");
                OptionalId(t,"companyID");
            }
            foreach(var e in Items(db,"exclusions")) {
                Strings(e,"title","kind");
                Dates(e,"from","to");
            }
            ArrayField(db,"archivedCourses",true);
            foreach(var a in Items(db,"archivedCourses")) {
                Strings(a,"id","title","snapshot");
                Require(ValidGuid(J.S(a,"id")),"id de curso");
                Dates(a,"archivedOn");
                Convert.FromBase64String(J.S(a,"snapshot"));
            }
        }
        static void ValidateWorkflow(object o,bool optional=false) {
            ArrayField(o,"paperwork",optional);
            if(J.Get(o,"paperwork")!=null)foreach(var p in Items(o,"paperwork")) {
                Strings(p,"id","title");
                Bools(p,"done");
                Dates(p,"date");
            }
            ArrayField(o,"documents",true);
            foreach(var f in Items(o,"documents")) {
                Strings(f,"kind");
                ArrayField(f,"milestones");
                foreach(var m in Items(f,"milestones")) {
                    Strings(m,"id");
                    Bools(m,"completed");
                    if(J.Get(m,"date")!=null)Dates(m,"date");
                }
            }
        }
        static void Unique(IEnumerable<string> ids) {
            var a=ids.ToList();
            if(a.Distinct().Count()!=a.Count)throw new Exception("Identificadores duplicados.");
        }
        static void CheckSteps(object o,int count) {
            var a=J.A(o,"paperwork");
            if(a.Count!=count||a.Any(x=>!ValidGuid(J.S(x,"id"))))throw new Exception("Trámites incompletos.");
            Unique(a.Select(x=>J.S(x,"id")));
        }
        static void CheckFlows(object o,bool company) {
            var flows=Items(o,"documents").ToList();
            Unique(flows.Select(x=>J.S(x,"kind")));
            foreach(var f in flows) {
                string k=J.S(f,"kind");
                if((company?k!="agreement":k!="annexI"&&k!="annexII")||!Items(f,"milestones").Select(x=>J.S(x,"id")).SequenceEqual(Stages(k)))throw new Exception("Hitos documentales no válidos.");
            }
        }
        static void MigrateSteps(object o) {
            var a=J.A(o,"paperwork");
            for(int i=0;
            i<10;
            i++)J.D(a[i])["title"]=StudentSteps[i];
            foreach(var pair in new[] {
                new[] {
                    2,3
                },new[] {
                    8,9
                }
            })if(J.B(a[pair[1]],"done")&&!J.B(a[pair[0]],"done")) {
                J.D(a[pair[0]])["done"]=true;
                J.D(a[pair[0]])["date"]=J.Get(a[pair[1]],"date");
            }
        }
        public static List<Dictionary<string,object>> Contacts(object db,Dictionary<string,object> c,Func<object,Calculation> calculate=null) {
            var result=new Dictionary<string,Dictionary<string,object>>();
            string id=J.S(c,"id");
            foreach(var s in Items(db,"students").Where(x=>J.S(x,"assignment")=="Definitiva"&&J.B(x,"hasStart"))) {
                var calculation=calculate==null?Calculate(s,db):calculate(s);
                if(calculation.Error!=null)continue;
                foreach(var p in Periods(s,db,calculation).Where(x=>x.Company==id&&x.End.HasValue)) {
                    DateTime end=p.End.Value;
                    var steps=J.A(p.Owner,"paperwork");
                    if(steps.Count>6&&J.B(steps[6],"done")&&J.Date(steps[6],"date")<end)end=J.Date(steps[6],"date");
                    for(int n=1;
                    n<=120;
                    n++) {
                        DateTime due=p.Start.AddMonths(n);
                        if(due>end)break;
                        string key=due.ToString("yyyy-MM");
                        Dictionary<string,object> contact;
                        if(!result.TryGetValue(key,out contact)) {
                            contact=J.Obj("id",key,"plannedDate",J.Stamp(due),"studentNames",new List<object>(),"completed",false,"completedOn",J.Stamp(J.Today),"notes","");
                            result[key]=contact;
                        }
                        if(due<J.Date(contact,"plannedDate"))contact["plannedDate"]=J.Stamp(due);
                        if(!J.A(contact,"studentNames").Contains(J.S(s,"name")))J.A(contact,"studentNames").Add(J.S(s,"name"));
                    }
                }
            }
            foreach(var saved in Items(c,"monthlyContacts")) {
                string key=J.S(saved,"id");
                Dictionary<string,object> planned;
                if(result.TryGetValue(key,out planned)) {
                    var merged=J.Clone(saved);
                    if(!J.B(saved,"completed")) {
                        merged["plannedDate"]=planned["plannedDate"];
                        merged["studentNames"]=planned["studentNames"];
                    }
                    result[key]=merged;
                }
                else {
                    var historical=J.Clone(saved);
                    historical["historical"]=true;
                    result[key]=historical;
                }
            }
            return result.Values.OrderBy(x=>J.Date(x,"plannedDate")).ToList();
        }
        public static string Report(object db,Dictionary<string,object> selected=null,string section="") {
            var b=new StringBuilder("PRÁCTICAS FP · "+J.S(db,"course")+"\r\n"+J.S(db,"institute")+"\r\nInforme: "+J.Text(J.Today)+"\r\nHoras previstas; no es un registro de asistencia.\r\n\r\n");
            foreach(var s in Items(db,"students").Where(x=>selected==null||section=="students"&&J.S(x,"id")==J.S(selected,"id")||section=="companies"&&Companies(x).Contains(J.S(selected,"id")))) {
                var calc=Calculate(s,db);
                b.AppendLine("ALUMNA: "+J.S(s,"name")+" · "+J.S(s,"group"));
                b.AppendLine("Asignación: "+J.S(s,"assignment")+" · Objetivo: "+J.N(s,"targetHours",500)+" h · Previstas hasta ayer: "+calc.Elapsed+" h");
                b.AppendLine("Inicio: "+(J.B(s,"hasStart")?J.Text(J.Date(s,"start")):"Sin establecer")+" · Fin: "+(calc.End.HasValue?J.Text(J.B(s,"manualEnd")?J.Date(s,"end"):calc.End.Value):"Sin calcular"));
                b.AppendLine("Jornada inicial: "+J.N(s,"hours")+" h/día");
                foreach(var shift in Items(s,"shifts").OrderBy(x=>J.Date(x,"from")))b.AppendLine("Cambio "+J.Text(J.Date(shift,"from"))+": "+J.S(shift,"hours")+" h/día");
                if(calc.Error!=null)b.AppendLine(calc.Error);
                if(calc.End.HasValue&&(J.Date(s,"start")<J.Date(db,"calendarFrom")||calc.End.Value>J.Date(db,"calendarTo")))b.AppendLine("Previsión fuera del calendario revisado.");
                foreach(var p in Periods(s,db)) {
                    b.AppendLine("Empresa: "+Name(db,"companies",p.Company)+" · Tutor: "+Name(db,"tutors",p.Tutor));
                    b.AppendLine("Periodo: "+(J.B(s,"hasStart")?J.Text(p.Start):"Sin inicio")+" – "+(p.End.HasValue?J.Text(p.End.Value):"Sin calcular"));
                    foreach(int i in Object.ReferenceEquals(p.Owner,s)?new[] {
                        0,5,6
                    }
                    :new[] {
                        5,6
                    }) {
                        var steps=J.A(p.Owner,"paperwork");
                        if(steps.Count>i)b.AppendLine(J.S(steps[i],"title")+": "+(J.B(steps[i],"done")?"Hecho · "+J.Text(J.Date(steps[i],"date")):"Pendiente"));
                    }
                    foreach(string kind in new[] {
                        "annexI","annexII"
                    })ReportFlow(b,Flow(p.Owner,kind));
                }
                b.AppendLine();
            }
            foreach(var c in Items(db,"companies").Where(x=>selected==null||section=="companies"&&J.S(x,"id")==J.S(selected,"id"))) {
                b.AppendLine("EMPRESA: "+J.S(c,"name"));
                b.AppendLine("Plazas: "+Occupied(db,J.S(c,"id"))+" / "+J.S(c,"capacity")+" · Respuesta: "+J.S(c,"response"));
                ReportFlow(b,Flow(c,"agreement"));
                foreach(var contact in Contacts(db,c))b.AppendLine("Contacto "+J.Text(J.Date(contact,"plannedDate"))+": "+(J.B(contact,"completed")?"Realizado · "+J.Text(J.Date(contact,"completedOn")):"Pendiente")+" · "+J.S(contact,"notes"));
                b.AppendLine();
            }
            if(!J.B(db,"instituteDaysConfirmed"))b.AppendLine("Previsión provisional: faltan los días de libre disposición del instituto.");
            return b.ToString();
        }
        static void ReportFlow(StringBuilder b,object flow) {
            foreach(var m in Items(flow,"milestones"))b.AppendLine(J.S(flow,"kind")+" · "+StageTitle(J.S(m,"id"))+": "+(J.B(m,"completed")?"Hecho · "+(J.Get(m,"date")==null?"Fecha sin registrar":J.Text(J.Date(m,"date"))):"Pendiente"));
        }
    }
}
