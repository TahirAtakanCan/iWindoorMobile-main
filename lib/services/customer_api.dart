import 'package:dio/dio.dart';

import '../models/customer.dart';
import '../models/dashboard.dart';
import '../models/payment.dart';
import '../models/project.dart';
import '../utils/status.dart';
import 'design_api.dart';
import 'offline/api_dio.dart';

class CustomerApi {
  final Dio _dio;

  CustomerApi({Dio? dio}) : _dio = dio ?? createApiDio();

  Future<T> _call<T>(Future<T> Function() f) async {
    try {
      return await f();
    } catch (e) {
      throw ApiError.from(e);
    }
  }

  Future<List<Customer>> listCustomers({String? q}) => _call(() async {
        final r = await _dio.get('/customers', queryParameters: {
          if (q != null && q.trim().isNotEmpty) 'q': q.trim(),
        });
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['customers'] as List? ?? const []) : const []);
        return [for (final c in list) Customer.fromJson(Map<String, dynamic>.from(c as Map))];
      });

  Future<Customer> getCustomer(int id) => _call(() async {
        final r = await _dio.get('/customers/$id');
        return Customer.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<Customer> createCustomer(Customer c) => _call(() async {
        final r = await _dio.post('/customers', data: c.toJson());
        return Customer.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<Customer> updateCustomer(int id, Customer c) => _call(() async {
        final r = await _dio.put('/customers/$id', data: c.toJson());
        return Customer.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> deleteCustomer(int id) => _call(() => _dio.delete('/customers/$id'));

  Future<DashboardSummary> dashboard() => _call(() async {
        final r = await _dio.get('/dashboard');
        return DashboardSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<Project> changeStatus(
    int projectId, {
    required ProjectStatus status,
    String? note,
    DateTime? deliveryDate,
  }) =>
      _call(() async {
        final r = await _dio.post('/projects/$projectId/status', data: {
          'status': status.apiValue,
          if (note != null && note.isNotEmpty) 'note': note,
          if (deliveryDate != null) 'deliveryDate': deliveryDate.toIso8601String().substring(0, 10),
        });
        return Project.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<List<StatusHistoryEntry>> statusHistory(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/history');
        final raw = r.data;
        final list = raw is List ? raw : (raw is Map ? (raw['items'] as List? ?? raw['history'] as List? ?? const []) : const []);
        return [for (final e in list) StatusHistoryEntry.fromJson(Map<String, dynamic>.from(e as Map))];
      });

  Future<Project> setDeliveryDate(int projectId, DateTime? date) => _call(() async {
        final r = await _dio.put('/projects/$projectId/delivery-date', data: {
          'deliveryDate': date?.toIso8601String().substring(0, 10),
        });
        return Project.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<PaymentsSummary> listPayments(int projectId) => _call(() async {
        final r = await _dio.get('/projects/$projectId/payments');
        return PaymentsSummary.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<Payment> createPayment(int projectId, Payment payment) => _call(() async {
        final r = await _dio.post('/projects/$projectId/payments', data: payment.toJson());
        return Payment.fromJson(Map<String, dynamic>.from(r.data as Map));
      });

  Future<void> deletePayment(int projectId, int paymentId) =>
      _call(() => _dio.delete('/projects/$projectId/payments/$paymentId'));
}
