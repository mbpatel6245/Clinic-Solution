/// Native applications retain login startup. Web startup honors the URL selected
/// before Flutter was loaded by the public marketing page.
String initialClinicLocation({required bool web, required Uri uri}) {
  if (!web) return '/login';
  if (uri.fragment.startsWith('/') && !uri.fragment.startsWith('//')) {
    return uri.fragment;
  }
  if (uri.path == '/' || uri.path.isEmpty || uri.path.endsWith('/index.html')) {
    return '/login';
  }
  return Uri(path: uri.path, query: uri.hasQuery ? uri.query : null).toString();
}
