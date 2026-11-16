// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Collections.Generic;
using System.Diagnostics;
using System.IO;
using System.Linq;
using System.Reflection;

static class PackageTests {
    static readonly string[] Files={"PracticasFP.exe","motor.exe","Desinstalar.exe"};

    static byte[] Resource(Assembly assembly,string name) {
        using(var source=assembly.GetManifestResourceStream(name)) {
            if(source==null)throw new IOException("Falta el recurso "+name);
            using(var output=new MemoryStream()) {
                source.CopyTo(output);
                return output.ToArray();
            }
        }
    }
    static void Check(bool condition,string description) {
        if(!condition)throw new InvalidOperationException(description);
    }
    static bool X64(byte[] bytes) {
        return bytes.Length>64&&bytes[0]==77&&bytes[1]==90&&BitConverter.ToUInt16(bytes,BitConverter.ToInt32(bytes,60)+4)==0x8664;
    }
    static void Run(string app,string argument,string session,string expected) {
        var start=new ProcessStartInfo(app,argument) {
            UseShellExecute=false,RedirectStandardOutput=true,RedirectStandardError=true,
            WorkingDirectory=Path.GetTempPath()
        };
        start.EnvironmentVariables["PRACTICAS_FP_TEST_SESSION"]=session;
        start.EnvironmentVariables.Remove("PRACTICAS_FP_BENCHMARK_COPY");
        using(var process=Process.Start(start)) {
            var output=process.StandardOutput.ReadToEndAsync();
            var error=process.StandardError.ReadToEndAsync();
            if(!process.WaitForExit(90000)) {
                process.Kill();
                process.WaitForExit();
                throw new TimeoutException("No terminó la prueba empaquetada "+argument);
            }
            Check(process.ExitCode==0&&output.Result.Contains(expected),output.Result+error.Result);
            Console.WriteLine(output.Result.Trim());
        }
    }
    static int Main(string[] args) {
        string session=Guid.NewGuid().ToString("N");
        string root=Path.Combine(Path.GetTempPath(),"PracticasFP-Paquete-"+session);
        string data=Path.Combine(Path.GetTempPath(),"PracticasFP-Rendimiento-"+session);
        try {
            string installer=Path.GetFullPath(args[0]);
            var assembly=Assembly.ReflectionOnlyLoadFrom(installer);
            var payload=new Dictionary<string,byte[]> {
                {"PracticasFP.exe",Resource(assembly,"PracticasFP.exe")},
                {"motor.exe",Resource(assembly,"motor.exe")},
                {"Desinstalar.exe",File.ReadAllBytes(installer)}
            };
            Check(payload.Values.All(X64),"El paquete contiene un ejecutable que no es x64.");
            Check(Resource(assembly,"LICENSE").Length>0&&Resource(assembly,"AVISO-LICENCIA.txt").Length>0,"Faltan las licencias.");
            UpdateFiles.Install(root,payload,()=>{},()=>{},null,Files);
            foreach(var file in payload)Check(File.ReadAllBytes(Path.Combine(root,file.Key)).SequenceEqual(file.Value),"Extracción distinta para "+file.Key);
            string app=Path.Combine(root,"PracticasFP.exe");
            Run(app,"--verificar-piloto",session,"copias verificadas");
            string courseFile=Path.Combine(data,"datos.json");
            byte[] course=File.ReadAllBytes(courseFile);
            var changed=new Dictionary<string,byte[]>(payload);
            changed["motor.exe"]=payload["motor.exe"].Concat(new byte[]{1}).ToArray();
            bool rollback=false;
            try {
                UpdateFiles.Install(root,changed,()=>{},()=>{},name=>{
                    if(name=="motor.exe")throw new IOException("Fallo simulado.");
                },Files);
            } catch(IOException error) {
                if(error.Message!="Fallo simulado.")throw;
                rollback=true;
            }
            Check(rollback&&File.ReadAllBytes(Path.Combine(root,"motor.exe")).SequenceEqual(payload["motor.exe"]),"La actualización no recuperó el motor original.");
            UpdateFiles.Install(root,payload,()=>{},()=>{},null,Files);
            Check(File.ReadAllBytes(courseFile).SequenceEqual(course),"Actualizar cambió los datos del curso.");
            Check(Files.All(name=>File.Exists(Path.Combine(root,"VersionAnterior",name))),"Falta algún ejecutable de la versión anterior.");
            Run(app,"--verificar-reapertura-piloto",session,"verificados tras reiniciar");
            Console.WriteLine("Paquete x64, instalación aislada, reversión y actualización verificadas.");
            return 0;
        } catch(Exception error) {
            Console.Error.WriteLine(error);
            return 1;
        } finally {
            if(Directory.Exists(root))Directory.Delete(root,true);
            if(Directory.Exists(data))Directory.Delete(data,true);
        }
    }
}
