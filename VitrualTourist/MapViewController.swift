//
//  MapViewController.swift
//  VitrualTourist
//
//  Created by Scott Knutti on 1/2/16.
//  Copyright © 2016 Scott Knutti. All rights reserved.
//

import UIKit
import MapKit
import CoreData

class MapViewController: UIViewController {

    @IBOutlet weak var mapView: MKMapView!
    
    var longPressRecognizer: UILongPressGestureRecognizer?
    var temporaryPin: MKPointAnnotation?
    
    var filePath : String {
        let manager = NSFileManager.defaultManager()
        let url = manager.URLsForDirectory(.DocumentDirectory, inDomains: .UserDomainMask).first! as NSURL
        return url.URLByAppendingPathComponent("mapRegionArchive").path!
    }
    
    var sharedContext: NSManagedObjectContext {
        return CoreDataStackManager.sharedInstance().managedObjectContext
    }
    
    lazy var fetchedResultsController: NSFetchedResultsController = {
        let fetchRequest = NSFetchRequest(entityName: "Pin")
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "latitude", ascending: true)]
        let fetchedResultsController = NSFetchedResultsController(fetchRequest: fetchRequest,
            managedObjectContext: self.sharedContext,
            sectionNameKeyPath: nil,
            cacheName: nil)
        return fetchedResultsController
    }()
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        longPressRecognizer = UILongPressGestureRecognizer(target: self, action: "longPressed:")
        mapView.addGestureRecognizer(longPressRecognizer!)
        
        navigationController?.navigationBarHidden = true
        
        restoreMapRegion(false)
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            try fetchedResultsController.performFetch()
        } catch {
            print(error)
        }
        
        fetchedResultsController.delegate = self
        if let fetched = fetchedResultsController.fetchedObjects as? [Pin] {
            for annotation in fetched {
                mapView.addAnnotation(annotation)
            }
        }
    }

    func saveMapRegion() {
        
        let dictionary = [
            "latitude" : mapView.region.center.latitude,
            "longitude" : mapView.region.center.longitude,
            "latitudeDelta" : mapView.region.span.latitudeDelta,
            "longitudeDelta" : mapView.region.span.longitudeDelta
        ]
        NSKeyedArchiver.archiveRootObject(dictionary, toFile: filePath)
    }
    
    func restoreMapRegion(animated: Bool) {
        
        if let regionDictionary = NSKeyedUnarchiver.unarchiveObjectWithFile(filePath) as? [String : AnyObject] {
            
            let longitude = regionDictionary["longitude"] as! CLLocationDegrees
            let latitude = regionDictionary["latitude"] as! CLLocationDegrees
            let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            
            let longitudeDelta = regionDictionary["latitudeDelta"] as! CLLocationDegrees
            let latitudeDelta = regionDictionary["longitudeDelta"] as! CLLocationDegrees
            let span = MKCoordinateSpan(latitudeDelta: latitudeDelta, longitudeDelta: longitudeDelta)
            
            let savedRegion = MKCoordinateRegion(center: center, span: span)
            
            mapView.setRegion(savedRegion, animated: animated)
        }
    }
    
    func longPressed(sender: UILongPressGestureRecognizer) {
        
        let point: CGPoint = sender.locationInView(mapView)
        let coordinates: CLLocationCoordinate2D = mapView.convertPoint(point, toCoordinateFromView: mapView)
        let annotation = MKPointAnnotation()
        annotation.coordinate = coordinates
        
        switch sender.state {
        case .Ended:
            mapView.removeAnnotation(temporaryPin!)
            var title: String? = ""
            let geoCoder = CLGeocoder()
            let location = CLLocation(latitude: coordinates.latitude, longitude: coordinates.longitude)
            geoCoder.reverseGeocodeLocation(location, completionHandler: { (placemarks, error) -> Void in
                
                // Place details
                var placeMark: CLPlacemark!
                placeMark = placemarks?[0]
                if let city = placeMark.addressDictionary!["City"] as? NSString {
                    if let country = placeMark.addressDictionary!["Country"] as? NSString {
                        title = "\(city), \(country)"
                    }
                } else if let name = placeMark.addressDictionary!["Name"] as? NSString {
                    if let country = placeMark.addressDictionary!["Country"] as? NSString {
                        title = "\(name), \(country)"
                    }
                }
                let dictionary: [String : AnyObject] = ["title": title!, "latitude": coordinates.latitude, "longitude": coordinates.longitude]
                let pin = Pin(dictionary: dictionary, context: self.sharedContext)
                CoreDataStackManager.sharedInstance().saveContext()
                
                FlickrClient.sharedInstance.fetchImageListFromFlickr(pin, context: self.sharedContext) { photos, error in
                    for photo in (photos as? [Photo])! {
                        FlickrClient.sharedInstance.downloadImagesFromFlickr(photo, addInBackground: true) { success, error in }
                    }
                }
            })
        case .Changed:
            temporaryPin?.coordinate = annotation.coordinate
        default:
            temporaryPin = annotation
            mapView.addAnnotation(annotation)
        }
    }
}

extension MapViewController : MKMapViewDelegate {
    
    func mapView(mapView: MKMapView, regionDidChangeAnimated animated: Bool) {
        saveMapRegion()
    }
    
    func mapView(mapView: MKMapView, viewForAnnotation annotation: MKAnnotation) -> MKAnnotationView? {
        
        let reuseId = "pin"
        var pinView = mapView.dequeueReusableAnnotationViewWithIdentifier(reuseId) as? MKPinAnnotationView
        
        if pinView == nil {
            pinView = MKPinAnnotationView(annotation: annotation, reuseIdentifier: reuseId)
            pinView!.canShowCallout = true
            pinView!.pinTintColor = UIColor.redColor()
            pinView!.rightCalloutAccessoryView = UIButton(type: .DetailDisclosure)
            pinView!.draggable = true
        } else {
            pinView!.annotation = annotation
        }
        
        return pinView
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, didChangeDragState newState: MKAnnotationViewDragState, fromOldState oldState: MKAnnotationViewDragState) {
        switch (newState) {
        case .Starting:
            view.dragState = .Dragging
        case .Ending, .Canceling:
            view.dragState = .None
        default: break
        }
    }
    
    func mapView(mapView: MKMapView, annotationView view: MKAnnotationView, calloutAccessoryControlTapped control: UIControl) {
        if control == view.rightCalloutAccessoryView {
            let controller = storyboard!.instantiateViewControllerWithIdentifier("PhotoAlbumViewController") as! PhotoAlbumViewController
            controller.pin = view.annotation as? Pin
            self.navigationController!.pushViewController(controller, animated: true)
        }
    }
}

extension MapViewController : NSFetchedResultsControllerDelegate {
    
    func controller(controller: NSFetchedResultsController,
        didChangeObject anObject: AnyObject,
        atIndexPath indexPath: NSIndexPath?,
        forChangeType type: NSFetchedResultsChangeType,
        newIndexPath: NSIndexPath?) {
            
            switch type {
            case .Insert:
                mapView.addAnnotation(anObject as! Pin)
                
            case .Delete:
                mapView.removeAnnotation(anObject as! Pin)
                
            case .Update:
                mapView.removeAnnotation(anObject as! Pin)
                mapView.addAnnotation(anObject as! Pin)
                
            default:
                return
            }
    }
}

