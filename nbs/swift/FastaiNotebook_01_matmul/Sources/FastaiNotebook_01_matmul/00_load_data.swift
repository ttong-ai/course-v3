/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: 00_load_data.ipynb

*/



precedencegroup ExponentiationPrecedence {
    associativity: right
    higherThan: MultiplicationPrecedence
}
infix operator ** : ExponentiationPrecedence

precedencegroup CompositionPrecedence { associativity: left }
infix operator >| : CompositionPrecedence

import Foundation
import Just
import Path

public extension String {
    @discardableResult
    func shell(_ args: String...) -> String
    {
        let (task,pipe) = (Process(),Pipe())
        task.executableURL = URL(fileURLWithPath: self)
        (task.arguments,task.standardOutput) = (args,pipe)
        do    { try task.run() }
        catch { print("Unexpected error: \(error).") }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: String.Encoding.utf8) ?? ""
    }
}

public func downloadFile(_ url: String, dest: String? = nil, force: Bool = false) {
    let dest_name = dest ?? (Path.cwd/url.split(separator: "/").last!).string
    let url_dest = URL(fileURLWithPath: (dest ?? (Path.cwd/url.split(separator: "/").last!).string))
    if !force && Path(dest_name)!.exists { return }

    print("Downloading \(url)...")

    if let cts = Just.get(url).content {
        do    {try cts.write(to: URL(fileURLWithPath:dest_name))}
        catch {print("Can't write to \(url_dest).\n\(error)")}
    } else {
        print("Can't reach \(url)")
    }
}

import TensorFlow

protocol ConvertibleFromByte: TensorFlowScalar {
    init(_ d:UInt8)
}

extension Float : ConvertibleFromByte {}
extension Int32 : ConvertibleFromByte {}

extension Data {
    func asTensor<T:ConvertibleFromByte>() -> Tensor<T> {
        return Tensor(map(T.init))
    }
}

func loadMNIST<T: ConvertibleFromByte>
            (training: Bool, labels: Bool, path: Path, flat: Bool) -> Tensor<T> {
    let split = training ? "train" : "t10k"
    let kind = labels ? "labels" : "images"
    let batch = training ? 60000 : 10000
    let shape: TensorShape = labels ? [batch] : (flat ? [batch, 784] : [batch, 28, 28])
    let dropK = labels ? 8 : 16
    let baseUrl = "https://storage.googleapis.com/cvdf-datasets/mnist/"
    let fname = split + "-" + kind + "-idx\(labels ? 1 : 3)-ubyte"
    let file = path/fname
    if !file.exists {
        downloadFile("\(baseUrl)\(fname).gz", dest:(path/"\(fname).gz").string)
        "/bin/gunzip".shell("-fq", (path/"\(fname).gz").string)
    }
    let data = try! Data(contentsOf: URL(fileURLWithPath: file.string)).dropFirst(dropK)
    if labels { return data.asTensor() }
    else      { return data.asTensor().reshaped(to: shape)}
}

public func loadMNIST(path:Path, flat:Bool = false)
        -> (Tensor<Float>, Tensor<Int32>, Tensor<Float>, Tensor<Int32>) {
    try! path.mkdir(.p)
    return (
        loadMNIST(training: true,  labels: false, path: path, flat: flat) / 255.0,
        loadMNIST(training: true,  labels: true,  path: path, flat: flat),
        loadMNIST(training: false, labels: false, path: path, flat: flat) / 255.0,
        loadMNIST(training: false, labels: true,  path: path, flat: flat)
    )
}

public let mnistPath = Path.home/".fastai"/"data"/"mnist_tst"

import Dispatch

// ⏰Time how long it takes to run the specified function, optionally taking
// the average across a number of repetitions.
public func time(repeating: Int = 1, _ f: () -> ()) {
    guard repeating > 0 else { return }
    
    // Warmup
    if repeating > 1 { f() }
    
    var times = [Double]()
    for _ in 1...repeating {
        let start = DispatchTime.now()
        f()
        let end = DispatchTime.now()
        let nanoseconds = Double(end.uptimeNanoseconds - start.uptimeNanoseconds)
        let milliseconds = nanoseconds / 1e6
        times.append(milliseconds)
    }
    print("average: \(times.reduce(0.0, +)/Double(times.count)) ms,   " +
          "min: \(times.reduce(times[0], min)) ms,   " +
          "max: \(times.reduce(times[0], max)) ms")
}

public extension String {
    func findFirst(pat: String) -> Range<String.Index>? {
        return range(of: pat, options: .regularExpression)
    }
    func hasMatch(pat: String) -> Bool {
        return findFirst(pat:pat) != nil
    }
}

public func notebookToScript(fname: Path){
    let newname = fname.basename(dropExtension: true)+".swift"
    let url = fname.parent/"FastaiNotebooks/Sources/FastaiNotebooks"/newname
    do {
        let data = try Data(contentsOf: fname.url)
        let jsonData = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as! [String: Any]
        let cells = jsonData["cells"] as! [[String:Any]]
        var module = """
/*
THIS FILE WAS AUTOGENERATED! DO NOT EDIT!
file to edit: \(fname.lastPathComponent)

*/
        
"""
        for cell in cells {
            if let source = cell["source"] as? [String], !source.isEmpty, 
                   source[0].hasMatch(pat: #"^\s*//\s*export\s*$"#) {
                module.append("\n" + source[1...].joined() + "\n")
            }
        }
        try module.write(to: url, encoding: .utf8)
    } catch {
        print("Can't read the content of \(fname)")
    }
}

public func exportNotebooks(_ path: Path) {
    for entry in try! path.ls()
    where entry.kind == Entry.Kind.file && 
          entry.path.basename().hasMatch(pat: #"^\d*_.*ipynb$"#) {
        print("Converting \(entry)")
        notebookToScript(fname: entry.path)
    }
}
