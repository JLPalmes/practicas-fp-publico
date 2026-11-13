// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
namespace PracticasFP {
    internal sealed class DocumentCheckBox : CheckBox {
        protected override CreateParams CreateParams {
            get {
                var parameters=base.CreateParams;
                parameters.Style |= 0x2000; // BS_MULTILINE
                return parameters;
            }
        }
    }

    internal sealed class BufferedEditor : Panel {
        public BufferedEditor() { DoubleBuffered=true; }
    }

    internal sealed class BufferedFlow : FlowLayoutPanel {
        public BufferedFlow() { DoubleBuffered=true; }
    }

    public sealed class TutorListButton: Button {
        readonly string[] lines;
        public TutorListButton(string[] value) {
            lines=value;FlatStyle=FlatStyle.Flat;FlatAppearance.BorderSize=0;
            AccessibleName=string.Join(" · ",lines);Text="";TextAlign=ContentAlignment.TopLeft;
        }
        public int HeightFor(int width) {
            int height=12;
            using(var bold=new Font(Font,FontStyle.Bold))for(int i=0;i<lines.Length;i++)
                height+=TextRenderer.MeasureText(lines[i],i==0?bold:Font,new Size(Math.Max(80,width-16),int.MaxValue),TextFormatFlags.WordBreak).Height+2;
            return Math.Max(40,height);
        }
        protected override void OnPaint(PaintEventArgs e) {
            base.OnPaint(e);int y=6;
            using(var bold=new Font(Font,FontStyle.Bold))for(int i=0;i<lines.Length;i++) {
                var font=i==0?bold:Font;
                int h=TextRenderer.MeasureText(lines[i],font,new Size(Math.Max(80,Width-16),int.MaxValue),TextFormatFlags.WordBreak).Height;
                TextRenderer.DrawText(e.Graphics,lines[i],font,new Rectangle(8,y,Math.Max(80,Width-16),h),i==1?Color.DimGray:ForeColor,TextFormatFlags.WordBreak);
                y+=h+2;
            }
        }
    }
    // UI preferences are separate from student data, backups and undo history.
    public sealed class ViewPreferences {
        readonly string path;
        Dictionary<string,object> values=new Dictionary<string,object>();
        public ViewPreferences(string folder) {
            path=Path.Combine(folder,"vista-windows.json");
            try {
                if(File.Exists(path))values=J.Parse(File.ReadAllText(path));
            }
            catch {
            }
        }
        public bool Open(string key) {
            return J.Get(values,"fold:"+key)==null||J.B(values,"fold:"+key);
        }
        public int Width(string section) {
            return (int)J.N(values,"width:"+section,section=="tutors"?300:340);
        }
        public void SetOpen(string key,bool open) {
            values["fold:"+key]=open;
            Save();
        }
        public void SetWidth(string section,int width) {
            values["width:"+section]=width;
            Save();
        }
        void Save() {
            try {
                J.Atomic(path,J.Json(values));
            }
            catch(IOException) {
            }
            catch(UnauthorizedAccessException) {
            }
        }
    }
    public partial class MainForm {
        readonly FlowLayoutPanel content=new BufferedFlow();
        readonly List<FlowLayoutPanel> buildingSections=new List<FlowLayoutPanel>();
        readonly Label pinned=new Label();
        readonly Dictionary<string,int> scrollPositions=new Dictionary<string,int>();
        readonly Dictionary<string,int> filterSelections=new Dictionary<string,int>();
        readonly Dictionary<string,int> listPositions=new Dictionary<string,int>();
        readonly Dictionary<string,int> titleCounts=new Dictionary<string,int>();
        ViewPreferences preferences;
        string visibleKey="";
        bool refreshQueued,building,restoring,restoreListPosition;
        string FieldTag(object obj,string key) {
            return Convert.ToString(fields.Tag)+"|"+J.S(obj,"id")+"|"+key;
        }
        int FieldWidth {
            get {
                return Math.Max(200,editor.ClientSize.Width-content.Padding.Horizontal-8);
            }
        }
        string ViewKey {
            get {
                return section+"|"+selected;
            }
        }
        void RememberView() {
            if(visibleKey!="")scrollPositions[visibleKey]=Math.Max(0,-editor.AutoScrollPosition.Y);
        }
        void UpdatePinned() {
            var o=Current();
            string name=o==null?heading.Text:J.S(o,section=="exclusions"?"title":"name");
            pinned.Text=string.IsNullOrWhiteSpace(name)?"Ficha sin nombre":name;
            if(section=="students"&&o!=null)pinned.Text+=" · "+J.S(o,"assignment");
            if(section=="tutors"&&o!=null)pinned.Text+=" · "+Model.Name(store.Db,"companies",J.S(o,"companyID"));
        }
        void ApplyWidth() {
            int maximum=Math.Max(split.Panel1MinSize,split.ClientSize.Width-split.Panel2MinSize-split.SplitterWidth);
            restoring=true;
            split.SplitterDistance=Math.Max(split.Panel1MinSize,Math.Min(maximum,preferences.Width(section)));
            restoring=false;
        }
        void FitFields() {
            int width=FieldWidth;
            content.SuspendLayout();
            content.MaximumSize=new Size(width+content.Padding.Horizontal+6,0);
            content.Width=content.MaximumSize.Width;
            foreach(Control child in content.Controls)FitControl(child,width);
            content.ResumeLayout(true);
        }
        void FitControl(Control control,int width) {
            width=Math.Max(120,width-control.Margin.Horizontal);
            var flow=control as FlowLayoutPanel;
            if(flow!=null) {
                flow.SuspendLayout();
                try {
                    flow.MaximumSize=new Size(width,0);
                    flow.Width=width;
                    string layout=flow.Tag as string;
                    if(layout=="columns"||layout=="contact-columns"||layout=="document-columns") {
                        int minimumWidth=layout=="columns"?225:layout=="contact-columns"?155:180;
                        int columnCount=Math.Max(1,Math.Min(layout=="document-columns"?3:2,width/minimumWidth));
                        int columnWidth=width/columnCount;
                        foreach(Control child in flow.Controls)FitControl(child,columnWidth);
                    }
                    else foreach(Control child in flow.Controls)FitControl(child,width-flow.Padding.Horizontal);
                } finally {
                    flow.ResumeLayout(true);
                }
            }
            else if(control is Button) {
                control.AutoSize=false;control.Width=width;
                control.Height=Math.Max(32,TextRenderer.MeasureText(control.Text,control.Font,new Size(Math.Max(60,width-12),int.MaxValue),TextFormatFlags.WordBreak).Height+8);
            }
            else if(control is TextBox||control is ComboBox)control.Width=width;
            else if(control is DocumentCheckBox) {
                control.AutoSize=false;
                control.Width=width;
                control.Height=TextRenderer.MeasureText(control.Text,control.Font,new Size(width-28,int.MaxValue),TextFormatFlags.WordBreak).Height+8;
            }
            else if(control is Label||control is CheckBox)control.MaximumSize=new Size(width,0);
        }
        void FitListColumns() {
            int width=Math.Max(100,list.ClientSize.Width-SystemInformation.VerticalScrollBarWidth-4);
            list.Columns[0].Width=width*45/100;
            list.Columns[1].Width=width-list.Columns[0].Width;
        }
        void FitTutorCards() {
            int width=Math.Max(180,tutorCards.ClientSize.Width-tutorCards.Padding.Horizontal-8);
            foreach(Control item in tutorCards.Controls) {
                item.Width=width;
                var card=item as TutorListButton;
                if(card!=null)card.Height=card.HeightFor(width);
            }
        }
        void RefreshTutorCards() {
            int offset=Math.Max(0,-tutorCards.AutoScrollPosition.Y);
            tutorCards.SuspendLayout();
            foreach(Control item in tutorCards.Controls.Cast<Control>().ToArray())item.Dispose();
            foreach(var tutor in Model.Items(store.Db,"tutors").Where(t=>WorkspaceRules.TutorMatches(store.Db,t,search.Text))) {
                string id=J.S(tutor,"id");
                var card=new TutorListButton(WorkspaceRules.TutorLines(store.Db,tutor)) {
                    Name="tutor-card",Tag=id,Font=Font,Margin=new Padding(0,0,0,4),BackColor=id==selected?Color.FromArgb(209,229,226):Color.White
                };
                card.Click+=(s,e)=> {
                    RememberView();selected=id;
                    foreach(Control row in tutorCards.Controls)row.BackColor=(string)row.Tag==id?Color.FromArgb(209,229,226):Color.White;
                    RenderEditor();
                };
                tutorCards.Controls.Add(card);
            }
            FitTutorCards();
            tutorCards.ResumeLayout(true);
            tutorCards.AutoScrollPosition=new Point(0,offset);
        }
        void RenderEditor() {
            // Defer disposal until the current click/Leave event has completed. A
            // numeric editor losing focus must not destroy the button being clicked.
            if(refreshQueued||building||IsDisposed)return;
            refreshQueued=true;
            if(!IsHandleCreated) {
                refreshQueued=false;
                BuildEditor();
                return;
            }
            BeginInvoke(new Action(()=> {
                refreshQueued=false;
                if(!IsDisposed)BuildEditor();
            }));
        }
        static Control FocusedControl(Control parent) {
            foreach(Control child in parent.Controls) {
                if(child.Focused)return child;
                if(child.ContainsFocus)return FocusedControl(child);
            }
            return null;
        }
        void BuildEditor() {
            if(building)return;
            building=true;
            bool same=visibleKey==ViewKey;
            var focused=FocusedControl(content);
            string focusTag=focused==null?null:focused.Tag as string;
            int caret=focused is TextBox?((TextBox)focused).SelectionStart:0;
            RememberView();
            int offset;
            scrollPositions.TryGetValue(ViewKey,out offset);
            try {
                int fittedWidth;
                editor.SuspendLayout();
                content.SuspendLayout();
                try {
                    RebuildEditor();
                    foreach(string slot in textFields.Keys.ToArray()) {
                        var field=textFields[slot];
                        if(field.Input.Parent!=null)continue;
                        field.Input.Dispose();
                        field.Caption.Dispose();
                        textFields.Remove(slot);
                    }
                    fittedWidth=FieldWidth;
                    FitFields();
                } finally {
                    foreach(var body in buildingSections)body.ResumeLayout(true);
                    buildingSections.Clear();
                    content.ResumeLayout(true);
                    editor.ResumeLayout(true);
                }
                visibleKey=ViewKey;
                UpdatePinned();
                if(FieldWidth!=fittedWidth)FitFields();
                if(same&&focusTag!=null) {
                    var target=FindTag(content,focusTag);
                    if(target!=null&&target.CanFocus) {
                        target.Focus();
                        var text=target as TextBox;
                        if(text!=null)text.SelectionStart=Math.Min(caret,text.TextLength);
                    }
                }
                editor.AutoScrollPosition=new Point(0,offset);
            }
            finally {
                building=false;
                rendering=false;
            }
        }
        static Control FindTag(Control parent,string tag) {
            foreach(Control c in parent.Controls) {
                if((c.Tag as string)==tag)return c;
                var found=FindTag(c,tag);
                if(found!=null)return found;
            }
            return null;
        }
        void Title(string text,Action populate=null,FlowLayoutPanel parent=null) {
            parent=parent??content;
            int count;
            titleCounts.TryGetValue(text,out count);
            titleCounts[text]=count+1;
            string key=section+"|"+text+"|"+count;
            var body=new FlowLayoutPanel {
                Tag=key,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,Width=FieldWidth,Margin=new Padding(0,0,0,4)
            };
            if(building) {
                body.SuspendLayout();
                buildingSections.Add(body);
            }
            bool open=preferences.Open(key);
            bool populated=populate==null;
            body.Visible=open;
            var toggle=new Button {
                Name="section-toggle",AccessibleName=text,Text=(open?"▾  ":"▸  ")+text,Width=FieldWidth,Height=32,TextAlign=ContentAlignment.MiddleLeft,FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(226,236,235),Font=new Font(Font,FontStyle.Bold),Margin=new Padding(0,6,0,3)
            };
            toggle.Click+=(s,e)=> {
                RememberView();
                bool show=!body.Visible;
                if(show&&!populated) {
                    var previous=fields;
                    content.SuspendLayout();
                    body.SuspendLayout();
                    try {
                        fields=body;
                        populate();
                        populated=true;
                        FitControl(body,FieldWidth);
                    } finally {
                        fields=previous;
                        body.ResumeLayout(true);
                        content.ResumeLayout(true);
                    }
                }
                body.Visible=show;
                toggle.Text=(body.Visible?"▾  ":"▸  ")+text;
                preferences.SetOpen(key,body.Visible);
                content.PerformLayout();
            };
            parent.Controls.Add(toggle);
            parent.Controls.Add(body);
            fields=body;
            if(open&&!populated) {
                populate();
                populated=true;
            }
        }
        void DocumentChanged(Dictionary<string,object> owner,string kind,string stage,bool completed,object date) {
            var flow=Model.EditFlow(owner,kind);
            Model.Complete(flow,stage,completed,date);
            Model.SyncLegacy(owner,kind);
        }
        void RefreshDocumentGroup(Dictionary<string,object> owner,string kind,FlowLayoutPanel group) {
            BeginInvoke(new Action(()=> {
                if(refreshQueued||group.IsDisposed||IsDisposed)return;
                int offset=Math.Max(0,-editor.AutoScrollPosition.Y);
                var focused=FocusedControl(group);string tag=focused==null?null:focused.Tag as string;
                var previous=fields;building=true;
                editor.SuspendLayout();
                content.SuspendLayout();
                group.SuspendLayout();
                try {
                    foreach(Control c in group.Controls.Cast<Control>().ToArray())c.Dispose();
                    group.Controls.Clear();fields=group;DocumentFields(owner,kind,group);
                    FitControl(group,FieldWidth);
                }finally{
                    group.ResumeLayout(true);
                    content.ResumeLayout(true);
                    editor.ResumeLayout(true);
                    fields=previous;building=false;
                }
                if(tag!=null){var next=FindTag(group,tag);if(next!=null)next.Focus();}
                editor.AutoScrollPosition=new Point(0,offset);
            }));
        }
    }
}
