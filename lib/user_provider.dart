import 'package:flutter/material.dart';
import 'user.dart';

//  any data change need inform observer to change ui
class UserProvider extends ChangeNotifier{
  final List<User> registeredUsers = [];

  void add(User user){
    registeredUsers.add(user);
    notifyListeners();
  }

  void remove(User user){
    registeredUsers.remove(user);
    notifyListeners();
  }

  void update(User updatedUser) {
    int index = registeredUsers.indexWhere(
          (user) => user.email == updatedUser.email,
    );

    if (index != -1) {
      registeredUsers[index] = updatedUser;
      notifyListeners();
    }
  }
}