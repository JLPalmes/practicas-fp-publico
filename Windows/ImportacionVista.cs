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
    public class ImportForm:Form {
        readonly List<Sheet> sheets;
        readonly object db;
        readonly ComboBox sheet=new ChoiceField();
        readonly NumericUpDown header=new NumberField();
        readonly DataGridView grid=new DataGridView();
        readonly FlowLayoutPanel mappings=new FlowLayoutPanel();
        readonly List<ComboBox> map=new List<ComboBox>();
        readonly Label summary=new Label();
        public List<object> Accepted=new List<object>();
        public ImportForm(List<Sheet> source,object existing) {
            sheets=source;
            db=existing;
            Text="Importar alumnas · revisión previa";
            Size=new Size(1050,780);
            StartPosition=FormStartPosition.CenterParent;
            Font=new Font("Segoe UI",10);
            sheet.DropDownStyle=ComboBoxStyle.DropDownList;
            sheet.Width=220;
            sheet.Items.AddRange(sheets.Select(x=>x.Name).ToArray());
            header.Minimum=1;
            header.Maximum=10000;
            header.Width=80;
            var top=new FlowLayoutPanel {
                Dock=DockStyle.Top,Height=42
            };
            top.Controls.Add(new Label {
                Text="Hoja",AutoSize=true
            });
            top.Controls.Add(sheet);
            top.Controls.Add(new Label {
                Text="Fila de títulos",AutoSize=true
            });
            top.Controls.Add(header);
            Controls.Add(top);
            mappings.Dock=DockStyle.Top;
            mappings.Height=190;
            mappings.AutoScroll=true;
            Controls.Add(mappings);
            mappings.BringToFront();
            top.BringToFront();
            grid.Dock=DockStyle.Fill;
            grid.AllowUserToAddRows=false;
            grid.AllowUserToDeleteRows=false;
            grid.AutoSizeColumnsMode=DataGridViewAutoSizeColumnsMode.Fill;
            grid.Columns.Add(new DataGridViewCheckBoxColumn {
                Name="use",HeaderText="Importar",FillWeight=30
            });
            grid.Columns.Add("name","Nombre");
            grid.Columns.Add("dni","DNI / NIE");
            grid.Columns.Add("nuss","NUSS");
            grid.Columns.Add("issue","Revisión");
            foreach(DataGridViewColumn col in grid.Columns)if(col.Name!="use")col.ReadOnly=true;
            Controls.Add(grid);
            grid.BringToFront();
            var bottom=new FlowLayoutPanel {
                Dock=DockStyle.Bottom,Height=70
            };
            summary.Width=550;
            summary.Height=60;
            bottom.Controls.Add(summary);
            var preview=new Button {
                Text="Revisar selección",AutoSize=true
            };
            preview.Click+=(s,e)=>Preview();
            bottom.Controls.Add(preview);
            var accept=new Button {
                Text="Importar",AutoSize=true
            };
            accept.Click+=(s,e)=> {
                grid.EndEdit();
                Accepted=grid.Rows.Cast<DataGridViewRow>().Where(r=>Convert.ToBoolean(r.Cells[0].Value)&&r.Tag!=null).Select(r=>r.Tag).ToList();
                if(Accepted.Count==0)return;
                DialogResult=DialogResult.OK;
            };
            bottom.Controls.Add(accept);
            Controls.Add(bottom);
            bottom.BringToFront();
            sheet.SelectedIndexChanged+=(s,e)=>Mapping();
            header.ValueChanged+=(s,e)=>Mapping();
            if(sheet.Items.Count>0)sheet.SelectedIndex=0;
        }
        void Mapping() {
            mappings.Controls.Clear();
            map.Clear();
            if(sheet.SelectedIndex<0)return;
            var s=sheets[sheet.SelectedIndex];
            int h=(int)header.Value-1;
            if(h>=s.Rows.Count) {
                grid.Rows.Clear();
                summary.Text="La fila elegida no existe.";
                return;
            }
            var used=new HashSet<int>();
            for(int i=0;
            i<s.Rows[h].Length;
            i++) {
                var panel=new FlowLayoutPanel {
                    FlowDirection=FlowDirection.TopDown,Width=175,Height=70
                };
                panel.Controls.Add(new Label {
                    Text=s.Rows[h][i],Width=170,Height=24
                });
                var c=new ChoiceField {
                    DropDownStyle=ComboBoxStyle.DropDownList,Width=170
                };
                c.Items.AddRange(Importer.Titles);
                int guess=Importer.Guess(s.Rows[h][i]);
                c.SelectedIndex=used.Contains(guess)?0:guess;
                if(guess!=0)used.Add(guess);
                c.SelectionChangeCommitted+=(sender,args)=>Preview();
                panel.Controls.Add(c);
                mappings.Controls.Add(panel);
                map.Add(c);
            }
            Preview();
        }
        void Preview() {
            grid.Rows.Clear();
            if(sheet.SelectedIndex<0)return;
            var s=sheets[sheet.SelectedIndex];
            int[] mapping=map.Select(x=>x.SelectedIndex).ToArray();
            var assigned=mapping.Where(x=>x!=0).ToList();
            if(assigned.Distinct().Count()!=assigned.Count) {
                summary.Text="Cada campo puede asignarse a una sola columna.";
                return;
            }
            var seen=new HashSet<string>();
            foreach(var existing in Model.Items(db,"students"))seen.UnionWith(Importer.Identity(existing));
            int valid=0;
            for(int r=(int)header.Value;
            r<s.Rows.Count;
            r++) {
                if(s.Rows[r].All(string.IsNullOrWhiteSpace))continue;
                string issue;
                var student=Importer.Student(s,r,mapping,out issue);
                var ids=Importer.Identity(student);
                if(issue==null&&seen.Overlaps(ids))issue="Posible duplicado: no se importará.";
                bool ok=issue==null;
                if(ok) {
                    seen.UnionWith(ids);
                    valid++;
                }
                int at=grid.Rows.Add(ok,J.S(student,"name"),J.S(student,"dni"),J.S(student,"nuss"),issue??"Lista para importar");
                grid.Rows[at].Tag=ok?student:null;
                if(!ok) {
                    grid.Rows[at].Cells[0].ReadOnly=true;
                    grid.Rows[at].DefaultCellStyle.BackColor=Color.MistyRose;
                }
            }
            summary.Text=valid+" filas válidas. Desmarca las que no quieras importar.\nTras cambiar la correspondencia, pulsa Revisar selección.";
        }
    }
}
