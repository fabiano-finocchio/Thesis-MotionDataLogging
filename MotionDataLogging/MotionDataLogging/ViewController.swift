//
//  ViewController.swift
//  MotionDataLogging
//
//  Created by Fabiano Finocchio on 17/05/2019.
//  Copyright © 2019 Fabiano Finocchio. All rights reserved.
//

import UIKit
import CoreMotion
import CoreLocation
import WatchConnectivity
import HealthKit

class ViewController: UIViewController {
    
    //    initializing manager of functions
    public var motion = CMMotionManager()
    public let locationManager = CLLocationManager()
    
    // initializing variables for data logging and saving
    private var sessionData = SessionData()
    private var sessionCounterPhone = 0
    private var sessionCounterWatch = 0
//    initializing folder for saving documents
    var appFolderURL: URL?

    
    //  initializing session for WatchOs communication
    var session: WCSession!
    
//    gui elements
    @IBOutlet weak var txtPhone: UILabel!
    @IBOutlet weak var txtWatch: UILabel!
    @IBOutlet weak var txtLabel: UITextField!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view.
        if let documentsDirectory = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first {
            appFolderURL = documentsDirectory.appendingPathComponent("WatchOSData")
            if !FileManager.default.fileExists(atPath: appFolderURL!.path) {
                do {
                    try FileManager.default.createDirectory(atPath: appFolderURL!.path, withIntermediateDirectories: true, attributes: nil)
                    print ("folder created")
                } catch {
                    print(error.localizedDescription)
                }
            }
        }
//        authorize health kit to record heart beat
        autorizeHealthKit { (authorized, error) in
            
            guard authorized else {
                
                let baseMessage = "HealthKit Authorization Failed"
                
                if let error = error {
                    print("\(baseMessage). Reason: \(error.localizedDescription)")
                } else {
                    print(baseMessage)
                }
                
                return
            }
            
            print("HealthKit Successfully Authorized.")
        }
        
        autorizeLocation()
//        establish the connection
        if WCSession.isSupported() {
            self.session = WCSession.default
            session.delegate = self
            session.activate()
            txtWatch.text?.removeAll()
            txtWatch.text?.append("Session Activated")}
        else {
            self.txtWatch.text?.removeAll()
            self.txtWatch.text?.append("failed")}
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        txtLabel.resignFirstResponder()
        if session.isPaired && session.isReachable{
            session.sendMessage(["label":txtLabel.text!], replyHandler: nil, errorHandler: nil)
        } else {
            txtWatch.text!.removeAll()
            txtWatch.text!.append("impossible to send label")
        }
    }
    
    @IBAction func onStartPressed(_ sender: UIButton) {
        txtPhone.text?.removeAll()
        txtPhone.text?.append("Start logging data...")
        self.sessionData.setStartAcquisition()
        self.myGyroStart()
        self.myDevMotStart()
        self.startUpdatingLocation()

    }
    
    
    @IBAction func onStopPressed(_ sender: UIButton) {
        txtPhone.text?.removeAll()
        txtPhone.text?.append("Saving data...")
        self.myGPSstop()
        self.myGyroStop()
        self.myDevMotStop()
        self.sessionData.setStopAcquisition()
        self.sessionData.setDevice(device: "iPhone")
        self.sessionData.setLabel(label: txtLabel.text!)
        self.sessionData.saveData(number: sessionCounterPhone)

        let documentName = sessionData.getDocumentName(number: sessionCounterPhone)
        txtPhone.text?.removeAll()
        
        if Storage.fileExists(documentName, in: .documents){
            txtPhone.text?.append("Data saved on iPhone")
            self.sessionData.clearAll()
            self.sessionCounterPhone+=1
        }
        else {
            txtPhone.text?.append("Something wrong on saving")
            self.sessionData.clearAll()
            self.sessionCounterPhone+=1
        }
        
        
    }
    
    
    func myGyroStart(){
        print ("Start gyroscope")
        if motion.isGyroAvailable {
            motion.gyroUpdateInterval = 1/50
            motion.startGyroUpdates(to: OperationQueue.current!){
                (data, error) in
                print(data as Any)
                if self.motion.isGyroActive{
                    if let trueData = data {
                        
                        self.reloadInputViews()
                        let x = trueData.rotationRate.x
                        let y = trueData.rotationRate.y
                        let z = trueData.rotationRate.z
                        
                        self.sessionData.appendGyroValues(x: x, y: y, z: z)
                    }
                }
            }
        }
        
    }
    
    func myGyroStop (){
        print ("Stop gyroscope")
        motion.stopGyroUpdates()
        
    }
    
    func myDevMotStart(){
        print ("Start Device Motion")
        if self.motion.isDeviceMotionAvailable{
            motion.deviceMotionUpdateInterval = 1/50
            motion.startDeviceMotionUpdates(to: OperationQueue.current!){
                (data,error) in print (data as Any)
                if self.motion.isDeviceMotionActive{
                    if let trueData = data {
                        self.reloadInputViews()
                        
                        let pitch = trueData.attitude.pitch
                        let yaw = trueData.attitude.yaw
                        let roll = trueData.attitude.roll
                        let userAccelerationX = trueData.userAcceleration.x
                        let userAccelerationY = trueData.userAcceleration.y
                        let userAccelerationZ = trueData.userAcceleration.z
                        
                        self.sessionData.appendAccValues(x: userAccelerationX, y: userAccelerationY, z: userAccelerationZ)
                        self.sessionData.appendOrientationValues(pitch: pitch, yaw: yaw, roll: roll)
                        
                    }
                }
            }
        }
        
    }
    func myDevMotStop(){
        print("stop Device Motion")
        self.motion.stopDeviceMotionUpdates()
        
    }
    
    
    func myGPSstop(){
        print("stop GPS update")
        self.locationManager.stopUpdatingLocation()
    }
    
    
    func autorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void){
        
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HKError.self as? Error)
            return
        }
        guard
            let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
            let healthKitTypesToWrite: Set<HKSampleType> = [heartRate,
                                                            HKObjectType.workoutType()],
            let healthKitTypesToRead: Set<HKObjectType> = [heartRate,
                                                           HKObjectType.workoutType()]
            else {
                
                completion(false, HKError.self as? Error)
                return
        }
        
        
        HKHealthStore().requestAuthorization(toShare: healthKitTypesToWrite,
                                             read: healthKitTypesToRead) { (success, error) in
                                                completion(success, error)}
    }
    
    
    func getDocumentDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func saveSession(){
        if !FileManager.default.fileExists(atPath: Storage.getURL(for: .documents).path) {
            let documentName = sessionData.getDocumentName(number: self.sessionCounterPhone)
            Storage.store(sessionData, to: .documents, as: documentName )
            if Storage.fileExists(documentName, in: .documents){
                print("Saved data successfully")
            }
            else{
                print ("Something went wrong")
                }
        }
        
    }
    
//    func fileReceived(tuple: FileReceived) {
//        let tempFileName = ProcessInfo().globallyUniqueString
//        let tempFileURL = appFolderURL?.appendingPathComponent(tempFileName)
//        do {
//            try FileManager.default.moveItem(at: tuple.file.fileURL, to: tempFileURL!)
//        } catch {
//            print(error.localizedDescription)
//        }
//    }
//
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
}

extension ViewController : CLLocationManagerDelegate{
    
    func autorizeLocation(){
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        
        
    }
    
    func startUpdatingLocation(){
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self as CLLocationManagerDelegate
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
            locationManager.startUpdatingLocation()
            
        }
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let currentSpeed : CLLocationSpeed = manager.location?.speed else {return}
        guard let trueData: CLLocationCoordinate2D = manager.location?.coordinate else {return}
        let longitude = Double(trueData.longitude)
        let latitude = Double(trueData.latitude)
        let speed = Double(currentSpeed)
        
        
        self.sessionData.appendCurrentSpeed(currentSpeed: speed)
        self.sessionData.appendLocation(longitude: longitude, latitude: latitude)
        
        
    }
    
    
    
    
}

extension ViewController : WCSessionDelegate{
    func sessionDidBecomeInactive(_ session: WCSession) {
        
    }
    
    func sessionDidDeactivate(_ session: WCSession) {
        self.session.activate()
    }
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        
    }
    
    //    func session(_ session: WCSession, didReceiveMessageData messageData: Data) {
    //        txtWatch.text?.removeAll()
    //        txtWatch.text?.append("Data received from Apple Watch")
    //        if var messageData : SessionDatas = try? JSONDecoder().decode(SessionDatas.self, from: messageData){
    //            messageData.setLabel(label: txtLabel.text!)
    //            messageData.saveData(number: sessionCounterWatch)
    //            sessionCounterWatch+=1
    //            txtWatch.text?.removeAll()
    //            txtWatch.text?.append("Data received from Apple Watch saved")
    //
    //        }
    //    }
    func session(_ session: WCSession, didReceive file: WCSessionFile) {
        txtWatch.text?.removeAll()
        txtWatch.text?.append("Data received from Apple Watch")
        let fileName = file.metadata!["filename"] as! String
//        let documentsURL = Storage.getURL(for: .documents)
        let fileTempURL = appFolderURL!.appendingPathComponent(fileName)
        do {
            try FileManager.default.moveItem(at: file.fileURL, to: fileTempURL)
        } catch {
            print(error.localizedDescription)
        }
        txtWatch.text?.removeAll()
        txtWatch.text?.append("file moved to documentsURL")
        
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        txtWatch.text?.removeAll()
        if !fileTransfer.isTransferring {
            txtWatch.text?.removeAll()
            txtWatch.text?.append("Transfering ended")
        } else {
            txtWatch.text?.removeAll()
            txtWatch.text?.append("Still transferring")
        }
        
    }
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let status = message["status"] as! String
        if status == "finish"{
            txtWatch.text?.removeAll()
            txtWatch.text?.append("WatchOS sent file")
        }
        
    }

    
}

extension ViewController : UITextFieldDelegate{
    
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
    
}

extension TimeInterval{
    
    func stringFromTimeInterval() -> String {
        
        let time = NSInteger(self)
        
        let ms = Int((self.truncatingRemainder(dividingBy: 1)) * 1000)
        let seconds = time % 60
        let minutes = (time / 60) % 60
        let hours = (time / 3600)
        
        return String(format: "%0.2d:%0.2d:%0.2d.%0.3d",hours,minutes,seconds,ms)
        
    }
}
