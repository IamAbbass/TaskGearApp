import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'values/value.dart';
import 'package:flutter_html_view/flutter_html_view.dart';

class ToDoDetailsPage extends StatefulWidget {
  final ToDo todo;
  ToDoDetailsPage({this.todo});
  @override
  _ToDoDetailsPageState createState() => _ToDoDetailsPageState();
}

class _ToDoDetailsPageState extends State<ToDoDetailsPage> {
  final GlobalKey<ScaffoldState> _scaffoldstate = new GlobalKey<ScaffoldState>();

  @override
  void initState() {
    super.initState();
  }  

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      key: _scaffoldstate,
      body: Scaffold(      
        appBar: AppBar(
          title: Text(widget.todo.name),
        ),
        body: Padding(
          padding: EdgeInsets.all(5),
          
          child: widget.todo.details == null ? Center(child: Text("No Details Added"),) : HtmlView(
            data: (widget.todo.details),          
            scrollable: true, //false to use MarksownBody and true to use Marksown
          ),
        )
      ),
    );
  }
}