import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';
import '../utils/constants.dart';
import '../models/models.dart';

class ApiException implements Exception {
  final String message;
  final int? statusCode;
  ApiException(this.message, {this.statusCode});
  @override
  String toString() => message;
}

class ApiService {
  static final ApiService _instance = ApiService._internal();
  factory ApiService() => _instance;
  ApiService._internal();

  String? _token;

  // 10 second timeout — shows error instead of spinning forever
  static const _timeout = Duration(seconds: 10);

  Future<void> loadToken() async {
    final prefs = await SharedPreferences.getInstance();
    _token = prefs.getString(AppConstants.tokenKey);
  }

  Future<void> saveToken(String token) async {
    _token = token;
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(AppConstants.tokenKey, token);
  }

  Future<void> clearToken() async {
    _token = null;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(AppConstants.tokenKey);
    await prefs.remove(AppConstants.userKey);
  }

  Map<String, String> get _headers => {
        'Content-Type': 'application/json',
        if (_token != null) 'Authorization': 'Bearer $_token',
      };

  Uri _uri(String path, [Map<String, dynamic>? params]) {
    final uri = Uri.parse('${AppConstants.baseUrl}$path');
    if (params != null && params.isNotEmpty) {
      return uri.replace(
          queryParameters: params.map((k, v) => MapEntry(k, v.toString())));
    }
    return uri;
  }

  Future<dynamic> _handleResponse(http.Response res) {
    if (res.statusCode >= 200 && res.statusCode < 300) {
      if (res.body.isEmpty) return Future.value(null);
      return Future.value(jsonDecode(utf8.decode(res.bodyBytes)));
    }
    String msg = 'Server error (${res.statusCode})';
    try {
      final body = jsonDecode(res.body);
      msg = body['detail'] ?? msg;
    } catch (_) {}
    throw ApiException(msg, statusCode: res.statusCode);
  }

  Future<dynamic> get(String path, [Map<String, dynamic>? params]) async {
    try {
      final res = await http
          .get(_uri(path, params), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException('Connection timed out.\nMake sure backend is running at:\n${AppConstants.baseUrl}');
    } on SocketException catch (e) {
      throw ApiException('Cannot reach server.\nURL: ${AppConstants.baseUrl}\nError: ${e.message}');
    } on HandshakeException {
      throw ApiException('SSL error. Try using http:// instead of https://');
    }
  }

  Future<dynamic> post(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .post(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException('Connection timed out.\nMake sure backend is running at:\n${AppConstants.baseUrl}');
    } on SocketException catch (e) {
      throw ApiException('Cannot reach server.\nURL: ${AppConstants.baseUrl}\nError: ${e.message}');
    } on HandshakeException {
      throw ApiException('SSL error. Try using http:// instead of https://');
    }
  }

  Future<dynamic> put(String path, Map<String, dynamic> body) async {
    try {
      final res = await http
          .put(_uri(path), headers: _headers, body: jsonEncode(body))
          .timeout(_timeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on SocketException catch (e) {
      throw ApiException('Cannot reach server: ${e.message}');
    }
  }

  Future<dynamic> delete(String path) async {
    try {
      final res = await http
          .delete(_uri(path), headers: _headers)
          .timeout(_timeout);
      return _handleResponse(res);
    } on TimeoutException {
      throw ApiException('Connection timed out.');
    } on SocketException catch (e) {
      throw ApiException('Cannot reach server: ${e.message}');
    }
  }

  // ─── Auth ──────────────────────────────────────────────────────────────────

  Future<Map<String, dynamic>> login(String username, String password) async {
    final data = await post('/auth/login', {
      'username': username,
      'password': password,
    });
    await saveToken(data['access_token']);
    return data;
  }

  Future<void> logout() => clearToken();

  // ─── Inventory ─────────────────────────────────────────────────────────────

  Future<List<InventoryItem>> getInventoryItems({
    String? search,
    int? categoryId,
    int? warehouseId,
    bool lowStockOnly = false,
  }) async {
    final params = <String, dynamic>{};
    if (search != null && search.isNotEmpty) params['search'] = search;
    if (categoryId != null) params['category_id'] = categoryId;
    if (warehouseId != null) params['warehouse_id'] = warehouseId;
    if (lowStockOnly) params['low_stock_only'] = 'true';
    final data = await get('/inventory/items', params);
    return (data as List).map((e) => InventoryItem.fromJson(e)).toList();
  }

  Future<InventoryItem> getInventoryItem(int id) async {
    final data = await get('/inventory/items/$id');
    return InventoryItem.fromJson(data);
  }

  Future<InventoryItem> createInventoryItem(Map<String, dynamic> body) async {
    final data = await post('/inventory/items', body);
    return InventoryItem.fromJson(data);
  }

  Future<InventoryItem> updateInventoryItem(int id, Map<String, dynamic> body) async {
    final data = await put('/inventory/items/$id', body);
    return InventoryItem.fromJson(data);
  }

  Future<void> deleteInventoryItem(int id) => delete('/inventory/items/$id');

  Future<InventoryItem> adjustStock(int id, double change, {String? notes}) async {
    final data = await post('/inventory/items/$id/adjust',
        {'quantity_change': change, if (notes != null) 'notes': notes});
    return InventoryItem.fromJson(data);
  }

  Future<List<Category>> getCategories() async {
    final data = await get('/inventory/categories');
    return (data as List).map((e) => Category.fromJson(e)).toList();
  }

  Future<Category> createCategory(String name, {String? description}) async {
    final data = await post('/inventory/categories',
        {'name': name, if (description != null) 'description': description});
    return Category.fromJson(data);
  }

  Future<List<Warehouse>> getWarehouses() async {
    final data = await get('/inventory/warehouses');
    return (data as List).map((e) => Warehouse.fromJson(e)).toList();
  }

  Future<List<WarehouseLocation>> getLocations({int? warehouseId}) async {
    final params = warehouseId != null ? {'warehouse_id': warehouseId} : null;
    final data = await get('/inventory/locations', params);
    return (data as List).map((e) => WarehouseLocation.fromJson(e)).toList();
  }

  // ─── Projects ──────────────────────────────────────────────────────────────

  Future<List<Project>> getProjects({String? status, String? search}) async {
    final params = <String, dynamic>{};
    if (status != null) params['status'] = status;
    if (search != null && search.isNotEmpty) params['search'] = search;
    final data = await get('/projects', params);
    return (data as List).map((e) => Project.fromJson(e)).toList();
  }

  Future<Project> getProject(int id) async {
    final data = await get('/projects/$id');
    return Project.fromJson(data);
  }

  Future<Project> createProject(Map<String, dynamic> body) async {
    final data = await post('/projects', body);
    return Project.fromJson(data);
  }

  Future<Project> updateProject(int id, Map<String, dynamic> body) async {
    final data = await put('/projects/$id', body);
    return Project.fromJson(data);
  }

  Future<void> deleteProject(int id) => delete('/projects/$id');

  Future<MaterialUsage> assignMaterial(int projectId, int itemId, double qty,
      {String? notes}) async {
    final data = await post('/projects/$projectId/assign-material', {
      'project_id': projectId,
      'inventory_item_id': itemId,
      'quantity': qty,
      if (notes != null) 'notes': notes,
    });
    return MaterialUsage.fromJson(data);
  }

  Future<MaterialUsage> returnMaterial(int projectId, int itemId, double qty,
      {String? notes}) async {
    final data = await post('/projects/$projectId/return-material', {
      'project_id': projectId,
      'inventory_item_id': itemId,
      'quantity': qty,
      if (notes != null) 'notes': notes,
    });
    return MaterialUsage.fromJson(data);
  }

  Future<List<MaterialUsage>> getProjectMaterials(int projectId) async {
    final data = await get('/projects/$projectId/materials');
    return (data as List).map((e) => MaterialUsage.fromJson(e)).toList();
  }

  // ─── Suppliers ─────────────────────────────────────────────────────────────

  Future<List<Supplier>> getSuppliers({String? search}) async {
    final params = search != null ? {'search': search} : null;
    final data = await get('/suppliers', params);
    return (data as List).map((e) => Supplier.fromJson(e)).toList();
  }

  Future<Supplier> createSupplier(Map<String, dynamic> body) async {
    final data = await post('/suppliers', body);
    return Supplier.fromJson(data);
  }

  Future<Supplier> updateSupplier(int id, Map<String, dynamic> body) async {
    final data = await put('/suppliers/$id', body);
    return Supplier.fromJson(data);
  }

  // ─── Purchases ─────────────────────────────────────────────────────────────

  Future<List<Purchase>> getPurchases({int? supplierId}) async {
    final params = supplierId != null ? {'supplier_id': supplierId} : null;
    final data = await get('/purchases', params);
    return (data as List).map((e) => Purchase.fromJson(e)).toList();
  }

  Future<Purchase> createPurchase(Map<String, dynamic> body) async {
    final data = await post('/purchases', body);
    return Purchase.fromJson(data);
  }

  // ─── Reports ───────────────────────────────────────────────────────────────

  Future<DashboardStats> getDashboard() async {
    final data = await get('/reports/dashboard');
    return DashboardStats.fromJson(data);
  }

  Future<Map<String, dynamic>> getStockSummary() async {
    return await get('/reports/stock-summary');
  }

  Future<List<StockSummaryItem>> getLowStock() async {
    final data = await get('/reports/low-stock');
    return (data as List).map((e) => StockSummaryItem.fromJson(e)).toList();
  }

  Future<List<Map<String, dynamic>>> getProjectProfits() async {
    final data = await get('/reports/project-profits');
    return List<Map<String, dynamic>>.from(data);
  }

  Future<Map<String, dynamic>> getProjectCostBreakdown(int projectId) async {
    return await get('/reports/project/$projectId/cost-breakdown');
  }
}
