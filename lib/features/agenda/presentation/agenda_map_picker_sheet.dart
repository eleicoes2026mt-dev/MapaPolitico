import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart' as ll;

import '../../../core/config/env_config.dart';
import '../../../core/geo/lat_lng.dart' as app_geo;
import '../../../core/services/geocode_reverse_service.dart';
import '../../../core/services/google_places_service.dart';
import '../../../core/services/maps_navigation_service.dart';

/// Resultado do seletor de ponto no mapa (endereço + coordenadas).
class AgendaMapPickerResult {
  const AgendaMapPickerResult({
    required this.addressLabel,
    required this.lat,
    required this.lng,
  });

  final String addressLabel;
  final double lat;
  final double lng;
}

/// Mapa com busca de locais (Google Places + Geocoding ou Nominatim) + toque para ajustar o pino.
Future<AgendaMapPickerResult?> showAgendaMapPickerSheet(
  BuildContext context, {
  required app_geo.LatLng initialCenter,
  required String municipioNome,
  String? searchBiasSuffix,
  String? initialSearchText,
}) {
  return showDialog<AgendaMapPickerResult>(
    context: context,
    barrierDismissible: false,
    builder: (ctx) => _AgendaMapPickerDialog(
      initialCenter: initialCenter,
      municipioNome: municipioNome,
      searchBiasSuffix: searchBiasSuffix,
      initialSearchText: initialSearchText,
    ),
  );
}

class _AgendaMapPickerDialog extends StatefulWidget {
  const _AgendaMapPickerDialog({
    required this.initialCenter,
    required this.municipioNome,
    this.searchBiasSuffix,
    this.initialSearchText,
  });

  final app_geo.LatLng initialCenter;
  final String municipioNome;
  final String? searchBiasSuffix;
  final String? initialSearchText;

  @override
  State<_AgendaMapPickerDialog> createState() => _AgendaMapPickerDialogState();
}

class _AgendaMapPickerDialogState extends State<_AgendaMapPickerDialog> {
  late final MapController _mapController;
  late final TextEditingController _busca;
  late ll.LatLng _marcador;
  late final String _placesSessionToken;

  Timer? _debounce;
  bool _buscando = false;
  bool _resolvendo = false;
  bool _silenciarBusca = false;
  List<PlacePrediction> _sugGoogle = [];
  List<GeocodeHit> _sugGeocode = [];
  List<NominatimSearchHit> _sugNom = [];

  bool get _usaGoogle => EnvConfig.googleMapsApiKey.trim().isNotEmpty;

  @override
  void initState() {
    super.initState();
    _placesSessionToken =
        '${DateTime.now().microsecondsSinceEpoch}_${identityHashCode(this)}';
    _mapController = MapController();
    _marcador = ll.LatLng(widget.initialCenter.latitude, widget.initialCenter.longitude);
    _busca = TextEditingController(text: widget.initialSearchText ?? '');
    _busca.addListener(_onBuscaChanged);
  }

  void _onBuscaChanged() {
    if (_silenciarBusca) return;
    _debounce?.cancel();
    final raw = _busca.text.trim();
    if (raw.length < 3) {
      setState(() {
        _sugGoogle = [];
        _sugGeocode = [];
        _sugNom = [];
      });
      return;
    }
    _debounce = Timer(const Duration(milliseconds: 400), _executarBusca);
  }

  Future<void> _executarBusca() async {
    if (!mounted) return;
    final raw = _busca.text.trim();
    if (raw.length < 3) return;

    final ctx = GooglePlacesMunicipioContext(
      centerLat: widget.initialCenter.latitude,
      centerLng: widget.initialCenter.longitude,
      municipioNome: widget.municipioNome,
    );

    setState(() => _buscando = true);
    if (_usaGoogle) {
      // Nearby + Text Search + Autocomplete (termos genéricos como "escola estadual").
      var list = await fetchGooglePlacesAgendaPickerResults(
        raw,
        ctx,
        sessionToken: _placesSessionToken,
      );
      var geo = <GeocodeHit>[];
      if (list.isEmpty) {
        final geoQuery = '$raw, ${widget.municipioNome}, MT, Brasil';
        geo = await fetchGoogleGeocodeForward(
          geoQuery,
          bounds: ctx.geocodeBounds,
          municipioContext: ctx,
        );
      }
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _sugGoogle = list;
        _sugGeocode = geo;
        _sugNom = [];
      });
    } else {
      final suffix = widget.searchBiasSuffix?.trim();
      final q = (suffix != null && suffix.isNotEmpty) ? '$raw$suffix' : raw;
      final list = await nominatimSearchPlaces(q);
      if (!mounted) return;
      setState(() {
        _buscando = false;
        _sugNom = list;
        _sugGoogle = [];
        _sugGeocode = [];
      });
    }
  }

  void _buscarAgora() {
    _debounce?.cancel();
    _executarBusca();
  }

  void _irPara(ll.LatLng p, {double zoom = 16}) {
    setState(() => _marcador = p);
    _mapController.move(p, zoom);
  }

  Future<void> _aoEscolherGoogle(PlacePrediction p) async {
    setState(() {
      _buscando = true;
      _sugGoogle = [];
      _sugGeocode = [];
      _sugNom = [];
    });
    final d = await fetchGooglePlaceDetailsLatLng(p.placeId);
    if (!mounted) return;
    setState(() => _buscando = false);
    if (d != null) {
      _irPara(ll.LatLng(d.lat, d.lng));
      _silenciarBusca = true;
      _busca.text = d.primaryLabel;
      _silenciarBusca = false;
    }
    FocusScope.of(context).unfocus();
  }

  void _aoEscolherGeocode(GeocodeHit h) {
    _irPara(ll.LatLng(h.lat, h.lng));
    _silenciarBusca = true;
    _busca.text = h.displayLabel;
    _silenciarBusca = false;
    setState(() {
      _sugGeocode = [];
      _sugGoogle = [];
      _sugNom = [];
    });
    FocusScope.of(context).unfocus();
  }

  void _aoEscolherNominatim(NominatimSearchHit h) {
    _irPara(ll.LatLng(h.lat, h.lng));
    _silenciarBusca = true;
    _busca.text = h.displayName;
    _silenciarBusca = false;
    setState(() {
      _sugNom = [];
      _sugGoogle = [];
      _sugGeocode = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _usarCoordenadas() async {
    setState(() => _resolvendo = true);
    final texto = await reverseGeocodeLabel(_marcador.latitude, _marcador.longitude);
    if (!mounted) return;
    setState(() => _resolvendo = false);
    final fallback =
        '${_marcador.latitude.toStringAsFixed(5)}, ${_marcador.longitude.toStringAsFixed(5)}';
    final label = (texto != null && texto.trim().isNotEmpty) ? texto.trim() : fallback;
    Navigator.of(context).pop(
      AgendaMapPickerResult(
        addressLabel: label,
        lat: _marcador.latitude,
        lng: _marcador.longitude,
      ),
    );
  }

  Future<void> _abrirExterno(Future<bool> Function() fn) async {
    final ok = await fn();
    if (!mounted) return;
    if (!ok) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Não foi possível abrir o app de mapas.')),
      );
    }
  }

  @override
  void dispose() {
    _debounce?.cancel();
    _busca.removeListener(_onBuscaChanged);
    _busca.dispose();
    _mapController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final h = MediaQuery.sizeOf(context).height * 0.82;
    final temSugestoes = _sugGoogle.isNotEmpty || _sugGeocode.isNotEmpty || _sugNom.isNotEmpty;
    final totalSug = _usaGoogle ? _sugGoogle.length + _sugGeocode.length : _sugNom.length;

    return AlertDialog(
      titlePadding: EdgeInsets.zero,
      contentPadding: EdgeInsets.zero,
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 20),
      title: ListTile(
        leading: Icon(Icons.map_outlined, color: theme.colorScheme.primary),
        title: const Text('Local no mapa'),
        subtitle: Text(
          widget.municipioNome,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      content: SizedBox(
        width: 560,
        height: h,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: TextField(
                controller: _busca,
                decoration: InputDecoration(
                  labelText: _usaGoogle ? 'Buscar lugar (Google)' : 'Buscar lugar (OpenStreetMap)',
                  hintText: 'Rua, bairro, comércio…',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: _buscando
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        )
                      : IconButton(
                          tooltip: 'Pesquisar',
                          icon: const Icon(Icons.manage_search),
                          onPressed: _buscarAgora,
                        ),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  isDense: true,
                ),
                textCapitalization: TextCapitalization.sentences,
                onSubmitted: (_) => _buscarAgora(),
              ),
            ),
            if (kIsWeb && !_usaGoogle)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Text(
                  'No navegador, a busca OpenStreetMap costuma falhar por CORS. '
                  'Configure GOOGLE_MAPS_API_KEY para ver sugestões e lista de resultados.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.error),
                ),
              ),
            if (temSugestoes)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 6, 12, 0),
                child: Material(
                  elevation: 2,
                  borderRadius: BorderRadius.circular(10),
                  clipBehavior: Clip.antiAlias,
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxHeight: 280),
                    child: ListView.separated(
                      shrinkWrap: true,
                      padding: EdgeInsets.zero,
                      itemCount: totalSug,
                      separatorBuilder: (_, __) => Divider(height: 1, color: theme.colorScheme.outlineVariant),
                      itemBuilder: (_, i) {
                        if (_usaGoogle) {
                          if (i < _sugGoogle.length) {
                            final p = _sugGoogle[i];
                            return ListTile(
                              dense: true,
                              leading: Icon(Icons.place_outlined, size: 22, color: theme.colorScheme.primary),
                              title: Text(p.description, maxLines: 2, overflow: TextOverflow.ellipsis),
                              onTap: () => _aoEscolherGoogle(p),
                            );
                          }
                          final g = _sugGeocode[i - _sugGoogle.length];
                          return ListTile(
                            dense: true,
                            leading: Icon(Icons.my_location_outlined, size: 22, color: theme.colorScheme.secondary),
                            title: Text(g.displayLabel, maxLines: 3, overflow: TextOverflow.ellipsis),
                            onTap: () => _aoEscolherGeocode(g),
                          );
                        }
                        final n = _sugNom[i];
                        return ListTile(
                          dense: true,
                          leading: Icon(Icons.location_searching, size: 22, color: theme.colorScheme.primary),
                          title: Text(n.displayName, maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _aoEscolherNominatim(n),
                        );
                      },
                    ),
                  ),
                ),
              ),
            if (!_buscando && _busca.text.trim().length >= 3 && !temSugestoes && _usaGoogle)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Text(
                  'Nenhum resultado. Tente outro termo ou toque na lupa para pesquisar de novo.',
                  style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 4),
              child: Text(
                'Toque no mapa para ajustar o pino. Escolha um item da lista para ir ao ponto — '
                'esse será o local da reunião ao confirmar.',
                style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _marcador,
                      initialZoom: 14,
                      minZoom: 4,
                      maxZoom: 18,
                      onTap: (_, p) => setState(() => _marcador = p),
                    ),
                    children: [
                      TileLayer(
                        urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'campanha_mt',
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: _marcador,
                            width: 48,
                            height: 48,
                            alignment: Alignment.bottomCenter,
                            child: Icon(Icons.location_on, color: theme.colorScheme.primary, size: 48),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                'Lat ${_marcador.latitude.toStringAsFixed(5)}, '
                'lng ${_marcador.longitude.toStringAsFixed(5)}',
                style: theme.textTheme.labelSmall?.copyWith(color: theme.colorScheme.onSurfaceVariant),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
              child: Wrap(
                spacing: 8,
                runSpacing: 4,
                alignment: WrapAlignment.center,
                children: [
                  OutlinedButton.icon(
                    onPressed: () => _abrirExterno(
                      () => openGoogleMapsDestination(
                        lat: _marcador.latitude,
                        lng: _marcador.longitude,
                      ),
                    ),
                    icon: const Icon(Icons.map, size: 18),
                    label: const Text('Google Maps'),
                  ),
                  OutlinedButton.icon(
                    onPressed: () => _abrirExterno(
                      () => openWazeDestination(lat: _marcador.latitude, lng: _marcador.longitude),
                    ),
                    icon: const Icon(Icons.navigation, size: 18),
                    label: const Text('Waze'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
              child: Row(
                children: [
                  TextButton(
                    onPressed: _resolvendo ? null : () => Navigator.pop(context),
                    child: const Text('Cancelar'),
                  ),
                  const Spacer(),
                  FilledButton.icon(
                    onPressed: _resolvendo ? null : _usarCoordenadas,
                    icon: _resolvendo
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : const Icon(Icons.check, size: 20),
                    label: Text(_resolvendo ? 'Resolvendo…' : 'Usar este local'),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
