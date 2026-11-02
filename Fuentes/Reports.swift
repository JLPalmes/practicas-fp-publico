// SPDX-License-Identifier: AGPL-3.0-only
// Copyright (C) 2026 Juan Luis (JLPalmes)
import AppKit
import CoreText
import PDFKit
import UniformTypeIdentifiers

enum ReportPDF {
    static func data(for text: String) throws -> Data {
        let data = NSMutableData()
        guard let consumer = CGDataConsumer(data: data) else { throw CocoaError(.fileWriteUnknown) }
        var box = CGRect(x: 0, y: 0, width: 595.28, height: 841.89)
        guard let context = CGContext(consumer: consumer, mediaBox: &box, [kCGPDFContextTitle: "Informe de prácticas FP", kCGPDFContextCreator: "Prácticas FP"] as CFDictionary) else { throw CocoaError(.fileWriteUnknown) }
        let metadata = """
        <?xpacket begin="﻿" id="W5M0MpCehiHzreSzNTczkc9d"?><x:xmpmeta xmlns:x="adobe:ns:meta/"><rdf:RDF xmlns:rdf="http://www.w3.org/1999/02/22-rdf-syntax-ns#"><rdf:Description rdf:about="" xmlns:dc="http://purl.org/dc/elements/1.1/"><dc:language><rdf:Bag><rdf:li>es-ES</rdf:li></rdf:Bag></dc:language></rdf:Description></rdf:RDF></x:xmpmeta><?xpacket end="w"?>
        """
        context.addDocumentMetadata(Data(metadata.utf8) as CFData)
        let style = NSMutableParagraphStyle(); style.lineSpacing = 3; style.paragraphSpacing = 5
        let attributed = NSAttributedString(string: text, attributes: [.font: NSFont.systemFont(ofSize: 11), .foregroundColor: NSColor.black, .paragraphStyle: style, NSAttributedString.Key("NSLanguage"): "es-ES"])
        let framesetter = CTFramesetterCreateWithAttributedString(attributed)
        var location = 0; var page = 1
        repeat {
            context.beginPDFPage(nil)
            let path = CGPath(rect: CGRect(x: 42, y: 48, width: box.width - 84, height: box.height - 90), transform: nil)
            let frame = CTFramesetterCreateFrame(framesetter, CFRange(location: location, length: 0), path, nil)
            CTFrameDraw(frame, context)
            let footer = NSAttributedString(string: "Prácticas FP · Página \(page)", attributes: [.font: NSFont.systemFont(ofSize: 9), .foregroundColor: NSColor.gray])
            context.textPosition = CGPoint(x: 42, y: 24); CTLineDraw(CTLineCreateWithAttributedString(footer), context)
            context.endPDFPage()
            let visible = CTFrameGetVisibleStringRange(frame)
            guard visible.length > 0 || attributed.length == 0 else { throw CocoaError(.fileWriteUnknown) }
            location += visible.length; page += 1
        } while location < attributed.length
        context.closePDF()
        return data as Data
    }
}
@MainActor func savePDFReport(_ text: String) {
    let panel = NSSavePanel(); panel.allowedContentTypes = [.pdf]; panel.nameFieldStringValue = "Informe-PracticasFP.pdf"
    guard panel.runModal() == .OK, let url = panel.url else { return }
    do {
        try ReportPDF.data(for: text).write(to: url, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
        NSWorkspace.shared.activateFileViewerSelecting([url])
    } catch { let alert = NSAlert(); alert.messageText = "No se ha guardado el PDF"; alert.informativeText = error.localizedDescription; alert.runModal() }
}
@MainActor func printReport(_ text: String) {
    do {
        guard let document = PDFDocument(data: try ReportPDF.data(for: text)), let operation = document.printOperation(for: NSPrintInfo.shared, scalingMode: .pageScaleDownToFit, autoRotate: true) else { throw CocoaError(.fileReadCorruptFile) }
        operation.run()
    } catch { let alert = NSAlert(); alert.messageText = "No se puede preparar la impresión"; alert.informativeText = error.localizedDescription; alert.runModal() }
}
