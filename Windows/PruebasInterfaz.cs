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
                var contactRow=All(content).OfType<FlowLayoutPanel>().First(p=>p.Name=="contact");
                Check(contactRow.Controls[0].Top==contactRow.Controls[1].Top,"Teléfono y correo comparten fila en la ficha de alumna");
                foreach(string pair in new[]{"identification","hours"}) {
                    var row=All(content).OfType<FlowLayoutPanel>().First(p=>p.Name==pair);
                    Check(row.Controls[0].Top==row.Controls[1].Top,"La ficha muestra en paralelo los campos de "+pair);
                }
                var documentRow=All(content).OfType<FlowLayoutPanel>().First(p=>(string)p.Tag=="document-columns");
                Check(documentRow.Controls[0].Top==documentRow.Controls[1].Top,"Los pasos de documentación se distribuyen en columnas");
                var list=Field<ListView>(form,"list");
                var nameField=All(content).OfType<TextBox>().First(c=>(c.Tag as string??"").EndsWith("|name"));
                list.Items[1].Selected=true;Pump();
                Check(nameField==All(content).OfType<TextBox>().First(c=>(c.Tag as string??"").EndsWith("|name"))&&nameField.Text==J.S(later,"name"),"Cambiar de alumna reutiliza el campo y muestra el nombre correcto");
                nameField.Focus();nameField.Text="Nombre editado en segunda ficha";list.Focus();Pump();
                Check(J.S(later,"name")=="Nombre editado en segunda ficha"&&J.S(initial,"name")=="Alumna del periodo inicial","El campo reutilizado guarda en la ficha correcta");
                nameField.Focus();nameField.Text="Alumna del periodo posterior";list.Focus();Pump();
                list.Items[0].Selected=true;Pump();
                var annexHeader=All(content).OfType<Button>().First(b=>b.AccessibleName=="Anexo I · asignación de tutor");
                annexHeader.PerformClick();Pump();
                list.Items[1].Selected=true;Pump();
                annexHeader=All(content).OfType<Button>().First(b=>b.AccessibleName=="Anexo I · asignación de tutor");
                var annexBody=content.Controls[content.Controls.IndexOf(annexHeader)+1];
                Check(annexBody.Controls.Count==0,"El anexo plegado no crea controles al cambiar de ficha");
                annexHeader.PerformClick();Pump();
                Check(annexBody.Controls.Count>0,"Al desplegar el anexo se crean sus controles");
                list.Items[0].Selected=true;Pump();
                var milestone=All(content).OfType<CheckBox>().First(c=>(c.Tag as string??"").Contains("annexI|generated"));
                milestone.Checked=true;Pump();
                Check(Model.Done(Model.Flow(initial,"annexI"),"generated"),"Los hitos en filas guardan su estado");
                var generated=Model.Items(Model.Flow(initial,"annexI"),"milestones").First(m=>J.S(m,"id")=="generated");
                Check(J.Get(generated,"date")==null,"Marcar un hito no registra una fecha");
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
                var companyRow=All(content).OfType<FlowLayoutPanel>().First(p=>p.Name=="company");
                Check(companyRow.Controls[0].Top==companyRow.Controls[1].Top,"Empresa y CIF comparten fila");
                Snapshot(form,output,"empresas-estrecha");
                var followup=All(content).OfType<Button>().First(b=>b.AccessibleName=="Seguimiento mensual");
                var followupBody=content.Controls[content.Controls.IndexOf(followup)+1];
                Check(followupBody.Controls.Count>0,"Seguimiento mensual muestra contenido incluso sin contactos");
                followup.PerformClick();Pump();
                Check(!followupBody.Visible,"Plegar Seguimiento mensual oculta su contenido");
                form.Size=new Size(1300,760);Pump();
                var columns=All(content).OfType<FlowLayoutPanel>().First(p=>(string)p.Tag=="columns");
                Check(columns.Controls[0].Top==columns.Controls[1].Top,"Contacto y plazas se muestran en paralelo con espacio suficiente");
                store.Change(()=>J.EditArray(store.Db,"exclusions").Clear());
                Invoke(form,"Navigate","exclusions");
                var addDay=All(content).OfType<Button>().First(b=>b.Text=="Añadir día o intervalo");
                addDay.PerformClick();Pump();
                Check(Model.Items(store.Db,"exclusions").Count()==1&&All(content).OfType<Button>().Any(b=>b.Text=="Eliminar día o intervalo…"&&b.Visible),"Añadir un día abre su ficha con la acción de eliminar visible");
                Check(!All(form).OfType<Button>().Any(b=>b.Text=="Pendientes"||b.Text=="Historial"),"La navegación omite Pendientes e Historial");
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
