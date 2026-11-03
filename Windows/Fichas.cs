// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Drawing;
using System.Drawing.Printing;
using System.Windows.Forms;
using System.Collections.Generic;
using System.Globalization;
using System.Diagnostics;
namespace PracticasFP {
    public partial class MainForm {
        void Student(Dictionary<string,object> o) {
            Title("Datos personales");
            foreach(var pair in new[] {
                new[] {
                    "name","Nombre y apellidos"
                },new[] {
                    "group","Grupo"
                },new[] {
                    "dni","DNI / NIE"
                },new[] {
                    "nuss","NUSS"
                },new[] {
                    "email","Email"
                },new[] {
                    "phone","Teléfono"
                }
            })TextField(o,pair[0],pair[1]);
            var warnings=new List<string>();
            if(J.S(o,"name").Trim()=="")warnings.Add("Completa el nombre.");
            if(Model.Items(store.Db,"students").Any(x=>J.S(x,"id")!=J.S(o,"id")&&Importer.Identity(x).Overlaps(Importer.Identity(o))))warnings.Add("Posible ficha duplicada: revisa nombre, DNI, NUSS y correo.");
            if(J.S(o,"nuss")!=""&&J.S(o,"nuss").Count(char.IsDigit)!=12)warnings.Add("Revisa el NUSS: se esperan 12 cifras.");
            if(J.S(o,"email")!=""&&(!J.S(o,"email").Contains("@")||J.S(o,"email").Any(char.IsWhiteSpace)))warnings.Add("Revisa el correo.");
            if(J.S(o,"dni")!=""&&J.S(o,"dni").Replace(" ","").Replace("-","").Length!=9)warnings.Add("Revisa el DNI / NIE.");
            foreach(var warning in warnings)Note(warning);
            Title("Preferencias");
            TextField(o,"preferredType","Tipo de empresa");
            TextField(o,"preferredZone","Zona");
            TextField(o,"preferences","Detalle de preferencias",true);
            TextField(o,"notes","Observaciones",true);
            Title("Horario y previsión");
            Check(o,"hasStart","Fecha de inicio establecida");
            DateField(o,"start","Inicio");
            Number(o,"hours","Horas diarias iniciales",0,24,2);
            Number(o,"targetHours","Horas objetivo",0,10000,2);
            Check(o,"manualEnd","Ajustar fecha final manualmente");
            if(J.B(o,"manualEnd"))DateField(o,"end","Fin manual");
            var calc=store.Queries.Calculate(o);
            Note(calc.Error??(calc.End.HasValue?"Fin calculado: "+J.Text(calc.End.Value)+" · Última jornada: "+calc.Last.ToString("0.##")+" h\nPrevisión hasta ayer: "+calc.Elapsed.ToString("0.##")+" h / "+J.N(o,"targetHours",500)+(J.B(o,"manualEnd")?"\nHoras hasta el fin manual: "+calc.Manual.ToString("0.##"):""):"Indica el inicio para calcular la previsión."));
            if(calc.End.HasValue&&(J.Date(o,"start")<J.Date(store.Db,"calendarFrom")||calc.End.Value>J.Date(store.Db,"calendarTo")))Note("La previsión sale del calendario revisado.");
            if(!J.B(store.Db,"instituteDaysConfirmed"))Note("Previsión provisional: faltan los días del instituto.");
            Select(o,"assignment","Asignación",new List<Choice> {
                new Choice("Pendiente","Pendiente"),new Choice("Provisional","Provisional"),new Choice("Definitiva","Definitiva")
            });
            Title("Práctica inicial");
            Assignment(o,o);
            Paperwork(o,true);
            Documents(o,"annexI");
            Documents(o,"annexII");
            foreach(var shift in Model.Items(o,"shifts").OrderBy(x=>J.Date(x,"from")).ToList()) {
                Title(J.S(shift,"companyID")==""?"Cambio de jornada":"Práctica posterior");
                DateField(shift,"from","Desde");
                Number(shift,"hours","Horas diarias (completar)",0,24,2,null,true);
                Assignment(o,shift);
                if(J.S(shift,"companyID")!="") {
                    Paperwork(shift,false);
                    Documents(shift,"annexI");
                    Documents(shift,"annexII");
                }
                var local=shift;
                AddButton(fields,"Eliminar este periodo…",()=> {
                    if(Confirm("¿Eliminar este periodo y sus documentos?")) {
                        store.Change(()=>J.EditArray(o,"shifts").Remove(local));
                        Render();
                    }
                });
            }
            Title("Añadir periodos");
            AddButton(fields,"Añadir periodo / cambio de jornada",()=> {
                store.Change(()=>J.EditArray(o,"shifts").Add(J.Obj("id",J.Id(),"from",J.Stamp(J.Today))));
                RenderEditor();
            });
        }
        void Assignment(Dictionary<string,object> student,Dictionary<string,object> owner) {
            Select(owner,"companyID","Empresa (sin asignar = continúa la anterior en cambios)",Choices("companies"),id=>Model.Assign(store.Db,student,owner,id));
            string company=J.S(owner,"companyID");
            if(company!="") {
                Link("companies",company,"Abrir empresa");
                Select(owner,"tutorID","Tutor de empresa",Choices("tutors",company));
                Link("tutors",J.S(owner,"tutorID"),"Abrir tutor");
            }
        }
        void Paperwork(Dictionary<string,object> o,bool certificate) {
            var a=J.Get(o,"paperwork")==null?Model.Steps():J.A(o,"paperwork");
            foreach(int i in certificate?new[] {
                0,5,6
            }
            :new[] {
                5,6
            }) {
                var step=J.D(a[i]);
                Check(step,"done",J.S(step,"title"),value=> {
                    if(J.Get(o,"paperwork")==null)o["paperwork"]=a;
                    step["done"]=value;
                    if(value)step["date"]=J.Stamp(J.Today);
                });
                if(J.B(step,"done"))DateField(step,"date","Fecha");
            }
        }
        void Documents(Dictionary<string,object> o,string kind) {
            Title(kind=="annexI"?"Anexo I · asignación de tutor":kind=="annexII"?"Anexo II · calificación final":"Concierto de colaboración");
            DocumentFields(o,kind,fields);
        }
        void DocumentFields(Dictionary<string,object> o,string kind,FlowLayoutPanel group) {
            var flow=Model.Flow(o,kind);
            var previous=fields;
            var grid=new FlowLayoutPanel {
                Tag="document-grid",FlowDirection=FlowDirection.LeftToRight,WrapContents=true,
                AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,Width=FieldWidth,Margin=new Padding(0)
            };
            group.Controls.Add(grid);
            int number=0;
            foreach(var m in Model.Items(flow,"milestones")) {
                string stage=J.S(m,"id");number++;
                var cell=new FlowLayoutPanel {
                    Tag=kind+"|"+stage,FlowDirection=FlowDirection.TopDown,WrapContents=false,
                    AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,Width=145,Padding=new Padding(4),Margin=new Padding(2)
                };
                grid.Controls.Add(cell);fields=cell;
                Check(m,"completed",number+". "+Model.StageTitle(stage),value=> {
                    DocumentChanged(o,kind,stage,value,value?(object)J.Stamp(J.Today):null);
                },()=>RefreshDocumentGroup(o,kind,group));
                if(J.B(m,"completed")) {
                    fields.Controls.Add(new Label {Text="Fecha (opcional)",AutoSize=true});
                    var date=new DateTimePicker {
                        Tag=FieldTag(m,"date"),Format=DateTimePickerFormat.Short,Width=130,ShowCheckBox=true,
                        Value=J.Date(m,"date"),Checked=J.Get(m,"date")!=null
                    };
                    date.CloseUp+=(sender,e)=>SaveDate(m,"date",date,true,value=>DocumentChanged(o,kind,stage,true,value));
                    date.Leave+=(sender,e)=>SaveDate(m,"date",date,true,value=>DocumentChanged(o,kind,stage,true,value));
                    fields.Controls.Add(date);
                }
                else fields.Controls.Add(new Label {Text="Pendiente",AutoSize=true,ForeColor=Color.DimGray});
            }
            fields=previous;
        }
        static string ResponseTitle(string v) {
            return v=="accepted"?"Admite alumnas":v=="rejected"?"Rechaza alumnas":v=="waiting"?"Esperando respuesta":"Contacto sin registrar";
        }
        void Company(Dictionary<string,object> o) {
            Title("Datos de la empresa");
            foreach(var p in new[] {
                new[] {
                    "name","Empresa"
                },new[] {
                    "cif","CIF"
                },new[] {
                    "address","Dirección"
                },new[] {
                    "contact","Persona de contacto"
                },new[] {
                    "phone","Teléfono"
                },new[] {
                    "email","Email"
                }
            })TextField(o,p[0],p[1]);
            TextField(o,"notes","Observaciones",true);
            Title("Contacto y plazas");
            Select(o,"response","Estado",new List<Choice> {
                new Choice("uncontacted","Contacto sin registrar"),new Choice("waiting","Esperando respuesta"),new Choice("accepted","Admite alumnas"),new Choice("rejected","Rechaza alumnas")
            });
            DateField(o,"contactedOn","Fecha de contacto",true);
            DateField(o,"respondedOn","Fecha de respuesta",true);
            int occupied=store.Queries.Occupied(J.S(o,"id"));
            Note(occupied+" plazas ocupadas · "+(J.Get(o,"capacity")==null?"Cupo sin indicar":Math.Max(0,J.N(o,"capacity")-occupied)+" libres"));
            Number(o,"capacity","Plazas concedidas",occupied,100000,0,value=> {
                o["capacity"]=(int)value;
                if(value>0)o["response"]="accepted";
            },true);
            Documents(o,"agreement");
            Title("Alumnas vinculadas");
            foreach(var s in Model.Items(store.Db,"students").Where(x=>Model.Companies(x).Contains(J.S(o,"id"))))Link("students",J.S(s,"id"),J.S(s,"name")+" · "+J.S(s,"assignment"));
            Title("Tutores");
            foreach(var t in Model.Items(store.Db,"tutors").Where(x=>J.S(x,"companyID")==J.S(o,"id")))Link("tutors",J.S(t,"id"),J.S(t,"name"));
            Title("Seguimiento mensual");
            foreach(var item in store.Queries.Contacts(o)) {
                var contact=item;
                Title(J.Date(contact,"plannedDate").ToString("MMMM yyyy",CultureInfo.GetCultureInfo("es-ES"))+(J.B(contact,"historical")?" · histórico":""));
                Note("Previsto: "+J.Text(J.Date(contact,"plannedDate"))+" · "+string.Join(", ",J.A(contact,"studentNames").Select(Convert.ToString)));
                bool saved=Model.Items(o,"monthlyContacts").Any(x=>J.S(x,"id")==J.S(contact,"id"));
                if(!saved) {
                    AddButton(fields,"Registrar este contacto",()=> {
                        store.Change(()=> {
                            var clone=J.Clone(contact);
                            clone.Remove("historical");
                            J.EditArray(o,"monthlyContacts").Add(clone);
                        });
                        RenderEditor();
                    });
                }
                else {
                    var record=Model.Items(o,"monthlyContacts").First(x=>J.S(x,"id")==J.S(contact,"id"));
                    Check(record,"completed","Contacto realizado",value=> {
                        record["completed"]=value;
                        if(value)record["completedOn"]=J.Stamp(J.Today);
                    });
                    DateField(record,"plannedDate","Fecha prevista guardada");
                    if(J.B(record,"completed"))DateField(record,"completedOn","Realizado el");
                    TextField(record,"notes","Observaciones del contacto",true);
                }
            }
        }
        void Tutor(Dictionary<string,object> o) {
            Title("Datos del tutor");
            TextField(o,"name","Nombre");
            string previous=J.S(o,"companyID");
            Select(o,"companyID","Empresa",Choices("companies"),id=> {
                if(previous!=id&&Model.Items(store.Db,"students").Any(s=>J.S(s,"tutorID")==J.S(o,"id")||Model.Items(s,"shifts").Any(p=>J.S(p,"tutorID")==J.S(o,"id"))))throw new Exception("Este tutor está asignado a prácticas. Retira esas asignaciones antes de cambiar su empresa.");
                if(id=="")o.Remove("companyID");
                else o["companyID"]=id;
            });
            Link("companies",J.S(o,"companyID"),"Abrir empresa");
            TextField(o,"phone","Teléfono");
            TextField(o,"email","Email");
            TextField(o,"notes","Observaciones",true);
            Title("Alumnas tutorizadas");
            var students=WorkspaceRules.TutorStudents(store.Db,J.S(o,"id"));
            if(students.Count==0)Note("Sin alumnas asignadas");
            foreach(var student in students)Link("students",J.S(student,"id"),J.S(student,"name"));
        }
        void CalendarSettings() {
            Title("Calendario del curso");
            DateField(store.Db,"calendarFrom","Revisado desde");
            DateField(store.Db,"calendarTo","Revisado hasta");
            Check(store.Db,"instituteDaysConfirmed","Días de libre disposición del instituto confirmados");
            Note("Se excluyen sábados, domingos e intervalos completos. Añade las fechas del instituto con Añadir.");
        }
        void Settings() {
            Title("Datos y copias · Windows");
            Note("Versión 1.8.4-windows.3 · Edición de pruebas\nFormato de datos 4 · Compatible con copias de Mac 1 a 4.");
            if(store.Blocked)Note(store.Error);
            else {
                TextField(store.Db,"institute","Centro");
                TextField(store.Db,"course","Curso");
            }
            Note("Datos: "+store.FilePath);
            AddButton(fields,"Abrir carpeta de datos",()=>Process.Start("explorer.exe",store.Folder));
            AddButton(fields,"Mostrar copias automáticas",()=>Process.Start("explorer.exe",store.Backups));
            AddButton(fields,"Guardar copia de seguridad…",Backup);
            AddButton(fields,"Restaurar copia de Windows o Mac…",Restore);
            Note("Los datos se guardan en este equipo. Para trasladarlos, guarda una copia y restáurala en el otro equipo. No hay sincronización automática.");
        }
        bool Confirm(string text) {
            return MessageBox.Show(this,text,"Prácticas FP",MessageBoxButtons.YesNo,MessageBoxIcon.Question,MessageBoxDefaultButton.Button2)==DialogResult.Yes;
        }
        void Backup() {
            using(var d=new SaveFileDialog {
                Title="Guardar copia de seguridad",Filter="Copia JSON|*.json",FileName="PracticasFP-Copia-"+DateTime.Now.ToString("yyyyMMdd-HHmmss")+".json"
            })if(d.ShowDialog(this)==DialogResult.OK) {
                if(Path.GetFullPath(d.FileName)==Path.GetFullPath(store.FilePath))throw new Exception("Elige una ubicación distinta del archivo de datos activo.");
                store.Export(d.FileName);
                MessageBox.Show(this,"Copia guardada y verificada:\n"+d.FileName,"Prácticas FP");
            }
        }
        void Restore() {
            using(var d=new OpenFileDialog {
                Title="Selecciona una copia de Windows o Mac",Filter="Datos JSON|*.json",InitialDirectory=store.Backups
            })if(d.ShowDialog(this)==DialogResult.OK) {
                var recovered=Model.Decode(File.ReadAllText(d.FileName));
                string detail="Copia: "+d.FileName+"\nFecha: "+File.GetLastWriteTime(d.FileName)+"\nCentro: "+J.S(recovered,"institute")+"\nCurso: "+J.S(recovered,"course")+"\nAlumnas: "+J.A(recovered,"students").Count+" (actuales: "+J.A(store.Db,"students").Count+")\nEmpresas: "+J.A(recovered,"companies").Count+" (actuales: "+J.A(store.Db,"companies").Count+")\nTutores: "+J.A(recovered,"tutors").Count+"\nCursos archivados: "+J.A(recovered,"archivedCourses").Count+"\n\n¿Sustituir los datos actuales? Se conservará una copia previa.";
                if(Confirm(detail)) {
                    store.Restore(recovered);
                    selected="";
                    Render();
                }
            }
        }
        void History() {
            Title("Historial de cursos");
            AddButton(fields,"Archivar curso actual e iniciar otro…",()=> {
                string title=Prompt("Curso nuevo (por ejemplo 2027–2028)","");
                if(title!=null&&Confirm("Se archivará el curso "+J.S(store.Db,"course")+". El nuevo curso conservará empresas y tutores, pero no alumnas, cupos ni calendario. ¿Continuar?")) {
                    store.Archive(title);
                    Render();
                }
            });
            foreach(var archive in Model.Items(store.Db,"archivedCourses")) {
                var a=archive;
                Title(J.S(a,"title"));
                Note("Archivado: "+J.Text(J.Date(a,"archivedOn")));
                AddButton(fields,"Consultar resumen",()=> {
                    var db=Model.Decode(Encoding.UTF8.GetString(Convert.FromBase64String(J.S(a,"snapshot"))));
                    ShowReport(Model.Report(db));
                });
                AddButton(fields,"Exportar copia del curso…",()=> {
                    using(var d=new SaveFileDialog {
                        Filter="Copia JSON|*.json",FileName="Curso-"+J.S(a,"title")+".json"
                    })if(d.ShowDialog(this)==DialogResult.OK) {
                        string json=Encoding.UTF8.GetString(Convert.FromBase64String(J.S(a,"snapshot")));
                        Model.Decode(json);
                        J.Atomic(d.FileName,json);
                    }
                });
            }
        }
        void Pending() {
            Title("Requiere actuación ahora");
            var later=new List<Action>();
            foreach(var s in Model.Items(store.Db,"students")) {
                var student=s;
                Action<string> add=text=> {
                    Note(J.S(student,"name")+" · "+text);
                    Link("students",J.S(student,"id"),"Abrir alumna");
                };
                if(J.S(s,"assignment")!="Definitiva")add("Asignación pendiente de confirmar");
                foreach(var p in store.Queries.Periods(s).Where(x=>x.Company!="")) {
                    if(p.Tutor=="")add("Tutor pendiente · "+J.Text(p.Start));
                    foreach(string kind in new[] {
                        "annexI","annexII"
                    }) {
                        var flow=Model.Flow(p.Owner,kind);
                        if(Model.Done(flow,"archived"))continue;
                        string next=Model.StageTitle(J.S(Model.Items(flow,"milestones").First(x=>!J.B(x,"completed")),"id"));
                        string text=(kind=="annexI"?"Anexo I":"Anexo II")+" · "+next+" · "+J.Text(p.Start);
                        bool finished=J.A(p.Owner,"paperwork").Count>6&&J.B(J.A(p.Owner,"paperwork")[6],"done")||J.B(s,"hasStart")&&p.End.HasValue&&p.End.Value<J.Today;
                        if(kind=="annexII"&&!finished&&!Model.Done(flow,"sentTutor")) {
                            string captured=text;
                            later.Add(()=>add(captured));
                        }
                        else add(text);
                    }
                }
            }
            foreach(var c in Model.Items(store.Db,"companies")) {
                if((J.S(c,"response")=="accepted"||store.Queries.Occupied(J.S(c,"id"))>0)&&!Model.Done(Model.Flow(c,"agreement"),"uploaded")) {
                    Note(J.S(c,"name")+" · Concierto pendiente");
                    Link("companies",J.S(c,"id"),"Abrir empresa");
                }
                foreach(var contact in store.Queries.Contacts(c).Where(x=>!J.B(x,"historical")&&!J.B(x,"completed")&&J.Date(x,"plannedDate")<J.Today)) {
                    Note(J.S(c,"name")+" · Contacto vencido "+J.Text(J.Date(contact,"plannedDate")));
                    Link("companies",J.S(c,"id"),"Abrir empresa");
                }
            }
            Title("Documentación de cierre · para más adelante");
            foreach(var action in later)action();
        }
        void Add() {
            if(!new[] {
                "students","companies","tutors","exclusions"
            }
            .Contains(section))return;
            var o=section=="students"?Model.Student():section=="companies"?Model.Company():section=="tutors"?Model.Tutor():Model.Exclusion("Nuevo día",J.Today,J.Today,"Libre disposición");
            store.Change(()=>J.EditArray(store.Db,section).Add(o));
            selected=J.S(o,"id");
            Render();
        }
        void Delete() {
            var o=Current();
            if(o==null)return;
            string id=J.S(o,"id");
            if(section=="companies"&&(Model.Occupied(store.Db,id)>0||Model.Items(store.Db,"tutors").Any(x=>J.S(x,"companyID")==id)))throw new Exception("Retira primero las alumnas y tutores vinculados a esta empresa.");
            if(section=="tutors"&&Model.Items(store.Db,"students").Any(s=>J.S(s,"tutorID")==id||Model.Items(s,"shifts").Any(p=>J.S(p,"tutorID")==id)))throw new Exception("Retira primero el tutor de las prácticas vinculadas.");
            if(Confirm("¿Eliminar esta ficha? Puedes recuperarla con Deshacer durante esta sesión.")) {
                store.Change(()=>J.EditArray(store.Db,section).Remove(o));
                selected="";
                Render();
            }
        }
        string Prompt(string title,string initial) {
            using(var f=new Form {
                Text=title,Width=500,Height=170,StartPosition=FormStartPosition.CenterParent,Font=Font
            }) {
                var t=new TextBox {
                    Text=initial,Left=15,Top=20,Width=450
                };
                var b=new Button {
                    Text="Continuar",DialogResult=DialogResult.OK,Left=340,Top=65,Width=125
                };
                f.Controls.Add(t);
                f.Controls.Add(b);
                f.AcceptButton=b;
                return f.ShowDialog(this)==DialogResult.OK?t.Text:null;
            }
        }
        void Import() {
            using(var d=new OpenFileDialog {
                Filter="CSV o Excel|*.csv;*.tsv;*.xlsx"
            })if(d.ShowDialog(this)==DialogResult.OK) {
                var sheets=Importer.Read(d.FileName);
                using(var dialog=new ImportForm(sheets,store.Db)) {
                    if(dialog.ShowDialog(this)==DialogResult.OK&&dialog.Accepted.Count>0) {
                        store.Backup();
                        store.Change(()=>J.EditArray(store.Db,"students").AddRange(dialog.Accepted));
                        Navigate("students");
                    }
                }
            }
        }
    }
}
