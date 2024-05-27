import Cocoa
import SwiftyJSON

var greeting = "Hello, playground"

func launchTask() {
    let scriptPath = Bundle.main.path(forResource: "SimctlList", ofType: "sh")
    let scriptTask = Process()
    let outputPipe = Pipe()
    
    scriptTask.standardOutput = outputPipe
    
    scriptTask.launchPath = "/bin/sh"
    scriptTask.arguments = [scriptPath!]
    scriptTask.launch()
    
    let fileHandle = outputPipe.fileHandleForReading
    let data = fileHandle.readDataToEndOfFile()
    
    guard let json = try? JSON(data: data) else { return }
    let devices = json["devices"].dictionaryValue
        .compactMapValues({ $0.arrayValue.count > 0 ? $0 : nil })
    
    
    for (key, jsonArray) in devices {
        for device in jsonArray.arrayValue {
            print(device)
        }
    }
    
}

launchTask()
