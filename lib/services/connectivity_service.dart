import 'package:connectivity_plus/connectivity_plus.dart';

class ConnectivityService {
  ConnectivityService._private();
  static final ConnectivityService instance = ConnectivityService._private();

  Future<bool> isOnline() async {
    final connectivity = await Connectivity().checkConnectivity();
    // If the list is empty or contains only 'none', we are offline.
    if (connectivity.isEmpty || connectivity.contains(ConnectivityResult.none)) {
      return false;
    }
    return true;
  }
}