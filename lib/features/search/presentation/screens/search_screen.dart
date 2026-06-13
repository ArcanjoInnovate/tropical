// lib/features/search/presentation/screens/search_screen.dart

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:geolocator/geolocator.dart';
import 'package:provider/provider.dart';

import 'package:tabuapp/core/providers/block_provider.dart';
import 'package:tabuapp/core/theme/tabu_theme.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_bloc.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_event.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_filters.dart';
import 'package:tabuapp/features/search/presentation/bloc/search_state.dart';
import 'package:tabuapp/features/search/presentation/widgets/search_bar_widget.dart';
import 'package:tabuapp/features/search/presentation/widgets/filter_dropdown.dart';
import 'package:tabuapp/features/search/presentation/widgets/proximity_controls.dart';
import 'package:tabuapp/features/search/presentation/widgets/user_tile.dart';
import 'package:tabuapp/features/search/presentation/widgets/party_tile.dart';
import 'package:tabuapp/features/search/presentation/widgets/party_detail_sheet.dart';
import 'package:tabuapp/features/search/di/search_injection.dart';
import 'package:tabuapp/features/profile/presentation/pages/profile/public_profile_screen.dart';
import 'package:tabuapp/features/search/data/services/ibge_service.dart';
import 'package:tabuapp/features/admin/data/services/location_service.dart';

class SearchScreen extends StatelessWidget {
  final String myUid;

  const SearchScreen({super.key, required this.myUid});

  @override
  Widget build(BuildContext context) {
    final blockedIds = context.read<BlockProvider>().allBlockedIds;

    return BlocProvider(
      create: (_) => SearchInjection.createBloc()
        ..add(SearchInitialized(
          myUid: myUid,
          blockedIds: blockedIds,
        )),
      child: _SearchView(myUid: myUid),
    );
  }
}

class _SearchView extends StatefulWidget {
  final String myUid;

  const _SearchView({required this.myUid});

  @override
  State<_SearchView> createState() => _SearchViewState();
}

class _SearchViewState extends State<_SearchView> {
  final _scrollController = ScrollController();
  final _ibgeService = IbgeService();
  bool _isLocating = false;

  Set<String> _lastKnownBlockedIds = {};

  @override
  void initState() {
    super.initState();
    _scrollController.addListener(_onScroll);

    WidgetsBinding.instance.addPostFrameCallback((_) {
      final blockProvider = context.read<BlockProvider>();
      _lastKnownBlockedIds = Set.from(blockProvider.allBlockedIds);
      blockProvider.addListener(_onBlockProviderChanged);
    });
  }

  @override
  void dispose() {
    _scrollController.dispose();
    try {
      context.read<BlockProvider>().removeListener(_onBlockProviderChanged);
    } catch (_) {}
    super.dispose();
  }

  void _onBlockProviderChanged() {
    if (!mounted) return;

    final blockProvider = context.read<BlockProvider>();
    final current = blockProvider.allBlockedIds;

    final changed = current.length != _lastKnownBlockedIds.length ||
        !current.containsAll(_lastKnownBlockedIds);

    if (changed) {
      _lastKnownBlockedIds = Set.from(current);
      context
          .read<SearchBloc>()
          .add(SearchBlockedIdsUpdated(Set.from(current)));
    }
  }

  void _onScroll() {
    if (_scrollController.position.pixels >=
        _scrollController.position.maxScrollExtent - 200) {
      context.read<SearchBloc>().add(const SearchNextPageRequested());
    }
  }

  Future<void> _requestLocation() async {
    setState(() => _isLocating = true);

    try {
      bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        _showSnackbar('Serviço de localização desativado.');
        return;
      }

      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
        if (permission == LocationPermission.denied) {
          _showSnackbar('Permissão de localização negada.');
          return;
        }
      }

      if (permission == LocationPermission.deniedForever) {
        _showSnackbar(
            'Permissão negada permanentemente. Ative nas configurações.');
        return;
      }

      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.medium,
      );

      if (mounted) {
        context.read<SearchBloc>().add(SearchProximityActivated(
              latitude: position.latitude,
              longitude: position.longitude,
              radiusKm: 10.0,
            ));
      }
    } catch (e) {
      _showSnackbar('Erro ao obter localização: $e');
    } finally {
      if (mounted) setState(() => _isLocating = false);
    }
  }

  void _showSnackbar(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message)),
    );
  }

  // ── Force refresh ────────────────────────────────────────────────────────

  Future<void> _onRefresh() async {
    context.read<SearchBloc>().add(const SearchRefreshRequested());
    // Aguarda o estado sair de isLoading para o pull-to-refresh fechar
    await Future.doWhile(() async {
      await Future.delayed(const Duration(milliseconds: 80));
      if (!mounted) return false;
      final state = context.read<SearchBloc>().state;
      return state.isLoading;
    }).timeout(const Duration(seconds: 10), onTimeout: () {});
  }

  // ── Build ────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Buscar'),
        actions: [
          BlocBuilder<SearchBloc, SearchState>(
            buildWhen: (prev, curr) => prev.isLoading != curr.isLoading,
            builder: (context, state) => IconButton(
              tooltip: 'Atualizar',
              icon: state.isLoading
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.refresh),
              onPressed:
                  state.isLoading ? null : _onRefresh,
            ),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(48),
          child: _SearchTypeTabs(),
        ),
      ),
      body: BlocBuilder<SearchBloc, SearchState>(
        builder: (context, state) {
          // RefreshIndicator envolve o Column inteiro para capturar o gesto
          // mesmo nos estados de loading/erro/vazio (sem lista scrollável).
          return RefreshIndicator(
            onRefresh: _onRefresh,
            child: Column(
              children: [
                _buildTopControls(context, state),
                const Divider(height: 1),
                Expanded(child: _buildBody(context, state)),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildTopControls(BuildContext context, SearchState state) {
    return Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        children: [
          SearchBarWidget(
            hint: state.filters.isUsersSearch
                ? 'Buscar pessoas...'
                : 'Buscar festas...',
            initialValue: state.filters.query,
            onChanged: (q) =>
                context.read<SearchBloc>().add(SearchQueryChanged(q)),
          ),
          const SizedBox(height: 8),
          ProximityControls(
            radiusKm: state.filters.radiusKm,
            isActive: state.filters.isProximityActive,
            isLocating: _isLocating,
            onActivate: _requestLocation,
            onDeactivate: () =>
                context.read<SearchBloc>().add(const SearchFiltersCleared()),
            onRadiusChanged: (r) =>
                context.read<SearchBloc>().add(SearchRadiusChanged(r)),
          ),
          if (!state.filters.isProximityActive)
            TextButton.icon(
              icon: Icon(
                state.filters.isFilterActive
                    ? Icons.filter_alt
                    : Icons.filter_alt_outlined,
              ),
              label: Text(
                state.filters.isFilterActive
                    ? 'Filtros ativos'
                    : 'Filtrar por localização',
              ),
              onPressed: () => _showFilterSheet(context, state),
            ),
        ],
      ),
    );
  }

  Widget _buildBody(BuildContext context, SearchState state) {
    if (state.isLoading) {
      // SingleChildScrollView com AlwaysScrollableScrollPhysics garante que
      // o pull-to-refresh funcione mesmo sem conteúdo suficiente para scroll.
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (state.hasError) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.error_outline, size: 48, color: Colors.red),
                const SizedBox(height: 8),
                Text(state.errorMessage!),
                const SizedBox(height: 16),
                ElevatedButton(
                  onPressed: _onRefresh,
                  child: const Text('Tentar novamente'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (state.isEmpty) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.5,
          child: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.search_off, size: 48, color: Colors.grey),
                const SizedBox(height: 8),
                Text(
                  state.filters.isUsersSearch
                      ? 'Nenhuma pessoa encontrada'
                      : 'Nenhuma festa encontrada',
                ),
                if (state.filters.hasActiveFilters) ...[
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context
                        .read<SearchBloc>()
                        .add(const SearchFiltersCleared()),
                    child: const Text('Limpar filtros'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    // Sem RefreshIndicator aqui — está no nível do Column em build().
    return state.filters.isUsersSearch
        ? _buildUsersList(context, state)
        : _buildPartiesList(context, state);
  }

  Widget _buildUsersList(BuildContext context, SearchState state) {
    final users = state.visibleUsers;
    final isProx = state.filters.isProximityActive;

    return LayoutBuilder(
      builder: (context, constraints) {
        // Número de colunas: 3 fixo até 480 dp, 4 em tablets.
        const crossAxisCount = 3;
        const crossAxisSpacing = 10.0;
        const mainAxisSpacing = 8.0;
        const padding = 12.0;

        // Largura real de cada célula considerando padding e espaços.
        final totalHorizontalPadding = padding * 2;
        final totalSpacing = crossAxisSpacing * (crossAxisCount - 1);
        final cellWidth = (constraints.maxWidth -
                totalHorizontalPadding -
                totalSpacing) /
            crossAxisCount;

        // Altura da célula definida em dp fixos — igual em qualquer tela.
        // Ajuste este valor para o conteúdo do UserTile.
        const cellHeight = 180.0;

        final childAspectRatio = cellWidth / cellHeight;

        return GridView.builder(
          controller: _scrollController,
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(padding),
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: crossAxisCount,
            mainAxisSpacing: mainAxisSpacing,
            crossAxisSpacing: crossAxisSpacing,
            childAspectRatio: childAspectRatio,
          ),
          itemCount: users.length + (state.pagination.isLoadingMore ? 1 : 0),
          itemBuilder: (context, index) {
            if (index == users.length) {
              return const Center(child: CircularProgressIndicator());
            }

            final user = users[index];

            double? distance;
            if (isProx &&
                user.latitude != null &&
                user.longitude != null &&
                state.filters.latitude != null &&
                state.filters.longitude != null) {
              distance = LocationService.distanceKm(
                state.filters.latitude!,
                state.filters.longitude!,
                user.latitude!,
                user.longitude!,
              );
            }

            return UserTile(
              user: user,
              distanceKm: distance,
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => PublicProfileScreen(
                      userId: user.uid,
                      userName: user.name,
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  Widget _buildPartiesList(BuildContext context, SearchState state) {
    final isProx = state.filters.isProximityActive;

    return ListView.builder(
      controller: _scrollController,
      physics: const AlwaysScrollableScrollPhysics(),
      itemCount:
          state.parties.length + (state.pagination.isLoadingMore ? 1 : 0),
      itemBuilder: (context, index) {
        if (index == state.parties.length) {
          return const Padding(
            padding: EdgeInsets.all(16),
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final party = state.parties[index];

        double? distance;
        if (isProx &&
            party.latitude != null &&
            party.longitude != null &&
            state.filters.latitude != null &&
            state.filters.longitude != null) {
          distance = LocationService.distanceKm(
            state.filters.latitude!,
            state.filters.longitude!,
            party.latitude!,
            party.longitude!,
          );
        }

        return PartyTile(
          party: party,
          distanceKm: distance,
          onTap: () => PartyDetailSheet.show(
            context,
            festa: party,
            myUid: widget.myUid,
            homeCoords: state.filters.isProximityActive &&
                    state.filters.latitude != null &&
                    state.filters.longitude != null
                ? (
                    latitude: state.filters.latitude!,
                    longitude: state.filters.longitude!,
                  )
                : null,
            onRefresh: () =>
                context.read<SearchBloc>().add(const SearchRefreshRequested()),
            userData: {},
          ),
        );
      },
    );
  }

  /// Captura o bloc ANTES de abrir o sheet (enquanto o context
  /// ainda está na árvore do BlocProvider) e o reinjecta via BlocProvider.value
  /// dentro da nova rota do modal — que tem seu próprio contexto isolado.
  void _showFilterSheet(BuildContext context, SearchState state) {
    final bloc = context.read<SearchBloc>();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: TabuTheme.main.scaffoldBackgroundColor,
      barrierColor: Colors.black54,
      elevation: 0,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => BlocProvider.value(
        value: bloc,
        child: Material(
          color: TabuTheme.main.scaffoldBackgroundColor,
          child: DraggableScrollableSheet(
            expand: false,
            initialChildSize: 0.5,
            minChildSize: 0.35,
            maxChildSize: 0.85,
            builder: (sheetContext, scrollController) {
              return Container(
                color: TabuTheme.main.scaffoldBackgroundColor,
                child: SingleChildScrollView(
                  controller: scrollController,
                  padding: EdgeInsets.only(
                    left: 16,
                    right: 16,
                    top: 16,
                    bottom:
                        MediaQuery.of(sheetContext).viewInsets.bottom + 16,
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Center(
                        child: Container(
                          width: 40,
                          height: 4,
                          margin: const EdgeInsets.only(bottom: 16),
                          decoration: BoxDecoration(
                            color: Colors.grey.shade300,
                            borderRadius: BorderRadius.circular(2),
                          ),
                        ),
                      ),
                      Text(
                        'Filtrar por localização',
                        style: Theme.of(sheetContext)
                            .textTheme
                            .titleMedium
                            ?.copyWith(fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 16),
                      FilterDropdown(
                        ibgeService: _ibgeService,
                        selectedEstado: state.filters.estadoSigla,
                        selectedCidade: state.filters.cidadeNome,
                        selectedBairro: state.filters.bairro,
                        onApply: ({estadoSigla, cidadeNome, bairro}) {
                          Navigator.pop(sheetContext);
                          bloc.add(
                            SearchLocationFilterApplied(
                              estadoSigla: estadoSigla,
                              cidadeNome: cidadeNome,
                              bairro: bairro,
                            ),
                          );
                        },
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }
}

// ── Tabs de tipo de busca ────────────────────────────────────────────────────

class _SearchTypeTabs extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<SearchBloc, SearchState>(
      buildWhen: (prev, curr) =>
          prev.filters.searchType != curr.filters.searchType,
      builder: (context, state) {
        return Row(
          children: [
            _Tab(
              label: 'Pessoas',
              icon: Icons.person_search,
              isSelected: state.filters.isUsersSearch,
              onTap: () => context
                  .read<SearchBloc>()
                  .add(const SearchTypeChanged(SearchType.users)),
            ),
            _Tab(
              label: 'Festas',
              icon: Icons.celebration,
              isSelected: state.filters.isPartiesSearch,
              onTap: () => context
                  .read<SearchBloc>()
                  .add(const SearchTypeChanged(SearchType.parties)),
            ),
          ],
        );
      },
    );
  }
}

class _Tab extends StatelessWidget {
  final String label;
  final IconData icon;
  final bool isSelected;
  final VoidCallback onTap;

  const _Tab({
    required this.label,
    required this.icon,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 10),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                icon,
                size: 18,
                color: isSelected
                    ? Theme.of(context).colorScheme.primary
                    : Colors.grey,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: TextStyle(
                  fontWeight:
                      isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected
                      ? Theme.of(context).colorScheme.primary
                      : Colors.grey,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}