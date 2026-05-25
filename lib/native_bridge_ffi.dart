import 'dart:ffi';
import 'dart:io';
import 'package:ffi/ffi.dart';

// --- FFI Signature Definitions ---

// C structure for SearchResult
final class SearchResult extends Struct {
  @Int32()
  external int id;

  @Float()
  external double distance;
}

// C structure for SearchResultList
final class SearchResultList extends Struct {
  external Pointer<SearchResult> results;

  @Int32()
  external int count;
}

// vector_db_create
typedef db_create_func = Pointer<Void> Function(Int32 dims);
typedef DbCreate = Pointer<Void> Function(int dims);

// vector_db_destroy
typedef db_destroy_func = Void Function(Pointer<Void> db_ptr);
typedef DbDestroy = void Function(Pointer<Void> db_ptr);

// vector_db_insert
typedef db_insert_func = Void Function(Pointer<Void> db_ptr, Int32 id, Pointer<Float> emb, Int32 emb_len);
typedef DbInsert = void Function(Pointer<Void> db_ptr, int id, Pointer<Float> emb, int emb_len);

// vector_db_search
typedef db_search_func = SearchResultList Function(Pointer<Void> db_ptr, Pointer<Float> query, Int32 query_len, Int32 k);
typedef DbSearch = SearchResultList Function(Pointer<Void> db_ptr, Pointer<Float> query, int query_len, int k);

// vector_db_free_results
typedef db_free_results_func = Void Function(SearchResultList list);
typedef DbFreeResults = void Function(SearchResultList list);

class VectorEngineBridge {
  static late final DynamicLibrary _lib;
  static Pointer<Void>? _dbPtr;

  static void init(int dims) {
    if (Platform.isAndroid) {
      _lib = DynamicLibrary.open('libvector_engine.so');
    } else if (Platform.isIOS) {
      _lib = DynamicLibrary.process();
    } else {
      throw UnsupportedError('Unsupported platform');
    }

    final DbCreate dbCreate = _lib
        .lookup<NativeFunction<db_create_func>>('vector_db_create')
        .asFunction();

    _dbPtr = dbCreate(dims);
  }

  static void destroy() {
    if (_dbPtr == null) return;
    
    final DbDestroy dbDestroy = _lib
        .lookup<NativeFunction<db_destroy_func>>('vector_db_destroy')
        .asFunction();
        
    dbDestroy(_dbPtr!);
    _dbPtr = null;
  }

  static void insertVector(int id, List<double> vector) {
    if (_dbPtr == null) throw Exception('VectorDB not initialized');
    
    final DbInsert dbInsert = _lib
        .lookup<NativeFunction<db_insert_func>>('vector_db_insert')
        .asFunction();

    // CRITICAL: Allocate memory using calloc to prevent memory leaks
    final Pointer<Float> embPtr = calloc<Float>(vector.length);
    for (int i = 0; i < vector.length; i++) {
      embPtr[i] = vector[i];
    }

    // Execute C function
    dbInsert(_dbPtr!, id, embPtr, vector.length);

    // CRITICAL: Free memory immediately
    calloc.free(embPtr);
  }

  static List<Map<String, dynamic>> searchVector(List<double> query, int k) {
    if (_dbPtr == null) throw Exception('VectorDB not initialized');
    
    final DbSearch dbSearch = _lib
        .lookup<NativeFunction<db_search_func>>('vector_db_search')
        .asFunction();
        
    final DbFreeResults dbFreeResults = _lib
        .lookup<NativeFunction<db_free_results_func>>('vector_db_free_results')
        .asFunction();

    // CRITICAL: Allocate query memory
    final Pointer<Float> queryPtr = calloc<Float>(query.length);
    for (int i = 0; i < query.length; i++) {
      queryPtr[i] = query[i];
    }

    // Call the C search function
    final SearchResultList resultList = dbSearch(_dbPtr!, queryPtr, query.length, k);

    // Parse the results from C struct to Dart Map
    final List<Map<String, dynamic>> parsedResults = [];
    for (int i = 0; i < resultList.count; i++) {
      parsedResults.add({
        'id': resultList.results[i].id,
        'distance': resultList.results[i].distance,
      });
    }

    // CRITICAL: Free the C-allocated result list array
    dbFreeResults(resultList);
    
    // CRITICAL: Free the Dart-allocated query pointer
    calloc.free(queryPtr);

    return parsedResults;
  }
}

// =====================================================================
//  DART TEST FUNCTION
// =====================================================================

void testVectorEngine() {
  print('--- Starting Vector Engine Test ---');
  
  // 1. Initialize the database with 3 dimensions for our test
  VectorEngineBridge.init(3);
  print('VectorDB Initialized with 3 dimensions.');

  // 2. Insert dummy vectors
  final dummyVector = [0.5, 0.8, 0.1];
  VectorEngineBridge.insertVector(1, dummyVector);
  print('Inserted dummy vector [0.5, 0.8, 0.1] with ID: 1');
  
  // Insert a couple more to test distance sorting
  VectorEngineBridge.insertVector(2, [0.1, 0.1, 0.1]); // Further away
  VectorEngineBridge.insertVector(3, [0.6, 0.7, 0.2]); // Very close

  // 3. Search for the exact dummy vector
  print('Searching for closest vectors to [0.5, 0.8, 0.1]...');
  final results = VectorEngineBridge.searchVector([0.5, 0.8, 0.1], 3);

  // 4. Print the results
  print('Search Results:');
  for (var res in results) {
    print(' - ID: ${res['id']}, Distance: ${res['distance'].toStringAsFixed(6)}');
  }
  
  print('--- Vector Engine Test Complete ---');
}
