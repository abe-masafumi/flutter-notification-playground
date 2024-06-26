import 'package:awesome_project01/providers/notification_provider.dart';
import 'package:awesome_project01/services/notification_preferences_manager.dart';
import 'package:awesome_project01/utils/native_sound.dart';
import 'package:badges/badges.dart' as badges;
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'firebase_options.dart';


// iOS、macOS、ウェブ端末でPush通知を受信する場合には、ユーザーに権限を付与する必要があります。
// ③
// IOS、Androidデバイス共通の処理、アプリがバックグラウンド時にメッセージを受け取る処理
// Android端末の場合はこの処理がなくても通知を受け取ることができるが、細かな処理はできない。
//
@pragma('vm:entry-point')
Future<void> _firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await Firebase.initializeApp();
  print("Handling a background message: ${message.messageId}");
  await NotificationPreferencesManager.init();
  await NotificationPreferencesManager.setNewNotificationsForBackground(true);
  await NotificationPreferencesManager.setNotificationCountAddForBackground();
  print('notificationCount: ${NotificationPreferencesManager.getNotificationCount()}');
  print('hasNewNotifications: ${NotificationPreferencesManager.getNewNotifications()}');
  print("完了: ${message.messageId}");
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  //
  // デバイスにデータを保存するための設定
  //
  await NotificationPreferencesManager.init();
  // await SharedPreferencesService.clearSharedPreferences(); // 開発用
  final container = ProviderContainer();
  FirebaseMessaging.onBackgroundMessage(_firebaseMessagingBackgroundHandler);
  setupTokenRefreshListener();

  // ④
  // アプリがフォアグラウンド状態にある場合にメッセージを受け取る処理
  //
  FirebaseMessaging.onMessage.listen((RemoteMessage message) async {
    print('Got a message whilst in the foreground!');
    print('Message data: ${message.data}');
    await NotificationPreferencesManager.setNewNotifications(container,true);
    await NotificationPreferencesManager.setNotificationCountAdd(container);

    // ⑤
    // 通知音を再生する
    //
    NativeSound.playDefaultNotificationSound();

    if (message.notification != null) {
      print('Message also contained a notification: ${message.notification}');
    }
  });

  runApp(
    UncontrolledProviderScope(
      container: container,
      child: const MyApp(),
    ),
  );
}

// ①
// この処理は、アプリが初回起動した場合、または新しいFCMトークンが生成された場合に呼び出されます。
// この処理を使用すると従来使用していた、final fcmToken = await FirebaseMessaging.instance.getToken();を使用せずに
// 無駄なgetToken()の呼び出しを避けることができる。
//
void setupTokenRefreshListener() {
  FirebaseMessaging.instance.onTokenRefresh.listen((fcmToken) {
    print('新しいFCMトークン: $fcmToken');
    //  c5H92-5bQiCjjtPdQngjHk:APA91bF9O160F69isR_1GrFL0AoxXEqm36ZdE26LJJnVnRoOPlE8myH9-acfok6IViiBxDY-QlfnKHCHh-xCLi0I9q8YXu0r6QRBjCiIIn7LQfGQeN6Qk2-68t2GEWa0OjKs4
    // TODO: If necessary send token to application server.
    //
    // TODO:　ReverpodでFCMトークンを管理し、適切な場面でサーバーへ送信する。
    //
  }).onError((err) {
    print('新しいFCMトークンの取得に失敗しました。');
  });
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends ConsumerStatefulWidget {
  const MyHomePage({super.key, required this.title});

  final String title;

  @override
  ConsumerState<ConsumerStatefulWidget> createState() => _MyHomePageState();
}

class _MyHomePageState extends ConsumerState<MyHomePage> with WidgetsBindingObserver {
  bool isBadgeVisible = false;

  Future<void> setupInteractedMessage() async {
    RemoteMessage? initialMessage =
        await FirebaseMessaging.instance.getInitialMessage();

    if (initialMessage != null) {
      _handleMessage(initialMessage);
    }

    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessage);
  }

  void _handleMessage(RemoteMessage message) {
    print("通知がタップされました。");
    // if (message.data['type'] == 'chat') {
    //   Navigator.pushNamed(context, '/chat',
    //     arguments: ChatArguments(message),
    //   );
    // }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    // ②
    // 通知をタップしてアプリが開かれた場合の処理を実行する
    // 例えば特定の画面へ遷移する。。など
    //
    setupInteractedMessage();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);
    if (state == AppLifecycleState.resumed) {
      // アプリがフォアグラウンドに戻った時にデータを再読み込み
      loadData();
    }
  }

  void loadData() async {
    SharedPreferences prefs= await SharedPreferences.getInstance();
    // バックグラウンド ハンドラーが別の分離環境で実行されるため、強制的に更新
    await prefs.reload();
    NotificationPreferencesManager.logAllSharedPreferences();
    ref.invalidate(newNotificationsProvider);
    ref.invalidate(notificationCountProvider);
  }


  int _counter = 0;

  void _incrementCounter() async {
    await NotificationPreferencesManager.setNotificationCountDraw(ref);
    if (NotificationPreferencesManager.getNotificationCount() == 0) {
      await NotificationPreferencesManager.setNewNotifications(ref,false);
    }
    setState(() {
      _counter++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: <Widget>[
              const Text(
                'You have pushed the button this many times:',
              ),
              Text(
                '$_counter',
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              ElevatedButton(
                onPressed: () async {
                  final String? fcmToken = await FirebaseMessaging.instance.getToken();
                  if (fcmToken != null) {
                    Clipboard.setData(ClipboardData(text: fcmToken));
                  }
                  NotificationPreferencesManager.logAllSharedPreferences();
                },
                child: const Text('Log Shared Preferences'),
              ),
              ElevatedButton(
                onPressed: () {
                  NotificationPreferencesManager.checkNotificationPermission(context);
                },
                child: Text('Request Notification Permission'),
              ),
            ]),
      ),
      //
      // バッチを表示
      //
      floatingActionButton: badges.Badge(
        badgeContent: Text(ref.watch(notificationCountProvider).toString(),
            style: const TextStyle(fontSize: 20)),
        position: badges.BadgePosition.topEnd(top: -20, end: 40),
        showBadge: ref.watch(newNotificationsProvider) ?? false,
        ignorePointer: true,
        badgeStyle: const badges.BadgeStyle(
          borderSide: BorderSide(color: Colors.white, width: 1),
          padding: EdgeInsets.all(9),
        ),
        child: FloatingActionButton(
          onPressed: _incrementCounter,
          tooltip: 'Increment',
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
