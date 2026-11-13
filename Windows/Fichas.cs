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
            Title("Datos personales",()=> {
                TextField(o,"name","Nombre y apellidos");
                TextField(o,"group","Grupo");
                FieldPair("identification",()=>TextField(o,"dni","DNI / NIE"),()=>TextField(o,"nuss","NUSS"));
                PhoneAndEmail(o);
                var warnings=new List<string>();
                if(J.S(o,"name").Trim()=="")warnings.Add("Completa el nombre.");
                if(Model.Items(store.Db,"students").Any(x=>J.S(x,"id")!=J.S(o,"id")&&Importer.Identity(x).Overlaps(Importer.Identity(o))))warnings.Add("Posible ficha duplicada: revisa nombre, DNI, NUSS y correo.");
                if(J.S(o,"nuss")!=""&&J.S(o,"nuss").Count(char.IsDigit)!=12)warnings.Add("Revisa el NUSS: se esperan 12 cifras.");
                if(J.S(o,"email")!=""&&(!J.S(o,"email").Contains("@")||J.S(o,"email").Any(char.IsWhiteSpace)))warnings.Add("Revisa el correo.");
                if(J.S(o,"dni")!=""&&J.S(o,"dni").Replace(" ","").Replace("-","").Length!=9)warnings.Add("Revisa el DNI / NIE.");
                foreach(var warning in warnings)Note(warning);
            });
            Title("Preferencias",()=> {
                TextField(o,"preferredType","Tipo de empresa");
                TextField(o,"preferredZone","Zona");
                TextField(o,"preferences","Detalle de preferencias",true);
                TextField(o,"notes","Observaciones",true);
            });
            Title("Horario y previsión",()=> {
                Check(o,"hasStart","Fecha de inicio establecida");
                DateField(o,"start","Inicio");
                FieldPair("hours",()=>Number(o,"hours","Horas diarias iniciales",0,24,2),
                    ()=>Number(o,"targetHours","Horas objetivo",0,10000,2));
                Check(o,"manualEnd","Ajustar fecha final manualmente");
                if(J.B(o,"manualEnd"))DateField(o,"end","Fin manual");
                var calc=store.Queries.Calculate(o);
                Note(calc.Error??(calc.End.HasValue?"Fin calculado: "+J.Text(calc.End.Value)+" · Última jornada: "+calc.Last.ToString("0.##")+" h\nPrevisión hasta ayer: "+calc.Elapsed.ToString("0.##")+" h / "+J.N(o,"targetHours",500)+(J.B(o,"manualEnd")?"\nHoras hasta el fin manual: "+calc.Manual.ToString("0.##"):""):"Indica el inicio para calcular la previsión."));
                if(calc.End.HasValue&&(J.Date(o,"start")<J.Date(store.Db,"calendarFrom")||calc.End.Value>J.Date(store.Db,"calendarTo")))Note("La previsión sale del calendario revisado.");
                if(!J.B(store.Db,"instituteDaysConfirmed"))Note("Previsión provisional: faltan los días del instituto.");
                Select(o,"assignment","Asignación",new List<Choice> {
                    new Choice("Pendiente","Pendiente"),new Choice("Provisional","Provisional"),new Choice("Definitiva","Definitiva")
                });
            });
            Title("Práctica inicial",()=> {
                Assignment(o,o);
                Paperwork(o,true);
            });
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
                if(i!=0&&J.B(step,"done"))DateField(step,"date","Fecha");
            }
        }
        void Documents(Dictionary<string,object> o,string kind) {
            Title(kind=="annexI"?"Anexo I · asignación de tutor":kind=="annexII"?"Anexo II · calificación final":"Concierto de colaboración",
                ()=>DocumentFields(o,kind,fields));
        }
        void DocumentFields(Dictionary<string,object> o,string kind,FlowLayoutPanel group) {
            var flow=Model.Flow(o,kind);
            var previous=fields;
            var grid=new FlowLayoutPanel {Tag="document-columns", AutoSize=true, WrapContents=true, Margin=new Padding(0)};
            group.Controls.Add(grid);
            fields=grid;
            foreach(var milestone in Model.Items(flow,"milestones")) {
                string stage=J.S(milestone,"id");
                var check=Check(milestone,"completed",Model.StageTitle(stage),value=> {
                    DocumentChanged(o,kind,stage,value,J.Get(milestone,"date"));
                },()=>RefreshDocumentGroup(o,kind,group),documentStep:true);
                check.Tag=FieldTag(o,kind+"|"+stage);
            }
            fields=previous;
        }
        static string ResponseTitle(string v) {
            return v=="accepted"?"Admite alumnas":v=="rejected"?"Rechaza alumnas":v=="waiting"?"Esperando respuesta":"Contacto sin registrar";
        }
        void Company(Dictionary<string,object> o) {
            Title("Datos de la empresa",()=> {
                FieldPair("company",()=>TextField(o,"name","Empresa"),()=>TextField(o,"cif","CIF"));
                TextField(o,"address","Dirección");
                TextField(o,"contact","Persona de contacto");
                PhoneAndEmail(o);
                TextField(o,"notes","Observaciones",true);
            });
            Title("Contacto y plazas",()=> {
                var columns=new FlowLayoutPanel {Tag="columns", AutoSize=true, WrapContents=true};
                fields.Controls.Add(columns);
                fields=CompanyColumn(columns,"Contacto");
                Select(o,"response","Estado",new List<Choice> {
                    new Choice("uncontacted","Contacto sin registrar"),new Choice("waiting","Esperando respuesta"),new Choice("accepted","Admite alumnas"),new Choice("rejected","Rechaza alumnas")
                });
                DateField(o,"contactedOn","Fecha de contacto",true);
                DateField(o,"respondedOn","Fecha de respuesta",true);
                fields=CompanyColumn(columns,"Plazas");
                int occupied=store.Queries.Occupied(J.S(o,"id"));
                Note(occupied+" plazas ocupadas · "+(J.Get(o,"capacity")==null?"Cupo sin indicar":Math.Max(0,J.N(o,"capacity")-occupied)+" libres"));
                Number(o,"capacity","Plazas concedidas",occupied,100000,0,value=> {
                    o["capacity"]=(int)value;
                    if(value>0)o["response"]="accepted";
                },true);
            });
            Documents(o,"agreement");
            Title("Alumnas vinculadas",()=> {
                foreach(var s in Model.Items(store.Db,"students").Where(x=>Model.Companies(x).Contains(J.S(o,"id"))))Link("students",J.S(s,"id"),J.S(s,"name")+" · "+J.S(s,"assignment"));
            });
            Title("Tutores",()=> {
                foreach(var t in Model.Items(store.Db,"tutors").Where(x=>J.S(x,"companyID")==J.S(o,"id")))Link("tutors",J.S(t,"id"),J.S(t,"name"));
            });
            Title("Seguimiento mensual",()=> {
                var followups=fields;
                followups.Padding=new Padding(16,0,0,0);
                var contacts=store.Queries.Contacts(o);
                if(contacts.Count==0)Note("Sin seguimientos mensuales.");
                foreach(var item in contacts) {
                    var contact=item;
                    Title(J.Date(contact,"plannedDate").ToString("MMMM yyyy",CultureInfo.GetCultureInfo("es-ES"))+(J.B(contact,"historical")?" · histórico":""),()=> {
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
                    },followups);
                }
            });
        }
        void PhoneAndEmail(Dictionary<string,object> record) {
            FieldPair("contact",()=>TextField(record,"phone","Teléfono"),
                ()=>TextField(record,"email","Correo electrónico"));
        }
        void FieldPair(string key,Action first,Action second) {
            var previous=fields;
            var row=new FlowLayoutPanel {Tag="contact-columns", AutoSize=true, WrapContents=true, Margin=new Padding(0)};
            row.Name=key;
            previous.Controls.Add(row);
            try {
                fields=CompanyColumn(row);
                fields.Tag=previous.Tag+"|"+key+"|first";
                first();
                fields=CompanyColumn(row);
                fields.Tag=previous.Tag+"|"+key+"|second";
                second();
            } finally {
                fields=previous;
            }
        }
        FlowLayoutPanel CompanyColumn(FlowLayoutPanel columns,string title=null) {
            var column=new FlowLayoutPanel {
                FlowDirection=FlowDirection.TopDown, WrapContents=false, AutoSize=true,
                Margin=new Padding(0,0,8,0)
            };
            if(title!=null)column.Controls.Add(new Label {Text=title,AutoSize=true});
            columns.Controls.Add(column);
            return column;
        }
        void Tutor(Dictionary<string,object> o) {
            Title("Datos del tutor",()=> {
                TextField(o,"name","Nombre");
                string previous=J.S(o,"companyID");
                Select(o,"companyID","Empresa",Choices("companies"),id=> {
                    if(previous!=id&&Model.Items(store.Db,"students").Any(s=>J.S(s,"tutorID")==J.S(o,"id")||Model.Items(s,"shifts").Any(p=>J.S(p,"tutorID")==J.S(o,"id"))))throw new Exception("Este tutor está asignado a prácticas. Retira esas asignaciones antes de cambiar su empresa.");
                    if(id=="")o.Remove("companyID");
                    else o["companyID"]=id;
                });
                Link("companies",J.S(o,"companyID"),"Abrir empresa");
                PhoneAndEmail(o);
                TextField(o,"notes","Observaciones",true);
            });
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
            Note("Versión 1.8.5 · Edición de pruebas\nFormato de datos 4 · Compatible con copias de Mac 1 a 4.");
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
            string question=section=="exclusions"?"¿Eliminar este día o intervalo?":"¿Eliminar esta ficha?";
            if(Confirm(question+" Puedes recuperarlo con Deshacer durante esta sesión.")) {
                store.Change(()=>J.EditArray(store.Db,section).Remove(o));
                selected="";
                Render();
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
