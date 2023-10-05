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
    
    let session = WCSession.default
    private var tennisSessions = [TennisSession]() {
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
    
    private func exportAccelerometerData() {
        var result = ""
        for session in tennisSessions {
            if !session.sessionData.accelerometerSnapshots.isEmpty {
                result.append("\n\(session.createAcceletometerDataCSV(includeHeader: false))")
            }
        }
        
        shareStringAsFile(string: result, filename: "tennis-acceleration-\(Date()).csv")
    }
    
    private func exportGyroscopeData() {
        var result = ""
        for session in tennisSessions {
            if !session.sessionData.gyroscopeSnapshots.isEmpty {
                result.append("\n\(session.createGyroscopeDataCSV(includeHeader: false))")
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
    
    @objc func clearAll() {
        let alert = UIAlertController(title: "Clear all recent data", message: nil, preferredStyle: .actionSheet)
        
        alert.addAction(UIAlertAction(title: "Clear", style: .destructive , handler:{ [weak self] _ in
            self?.tennisSessions = []
        }))
        
        alert.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler:nil))
        
        self.present(alert, animated: true, completion: nil)
    }
}

extension ViewController: UITableViewDataSource, UITableViewDelegate {
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        tennisSessions.count
    }
    
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = UITableViewCell(style: .default, reuseIdentifier: "TennisSessionCell")
        let session = tennisSessions[indexPath.row]
        
        let title: String
        if session.sessionData.accelerometerSnapshots.count > 0 && session.sessionData.gyroscopeSnapshots.isEmpty {
            title = "Acceletometer at \(String(describing: session.dateStarted))"
        } else if session.sessionData.gyroscopeSnapshots.count > 0 && session.sessionData.accelerometerSnapshots.isEmpty {
            title = "Rotation at \(String(describing: session.dateStarted))"
        } else {
            title = "Mixed data at \(String(describing: session.dateStarted))"
        }
        cell.textLabel?.text = title
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        // TODO: present chart
    }
    
    private func getDocumentsDirectory() -> String {
        let paths = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)
        let documentsDirectory = paths[0]
        return documentsDirectory
    }
}

extension ViewController: WCSessionDelegate {
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if let error {
            print("session activation failed with error: \(error.localizedDescription)")
        }
    }
  
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        guard let data: Data = message["data"] as? Data else { return }
        let tennisSession = TennisSession.decodeIt(data)
        DispatchQueue.main.async {
            self.tennisSessions.append(tennisSession)
        }
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any], replyHandler: @escaping ([String : Any]) -> Void) {
        guard let data: Data = message["data"] as? Data else { return }
        let tennisSession = TennisSession.decodeIt(data)
        DispatchQueue.main.async {
            self.tennisSessions.append(tennisSession)
        }
    }
        
    func sessionDidBecomeInactive(_ session: WCSession) {
        session.activate()
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }
}
