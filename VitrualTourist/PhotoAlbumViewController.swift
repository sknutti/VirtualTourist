//
//  PhotoAlbumViewController.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import Foundation
import UIKit
import MapKit
import CoreData

class PhotoAlbumViewController: UIViewController {
    
    @IBOutlet weak var mapView: MKMapView!
    @IBOutlet weak var noImagesLabel: UILabel!
    
    var pin: MKAnnotation?
    
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        navigationController?.navigationBarHidden = false
        navigationItem.title = nil
        restoreMapRegion(false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        mapView.addAnnotation(pin!)
//        do {
//            try fetchedResultsController.performFetch()
//        } catch {
//            print(error)
//        }
//        
//        fetchedResultsController.delegate = self
//        if let fetched = fetchedResultsController.fetchedObjects as? [Pin] {
//            for annotation in fetched {
//                mapView.addAnnotation(annotation)
//            }
//        }
    }
    
    func restoreMapRegion(animated: Bool) {
        
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: (latitudeDelta/4.0) + 2, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
}