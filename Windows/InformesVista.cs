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
    public partial class MainForm {
        void Report() {
            var menu=new ContextMenuStrip();
            if((section=="students"||section=="companies")&&Current()!=null)
                menu.Items.Add("Informe de la ficha seleccionada",null,(s,e)=>ShowReport(Model.Report(store.Db,Current(),section)));
            menu.Items.Add("Informe del curso completo",null,(s,e)=>ShowReport(Model.Report(store.Db,null,section)));
            menu.Closed+=(s,e)=>BeginInvoke(new Action(()=>menu.Dispose()));
            menu.Show(Cursor.Position);
        }
        void ShowReport(string report) {
            using(var f=new Form {
                Text="Informe · Prácticas FP",Size=new Size(850,750),StartPosition=FormStartPosition.CenterParent
            }) {
                var t=new TextBox {
                    Multiline=true,ReadOnly=true,Text=report,Dock=DockStyle.Fill,ScrollBars=ScrollBars.Both,Font=new Font("Consolas",10),WordWrap=false
                };
                var bar=new FlowLayoutPanel {
                    Dock=DockStyle.Bottom,Height=45
                };
                f.Controls.Add(t);
                f.Controls.Add(bar);
                AddButton(bar,"Guardar texto…",()=> {
                    using(var d=new SaveFileDialog {
                        Filter="Texto UTF-8|*.txt",FileName="Informe-PracticasFP.txt"
                    })if(d.ShowDialog(f)==DialogResult.OK)J.Atomic(d.FileName,report);
                });
                AddButton(bar,"Imprimir / Guardar como PDF…",()=>Print(report,f));
                f.ShowDialog(this);
            }
        }
        void Print(string text,Form parent) {
            using(var doc=new PrintDocument()) {
                doc.DocumentName="Informe-PracticasFP";
                doc.DefaultPageSettings.PaperSize=new PaperSize("A4",827,1169);
                doc.DefaultPageSettings.Margins=new Margins(55,55,55,55);
                int offset=0;
                using(var font=new Font("Segoe UI",10)) {
                    doc.BeginPrint+=(s,e)=>offset=0;
                    doc.PrintPage+=(s,e)=> {
                        int chars,lines;
                        var area=e.MarginBounds;
                        using(var format=new StringFormat(StringFormat.GenericTypographic)) {
                            format.FormatFlags=StringFormatFlags.LineLimit;
                            e.Graphics.MeasureString(text.Substring(offset),font,area.Size,format,out chars,out lines);
                            if(chars==0)throw new Exception("No cabe texto en el área imprimible.");
                            e.Graphics.DrawString(text.Substring(offset,chars),font,Brushes.Black,area,format);
                            offset+=chars;
                            e.HasMorePages=offset<text.Length;
                        }
                    };
                    using(var dialog=new PrintDialog {
                        Document=doc,UseEXDialog=true,AllowSomePages=false
                    })if(dialog.ShowDialog(parent)==DialogResult.OK)doc.Print();
                }
            }
        }
    }
}
