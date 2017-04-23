/*
 * Copyright 2016 Google Inc. All rights reserved.
 *
 *
 * Licensed under the Apache License, Version 2.0 (the "License"); you may not use this
 * file except in compliance with the License. You may obtain a copy of the License at
 *
 *     http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under
 * the License is distributed on an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF
 * ANY KIND, either express or implied. See the License for the specific language governing
 * permissions and limitations under the License.
 */

import UIKit
import GoogleMaps
import GooglePlaces


infix operator ~>   // serial queue operator
/**
 Executes the lefthand closure on a background thread and,
 upon completion, the righthand closure on the main thread.
 Passes the background closure's output to the main closure.
 */
func ~> <R> (
    backgroundClosure:   @escaping () -> R,
    mainClosure:         @escaping (_ result: R) -> ())
{
    serial_queue.async {
        let result = backgroundClosure()
        DispatchQueue.main.async(execute: {
            mainClosure(result)
        })
    }
}
/** Serial dispatch queue used by the ~> operator. */
private let serial_queue = DispatchQueue(label: "serial-worker")

////////////////////////////////////////////////////////////////////////////////////////////////////
infix operator ≠>   // concurrent queue operator
/**
 Executes the lefthand closure on a background thread and,
 upon completion, the righthand closure on the main thread.
 Passes the background closure's output to the main closure.
 */
func ≠> <R> (
    backgroundClosure: @escaping () -> R,
    mainClosure:       @escaping (_ result: R) -> ())
{
    concurrent_queue.async {
        let result = backgroundClosure()
        DispatchQueue.main.async(execute: {
            mainClosure(result)
        })
    }
}

/** Concurrent dispatch queue used by the ≠> operator. */
private let concurrent_queue = DispatchQueue(label: "concurrent-worker", attributes: .concurrent)

class MapViewController: UIViewController {

    @IBOutlet var button: UIButton!
    
  
  @IBOutlet var mainView: UIView!
  var locationManager = CLLocationManager()
  var currentLocation: CLLocation?
  var mapView: GMSMapView!
  var zoomLevel: Float = 15.0
    var currentRegion: Int = 0
    var userID: Int = 2
  var colors:[UIColor] = [UIColor(red: 0.5, green: 0, blue: 0, alpha: 0.2), UIColor(red: 0.9, green: 0.76, blue: 0, alpha: 0.2)]

    //Operator override for threading
    

    
  // A default location to use when location permission is not granted.
  let defaultLocation = CLLocation(latitude: -33.869405, longitude: 151.199)


  @IBAction func sendAttack(_ sender: UIButton) {
    
    var request = URLRequest(url: URL(string: "http://hackcu.ohioporcelain.com/server.php?a=set_battle&region_id=\(currentRegion)&user_id=\(userID)")!)
    print("http://hackcu.ohioporcelain.com/server.php?a=set_battle&region_id=\(currentRegion)&user_id=\(userID)")
    request.httpMethod = "GET"
    let session = URLSession.shared
    session.dataTask(with: request) {data, response, err in
        print("attack sent")
    }
  }
    
  override func viewDidLoad() {
    super.viewDidLoad()
    // Initialize the location manager.
    locationManager = CLLocationManager()
    locationManager.desiredAccuracy = kCLLocationAccuracyBest
    locationManager.requestAlwaysAuthorization()
    locationManager.distanceFilter = 50
    locationManager.startUpdatingLocation()
    
    
    // Create a map.
    let camera = GMSCameraPosition.camera(withLatitude: defaultLocation.coordinate.latitude,
                                          longitude: defaultLocation.coordinate.longitude,
                                          zoom: zoomLevel)
    mapView = GMSMapView.map(withFrame: view.bounds, camera: camera)
    mapView.settings.myLocationButton = true
    mapView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    mapView.isMyLocationEnabled = true

    // Add the map to the view, hide it until we've got a location update.
    self.view.insertSubview(mapView, at:0)
    //let button1 = button //UIButton(frame: CGRect(x: 150, y: 560, width: 75, height: 40))
    self.view.insertSubview(button, at:1)
    mapView.isHidden = true
    
    var gameTimer: Timer!
    gameTimer = Timer.scheduledTimer(timeInterval: 0.5, target: self, selector: #selector(loopUpdate), userInfo: nil, repeats: true)
    
  }
    
    func displayRegions(regions: [[String: Any]]) {
        for region in regions {
            let color = colors[(region["team_winning"] as! Int)-1]
            var points = [CLLocationDegrees](repeating: CLLocationDegrees(0.0), count: 8)
            let coordinates = region["coordinates"] as! [[String: Float]]
            var i = 0
            for coord in coordinates {
                points[i] = CLLocationDegrees(coord["lat"]!)
                points[i+1] = CLLocationDegrees(coord["lon"]!)
                i += 2
            }
            drawPolygon(points: points, color: color)
        }
    }
    
    func drawPolygon(points : [CLLocationDegrees], color : UIColor) {
        let path = GMSMutablePath()
        for i in (0..<8).filter({ $0 % 2 == 0 }) {
            path.add(CLLocationCoordinate2D(latitude: points[i], longitude: points[i+1]))
        }
        let polygon = GMSPolygon(path: path)
        polygon.fillColor = color
        polygon.strokeColor = .black
        polygon.strokeWidth = 2
        polygon.map = mapView
        
    }
    
    func getCoordinates(latitude: CLLocationDegrees, longitude: CLLocationDegrees){
        
        var request = URLRequest(url: URL(string: "http://hackcu.ohioporcelain.com/server.php?a=get_regions&user_id=\(userID)&lat=\(latitude)&lon=\(longitude)")!)
        request.httpMethod = "GET"
        let session = URLSession.shared
        session.dataTask(with: request) {data, response, err in
            //print("Entered the completionHandler")
            let json = try? JSONSerialization.jsonObject(with: data!, options: []) as! [String: Any]
            if let regions = json?["regions"] as? [[String: Any]] {
                //print(regions)
                self.currentRegion = (json?["region_id"] as? Int)!
                print(self.currentRegion)
                self.displayRegions(regions: regions)
            }
        }.resume()
        
    }
    
    // HTTP POST to update server based on button clicks
    func getRegionWinners() {
//        var request = URLRequest(url: URL(string: "http://hackcu.ohioporcelain.com/server.php?a=get_battle&region_id=\(self.currentRegion)"))
//        request.httpMethod = "POST"
//        let session = URLSession.shared
        
        
        let json = self.currentRegion
        
        do {
            let jsonData = try JSONSerialization.data(withJSONObject: json, options: .prettyPrinted)
            
            // create post request
            let endpoint: String = "http://hackcu.ohioporcelain.com/server.php?a=get_battle&region_id=\(self.currentRegion)"
            let session = URLSession.shared
            let url = NSURL(string: endpoint)!
            let request = NSMutableURLRequest(url: url as URL)
            request.httpMethod = "POST"
            
            // insert json data to the request
            request.httpBody = jsonData
            
            
            let task = session.dataTask(with: request as URLRequest){ data,response,error in
                if error != nil{
                    print(error?.localizedDescription)
                    return
                }
            }
            task.resume()
        } catch {
            print("bad things happened")
        }
        
    }
    
    //Updates display based on updated coordinates from HTTP GET
    func updateUI() {
       displayRegions(getCoordinates(self.currentRegion.latitude, self.currentRegion.longitude))
    }
    
    //Loops every 0.5 sec and updates the UI and server threads
    func loopUpdate() {
        {self.getRegionWinners()} ~> {self.updateUI()}
    }


}

// Delegates to handle events for the location manager.
extension MapViewController: CLLocationManagerDelegate {

  // Handle incoming location events.
  func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
    let location: CLLocation = locations.last!
    print("Location: \(location)")

    let camera = GMSCameraPosition.camera(withLatitude: location.coordinate.latitude,
                                          longitude: location.coordinate.longitude,
                                          zoom: zoomLevel)

    if mapView.isHidden {
      mapView.isHidden = false
      mapView.camera = camera
    } else {
      mapView.animate(to: camera)
    }
    getCoordinates(latitude: location.coordinate.latitude, longitude: location.coordinate.longitude)
  }

  // Handle authorization for the location manager.
  func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
    switch status {
    case .restricted:
      print("Location access was restricted.")
    case .denied:
      print("User denied access to location.")
      // Display the map using the default location.
      mapView.isHidden = false
    case .notDetermined:
      print("Location status not determined.")
    case .authorizedAlways: fallthrough
    case .authorizedWhenInUse:
      print("Location status is OK.")
    }
  }

  // Handle location manager errors.
  func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
    locationManager.stopUpdatingLocation()
    print("Error: \(error)")
  }
}
