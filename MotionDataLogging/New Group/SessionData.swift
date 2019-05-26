//
//  SessionData.swift
//  MotionDataLogging
//
//  Created by Fabiano Finocchio on 17/05/2019.
//  Copyright © 2019 Fabiano Finocchio. All rights reserved.
//

import Foundation
struct SessionData : Codable {
    
    private var label : String?
    var device : String?
    private var accelerationX : [Double]
    private var accelerationY : [Double]
    private var accelerationZ : [Double]
    private var gyroX : [Double]
    private var gyroY : [Double]
    private var gyroZ : [Double]
    private var pitch : [Double]
    private var roll : [Double]
    private var yaw : [Double]
    private var longitude : [Double]
    private var latitude : [Double]
    private var currentSpeed : [Double]
    private var heartRate : [Double]
    private var startDataAcquisition : Date?
    private var stopDataAcquisition : Date?
    private var startAcquisitionString : String?
    private var stopAcquistionString : String?
    private var durationAcquisition : Double?
    private var frequency: Int?
    
    
    var json: Data {
        return try! JSONEncoder().encode(self)
    }
    
//    var temporaryURL : URL?
    
    init() {
        self.accelerationX = [Double]()
        self.accelerationY = [Double]()
        self.accelerationZ = [Double]()
        self.gyroX = [Double]()
        self.gyroY = [Double]()
        self.gyroZ = [Double]()
        self.pitch = [Double]()
        self.roll = [Double]()
        self.yaw = [Double]()
        self.currentSpeed = [Double]()
        self.longitude = [Double]()
        self.latitude = [Double]()
        self.heartRate = [Double]()
        self.frequency = 50;
//        var searchPathDirectory: FileManager.SearchPathDirectory
//        searchPathDirectory = .documentDirectory
//        self.temporaryURL = FileManager.default.urls(for: searchPathDirectory, in: .userDomainMask).first
    }
    
    
    
    func getLabel()->String{
        if self.label == nil{
            return "None"
        }else {
            return self.label!
        }
    }
    mutating func setLabel (label: String){
        self.label = label
    }
    mutating func setDevice( device: String){
        self.device = device
    }
    func getAccX()->[Double]{
        return self.accelerationX
    }
    func getAccZ()->[Double]{
        return self.accelerationZ
    }
    func getAccY()->[Double]{
        return self.accelerationY
    }
    func getGyroX()->[Double]{
        return self.gyroX
    }
    func getGyroY()->[Double]{
        return self.gyroY
    }
    func getGyroZ()->[Double]{
        return self.gyroZ
    }
    func getPitch()->[Double]{
        return self.pitch
    }
    func getYaw()->[Double]{
        return self.yaw
    }
    func getRoll()->[Double]{
        return self.roll
    }
    func getSpeed()->[Double]{
        return self.currentSpeed
    }
    func getLongitude()->[Double]{
        return self.longitude
    }
    func getLatitude()->[Double]{
        return self.latitude
    }
    func getHeartRate()->[Double]{
        return self.heartRate
    }
    func getStart()->Date{
        return self.startDataAcquisition!
    }
    func getStop()->Date{
        return self.stopDataAcquisition!
    }
    func getFrequency()->Int{
        return self.frequency!
        
    }
    mutating func setFrequency(frequency : Int){
        self.frequency = frequency
        
    }
    
    mutating func setStartAcquisition() {
        self.startDataAcquisition = Date()
        self.startAcquisitionString = convertDateToString(date: self.startDataAcquisition!)
    }
    mutating func setStopAcquisition(){
        self.stopDataAcquisition = Date()
        self.stopAcquistionString = convertDateToString(date: self.stopDataAcquisition!)
    }
    mutating func appendGyroValues (x: Double, y: Double, z:Double){
        self.gyroX.append(x)
        self.gyroY.append(y)
        self.gyroZ.append(z)
        
    }
    
    mutating func appendAccValues(x:Double, y: Double, z:Double){
        self.accelerationX.append(x)
        self.accelerationY.append(y)
        self.accelerationZ.append(z)
    }
    
    mutating func appendOrientationValues (pitch : Double, yaw : Double, roll : Double){
        self.roll.append(roll)
        self.yaw.append(yaw)
        self.pitch.append(pitch)
    }
    
    mutating func appendCurrentSpeed (currentSpeed :Double){
        self.currentSpeed.append(currentSpeed)
    }
    
    mutating func appendLocation(longitude: Double, latitude: Double){
        self.longitude.append(longitude)
        self.latitude.append(latitude)
    }
    mutating func appendHeartRate( heartRate : Double){
        self.heartRate.append(heartRate)
    }
    
    func convertDateToString (date:Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd_HH:mm:ss"
        let myString = formatter.string(from: date)
        return myString
        
    }
    
    func getDocumentName(number:Int)->String{
        var documentName : String
        documentName = "DataSession_\(self.device!)_\(number).json"
        return documentName
    }
    
    func saveData(number: Int){
        var documentName : String
        
        documentName = "DataSession_\(device!)_\(number).json"
        
        Storage.store(self, to: .documents, as: documentName )
        if Storage.fileExists(documentName, in: .documents){
            print("Saved data successfully")
        }
        else{
            print ("Something went wrong")
        }
    }
    
    mutating func clearAll(){
        self.startDataAcquisition = nil
        self.stopDataAcquisition = nil
        self.startAcquisitionString = nil
        self.stopAcquistionString = nil
        self.label = nil
        self.accelerationX.removeAll()
        self.accelerationY.removeAll()
        self.accelerationZ.removeAll()
        self.gyroZ.removeAll()
        self.gyroY.removeAll()
        self.gyroX.removeAll()
        self.pitch.removeAll()
        self.yaw.removeAll()
        self.roll.removeAll()
        self.currentSpeed.removeAll()
    }
    
}
