// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;
using System.Windows.Forms;
using PracticasFP;

internal static class Rendimiento {
    static readonly string[] Annexes={"annexI","annexII"};
    static readonly string[] PersonalFields={"name","group","dni","nuss","phone","email","preferredType","preferredZone","preferences","notes"};
    static IEnumerable<Control> Controls(Control parent) {
        foreach(Control child in parent.Controls) {
            yield return child;
            foreach(var descendant in Controls(child))yield return descendant;
        }
    }

    internal static void Measure(string name,Action<int> action) {
        const int samples=30;
        for(int i=0;i<4;i++)action(i);
        var times=new double[samples];
        for(int i=0;i<samples;i++) {
            var timer=Stopwatch.StartNew();
            action(i);
            times[i]=timer.Elapsed.TotalMilliseconds;
        }
        Array.Sort(times);
        Console.WriteLine("{0}: mediana {1:F2} ms, p95 {2:F2} ms",name,
            (times[14]+times[15])/2,times[28]);
    }

    internal static Dictionary<string,object> Fixture() {
        var db=Model.Empty();
        var company=Model.Company();
        company["name"]="Empresa de prueba";
        var alternate=Model.Company();
        alternate["name"]="Segunda empresa de prueba";
        alternate["response"]="accepted";
        alternate["capacity"]=300;
        var unavailable=Model.Company();
        unavailable["name"]="Empresa sin plazas";
        var students=new List<object>();
        for(int i=0;i<300;i++) {
            var student=Model.Student();
            student["name"]="Alumna "+i.ToString("D3");
            student["group"]="Grupo "+(i%10+1);
            student["preferredZone"]=i%2==0?"Centro":"Norte";
            student["preferences"]="Disponibilidad de mañana durante el primer periodo.";
            student["companyID"]=J.S(company,"id");
            Model.ConvertPeriods(student,db);
            var periods=Model.Items(student,"practicePeriods").ToArray();
            periods[1]["active"]=true;
            periods[1]["companyID"]=J.S(company,"id");
            for(int j=0;j<periods.Length;j++) {
                var period=periods[j];
                var start=new DateTime(2026,j==0?9:11,7).AddDays(i%3);
                period["hasStart"]=true;
                period["manualEnd"]=true;
                period["start"]=J.Stamp(start);
                period["end"]=J.Stamp(start.AddDays(19));
                J.EditArray(period,"shifts").Add(J.Obj("id",J.Id(),"from",J.Stamp(start.AddDays(5)),"hours",5.5));
                if(i>1&&i%3==0) {
                    Model.Complete(Model.EditFlow(period,"annexI"),"sentTutor",true,null);
                    Model.SyncLegacy(period,"annexI");
                }
            }
            students.Add(student);
        }
        db["companies"]=new List<object>{company,alternate,unavailable};
        var firstTutor=Model.Tutor();
        firstTutor["name"]="Tutora de la primera empresa";
        firstTutor["companyID"]=J.S(company,"id");
        var secondTutor=Model.Tutor();
        secondTutor["name"]="Tutor de la segunda empresa";
        secondTutor["companyID"]=J.S(alternate,"id");
        db["tutors"]=new List<object>{firstTutor,secondTutor};
        db["students"]=students;
        db["version"]=5;
        return Model.Decode(J.Json(db));
    }

    static object ReadFicha(Store store,Dictionary<string,object> record) {
        var forecast=store.Queries.Calculate(record);
        var calculated=store.Queries.Periods(record);
        var periods=Model.Items(record,"practicePeriods").Select(owner=>
            calculated.FirstOrDefault(p=>Object.ReferenceEquals(p.Owner,owner))??new Period {
                Owner=owner,Company=J.S(owner,"companyID"),Tutor=J.S(owner,"tutorID"),
                Start=J.Date(owner,"start"),Result=new Calculation()
            }).Select(p=>J.Obj(
            "company",p.Company,"tutor",p.Tutor,"assignment",Model.PeriodAssignment(record,p.Owner),
            "practice",new[]{5,6}.Select(i=>J.B(J.A(p.Owner,"paperwork")[i],"done")).ToArray(),
            "practiceEndDate",J.B(J.A(p.Owner,"paperwork")[6],"done")?IsoDate(J.Date(J.A(p.Owner,"paperwork")[6],"date")):"",
            "start",J.B(p.Owner,"hasStart")?IsoDate(p.Start):"",
            "end",J.B(p.Owner,"manualEnd")?IsoDate(J.Date(p.Owner,"end")):"",
            "forecastEnd",p.End.HasValue?IsoDate(p.End.Value):"",
            "error",p.Result.Error??"",
            "shifts",Model.Items(p.Owner,"shifts").OrderBy(s=>J.Date(s,"from")).Select(s=>J.Obj(
                "id",J.S(s,"id"),"from",IsoDate(J.Date(s,"from")),"hours",J.N(s,"hours"))).ToArray(),
            "annexes",Annexes.Select(kind=>J.Obj("kind",kind,"steps",Model.Items(Model.Flow(p.Owner,kind),"milestones")
                .Select(step=>J.Obj("id",J.S(step,"id"),"label",Model.StageTitle(J.S(step,"id")),
                    "checked",J.B(step,"completed"),"dated",J.Get(step,"date")!=null)).ToArray())).ToArray(),
            "hours",J.N(p.Owner,"hours"),"target",J.N(p.Owner,"targetHours"))).ToArray();
        var result=J.Obj(
            "certificate",J.B(J.A(record,"paperwork")[0],"done"),
            "warnings",WorkspaceRules.StudentWarnings(store.Db,record).ToArray(),
            "secondActive",J.B(Model.Items(record,"practicePeriods").Last(),"active"),
            "target",J.N(record,"targetHours"),"previous",J.N(record,"previousCourseHours"),"next",J.N(record,"nextCourseHours"),
            "periods",periods,"elapsed",forecast.Elapsed,"remaining",Model.RemainingHours(record,forecast.Elapsed));
        foreach(string key in PersonalFields)result[key]=J.S(record,key);
        result["card"]=StudentCard(store.Db,record);
        return result;
    }

    static object StudentCard(object db,object record) {
        var lines=WorkspaceRules.StudentLines(J.D(db),J.D(record));
        return J.Obj("id",J.S(record,"id"),"name",J.S(record,"name"),"lines",lines,
            "search",Importer.Key(string.Join(" ",lines)+" "+J.S(record,"dni")+" "+J.S(record,"group")));
    }

    static void EditAnnexes(Dictionary<string,object> period,object fields,bool company=false) {
        foreach(var edit in Model.Items(fields,"annexEdits")) {
            string kind=J.S(edit,"kind"),stage=J.S(edit,"id");
            var value=J.Get(edit,"checked");
            if((company?kind!="agreement":!Annexes.Contains(kind))||!Model.Stages(kind).Contains(stage)||!(value is bool))
                throw new ArgumentException("Hito de documentación desconocido.");
            bool completed=(bool)value;
            if(Model.Done(Model.Flow(period,kind),stage)==completed)continue;
            Model.Complete(Model.EditFlow(period,kind),stage,completed,null);
            Model.SyncLegacy(period,kind);
        }
    }

    static List<object> ReadShifts(object period,object fields,DateTime? start) {
        var existing=Model.Items(period,"shifts").ToDictionary(s=>J.S(s,"id"));
        var dates=new HashSet<DateTime>();
        var ids=new HashSet<string>();
        var result=new List<object>();
        foreach(var edit in Model.Items(fields,"shifts")) {
            var from=OptionalDate(edit,"from","la fecha del cambio de jornada");
            if(!from.HasValue || (start.HasValue&&from.Value<start.Value) || !dates.Add(from.Value))
                throw new ArgumentException("Cada cambio de jornada requiere una fecha distinta, igual o posterior al inicio.");
            string id=J.S(edit,"id");
            Dictionary<string,object> original;
            if(id!=""&&(!existing.ContainsKey(id)||!ids.Add(id)))
                throw new ArgumentException("Cambio de jornada desconocido o repetido.");
            var shift=existing.TryGetValue(id,out original)?J.Clone(original):J.Obj("id",J.Id());
            shift["from"]=J.Stamp(from.Value);
            shift["hours"]=Hours(edit,"hours","las horas del cambio de jornada",0.01m,24);
            result.Add(shift);
        }
        return result;
    }

    static string IsoDate(DateTime date) {
        return date.ToString("yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture);
    }

    static DateTime? OptionalDate(object period,string key,string label) {
        string text=J.S(period,key);
        if(text=="")return null;
        DateTime date;
        if(!DateTime.TryParseExact(text,"yyyy-MM-dd",System.Globalization.CultureInfo.InvariantCulture,
                System.Globalization.DateTimeStyles.None,out date))
            throw new ArgumentException("Revisa "+label+".");
        return date;
    }

    static double Hours(object fields,string key,string label,decimal min,decimal max) {
        decimal number;
        string text=J.S(fields,key).Trim().Replace(',','.');
        if(!decimal.TryParse(text,System.Globalization.NumberStyles.AllowDecimalPoint,
                System.Globalization.CultureInfo.InvariantCulture,out number) ||
            number<min || number>max || decimal.Round(number,2)!=number)
            throw new ArgumentException("Revisa "+label+".");
        return (double)number;
    }

    static void SaveFicha(Store store,Dictionary<string,object> record,object fields) {
        string email=J.S(fields,"email").Trim();
        if(email!=""&&(!email.Contains("@")||email.Any(char.IsWhiteSpace)))
            throw new ArgumentException("Revisa el correo.");
        double target=Hours(fields,"target","el objetivo general",0.01m,10000);
        double previous=Hours(fields,"previous","las horas del curso anterior",0,10000);
        double next=Hours(fields,"next","las horas para el curso siguiente",0,10000);
        var allPeriods=Model.Items(record,"practicePeriods").ToArray();
        var secondActive=J.Get(fields,"secondActive") as bool?;
        bool activate=secondActive??J.B(allPeriods[1],"active");
        var periods=allPeriods.Take(activate?2:1).ToArray();
        var edits=Model.Items(fields,"periods").ToArray();
        if(edits.Length!=periods.Length)throw new ArgumentException("Los periodos de la ficha han cambiado.");
        var values=edits.Select((period,i)=>new {
            Daily=Hours(period,"hours","la jornada del periodo "+(i+1),0.01m,24),
            Target=Hours(period,"target","el objetivo del periodo "+(i+1),0,10000),
            Company=J.S(period,"company"),
            Tutor=J.S(period,"tutor"),
            Assignment=J.S(period,"assignment"),
            Start=OptionalDate(period,"start","el inicio del periodo "+(i+1)),
            End=OptionalDate(period,"end","el fin manual del periodo "+(i+1))
        }).ToArray();
        if(values.Any(value=>value.End.HasValue&&(!value.Start.HasValue||value.End.Value<value.Start.Value)))
            throw new ArgumentException("El fin manual requiere un inicio y debe ser igual o posterior.");
        var changes=values.Select((value,i)=>ReadShifts(periods[i],edits[i],value.Start)).ToArray();
        store.Change(()=> {
            allPeriods[1]["active"]=activate;
            foreach(string key in PersonalFields)record[key]=J.S(fields,key).Trim();
            if(J.Get(fields,"certificate") is bool)
                J.D(J.A(record,"paperwork")[0])["done"]=J.B(fields,"certificate");
            record["targetHours"]=target;
            record["previousCourseHours"]=previous;
            record["nextCourseHours"]=next;
            for(int i=0;i<periods.Length;i++) {
                var period=periods[i];
                var value=values[i];
                if(value.Company!=""||J.S(period,"companyID")!="")Model.Assign(store.Db,record,period,value.Company);
                else if(value.Assignment!="Pendiente"||value.Tutor!="")
                    throw new ArgumentException("Selecciona una empresa para este periodo.");
                if(!new[]{"Pendiente","Provisional","Definitiva"}.Contains(value.Assignment))
                    throw new ArgumentException("Revisa el estado de la asignación.");
                if(value.Tutor!=""&&J.S(Model.Find(store.Db,"tutors",value.Tutor),"companyID")!=value.Company)
                    throw new ArgumentException("El tutor debe pertenecer a la empresa del periodo.");
                if(value.Tutor=="")period.Remove("tutorID");
                else period["tutorID"]=value.Tutor;
                period["assignment"]=value.Assignment;
                period["hours"]=value.Daily;
                period["targetHours"]=value.Target;
                period["hasStart"]=value.Start.HasValue;
                period["manualEnd"]=value.End.HasValue;
                period["shifts"]=changes[i];
                if(value.Start.HasValue)period["start"]=J.Stamp(value.Start.Value);
                if(value.End.HasValue)period["end"]=J.Stamp(value.End.Value);
                EditAnnexes(period,edits[i]);
                var practice=J.A(edits[i],"practice");
                if(practice.Count==2) {
                    for(int j=0;j<2;j++) {
                        var step=J.D(J.A(period,"paperwork")[5+j]);
                        if(!(practice[j] is bool))throw new ArgumentException("Revisa el estado de las prácticas.");
                        bool done=(bool)practice[j];
                        bool previouslyDone=J.B(step,"done");
                        if(j==1&&done) {
                            var completion=OptionalDate(edits[i],"practiceEndDate","la fecha de práctica terminada");
                            if(completion.HasValue&&value.Start.HasValue&&completion.Value<value.Start.Value)
                                throw new ArgumentException("La práctica no puede terminar antes de comenzar.");
                            if(completion.HasValue||!previouslyDone)
                                step["date"]=J.Stamp(completion??value.End??J.Today);
                        } else if(done&&!previouslyDone)step["date"]=J.Stamp(J.Today);
                        step["done"]=done;
                    }
                }
            }
        });
    }

    static object DirectoryData(Store store) {
        var companies=Model.Items(store.Db,"companies").Select(c=>{
            var result=J.Clone(c);
            result["occupied"]=store.Queries.Occupied(J.S(c,"id"));
            result["students"]=Model.Items(store.Db,"students").Where(s=>Model.Companies(s).Contains(J.S(c,"id")))
                .Select(s=>J.S(s,"name")).ToArray();
            foreach(string key in new[]{"contactedOn","respondedOn"})
                result[key]=J.Get(c,key)!=null?IsoDate(J.Date(c,key)):"";
            return result;
        }).ToArray();
        var tutors=Model.Items(store.Db,"tutors").Select(t=>{
            var result=J.Clone(t);
            result["company"]=J.S(t,"companyID");
            result["students"]=WorkspaceRules.TutorStudents(store.Db,J.S(t,"id")).Select(s=>J.S(s,"name")).ToArray();
            return result;
        }).ToArray();
        return J.Obj("cards",Model.Items(store.Db,"students").Select(s=>StudentCard(store.Db,s)).ToArray(),
            "companies",companies,"tutors",tutors);
    }

    static object CompanyDetails(Store store,Dictionary<string,object> company) {
        string companyId=J.S(company,"id");
        return J.Obj("links",Model.Items(store.Db,"students").Where(s=>Model.Companies(s).Contains(companyId))
            .Select(s=>J.Obj("kind","students","id",J.S(s,"id"),
                "label",J.S(s,"name")+" · "+Model.AssignmentSummary(s,companyId)))
            .Concat(Model.Items(store.Db,"tutors").Where(t=>J.S(t,"companyID")==companyId)
                .Select(t=>J.Obj("kind","tutors","id",J.S(t,"id"),"label",J.S(t,"name")))).ToArray(),
            "agreement",Model.Items(Model.Flow(company,"agreement"),"milestones").Select(step=>
            J.Obj("id",J.S(step,"id"),"label",Model.StageTitle(J.S(step,"id")),
                "checked",J.B(step,"completed"),"dated",J.Get(step,"date")!=null)).ToArray(),
            "contacts",store.Queries.Contacts(company).Select(contact=>{
                string id=J.S(contact,"id");
                var saved=Model.Items(company,"monthlyContacts").FirstOrDefault(item=>J.S(item,"id")==id);
                return J.Obj("id",id,"planned",IsoDate(J.Date(saved??contact,"plannedDate")),
                    "doneOn",J.Get(contact,"completedOn")==null?"":IsoDate(J.Date(contact,"completedOn")),
                    "completed",J.B(contact,"completed"),"notes",J.S(contact,"notes"),
                    "historical",J.B(contact,"historical"),"students",J.A(contact,"studentNames"),
                    "saved",saved!=null);
            }).ToArray());
    }

    static object TutorLinks(Store store,Dictionary<string,object> tutor) {
        var result=WorkspaceRules.TutorStudents(store.Db,J.S(tutor,"id")).Select(student=>
            J.Obj("kind","students","id",J.S(student,"id"),"label",J.S(student,"name"))).ToList();
        string company=J.S(tutor,"companyID");
        if(company!="")result.Insert(0,J.Obj("kind","companies","id",company,"label",Model.Name(store.Db,"companies",company)));
        return result;
    }

    static void SaveContacts(Store store,Dictionary<string,object> company,object fields) {
        var edits=Model.Items(fields,"contacts").ToArray();
        if(edits.Length==0)return;
        var scheduled=Model.Contacts(store.Db,company).ToDictionary(c=>J.S(c,"id"));
        foreach(var edit in edits) {
            string id=J.S(edit,"id");
            var contact=Model.Items(company,"monthlyContacts").FirstOrDefault(c=>J.S(c,"id")==id);
            if(contact==null) {
                Dictionary<string,object> planned;
                if(!scheduled.TryGetValue(id,out planned))throw new ArgumentException("El seguimiento ya no está previsto.");
                contact=J.Clone(planned);
                contact.Remove("historical");
                J.EditArray(company,"monthlyContacts").Add(contact);
            }
            var date=OptionalDate(edit,"planned","la fecha prevista");
            if(!date.HasValue)throw new ArgumentException("Indica la fecha prevista del seguimiento.");
            bool completed=J.B(edit,"completed");
            var done=OptionalDate(edit,"doneOn","la fecha de realización");
            contact["plannedDate"]=J.Stamp(date.Value);
            contact["completed"]=completed;
            contact["notes"]=J.S(edit,"notes");
            if(completed)contact["completedOn"]=J.Stamp(done??J.Today);
        }
    }

    static object SaveDirectory(Store store,object request) {
        string kind=J.S(request,"kind");
        if(kind!="companies"&&kind!="tutors")throw new ArgumentException("Tipo de ficha desconocido.");
        bool company=kind=="companies";
        var fields=J.Get(request,"fields");
        string id=J.S(fields,"id");
        var record=id==""?(company?Model.Company():Model.Tutor()):Model.Find(store.Db,kind,id);
        if(record==null)throw new ArgumentException("Ficha desconocida.");
        store.Change(()=>{
            foreach(string key in company?new[]{"name","cif","address","contact","phone","email","notes"}:
                new[]{"name","phone","email","notes"})record[key]=J.S(fields,key).Trim();
            if(company) {
                string response=J.S(fields,"response");
                if(!new[]{"uncontacted","waiting","accepted","rejected"}.Contains(response))
                    throw new ArgumentException("Estado de contacto desconocido.");
                record["response"]=response;
                if(response=="accepted") {
                    int minimum=Math.Max(1,Model.Occupied(store.Db,J.S(record,"id")));
                    int capacity;
                    string typed=J.S(fields,"capacity").Trim();
                    if(typed=="")capacity=Math.Max(minimum,(int)J.N(record,"capacity"));
                    else if(!int.TryParse(typed,out capacity)||capacity<minimum||capacity>100000)
                        throw new ArgumentException("El cupo debe ser un entero entre "+minimum+" y 100000.");
                    record["capacity"]=capacity;
                }
                foreach(string key in new[]{"contactedOn","respondedOn"}) {
                    var date=OptionalDate(fields,key,"la fecha de contacto o respuesta");
                    if(date.HasValue)record[key]=J.Stamp(date.Value);
                    else record.Remove(key);
                }
                EditAnnexes(record,fields,true);
                SaveContacts(store,record,fields);
            } else {
                string next=J.S(fields,"company");
                if(next!=""&&Model.Find(store.Db,"companies",next)==null)throw new ArgumentException("Empresa desconocida.");
                if(next!=J.S(record,"companyID")&&Model.Items(store.Db,"students").Any(s=>Model.HasTutor(s,J.S(record,"id"))))
                    throw new ArgumentException("Retira las asignaciones del tutor antes de cambiar su empresa.");
                if(next=="")record.Remove("companyID");
                else record["companyID"]=next;
            }
            if(id=="")J.EditArray(store.Db,kind).Add(record);
        });
        return DirectoryData(store);
    }

    static object CalendarData(object db) {
        return J.Obj("from",IsoDate(J.Date(db,"calendarFrom")),"to",IsoDate(J.Date(db,"calendarTo")),
            "confirmed",J.B(db,"instituteDaysConfirmed"),
            "exclusions",Model.Items(db,"exclusions").OrderBy(item=>J.Date(item,"from")).Select(item=>
                J.Obj("id",J.S(item,"id"),"title",J.S(item,"title"),"kind",J.S(item,"kind"),
                    "from",IsoDate(J.Date(item,"from")),"to",IsoDate(J.Date(item,"to")))).ToArray());
    }

    static void ChangeCalendar(Store store,string action,object fields) {
        if(action=="deleteExclusion") {
            var deleted=Model.Find(store.Db,"exclusions",J.S(fields,"id"));
            if(deleted==null)throw new ArgumentException("Día o intervalo desconocido.");
            store.Change(()=>J.EditArray(store.Db,"exclusions").Remove(deleted));
            return;
        }
        var from=OptionalDate(fields,"from","la fecha inicial");
        var to=OptionalDate(fields,"to","la fecha final");
        if(!from.HasValue||!to.HasValue||from.Value>to.Value)
            throw new ArgumentException("Indica un intervalo con el fin igual o posterior al inicio.");
        if(action=="saveCalendar") {
            store.Change(()=>{
                store.Db["calendarFrom"]=J.Stamp(from.Value);
                store.Db["calendarTo"]=J.Stamp(to.Value);
                store.Db["instituteDaysConfirmed"]=J.B(fields,"confirmed");
            });
            return;
        }
        string id=J.S(fields,"id");
        string title=J.S(fields,"title").Trim(),kind=J.S(fields,"kind").Trim();
        var item=id==""?Model.Exclusion(title,from.Value,to.Value,kind):Model.Find(store.Db,"exclusions",id);
        if(item==null)throw new ArgumentException("Día o intervalo desconocido.");
        store.Change(()=>{
            item["title"]=title;
            item["kind"]=kind;
            item["from"]=J.Stamp(from.Value);
            item["to"]=J.Stamp(to.Value);
            if(id=="")J.EditArray(store.Db,"exclusions").Add(item);
        });
    }

    static Dictionary<string,object> ReadCourseCopy(string path) {
        var recovered=Model.Decode(File.ReadAllText(path));
        foreach(var student in Model.Items(recovered,"students"))Model.ConvertPeriods(student,recovered);
        recovered["version"]=5;
        return Model.Decode(J.Json(recovered));
    }

    static object BackupPreview(object db) {
        return J.Obj("institute",J.S(db,"institute"),"course",J.S(db,"course"),
            "students",J.A(db,"students").Count,"companies",J.A(db,"companies").Count,"tutors",J.A(db,"tutors").Count);
    }

    sealed class DialogOwner : IWin32Window {
        public IntPtr Handle {get;private set;}
        public DialogOwner(long handle) {Handle=new IntPtr(handle);}
    }

    static IWin32Window GetDialogOwner(object request) {
        long handle;
        return Int64.TryParse(J.S(request,"owner"),out handle)&&handle!=0?new DialogOwner(handle):null;
    }

    static bool ExportCourse(Store store,IWin32Window owner) {
        using(var dialog=new SaveFileDialog {
            Title="Guardar copia de seguridad",Filter="Copia JSON|*.json",
            FileName="PracticasFP-Copia-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+".json"
        }) {
            if(dialog.ShowDialog(owner)!=DialogResult.OK)return false;
            if(String.Equals(Path.GetFullPath(dialog.FileName),Path.GetFullPath(store.FilePath),StringComparison.OrdinalIgnoreCase))
                throw new ArgumentException("Elige una ubicación distinta del archivo de datos activo.");
            store.Export(dialog.FileName);
            return true;
        }
    }

    static void VerifyCourseCopies(Store store) {
        string exported=Path.Combine(store.Folder,"exportada-prueba.json");
        string legacyPath=Path.Combine(store.Folder,"anterior-prueba.json");
        store.Export(exported);
        var recovered=ReadCourseCopy(exported);
        if(J.Json(recovered)!=J.Json(store.Db))throw new InvalidOperationException("La exportación alteró el curso.");
        var previous=Model.Empty();
        var student=Model.Student();
        student["name"]="Alumna del formato anterior";
        J.EditArray(previous,"students").Add(student);
        J.Atomic(legacyPath,J.Json(previous));
        var legacy=ReadCourseCopy(legacyPath);
        if(!Model.Items(legacy,"students").All(Model.HasTwoPeriods))
            throw new InvalidOperationException("No se convirtieron las fichas anteriores.");
        store.Restore(legacy);
        if(J.S(Model.Items(store.Db,"students").Single(),"name")!="Alumna del formato anterior"||
            !Directory.GetFiles(store.Backups,"*.json").Any())
            throw new InvalidOperationException("Faltan la ficha restaurada o la copia previa.");
        store.Undo(false);
        if(J.Json(new Store(store.Folder).Db)!=J.Json(recovered))
            throw new InvalidOperationException("Deshacer no recuperó el curso anterior desde disco.");
    }

    static void VerifyStudentImport(Store store) {
        var sheet=Importer.Csv("Nombre;DNI;NUSS\r\nAlumna CSV;00000000T;001234567890\r\n");
        string error;
        var accepted=Importer.Student(sheet,1,sheet.Rows[0].Select(Importer.Guess).ToArray(),out error);
        if(error!=null)throw new InvalidOperationException(error);
        MainForm.SaveImportedStudents(store,new List<object>{accepted});
        var actual=Model.Items(new Store(store.Folder).Db,"students").Last();
        if(J.S(actual,"name")!="Alumna CSV"||J.S(actual,"nuss")!="001234567890"||!Model.HasTwoPeriods(actual))
            throw new InvalidOperationException("La ficha importada no conservó su identificación o sus periodos.");
        store.Undo(false);
        if(Model.Items(store.Db,"students").Any(s=>J.S(s,"id")==J.S(actual,"id")))
            throw new InvalidOperationException("No se deshizo la importación.");
    }

    static void Serve(Store store,bool isolatedPilot) {
        Console.InputEncoding=new System.Text.UTF8Encoding(false);
        Console.OutputEncoding=new System.Text.UTF8Encoding(false);
        Console.WriteLine(J.Json(DirectoryData(store)));
        Dictionary<string,object> pendingRestore=null;
        string input;
        while((input=Console.ReadLine())!=null) {
            try {
                var request=J.Parse(input);
                string action=J.S(request,"action");
                if(action=="importStudents"||action=="verifyImport") {
                    if(action=="verifyImport") {
                        if(!isolatedPilot)throw new InvalidOperationException("Solo disponible en la prueba aislada.");
                        VerifyStudentImport(store);
                    }
                    object data=action=="verifyImport"?(object)true:MainForm.ImportStudents(store,GetDialogOwner(request))?DirectoryData(store):null;
                    Console.WriteLine(J.Json(J.Obj("data",data)));
                    continue;
                }
                if(action=="backupInfo"||action=="saveCourse"||action=="exportCourse"||action=="selectRestore"||
                    action=="applyRestore"||action=="cancelRestore"||action=="verifyCopies") {
                    object data=null;
                    if(action=="backupInfo")data=BackupPreview(store.Db);
                    if(action=="saveCourse") {
                        var fields=J.Get(request,"fields");
                        store.Change(()=>{
                            store.Db["institute"]=J.S(fields,"institute").Trim();
                            store.Db["course"]=J.S(fields,"course").Trim();
                        });
                        data=BackupPreview(store.Db);
                    }
                    if(action=="exportCourse")data=ExportCourse(store,GetDialogOwner(request));
                    if(action=="selectRestore") {
                        pendingRestore=null;
                        using(var dialog=new OpenFileDialog {
                            Title="Selecciona una copia de Windows o Mac",Filter="Copia JSON|*.json",InitialDirectory=store.Backups
                        }) if(dialog.ShowDialog(GetDialogOwner(request))==DialogResult.OK) {
                            pendingRestore=ReadCourseCopy(dialog.FileName);
                            data=BackupPreview(pendingRestore);
                        }
                    }
                    if(action=="applyRestore") {
                        if(pendingRestore==null)throw new InvalidOperationException("Selecciona una copia antes de restaurar.");
                        store.Restore(pendingRestore);
                        pendingRestore=null;
                        data=DirectoryData(store);
                    }
                    if(action=="cancelRestore")pendingRestore=null;
                    if(action=="verifyCopies") {
                        if(!isolatedPilot)throw new InvalidOperationException("Solo disponible en la prueba aislada.");
                        VerifyCourseCopies(store);
                        data=true;
                    }
                    Console.WriteLine(J.Json(J.Obj("data",data)));
                    continue;
                }
                if(action=="report"||action=="saveReport"||action=="printReport") {
                    var fields=J.Get(request,"fields");
                    string kind=J.S(request,"kind"),id=J.S(fields,"id");
                    if(id!=""&&kind!="students"&&kind!="companies")throw new ArgumentException("Tipo de informe desconocido.");
                    var reportRecord=id==""?null:Model.Find(store.Db,kind,id);
                    if(id!=""&&reportRecord==null)throw new ArgumentException("No se encontró la ficha del informe.");
                    string report=Model.Report(store.Db,reportRecord,kind);
                    object data=action=="report"?(object)report:
                        action=="saveReport"?MainForm.SaveReportText(report,GetDialogOwner(request)):
                            MainForm.PrintReport(report,GetDialogOwner(request));
                    Console.WriteLine(J.Json(J.Obj("data",data)));
                    continue;
                }
                if(action=="calendar"||action=="saveCalendar"||action=="saveExclusion"||action=="deleteExclusion") {
                    if(action!="calendar")ChangeCalendar(store,action,J.Get(request,"fields"));
                    Console.WriteLine(J.Json(J.Obj("data",CalendarData(store.Db))));
                    continue;
                }
                if(action=="deleteRecord") {
                    string kind=J.S(request,"kind");
                    if(!new[]{"students","companies","tutors","exclusions"}.Contains(kind))
                        throw new ArgumentException("Tipo de ficha desconocido.");
                    string id=J.S(J.Get(request,"fields"),"id");
                    var deleted=Model.Find(store.Db,kind,id);
                    if(deleted==null)throw new ArgumentException("Ficha desconocida.");
                    WorkspaceRules.CheckDelete(store.Db,kind,id);
                    store.Change(()=>J.EditArray(store.Db,kind).Remove(deleted));
                    Console.WriteLine(J.Json(J.Obj("data",DirectoryData(store))));
                    continue;
                }
                if(action=="companyDetails") {
                    var company=Model.Find(store.Db,"companies",J.S(J.Get(request,"fields"),"id"));
                    if(company==null)throw new ArgumentException("Empresa desconocida.");
                    Console.WriteLine(J.Json(J.Obj("data",CompanyDetails(store,company))));
                    continue;
                }
                if(action=="tutorLinks") {
                    var tutor=Model.Find(store.Db,"tutors",J.S(J.Get(request,"fields"),"id"));
                    if(tutor==null)throw new ArgumentException("Tutor desconocido.");
                    Console.WriteLine(J.Json(J.Obj("data",TutorLinks(store,tutor))));
                    continue;
                }
                if(action=="directory"||action=="saveDirectory") {
                    Console.WriteLine(J.Json(J.Obj("data",action=="directory"?DirectoryData(store):SaveDirectory(store,request))));
                    continue;
                }
                if(action=="create"||action=="undo"||action=="redo"||action=="reopen") {
                    if(action=="create")store.Change(()=>{
                        var student=Model.Student();
                        Model.ConvertPeriods(student,store.Db);
                        J.EditArray(store.Db,"students").Add(student);
                    });
                    else if(action=="reopen") {
                        var reopened=new Store(store.Folder);
                        if(reopened.Blocked||!File.Exists(reopened.FilePath))
                            throw new InvalidOperationException("No se pudo reabrir el almacén experimental.");
                        store=reopened;
                    }
                    else store.Undo(action=="redo");
                    Console.WriteLine(J.Json(J.Obj("data",DirectoryData(store))));
                    continue;
                }
                var current=Model.Items(store.Db,"students").ToArray();
                int index=(int)J.N(request,"index",-1);
                if(index<0||index>=current.Length)throw new ArgumentException("Ficha desconocida.");
                var record=current[index];
                if(action=="save")SaveFicha(store,record,J.Get(request,"fields"));
                Console.WriteLine(J.Json(J.Obj("data",ReadFicha(store,record))));
            }
            catch(Exception ex) {
                Console.WriteLine(J.Json(J.Obj("error",ex.Message)));
            }
        }
    }

    [STAThread]
    static void Main(string[] args) {
        bool motor=args.Length>0&&args[0]=="--motor";
        bool pilot=motor&&args.Length>=2&&args[1]=="--piloto";
        Guid session=Guid.Empty;
        int sessionArg=pilot?2:1;
        bool shared=motor&&args.Length>sessionArg&&Guid.TryParseExact(args[sessionArg],"N",out session);
        string folder=pilot&&!shared?Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"PracticasFP-Tauri-Piloto"):
            Path.Combine(Path.GetTempPath(),"PracticasFP-Rendimiento-"+(shared?session:Guid.NewGuid()).ToString("N"));
        FileStream pilotLock=null;
        try {
            if(pilot) {
                Directory.CreateDirectory(folder);
                pilotLock=new FileStream(Path.Combine(folder,"sesion.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None);
            }
            var store=new Store(folder);
            if(store.Blocked)throw new InvalidOperationException(store.Error);
            string source=Environment.GetEnvironmentVariable("PRACTICAS_FP_BENCHMARK_COPY");
            bool fromCopy=!string.IsNullOrWhiteSpace(source);
            if(!File.Exists(store.FilePath)) {
                store.Db=pilot?Model.Empty():fromCopy?Model.Decode(File.ReadAllText(source)):Fixture();
                if(pilot)store.Db["version"]=5;
                if(fromCopy) {
                    var records=Model.Items(store.Db,"students").ToList();
                    foreach(var record in records)Model.ConvertPeriods(record,store.Db);
                    if(records.Count<2)throw new ArgumentException("La copia requiere al menos dos fichas.");
                    store.Db["version"]=5;
                    store.Db=Model.Decode(J.Json(store.Db));
                }
            }
            if(motor) {Serve(store,pilot&&shared);return;}
            if(args.Length==1&&args[0]=="--sqlite") {
                RendimientoSqlite.Run(folder,store.Db);
                return;
            }
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            var students=Model.Items(store.Db,"students").ToArray();
            Console.WriteLine("Windows / "+students.Length+" fichas / 30 mediciones por operación");
            using(var form=new MainForm(store)) {
                form.Show();
                Application.DoEvents();
                var cards=(FlowLayoutPanel)typeof(MainForm).GetField("tutorCards",BindingFlags.Instance|BindingFlags.NonPublic).GetValue(form);
                var first=(Button)cards.Controls[0];
                var second=(Button)cards.Controls[1];
                var selected=typeof(MainForm).GetField("selected",BindingFlags.Instance|BindingFlags.NonPublic);
                Measure("Cambiar de ficha (gestión y repintado)",i=> {
                    var card=i%2==0?second:first;
                    card.PerformClick();
                    form.Update();
                    Application.DoEvents();
                    if((string)selected.GetValue(form)!=(string)card.Tag)
                        throw new InvalidOperationException("La ficha mostrada no coincide con la solicitud.");
                });
                var header=Controls(form).OfType<Button>().First(b=>b.AccessibleName=="Anexo I · asignación de tutor");
                Measure("Desplegar y plegar el anexo (dos acciones)",i=> {
                    header.PerformClick();
                    form.Update();
                    Application.DoEvents();
                    header.PerformClick();
                    form.Update();
                    Application.DoEvents();
                });
            }
            if(fromCopy)return;
            Measure("Guardar una edición (Store.Change)",i=>store.Change(()=>J.D(students[0])["phone"]="600000"+i.ToString("D3")));
            Measure("Abrir el archivo completo desde disco",i=> {
                if(new Store(folder).Blocked)throw new InvalidOperationException("No se pudo leer la copia de prueba.");
            });
        }
        finally {
            if(pilotLock!=null)pilotLock.Dispose();
            if(!pilot&&!shared&&Directory.Exists(folder))Directory.Delete(folder,true);
        }
    }
}
