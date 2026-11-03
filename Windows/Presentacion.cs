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
            return Model.Items(db,"students").Where(s=>J.S(s,"tutorID")==id||Model.Items(s,"shifts").Any(p=>J.S(p,"tutorID")==id)).ToList();
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
    }
}
