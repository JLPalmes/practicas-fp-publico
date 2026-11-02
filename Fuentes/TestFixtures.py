# SPDX-License-Identifier: AGPL-3.0-only
# Copyright (C) 2026 Juan Luis (JLPalmes)
from pathlib import Path
from zipfile import ZipFile, ZIP_DEFLATED
from html import escape
import sys
root = Path(sys.argv[1])
root.mkdir(exist_ok=True)
(root/'lista.csv').write_text('\ufeffNombre;Apellidos;DNI;NUSS;Email;Teléfono;Grupo;Observaciones\r\nAna;Pérez;00123456Z;001234567890;ana@example.test;600123456;2A;"Dice ""sí""; zona norte\nPreferencia de mañana"\r\n', encoding='utf-8')
(root/'comma.csv').write_text('Nombre,DNI\n"María, López",00000001R\n', encoding='utf-8')
(root/'legacy.csv').write_bytes('Nombre;Apellidos\nMaría;Muñoz\n'.encode('cp1252'))
(root/'utf16.csv').write_text('Nombre\tDNI\nElena\t00000123X\n', encoding='utf-16')
def make(path, values):
    with ZipFile(path,'w',ZIP_DEFLATED) as z:
        for k,v in values.items(): z.writestr(k,v)
xml = {
'[Content_Types].xml':'<Types xmlns="http://schemas.openxmlformats.org/package/2006/content-types"><Default Extension="xml" ContentType="application/xml"/></Types>',
'xl/workbook.xml':'<workbook xmlns="http://schemas.openxmlformats.org/spreadsheetml/2006/main" xmlns:r="http://schemas.openxmlformats.org/officeDocument/2006/relationships"><sheets><sheet name="Instrucciones" sheetId="1" r:id="rId1"/><sheet name="Alumnas" sheetId="2" r:id="rId2"/></sheets></workbook>',
'xl/_rels/workbook.xml.rels':'<Relationships xmlns="http://schemas.openxmlformats.org/package/2006/relationships"><Relationship Id="rId1" Target="worksheets/sheet1.xml"/><Relationship Id="rId2" Target="/xl/worksheets/sheet2.xml"/></Relationships>',
'xl/sharedStrings.xml':'<sst><si><t>Nombre</t></si><si><r><t>María </t></r><r><t>Muñoz</t></r></si></sst>',
'xl/styles.xml':'<styleSheet><numFmts><numFmt numFmtId="164" formatCode="000000000000"/></numFmts><cellXfs><xf numFmtId="0"/><xf numFmtId="164"/></cellXfs></styleSheet>',
'xl/worksheets/sheet1.xml':'<worksheet><sheetData><row r="1"><c r="A1" t="inlineStr"><is><t>Selecciona la hoja Alumnas</t></is></c></row></sheetData></worksheet>',
'xl/worksheets/sheet2.xml':'''<worksheet><sheetData>
<row r="1"><c r="A1" t="s"><v>0</v></c><c r="B1" t="inlineStr"><is><t>NUSS</t></is></c><c r="C1" t="inlineStr"><is><t>Email</t></is></c></row>
<row r="2"><c r="A2" t="s"><v>1</v></c><c r="B2" s="1"><v>1234567890</v></c><c r="C2" t="inlineStr"><is><t>maria@example.test</t></is></c></row>
<row r="4"><c r="A4" t="inlineStr"><is><t>Elena</t></is></c><c r="C4" t="inlineStr"><is><t>elena@example.test</t></is></c></row>
<row r="5"><c r="A5" t="str"><f>CONCAT("Nombre")</f><v>Resultado</v></c></row>
<row r="6"><c r="A6" t="inlineStr"><is><t>Número largo</t></is></c><c r="B6"><v>1234567890123456</v></c></row>
</sheetData></worksheet>'''
}
make(root/'lista.xlsx', xml)
bad = dict(xml); bad['xl/_rels/workbook.xml.rels'] = '<Relationships><Relationship Id="rId1" Target="../outside.xml"/></Relationships>'
make(root/'bad.xlsx', bad)
(root/'broken.xlsx').write_text('No es un zip')
