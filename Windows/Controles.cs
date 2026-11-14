// SPDX-License-Identifier: AGPL-3.0-only
using System;
using System.Runtime.InteropServices;
using System.Windows.Forms;

namespace PracticasFP {
    internal static class FieldWheel {
        internal const int Vertical = 0x020A;

        [DllImport("user32.dll", CharSet=CharSet.Auto)]
        static extern IntPtr SendMessage(IntPtr window,int message,IntPtr wParam,IntPtr lParam);

        internal static void Forward(Control field,ref Message message) {
            for(Control parent=field.Parent;parent!=null;parent=parent.Parent) {
                var scroll=parent as ScrollableControl;
                if(scroll==null||!scroll.AutoScroll)continue;
                message.Result=SendMessage(scroll.Handle,message.Msg,message.WParam,message.LParam);
                return;
            }
        }
    }

    internal sealed class NumberField : NumericUpDown {
        public NumberField() { InterceptArrowKeys=false; }

        protected override void OnLayout(LayoutEventArgs e) {
            base.OnLayout(e);
            foreach(Control child in Controls) {
                if(child is TextBox)child.Width=Math.Max(0,ClientSize.Width-child.Left-1);
                else if(child.Visible)child.Hide();
            }
        }

        protected override void OnMouseWheel(MouseEventArgs e) {
            var handled=e as HandledMouseEventArgs;
            if(handled!=null)handled.Handled=true;
        }
        protected override void WndProc(ref Message message) {
            if(message.Msg==FieldWheel.Vertical)FieldWheel.Forward(this,ref message);
            else base.WndProc(ref message);
        }
    }

    internal sealed class ChoiceField : ComboBox {
        protected override void WndProc(ref Message message) {
            if(message.Msg==FieldWheel.Vertical&&!DroppedDown)FieldWheel.Forward(this,ref message);
            else base.WndProc(ref message);
        }
    }

    internal sealed class DateFieldControl : DateTimePicker {
        protected override void WndProc(ref Message message) {
            if(message.Msg==FieldWheel.Vertical)FieldWheel.Forward(this,ref message);
            else base.WndProc(ref message);
        }
    }
}
