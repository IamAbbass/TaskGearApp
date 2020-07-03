import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'values/value.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'todo_details.dart';
import 'package:intl/intl.dart';
import 'package:firebase_messaging/firebase_messaging.dart';

//import 'push_nofitications.dart';

class ToDoPage extends StatefulWidget {
  @override
  _ToDoPageState createState() => _ToDoPageState();
}

class _ToDoPageState extends State<ToDoPage> {

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging();

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

  Future<List<ToDo>> _fetchToDos() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    apiToken = prefs.getString('apiToken');
    final jobsListAPIUrl = '${base_url}/todos?api_token=${apiToken}';
    final response = await http.get(jobsListAPIUrl);
    if (response.statusCode == 200) {
      List jsonResponse = json.decode(response.body);
      return jsonResponse.map((appliance) => new ToDo.fromJson(appliance)).toList();
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

  var newFormat = DateFormat("dd-mm-yyyy");
  
  ListView _todoListView(data) {
    return ListView.separated(
        separatorBuilder: (context, index) => Divider(),
        itemCount: data.length,
        itemBuilder: (context, index) {
          return _tile(data[index]);
        });
  }
  
  ListTile _tile(ToDo todo) => ListTile(
    dense: false,
    key: Key(todo.id.toString()),
    title: Text(todo.name,
        style: TextStyle(
          fontWeight: FontWeight.bold,
          //color: Colors.teal,
        )
    ),
    leading: todo.done == 0 ? Icon(Icons.check_box_outline_blank) : Icon(Icons.check_box),
    subtitle: Text(todo.scheduled != null ? newFormat.format(DateTime.parse(todo.scheduled)).toString() : 'Not Scheduled'),
    onTap: (){
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => ToDoDetailsPage(
            todo: todo,
          ),
        ),
      );
    },
  );
  bool _todoLoading = false;

  String _message = '';

  Future<http.Response> saveFCMToken(String token) {
    return http.get(
      '${base_url}/fcm_token?api_token=${apiToken}&fcm_token=${token}',
    );
  }

  void getMessage() async{
     _firebaseMessaging.requestNotificationPermissions();
    _firebaseMessaging.configure();

    // For testing purposes print the Firebase Messaging token
    String token = await _firebaseMessaging.getToken();
    print("FirebaseMessaging token: $token");

    saveFCMToken(token);

    _firebaseMessaging.configure(
        onMessage: (Map<String, dynamic> message) async {
      print('on message $message');
      setState(() => _message = message["notification"]["title"]);
      _showDialog(message["notification"]["title"],message["notification"]["body"]);
    }, onResume: (Map<String, dynamic> message) async {
      print('on resume $message');
      setState(() => _message = message["notification"]["title"]);
      _showDialog(message["notification"]["title"],message["notification"]["body"]);
    }, onLaunch: (Map<String, dynamic> message) async {
      print('on launch $message');
      setState(() => _message = message["notification"]["title"]);
      _showDialog(message["notification"]["title"],message["notification"]["body"]);
    });

  }

  @override
  void initState() {
    super.initState();
    getMessage();
  }  

  void _showDialog(String title, String body) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        // return object of type Dialog
        return AlertDialog(
          title: new Text(title),
          content: new Text(body),
          actions: <Widget>[
            new FlatButton(
              child: new Text("Close"),
              onPressed: () {
                Navigator.of(context).pop();
              },
            ),
          ],
        );
      },
    );
  }



  Widget _loadTodos (){
    return FutureBuilder<List<ToDo>>(
      future: this._fetchToDos(),
      builder: (context, snapshot) {

        if (snapshot.hasData) {
          List<ToDo> applianceData = snapshot.data;
          return _todoListView(applianceData);
        } else if (snapshot.hasError) {
          return Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.center,
            children: <Widget>[
              GestureDetector(
                child: Center(
                  child: _todoLoading ? new CircularProgressIndicator() : Icon(Icons.cloud_off, size: 96,),
                ),
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

  bool _reload = false;

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
            title: Text("Task Gear"),
            actions: <Widget>[
              FlatButton(
                onPressed: (){
                  setState(() {
                    _reload = _reload ? false : true;  
                  });
                }, 
                child: Text("Refresh")
              )
            ],
          ),
          body: _loadTodos(),
          floatingActionButton: FloatingActionButton(
            child: Icon(Icons.add),
            onPressed: () async{
              _showDialog("Coming Soon","For now, create tasks from web app!");
            },
          ),
        ),
      ),
    );
  }
}