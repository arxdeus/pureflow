import 'dart:async';

import 'package:pureflow/pureflow.dart';

Future<void> main() async {
  final session = AuthSession();

  void printUser() =>
      print('user: ${session.user.value?.email ?? 'signed out'}');
  void printLoading() => print('loading: ${session.isLoading.value}');
  void printAuthenticated() =>
      print('authenticated: ${session.isAuthenticated.value}');

  session.user.addListener(printUser);
  session.isLoading.addListener(printLoading);
  session.isAuthenticated.addListener(printAuthenticated);

  print('initial authenticated: ${session.isAuthenticated.value}');

  final firstLogin = session.login('alex@example.com');
  final duplicateLogin = session.login('alex@example.com');
  await Future.wait(<Future<void>>[firstLogin, duplicateLogin]);

  print('active user: ${session.user.value?.email ?? 'none'}');

  await session.logout();
  print('active user after logout: ${session.user.value?.email ?? 'none'}');

  session.user.removeListener(printUser);
  session.isLoading.removeListener(printLoading);
  session.isAuthenticated.removeListener(printAuthenticated);
  await session.dispose();
}

class AuthSession {
  final Store<User?> _user = Store<User?>(null);
  final Store<bool> _isLoading = Store<bool>(false);
  final Pipeline _pipeline = Pipeline(transformer: restartable());

  late final Computed<bool> _isAuthenticated = Computed<bool>(
    () => _user.value != null,
  );

  ValueObservable<User?> get user => _user;
  ValueObservable<bool> get isLoading => _isLoading;
  ValueObservable<bool> get isAuthenticated => _isAuthenticated;

  Future<void> login(String email) {
    return _pipeline.run<void>((context) async {
      _isLoading.value = true;
      print('logging in $email');
      await Future<void>.delayed(const Duration(milliseconds: 80));

      if (!context.isActive) {
        print('stale login ignored for $email');
        _isLoading.value = false;
        return;
      }

      batch(() {
        _user.value = User(email: email);
        _isLoading.value = false;
      });
    }, debugLabel: 'login:$email');
  }

  Future<void> logout() {
    return _pipeline.run<void>((context) async {
      _isLoading.value = true;
      print('logging out');
      await Future<void>.delayed(const Duration(milliseconds: 40));

      if (!context.isActive) {
        print('stale logout ignored');
        _isLoading.value = false;
        return;
      }

      batch(() {
        _user.value = null;
        _isLoading.value = false;
      });
    }, debugLabel: 'logout');
  }

  Future<void> dispose() async {
    await _pipeline.dispose();
    _isAuthenticated.dispose();
    _isLoading.dispose();
    _user.dispose();
  }
}

class User {
  final String email;

  const User({required this.email});
}
