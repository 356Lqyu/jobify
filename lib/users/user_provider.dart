import 'package:flutter/material.dart';
import 'package:jobify/users/users.dart';
import 'package:jobify/data/user_repository.dart';

/// Use to manage user state throughout the application
/// It implement cache first (delegated to UserRepository) , optimize update for immediate UI feedback , auto rollback on server error
class UserProvider extends ChangeNotifier {
  // get current authenticated user data
  Users? _currentUser;
  final UserRepository _userRepo = UserRepository();     // this repository will handle all supabase and cache interaction
  bool _isLoading = false;

  Users? get currentUser => _currentUser;
  bool get isLoading => _isLoading;

  // load current user from cache / server
  Future<void> loadUser({String? userId, bool forceRefresh = false}) async {
    _isLoading = true;
    notifyListeners();

    try {
      _currentUser = await _userRepo.getCurrentUser(forceRefresh: forceRefresh);
    } finally {
      _isLoading = false;
      notifyListeners();
    }
  }

  // Update user info
  Future<void> updateUser(Map<String, dynamic> updates) async {
    if (_currentUser == null) return;

    // update UI immediately (notify listener then UI will show new value)
    final oldUser = _currentUser;
    _currentUser = _currentUser!.copyWith(
      fullname: updates['fullname'] ?? _currentUser!.fullname,
      phone: updates['phone'] ?? _currentUser!.phone,
      profileImageUrl: updates['profile_image_url'] ?? _currentUser!.profileImageUrl,
    );
    notifyListeners();

    try {
      await _userRepo.updateUser(_currentUser!.userId, updates);
      await loadUser(forceRefresh: true);         // Refresh from server
    } catch (e) {
      _currentUser = oldUser;         // If error then revert to old value
      notifyListeners();
      rethrow;
    }
  }

  // update profile image url
  Future<void> updateProfileImage(String imageUrl) async {
    await updateUser({'profile_image_url': imageUrl});
  }

  Future<void> refreshUser() async {
    await loadUser(forceRefresh: true);
  }

  void clearUser() {
    _currentUser = null;
    notifyListeners();
  }
}