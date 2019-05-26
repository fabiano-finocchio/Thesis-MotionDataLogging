//
//  InterfaceController.swift
//  MotionDataLogging WatchKit Extension
//
//  Created by Fabiano Finocchio on 17/05/2019.
//  Copyright © 2019 Fabiano Finocchio. All rights reserved.
//

import WatchKit
import WatchConnectivity
import Foundation
import CoreMotion
import CoreLocation
import HealthKit


class InterfaceController: WKInterfaceController {
    
    var session : WCSession!
    private let motion = CMMotionManager()
    private let locationManager = CLLocationManager()
    public let healthStore = HKHealthStore()
    private var sessionDatas = SessionData()
    private var sessionCounterWatch = 0
    private var sessionWorkout : HKWorkoutSession?
    private var labelFromPhone : String?
    private var heartRateQuery : HKObserverQuery?
//    gui elements

    @IBOutlet weak var dataLogTimer: WKInterfaceTimer!
    @IBOutlet weak var txtSystem: WKInterfaceLabel!
    
    override func awake(withContext context: Any?) {
        super.awake(withContext: context)
        
        if isSuported() {
            self.session = WCSession.default
            session.delegate = self
            session.activate()
            txtSystem.setText("session established")
        }
        // Configure interface objects here.
        self.locationManager.requestAlwaysAuthorization()
        self.locationManager.requestWhenInUseAuthorization()
        autorizeLocation()
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
    }
    
    override func willActivate() {
        // This method is called when watch view controller is about to be visible to user
        super.willActivate()
    }
    
    override func didDeactivate() {
        // This method is called when watch view controller is no longer visible
        super.didDeactivate()
    }
   
    private func isSuported() -> Bool {
        return WCSession.isSupported()
    }
    
    private func isReachable() -> Bool {
        return session.isReachable
    }
    @IBAction func onStartPressed() {
        self.dataLogTimer.setDate(Date.init())
        self.dataLogTimer.start()
        self.startWorkOut()
        txtSystem.setText("Start recording")
    }
    
    @IBAction func onStopPressed() {
        txtSystem.setText("Stopping session...")
        sessionDatas.setDevice(device:"watchOS")
        self.dataLogTimer.stop()
        self.sessionDatas.setStopAcquisition()
        self.stopWorkOut()
        if (self.labelFromPhone != nil){
            sessionDatas.setLabel(label: self.labelFromPhone!)
        }
        
        self.saveSession()
        txtSystem.setText("session saved locally")
        var metadata : [String:Any]  = ["filename" : sessionDatas.getDocumentName(number: self.sessionCounterWatch)]
//        let URLPath = Bundle.main.url(forResource: metadata["filename"] as? String, withExtension: ".json")
        var URLPath = Storage.getURL(for: .documents)
        URLPath = URLPath.appendingPathComponent(metadata["filename"] as! String)
//        cannot retrieve url like this
        
        session.transferFile(URLPath, metadata: metadata)
        txtSystem.setText("Transfering file")
    
        self.sessionDatas.clearAll()
        self.sessionCounterWatch+=1
        self.dataLogTimer.setDate(Date.init())
    }
    func myDevMotStart(){
        print ("Start Device Motion")
        if self.motion.isDeviceMotionAvailable{
            motion.deviceMotionUpdateInterval = 1/50
            motion.startDeviceMotionUpdates(to: OperationQueue.current!){
                (data,error) in print (data as Any)
                if self.motion.isDeviceMotionActive{
                    if let trueData = data {
                        
                        
                        let pitch = trueData.attitude.pitch
                        let yaw = trueData.attitude.yaw
                        let roll = trueData.attitude.roll
                        let userAccelerationX = trueData.userAcceleration.x
                        let userAccelerationY = trueData.userAcceleration.y
                        let userAccelerationZ = trueData.userAcceleration.z
                        let gyrox = trueData.rotationRate.x
                        let gyroy = trueData.rotationRate.y
                        let gyroz = trueData.rotationRate.z
                        self.sessionDatas.appendAccValues(x: userAccelerationX, y: userAccelerationY, z: userAccelerationZ)
                        self.sessionDatas.appendGyroValues(x: gyrox, y: gyroy, z: gyroz)
                        self.sessionDatas.appendOrientationValues(pitch: pitch, yaw: yaw, roll: roll)
                    }
                }
            }
            
        }
        
    }
    func myDevMotStop(){
        print("stop Device Motion")
        self.motion.stopDeviceMotionUpdates()
        
    }
    
    func startWorkOut(){
        let workoutConfiguration = HKWorkoutConfiguration()
        workoutConfiguration.activityType = .other
        workoutConfiguration.locationType = .unknown
        
        do {
            sessionWorkout = try HKWorkoutSession(configuration: workoutConfiguration)
        } catch {
            fatalError("Unable to create the workout session!")
        }
        
        // Start the workout session and device motion updates.
        healthStore.start(sessionWorkout!)
        myDevMotStart()
        locationManager.startUpdatingLocation()
        subscribeToHeartBeatChanges()
        self.txtSystem.setText("started acquisition")
    }
    
    func stopWorkOut(){
        if sessionWorkout != nil {
            healthStore.end(sessionWorkout!)
        }
        
        print("Ended health session")
        // Clear the workout session.
        sessionWorkout = nil
        myDevMotStop()
        locationManager.stopUpdatingLocation()
    }
    
    func getDocumentDirectory() -> URL {
        
        let paths = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)
        return paths[0]
    }
    
    func autorizeHealthKit(completion: @escaping (Bool, Error?) -> Swift.Void){
        
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false, HKError.self as? Error)
            return
        }
        guard let heartRate = HKObjectType.quantityType(forIdentifier: .heartRate),
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
    
    
    func subscribeToHeartBeatChanges() {
        guard let sampleType : HKSampleType = HKObjectType.quantityType(forIdentifier: .heartRate) else {return
        }
        
        self.heartRateQuery  = HKObserverQuery.init(sampleType: sampleType, predicate: nil) { (_, _, error) in
            if let error = error {
                print("Error: \(error.localizedDescription)")
                return
            }}
        
        /// When the completion is called, an other query is executed
        /// to fetch the latest heart rate
        fetchLatestHeartRateSample(completion: { sample in
            guard let sample = sample else {
                return
            }
            
            /// The completion in called on a background thread, but we
            /// need to update the UI on the main.
            DispatchQueue.main.async {
                
                /// Converting the heart rate to bpm
                let heartRateUnit = HKUnit(from: "count/min")
                let heartRate = sample
                    .quantity
                    .doubleValue(for: heartRateUnit)
                
                /// Updating the UI with the retrieved value

                self.sessionDatas.appendHeartRate(heartRate: heartRate)
                self.txtSystem.setText("current heart rate: \(heartRate)")
            }
        })
        healthStore.execute(heartRateQuery!)
    }
    
    
    
    func fetchLatestHeartRateSample(
        completion: @escaping (_ sample: HKQuantitySample?) -> Void) {
        
        /// Create sample type for the heart rate
        guard let sampleType = HKObjectType
            .quantityType(forIdentifier: .heartRate) else {
                completion(nil)
                return
        }
        
        /// Predicate for specifiying start and end dates for the query
        let predicate = HKQuery
            .predicateForSamples(
                withStart: Date.distantPast,
                end: Date(),
                options: .strictEndDate)
        
        /// Set sorting by date.
        let sortDescriptor = NSSortDescriptor(
            key: HKSampleSortIdentifierStartDate,
            ascending: false)
        
        /// Create the query
        let query = HKSampleQuery(
            sampleType: sampleType,
            predicate: predicate,
            limit: Int(HKObjectQueryNoLimit),
            sortDescriptors: [sortDescriptor]) { (_, results, error) in
                
                guard error == nil else {
                    print("Error: \(error!.localizedDescription)")
                    return
                }
                
                completion(results?[0] as? HKQuantitySample)
        }
        
        self.healthStore.execute(query)
    }
    
    func saveSession(){
        Storage.store(sessionDatas, to: .documents, as: sessionDatas.getDocumentName(number: self.sessionCounterWatch
        ) )
        if Storage.fileExists(sessionDatas.getDocumentName(number: self.sessionCounterWatch), in: .documents){
            print("Saved data successfully")
        }
        else{
            print ("Something went wrong")
        }
        
    }

}
extension InterfaceController : WCSessionDelegate {
    
    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        print("activationDidCompleteWith activationState:\(activationState) error:\(String(describing: error))")
    }
    
    func session(_ session: WCSession, didReceiveMessage message: [String : Any]) {
        let message = message["label"] as! String
        txtSystem.setText("label received")
        self.labelFromPhone = message
    }
    func session(_ session: WCSession, didFinish fileTransfer: WCSessionFileTransfer, error: Error?) {
        txtSystem.setText("finish transfer file")
        session.sendMessage(["status" : "finished"], replyHandler: nil, errorHandler: nil)
    }

    
}

extension InterfaceController : CLLocationManagerDelegate{
    
    func autorizeLocation(){
        
        if CLLocationManager.locationServicesEnabled() {
            locationManager.delegate = self as CLLocationManagerDelegate
            locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters
        }
        
    }
    
    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let trueData: CLLocationCoordinate2D = manager.location?.coordinate else { return }
        let longitude = trueData.longitude
        let latitude = trueData.latitude
        let currentSpeed = Double(manager.location!.speed)
        
        self.sessionDatas.appendCurrentSpeed(currentSpeed: currentSpeed)
        self.sessionDatas.appendLocation(longitude: longitude, latitude: latitude)
        
    }
    
}

