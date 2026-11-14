import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

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
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF6C4AB6),
          brightness: Brightness.dark,
        ),
      ),
      themeMode: ThemeMode.system,
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

// ---------------- সাধারণ সাহায্যকারী ----------------

const List<String> _emojis = ['👍', '❤️', '😂', '😮', '😢', '🙏'];

CollectionReference<Map<String, dynamic>> get usersRef =>
    FirebaseFirestore.instance.collection('users');

CollectionReference<Map<String, dynamic>> get chatsRef =>
    FirebaseFirestore.instance.collection('chats');

String timeText(Timestamp? ts) {
  if (ts == null) return '';
  final d = ts.toDate();
  final hh = d.hour.toString().padLeft(2, '0');
  final mm = d.minute.toString().padLeft(2, '0');
  return '$hh:$mm';
}

Timestamp? asTimestamp(dynamic value) => value is Timestamp ? value : null;

String firstLetter(String name) =>
    name.isNotEmpty ? name.characters.first.toUpperCase() : '?';

String myDisplayName(User u) {
  final n = u.displayName;
  if (n != null && n.isNotEmpty) return n;
  return u.email ?? 'আমি';
}

// অনলাইন কিনা: online চিহ্ন আছে এবং শেষ ৩ মিনিটের মধ্যে সাড়া দিয়েছে
bool isOnline(Map<String, dynamic> data) {
  if (data['online'] != true) return false;
  final ts = data['lastSeen'];
  if (ts is! Timestamp) return false;
  return DateTime.now().difference(ts.toDate()).inMinutes < 3;
}

class UserAvatar extends StatelessWidget {
  final String name;
  final String? photoUrl;
  final double radius;
  final bool online;

  const UserAvatar({
    super.key,
    required this.name,
    this.photoUrl,
    this.radius = 20,
    this.online = false,
  });

  Widget _initial() =>
      CircleAvatar(radius: radius, child: Text(firstLetter(name)));

  @override
  Widget build(BuildContext context) {
    final hasPhoto = photoUrl != null && photoUrl!.isNotEmpty;
    final Widget base = hasPhoto
        ? ClipOval(
            child: Image.network(
              photoUrl!,
              width: radius * 2,
              height: radius * 2,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => _initial(),
            ),
          )
        : _initial();
    if (!online) return base;
    return Stack(
      children: [
        base,
        Positioned(
          right: 0,
          bottom: 0,
          child: Container(
            width: radius * 0.7,
            height: radius * 0.7,
            decoration: BoxDecoration(
              color: Colors.green,
              shape: BoxShape.circle,
              border: Border.all(
                color: Theme.of(context).colorScheme.surface,
                width: 2,
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------- হোম ----------------

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final User _me = FirebaseAuth.instance.currentUser!;
  Timer? _heartbeat;
  bool _foreground = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _setOnline(true);
    _heartbeat = Timer.periodic(const Duration(seconds: 60), (_) {
      if (_foreground) _setOnline(true);
    });
  }

  @override
  void dispose() {
    _heartbeat?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _setOnline(_foreground);
  }

  Future<void> _setOnline(bool online) async {
    try {
      await usersRef.doc(_me.uid).set({
        'online': online,
        'lastSeen': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  Future<void> _logout() async {
    await _setOnline(false);
    await FirebaseAuth.instance.signOut();
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('গুঞ্জন'),
          actions: [
            IconButton(
              tooltip: 'নতুন গ্রুপ',
              icon: const Icon(Icons.group_add),
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const NewGroupPage()),
                );
              },
            ),
            PopupMenuButton<String>(
              tooltip: 'অ্যাকাউন্ট',
              icon: const Icon(Icons.account_circle),
              onSelected: (_) => _logout(),
              itemBuilder: (context) => [
                PopupMenuItem<String>(
                  enabled: false,
                  child: Text('${myDisplayName(_me)}\n${_me.email ?? ''}'),
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
          bottom: const TabBar(
            tabs: [
              Tab(text: 'চ্যাট'),
              Tab(text: 'মানুষ'),
            ],
          ),
        ),
        body: TabBarView(
          children: [
            ChatsTab(me: _me),
            PeopleTab(me: _me),
          ],
        ),
      ),
    );
  }
}

// ---------------- চ্যাট তালিকা ----------------

class ChatsTab extends StatelessWidget {
  final User me;

  const ChatsTab({super.key, required this.me});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
      stream: chatsRef.where('participants', arrayContains: me.uid).snapshots(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return Center(child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final docs = snapshot.data!.docs.where((d) {
          final m = d.data()['lastMessage'];
          return m is String && m.isNotEmpty;
        }).toList();

        int millisOf(QueryDocumentSnapshot<Map<String, dynamic>> d) {
          final ts = asTimestamp(d.data()['updatedAt']);
          return ts?.millisecondsSinceEpoch ??
              DateTime.now().millisecondsSinceEpoch;
        }

        docs.sort((a, b) => millisOf(b).compareTo(millisOf(a)));

        if (docs.isEmpty) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'এখনো কোনো চ্যাট নেই।\n"মানুষ" ট্যাব থেকে কারো সাথে কথা শুরু করুন।',
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
            final data = doc.data();
            final isGroup = data['isGroup'] == true;
            final participants =
                List<String>.from(data['participants'] ?? const []);
            final names = Map<String, dynamic>.from(data['names'] ?? const {});
            final namesText =
                names.map((k, v) => MapEntry(k, v.toString()));

            String title;
            if (isGroup) {
              title = (data['name'] ?? 'গ্রুপ').toString();
            } else {
              final other =
                  participants.firstWhere((p) => p != me.uid, orElse: () => '');
              title = (names[other] ?? 'ব্যবহারকারী').toString();
            }
            final prefix = data['lastSenderId'] == me.uid ? 'আপনি: ' : '';

            return ListTile(
              leading: isGroup
                  ? const CircleAvatar(child: Icon(Icons.group))
                  : UserAvatar(name: title),
              title: Text(title),
              subtitle: Text(
                '$prefix${data['lastMessage']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              trailing: Text(
                timeText(asTimestamp(data['updatedAt'])),
                style: const TextStyle(fontSize: 12),
              ),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ChatPage(
                      chatId: doc.id,
                      title: title,
                      isGroup: isGroup,
                      participants: participants,
                      names: namesText,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }
}

// ---------------- মানুষের তালিকা ----------------

class PeopleTab extends StatefulWidget {
  final User me;

  const PeopleTab({super.key, required this.me});

  @override
  State<PeopleTab> createState() => _PeopleTabState();
}

class _PeopleTabState extends State<PeopleTab> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
          child: TextField(
            onChanged: (v) => setState(() => _query = v.trim().toLowerCase()),
            decoration: InputDecoration(
              hintText: 'নাম দিয়ে খুঁজুন...',
              prefixIcon: const Icon(Icons.search),
              filled: true,
              contentPadding: const EdgeInsets.symmetric(vertical: 8),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(24),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
            stream: usersRef.orderBy('name').snapshots(),
            builder: (context, snapshot) {
              if (snapshot.hasError) {
                return Center(child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
              }
              if (!snapshot.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              final docs = snapshot.data!.docs.where((d) {
                if (d.id == me.uid) return false;
                final name = (d.data()['name'] ?? '').toString().toLowerCase();
                return _query.isEmpty || name.contains(_query);
              }).toList();

              if (docs.isEmpty) {
                return const Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Text(
                      'কেউ পাওয়া যায়নি।\nবন্ধুকে অ্যাপে অ্যাকাউন্ট খুলতে বলুন।',
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
                  final data = doc.data();
                  final name = (data['name'] ?? 'নামহীন').toString();
                  final online = isOnline(data);
                  return ListTile(
                    leading: UserAvatar(
                      name: name,
                      photoUrl: data['photoUrl']?.toString(),
                      online: online,
                    ),
                    title: Text(name),
                    subtitle: Text(
                      online ? 'অনলাইন' : (data['email'] ?? '').toString(),
                      style: TextStyle(
                        color: online ? Colors.green : null,
                      ),
                    ),
                    onTap: () {
                      final ids = [me.uid, doc.id]..sort();
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => ChatPage(
                            chatId: ids.join('_'),
                            title: name,
                            isGroup: false,
                            participants: [me.uid, doc.id],
                            names: {
                              me.uid: myDisplayName(me),
                              doc.id: name,
                            },
                          ),
                        ),
                      );
                    },
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }
}

// ---------------- নতুন গ্রুপ ----------------

class NewGroupPage extends StatefulWidget {
  const NewGroupPage({super.key});

  @override
  State<NewGroupPage> createState() => _NewGroupPageState();
}

class _NewGroupPageState extends State<NewGroupPage> {
  final _nameController = TextEditingController();
  final Set<String> _selected = {};
  final Map<String, String> _names = {};
  bool _creating = false;
  String? _error;

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) {
      setState(() => _error = 'গ্রুপের নাম লিখুন।');
      return;
    }
    if (_selected.isEmpty) {
      setState(() => _error = 'কমপক্ষে একজনকে বেছে নিন।');
      return;
    }
    setState(() {
      _creating = true;
      _error = null;
    });

    final me = FirebaseAuth.instance.currentUser!;
    final participants = <String>[me.uid, ..._selected];
    final names = <String, String>{
      me.uid: myDisplayName(me),
      for (final id in _selected) id: _names[id] ?? 'ব্যবহারকারী',
    };

    try {
      final ref = await chatsRef.add({
        'isGroup': true,
        'name': name,
        'participants': participants,
        'names': names,
        'createdBy': me.uid,
        'lastMessage': 'গ্রুপ তৈরি হয়েছে',
        'lastSenderId': me.uid,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ChatPage(
            chatId: ref.id,
            title: name,
            isGroup: true,
            participants: participants,
            names: names,
          ),
        ),
      );
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'সমস্যা হয়েছে: $e';
          _creating = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('নতুন গ্রুপ')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                labelText: 'গ্রুপের নাম',
                prefixIcon: Icon(Icons.group),
                border: OutlineInputBorder(),
              ),
            ),
          ),
          const Padding(
            padding: EdgeInsets.symmetric(horizontal: 16),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Text('সদস্য বেছে নিন'),
            ),
          ),
          Expanded(
            child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
              stream: usersRef.orderBy('name').snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return Center(
                      child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final docs =
                    snapshot.data!.docs.where((d) => d.id != me.uid).toList();
                return ListView.builder(
                  itemCount: docs.length,
                  itemBuilder: (context, index) {
                    final doc = docs[index];
                    final name = (doc.data()['name'] ?? 'নামহীন').toString();
                    _names[doc.id] = name;
                    return CheckboxListTile(
                      value: _selected.contains(doc.id),
                      title: Text(name),
                      subtitle: Text((doc.data()['email'] ?? '').toString()),
                      onChanged: (v) {
                        setState(() {
                          if (v == true) {
                            _selected.add(doc.id);
                          } else {
                            _selected.remove(doc.id);
                          }
                        });
                      },
                    );
                  },
                );
              },
            ),
          ),
          if (_error != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: SizedBox(
                width: double.infinity,
                height: 48,
                child: FilledButton(
                  onPressed: _creating ? null : _create,
                  child: _creating
                      ? const SizedBox(
                          height: 22,
                          width: 22,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Text('গ্রুপ বানান'),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------- চ্যাট ----------------

class ChatPage extends StatefulWidget {
  final String chatId;
  final String title;
  final bool isGroup;
  final List<String> participants;
  final Map<String, String> names;

  const ChatPage({
    super.key,
    required this.chatId,
    required this.title,
    required this.isGroup,
    required this.participants,
    required this.names,
  });

  @override
  State<ChatPage> createState() => _ChatPageState();
}

class _ChatPageState extends State<ChatPage> {
  final _controller = TextEditingController();
  late final User _me;
  late final DocumentReference<Map<String, dynamic>> _chatRef;
  late final Future<void> _ready;
  Map<String, String>? _replyTo;
  int _lastTypingWrite = 0;

  @override
  void initState() {
    super.initState();
    _me = FirebaseAuth.instance.currentUser!;
    _chatRef = chatsRef.doc(widget.chatId);
    _ready = _ensureChat();
  }

  @override
  void dispose() {
    _setTyping(0);
    _controller.dispose();
    super.dispose();
  }

  // ১-১ চ্যাটের ডকুমেন্ট আগে থেকে তৈরি করে রাখা
  Future<void> _ensureChat() async {
    if (widget.isGroup) return;
    await _chatRef.set({
      'participants': widget.participants,
      'isGroup': false,
      'names': widget.names,
    }, SetOptions(merge: true));
  }

  Future<void> _setTyping(int value) async {
    try {
      await _chatRef.set({
        'typing': {_me.uid: value},
      }, SetOptions(merge: true));
    } catch (_) {}
  }

  void _onTextChanged(String _) {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (now - _lastTypingWrite > 2500) {
      _lastTypingWrite = now;
      _setTyping(now);
    }
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    _controller.clear();
    final reply = _replyTo;
    setState(() => _replyTo = null);
    _lastTypingWrite = 0;

    final msg = <String, dynamic>{
      'text': text,
      'senderId': _me.uid,
      'createdAt': FieldValue.serverTimestamp(),
      'seenBy': [_me.uid],
    };
    if (reply != null) {
      msg['replyText'] = reply['text'];
      msg['replyName'] = reply['name'];
    }

    try {
      await Future.wait<Object?>([
        _chatRef.collection('messages').add(msg),
        _chatRef.set({
          'lastMessage': text,
          'lastSenderId': _me.uid,
          'updatedAt': FieldValue.serverTimestamp(),
          'typing': {_me.uid: 0},
        }, SetOptions(merge: true)),
      ]);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('পাঠানো যায়নি: $e')),
        );
      }
    }
  }

  // অন্যের পাঠানো মেসেজ "দেখা হয়েছে" চিহ্নিত করা
  Future<void> _markSeen(
      List<QueryDocumentSnapshot<Map<String, dynamic>>> docs) async {
    final unseen = docs.where((d) {
      final data = d.data();
      final seenBy = List<String>.from(data['seenBy'] ?? const []);
      return data['senderId'] != _me.uid && !seenBy.contains(_me.uid);
    }).toList();
    if (unseen.isEmpty) return;
    try {
      final batch = FirebaseFirestore.instance.batch();
      for (final d in unseen) {
        batch.update(d.reference, {
          'seenBy': FieldValue.arrayUnion([_me.uid]),
        });
      }
      await batch.commit();
    } catch (_) {}
  }

  Future<void> _react(
      QueryDocumentSnapshot<Map<String, dynamic>> doc, String emoji) async {
    final reactions =
        Map<String, dynamic>.from(doc.data()['reactions'] ?? const {});
    final same = reactions[_me.uid] == emoji;
    try {
      await doc.reference.update({
        'reactions.${_me.uid}': same ? FieldValue.delete() : emoji,
      });
    } catch (_) {}
  }

  Future<void> _delete(QueryDocumentSnapshot<Map<String, dynamic>> doc) async {
    try {
      await doc.reference.update({'deleted': true, 'text': ''});
    } catch (_) {}
  }

  void _showActions(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data['deleted'] == true) return;
    final mine = data['senderId'] == _me.uid;
    final text = (data['text'] ?? '').toString();
    final senderName = mine
        ? 'আপনি'
        : (widget.names[data['senderId']] ?? 'ব্যবহারকারী');

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  for (final e in _emojis)
                    InkWell(
                      onTap: () {
                        Navigator.pop(sheetContext);
                        _react(doc, e);
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Text(e, style: const TextStyle(fontSize: 28)),
                      ),
                    ),
                ],
              ),
            ),
            const Divider(height: 1),
            ListTile(
              leading: const Icon(Icons.reply),
              title: const Text('উত্তর দিন'),
              onTap: () {
                Navigator.pop(sheetContext);
                setState(() {
                  _replyTo = {
                    'text': text.length > 80 ? text.substring(0, 80) : text,
                    'name': senderName,
                  };
                });
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('কপি করুন'),
              onTap: () {
                Navigator.pop(sheetContext);
                Clipboard.setData(ClipboardData(text: text));
              },
            ),
            if (mine)
              ListTile(
                leading: const Icon(Icons.delete_outline),
                title: const Text('মুছে ফেলুন'),
                onTap: () {
                  Navigator.pop(sheetContext);
                  _delete(doc);
                },
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildBubble(QueryDocumentSnapshot<Map<String, dynamic>> doc) {
    final color = Theme.of(context).colorScheme;
    final data = doc.data();
    final mine = data['senderId'] == _me.uid;
    final deleted = data['deleted'] == true;
    final seenBy = List<String>.from(data['seenBy'] ?? const []);
    final seen = seenBy.length > 1;
    final reactions =
        Map<String, dynamic>.from(data['reactions'] ?? const {});
    final counts = <String, int>{};
    for (final e in reactions.values) {
      final key = e.toString();
      counts[key] = (counts[key] ?? 0) + 1;
    }
    final textColor = mine ? color.onPrimary : color.onSurface;
    final senderName = widget.names[data['senderId']] ?? 'ব্যবহারকারী';
    final replyText = data['replyText']?.toString();
    final replyName = data['replyName']?.toString() ?? '';

    final bubble = Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      constraints: BoxConstraints(
        maxWidth: MediaQuery.of(context).size.width * 0.75,
      ),
      decoration: BoxDecoration(
        color: mine ? color.primary : color.surfaceContainerHighest,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.isGroup && !mine)
            Text(
              senderName,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.bold,
                color: color.primary,
              ),
            ),
          if (replyText != null && replyText.isNotEmpty && !deleted)
            Container(
              margin: const EdgeInsets.only(bottom: 4),
              padding: const EdgeInsets.only(left: 8),
              decoration: BoxDecoration(
                border: Border(
                  left: BorderSide(color: textColor.withAlpha(150), width: 3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    replyName,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  Text(
                    replyText,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontSize: 12, color: textColor),
                  ),
                ],
              ),
            ),
          Text(
            deleted
                ? 'মেসেজটি মুছে ফেলা হয়েছে'
                : (data['text'] ?? '').toString(),
            style: TextStyle(
              color: textColor,
              fontSize: 16,
              fontStyle: deleted ? FontStyle.italic : FontStyle.normal,
            ),
          ),
          Align(
            alignment: Alignment.centerRight,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  timeText(asTimestamp(data['createdAt'])),
                  style: TextStyle(fontSize: 11, color: textColor.withAlpha(180)),
                ),
                if (mine && !deleted) ...[
                  const SizedBox(width: 4),
                  Icon(
                    seen ? Icons.done_all : Icons.done,
                    size: 14,
                    color: seen
                        ? Colors.lightBlueAccent
                        : textColor.withAlpha(180),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );

    final reactionChips = counts.entries.map((e) {
      final label = e.value > 1 ? '${e.key} ${e.value}' : e.key;
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
        decoration: BoxDecoration(
          color: color.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Text(label, style: const TextStyle(fontSize: 13)),
      );
    }).toList();

    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: () => _showActions(doc),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 3),
          child: Column(
            crossAxisAlignment:
                mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
            children: [
              bubble,
              if (reactionChips.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 2),
                  child: Wrap(spacing: 4, children: reactionChips),
                ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String? otherUid = widget.isGroup
        ? null
        : widget.participants.firstWhere((p) => p != _me.uid, orElse: () => '');

    return Scaffold(
      appBar: AppBar(
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(widget.title, style: const TextStyle(fontSize: 18)),
            FutureBuilder<void>(
              future: _ready,
              builder: (context, snap) {
                if (snap.connectionState != ConnectionState.done ||
                    snap.hasError) {
                  return const SizedBox.shrink();
                }
                return ChatSubtitle(
                  chatRef: _chatRef,
                  meUid: _me.uid,
                  isGroup: widget.isGroup,
                  otherUid: (otherUid == null || otherUid.isEmpty)
                      ? null
                      : otherUid,
                  memberCount: widget.participants.length,
                );
              },
            ),
          ],
        ),
      ),
      body: FutureBuilder<void>(
        future: _ready,
        builder: (context, readySnap) {
          if (readySnap.hasError) {
            return Center(child: Text('সমস্যা হয়েছে: ${readySnap.error}'));
          }
          if (readySnap.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          return Column(
            children: [
              Expanded(
                child: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  stream: _chatRef
                      .collection('messages')
                      .orderBy('createdAt', descending: true)
                      .limit(200)
                      .snapshots(),
                  builder: (context, snapshot) {
                    if (snapshot.hasError) {
                      return Center(
                          child: Text('সমস্যা হয়েছে: ${snapshot.error}'));
                    }
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    final docs = snapshot.data!.docs;
                    WidgetsBinding.instance
                        .addPostFrameCallback((_) => _markSeen(docs));
                    if (docs.isEmpty) {
                      return const Center(
                        child: Text('একটা মেসেজ পাঠিয়ে শুরু করুন 👋'),
                      );
                    }
                    return ListView.builder(
                      reverse: true,
                      padding: const EdgeInsets.all(12),
                      itemCount: docs.length,
                      itemBuilder: (context, index) =>
                          _buildBubble(docs[index]),
                    );
                  },
                ),
              ),
              if (_replyTo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(12, 6, 4, 6),
                  color: Theme.of(context).colorScheme.surfaceContainerHighest,
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${_replyTo!['name']} কে উত্তর',
                              style: const TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Text(
                              _replyTo!['text'] ?? '',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() => _replyTo = null),
                      ),
                    ],
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
                          onChanged: _onTextChanged,
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
          );
        },
      ),
    );
  }
}

// চ্যাটের উপরের ছোট লেখা: টাইপ করছে / অনলাইন / সর্বশেষ দেখা / সদস্য সংখ্যা
class ChatSubtitle extends StatefulWidget {
  final DocumentReference<Map<String, dynamic>> chatRef;
  final String meUid;
  final bool isGroup;
  final String? otherUid;
  final int memberCount;

  const ChatSubtitle({
    super.key,
    required this.chatRef,
    required this.meUid,
    required this.isGroup,
    required this.otherUid,
    required this.memberCount,
  });

  @override
  State<ChatSubtitle> createState() => _ChatSubtitleState();
}

class _ChatSubtitleState extends State<ChatSubtitle> {
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(seconds: 2), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(fontSize: 12);
    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: widget.chatRef.snapshots(),
      builder: (context, snap) {
        final data = snap.data?.data();
        final typing = Map<String, dynamic>.from(data?['typing'] ?? const {});
        final now = DateTime.now().millisecondsSinceEpoch;
        final someoneTyping = typing.entries.any((e) {
          final v = e.value;
          return e.key != widget.meUid &&
              v is num &&
              v > 0 &&
              now - v.toInt() < 5000;
        });
        if (someoneTyping) {
          return const Text('টাইপ করছে...', style: style);
        }
        if (widget.isGroup) {
          return Text('${widget.memberCount} জন সদস্য', style: style);
        }
        final other = widget.otherUid;
        if (other == null) return const SizedBox.shrink();
        return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
          stream: usersRef.doc(other).snapshots(),
          builder: (context, s) {
            final u = s.data?.data();
            if (u == null) return const SizedBox.shrink();
            if (isOnline(u)) {
              return const Text(
                'অনলাইন',
                style: TextStyle(fontSize: 12, color: Colors.green),
              );
            }
            final ls = asTimestamp(u['lastSeen']);
            if (ls != null) {
              return Text('সর্বশেষ দেখা: ${timeText(ls)}', style: style);
            }
            return const SizedBox.shrink();
          },
        );
      },
    );
  }
}
