// Mock implementation of the native bridge for the web platform.
class VectorEngineBridge {
  static void init(int dims) {
    print('VectorEngineBridge: init mock on Web.');
  }

  static void destroy() {
    print('VectorEngineBridge: destroy mock on Web.');
  }

  static void insertVector(int id, List<double> vector) {
    print('VectorEngineBridge: insertVector mock on Web.');
  }

  static List<Map<String, dynamic>> searchVector(List<double> query, int k) {
    print('VectorEngineBridge: searchVector mock on Web.');
    return [];
  }
}

void testVectorEngine() {
  print('VectorEngineBridge: testVectorEngine mock on Web.');
}
