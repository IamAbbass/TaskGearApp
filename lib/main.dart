import 'package:flutter/material.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        // This is the theme of your application.
        //
        // Try running your application with "flutter run". You'll see the
        // application has a blue toolbar. Then, without quitting the app, try
        // changing the primarySwatch below to Colors.green and then invoke
        // "hot reload" (press "r" in the console where you ran "flutter run",
        // or simply save your changes to "hot reload" in a Flutter IDE).
        // Notice that the counter didn't reset back to zero; the application
        // is not restarted.
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  MyHomePage({Key key, this.title}) : super(key: key);
  final String title;

  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
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

  @override
  void initState() {
    super.initState();
  }

  TextStyle style = TextStyle(fontFamily: 'Montserrat', fontSize: 20.0);

  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool loading = false;

  @override
  Widget build(BuildContext context) {

    _performLogin() async {

      if(emailController.text.length == 0){
        _showDialog('Email is required to login', 'Please enter your email address');
      }else if(passwordController.text.length == 0){
        _showDialog('Password is required to login', 'Please enter your password');
      }else{
        setState(() {
          loading = true;
        });
        // make GET request
        String url = '${base_url}/signin?email=${emailController.text}&password=${passwordController.text}';

        try {
          Response response = await get(url);
          int statusCode = response.statusCode;
          Map<String, String> headers = response.headers;
          String contentType = headers['content-type'];
          String response_body = response.body;
          Map<String, dynamic> json = jsonDecode(response_body);
          setState(() {loading = false;});
          if(json['success']){
            apiToken    = json['api_token'];
            isLoggedin  = true;
            SharedPreferences prefs = await SharedPreferences.getInstance();
            await prefs.setBool('isLoggedin', isLoggedin);
            await prefs.setString('apiToken', apiToken);
            Navigator.push(
              context,
              MaterialPageRoute(builder: (context) => MyHomePage()),
            );
          }else{
            _showDialog(json['title'], json['message']);
            isLoggedin  = false;
          }
        } on SocketException catch (_) {
          _showDialog('No Internet!', 'Please check your network connection');
          setState(() {loading = false;});
        }
      }
    }

    final emailField = TextField(
      obscureText:false,
      style: style,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Email",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
      controller: emailController,

    );

    final passwordField = TextField(
      obscureText: true,
      style: style,
      decoration: InputDecoration(
          contentPadding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
          hintText: "Password",
          border:
          OutlineInputBorder(borderRadius: BorderRadius.circular(32.0))),
      controller: passwordController,
      onSubmitted: (String str){_performLogin();},

    );

    final loginButon = Material(
      elevation: 10.0,
      borderRadius: BorderRadius.circular(30.0),
      child: MaterialButton(
        minWidth: MediaQuery.of(context).size.width,
        padding: EdgeInsets.fromLTRB(20.0, 15.0, 20.0, 15.0),
        onPressed: _performLogin,
        child: Text("Login",
          textAlign: TextAlign.center,
          style: style.copyWith(fontWeight: FontWeight.bold),
        ),
      ),

    );

    return Scaffold(
      body: WillPopScope(
          onWillPop: () async{Future.value(false);},
          child: SingleChildScrollView(
            child: Center(
              child: Container(
                child: Padding(
                  padding: const EdgeInsets.all(36.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      SizedBox(height: 25.0),
                      SizedBox(
                        height: 120,
                        child: Image.asset(
                          "assets/images/logo.png",
                          fit: BoxFit.fitWidth,
                        ),
                      ),

                      Text("Smart Home", style: TextStyle(fontFamily: 'Montserrat', fontSize: 32.0, fontWeight: FontWeight.bold),),
                      Text("Please Login", style: TextStyle(fontFamily: 'Montserrat', fontSize: 16.0),),
                      SizedBox(height: 20.0),
                      emailField,
                      SizedBox(height: 25.0),
                      passwordField,
                      SizedBox(
                        height: 35.0,
                      ),
                      loading ? new CircularProgressIndicator() : loginButon,
                      SizedBox(
                        height: 15.0,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          )
      ),
    );
  }
}
