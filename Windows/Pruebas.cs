// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.IO.Compression;
using PracticasFP;
class Tests {
    static int count;
    static void Assert(bool condition,string name) {
        count++;
        if(!condition)throw new Exception("FALLO: "+name);
        Console.WriteLine("OK · "+name);
    }
    static void Reject(Action action,string name) {
        bool rejected=false;
        try {
            action();
        }
        catch {
            rejected=true;
        }
        Assert(rejected,name);
    }
    static Dictionary<string,object> Student(Dictionary<string,object> db) {
        var s=Model.Student();
        J.A(db,"students").Add(s);
        return s;
    }
    static int Main() {
        string folder=Path.Combine(Path.GetTempPath(),"PracticasFP-QA-"+Guid.NewGuid().ToString("N"));
        try {
            Directory.CreateDirectory(folder);
            foreach(var d in new[] {
                new DateTime(2026,1,1),new DateTime(2026,7,1),new DateTime(2026,10,25)
            })Assert(J.Date(J.Obj("date",J.Stamp(d)),"date")==d,"Fecha canaria "+d.ToString("yyyy-MM-dd"));
            Assert(J.Stamp(new DateTime(2001,1,1))==0,"Época Swift 2001");
            Assert(J.Date(J.Obj("d",804553200.0),"d")==new DateTime(2026,7,1),"Lectura de fecha Swift en horario de verano");
            var db=Model.Empty();
            db["exclusions"]=new List<object>();
            var s=Student(db);
            s["name"]="Alumna ficticia";
            s["hasStart"]=true;
            s["start"]=J.Stamp(new DateTime(2026,11,2));
            s["hours"]=7.0;
            s["targetHours"]=10.0;
            var calc=Model.Calculate(s,db,new DateTime(2026,11,3));
            Assert(calc.End==new DateTime(2026,11,3)&&calc.Last==3&&calc.Elapsed==7,"Objetivo, última jornada y previsión hasta ayer");
            J.A(db,"exclusions").Add(Model.Exclusion("Festivo ficticio",new DateTime(2026,11,3),new DateTime(2026,11,3),"Festivo"));
            J.A(db,"exclusions").Add(Model.Exclusion("Solapamiento",new DateTime(2026,11,3),new DateTime(2026,11,4),"Festivo"));
            Assert(Model.Calculate(s,db).End==new DateTime(2026,11,5),"Exclusiones inclusivas y solapadas");
            db["exclusions"]=new List<object>();
            s["targetHours"]=500.0;
            s["hours"]=7.0;
            s["start"]=J.Stamp(new DateTime(2026,11,6));
            Assert(Model.Calculate(s,db).End==new DateTime(2027,2,15),"Fin de semana y cálculo de 500 horas");
            s["targetHours"]=10.0;
            s["start"]=J.Stamp(new DateTime(2026,11,2));
            var shift=J.Obj("id",J.Id(),"from",J.Stamp(new DateTime(2026,11,3)),"hours",2.0);
            J.A(s,"shifts").Add(shift);
            Assert(Model.Calculate(s,db).End==new DateTime(2026,11,4),"Reducción de jornada por fecha efectiva");
            shift.Remove("hours");
            Assert(Model.Calculate(s,db).Error!=null,"Jornada nueva sin confirmar");
            shift["hours"]=2.0;
            J.A(s,"shifts").Add(J.Clone(shift));
            Assert(Model.Calculate(s,db).Error!=null,"Fechas de cambio duplicadas");
            J.A(s,"shifts").RemoveAt(1);
            var c=Model.Company();
            c["name"]="Empresa ficticia";
            c["capacity"]=1;
            c["response"]="accepted";
            J.A(db,"companies").Add(c);
            Model.Assign(db,s,s,J.S(c,"id"));
            var s2=Student(db);
            Reject(()=>Model.Assign(db,s2,s2,J.S(c,"id")),"Cupo lleno impide asignar");
            Model.Assign(db,s,shift,J.S(c,"id"));
            Assert(Model.Occupied(db,J.S(c,"id"))==1,"Una alumna ocupa una plaza por empresa");
            var flow=Model.EditFlow(s,"annexI");
            Model.Complete(flow,"receivedTutor",true,J.Stamp(J.Today));
            Assert(Model.Done(flow,"sentTutor")&&J.Get(Model.Items(flow,"milestones").First(x=>J.S(x,"id")=="sentTutor"),"date")==null,"Recepción confirma envío sin inventar fecha");
            Model.Complete(flow,"sentTutor",false,null);
            Assert(!Model.Done(flow,"receivedTutor"),"Retirar envío retira recepción");
            Model.Complete(flow,"receivedStudent",true,null);
            Assert(Model.Done(flow,"sentStudent")&&!Model.Done(flow,"generated"),"No se completan hitos anteriores");
            Model.SyncLegacy(s,"annexI");
            Assert(J.B(J.A(s,"paperwork")[4],"done"),"Compatibilidad de hitos con campos anteriores");
            db["extensionFutura"]=J.Obj("dato","conservar");
            var decoded=Model.Decode(J.Json(db));
            Assert(J.S(J.Get(decoded,"extensionFutura"),"dato")=="conservar","Se conservan campos desconocidos");
            Assert(J.S(Model.Items(decoded,"students").First(),"dni")=="","Identificadores conservados como texto");
            var legacy=Model.Empty();
            legacy["version"]=1;
            var ls=Student(legacy);
            J.D(J.A(ls,"paperwork")[2])["done"]=true;
            J.D(J.A(ls,"paperwork")[3])["done"]=true;
            var migrated=Model.Decode(J.Json(legacy));
            Assert(J.N(migrated,"version")==4&&J.B(J.A(Model.Items(migrated,"students").First(),"paperwork")[2],"done"),"Migración versión 1 y reconciliación de devolución");
            var malformed=J.Clone(db);
            malformed["version"]=6;
            Reject(()=>Model.Decode(J.Json(malformed)),"Se rechaza versión futura");
            malformed=J.Clone(db);
            J.A(malformed,"students").Add(J.Clone(J.A(malformed,"students")[0]));
            Reject(()=>Model.Decode(J.Json(malformed)),"Se rechazan identificadores duplicados");
            malformed=J.Clone(db);
            malformed["students"]="no es una lista";
            Reject(()=>Model.Decode(J.Json(malformed)),"Se rechazan listados de tipo incorrecto");
            malformed=J.Clone(db);
            J.D(J.A(malformed,"students")[0])["nuss"]=123456789012;
            Reject(()=>Model.Decode(J.Json(malformed)),"Identificadores numéricos rechazados para proteger ceros");
            malformed=J.Clone(db);
            malformed.Remove("institute");
            Reject(()=>Model.Decode(J.Json(malformed)),"Se rechazan copias incompletas");
            string data=Path.Combine(folder,"datos");
            var store=new Store(data);
            store.Change(()=>J.A(store.Db,"students").Add(Model.Student()));
            Assert(File.Exists(store.FilePath),"Guardado atómico");
            store.Undo(false);
            Assert(J.A(store.Db,"students").Count==0,"Deshacer");
            store.Undo(true);
            Assert(J.A(store.Db,"students").Count==1,"Rehacer");
            store.Export(Path.Combine(folder,"copia.json"));
            Assert(Model.Decode(File.ReadAllText(Path.Combine(folder,"copia.json")))!=null,"Copia exportada verificada");
            store.Archive("2027–2028");
            Assert(J.A(store.Db,"students").Count==0&&J.A(store.Db,"archivedCourses").Count==1&&!J.B(store.Db,"instituteDaysConfirmed"),"Archivo de curso e inicio limpio");
            var archive=Model.Items(store.Db,"archivedCourses").First();
            Assert(J.A(Model.Decode(Encoding.UTF8.GetString(Convert.FromBase64String(J.S(archive,"snapshot")))),"students").Count==1,"Instantánea base64 compatible con Swift");
            string broken=Path.Combine(folder,"roto");
            Directory.CreateDirectory(broken);
            File.WriteAllText(Path.Combine(broken,"datos.json"),"roto");
            var protectedStore=new Store(broken);
            Assert(protectedStore.Blocked,"Archivo ilegible protegido");
            Reject(()=>protectedStore.Change(()=>protectedStore.Db["course"]="otro"),"No se sobrescribe el archivo ilegible");
            Assert(File.ReadAllText(protectedStore.FilePath)=="roto","Original conservado");
            protectedStore.Restore(Model.Empty());
            Assert(!protectedStore.Blocked,"Restauración permite recuperar el almacén");
            var csv=Importer.Csv("Nombre;Apellidos;DNI;NUSS;Observaciones\r\nAna;Prueba;00123456X;001234567890;\"Texto; con separador\nsegunda línea\"\r\n");
            string issue;
            var imported=Importer.Student(csv,1,new[] {
                1,2,4,5,12
            },out issue);
            Assert(issue==null&&J.S(imported,"name")=="Ana Prueba"&&J.S(imported,"dni")=="00123456X"&&J.S(imported,"nuss")=="001234567890","CSV conserva ceros y apellidos");
            Assert(J.S(imported,"notes").Contains("\n"),"CSV con saltos de línea y separadores entre comillas");
            Assert(Importer.Identity(imported).Overlaps(Importer.Identity(J.Obj("name","Prueba Ana"))),"Duplicados con apellidos reordenados");
            Reject(()=>Importer.Csv("Nombre\n\"sin cerrar"),"CSV mal formado rechazado");
            string xlsx=Path.Combine(folder,"ficticio.xlsx");
            using(var zip=ZipFile.Open(xlsx,ZipArchiveMode.Create)) {
                Entry(zip,"xl/workbook.xml","<workbook xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main' xmlns:r='http://schemas.openxmlformats.org/officeDocument/2006/relationships'><sheets><sheet name='Alumnas' sheetId='1' r:id='rId1'/></sheets></workbook>");
                Entry(zip,"xl/_rels/workbook.xml.rels","<Relationships xmlns='http://schemas.openxmlformats.org/package/2006/relationships'><Relationship Id='rId1' Target='worksheets/sheet1.xml'/></Relationships>");
                Entry(zip,"xl/styles.xml","<styleSheet xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><numFmts><numFmt numFmtId='164' formatCode='000000000000'/></numFmts><cellXfs><xf numFmtId='0'/><xf numFmtId='164'/></cellXfs></styleSheet>");
                Entry(zip,"xl/worksheets/sheet1.xml","<worksheet xmlns='http://schemas.openxmlformats.org/spreadsheetml/2006/main'><sheetData><row r='1'><c r='A1' t='inlineStr'><is><t>Nombre</t></is></c><c r='B1' t='inlineStr'><is><t>NUSS</t></is></c></row><row r='2'><c r='A2' t='inlineStr'><is><t>Ficticia</t></is></c><c r='B2' s='1'><v>1234567890</v></c></row><row r='3'><c r='A3'><f>1+1</f><v>2</v></c></row></sheetData></worksheet>");
            }
            var excel=Importer.Read(xlsx)[0];
            Assert(excel.Rows[1][1]=="001234567890","Excel conserva ceros de formato numérico simple");
            Assert(excel.Issues.Contains("2:0"),"Fórmulas de Excel requieren revisión");
            var monthly=Model.Empty();
            monthly["exclusions"]=new List<object>();
            var ms=Student(monthly);
            ms["name"]="Seguimiento ficticio";
            ms["companyID"]=J.S(c,"id");
            ms["assignment"]="Definitiva";
            ms["hasStart"]=true;
            ms["start"]=J.Stamp(new DateTime(2026,11,2));
            J.A(monthly,"companies").Add(J.Clone(c));
            var contacts=Model.Contacts(monthly,Model.Items(monthly,"companies").First());
            Assert(contacts.Count==3&&J.Date(contacts[0],"plannedDate")==new DateTime(2026,12,2),"Seguimiento mensual desde el inicio");
            Assert(Model.Report(monthly).Contains("Seguimiento ficticio"),"Informe del curso");
            var readOnly=Model.Empty();
            var readStudent=Student(readOnly);
            readStudent.Remove("targetHours");
            var readCompany=Model.Company();
            J.A(readOnly,"companies").Add(readCompany);
            string unchanged=J.Json(readOnly);
            Model.Flow(readStudent,"annexI");
            Model.Flow(readCompany,"agreement");
            Model.Report(readOnly);
            Model.Contacts(readOnly,readCompany);
            Model.Periods(readStudent,readOnly);
            J.A(readStudent,"optionalMissing");
            Assert(J.Json(readOnly)==unchanged,"Consultar informes, periodos y documentos no modifica datos");
            var historyStore=new Store(Path.Combine(folder,"historial"));
            historyStore.Restore(readOnly);
            var owner=Model.Items(historyStore.Db,"students").First();
            historyStore.Change(()=> {
                Model.Complete(Model.EditFlow(owner,"annexI"),"receivedTutor",true,null);
                Model.SyncLegacy(owner,"annexI");
            });
            Assert(Model.Done(Model.Flow(owner,"annexI"),"receivedTutor"),"Una edición explícita registra el documento");
            historyStore.Undo(false);
            Assert(J.Get(Model.Items(historyStore.Db,"students").First(),"documents")==null,"Deshacer elimina el documento creado por la edición");
            historyStore.Undo(true);
            Assert(Model.Done(Model.Flow(Model.Items(historyStore.Db,"students").First(),"annexI"),"receivedTutor"),"Rehacer recupera documento y recepción");
            var big=Model.Empty();
            J.EditArray(big,"archivedCourses").Add(J.Obj("id",J.Id(),"title","Ficticio","archivedOn",J.Stamp(J.Today),"snapshot",Convert.ToBase64String(new byte[1024*1024])));
            historyStore.Restore(big);
            long initialHistory=historyStore.HistoryBytes;
            for(int i=0;
            i<10;
            i++) {
                int n=i;
                historyStore.Change(()=>historyStore.Db["institute"]="Centro "+n);
            }
            Assert(historyStore.HistoryBytes-initialHistory<20000,"Diez ediciones no duplican el archivo de curso de 1 MB en Deshacer");
            historyStore.Undo(false);
            Assert(J.S(historyStore.Db,"institute")=="Centro 8","Historial incremental restaura campos");
            historyStore.Undo(true);
            Assert(J.S(historyStore.Db,"institute")=="Centro 9","Historial incremental rehace campos");
            historyStore.Change(()=>historyStore.Db["institute"]="Edición nueva");
            historyStore.Undo(true);
            Assert(J.S(historyStore.Db,"institute")=="Edición nueva","Una nueva edición descarta Rehacer");
            var cacheStore=new Store(Path.Combine(folder,"cache"));
            cacheStore.Restore(monthly);
            var cachedStudent=Model.Items(cacheStore.Db,"students").First();
            cacheStore.Queries.Calculate(cachedStudent);
            cacheStore.Queries.Periods(cachedStudent);
            cacheStore.Queries.Contacts(Model.Items(cacheStore.Db,"companies").First());
            cacheStore.Queries.Calculate(cachedStudent);
            Assert(cacheStore.Queries.CalculationRuns==1,"Filtros, periodos y contactos reutilizan una sola previsión");
            cacheStore.Change(()=>cachedStudent["hours"]=3.0);
            cacheStore.Queries.Calculate(cachedStudent);
            Assert(cacheStore.Queries.CalculationRuns==2,"Un cambio invalida la previsión cacheada");
            cacheStore.Undo(false);
            cacheStore.Queries.Calculate(Model.Items(cacheStore.Db,"students").First());
            Assert(cacheStore.Queries.CalculationRuns==3,"Deshacer también invalida la caché");
            Reject(()=>cacheStore.Change(()=>cacheStore.Db["institute"]=123),"Se revierte una edición inválida");
            Assert(J.Get(cacheStore.Db,"institute") is string,"La reversión conserva el tipo original");
            UpdateTests(folder);
            var firstID=J.Id();var nextID=J.Id();
            Assert(WorkspaceRules.Selection(new[]{firstID,nextID},"")==firstID,"Abre la primera ficha disponible");
            Assert(WorkspaceRules.Selection(new[]{firstID,nextID},nextID)==nextID,"Conserva la ficha seleccionada al volver");
            Assert(WorkspaceRules.Selection(new[]{nextID},firstID)==nextID,"Eliminar la ficha abierta selecciona otra");
            Assert(WorkspaceRules.Selection(new string[0],firstID)=="","Listado vacío no conserva una selección obsoleta");
            var tutorDb=Model.Empty();var tutor=Model.Tutor();tutor["name"]="Tutora ficticia";
            var company=Model.Company();company["name"]="Empresa del tutor";tutor["companyID"]=J.S(company,"id");
            J.EditArray(tutorDb,"companies").Add(company);J.EditArray(tutorDb,"tutors").Add(tutor);
            var initial=Student(tutorDb);initial["name"]="Alumna inicial";initial["tutorID"]=J.S(tutor,"id");
            var laterStudent=Student(tutorDb);laterStudent["name"]="Alumna posterior";
            J.EditArray(laterStudent,"shifts").Add(J.Obj("id",J.Id(),"tutorID",J.S(tutor,"id")));
            J.EditArray(laterStudent,"shifts").Add(J.Obj("id",J.Id(),"tutorID",J.S(tutor,"id")));
            Assert(WorkspaceRules.TutorStudents(tutorDb,J.S(tutor,"id")).Count==2,"Tutor incluye periodos posteriores sin duplicar alumnas");
            var lines=WorkspaceRules.TutorLines(tutorDb,tutor);
            Assert(lines.SequenceEqual(new[]{"Tutora ficticia","Empresa del tutor","Alumna inicial","Alumna posterior"}),"Lista de tutores ordena nombre, empresa y alumnas");
            Assert(WorkspaceRules.TutorMatches(tutorDb,tutor,"empresa del tutor")&&WorkspaceRules.TutorMatches(tutorDb,tutor,"posterior"),"Búsqueda de tutores admite empresa y alumna");
            Assert(WorkspaceRules.TutorLines(tutorDb,Model.Tutor()).Skip(1).SequenceEqual(new[]{"Sin empresa","Sin alumnas asignadas"}),"Tutor sin vínculos muestra estados explícitos");
            TwoPeriodTests();
            Console.WriteLine("SUPERADAS: "+count+" comprobaciones.");
            return 0;
        }
        catch(Exception ex) {
            Console.Error.WriteLine(ex);
            return 1;
        }
        finally {
            if(Directory.Exists(folder))Directory.Delete(folder,true);
        }
    }
    static void TwoPeriodTests() {
        var db=Model.Empty();
        db["version"]=5;
        db["exclusions"]=new List<object>();
        var company=Model.Company();
        company["capacity"]=1;
        company["response"]="accepted";
        J.EditArray(db,"companies").Add(company);
        var student=Student(db);
        student["targetHours"]=40.0;
        Model.ConvertPeriods(student,db);
        var periods=Model.Items(student,"practicePeriods").ToList();
        Assert(periods.Count==2&&!J.B(periods[1],"active"),"Dos periodos con segundo opcional");
        var first=periods[0];var second=periods[1];
        first["hasStart"]=true;
        first["start"]=J.Stamp(new DateTime(2026,11,2));
        first["targetHours"]=14.0;
        Assert(Model.CalculatePeriod(first,db).Error!=null,"El cálculo exige empresa asignada");
        string id=J.S(company,"id");
        Model.Assign(db,student,first,id);
        Reject(()=>Model.Assign(db,student,first,""),"Un periodo no puede quedar sin empresa al editar la asignación");
        J.EditArray(first,"shifts").Add(J.Obj("id",J.Id(),"from",J.Stamp(new DateTime(2026,11,3)),"hours",3.5));
        Assert(Model.CalculatePeriod(first,db).End==new DateTime(2026,11,4),"El cambio de jornada afecta solo a su periodo");
        second["active"]=true;
        second["hasStart"]=true;
        second["start"]=J.Stamp(new DateTime(2026,11,5));
        second["targetHours"]=7.0;
        Model.Assign(db,student,second,id);
        first["assignment"]="Definitiva";
        Assert(Model.PeriodAssignment(student,second)=="Provisional","Confirmar un periodo no confirma el otro");
        student["previousCourseHours"]=10.0;
        student["nextCourseHours"]=9.0;
        var global=Model.Calculate(student,db,new DateTime(2026,11,6));
        Assert(global.Elapsed==21&&Model.RemainingHours(student,global.Elapsed)==9&&Model.Occupied(db,id)==1,"Suma independiente de periodos, horas previas y una sola plaza por alumna");
        Assert(Model.Decode(J.Json(db))["version"].ToString()=="5","Se guardan ambos periodos en el formato 5");
        second["start"]=J.Stamp(new DateTime(2026,11,4));
        Assert(Model.Calculate(student,db,new DateTime(2026,11,6)).Elapsed==14&&Model.Periods(student,db)[1].Result.Error!=null,"No se suman periodos solapados");
    }
    static void Entry(ZipArchive zip,string path,string text) {
        using(var w=new StreamWriter(zip.CreateEntry(path).Open()))w.Write(text);
    }
    static void UpdateTests(string folder) {
        string root=Path.Combine(folder,"actualizacion");
        Directory.CreateDirectory(root);
        var payload=new Dictionary<string,byte[]> {
            {
                "PracticasFP.exe",Encoding.UTF8.GetBytes("nueva aplicación ficticia")
            }, {
                "Desinstalar.exe",Encoding.UTF8.GetBytes("nuevo desinstalador ficticio")
            }
        };
        string app=Path.Combine(root,"PracticasFP.exe"),uninstall=Path.Combine(root,"Desinstalar.exe");
        File.WriteAllText(app,"anterior");
        File.WriteAllText(uninstall,"desinstalador anterior");
        Reject(()=>UpdateFiles.Install(root,payload,()=> {
        },()=> {
        },name=> {
            throw new IOException("Fallo simulado después del primer reemplazo");
        }),"Actualización detecta fallo tras reemplazar un archivo");
        Assert(File.ReadAllText(app)=="anterior"&&File.ReadAllText(uninstall)=="desinstalador anterior","Se recuperan ambos archivos anteriores tras el fallo");
        bool rolledBack=false;
        Reject(()=>UpdateFiles.Install(root,payload,()=> {
            throw new IOException("Fallo simulado de accesos directos");
        },()=> {
            rolledBack=true;
        }),"Actualización detecta fallo en integración");
        Assert(rolledBack&&File.ReadAllText(app)=="anterior","Fallo en integración recupera archivos e invoca recuperación de accesos");
        UpdateFiles.Install(root,payload,()=> {
        },()=> {
        });
        Assert(File.ReadAllText(app)=="nueva aplicación ficticia"&&File.ReadAllText(Path.Combine(root,"VersionAnterior","PracticasFP.exe"))=="anterior","Actualización correcta conserva una versión anterior recuperable");
        using(var locked=new FileStream(app,FileMode.Open,FileAccess.Read,FileShare.None))Reject(()=>UpdateFiles.Install(root,payload,()=> {
        },()=> {
        }),"Aplicación en uso impide actualizar antes de cambiar archivos");
        string fresh=Path.Combine(folder,"instalacion-ficticia");
        Reject(()=>UpdateFiles.Install(fresh,payload,()=> {
            throw new IOException("fallo");
        },()=> {
        }),"Fallo de primera instalación");
        Assert(!File.Exists(Path.Combine(fresh,"PracticasFP.exe"))&&!File.Exists(Path.Combine(fresh,"Desinstalar.exe")),"Primera instalación fallida retira solo los archivos nuevos");
        string interrupted=Path.Combine(root,".actualizacion-ficticia");
        Directory.CreateDirectory(interrupted);
        File.WriteAllText(Path.Combine(interrupted,"old-PracticasFP.exe"),"recuperada");
        File.WriteAllText(Path.Combine(interrupted,"old-Desinstalar.exe"),"recuperado");
        File.WriteAllLines(Path.Combine(interrupted,"existing.txt"),new[] {
            "PracticasFP.exe","Desinstalar.exe"
        });
        File.WriteAllText(Path.Combine(interrupted,"prepared"),"1");
        File.WriteAllText(app,"incompleta");
        UpdateFiles.Recover(root);
        Assert(File.ReadAllText(app)=="recuperada"&&!Directory.Exists(interrupted),"Se recupera una sustitución interrumpida al reintentar");
    }
}
