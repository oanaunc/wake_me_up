import SwiftUI
import UIKit

struct JournalShareSheet:UIViewControllerRepresentable {
    var url:URL
    func makeUIViewController(context:Context)->UIActivityViewController {UIActivityViewController(activityItems:[url],applicationActivities:nil)}
    func updateUIViewController(_ controller:UIActivityViewController,context:Context) {}
}
