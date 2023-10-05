//
//  ViewController.swift
//  TennisMotionAnalyzer
//
//  Created by Pavel Shadrin on 13.08.2023.
//

import UIKit
import WatchConnectivity

class ViewController: UIViewController {
    @IBOutlet weak var tableView: UITableView!
    
    private let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .medium
        return formatter
    }()
    
    let session = WCSession.default
    private var tennisDataChunks = [TennisDataChunk]() {
        didSet {
            tableView.reloadData()
        }
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()

        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
        
        tableView.dataSource = self
        tableView.delegate = self
        
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Export", style: .done, target: self, action: #selector(exportAll))
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Clear", style: .done, target: self, action: #selector(clearAll))
    }
    
    @objc func exportAll() {
        let alert = UIAlertController(title: "Export aggregated data", message: "Select which king of data to share", preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Accelerometer", style: .default , handler:{ [weak self] _ in
            self?.exportAccelerometerData()
        }))
        
        alert.addAction(UIAlertAction(title: "Rotation", style: .default , handler:{ [weak self] _ in
            self?.exportGyroscopeData()
        }))
        
        alert.addAction(UIAlertAction(title: "Dismiss", style: .cancel, handler:nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    @objc func clearAll() {
        let alert = UIAlertController(title: "Clear all recent data", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive , handler:{ [weak self] _ in
            self?.tennisDataChunks = []
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
        
        self.present(alert, animated: true, completion: nil)
    }
    
    // MARK: - Private
    
    private func exportAccelerometerData() {
        var result = ""
        for chunk in tennisDataChunks {
            if !chunk.data.accelerometerSnapshots.isEmpty {
                result.append("\n\(chunk.createAcceletometerDataCSV())")
            }
        }
        
        shareStringAsFile(string: result, filename: "tennis-acceleration-\(Date()).csv")
    }
    
    private func exportGyroscopeData() {
        var result = ""
        for chunk in tennisDataChunks {
            if !chunk.data.gyroscopeSnapshots.isEmpty {
                result.append("\n\(chunk.createGyroscopeDataCSV())")
            }
        }
        
        shareStringAsFile(string: result, filename: "tennis-gyroscope-\(Date()).csv")
    }
    
    private func shareStringAsFile(string: String, filename: String) {
        if string.isEmpty {
            return
        }
        
        do {
            let filename = "\(self.getDocumentsDirectory())/\(filename)"
            let fileURL = URL(fileURLWithPath: filename)
            try string.write(to: fileURL, atomically: true, encoding: .utf8)
            
            let vc = UIActivityViewController(activityItems: [fileURL], applicationActivities: [])
            
            self.present(vc, animated: true)
        } catch {
            print("cannot write file")
        }
    }
    
    private func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tennisDataChunks.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "TennisSessionCell")
        let chunk = tennisDataChunks[indexPath.row]
        
        let title: String
        if !chunk.data.accelerometerSnapshots.isEmpty && chunk.data.gyroscopeSnapshots.isEmpty {
            title = "Acceletometer at \(dateFormatter.string(from: chunk.date))"
        } else if !chunk.data.gyroscopeSnapshots.isEmpty && chunk.data.accelerometerSnapshots.isEmpty {
            title = "Rotation at \(dateFormatter.string(from: chunk.date))"
        } else {
            title = "Mixed data at \(dateFormatter.string(from: chunk.date))"
        }
        cell.textLabel?.text = title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: present chart
    }
}

extension ViewController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("session activation failed with error: \(error.localizedDescription)")
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let data: Data = message["data"] as? Data else { return }
        let chunk = TennisDataChunk.decodeIt(data)
        DispatchQueue.main.async {
            self.tennisDataChunks.append(chunk)
        }
    }
        
    func sessionDidBecomeInactive(_ session: WCSession) {
        session.activate()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
