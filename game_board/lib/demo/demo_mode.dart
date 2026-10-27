/// True when the app was built with --dart-define=DEMO=true.
///
/// A demo build never talks to a real server: every REST call goes to
/// [DemoBackend], an in-memory fake of the Node API filled with made-up
/// players. Online play and the chat test need the live Socket.IO server,
/// so they are switched off. Nothing is saved, and a refresh starts again.
const bool isDemo = bool.fromEnvironment('DEMO');
