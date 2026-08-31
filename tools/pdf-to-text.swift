// Extract the text of a PDF page by page with PDFKit (macOS). Usage: swift tools/pdf-to-text.swift in.pdf out.txt
import Foundation
import PDFKit
let args = CommandLine.arguments
guard args.count == 3, let doc = PDFDocument(url: URL(fileURLWithPath: args[1])) else { print("usage: swift pdf-to-text.swift in.pdf out.txt"); exit(1) }
var out = ""
for i in 0..<doc.pageCount {
    out += "===== page \(i + 1) =====\n"
    out += (doc.page(at: i)?.string ?? "") + "\n"
}
try! out.write(toFile: args[2], atomically: true, encoding: .utf8)
print("\(doc.pageCount) pages -> \(args[2])")
