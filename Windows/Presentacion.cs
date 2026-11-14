// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.Linq;
using System.Collections.Generic;
namespace PracticasFP {
    public static class WorkspaceRules {
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
