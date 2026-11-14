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
    static class Program {
        [STAThread] static void Main(string[] args) {
            Application.EnableVisualStyles();
            Application.SetCompatibleTextRenderingDefault(false);
            string folder=Path.Combine(Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData),"PracticasFP2","Datos");
            int at=Array.IndexOf(args,"--data-directory");
            if(at>=0&&at+1<args.Length)folder=Path.GetFullPath(args[at+1]);
            Directory.CreateDirectory(folder);
            try {
                using(var file=new FileStream(Path.Combine(folder,"sesion.lock"),FileMode.OpenOrCreate,FileAccess.ReadWrite,FileShare.None))Application.Run(new MainForm(new Store(folder)));
            }
            catch(IOException) {
                MessageBox.Show("No se puede abrir la carpeta de datos. Puede que Prácticas FP ya esté abierta con esos datos.","Prácticas FP");
            }
        }
    }
    public class Choice {
        public string Id,Title;
        public Choice(string id,string title) {
            Id=id;
            Title=title;
        }
        public override string ToString() {
            return Title;
        }
    }
    public partial class MainForm:Form {
        readonly Store store;
        readonly SplitContainer split=new SplitContainer();
        readonly ListView list=new ListView();
        readonly FlowLayoutPanel tutorCards=new BufferedFlow();
        readonly Panel editor=new BufferedEditor();
        FlowLayoutPanel fields;
        readonly TextBox search=new TextBox();
        readonly ComboBox filter=new ChoiceField();
        readonly ToolStripStatusLabel status=new ToolStripStatusLabel();
        readonly Label heading=new Label();
        string section="students",selected="";
        bool rendering;
        readonly Dictionary<string,string> searches=new Dictionary<string,string>(),selections=new Dictionary<string,string>();
        public MainForm(Store value) {
            store=value;
            fields=content;
            preferences=new ViewPreferences(store.Folder);
            Text="Prácticas FP · Windows · 2.0.0";
            MinimumSize=new Size(900,620);
            Size=new Size(1280,850);
            StartPosition=FormStartPosition.CenterScreen;
            Font=new Font("Segoe UI",10);
            BackColor=Color.FromArgb(245,247,247);
            var nav=new FlowLayoutPanel {
                Dock=DockStyle.Left,Width=174,FlowDirection=FlowDirection.TopDown,Padding=new Padding(10),BackColor=Color.FromArgb(22,65,66),WrapContents=false
            };
            Controls.Add(nav);
            string[] labels= {
                "Alumnas","Empresas","Tutores","Calendario","Ajustes y copias"
            },keys= {
                "students","companies","tutors","exclusions","settings"
            };
            for(int i=0;
            i<keys.Length;
            i++) {
                string key=keys[i];
                var b=new Button {
                    Text=labels[i],Width=150,Height=36,FlatStyle=FlatStyle.Flat,ForeColor=Color.White,BackColor=Color.FromArgb(22,65,66),TextAlign=ContentAlignment.MiddleLeft
                };
                b.Click+=(s,e)=>Navigate(key);
                nav.Controls.Add(b);
            }
            nav.Controls.Add(new Label {
                Text="2.0.0 · Windows",ForeColor=Color.White,AutoSize=true,Margin=new Padding(4,28,0,0)
            });
            var area=new Panel {
                Dock=DockStyle.Fill,Padding=new Padding(8)
            };
            Controls.Add(area);
            area.BringToFront();
            var top=new FlowLayoutPanel {
                Dock=DockStyle.Top,Height=86,FlowDirection=FlowDirection.LeftToRight,WrapContents=true
            };
            heading.Font=new Font(Font,FontStyle.Bold);
            heading.Size=new Size(250,30);
            top.Controls.Add(heading);
            search.Width=220;
            search.TextChanged+=(s,e)=> {
                if(!rendering)RefreshList();
            };
            top.Controls.Add(search);
            filter.Width=210;
            filter.DropDownStyle=ComboBoxStyle.DropDownList;
            filter.SelectedIndexChanged+=(s,e)=> {
                if(!rendering) {
                    filterSelections[section]=filter.SelectedIndex;
                    RefreshList();
                }
            };
            top.Controls.Add(filter);
            addButton=AddButton(top,"Añadir",Add);
            AddButton(top,"Importar CSV / Excel",Import);
            AddButton(top,"Informe…",Report);
            AddButton(top,"Deshacer",()=>Safe(()=> {
                store.Undo(false);
                Render();
            }));
            AddButton(top,"Rehacer",()=>Safe(()=> {
                store.Undo(true);
                Render();
            }));
            split.Size=new Size(1000,600);
            split.Dock=DockStyle.Fill;
            split.FixedPanel=FixedPanel.None;
            split.Panel1MinSize=250;
            split.Panel2MinSize=320;
            split.SplitterWidth=7;
            area.Controls.Add(split);
            area.Controls.Add(top);
            split.SplitterDistance=450;
            list.Dock=DockStyle.Fill;
            list.View=View.Details;
            list.FullRowSelect=true;
            list.HideSelection=false;
            list.MultiSelect=false;
            list.Columns.Add("Nombre",220);
            list.Columns.Add("Resumen",330);
            list.SelectedIndexChanged+=(s,e)=> {
                if(rendering||list.SelectedItems.Count==0)return;
                RememberView();
                selected=(string)list.SelectedItems[0].Tag;
                RenderEditor();
            };
            split.Panel1.Controls.Add(list);
            list.Resize+=(s,e)=>FitListColumns();
            tutorCards.Dock=DockStyle.Fill;
            tutorCards.FlowDirection=FlowDirection.TopDown;
            tutorCards.WrapContents=false;
            tutorCards.AutoScroll=true;
            tutorCards.Padding=new Padding(4);
            tutorCards.Visible=false;
            tutorCards.Resize+=(s,e)=>FitTutorCards();
            split.Panel1.Controls.Add(tutorCards);
            editor.Dock=DockStyle.Fill;
            editor.AutoScroll=true;
            split.Panel2.Controls.Add(editor);
            pinned.Dock=DockStyle.Top;
            pinned.Height=40;
            pinned.Padding=new Padding(6);
            pinned.Font=new Font(Font,FontStyle.Bold);
            pinned.BackColor=Color.FromArgb(226,236,235);
            split.Panel2.Controls.Add(pinned);
            content.FlowDirection=FlowDirection.TopDown;
            content.WrapContents=false;
            content.AutoSize=true;
            content.AutoSizeMode=AutoSizeMode.GrowAndShrink;
            content.Padding=new Padding(6);
            editor.Controls.Add(content);
            editor.Resize+=(s,e)=> {
                if(!building)FitFields();
            };
            split.SplitterMoved+=(s,e)=> {
                if(!restoring&&!building)preferences.SetWidth(section,split.SplitterDistance);
            };
            var statusStrip=new StatusStrip();
            statusStrip.Items.Add(status);
            Controls.Add(statusStrip);
            statusStrip.BringToFront();
            FormClosing+=(s,e)=> {
                ActiveControl=null;
            };
            Shown+=(s,e)=> {
                ApplyWidth();
                Render();
                if(store.Error!=null)MessageBox.Show(this,store.Error,"Datos protegidos",MessageBoxButtons.OK,MessageBoxIcon.Warning);
            };
            KeyPreview=true;
            KeyDown+=(s,e)=> {
                if(e.Control&&e.KeyCode==Keys.Z&&!(ActiveControl is TextBox)) {
                    store.Undo(false);
                    Render();
                    e.Handled=true;
                }
            };
        }
        Button addButton;
        Button AddButton(Control panel,string title,Action action) {
            var b=new Button {
                Text=title,AutoSize=true,Height=32,Margin=new Padding(3)
            };
            b.Click+=(s,e)=>Safe(action);
            panel.Controls.Add(b);
            return b;
        }
        void Safe(Action action) {
            try {
                action();
                status.Text=store.Blocked?"Archivo protegido · revisa Ajustes y copias":"Guardado en este equipo · "+J.S(store.Db,"course");
            }
            catch(Exception ex) {
                MessageBox.Show(this,ex.Message,"No se ha completado la operación",MessageBoxButtons.OK,MessageBoxIcon.Warning);
                Render();
            }
        }
        void Navigate(string key) {
            ActiveControl=null;
            RememberView();
            cardOffsets[section]=Math.Max(0,-tutorCards.AutoScrollPosition.Y);
            if(list.TopItem!=null)listPositions[section]=list.TopItem.Index;
            filterSelections[section]=filter.SelectedIndex;
            searches[section]=search.Text;
            selections[section]=selected;
            section=key;
            restoreListPosition=true;
            selected=selections.ContainsKey(key)?selections[key]:"";
            rendering=true;
            search.Text=searches.ContainsKey(key)?searches[key]:"";
            rendering=false;
            ApplyWidth();
            Render();
        }
        void Render() {
            rendering=true;
            heading.Text=section=="students"?"Alumnas":section=="companies"?"Empresas":section=="tutors"?"Tutores":section=="exclusions"?"Calendario":"Ajustes y copias";
            addButton.Text=section=="exclusions"?"Añadir día o intervalo":"Añadir";
            addButton.Visible=section!="settings";
            int savedFilter;
            filterSelections.TryGetValue(section,out savedFilter);
            filter.Items.Clear();
            filter.Items.AddRange(section=="students"?new object[] {
                "Todas","Sin tutor","Anexo I pendiente","Finalizan este mes","Contacto vencido"
            }
            :section=="companies"?new object[] {
                "Todas","Esperando respuesta","Admite alumnas","Rechaza alumnas","Asignaciones definitivas"
            }
            :new object[] {
                "Todas"
            });
            filter.SelectedIndex=Math.Max(0,Math.Min(savedFilter,filter.Items.Count-1));
            rendering=false;
            if(new[]{"students","companies","tutors","exclusions"}.Contains(section))
                selected=WorkspaceRules.Selection(Model.Items(store.Db,section).Select(x=>J.S(x,"id")),selected);
            RefreshList();
            RenderEditor();
            status.Text=store.Blocked?"Archivo protegido · revisa Ajustes y copias":"Guardado en este equipo · "+J.S(store.Db,"course");
        }
        Dictionary<string,object> Current() {
            return Model.Find(store.Db,section,selected);
        }
        bool StudentFilter(Dictionary<string,object> s) {
            int f=filter.SelectedIndex;
            if(f==0)return true;
            var p=store.Queries.Periods(s);
            if(f==1)return p.Any(x=>x.Company!=""&&x.Tutor=="");
            if(f==2)return p.Any(x=>x.Company!=""&&!Model.Done(Model.Flow(x.Owner,"annexI"),"archived"));
            if(f==3) {
                var c=store.Queries.Calculate(s);
                DateTime? end=Model.ForecastEnd(s,c);
                return end.HasValue&&end.Value.ToString("yyyy-MM")==J.Today.ToString("yyyy-MM");
            }
            return Model.Companies(s).Any(id=> {
                var c=Model.Find(store.Db,"companies",id);
                return c!=null&&store.Queries.Contacts(c).Any(x=>!J.B(x,"historical")&&!J.B(x,"completed")&&J.Date(x,"plannedDate")<J.Today);
            });
        }
        bool CompanyFilter(Dictionary<string,object> company) {
            switch(filter.SelectedIndex) {
                case 1: return J.S(company,"response")=="waiting";
                case 2: return J.S(company,"response")=="accepted";
                case 3: return J.S(company,"response")=="rejected";
                case 4: return Model.Items(store.Db,"students").Any(s=>Model.HasConfirmedCompany(s,J.S(company,"id")));
                default: return true;
            }
        }
        void RefreshList() {
            rendering=true;
            string previous=selected;
            if(new[]{"students","companies","tutors"}.Contains(section))
                selected=WorkspaceRules.Selection(Model.Items(store.Db,section).Select(x=>J.S(x,"id")),selected);
            bool showCards=section=="students"||section=="companies"||section=="tutors";
            tutorCards.Visible=showCards;
            list.Visible=!showCards;
            if(showCards) {
                RefreshCards();
                rendering=false;
                UpdatePinned();
                if(previous!=selected)RenderEditor();
                return;
            }
            int top=list.TopItem==null?0:list.TopItem.Index;
            list.BeginUpdate();
            list.Items.Clear();
            if(section=="exclusions")foreach(var o in Model.Items(store.Db,section)) {
                string name=J.S(o,"title");
                if(!Importer.Key(name).Contains(Importer.Key(search.Text)))continue;
                string summary=J.Text(J.Date(o,"from"))+" – "+J.Text(J.Date(o,"to"));
                var item=new ListViewItem(name==""?"Sin nombre":name);
                item.SubItems.Add(summary);
                item.Tag=J.S(o,"id");
                list.Items.Add(item);
                if((string)item.Tag==selected)item.Selected=true;
            }
            list.EndUpdate();
            FitListColumns();
            int savedTop;
            if(restoreListPosition&&listPositions.TryGetValue(section,out savedTop))top=savedTop;
            restoreListPosition=false;
            if(list.Items.Count>0)list.TopItem=list.Items[Math.Min(top,list.Items.Count-1)];
            rendering=false;
            UpdatePinned();
            if(previous!=selected)RenderEditor();
        }
        void ClearEditor() {
            fields=content;
            titleCounts.Clear();
            foreach(var field in textFields.Values) {
                if(field.Input.Parent!=null)field.Input.Parent.Controls.Remove(field.Input);
                if(field.Caption.Parent!=null)field.Caption.Parent.Controls.Remove(field.Caption);
            }
            foreach(Control c in content.Controls.Cast<Control>().ToArray())c.Dispose();
            content.Controls.Clear();
        }
        void Note(string text) {
            fields.Controls.Add(new Label {
                Text=text,AutoSize=true,MaximumSize=new Size(530,0),Margin=new Padding(0,4,0,10)
            });
        }
        sealed class TextFieldBinding {
            public readonly Label Caption=new Label {AutoSize=true,Margin=new Padding(0,7,0,2)};
            public readonly TextBox Input=new TextBox();
            public Dictionary<string,object> Record;
        }
        readonly Dictionary<string,TextFieldBinding> textFields=new Dictionary<string,TextFieldBinding>();

        void TextField(Dictionary<string,object> obj,string key,string title,bool multiline=false) {
            string slot=section+"|"+fields.Tag+"|"+key;
            TextFieldBinding binding;
            if(!textFields.TryGetValue(slot,out binding)) {
                binding=new TextFieldBinding();
                textFields.Add(slot,binding);
                binding.Input.Leave+=(s,e)=> {
                    var record=binding.Record;
                    string value=binding.Input.Text;
                    if(value==J.S(record,key))return;
                    Safe(()=> {
                        store.Change(()=>record[key]=value);
                        RefreshList();
                    });
                };
            }
            binding.Record=obj;
            binding.Caption.Text=title;
            binding.Input.Multiline=multiline;
            binding.Input.Height=multiline?75:28;
            binding.Input.Width=FieldWidth;
            binding.Input.Tag=FieldTag(obj,key);
            binding.Input.Text=J.S(obj,key);
            fields.Controls.Add(binding.Caption);
            fields.Controls.Add(binding.Input);
        }
        void Number(Dictionary<string,object> obj,string key,string title,decimal min,decimal max,int decimals=0,Action<decimal> custom=null,bool optional=false) {
            fields.Controls.Add(new Label {
                Text=title,AutoSize=true,Margin=new Padding(0,7,0,2)
            });
            var row=new FlowLayoutPanel {
                AutoSize=true,WrapContents=true,Width=FieldWidth,Margin=new Padding(0,3,0,3)
            };
            var n=new NumberField {
                Minimum=min,Maximum=max,Tag=FieldTag(obj,key),DecimalPlaces=decimals,Increment=decimals>0?0.5m:1m,Width=130
            };
            double value=J.N(obj,key,key=="targetHours"?500:(double)min);
            n.Value=Math.Max(min,Math.Min(max,(decimal)value));
            row.Controls.Add(n);
            CheckBox enabled=null;
            if(optional) {
                enabled=new CheckBox {
                    Text="Indicado",Checked=J.Get(obj,key)!=null,AutoSize=true
                };
                n.Enabled=enabled.Checked;
                row.Controls.Add(enabled);
                enabled.CheckedChanged+=(s,e)=>Safe(()=> {
                    store.Change(()=> {
                        if(enabled.Checked) {
                            if(custom!=null)custom(n.Value);
                            else obj[key]=(double)n.Value;
                        }
                        else obj.Remove(key);
                    });
                    RenderEditor();
                    RefreshList();
                });
            }
            n.Leave+=(s,e)=> {
                if(optional&&enabled!=null&&!enabled.Checked)return;
                if((double)n.Value==J.N(obj,key))return;
                Safe(()=> {
                    store.Change(()=> {
                        if(custom!=null)custom(n.Value);
                        else obj[key]=(double)n.Value;
                    });
                    RefreshList();
                    RenderEditor();
                });
            };
            fields.Controls.Add(row);
        }
        CheckBox Check(Dictionary<string,object> obj,string key,string title,Action<bool> custom=null,Action refresh=null,bool documentStep=false) {
            CheckBox c=documentStep?new DocumentCheckBox():new CheckBox();
            c.Text=title;
            c.Tag=FieldTag(obj,key);
            c.Checked=J.B(obj,key);
            c.AutoSize=!documentStep;
            c.MaximumSize=new Size(520,0);
            c.Margin=new Padding(0,8,0,5);
            c.CheckedChanged+=(s,e)=>Safe(()=> {
                store.Change(()=> {
                    if(custom!=null)custom(c.Checked);
                    else obj[key]=c.Checked;
                });
                RefreshList();
                if(refresh==null)RenderEditor();else refresh();
            });
            fields.Controls.Add(c);
            return c;
        }
        void DateField(Dictionary<string,object> obj,string key,string title,bool optional=false,Action<object> custom=null,bool refreshEditor=false) {
            var row=new FlowLayoutPanel {
                AutoSize=true,WrapContents=true,Width=FieldWidth,Margin=new Padding(0,3,0,3)
            };
            row.Controls.Add(new Label {
                Text=title,AutoSize=true,MaximumSize=new Size(Math.Max(100,FieldWidth-165),0),TextAlign=ContentAlignment.MiddleLeft
            });
            var date=new DateFieldControl {
                Tag=FieldTag(obj,key),Format=DateTimePickerFormat.Short,Width=145,ShowCheckBox=optional
            };
            date.Value=J.Date(obj,key);
            date.Checked=!optional||J.Get(obj,key)!=null;
            row.Controls.Add(date);
            date.CloseUp+=(s,e)=>SaveDate(obj,key,date,optional,custom,refreshEditor);
            date.Leave+=(s,e)=>SaveDate(obj,key,date,optional,custom,refreshEditor);
            fields.Controls.Add(row);
        }
        void SaveDate(Dictionary<string,object> obj,string key,DateTimePicker d,bool optional,Action<object> custom,bool refreshEditor) {
            object value=optional&&!d.Checked?null:(object)J.Stamp(d.Value.Date);
            if(J.Get(obj,key)==null&&value==null||J.Get(obj,key)!=null&&value!=null&&J.N(obj,key)==(double)value)return;
            Safe(()=> {
                store.Change(()=> {
                    if(custom!=null)custom(value);
                    else if(value==null)obj.Remove(key);
                    else obj[key]=value;
                });
                RefreshList();
                if(refreshEditor)RenderEditor();
            });
        }
        void Select(Dictionary<string,object> obj,string key,string title,List<Choice> choices,Action<string> custom=null,string selectedValue=null) {
            fields.Controls.Add(new Label {
                Text=title,AutoSize=true,Margin=new Padding(0,7,0,2)
            });
            var c=new ChoiceField {
                DropDownStyle=ComboBoxStyle.DropDownList,Tag=FieldTag(obj,key),Width=FieldWidth
            };
            c.Items.AddRange(choices.ToArray());
            c.SelectedIndex=Math.Max(0,choices.FindIndex(x=>x.Id==(selectedValue??J.S(obj,key))));
            c.SelectionChangeCommitted+=(s,e)=>Safe(()=> {
                var choice=(Choice)c.SelectedItem;
                store.Change(()=> {
                    if(custom!=null)custom(choice.Id);
                    else if(choice.Id=="")obj.Remove(key);
                    else obj[key]=choice.Id;
                });
                RefreshList();
                RenderEditor();
            });
            fields.Controls.Add(c);
        }
        List<Choice> Choices(string list,string company=null) {
            return new[] {
                new Choice("","Sin asignar")
            }
            .Concat(Model.Items(store.Db,list).Where(x=>company==null||J.S(x,"companyID")==company).OrderBy(x=>J.S(x,"name")).Select(x=>new Choice(J.S(x,"id"),J.S(x,"name")))).ToList();
        }
        void Link(string list,string id,string title) {
            if(id=="")return;
            AddButton(fields,title,()=> {
                Navigate(list);
                selected=id;
                RefreshList();
                RenderEditor();
            });
        }
        void RebuildEditor() {
            rendering=true;
            ClearEditor();
            if(section=="settings")Settings();
            else {
                var o=Current();
                if(section=="exclusions")CalendarSettings();
                if(section=="exclusions")Title("Día o intervalo");
                if(o==null) {
                    Note(section=="exclusions"?"Añade un día o intervalo al calendario.":section=="tutors"?"Añade un tutor. Su ficha aparecerá aquí, junto al listado.":section=="companies"?"Añade una empresa. Su ficha aparecerá aquí, junto al listado.":"Añade una alumna. Su ficha aparecerá aquí, junto al listado.");
                    AddButton(fields,section=="exclusions"?"Añadir día o intervalo":section=="tutors"?"Añadir tutor":section=="companies"?"Añadir empresa":"Añadir alumna",Add);
                }
                else {
                    if(section=="students")Student(o);
                    if(section=="companies")Company(o);
                    if(section=="tutors")Tutor(o);
                    if(section=="exclusions") {
                        TextField(o,"title","Descripción");
                        DateField(o,"from","Desde (incluido)");
                        DateField(o,"to","Hasta (incluido)");
                        TextField(o,"kind","Tipo");
                        AddButton(fields,"Eliminar día o intervalo…",Delete);
                    }
                    else {
                        Title("Acciones de la ficha");
                        AddButton(fields,"Eliminar…",Delete);
                    }
                }
            }
            content.Enabled=!store.Blocked||section=="settings";
            rendering=false;
        }
    }
}
