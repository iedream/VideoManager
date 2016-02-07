//
//  Helper.swift
//  VideoPlayistBuilder
//
//  Created by Catherine Zhao on 2016-02-06.
//  Copyright © 2016 Catherine. All rights reserved.
//

struct OrderedDictionary<KeyType: Hashable, ValueType> {
    
    typealias ArrayType = [String]
    typealias DictionaryType = [String: String]
    
    var array = ArrayType()
    var dictionary = DictionaryType()
    
    var count: Int {
        return self.array.count
    }
    
    subscript(key: String) -> String? {
        get{
            return self.dictionary[key]
        }
        
        set{
            if let _ = self.array.indexOf(key){
            }else{
                self.array.append(key)
            }
            
            self.dictionary[key] = newValue
        }
    }
    
    func indexOfKey(key:String) -> Int{
        return self.array.indexOf(key)!
    }
    
    subscript(index: Int) -> (String, String){
        get{
            precondition(index < self.array.count, "Index out-of-bounds")
            
            let key = self.array[index]
            let value = self.dictionary[key]
            return (key,value!)
        }
    }
    
    func writeToPlist() -> NSArray{
        let returnArray:NSArray = [self.array,self.dictionary]
        return returnArray
    }
    
    mutating func build(initialArray:NSArray){
        self.array = initialArray[0] as! ArrayType
        self.dictionary = initialArray[1] as! DictionaryType
    }
}

import Foundation
import MediaPlayer

class Helper{
    
    // Singleton
    static let sharedInstance = Helper()
    
    // Ipod Library Source
    let mainQuery:MPMediaQuery = MPMediaQuery.init()
    let typePredicate = MPMediaPropertyPredicate(value: MPMediaType.AnyVideo.rawValue, forProperty: MPMediaItemPropertyMediaType)
    
    // Local Source Data
    var playistAmblum:[String:OrderedDictionary<String,String>] = [String:OrderedDictionary<String,String>]()
    var singerAmblum:[String:OrderedDictionary<String,String>] = [String:OrderedDictionary<String,String>]()
    var allAmblum:OrderedDictionary<String,String> = OrderedDictionary<String,String>()
    var localAmblum:[String:String] = [String:String]()
    var localImageDic:[String:UIImage] = [String:UIImage]()
    
    
    // MARK: - Get Data From Ipod Library -
    
    func getIpodLibraryInformation(){
        mainQuery.addFilterPredicate(typePredicate)
        for (item) in mainQuery.items! {
            let name:String = item.valueForProperty(MPMediaItemPropertyTitle) as! String
            let path:NSURL = item.valueForProperty(MPMediaItemPropertyAssetURL) as! NSURL
            localAmblum[name] = path.absoluteString
            // Setting up to get image from mp4
            self.captureFrame(path, timeInSeconds: 12, key:name)
        }
    }
    
    func getVideoImage(type:String) -> [String:UIImage]{
        var imageDic:[String:UIImage] = [String:UIImage]()
        if (type == "Playist"){
            for(_,subDic) in playistAmblum{
                for(name,_) in subDic.dictionary{
                    imageDic[name] = localImageDic[name]
                }
            }
        }else if( type == "Singer"){
            for(_,subDic) in singerAmblum{
                for(name,_) in subDic.dictionary{
                    imageDic[name] = localImageDic[name]
                }
            }
        }else if( type == "All"){
            for(name,_) in allAmblum.dictionary{
                imageDic[name] = localImageDic[name]
            }
        }
        return imageDic
    }
    
    // MARK: - Get Individual Mp4 Image To Disply -
    
    // Acutally getting the image
    func captureFrame(url:NSURL, timeInSeconds time:Int64, key:String) {
        let generator = AVAssetImageGenerator(asset: AVAsset(URL: url))
        let tVal = NSValue(CMTime: CMTimeMake(time, 1))
        generator.generateCGImagesAsynchronouslyForTimes([tVal], completionHandler: {(_, im:CGImage?, _, _, e:NSError?) in self.finshedCapture(im, key:key, error:e)})
    }
    
    // Save image in dictionary
    func finshedCapture(im:CGImage?, key:String, error:NSError?)  {
        localImageDic[key] = UIImage(CGImage: im!)
    }

     // MARK: - Local Source Access -
    
    // Get Array To Display on Different View Controller
    func getChosenArray(choice:String) -> [String]{
        if(choice == "Singer"){
            return Array(singerAmblum.keys)
        }else if(choice == "Playist"){
            return Array(playistAmblum.keys)
        }else{
            return allAmblum.array
        }
    }
    
     // Add Video To Local Source
    func addVideo(choice:String, folderName:String, videoFile:String, fileName:String){
        if(choice == "Singer"){
            singerAmblum[folderName]![fileName] = videoFile
        }else if(choice == "Playist"){
            playistAmblum[folderName]![fileName] = videoFile
        }
        allAmblum[fileName] = videoFile
        writeToModifyPlist()
    }
    
    // Add New Folder To Local Source
    func writeToFolder(choice:String, key:String){
        if(choice == "Singer"){
            singerAmblum[key] = OrderedDictionary<String,String>()
            writeToModifyPlist()
        }else if(choice == "Playist"){
            playistAmblum[key] = OrderedDictionary<String,String>()
            writeToModifyPlist()
        }
    }
    
    // MARK: - Plist Access -
    
    // Read From Plist
    func populatePlayListFromPlist(){
        let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
        let fileURL = documentsURL.URLByAppendingPathComponent("localList.plist")
        let fileMananger = NSFileManager.defaultManager()
        if(!fileMananger.fileExistsAtPath(fileURL.path!)){
            if let bundlePath = NSBundle.mainBundle().pathForResource("localList", ofType: "plist"){
                do{
                    try fileMananger.copyItemAtPath(bundlePath, toPath: fileURL.path!)
                }catch{
                    
                }
            }
        }
        let resultDictionary:NSMutableDictionary = NSMutableDictionary(contentsOfFile: fileURL.path!)!
        if( (resultDictionary.objectForKey("allAmblum") as! NSArray).count != 0 ){
            allAmblum.array = (resultDictionary.objectForKey("allAmblum") as! NSArray)[0] as! [String]
            allAmblum.dictionary = (resultDictionary.objectForKey("allAmblum") as! NSArray)[1] as! [String:String]
        }
        
        convertFromBasicType(resultDictionary.objectForKey("singerAmblum") as! NSDictionary, type: "Singer")
        convertFromBasicType(resultDictionary.objectForKey("playistAmblum") as! NSDictionary, type: "Playist")
    }
    
    func convertFromBasicType(dictToConvert:NSDictionary,type:String){
        for(key,subDic) in dictToConvert{
            var orderDic:OrderedDictionary<String,String> = OrderedDictionary<String,String>()
            
            if(subDic.count == 2){
                orderDic.array = (subDic as! NSArray)[0] as! [String]
                orderDic.dictionary = (subDic as! NSArray)[1] as! [String:String]
            }
            if( type == "Singer"){
                singerAmblum[key as! String] = orderDic
            }else if( type == "Playist"){
                playistAmblum[key as! String] = orderDic
            }
        }
    }
    
    
    
    // Write To Plist
    func writeToModifyPlist(){
        let documentsURL = NSFileManager.defaultManager().URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask)[0]
        let fileURL = documentsURL.URLByAppendingPathComponent("localList.plist")
        
        let dictToBeWrite:NSDictionary = ["allAmblum":allAmblum.writeToPlist(),"singerAmblum":convertToBasicType(singerAmblum),"playistAmblum":convertToBasicType(playistAmblum)]
        dictToBeWrite.writeToURL(fileURL, atomically: false)

    }
    
    func convertToBasicType(dictToConvert:[String:OrderedDictionary<String,String>]) -> NSDictionary{
        let newDict:NSMutableDictionary = NSMutableDictionary.init(dictionary: [:])
        for(key,subDic) in dictToConvert{
            newDict[key] = subDic.writeToPlist()
        }
        return newDict
    }
}