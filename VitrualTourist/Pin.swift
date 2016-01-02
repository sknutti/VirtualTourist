//
//  Pin.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import Foundation
import CoreData
import MapKit

class Pin : NSManagedObject, MKAnnotation {
    
    @NSManaged var title: String?
    @NSManaged var latitude: NSNumber
    @NSManaged var longitude: NSNumber
    @NSManaged var photos: [Photo]
    
    override init(entity: NSEntityDescription, insertIntoManagedObjectContext context: NSManagedObjectContext?) {
        super.init(entity: entity, insertIntoManagedObjectContext: context)
    }
    
    init(dictionary: [String : AnyObject], context: NSManagedObjectContext) {
        let entity =  NSEntityDescription.entityForName("Pin", inManagedObjectContext: context)!
        super.init(entity: entity, insertIntoManagedObjectContext: context)
        
        latitude = (dictionary["latitude"] as? Double)!
        longitude = (dictionary["longitude"] as? Double)!
        if (dictionary["title"] as? String)?.characters.count > 0 {
            title = dictionary["title"] as? String
        } else {
            title = "\(latitude), \(longitude)"
        }
    }
    
    var coordinate: CLLocationCoordinate2D {
        get {
            return CLLocationCoordinate2DMake(latitude as Double, longitude as Double)
        }
    }
}
