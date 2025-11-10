import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/services/supabase_service.dart';
import '../../domain/entities/cities.dart';

class CityRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  Future<List<City>> getActiveCities() async {
    final response = await _supabase
        .from('cities')
        .select()
        .eq('active', true)
        .order('name');
    
    return (response as List).map((json) => City.fromJson(json)).toList();
  }

  Future<City?> getCityById(String cityId) async {
    final response = await _supabase
        .from('cities')
        .select()
        .eq('id', cityId)
        .maybeSingle();
    
    return response != null ? City.fromJson(response) : null;
  }
}