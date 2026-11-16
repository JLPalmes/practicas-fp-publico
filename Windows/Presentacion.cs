// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.Linq;
using System.Collections.Generic;
namespace PracticasFP {
    public static class WorkspaceRules {
        public static void CheckDelete(object db,string section,string id) {
            if(section=="companies"&&(Model.Occupied(db,id)>0||Model.Items(db,"tutors").Any(x=>J.S(x,"companyID")==id)))
                throw new InvalidOperationException("Retira primero las alumnas y tutores vinculados a esta empresa.");
            if(section=="tutors"&&Model.Items(db,"students").Any(s=>Model.HasTutor(s,id)))
                throw new InvalidOperationException("Retira primero el tutor de las prácticas vinculadas.");
        }
        public static IEnumerable<string> StudentWarnings(object db,object student) {
            if(J.S(student,"name").Trim()=="")yield return "Completa el nombre.";
            var identity=Importer.Identity(student);
            if(Model.Items(db,"students").Any(other=>J.S(other,"id")!=J.S(student,"id")&&Importer.Identity(other).Overlaps(identity)))
                yield return "Posible ficha duplicada: revisa nombre, DNI, NUSS y correo.";
            string nuss=J.S(student,"nuss");
            if(nuss!=""&&nuss.Count(char.IsDigit)!=12)yield return "Revisa el NUSS: se esperan 12 cifras.";
            string email=J.S(student,"email");
            if(email!=""&&(!email.Contains("@")||email.Any(char.IsWhiteSpace)))yield return "Revisa el correo.";
            string dni=J.S(student,"dni");
            if(dni!=""&&dni.Replace(" ","").Replace("-","").Length!=9)yield return "Revisa el DNI / NIE.";
        }

        public static string Selection(IEnumerable<string> ids,string selected) {
            var available=ids.ToList();
            return available.Contains(selected)?selected:available.FirstOrDefault()??"";
        }
        public static List<Dictionary<string,object>> TutorStudents(Dictionary<string,object> db,string id) {
            return Model.Items(db,"students").Where(s=>Model.HasTutor(s,id)).ToList();
        }
        public static string[] TutorLines(Dictionary<string,object> db,Dictionary<string,object> tutor) {
            var lines=new List<string>{J.S(tutor,"name")==""?"Tutor sin nombre":J.S(tutor,"name"),Model.Name(db,"companies",J.S(tutor,"companyID"))};
            if(J.S(tutor,"companyID")=="")lines[1]="Sin empresa";
            var students=TutorStudents(db,J.S(tutor,"id"));
            if(students.Count==0)lines.Add("Sin alumnas asignadas");
            else lines.AddRange(students.Select(s=>J.S(s,"name")==""?"Alumna sin nombre":J.S(s,"name")));
            return lines.ToArray();
        }
        public static bool TutorMatches(Dictionary<string,object> db,Dictionary<string,object> tutor,string search) {
            return Importer.Key(string.Join(" ",TutorLines(db,tutor))).Contains(Importer.Key(search));
        }
        public static string[] CompanyLines(object db,object company) {
            var students=Model.Items(db,"students").Where(s=>Model.Companies(s).Contains(J.S(company,"id")));
            return new[]{J.S(company,"name")==""?"Empresa sin nombre":J.S(company,"name")}
                .Concat(students.Select(s=>J.S(s,"name")==""?"Alumna sin nombre":J.S(s,"name")).DefaultIfEmpty("Sin alumnas asignadas")).ToArray();
        }

        public static string[] StudentLines(object db,object student) {
            return new[]{J.S(student,"name")==""?"Alumna sin nombre":J.S(student,"name")}
                .Concat(Model.Companies(student).Select(id=>Model.Name(db,"companies",id)).DefaultIfEmpty("Sin empresa asignada")).ToArray();
        }
    }
}
