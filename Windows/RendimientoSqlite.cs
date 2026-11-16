// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Collections.Generic;
using System.IO;
using System.Linq;
using System.Runtime.InteropServices;
using System.Text;
using PracticasFP;

internal sealed class RendimientoSqlite : IDisposable {
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)]
    delegate int Row(IntPtr user,int count,IntPtr columns,IntPtr names);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_open(byte[] path,out IntPtr handle);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_exec(IntPtr handle,byte[] sql,Row callback,IntPtr user,out IntPtr error);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]
    static extern void sqlite3_free(IntPtr pointer);
    [DllImport("winsqlite3.dll",CallingConvention=CallingConvention.Cdecl)]
    static extern int sqlite3_close(IntPtr handle);

    IntPtr handle;
    static byte[] Utf8(string text) {return Encoding.UTF8.GetBytes(text+"\0");}
    static string Read(IntPtr pointer) {
        if(pointer==IntPtr.Zero)return null;
        int length=0;
        while(Marshal.ReadByte(pointer,length)!=0)length++;
        var bytes=new byte[length];
        Marshal.Copy(pointer,bytes,0,length);
        return Encoding.UTF8.GetString(bytes);
    }
    static string Literal(string value) {return "'"+value.Replace("'","''")+"'";}

    RendimientoSqlite(string path) {
        if(sqlite3_open(Utf8(path),out handle)==0)return;
        Dispose();
        throw new IOException("No se pudo abrir la base SQLite de prueba.");
    }
    public void Dispose() {
        if(handle==IntPtr.Zero)return;
        sqlite3_close(handle);
        handle=IntPtr.Zero;
    }
    List<string> Query(string sql) {
        var rows=new List<string>();
        Row callback=(user,count,columns,names)=>{
            rows.Add(Read(Marshal.ReadIntPtr(columns)));
            return 0;
        };
        IntPtr error;
        if(sqlite3_exec(handle,Utf8(sql),callback,IntPtr.Zero,out error)==0)return rows;
        string message=Read(error);
        sqlite3_free(error);
        throw new InvalidOperationException(message);
    }
    void Execute(string sql) {Query(sql);}

    sealed class ContactStore : Store {
        readonly RendimientoSqlite sqlite;
        readonly string studentId;

        internal ContactStore(string folder,RendimientoSqlite sqlite,Dictionary<string,object> backup,string studentId)
            : base(folder) {
            this.sqlite=sqlite;
            this.studentId=studentId;
            Db=Model.Decode(J.Json(backup));
        }

        protected override void Persist(Dictionary<string,object> db,string json) {
            // This experiment only writes changes to the selected student's contact fields.
            var student=Model.Find(db,"students",studentId);
            sqlite.Execute("UPDATE student SET payload="+Literal(J.Json(student))+" WHERE id="+Literal(studentId)+";");
        }
    }

    static void Import(RendimientoSqlite sqlite,Dictionary<string,object> backup) {
        var db=Model.Decode(J.Json(backup));
        var students=Model.Items(db,"students").ToArray();
        db["students"]=new List<object>();
        sqlite.Execute("PRAGMA foreign_keys=ON; PRAGMA synchronous=FULL; "+
            "CREATE TABLE metadata(payload TEXT NOT NULL); "+
            "CREATE TABLE student(id TEXT PRIMARY KEY, position INTEGER NOT NULL, payload TEXT NOT NULL); "+
            "CREATE TABLE assignment(company TEXT NOT NULL, student TEXT REFERENCES student(id), PRIMARY KEY(company,student)); BEGIN;");
        sqlite.Execute("INSERT INTO metadata VALUES("+Literal(J.Json(db))+");");
        for(int index=0;index<students.Length;index++) {
            var student=students[index];
            string id=Literal(J.S(student,"id"));
            sqlite.Execute("INSERT INTO student VALUES("+id+","+index+","+Literal(J.Json(student))+");");
            foreach(string company in Model.Companies(student))
                sqlite.Execute("INSERT INTO assignment VALUES("+Literal(company)+","+id+");");
        }
        sqlite.Execute("COMMIT;");
    }
    static void VerifyRoundTrip(RendimientoSqlite sqlite,Dictionary<string,object> backup) {
        var restored=J.Parse(sqlite.Query("SELECT payload FROM metadata;").Single());
        restored["students"]=sqlite.Query("SELECT payload FROM student ORDER BY position;")
            .Select(row=>(object)J.Parse(row)).ToList();
        if(J.Json(Model.Decode(J.Json(restored)))!=J.Json(Model.Decode(J.Json(backup))))
            throw new InvalidOperationException("La copia restaurada cambió al pasar por SQLite.");
    }
    static void Compare(string path,Dictionary<string,object> backup) {
        using(var sqlite=new RendimientoSqlite(path))Import(sqlite,backup);
        using(var sqlite=new RendimientoSqlite(path)) {
            VerifyRoundTrip(sqlite,backup);
            Console.WriteLine("SQLite: copia JSON restaurada y verificada con ambos periodos.");
            var students=Model.Items(backup,"students").ToArray();
            var student=J.Clone(students[0]);
            string id=Literal(J.S(student,"id"));
            string company=Model.Companies(student).Single();
            string search="SELECT student FROM assignment WHERE company="+Literal(company)+";";
            int expected=students.Count(s=>Model.Companies(s).Contains(company));
            if(sqlite.Query(search).Count!=expected)throw new InvalidOperationException("Asignaciones distintas.");
            Rendimiento.Measure("JSON en memoria: alumnas de una empresa",i=>
                students.Where(s=>Model.Companies(s).Contains(company)).Select(s=>J.S(s,"id")).ToArray());
            Rendimiento.Measure("SQLite: alumnas de una empresa",i=>sqlite.Query(search));
            Rendimiento.Measure("SQLite: leer una ficha",i=>J.Parse(sqlite.Query("SELECT payload FROM student WHERE id="+id+";").Single()));
            Rendimiento.Measure("SQLite: guardar un teléfono",i=> {
                student["phone"]="600000"+i.ToString("D3");
                sqlite.Execute("UPDATE student SET payload="+Literal(J.Json(student))+" WHERE id="+id+";");
            });
            if(J.S(J.Parse(sqlite.Query("SELECT payload FROM student WHERE id="+id+";").Single()),"phone")!="600000029")
                throw new InvalidOperationException("No se guardó el último teléfono.");
            string studentId=J.S(student,"id");
            var full=new ContactStore(Path.GetDirectoryName(path),sqlite,backup,studentId);
            Func<string> savedPhone=()=>J.S(J.Parse(sqlite.Query("SELECT payload FROM student WHERE id="+id+";").Single()),"phone");
            Action<string> edit=phone=>full.Change(()=>Model.Find(full.Db,"students",studentId)["phone"]=phone);
            Rendimiento.Measure("SQLite: guardado con validación e historial",i=>edit("600000"+i.ToString("D3")));
            VerifyRoundTrip(sqlite,full.Db);
            full.Undo(false);
            if(savedPhone()!="600000028")throw new InvalidOperationException("Deshacer no actualizó SQLite.");
            full.Undo(true);
            if(savedPhone()!="600000029")throw new InvalidOperationException("Rehacer no actualizó SQLite.");
            bool rejected=false;
            try {full.Change(()=>Model.Find(full.Db,"students",studentId)["phone"]=123);}
            catch(Exception) {rejected=true;}
            if(!rejected||J.S(Model.Find(full.Db,"students",studentId),"phone")!="600000029"||savedPhone()!="600000029")
                throw new InvalidOperationException("La validación rechazó incorrectamente la edición o alteró el teléfono.");
            VerifyRoundTrip(sqlite,full.Db);
            Console.WriteLine("SQLite: validación, deshacer, rehacer y concordancia con el modelo verificados.");
        }
    }
    internal static void Run(string folder,Dictionary<string,object> backup) {
        var legacy=Model.Empty();
        legacy["version"]=1;
        var student=Model.Student();
        student["name"]="Alumna de una copia anterior";
        legacy["students"]=new List<object>{student};
        using(var sqlite=new RendimientoSqlite(Path.Combine(folder,"anterior.sqlite"))) {
            Import(sqlite,legacy);
            VerifyRoundTrip(sqlite,legacy);
            Console.WriteLine("SQLite: copia ficticia de la versión 1 migrada y verificada.");
        }
        Compare(Path.Combine(folder,"prueba.sqlite"),backup);
    }
}
