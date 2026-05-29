import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/theme/app_theme.dart';
import '../../../auth/domain/user_model.dart';
import '../providers/admin_provider.dart';
import '../../domain/admin_models.dart';

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _activeTab = 0;
  final TextEditingController _userSearchController = TextEditingController();
  final TextEditingController _notificationTitleController = TextEditingController();
  final TextEditingController _notificationBodyController = TextEditingController();
  
  // Tournament form controllers
  final TextEditingController _tournamentTitleController = TextEditingController();
  final TextEditingController _tournamentEntryFeeController = TextEditingController();
  final TextEditingController _tournamentPrizePoolController = TextEditingController();
  DateTime? _selectedTournamentTime;

  @override
  void initState() {
    super.initState();
    Future.microtask(() {
      ref.read(adminProvider.notifier).fetchAll();
    });
  }

  @override
  void dispose() {
    _userSearchController.dispose();
    _notificationTitleController.dispose();
    _notificationBodyController.dispose();
    _tournamentTitleController.dispose();
    _tournamentEntryFeeController.dispose();
    _tournamentPrizePoolController.dispose();
    super.dispose();
  }

  void _showAdjustRewardsDialog(UserModel user) {
    final coinsController = TextEditingController(text: '100');
    final xpController = TextEditingController(text: '50');

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(
          'Adjust Balance: ${user.name}',
          style: const TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: coinsController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Modify Coins (positive or negative)',
                filled: true,
                fillColor: Color(0xFF1E293B),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: xpController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: 'Modify XP (positive or negative)',
                filled: true,
                fillColor: Color(0xFF1E293B),
                border: OutlineInputBorder(),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
          ),
          ElevatedButton(
            onPressed: () async {
              final coins = int.tryParse(coinsController.text) ?? 0;
              final xp = int.tryParse(xpController.text) ?? 0;
              
              Navigator.pop(context);
              
              final success = await ref.read(adminProvider.notifier).adjustUserCoins(user.id, coins, xp);
              if (success && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('User balances successfully updated!'), backgroundColor: AppColors.ludoGreen),
                );
              }
            },
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary),
            child: const Text('Update'),
          ),
        ],
      ),
    );
  }

  void _showCreateTournamentDialog() {
    _tournamentTitleController.clear();
    _tournamentEntryFeeController.text = '200';
    _tournamentPrizePoolController.text = '1000';
    _selectedTournamentTime = DateTime.now().add(const Duration(days: 1));

    showDialog(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Create New Tournament', style: TextStyle(fontWeight: FontWeight.bold, fontFamily: 'Outfit')),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  controller: _tournamentTitleController,
                  decoration: const InputDecoration(
                    labelText: 'Tournament Title',
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tournamentEntryFeeController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Entry Fee (Coins)',
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 12),
                TextField(
                  controller: _tournamentPrizePoolController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(
                    labelText: 'Prize Pool (Coins)',
                    filled: true,
                    fillColor: Color(0xFF1E293B),
                    border: OutlineInputBorder(),
                  ),
                ),
                const SizedBox(height: 16),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Start Time:', style: TextStyle(fontWeight: FontWeight.bold)),
                    ElevatedButton.icon(
                      onPressed: () async {
                        final date = await showDatePicker(
                          context: context,
                          initialDate: _selectedTournamentTime!,
                          firstDate: DateTime.now(),
                          lastDate: DateTime.now().add(const Duration(days: 365)),
                        );
                        if (date != null) {
                          final time = await showTimePicker(
                            context: context,
                            initialTime: TimeOfDay.fromDateTime(_selectedTournamentTime!),
                          );
                          if (time != null) {
                            setState(() {
                              _selectedTournamentTime = DateTime(
                                date.year,
                                date.month,
                                date.day,
                                time.hour,
                                time.minute,
                              );
                            });
                          }
                        }
                      },
                      icon: const Icon(Icons.calendar_month, size: 18),
                      label: Text(
                        '${_selectedTournamentTime!.day}/${_selectedTournamentTime!.month} ${_selectedTournamentTime!.hour.toString().padLeft(2, '0')}:${_selectedTournamentTime!.minute.toString().padLeft(2, '0')}',
                        style: const TextStyle(fontSize: 12),
                      ),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBg,
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: const Text('Cancel', style: TextStyle(color: Colors.white70)),
            ),
            ElevatedButton(
              onPressed: () async {
                final title = _tournamentTitleController.text.trim();
                final entryFee = int.tryParse(_tournamentEntryFeeController.text) ?? 200;
                final prizePool = int.tryParse(_tournamentPrizePoolController.text) ?? 1000;

                if (title.isEmpty) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Please enter a title'), backgroundColor: AppColors.ludoRed),
                  );
                  return;
                }

                Navigator.pop(context);
                final success = await ref.read(adminProvider.notifier).createTournament(
                  title: title,
                  entryFee: entryFee,
                  prizePool: prizePool,
                  startTime: _selectedTournamentTime!,
                );
                if (success && mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Tournament created successfully!'), backgroundColor: AppColors.ludoGreen),
                  );
                }
              },
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
              child: const Text('Create'),
            ),
          ],
        ),
      ),
    );
  }

  void _handleBroadcastNotification() async {
    final title = _notificationTitleController.text.trim();
    final body = _notificationBodyController.text.trim();

    if (title.isEmpty || body.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a title and message body'), backgroundColor: AppColors.ludoRed),
      );
      return;
    }

    final success = await ref.read(adminProvider.notifier).broadcastNotification(title, body);
    if (success && mounted) {
      _notificationTitleController.clear();
      _notificationBodyController.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('System alert broadcast triggered!'), backgroundColor: AppColors.ludoGreen),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final adminState = ref.watch(adminProvider);
    final isDesktop = MediaQuery.of(context).size.width > 900;

    // Direct listener for error messages
    ref.listen<AdminState>(adminProvider, (previous, next) {
      if (next.errorMessage != null && next.errorMessage != previous?.errorMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.errorMessage!), backgroundColor: AppColors.ludoRed),
        );
        ref.read(adminProvider.notifier).clearMessages();
      }
      if (next.successMessage != null && next.successMessage != previous?.successMessage) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(next.successMessage!), backgroundColor: AppColors.ludoGreen),
        );
        ref.read(adminProvider.notifier).clearMessages();
      }
    });

    Widget activeContent;
    switch (_activeTab) {
      case 0:
        activeContent = _buildAnalyticsDashboard(adminState);
        break;
      case 1:
        activeContent = _buildUserDirectory(adminState);
        break;
      case 2:
        activeContent = _buildTournamentManager(adminState);
        break;
      case 3:
        activeContent = _buildMatchesMonitor(adminState);
        break;
      case 4:
        activeContent = _buildBroadcastNotificationScreen(adminState);
        break;
      default:
        activeContent = const Center(child: Text('Unknown tab'));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Ludo Kingdom - Administrative Panel',
          style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: AppColors.surface,
        elevation: 4,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Refresh all dashboard data',
            onPressed: () => ref.read(adminProvider.notifier).fetchAll(),
          ),
          IconButton(
            icon: const Icon(Icons.exit_to_app),
            tooltip: 'Return to game home',
            onPressed: () => context.go('/home'),
          ),
          const SizedBox(width: 8),
        ],
      ),
      body: isDesktop
          ? Row(
              children: [
                // Sidebar Navigation (Desktop/Web Layout)
                Container(
                  width: 250,
                  color: AppColors.surface,
                  child: Column(
                    children: [
                      const SizedBox(height: 24),
                      const CircleAvatar(
                        radius: 36,
                        backgroundColor: AppColors.primary,
                        child: Icon(Icons.admin_panel_settings, size: 40, color: Colors.white),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'System Administrator',
                        style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                      ),
                      const Text(
                        'Role: Full Access',
                        style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
                      ),
                      const SizedBox(height: 32),
                      Expanded(
                        child: ListView(
                          children: [
                            _buildSidebarTile(0, 'Dashboard Analytics', Icons.dashboard_rounded),
                            _buildSidebarTile(1, 'User Management', Icons.people_rounded),
                            _buildSidebarTile(2, 'Tournament Manager', Icons.emoji_events_rounded),
                            _buildSidebarTile(3, 'Matches Monitoring', Icons.casino_rounded),
                            _buildSidebarTile(4, 'Broadcast Alerts', Icons.campaign_rounded),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                // Main Content Window
                Expanded(
                  child: Container(
                    padding: const EdgeInsets.all(24),
                    child: activeContent,
                  ),
                ),
              ],
            )
          : activeContent, // Tab pages rendering for mobile, adding a bottom navbar or sliding panel
      bottomNavigationBar: isDesktop
          ? null
          : BottomNavigationBar(
              currentIndex: _activeTab,
              selectedItemColor: AppColors.primary,
              unselectedItemColor: AppColors.textSecondary,
              backgroundColor: AppColors.surface,
              type: BottomNavigationBarType.fixed,
              onTap: (index) {
                setState(() {
                  _activeTab = index;
                });
              },
              items: const [
                BottomNavigationBarItem(icon: Icon(Icons.dashboard), label: 'Stats'),
                BottomNavigationBarItem(icon: Icon(Icons.people), label: 'Users'),
                BottomNavigationBarItem(icon: Icon(Icons.emoji_events), label: 'Tourney'),
                BottomNavigationBarItem(icon: Icon(Icons.casino), label: 'Matches'),
                BottomNavigationBarItem(icon: Icon(Icons.campaign), label: 'Broadcast'),
              ],
            ),
    );
  }

  Widget _buildSidebarTile(int index, String label, IconData icon) {
    final isSelected = _activeTab == index;
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: isSelected ? AppColors.primary.withOpacity(0.2) : Colors.transparent,
        borderRadius: BorderRadius.circular(8),
      ),
      child: ListTile(
        leading: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary),
        title: Text(
          label,
          style: TextStyle(
            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
            color: isSelected ? Colors.white : AppColors.textSecondary,
            fontSize: 14,
          ),
        ),
        onTap: () {
          setState(() {
            _activeTab = index;
          });
        },
      ),
    );
  }

  Widget _buildAnalyticsDashboard(AdminState state) {
    final analytics = state.analytics;
    
    if (state.isAnalyticsLoading && analytics == null) {
      return const Center(child: CircularProgressIndicator());
    }

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Dashboard Analytics',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const Text(
            'System status logs and real-time economy statistics',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          // Grid of Primary metric cards
          LayoutBuilder(
            builder: (context, constraints) {
              final columns = constraints.maxWidth > 600 ? 4 : 2;
              return GridView.count(
                crossAxisCount: columns,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 16,
                crossAxisSpacing: 16,
                childAspectRatio: 1.3,
                children: [
                  _buildMetricCard(
                    title: 'TOTAL REGISTERED USERS',
                    value: '${analytics?.totalUsers ?? 0}',
                    icon: Icons.people,
                    color: AppColors.primary,
                  ),
                  _buildMetricCard(
                    title: 'TOTAL MATCHES PLAYED',
                    value: '${analytics?.totalMatches ?? 0}',
                    icon: Icons.casino,
                    color: AppColors.secondary,
                  ),
                  _buildMetricCard(
                    title: 'ACTIVE LUDO ROOMS',
                    value: '${analytics?.totalActiveRooms ?? 0}',
                    icon: Icons.sports_esports,
                    color: AppColors.ludoGreen,
                  ),
                  _buildMetricCard(
                    title: 'COINS IN ECONOMY',
                    value: '${analytics?.activeCoinsInEconomy ?? 0}',
                    icon: Icons.monetization_on,
                    color: AppColors.gold,
                  ),
                ],
              );
            },
          ),
          
          const SizedBox(height: 32),

          // System Summary Card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Administrative Controls Quick Reference',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 12),
                  const Divider(color: Color(0xFF334155)),
                  const SizedBox(height: 8),
                  _buildQuickRefRow(Icons.check_circle_outline, 'Active Database Server:', 'MongoDB Atlas Cluster (Connected)'),
                  const SizedBox(height: 8),
                  _buildQuickRefRow(Icons.check_circle_outline, 'Active Socket Bridge:', 'Socket.IO Namespace initialized'),
                  const SizedBox(height: 8),
                  _buildQuickRefRow(Icons.check_circle_outline, 'Secure Authorization System:', 'Firebase Auth verify & JWT Authentication Token verify'),
                ],
              ),
            ),
          ).animate().fade(duration: 500.ms).slideY(begin: 0.1, end: 0),
        ],
      ),
    );
  }

  Widget _buildQuickRefRow(IconData icon, String title, String val) {
    return Row(
      children: [
        Icon(icon, color: AppColors.ludoGreen, size: 20),
        const SizedBox(width: 8),
        Text(title, style: const TextStyle(fontWeight: FontWeight.bold)),
        const SizedBox(width: 8),
        Text(val, style: const TextStyle(color: AppColors.textSecondary)),
      ],
    );
  }

  Widget _buildMetricCard({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
  }) {
    return Card(
      elevation: 4,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: color.withOpacity(0.3), width: 1.5),
          gradient: LinearGradient(
            colors: [AppColors.surface, color.withOpacity(0.05)],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: const TextStyle(color: AppColors.textSecondary, fontSize: 10, fontWeight: FontWeight.bold, letterSpacing: 1),
                  ),
                ),
                Icon(icon, color: color, size: 24),
              ],
            ),
            Text(
              value,
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.bold, fontFamily: 'Outfit', color: Colors.white),
            ),
          ],
        ),
      ),
    ).animate().scale(duration: 300.ms, curve: Curves.easeOutBack);
  }

  Widget _buildUserDirectory(AdminState state) {
    final users = state.users;
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'User Directory',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                Text(
                  'Search, edit coin balances, adjust level and ban suspicious players',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            if (state.isActionPending)
              const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)),
          ],
        ),
        const SizedBox(height: 20),

        // Search interface
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _userSearchController,
                decoration: const InputDecoration(
                  hintText: 'Search by User Name or Email...',
                  prefixIcon: Icon(Icons.search, color: AppColors.textSecondary),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(borderRadius: BorderRadius.all(Radius.circular(12))),
                ),
                onChanged: (val) {
                  // Standard client-side filter logic
                  setState(() {});
                },
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        // User Directory List
        Expanded(
          child: state.isUsersLoading
              ? const Center(child: CircularProgressIndicator())
              : users.isEmpty
                  ? const Center(child: Text('No users registered in database'))
                  : ListView.builder(
                      itemCount: users.length,
                      itemBuilder: (context, index) {
                        final user = users[index];
                        // Apply local search filter
                        final query = _userSearchController.text.toLowerCase();
                        if (query.isNotEmpty &&
                            !user.name.toLowerCase().contains(query) &&
                            !user.email.toLowerCase().contains(query)) {
                          return const SizedBox.shrink();
                        }

                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundImage: NetworkImage(user.avatar),
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Text(
                                            user.name,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                                          ),
                                          if (user.isAdmin)
                                            Container(
                                              margin: const EdgeInsets.only(left: 8),
                                              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                              decoration: BoxDecoration(
                                                color: AppColors.primary,
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                              child: const Text('Admin', style: TextStyle(fontSize: 9, fontWeight: FontWeight.bold)),
                                            ),
                                        ],
                                      ),
                                      Text(
                                        user.email,
                                        style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          const Icon(Icons.monetization_on, color: AppColors.gold, size: 14),
                                          const SizedBox(width: 2),
                                          Text('${user.coins} Coins', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold)),
                                          const SizedBox(width: 12),
                                          const Icon(Icons.star, color: AppColors.secondary, size: 14),
                                          const SizedBox(width: 2),
                                          Text('Lvl ${user.level} (${user.xp} XP)', style: const TextStyle(fontSize: 12)),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                                
                                // User Actions Layout
                                Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.wallet_giftcard_rounded, color: AppColors.gold),
                                      tooltip: 'Reward Coins/XP',
                                      onPressed: () => _showAdjustRewardsDialog(user),
                                    ),
                                    
                                    // Ban Status Indicator
                                    if (user.isAdmin)
                                      const SizedBox(width: 48) // Admins cannot ban other admins
                                    else ...[
                                      Icon(
                                        user.banned ? Icons.block : Icons.check_circle,
                                        color: user.banned ? AppColors.ludoRed : AppColors.ludoGreen,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      
                                      // Banned toggle button
                                      ElevatedButton(
                                        onPressed: () => ref.read(adminProvider.notifier).toggleBanUser(
                                          user.id,
                                          !user.banned,
                                        ),
                                        style: ElevatedButton.styleFrom(
                                          backgroundColor: user.banned
                                              ? AppColors.ludoGreen
                                              : AppColors.ludoRed,
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                        ),
                                        child: Text(
                                          user.banned ? 'Unban' : 'Ban',
                                          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
        
        // Paginator bar
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_back_ios),
              onPressed: state.usersCurrentPage > 1
                  ? () => ref.read(adminProvider.notifier).getUsers(page: state.usersCurrentPage - 1)
                  : null,
            ),
            Text(
              'Page ${state.usersCurrentPage} of ${((state.usersTotalCount) / 10).ceil().clamp(1, 1000)}',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
            IconButton(
              icon: const Icon(Icons.arrow_forward_ios),
              onPressed: (state.usersCurrentPage * 10) < state.usersTotalCount
                  ? () => ref.read(adminProvider.notifier).getUsers(page: state.usersCurrentPage + 1)
                  : null,
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildTournamentManager(AdminState state) {
    final tournaments = state.tournaments;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            const Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Tournament Management',
                  style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
                ),
                Text(
                  'Schedule new Ludo tournaments, view registrations, and delete expired tourneys',
                  style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
                ),
              ],
            ),
            ElevatedButton.icon(
              onPressed: _showCreateTournamentDialog,
              icon: const Icon(Icons.add, size: 18),
              label: const Text('New Tournament'),
              style: ElevatedButton.styleFrom(backgroundColor: AppColors.secondary),
            ),
          ],
        ),
        const SizedBox(height: 20),

        Expanded(
          child: state.isTournamentsLoading
              ? const Center(child: CircularProgressIndicator())
              : tournaments.isEmpty
                  ? const Center(child: Text('No active or upcoming tournaments scheduled.'))
                  : GridView.builder(
                      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                        maxCrossAxisExtent: 400,
                        mainAxisSpacing: 16,
                        crossAxisSpacing: 16,
                        childAspectRatio: 1.4,
                      ),
                      itemCount: tournaments.length,
                      itemBuilder: (context, index) {
                        final t = tournaments[index];
                        Color statusColor;
                        switch (t.status) {
                          case 'upcoming':
                            statusColor = AppColors.ludoBlue;
                            break;
                          case 'ongoing':
                            statusColor = AppColors.ludoGreen;
                            break;
                          case 'completed':
                            statusColor = AppColors.textMuted;
                            break;
                          default:
                            statusColor = Colors.white;
                        }

                        return Card(
                          child: Padding(
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    Expanded(
                                      child: Text(
                                        t.title,
                                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
                                      ),
                                    ),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                      decoration: BoxDecoration(
                                        color: statusColor.withOpacity(0.15),
                                        borderRadius: BorderRadius.circular(8),
                                        border: Border.all(color: statusColor.withOpacity(0.5)),
                                      ),
                                      child: Text(
                                        t.status.toUpperCase(),
                                        style: TextStyle(color: statusColor, fontSize: 10, fontWeight: FontWeight.bold),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  children: [
                                    _buildInfoTextCol('ENTRY FEE', '${t.entryFee} Coins'),
                                    _buildInfoTextCol('PRIZE POOL', '${t.prizePool} Coins'),
                                    _buildInfoTextCol('PARTICIPANTS', '${t.participantCount} registered'),
                                  ],
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Starts: ${t.startTime.day}/${t.startTime.month}/${t.startTime.year} @ ${t.startTime.hour.toString().padLeft(2, '0')}:${t.startTime.minute.toString().padLeft(2, '0')}',
                                  style: const TextStyle(color: AppColors.textSecondary, fontSize: 12),
                                ),
                                const Divider(color: Color(0xFF334155)),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.end,
                                  children: [
                                    if (t.status == 'upcoming')
                                      TextButton(
                                        onPressed: () => ref.read(adminProvider.notifier).updateTournamentStatus(t.id, 'ongoing'),
                                        child: const Text('Start Now', style: TextStyle(color: AppColors.ludoGreen)),
                                      ),
                                    if (t.status == 'ongoing')
                                      TextButton(
                                        onPressed: () => ref.read(adminProvider.notifier).updateTournamentStatus(t.id, 'completed'),
                                        child: const Text('Complete', style: TextStyle(color: AppColors.gold)),
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline, color: AppColors.ludoRed),
                                      tooltip: 'Delete Tournament',
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (context) => AlertDialog(
                                            backgroundColor: AppColors.surface,
                                            title: const Text('Confirm Delete', style: TextStyle(fontWeight: FontWeight.bold)),
                                            content: Text('Are you sure you want to delete "${t.title}"?'),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('No')),
                                              ElevatedButton(
                                                onPressed: () => Navigator.pop(context, true),
                                                style: ElevatedButton.styleFrom(backgroundColor: AppColors.ludoRed),
                                                child: const Text('Delete'),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          ref.read(adminProvider.notifier).deleteTournament(t.id);
                                        }
                                      },
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
        ),
      ],
    );
  }

  Widget _buildInfoTextCol(String label, String value) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
        ),
      ],
    );
  }

  Widget _buildMatchesMonitor(AdminState state) {
    final active = state.activeMatches;
    final history = state.matchHistory;

    return DefaultTabController(
      length: 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Match Monitoring',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const Text(
            'Monitor real-time active multiplayer matches and view historical logs',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 16),
          
          const TabBar(
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.textSecondary,
            indicatorColor: AppColors.primary,
            tabs: [
              Tab(icon: Icon(Icons.online_prediction), text: 'Live Active Matches'),
              Tab(icon: Icon(Icons.history), text: 'Finished Match History'),
            ],
          ),
          const SizedBox(height: 16),

          Expanded(
            child: TabBarView(
              children: [
                // 1. Live Active Matches Tab
                state.isMatchesLoading
                    ? const Center(child: CircularProgressIndicator())
                    : active.isEmpty
                        ? const Center(child: Text('No matches currently being played.'))
                        : GridView.builder(
                            gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                              maxCrossAxisExtent: 400,
                              mainAxisSpacing: 16,
                              crossAxisSpacing: 16,
                              childAspectRatio: 1.4,
                            ),
                            itemCount: active.length,
                            itemBuilder: (context, index) {
                              final m = active[index];
                              return Card(
                                child: Padding(
                                  padding: const EdgeInsets.all(16),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'ROOM: ${m.roomCode}',
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16, fontFamily: 'Outfit', color: AppColors.secondary),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.ludoGreen.withOpacity(0.1),
                                              borderRadius: BorderRadius.circular(4),
                                            ),
                                            child: const Row(
                                              children: [
                                                CircleAvatar(radius: 4, backgroundColor: AppColors.ludoGreen),
                                                SizedBox(width: 4),
                                                Text('LIVE', style: TextStyle(color: AppColors.ludoGreen, fontSize: 9, fontWeight: FontWeight.bold)),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 8),
                                      const Text(
                                        'PLAYERS IN MATCH:',
                                        style: TextStyle(color: AppColors.textMuted, fontSize: 9, fontWeight: FontWeight.bold),
                                      ),
                                      
                                      // Render player tokens/colors in match
                                      Column(
                                        children: m.players.map((p) {
                                          final isTurn = m.activeColor == p.color;
                                          Color bulletColor;
                                          switch (p.color) {
                                            case 'Red': bulletColor = AppColors.ludoRed; break;
                                            case 'Green': bulletColor = AppColors.ludoGreen; break;
                                            case 'Yellow': bulletColor = AppColors.ludoYellow; break;
                                            case 'Blue': bulletColor = AppColors.ludoBlue; break;
                                            default: bulletColor = Colors.white;
                                          }

                                          return Padding(
                                            padding: const EdgeInsets.symmetric(vertical: 2),
                                            child: Row(
                                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                              children: [
                                                Row(
                                                  children: [
                                                    Icon(Icons.lens, color: bulletColor, size: 10),
                                                    const SizedBox(width: 8),
                                                    Text(p.name, style: TextStyle(fontSize: 13, fontWeight: isTurn ? FontWeight.bold : FontWeight.normal)),
                                                    if (p.isBot)
                                                      Text(' (Bot)', style: TextStyle(color: AppColors.textSecondary.withOpacity(0.6), fontSize: 11)),
                                                  ],
                                                ),
                                                if (isTurn)
                                                  const Icon(Icons.play_arrow, color: AppColors.gold, size: 16),
                                              ],
                                            ),
                                          );
                                        }).toList(),
                                      ),
                                      
                                      const Divider(color: Color(0xFF334155)),
                                      Text(
                                        'Turn: ${m.activeColor} | Dice: ${m.diceValue ?? "-"} (${m.rollState})',
                                        style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),

                // 2. Finished Match History Tab
                Column(
                  children: [
                    Expanded(
                      child: history.isEmpty
                          ? const Center(child: Text('No historical logs saved in DB'))
                          : ListView.builder(
                              itemCount: history.length,
                              itemBuilder: (context, index) {
                                final h = history[index];
                                return Card(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  child: ListTile(
                                    leading: const CircleAvatar(
                                      backgroundColor: AppColors.surface,
                                      child: Icon(Icons.receipt_long, color: AppColors.textSecondary),
                                    ),
                                    title: Text(
                                      'Room ${h.roomCode} - Winner: ${h.winnerName}',
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                                    ),
                                    subtitle: Text(
                                      'Prize Pool: ${h.prizePool} Coins | Fee: ${h.entryFee} | Played on: ${h.createdAt.day}/${h.createdAt.month}/${h.createdAt.year}',
                                      style: const TextStyle(fontSize: 12),
                                    ),
                                    trailing: const Icon(Icons.arrow_forward_ios, size: 14, color: AppColors.textMuted),
                                  ),
                                );
                              },
                            ),
                    ),
                    
                    // History paginator
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        IconButton(
                          icon: const Icon(Icons.arrow_back_ios),
                          onPressed: state.historyCurrentPage > 1
                              ? () => ref.read(adminProvider.notifier).getMatchHistory(page: state.historyCurrentPage - 1)
                              : null,
                        ),
                        Text(
                          'Page ${state.historyCurrentPage} of ${((state.historyTotalCount) / 10).ceil().clamp(1, 1000)}',
                          style: const TextStyle(fontWeight: FontWeight.bold),
                        ),
                        IconButton(
                          icon: const Icon(Icons.arrow_forward_ios),
                          onPressed: (state.historyCurrentPage * 10) < state.historyTotalCount
                              ? () => ref.read(adminProvider.notifier).getMatchHistory(page: state.historyCurrentPage + 1)
                              : null,
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBroadcastNotificationScreen(AdminState state) {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Broadcast System Alert',
            style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, fontFamily: 'Outfit'),
          ),
          const Text(
            'Push real-time system alerts, server announcements, and coin giveaways to all players',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),

          Card(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Compose Notification Message',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, fontFamily: 'Outfit'),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _notificationTitleController,
                    decoration: const InputDecoration(
                      labelText: 'Notification Title',
                      hintText: 'e.g. Server Maintenance Notice',
                      filled: true,
                      fillColor: Color(0xFF1E293B),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 16),
                  
                  TextField(
                    controller: _notificationBodyController,
                    maxLines: 4,
                    decoration: const InputDecoration(
                      labelText: 'Alert Message Body',
                      hintText: 'e.g. Ludo Premium servers will undergo scheduled database maintenance at 02:00 AM UTC. Please finish your active matches.',
                      filled: true,
                      fillColor: Color(0xFF1E293B),
                      border: OutlineInputBorder(),
                    ),
                  ),
                  const SizedBox(height: 24),
                  
                  ElevatedButton.icon(
                    onPressed: state.isActionPending ? null : _handleBroadcastNotification,
                    icon: const Icon(Icons.send_rounded),
                    label: Text(state.isActionPending ? 'BROADCASTING...' : 'SEND BROADCAST ALERT'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                    ),
                  ),
                ],
              ),
            ),
          ).animate().fade(duration: 500.ms),
        ],
      ),
    );
  }
}
