// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
using System;
using System.IO;
using System.Linq;
using System.Text;
using System.Collections.Generic;
using System.Globalization;
using System.Xml.Linq;
using System.IO.Compression;
namespace PracticasFP {
    public class Sheet {
        public string Name;
        public List<string[]> Rows=new List<string[]>();
        public HashSet<string> Issues=new HashSet<string>();
    }
    public static class Importer {
        public static readonly string[] Fields= {
            "","name","surnames","surname2","dni","nuss","email","phone","group","preferredType","preferredZone","preferences","notes"
        };
        public static readonly string[] Titles= {
            "No importar","Nombre","Apellidos","Segundo apellido","DNI / NIE","NUSS","Email","Teléfono","Grupo","Tipo de empresa","Zona","Preferencias","Observaciones"
        };
        public static string Key(string s) {
            var b=new StringBuilder();
            foreach(char ch in s.ToLowerInvariant().Normalize(NormalizationForm.FormD))if(CharUnicodeInfo.GetUnicodeCategory(ch)!=UnicodeCategory.NonSpacingMark)b.Append(char.IsLetterOrDigit(ch)?ch:' ');
            return string.Join(" ",b.ToString().Split(new[] {
                ' '
            },StringSplitOptions.RemoveEmptyEntries));
        }
        public static int Guess(string s) {
            string k=Key(s);
            string[][] aliases= {
                new string[0],new[] {
                    "nombre","nombre completo","nombre y apellidos","alumna","alumno","alumnado"
                },new[] {
                    "apellidos","primer apellido","apellido1","apellido 1"
                },new[] {
                    "segundo apellido","apellido2","apellido 2"
                },new[] {
                    "dni","nie","dni nie","documento","nif"
                },new[] {
                    "nuss","naf","numero seguridad social","seguridad social","n ss"
                },new[] {
                    "email","e mail","correo","correo electronico"
                },new[] {
                    "telefono","movil","telefono movil"
                },new[] {
                    "grupo","curso"
                },new[] {
                    "tipo de empresa","tipo de empresa preferido","empresa preferida"
                },new[] {
                    "zona","zona preferida"
                },new[] {
                    "preferencias","detalle de preferencias"
                },new[] {
                    "observaciones","notas"
                }
            };
            for(int i=1;
            i<aliases.Length;
            i++)if(aliases[i].Contains(k))return i;
            return 0;
        }
        public static HashSet<string> Identity(object s) {
            var keys=new HashSet<string>();
            foreach(string field in new[] {
                "dni","nuss","email"
            }) {
                string v=new string(J.S(s,field).ToLowerInvariant().Where(c=>!char.IsWhiteSpace(c)&&c!='-').ToArray());
                if(v!="")keys.Add(field+":"+v);
            }
            string name=string.Join(" ",Key(J.S(s,"name")).Split(' ').OrderBy(x=>x));
            if(name.Trim()!="")keys.Add("name:"+name);
            return keys;
        }
        public static List<Sheet> Read(string path) {
            if(new FileInfo(path).Length>20*1024*1024)throw new Exception("El archivo supera los 20 MB.");
            if(Path.GetExtension(path).ToLowerInvariant()==".xlsx")return Excel(path);
            byte[] bytes=File.ReadAllBytes(path);
            string text;
            try {
                if(bytes.Length>=2&&(bytes[0]==255&&bytes[1]==254||bytes[0]==254&&bytes[1]==255))text=(bytes[0]==255?Encoding.Unicode:Encoding.BigEndianUnicode).GetString(bytes,2,bytes.Length-2);
                else text=new UTF8Encoding(false,true).GetString(bytes).TrimStart('\uFEFF');
            }
            catch(DecoderFallbackException) {
                text=Encoding.GetEncoding(1252).GetString(bytes);
            }
            return new List<Sheet> {
                Csv(text)
            };
        }
        public static Sheet Csv(string text) {
            string first=text.Split('\n')[0];
            char separator=new[] {
                ';',',','\t'
            }
            .OrderByDescending(c=>first.Count(x=>x==c)).First();
            var sheet=new Sheet {
                Name="CSV"
            };
            var row=new List<string>();
            var cell=new StringBuilder();
            bool quoted=false;
            for(int i=0;
            i<text.Length;
            i++) {
                char c=text[i];
                if(c=='"') {
                    if(quoted&&i+1<text.Length&&text[i+1]=='"') {
                        cell.Append('"');
                        i++;
                    }
                    else quoted=!quoted;
                }
                else if(!quoted&&(c==separator||c=='\r'||c=='\n')) {
                    row.Add(cell.ToString());
                    cell.Clear();
                    if(c!=separator) {
                        if(c=='\r'&&i+1<text.Length&&text[i+1]=='\n')i++;
                        sheet.Rows.Add(row.ToArray());
                        row.Clear();
                    }
                }
                else cell.Append(c);
                if(row.Count>256||sheet.Rows.Count>10000)throw new Exception("Límite: 10.000 filas y 256 columnas.");
            }
            if(quoted)throw new Exception("CSV con comillas sin cerrar.");
            if(cell.Length>0||row.Count>0) {
                row.Add(cell.ToString());
                sheet.Rows.Add(row.ToArray());
            }
            Check(sheet);
            return sheet;
        }
        static void Check(Sheet s) {
            if(s.Rows.Count>10000||s.Rows.Any(x=>x.Length>256))throw new Exception("Límite: 10.000 filas y 256 columnas.");
        }
        static XDocument Xml(ZipArchive zip,string path) {
            var entry=zip.GetEntry(path);
            if(entry==null)throw new Exception("Falta una parte del Excel: "+path);
            if(entry.Length>40*1024*1024)throw new Exception("Contenido Excel demasiado grande.");
            using(var s=entry.Open())using(var reader=System.Xml.XmlReader.Create(s,new System.Xml.XmlReaderSettings {
                DtdProcessing=System.Xml.DtdProcessing.Prohibit,XmlResolver=null,MaxCharactersInDocument=40*1024*1024
            }))return XDocument.Load(reader);
        }
        static List<Sheet> Excel(string path) {
            using(var zip=ZipFile.OpenRead(path)) {
                if(zip.Entries.Sum(e=>e.Length)>80*1024*1024)throw new Exception("Contenido Excel demasiado grande.");
                XNamespace ns="http://schemas.openxmlformats.org/spreadsheetml/2006/main", rel="http://schemas.openxmlformats.org/officeDocument/2006/relationships";
                var shared=new List<string>();
                if(zip.GetEntry("xl/sharedStrings.xml")!=null)shared=Xml(zip,"xl/sharedStrings.xml").Descendants(ns+"si").Select(e=>string.Concat(e.Descendants(ns+"t").Select(t=>t.Value))).ToList();
                var styles=new List<int>();
                var formats=new Dictionary<int,string>();
                if(zip.GetEntry("xl/styles.xml")!=null) {
                    var st=Xml(zip,"xl/styles.xml");
                    foreach(var f in st.Descendants(ns+"numFmt"))formats[(int)f.Attribute("numFmtId")]=(string)f.Attribute("formatCode");
                    var xf=st.Descendants(ns+"cellXfs").FirstOrDefault();
                    if(xf!=null)styles=xf.Elements().Select(e=>(int?)e.Attribute("numFmtId")??0).ToList();
                }
                var relationships=Xml(zip,"xl/_rels/workbook.xml.rels").Root.Elements().ToDictionary(e=>(string)e.Attribute("Id"),e=>(string)e.Attribute("Target"));
                var result=new List<Sheet>();
                foreach(var info in Xml(zip,"xl/workbook.xml").Descendants(ns+"sheet")) {
                    string target=relationships[(string)info.Attribute(rel+"id")].Replace('\\','/');
                    string part=target.StartsWith("/")?target.TrimStart('/'):"xl/"+target;
                    var sheet=new Sheet {
                        Name=(string)info.Attribute("name")
                    };
                    var xml=Xml(zip,part);
                    foreach(var r in xml.Descendants(ns+"row")) {
                        var cells=new Dictionary<int,string>();
                        int rowIndex=sheet.Rows.Count;
                        foreach(var c in r.Elements(ns+"c")) {
                            string address=(string)c.Attribute("r")??"A1";
                            int col=0;
                            foreach(char ch in address.TakeWhile(char.IsLetter))col=col*26+(char.ToUpperInvariant(ch)-'A'+1);
                            col--;
                            if(col<0||col>=256)throw new Exception("Excel supera las 256 columnas.");
                            string type=(string)c.Attribute("t"),value=(string)c.Element(ns+"v")??"";
                            bool issue=c.Element(ns+"f")!=null||type=="e";
                            if(type=="s") {
                                int at;
                                if(!int.TryParse(value,out at)||at<0||at>=shared.Count)throw new Exception("Texto compartido de Excel inválido.");
                                value=shared[at];
                            }
                            else if(type=="inlineStr")value=string.Concat(c.Descendants(ns+"t").Select(e=>e.Value));
                            else if(type==null||type=="n") {
                                string digits=new string(value.Where(char.IsDigit).ToArray()).TrimStart('0');
                                if(digits.Length>15)issue=true;
                                int style=(int?)c.Attribute("s")??0;
                                string format;
                                if(style<styles.Count&&formats.TryGetValue(styles[style],out format)&&format.Length>0&&format.All(ch=>ch=='0')) {
                                    decimal n;
                                    if(decimal.TryParse(value,NumberStyles.Float,CultureInfo.InvariantCulture,out n)&&n>=0&&n==decimal.Truncate(n))value=n.ToString(new string('0',format.Length),CultureInfo.InvariantCulture);
                                }
                            }
                            cells[col]=value;
                            if(issue)sheet.Issues.Add(rowIndex+":"+col);
                        }
                        int width=cells.Count==0?0:cells.Keys.Max()+1;
                        var values=new string[width];
                        for(int i=0;
                        i<width;
                        i++)values[i]=cells.ContainsKey(i)?cells[i]:"";
                        sheet.Rows.Add(values);
                        if(sheet.Rows.Count>10000)throw new Exception("Excel supera las 10.000 filas.");
                    }
                    Check(sheet);
                    result.Add(sheet);
                }
                return result;
            }
        }
        public static Dictionary<string,object> Student(Sheet sheet,int row,int[] mapping,out string issue) {
            var s=Model.Student();
            issue=null;
            var parts=new string[3];
            for(int c=0;
            c<mapping.Length;
            c++) {
                int field=mapping[c];
                if(field==0||c>=sheet.Rows[row].Length)continue;
                string value=(sheet.Rows[row][c]??"").Trim();
                if(sheet.Issues.Contains(row+":"+c))issue="Fórmula, error o número de más de 15 cifras: revisar en Excel.";
                if(field>=1&&field<=3)parts[field-1]=value;
                else s[Fields[field]]=value;
            }
            s["name"]=string.Join(" ",parts.Where(x=>!string.IsNullOrWhiteSpace(x)));
            if(J.S(s,"name")=="")issue="Falta el nombre.";
            return s;
        }
    }
}
