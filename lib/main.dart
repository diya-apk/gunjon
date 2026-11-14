import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

// ---------------- Firebase সেটিংস ----------------

const FirebaseOptions webOptions = FirebaseOptions(
  apiKey: 'AIzaSyB2gys0Qe4G2oYB8R1PR1f5-oBbl8xbRu8',
  appId: '1:686538696549:web:1a94aad7515becba4d638c',
  messagingSenderId: '686538696549',
  projectId: 'gunjon-143',
  authDomain: 'gunjon-143.firebaseapp.com',
  storageBucket: 'gunjon-143.firebasestorage.app',
);

const FirebaseOptions androidOptions = FirebaseOptions(
  apiKey: 'AIzaSyDhAITcMvzua7_3MftNcO79lkxXiewHp7o',
  appId: '1:686538696549:android:c1570a67e3f0f0db4d638c',
  messagingSenderId: '686538696549',
  projectId: 'gunjon-143',
  storageBucket: 'gunjon-143.firebasestorage.app',
);

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: kIsWeb ? webOptions : androidOptions,
  );
  runApp(const GunjonApp());
}

// ---------------- অ্যাপ ----------------

class GunjonApp extends StatelessWidget {
  const GunjonApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gunjon',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF6C4AB6)),
      ),
      home: const AuthGate(),
    );
  }
}

// লগইন করা আছে কিনা দেখে সঠিক পেজ দেখায়
class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        if (snapshot.hasData) {
          return const HomePage();
        }
        return const LoginPage();
      },
    );
  }
}

// ---------------- লগইন / সাইন আপ ----------------

class LoginPage extends StatefulWidget {
  const LoginPage({super.key});

  @override
  State<LoginPage> createState() => _LoginPageState();
}

class _LoginPageState extends State<LoginPage> {
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isSignUp = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String _bangla(FirebaseAuthException e) {
    switch (e.code) {
      case 'invalid-email':
        return 'ইমেইলটি সঠিক নয়।';
      case 'user-not-found':
      case 'wrong-password':
      case 'invalid-credential':
        return 'ইমেইল বা পাসওয়ার্ড ভুল।';
      case 'email-already-in-use':
        return 'এই ইমেইল দিয়ে আগেই অ্যাকাউন্ট খোলা হয়েছে।';
      case 'weak-password':
        return 'পাসওয়ার্ড কমপক্ষে ৬ অক্ষরের দিন।';
      case 'network-request-failed':
        return 'ইন্টারনেট সংযোগ নেই।';
      case 'account-exists-with-different-credential':
        return 'এই ইমেইলে অন্য পদ্ধতিতে অ্যাকাউন্ট খোলা আছে।';
      case 'operation-not-allowed':
        return 'Firebase-এ Google লগইন এখনো চালু করা হয়নি।';
      case 'unauthorized-domain':
        return 'এই ওয়েবসাইটের ঠিকানা Firebase-এ অনুমোদিত নয়।';
      default:
        return 'সমস্যা হয়েছে (${e.code})';
    }
  }

  Future<void> _submit() async {
    final name = _nameController.text.trim();
    final email = _emailController.text.trim();
    final password = _passwordController.text;

    if (email.isEmpty || password.isEmpty) {
      setState(() => _error = 'ইমেইল ও পাসওয়ার্ড লিখুন।');
      return;
    }
    if (_isSignUp && name.isEmpty) {
      setState(() => _error = 'আপনার নাম লিখুন।');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isSignUp) {
        final cred = await FirebaseAuth.instance
            .createUserWithEmailAndPassword(email: email, password: password);
        await cred.user!.updateDisplayName(name);
        await FirebaseFirestore.instance
            .collection('users')
            .doc(cred.user!.uid)
            .set({
          'name': name,
          'email': email,
          'createdAt': FieldValue.serverTimestamp(),
        });
      } else {
        await FirebaseAuth.instance
            .signInWithEmailAndPassword(email: email, password: password);
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = _bangla(e));
    } catch (e) {
      setState(() => _error = 'সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _googleSignIn() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final provider = GoogleAuthProvider()
        ..addScope('email')
        ..setCustomParameters({'prompt': 'select_account'});

      final UserCredential cred = kIsWeb
          ? await FirebaseAuth.instance.signInWithPopup(provider)
          : await FirebaseAuth.instance.signInWithProvider(provider);

      final user = cred.user;
      if (user != null) {
        final data = <String, dynamic>{
          'name': (user.displayName != null && user.displayName!.isNotEmpty)
              ? user.displayName
              : (user.email ?? 'নামহীন'),
          'email': user.email ?? '',
          'photoUrl': user.photoURL ?? '',
        };
        if (cred.additionalUserInfo?.isNewUser ?? false) {
          data['createdAt'] = FieldValue.serverTimestamp();
        }
        await FirebaseFirestore.instance
            .collection('users')
            .doc(user.uid)
            .set(data, SetOptions(merge: true));
      }
    } on FirebaseAuthException catch (e) {
      const ignored = [
        'popup-closed-by-user',
        'cancelled-popup-request',
        'web-context-canceled',
        'web-context-cancelled',
      ];
      if (mounted && !ignored.contains(e.code)) {
        setState(() => _error = _bangla(e));
      }
    } catch (e) {
      if (mounted) setState(() => _error = 'সমস্যা হয়েছে: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 400),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    radius: 40,
                    backgroundColor: color.primary,
                    child: Icon(Icons.chat_bubble_rounded,
                        size: 40, color: color.onPrimary),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'গুঞ্জন',
                    style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: color.primary,
                        ),
                  ),
                  const SizedBox(height: 32),
                  if (_isSignUp) ...[
                    TextField(
                      controller: _nameController,
                      decoration: const InputDecoration(
                        labelText: 'আপনার নাম',
                        prefixIcon: Icon(Icons.person),
                        border: OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration: const InputDecoration(
                      labelText: 'ইমেইল',
                      prefixIcon: Icon(Icons.email),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'পাসওয়ার্ড',
                      prefixIcon: Icon(Icons.lock),
                      border: OutlineInputBorder(),
                    ),
                    onSubmitted: (_) => _submit(),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: TextStyle(color: color.error)),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: FilledButton(
                      onPressed: _loading ? null : _submit,
                      child: _loading
                          ? const SizedBox(
                              height: 22,
                              width: 22,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : Text(_isSignUp ? 'অ্যাকাউন্ট খুলুন' : 'লগইন'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: const [
                      Expanded(child: Divider()),
                      Padding(
                        padding: EdgeInsets.symmetric(horizontal: 12),
                        child: Text('অথবা'),
                      ),
                      Expanded(child: Divider()),
                    ],
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: _loading ? null : _googleSignIn,
                      icon: const Icon(Icons.account_circle_outlined),
                      label: const Text('Google দিয়ে লগইন'),
                    ),
                  ),
                  TextButton(
                    onPressed: _loading
                        ? null
                        : () => setState(() {
                              _isSignUp = !_isSignUp;
                              _error = null;
                            }),
                    child: Text(_isSignUp
                        ? 'আগে থেকেই অ্যাকাউন্ট আছে? লগইন করুন'
                        : 'নতুন? অ্যাকাউন্ট খুলুন'),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------- হোম: ব্যবহারকারীদের তালিকা ----------------

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(
        title: const Text('গুঞ্জন'),
        actions: [
          PopupMenuButton<String>(
            tooltip: 'অ্যাকাউন্ট',
            icon: const Icon(Icons.account_circle),
            onSelected: (value) => FirebaseAuth.instance.signOut(),
            itemBuilder: (context) => [
              PopupMenuItem<String>(
                enabled: false,
                child: Text(
                  (me.displayName != null && me.displayName!.isNotEmpty)
                      ? '${me.displayName}\n${me.email ?? ''}'
                      : (me.email ?? ''),
                ),
              ),
              const PopupMenuDivider(),
              const PopupMenuItem<String>(
                value: 'switch',
                child: Text('অন্য অ্যাকাউন্টে লগইন করুন'),
              ),
              const PopupMenuItem<String>(
                value: 'logout',
                child: Text('লগআউট'),
              ),
            ],
          ),
        ],
      ),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('users')
            .orderBy('name')
            .snapshots(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final docs = snapshot.data!.docs.where((d) => d.id != me.uid).toList();
          if (docs.isEmpty) {
            return const Center(
              child: Padding(
                padding: EdgeInsets.all(24),
                child: Text(
                  'এখনো কেউ নেই।\nবন্ধুকে অ্যাপে অ্যাকাউন্ট খুলতে বলুন।',
                  textAlign: TextAlign.center,
                ),
              ),
            );
          }
          return ListView.separated(
            itemCount: docs.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, index) {
              final doc = docs[index];
              final name = (doc.data()['name'] ?? 'নামহীন') as String;
              return ListTile(
                leading: CircleAvatar(
                  child: Text(name.isNotEmpty ? name.characters.first : '?'),
                ),
                title: Text(name),
                subtitle: Text((doc.data()['email'] ?? '') as String),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) =>
                          ChatPage(otherUid: doc.id, otherName: name),
                    ),
                  );
                },
              );
            },
          );
        },
      ),
    );
  }
}

// ---------------- চ্যাট ----------------

class ChatPage extends StatefulWidget {
  final String otherUid;
  final String otherName;

  const ChatPage({super.key, required this.otherUid, required this.otherName});

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  late final User _me;
  late final String _chatId;

  @override
  void initState() {
    super.initState();
    _me = FirebaseAuth.instance.currentUser!;
    final ids = [_me.uid, widget.otherUid]..sort();
    _chatId = ids.join('_');
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();

    final chatRef = FirebaseFirestore.instance.collection('chats').doc(_chatId);
    await chatRef.set({
      'participants': [_me.uid, widget.otherUid],
      'lastMessage': text,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
    await chatRef.collection('messages').add({
      'text': text,
      'senderId': _me.uid,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Widget build(BuildContext context) {
    final color = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(widget.otherName)),
      body: Column(
        children: [
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('chats')
                  .doc(_chatId)
                  .collection('messages')
                  .orderBy('createdAt', descending: true)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs = snapshot.data!.docs;
                if (docs.isEmpty) {
                  return const Center(child: Text('একটা মেসেজ পাঠিয়ে শুরু করুন 👋'));
                }
                return ListView.builder(
                  reverse: true,
                  padding: const EdgeInsets.all(12),
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final data = docs[index].data();
                    final mine = data['senderId'] == _me.uid;
                    return Align(
                      alignment:
                          mine ? Alignment.centerRight : Alignment.centerLeft,
                      child: Container(
                        margin: const EdgeInsets.symmetric(vertical: 3),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 10),
                        constraints: BoxConstraints(
                          maxWidth: MediaQuery.of(context).size.width * 0.75,
                        ),
                        decoration: BoxDecoration(
                          color: mine
                              ? color.primary
                              : color.surfaceContainerHighest,
                          borderRadius: BorderRadius.circular(18),
                        ),
                        child: Text(
                          (data['text'] ?? '') as String,
                          style: TextStyle(
                            color: mine ? color.onPrimary : color.onSurface,
                            fontSize: 16,
                          ),
                        ),
                      ),
                    );
                  },
                );
              },
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(12, 6, 8, 8),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _controller,
                      minLines: 1,
                      maxLines: 4,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _send(),
                      decoration: InputDecoration(
                        hintText: 'মেসেজ লিখুন...',
                        filled: true,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 10),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 6),
                  IconButton.filled(
                    onPressed: _send,
                    icon: const Icon(Icons.send),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
