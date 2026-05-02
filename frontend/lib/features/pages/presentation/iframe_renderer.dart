// Conditional re-export — picks the web implementation when compiled for
// the web (dart.library.html available), the stub otherwise. Keeps
// page_renderer.dart free of platform branching at the call site.
export 'iframe_renderer_stub.dart' if (dart.library.html) 'iframe_renderer_web.dart';
