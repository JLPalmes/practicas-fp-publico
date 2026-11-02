// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Collections.Generic;
using System.Drawing;
using System.Windows.Forms;
namespace PracticasFP {
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
            return (int)J.N(values,"width:"+section,420);
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
        readonly FlowLayoutPanel content=new FlowLayoutPanel();
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
                return Math.Max(240,editor.ClientSize.Width-44);
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
            content.Width=width+24;
            foreach(Control child in content.Controls) {
                var body=child as FlowLayoutPanel;
                if(body!=null) {
                    body.Width=width;
                    foreach(Control control in body.Controls) {
                        if(control is TextBox||control is ComboBox)control.Width=width;
                        if(control is Label||control is CheckBox)control.MaximumSize=new Size(width,0);
                    }
                }
                else if(child is Button)child.Width=width;
                else child.MaximumSize=new Size(width,0);
            }
            content.ResumeLayout(true);
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
                RebuildEditor();
                visibleKey=ViewKey;
                UpdatePinned();
                FitFields();
                if(same&&focusTag!=null) {
                    var target=FindTag(content,focusTag);
                    if(target!=null&&target.CanFocus) {
                        target.Focus();
                        var text=target as TextBox;
                        if(text!=null)text.SelectionStart=Math.Min(caret,text.TextLength);
                    }
                }
                editor.PerformLayout();
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
        void Title(string text) {
            int count;
            titleCounts.TryGetValue(text,out count);
            titleCounts[text]=count+1;
            string key=section+"|"+text+"|"+count;
            var body=new FlowLayoutPanel {
                Tag=key,FlowDirection=FlowDirection.TopDown,WrapContents=false,AutoSize=true,AutoSizeMode=AutoSizeMode.GrowAndShrink,Width=FieldWidth,Margin=new Padding(0,0,0,8)
            };
            bool open=preferences.Open(key);
            body.Visible=open;
            var toggle=new Button {
                Text=(open?"▾  ":"▸  ")+text,Width=FieldWidth,Height=36,TextAlign=ContentAlignment.MiddleLeft,FlatStyle=FlatStyle.Flat,BackColor=Color.FromArgb(226,236,235),Font=new Font(Font,FontStyle.Bold),Margin=new Padding(0,12,0,3)
            };
            toggle.Click+=(s,e)=> {
                RememberView();
                body.Visible=!body.Visible;
                toggle.Text=(body.Visible?"▾  ":"▸  ")+text;
                preferences.SetOpen(key,body.Visible);
                content.PerformLayout();
            };
            content.Controls.Add(toggle);
            content.Controls.Add(body);
            fields=body;
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
                try {
                    group.SuspendLayout();
                    foreach(Control c in group.Controls.Cast<Control>().ToArray())c.Dispose();
                    group.Controls.Clear();fields=group;DocumentFields(owner,kind,group);
                    group.ResumeLayout(true);FitFields();
                    if(tag!=null){var next=FindTag(group,tag);if(next!=null)next.Focus();}
                    editor.AutoScrollPosition=new Point(0,offset);
                }finally{fields=previous;building=false;}
            }));
        }
    }
}
