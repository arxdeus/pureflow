import 'dart:async';

import 'package:pureflow/pureflow.dart';

void main() {
  final email = Store<String>('');
  final password = Store<String>('');
  final submitted = Store<bool>(false);

  final emailError = Computed<String?>(() {
    final value = email.value.trim();
    if (value.isEmpty) return 'Email is required';
    if (!value.contains('@')) return 'Email must contain @';
    return null;
  });

  final passwordError = Computed<String?>(() {
    final value = password.value;
    if (value.isEmpty) return 'Password is required';
    if (value.length < 8) return 'Password must be at least 8 characters';
    return null;
  });

  final canSubmit = Computed<bool>(
    () => emailError.value == null && passwordError.value == null,
  );

  final subscriptions = <StreamSubscription<Object?>>[
    emailError.listen((error) => print('email error: ${error ?? 'none'}')),
    passwordError.listen(
      (error) => print('password error: ${error ?? 'none'}'),
    ),
    canSubmit.listen((enabled) => print('submit enabled: $enabled')),
  ];

  void printState(String label) {
    print('\n$label');
    print('email: "${email.value}"');
    print('password length: ${password.value.length}');
    print('email error: ${emailError.value ?? 'none'}');
    print('password error: ${passwordError.value ?? 'none'}');
    print('submit enabled: ${canSubmit.value}');
  }

  printState('initial state');

  email.value = 'sam';
  password.value = 'short';
  printState('after partial input');

  batch(() {
    email.value = 'sam@example.com';
    password.value = 'correct horse';
    submitted.value = true;
  });
  printState('after submit batch');

  if (canSubmit.value && submitted.value) {
    print('submitted form for ${email.value}');
  }

  batch(() {
    email.value = '';
    password.value = '';
    submitted.value = false;
  });
  printState('after reset batch');

  for (final subscription in subscriptions) {
    subscription.cancel();
  }
  email.dispose();
  password.dispose();
  submitted.dispose();
  emailError.dispose();
  passwordError.dispose();
  canSubmit.dispose();
}
