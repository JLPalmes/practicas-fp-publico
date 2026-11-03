// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Drawing;
using System.Drawing.Imaging;
using System.Reflection;
using System.Windows.Forms;
using System.Collections.Generic;
using PracticasFP;
class UiTests {
    static int checks;
    static void Check(bool value,string text) {
        if(!value)throw new Exception(text);
        checks++;Console.WriteLine("OK UI · "+text);
    }
    static T Field<T>(object o,string name) {
        return (T)o.GetType().GetField(name,BindingFlags.Instance|BindingFlags.NonPublic).GetValue(o);
    }
    static void Invoke(object o,string name,params object[] args) {
        o.GetType().GetMethod(name,BindingFlags.Instance|BindingFlags.NonPublic).Invoke(o,args);Pump();
    }
    static void Pump() {for(int i=0;i<8;i++)Application.DoEvents();}
    static IEnumerable<Control> All(Control parent) {
        foreach(Control c in parent.Controls) {
            yield return c;
            foreach(var child in All(c))yield return child;
        }
    }
    static void Snapshot(MainForm form,string output,string name) {
        Pump();using(var bitmap=new Bitmap(form.Width,form.Height)) {
            form.DrawToBitmap(bitmap,new Rectangle(0,0,form.Width,form.Height));
            bitmap.Save(Path.Combine(output,"Windows-"+name+".png"),ImageFormat.Png);
        }
    }
    [STAThread] static int Main(string[] args) {
        string folder=Path.Combine(Path.GetTempPath(),"PracticasFP-UI-"+Guid.NewGuid().ToString("N"));
        try {
            Application.EnableVisualStyles();Application.SetCompatibleTextRenderingDefault(false);
            string output=args[0];Directory.CreateDirectory(output);
            var store=new Store(folder);var db=Model.Empty();
            var company=Model.Company();company["name"]="Empresa de prueba";company["capacity"]=4;company["response"]="accepted";
            var tutor=Model.Tutor();tutor["name"]="Tutora de prueba";tutor["companyID"]=J.S(company,"id");
            var other=Model.Tutor();other["name"]="Tutor sin asignación";
            var initial=Model.Student();initial["name"]="Alumna del periodo inicial";initial["companyID"]=J.S(company,"id");initial["tutorID"]=J.S(tutor,"id");initial["assignment"]="Definitiva";
            var later=Model.Student();later["name"]="Alumna del periodo posterior";
            J.EditArray(later,"shifts").Add(J.Obj("id",J.Id(),"from",J.Stamp(J.Today),"companyID",J.S(company,"id"),"tutorID",J.S(tutor,"id"),"hours",7.0));
            db["students"]=new List<object>{initial,later};db["companies"]=new List<object>{company};db["tutors"]=new List<object>{tutor,other};
            store.Db=db;
            using(var form=new MainForm(store)) {
                form.Show();Pump();form.Size=new Size(900,620);Pump();
                Check(Field<string>(form,"selected")==J.S(initial,"id"),"Alumnas abre automáticamente su primera ficha");
                var split=Field<SplitContainer>(form,"split");
                Check(!split.Panel1Collapsed&&!split.Panel2Collapsed,"Panel y ficha permanecen visibles");
                Snapshot(form,output,"alumnas-estrecha");
                var editor=Field<Panel>(form,"editor");
                Console.WriteLine("LAYOUT editor "+editor.ClientSize+" display "+editor.DisplayRectangle);
                foreach(var control in All(editor).Where(c=>c.Parent!=null&&c.Right>c.Parent.ClientSize.Width))
                    Console.WriteLine("EXCESO "+control.GetType().Name+" tag="+control.Tag+" width="+control.Width+" right="+control.Right+" parent="+control.Parent.GetType().Name+" width="+control.Parent.ClientSize.Width);
                Check(!editor.HorizontalScroll.Visible,"Ficha estrecha sin barra horizontal");
                var content=Field<FlowLayoutPanel>(form,"content");
                var milestone=All(content).OfType<CheckBox>().First(c=>(c.Tag as string??"").Contains("annexI|generated"));
                milestone.Checked=true;Pump();
                Check(Model.Done(Model.Flow(initial,"annexI"),"generated"),"Los hitos en filas guardan su estado");
                Check(!Field<Panel>(form,"editor").HorizontalScroll.Visible,"Los hitos realizados mantienen la ficha sin barra horizontal");
                var header=All(content).OfType<Button>().First(b=>b.Name=="section-toggle");
                Check(header.Width>200&&header.Height>=32,"Toda la cabecera ofrece un área pulsable amplia");
                var body=(FlowLayoutPanel)content.Controls[content.Controls.IndexOf(header)+1];
                bool before=body.Visible;header.PerformClick();Pump();
                Check(body.Visible!=before,"Pulsar la cabecera pliega la sección");header.PerformClick();Pump();
                Invoke(form,"Navigate","tutors");
                var cards=Field<FlowLayoutPanel>(form,"tutorCards");
                var rows=cards.Controls.OfType<TutorListButton>().ToArray();
                Check(rows.Length==2&&rows[0].AccessibleName.Contains("Empresa de prueba")&&rows[0].AccessibleName.Contains("Alumna del periodo posterior"),"Tutor muestra empresa y alumnas de ambos periodos");
                rows[1].PerformClick();Pump();Check(Field<string>(form,"selected")==J.S(other,"id"),"Seleccionar otro tutor actualiza la ficha");
                Invoke(form,"Navigate","companies");Invoke(form,"Navigate","tutors");
                Check(Field<string>(form,"selected")==J.S(other,"id"),"Volver a Tutores conserva la última selección");
                rows=cards.Controls.OfType<TutorListButton>().ToArray();rows[0].PerformClick();Pump();
                Snapshot(form,output,"tutores-estrecha");
                var search=Field<TextBox>(form,"search");search.Text="posterior";Pump();
                Check(cards.Controls.OfType<TutorListButton>().Count()==1,"Buscar una alumna encuentra su tutor");search.Text="";Pump();
                Invoke(form,"Navigate","companies");
                Check(Field<string>(form,"selected")==J.S(company,"id"),"Empresas abre automáticamente su primera ficha");
                Snapshot(form,output,"empresas-estrecha");
                Invoke(form,"Navigate","students");
                store.Change(()=>J.EditArray(store.Db,"students").Remove(initial));Invoke(form,"Render");
                Check(Field<string>(form,"selected")==J.S(later,"id"),"Borrar la ficha abierta selecciona otra");
                store.Change(()=>J.EditArray(store.Db,"students").Clear());Invoke(form,"Render");
                Check(Field<string>(form,"selected")==""&&!split.Panel2Collapsed,"Vaciar la lista mantiene la columna de ficha");
                var add=All(content).OfType<Button>().First(b=>b.Text=="Añadir alumna");
                add.PerformClick();Pump();Check(Model.Items(store.Db,"students").Count()==1&&Field<string>(form,"selected")!="","La columna vacía permite añadir y abre la nueva ficha");
                form.Close();
            }
            Console.WriteLine("SUPERADAS UI: "+checks);return 0;
        }
        catch(Exception ex) {Console.Error.WriteLine(ex.ToString());return 1;}
        finally {if(Directory.Exists(folder))Directory.Delete(folder,true);}
    }
}
