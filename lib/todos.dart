import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:dynamic_theme/dynamic_theme.dart';
import 'values/value.dart';
import 'auth/auth_state.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:transparent_image/transparent_image.dart';
import 'package:mqtt_client/mqtt_client.dart' as mqtt;
import 'package:connectivity/connectivity.dart';
import 'package:cached_network_image/cached_network_image.dart';

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {

  mqtt.MqttClient client;
  mqtt.MqttConnectionState connectionState;
  Icon mqttCloudConnection = Icon(Icons.cloud);
  StreamSubscription subscription;

  void _subscribeToTopic(String topic) {
    if (connectionState == mqtt.MqttConnectionState.connected) {
      client.subscribe(topic, mqtt.MqttQos.atLeastOnce);
    }
  }

  void _connect() async {
    if(client == null) {
      print("client is null initially");
    }else{
      print("client is not null initially");
    }

    client = mqtt.MqttClient(broker, '');
    client.port = port;
    client.useWebSocket = false;
    client.logging(on: true);
    client.keepAlivePeriod = 30;
    client.onDisconnected = _onDisconnected;
    final mqtt.MqttConnectMessage connMess = mqtt.MqttConnectMessage()
        .withClientIdentifier(clientIdentifier)
        .startClean() // Non persistent session for testing
        .keepAliveFor(30)
        .withWillQos(mqtt.MqttQos.atLeastOnce);
    print('[MQTT client] MQTT client connecting....');
    setState(() {
      mqttCloudConnection = Icon(Icons.cloud_upload);
    });
    client.connectionMessage = connMess;


    print('[MQTT client] ERROR: MQTT client connection failed - '
        'disconnecting, state is ${client.connectionState}');
    //_disconnect();
    setState(() {
      mqttCloudConnection = Icon(Icons.cloud_off);
    });

    await client.connect(username, passwd);
    print("wait done");


    if(client == null){
      print('client id null');
    }else{
      if (client.connectionState == mqtt.MqttConnectionState.connected) {
        _showSnackBar("You are connected!");
        setState(() {
          _applianceLoading = false;
        });
        print("connected");


        setState(() {
          connectionState = client.connectionState;
          mqttCloudConnection = Icon(Icons.cloud_done);
        });
        subscription = client.updates.listen(_onMessage);
        //_subscribeToTopic("app");
      }else{
        print("not connected");
      }
    }
  }

  void _onDisconnected() {
    //_connect();

    print('[MQTT client] _onDisconnected');
    setState(() {
      //topics.clear();
      connectionState = client.connectionState;
      client = null;
      try{
        subscription.cancel();
      }catch(e){

      }
      subscription.cancel();
      subscription = null;
      mqttCloudConnection = Icon(Icons.cloud_off);
    });
    print('[MQTT client] MQTT client disconnected');
  }

  void _onMessage(List<mqtt.MqttReceivedMessage> event) {
    final mqtt.MqttPublishMessage recMess = event[0].payload as mqtt.MqttPublishMessage;
    final String message =  mqtt.MqttPublishPayload.bytesToStringAsString(recMess.payload.message);

    String topic = event[0].topic;
    if(topic.contains('/')){
      String endpoint = topic.substring(topic.indexOf('/')+1, topic.length);


      if(endpoint == "callback" || endpoint == "gpiostatus/callback"){
        Map<String, dynamic> message_json = json.decode(message);
        int gpio   = message_json['gpio'];
        int action = message_json['action'];
        //{"command": 2,"action": 0,"trigger": 0,"delay": 0.0,"gpio": 17}
        _showSnackBar('GPIO:${gpio} is ${action == 1 ? 'ON' : 'OFF'}');

        //_showSnackBar(listAppliances.where((appliance) => appliance['gpio'] == gpio).toString());

//        if(status == "on"){
////          if(!appliancesOn.contains(gpio)){
////            setState(() {
////              appliancesOn.add(gpio); //add
////            });
////          }
//          if(endpoint == "callback"){
//            _showSnackBar('Appliance switched ON');
//          }
//        }else if(status == "off"){
////          try {
////            setState(() {
////              appliancesOn.remove(gpio);
////            });
////          } catch (e) {
////            print(e);
////          }
//          if(endpoint == "callback"){
//            _showSnackBar('Appliance switched OFF');
//          }
//        }else if(status == "triggered"){
//          if(endpoint == "callback"){
//            _showSnackBar('Appliance triggered');
//          }
//        }

      }
    }
  }


  final GlobalKey<ScaffoldState> _scaffoldstate = new GlobalKey<ScaffoldState>();

  List<int> appliancesOn = <int>[];
  List<int> appliancesLoading = <int>[];

  List<String> subscribedSerials = <String>[];
  List<int> initialStatus = <int>[];


  List listAppliances;

  _logOut() async{
    SharedPreferences prefs = await SharedPreferences.getInstance();
    await prefs.setBool('isLoggedin', false);
    isLoggedin = false;
    Navigator.pushNamed(context, '/login');
  }

  Future<List<Appliance>> _fetchAppliances() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    apiToken = prefs.getString('apiToken');
    final jobsListAPIUrl = '${base_url}/appliance?api_token=${apiToken}';
    final response = await http.get(jobsListAPIUrl);
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
//      setState(() {
//        listAppliances = jsonResponse;
//      });
      return jsonResponse.map((appliance) => new Appliance.fromJson(appliance)).toList();
    } else {
      // throw Exception('Failed to load data from API');
    }
  }

  void _showSnackBar(String text) {
    _scaffoldstate.currentState.showSnackBar(new SnackBar(
        duration: Duration(seconds: 1) ,
        action: SnackBarAction(label: 'Okay',
          onPressed: () {
            // Some code to undo the change.
          },
        ),
        content: new Text(text))
    );
  }

  Future<List<Appliance>> _sendCommand(int id, String name, bool status, int trigger, double delay, int gpio, String serial) async {

    if (connectionState != mqtt.MqttConnectionState.connected) {
      _showSnackBar("Reconnecting ..");
      _connect();
    }

    int action = status ? 1 : 0;
    final mqtt.MqttClientPayloadBuilder builder = mqtt.MqttClientPayloadBuilder();
    builder.addString('{"command": ${id},"action": ${action},"trigger": ${trigger},"delay": ${delay},"gpio": ${gpio}}');
    client.publishMessage(serial,  mqtt.MqttQos.atLeastOnce, builder.payload);

    _showSnackBar("Command Sent ..");

    if(status){//on karo
      if(!appliancesOn.contains(gpio)){
        setState(() {
          appliancesOn.add(gpio); //add
        });
      }
    }else{ //off karo
      try {
        setState(() {
          appliancesOn.remove(gpio);
        });
      } catch (e) {
        print(e);
      }
    }
  }

  _displayDialog(BuildContext context,int id, String name, bool status, int trigger, double delay, int gpio, String serial) async {
    return showDialog(
        context: context,
        builder: (context) {
          return AlertDialog(
            title: Text('Are you sure ?'),
            actions: <Widget>[
              new FlatButton(
                child: new Text('Cancel'),
                onPressed: () {
                  Navigator.of(context).pop();
                },
              ),
              new FlatButton(
                child: new Text('Yes'),
                onPressed: () {
                  _sendCommand(id, name, status, trigger, delay, gpio, serial);
                  Navigator.of(context).pop();
                },
              ),

            ],
          );
        });
  }


  ListView _applianceListView(data) {

    return ListView.separated(
        separatorBuilder: (context, index) => Divider(),
        itemCount: data.length,
        itemBuilder: (context, index) {

          if(!subscribedSerials.contains(data[index].serial)){
            //callback when command is sent
            _subscribeToTopic(data[index].serial+"/callback");
            //callback when we need to know the status
            _subscribeToTopic(data[index].serial+"/gpiostatus/callback");
            subscribedSerials.add(data[index].serial);
          }

//      if(!initialStatus.contains(data[index].gpio)){
//        final mqtt.MqttClientPayloadBuilder builder = mqtt.MqttClientPayloadBuilder();
//        builder.addString('{"gpio": ${data[index].gpio}}');
//        String topic = "${data[index].serial}/gpiostatus";
//        client.publishMessage(topic,  mqtt.MqttQos.atLeastOnce, builder.payload);
//        initialStatus.add(data[index].gpio);
//      }

          return _tile(data[index].id, data[index].name, data[index].status, data[index].trigger, data[index].delay, data[index].gpio, data[index].serial, data[index].icon, data[index].gpio_type_id);
        });
  }

  ListTile _tile(int id, String name, bool status, int trigger, double delay, int gpio, String serial, String icon, int gpio_type_id) => ListTile(
    key: Key(id.toString()),
    title: Text(name,
        style: TextStyle(
          fontWeight: FontWeight.w500,
          fontSize: 20,
        )
    ),
    leading:
    CachedNetworkImage(
      placeholder: (context, url) => CircularProgressIndicator(),
      imageUrl:
      '${server_url}/icons/'+icon,
      fadeInDuration: Duration(milliseconds: 300),
      height: 40,
    ),
    //subtitle: Text("GPIO:${gpio}"),
    trailing: trigger == 0 ? Wrap(
      spacing: 12, // space between two icons
      children: <Widget>[
        IconButton(icon: Icon(Icons.cancel, size: 36),onPressed: (){
          _sendCommand(id, name, false, trigger, delay, gpio, serial);
        },), // icon-1
        IconButton(icon: Icon(Icons.check_circle, size: 36),onPressed: (){
          _sendCommand(id, name, true, trigger, delay, gpio, serial);
        },), // icon-1/ icon-2
      ],
    ): RaisedButton(
      onPressed: (){
        _displayDialog(context, id, name, true, trigger, delay, gpio, serial);
      },
      child: Text("OPEN"),
    ),
//    trailing: trigger == 0 ? new Switch(value: appliancesOn.contains(gpio), onChanged: (status){
//      _sendCommand(id, name, status, trigger, delay, gpio, serial);
//    }) : RaisedButton(
//      onPressed: (){
//        _displayDialog(context, id, name, true, trigger, delay, gpio, serial);
//      },
//      child: Text("OPEN"),
//    ),
//    onTap: (){
//      if(trigger == 0){
//        //_subscribeToTopic(serial+"/callback");
//        _sendCommand(id, name, !appliancesOn.contains(gpio), trigger, delay, gpio, serial);
//      }else{
//        _displayDialog(context, id, name, true, trigger, delay, gpio, serial);
//      }
//    },
    onLongPress: (){
//      _subscribeToTopic(serial+"/gpiostatus/callback");
////
////      final mqtt.MqttClientPayloadBuilder builder = mqtt.MqttClientPayloadBuilder();
////      builder.addString('{"gpio": ${gpio}}');
////      String topic = "${serial}/gpiostatus";
////      client.publishMessage(topic,  mqtt.MqttQos.atLeastOnce, builder.payload);

      _showSnackBar("GPIO:${gpio}");
    },
  );
  int _refreshAppliances = 0;
  bool _applianceLoading = false;

  @override
  void initState() {
    super.initState();
    subscription = Connectivity().onConnectivityChanged.listen((ConnectivityResult result) {
      if (result != ConnectivityResult.none) {
        _connect();
      }
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch(state) {
      case AppLifecycleState.resumed:
        _reconnect();
        break;
      case AppLifecycleState.inactive:
        _reconnect();
        break;
      case AppLifecycleState.paused:
        _reconnect();
        break;
    }
  }


  //@override
  //dispose() {
  //  super.dispose();
  //  subscription.cancel();
  //}

  void changeBrightness() {
    DynamicTheme.of(context).setBrightness(Theme.of(context).brightness == Brightness.dark? Brightness.light: Brightness.dark);
//    DynamicTheme.of(context).setThemeData(new ThemeData(
//        primarySwatch: Theme.of(context).primaryColorLight == Colors.black? Colors.black: Colors.black
//    ));
  }

  Choice _selectedChoice = choices[0];
  void _select(Choice choice) {
    setState(() {
      _selectedChoice = choice;
      if(_selectedChoice.toString() == "Profile"){
        Navigator.pushNamed(context, '/profile');
      }
      else if(_selectedChoice.toString() == "Settings"){
        Navigator.pushNamed(context, '/settings');
      }
      else if(_selectedChoice.toString() == "Dark/Light Mode"){
        changeBrightness();
      }
      else if(_selectedChoice.toString() == "Logout"){
        showDialog(
          context: context,
          builder: (BuildContext context) {
            // return object of type Dialog
            return AlertDialog(
              title: new Text("Are you sure ?"),
              content: new Text("Are you sure you want to log out ?"),
              actions: <Widget>[
                new FlatButton(
                  child: new Text("Yes"),
                  onPressed: () {
                    _logOut();
                  },
                ),
              ],
            );
          },
        );

      }
    });
  }

  int _selectedIndex = 0;
  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      print(_selectedIndex);
    });
  }

  Widget _loadAppliances (){
    return FutureBuilder<List<Appliance>>(
      future: this._fetchAppliances(),
      builder: (context, snapshot) {

        if (snapshot.hasData) {
          List<Appliance> applianceData = snapshot.data;
          return _applianceListView(applianceData);
        } else if (snapshot.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: _applianceLoading ? new CircularProgressIndicator() : Icon(Icons.cloud_off, size: 96,),
                ),
                onTap: _reconnect,
              ),
              Center(
                child: Padding(
                  padding: EdgeInsets.all(12),
                  child: Text("Reconnecting ..", textAlign: TextAlign.center,),
                ),
              )
            ],
          );
        }
        return LinearProgressIndicator();
      },
    );
  }

  void _reconnect(){
    setState(() {
      _applianceLoading = true;
    });
    this._refreshAppliances = this._refreshAppliances+1;

    if (connectionState == mqtt.MqttConnectionState.connected) {
      _showSnackBar("You are connected!");
      setState(() {
        _applianceLoading = false;
      });
    }else{
      _showSnackBar("Reconnecting ..");
      _connect();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async{
        Future.value(false);
      },
      child: Scaffold(
        key: _scaffoldstate,
        body: Scaffold(
          //drawer: appDrawer(context),
          appBar: AppBar(
            automaticallyImplyLeading: false,
            title: Text("Smart Home"),
            actions: <Widget>[
              PopupMenuButton<Choice>(
                onSelected: _select,
                //icon: Icon(Icons.account_circle),
                itemBuilder: (BuildContext context) {
                  return choices.map((Choice choice) {
                    return PopupMenuItem<Choice>(
                      value: choice,
                      child: Text(choice.title),
                    );
                  }).toList();
                },
              ),
            ],
          ),
          body: _loadAppliances(),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _reconnect,
          tooltip: 'Connection',
          child: mqttCloudConnection,
        ),
      ),
    );
  }
}