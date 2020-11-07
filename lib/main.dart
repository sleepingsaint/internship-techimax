import 'dart:math';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:location/location.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp();
  runApp(MyHomePage());
}

class MyHomePage extends StatelessWidget {
  const MyHomePage({Key key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Container(
      child: MaterialApp(
        home: MapWidget(),
      ),
    );
  }
}

class LocationClass{
  double latitude;
  double longitude;

  LocationClass(double latitude, double longitude){
    this.latitude = latitude;
    this.longitude = longitude;
  }

  double getDistance(LocationData loc){
    return sqrt(pow(longitude - loc.longitude, 2) + pow(latitude - loc.latitude, 2));
  }
}

class MapWidget extends StatefulWidget {
  MapWidget({Key key}) : super(key: key);

  @override
  _MapWidgetState createState() => _MapWidgetState();
}

class _MapWidgetState extends State<MapWidget> {
  CollectionReference _geopointers = FirebaseFirestore.instance.collection("geopointers");
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

  String _userMessageToken;
  Map<String, dynamic> _message;
  Location location = new Location();
  List<LocationClass> _locationLocations = new List<LocationClass>();
  bool _serviceEnabled = false;
  PermissionStatus _permissionGranted = PermissionStatus.denied;

  @override
  void initState() { 
    super.initState();

    location.serviceEnabled().then((val){
      if(val){
        setState(() {
          _serviceEnabled = val;
        });
      }else{
        _requestService().then((_req){
          setState(() {
            _serviceEnabled = _req;
          });
        });
      }
    });

    location.hasPermission().then((val){
      if(val == PermissionStatus.granted){
        setState(() {
          _permissionGranted = val;
        });
      }else{
        _requestPermission().then((_perm){
          setState(() {
            _permissionGranted = _perm;
          });
        });
      }
    });

    _firebaseMessaging.getToken().then((_token){
      setState(() {
        _userMessageToken = _token;
      });
    });


    _firebaseMessaging.configure(
      onMessage: (Map<String, dynamic> _msg) async {
        print(_msg);
        setState(() {
          _message = _msg["notification"];
        });
      },
      onBackgroundMessage: myBackgroundMessageHandler,
      onLaunch: (Map<String, dynamic> message) async {
        print("onLaunch: $message");
      },
      onResume: (Map<String, dynamic> message) async {
        print("onResume: $message");
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
        body: Center(
         child: _serviceEnabled && _permissionGranted == PermissionStatus.granted ? StreamBuilder<LocationData>(
           stream: location.onLocationChanged,
           builder: (BuildContext context, AsyncSnapshot<LocationData> snapshot){
            if (snapshot.hasError) {
              return Text("oops! something went wrong");
            }else {
              switch (snapshot.connectionState) {
                case ConnectionState.none:
                  return Text("Connecting....");
                  break;
                case ConnectionState.waiting:
                  return Text("Loading...");
                  break;
                case ConnectionState.active:
                  if(snapshot.hasData && _userMessageToken != null){
                    LocationData loc = snapshot.data;

                    if(_locationLocations.length == 0){  
                      if(loc.latitude == null && loc.longitude == null){
                        return Text("Loading");
                      }
                      _locationLocations.add(new LocationClass(loc.latitude + 1.0, loc.longitude));
                      _locationLocations.add(new LocationClass(loc.latitude - 1.0, loc.longitude));
                      _locationLocations.add(new LocationClass(loc.latitude, loc.longitude + 1.0));
                      _locationLocations.add(new LocationClass(loc.latitude, loc.longitude - 1.0));          

                      // _geopointers.doc(_userMessageToken).set({
                      //   "current_location": {"latitude" : loc.latitude, "logitude" : loc.longitude},
                      //   "neighbors": {
                      //     "1": {"latitude" : loc.latitude + 1.0, "longitude" : loc.longitude},
                      //     "2": {"latitude" : loc.latitude - 1.0, "longitude" : loc.longitude},
                      //     "3": {"latitude" : loc.latitude, "longitude" : loc.longitude + 1.0},
                      //     "4": {"latitude" : loc.latitude, "longitude" : loc.longitude - 1.0}
                      //   },
                      //   "messageToken": _userMessageToken
                      // });    
                      _geopointers.doc(_userMessageToken).set({
                        "current_location": GeoPoint(loc.latitude, loc.longitude),
                        "neighbors": [
                          GeoPoint(loc.latitude + 1.0, loc.longitude),
                          GeoPoint(loc.latitude - 1.0, loc.longitude),
                          GeoPoint(loc.latitude, loc.longitude + 1.0),
                          GeoPoint(loc.latitude, loc.longitude - 1.0)
                        ],
                        "messageToken": _userMessageToken
                      }); 
                      return Text(snapshot.data.longitude.toString());
                    }

                    // _geopointers.doc(_userMessageToken).update({"current_location": {"latitude" : loc.latitude, "longitude": loc.longitude}});
                    _geopointers.doc(_userMessageToken).update({"current_location": GeoPoint(loc.latitude, loc.longitude)});
                    List<TableRow> _locations = new List<TableRow>();

                    _locations.add(TableRow(
                      children: [
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("location Co-ordinates"),
                        ),
                        Padding(
                          padding: const EdgeInsets.all(8.0),
                          child: Text("Distance"),
                        )
                      ]
                    ));

                    _locations.addAll(_locationLocations.asMap().entries.map((e){
                      // int index = e.key + 1;
                      LocationClass _location = e.value;
                      double _dist = _location.getDistance(loc);
                      // if(_dist <= 0.6){
                      //   _sendNotification(index);
                      // }
                      return TableRow(
                        children: [
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text("${_location.latitude}, ${_location.longitude}"),
                          ),
                          Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Text(_dist.toString()),
                          )
                        ]
                      );
                    }).toList());

                    Widget _table = Table(
                      border: TableBorder.all(),
                      children: _locations,
                    );

                    return Padding(
                      padding: EdgeInsets.all(8.0), 
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          _message != null ? Text(_message["title"]) : SizedBox(height: 0),
                          Text("Current Location"),
                          Text("${loc.latitude}, ${loc.longitude}"),
                          SizedBox(height: 10.0),
                          _table
                        ]),
                      );
                  }

                  return Text("loading...");

                  break;

                case ConnectionState.done:
                  return Text("Connection ended");
                  break;
              }
            }
          }
          ) : Text("Enable the location and give the permissions"),
      ),
    );
  }

  Future<bool> _requestService() async {
    bool _req = await location.requestService();
    return _req;
  }

  Future<PermissionStatus> _requestPermission() async {
    PermissionStatus _permission = await location.requestPermission();
    return _permission;
  }

  void _sendNotification(int index){
    print("Went close to location $index");
  }

  Future<void> _showMyDialog(Map<String, dynamic> _message) async {
    return showDialog<void>(
      context: context,
      barrierDismissible: false, // user must tap button!
      builder: (BuildContext context) {
        return AlertDialog(
          title: Text(_message['title']),
          content: SingleChildScrollView(
            child: ListBody(
              children: <Widget>[
                Text(_message['body']),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              child: Text('Close'),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }

}
Future<dynamic> myBackgroundMessageHandler(Map<String, dynamic> message) async {
  if (message.containsKey('data')) {
    // Handle data message
    final dynamic data = message['data'];
  }

  if (message.containsKey('notification')) {
    // Handle notification message
    final dynamic notification = message['notification'];
  }

  // Or do other work.
}