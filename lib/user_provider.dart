import 'package:flutter/material.dart';
import 'user.dart'; // your User model

class UserProvider extends ChangeNotifier {
  User? _currentUser;

  User? get currentUser => _currentUser;
  String? get userId => _currentUser?.userId;
  String? get role => _currentUser?.role;
  String? get email => _currentUser?.email;
  String? get fullname => _currentUser?.fullname;

  void setUser(User user) {
    _currentUser = user;
    notifyListeners();
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }

  bool get isLoggedIn => _currentUser != null;
}