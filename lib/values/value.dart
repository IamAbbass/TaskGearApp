import 'package:flutter/material.dart';

bool isLoggedin   = false; //Shared Pref
String apiToken   = ''; //Shared Pref

//String server_url = "http://192.168.0.113:8000";
String server_url = "https://taskgear.zeddevelopers.com";
String base_url   = "${server_url}/api";

class ToDo {
  final int id;
  final String name;
  final String details;
  final int done;
  final int done_by;
  final String done_at;
  final String scheduled;
  final int company_id;
  final int user_id;
  final int assigned_to;
  final int project_id;
  final int milestone_id;
  final int is_deleted;
  final String created_at;
  final String updated_at;

  ToDo({
    this.id,
    this.name,
    this.details,
    this.done,
    this.done_by,
    this.done_at,
    this.scheduled,
    this.company_id,
    this.user_id,
    this.assigned_to,
    this.project_id,
    this.milestone_id,
    this.is_deleted,
    this.created_at,
    this.updated_at,
  });

  factory ToDo.fromJson(Map<String, dynamic> json) {
    return ToDo(
      id : json['id'] as int,
      name : json['name'] as String,
      details : json['details'] as String,
      done : json['done'] as int,
      done_by : json['done_by'] as int,
      done_at : json['done_at'] as String,
      scheduled : json['scheduled'] as String,
      company_id : json['company_id'] as int,
      user_id : json['user_id'] as int,
      assigned_to : json['assigned_to'] as int,
      project_id : json['project_id'] as int,
      milestone_id : json['milestone_id'] as int,
      is_deleted : json['is_deleted'] as int,
      created_at : json['created_at'] as String,
      updated_at : json['updated_at'] as String,
    );
  }
}
