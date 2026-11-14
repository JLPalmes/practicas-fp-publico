// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Collections.Generic;
using System.Linq;

namespace PracticasFP {
    public static partial class Model {
        public static bool HasTwoPeriods(object student) { return J.Get(student,"practicePeriods")!=null; }

        public static string PeriodAssignment(object student,object period) {
            if(J.S(period,"companyID")=="")return "Pendiente";
            string status=J.S(HasTwoPeriods(student)?period:student,"assignment");
            if(status==""&&HasTwoPeriods(student))status=J.S(student,"assignment");
            return status==""?"Pendiente":status;
        }

        public static bool HasConfirmedCompany(object student,string company) {
            return PeriodOwners(student).Any(period=>J.S(period,"companyID")==company&&PeriodAssignment(student,period)=="Definitiva");
        }

        public static string AssignmentSummary(object student,string company=null) {
            if(!HasTwoPeriods(student))return J.S(student,"assignment");
            return string.Join(" · ",PeriodOwners(student).Select((period,index)=>new {period,index})
                .Where(item=>company==null||J.S(item.period,"companyID")==company)
                .Select(item=>(item.index==0?"Primer periodo: ":"Segundo periodo: ")+PeriodAssignment(student,item.period)));
        }

        public static IEnumerable<Dictionary<string,object>> PeriodOwners(object student) {
            return HasTwoPeriods(student)
                ? Items(student,"practicePeriods").Where(p=>J.B(p,"active"))
                : new[]{J.D(student)}.Concat(Items(student,"shifts").Where(p=>J.S(p,"companyID")!=""));
        }

        public static bool HasTutor(object student,string id) {
            var owners=HasTwoPeriods(student)?Items(student,"practicePeriods"):new[]{J.D(student)}.Concat(Items(student,"shifts"));
            return owners.Any(p=>J.S(p,"tutorID")==id);
        }

        public static DateTime? ForecastEnd(object student,Calculation calculation) {
            if(!HasTwoPeriods(student)&&calculation.End.HasValue&&J.B(student,"manualEnd"))
                return J.Date(student,"end");
            return calculation.End;
        }

        static Dictionary<string,object> NewPeriod(bool active,DateTime start,double target) {
            return J.Obj("id",J.Id(),"active",active,"hasStart",false,"start",J.Stamp(start),
                "end",J.Stamp(start),"manualEnd",false,"hours",7.0,"targetHours",target,
                "shifts",new List<object>(),"paperwork",Steps());
        }

        public static void ConvertPeriods(Dictionary<string,object> student,object db) {
            if(HasTwoPeriods(student))return;
            var changes=Items(student,"shifts").OrderBy(x=>J.Date(x,"from")).ToList();
            var placements=changes.Where(x=>J.S(x,"companyID")!="").ToList();
            if(placements.Count>1)throw new InvalidOperationException("Esta ficha tiene más de dos periodos. Conserva la copia anterior y revisa sus periodos antes de convertirla.");

            var first=NewPeriod(true,J.Date(student,"start"),J.N(student,"targetHours",500));
            var second=NewPeriod(placements.Count==1,J.Today,0);
            foreach(string key in new[]{"hasStart","start","end","manualEnd","hours","companyID","tutorID","paperwork","documents"})
                if(student.ContainsKey(key))first[key]=student[key];

            if(placements.Count==1) {
                var placement=placements[0];
                DateTime boundary=J.Date(placement,"from");
                second["start"]=placement["from"];
                second["hasStart"]=J.B(student,"hasStart");
                second["end"]=student["end"];
                second["manualEnd"]=student["manualEnd"];
                foreach(string key in new[]{"hours","companyID","tutorID","paperwork","documents"})
                    if(placement.ContainsKey(key))second[key]=placement[key];
                first["manualEnd"]=true;
                first["end"]=J.Stamp(boundary.AddDays(-1));
                first["shifts"]=changes.Where(x=>J.S(x,"companyID")==""&&J.Date(x,"from")<boundary).Cast<object>().ToList();
                second["shifts"]=changes.Where(x=>J.S(x,"companyID")==""&&J.Date(x,"from")>=boundary).Cast<object>().ToList();
                double consumed=Calculate(first,db).Manual;
                first["targetHours"]=Math.Min(J.N(student,"targetHours",500),consumed);
                second["targetHours"]=Math.Max(0,J.N(student,"targetHours",500)-consumed);
            } else first["shifts"]=changes.Cast<object>().ToList();

            foreach(var period in new[]{first,second})period["assignment"]=PeriodAssignment(student,period);

            student["practicePeriods"]=new List<object>{first,second};
            student["previousCourseHours"]=0.0;
            student["nextCourseHours"]=0.0;
            // Keep the original record for reference. Edits to the new periods
            // must not change the archived steps or shifts through shared objects.
            student["practicePeriods"]=J.A(J.Clone(student),"practicePeriods");
        }

        public static Calculation CalculatePeriod(object period,object db,DateTime? today=null) {
            if(!J.B(period,"active"))return new Calculation();
            if(J.S(period,"companyID")==""||Find(db,"companies",J.S(period,"companyID"))==null)
                return new Calculation {Error="Asigna una empresa al periodo."};
            if(!J.B(period,"hasStart"))return new Calculation();
            if(J.B(period,"manualEnd")&&J.Date(period,"end")<J.Date(period,"start"))
                return new Calculation {Error="El fin manual debe ser igual o posterior al inicio."};
            if(J.N(period,"targetHours")==0&&J.B(period,"manualEnd")) {
                // A manual interval can exist even when the general target has already been met.
                var manual=J.Clone(period);
                manual["targetHours"]=0.01;
                return CalculatePeriod(manual,db,today);
            }
            var calculation=Calculate(period,db,today);
            if(calculation.Error!=null)return calculation;
            if(J.B(period,"manualEnd")) {
                var until=J.Clone(period);
                var yesterday=(today??J.Today).Date.AddDays(-1);
                var end=J.Date(period,"end");
                until["end"]=J.Stamp(yesterday<end?yesterday:end);
                calculation.Elapsed=Calculate(until,db,today).Manual;
                calculation.End=end;
            }
            return calculation;
        }

        static List<Period> TwoPeriods(object student,object db,DateTime? today=null) {
            var periods=PeriodOwners(student).Select(owner=> {
                var calculated=CalculatePeriod(owner,db,today);
                return new Period {Owner=owner,Company=J.S(owner,"companyID"),Tutor=J.S(owner,"tutorID"),
                    Start=J.Date(owner,"start"),End=calculated.End,Result=calculated};
            }).ToList();
            if(periods.Count==2&&J.B(periods[1].Owner,"hasStart")&&periods[0].End.HasValue&&periods[1].Start<=periods[0].End.Value) {
                periods[1].Result.Error="El segundo periodo debe comenzar después de finalizar el primero.";
                periods[1].Result.Elapsed=0;
                periods[1].Result.End=periods[1].End=null;
            }
            return periods;
        }

        static Calculation CalculateGlobal(object student,object db,DateTime? today) {
            var periods=TwoPeriods(student,db,today);
            return new Calculation {
                Elapsed=periods.Sum(p=>p.Result.Elapsed),
                End=periods.Where(p=>p.End.HasValue).Select(p=>p.End).DefaultIfEmpty().Max(),
                Error=periods.Select(p=>p.Result.Error).FirstOrDefault(error=>error!=null)
            };
        }

        public static double RemainingHours(object student,double elapsed) {
            return Math.Max(0,J.N(student,"targetHours",500)-J.N(student,"previousCourseHours")-elapsed);
        }

        static void ValidateTwoPeriods(object student,int version) {
            Require(version==5,"versión del registro con dos periodos");
            Numbers(student,"previousCourseHours","nextCourseHours");
            ArrayField(student,"practicePeriods");
            var periods=Items(student,"practicePeriods").ToList();
            Require(periods.Count==2,"dos periodos por alumna");
            Require(J.B(periods[0],"active"),"primer periodo activo");
            Unique(periods.Select(p=>J.S(p,"id")));
            foreach(var period in periods) {
                Require(ValidGuid(J.S(period,"id")),"identificador del periodo");
                Bools(period,"active","hasStart","manualEnd");
                Dates(period,"start","end");
                Numbers(period,"hours","targetHours");
                OptionalId(period,"companyID");
                OptionalId(period,"tutorID");
                if(J.Get(period,"assignment")!=null)
                    Require(new[]{"Pendiente","Provisional","Definitiva"}.Contains(J.S(period,"assignment")),"asignación del periodo");
                ValidateWorkflow(period);
                CheckSteps(period,10);
                CheckFlows(period,false);
                ArrayField(period,"shifts");
                var shifts=Items(period,"shifts").ToList();
                Unique(shifts.Select(p=>J.S(p,"id")));
                foreach(var shift in shifts) {
                    Require(ValidGuid(J.S(shift,"id"))&&J.S(shift,"companyID")=="","cambio de jornada en la misma empresa");
                    Dates(shift,"from");
                    if(J.Get(shift,"hours")!=null)Numbers(shift,"hours");
                }
            }
        }
    }
}
