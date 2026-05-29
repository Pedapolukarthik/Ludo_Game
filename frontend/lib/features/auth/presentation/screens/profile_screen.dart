import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../../core/network/api_client.dart';
import '../../../../core/theme/app_theme.dart';
import '../providers/auth_provider.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _nameController = TextEditingController();
  List<dynamic> _friends = [];
  bool _isLoadingFriends = false;
  String _searchQuery = '';
  List<dynamic> _searchResults = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _nameController.text = ref.read(authProvider).user?.name ?? '';
    _fetchFriends();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _fetchFriends() async {
    setState(() => _isLoadingFriends = true);
    try {
      final response = await ApiClient.get('/auth/me');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _friends = data['user']['friends'] ?? [];
        });
      }
    } catch (e) {
      print('Error fetching friends: $e');
    } finally {
      setState(() => _isLoadingFriends = false);
    }
  }

  void _searchUsers(String val) async {
    if (val.trim().isEmpty) {
      setState(() {
        _searchResults = [];
        _isSearching = false;
      });
      return;
    }
    setState(() => _isSearching = true);
    try {
      final response = await ApiClient.get('/users/search?query=$val');
      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        setState(() {
          _searchResults = data['users'] ?? [];
        });
      }
    } catch (e) {
      print('Error searching users: $e');
    } finally {
      setState(() => _isSearching = false);
    }
  }

  void _sendFriendRequest(String userId) async {
    try {
      final response = await ApiClient.post('/users/friends/request/$userId', {});
      final data = jsonDecode(response.body);
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(data['message'] ?? 'Friend request sent!')),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to send request')),
      );
    }
  }

  void _removeFriend(String userId) async {
    try {
      final response = await ApiClient.delete('/users/friends/$userId');
      if (response.statusCode == 200) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Friend removed')),
        );
        _fetchFriends();
      }
    } catch (e) {
      print(e);
    }
  }

  void _updateName() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final response = await ApiClient.put('/users/profile', {'name': name});
      if (response.statusCode == 200) {
        ref.read(authProvider.notifier).tryRestoreSession();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Profile updated successfully!')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to update profile')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = ref.watch(authProvider).user;
    if (user == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    final nextLevelXp = 1000;
    final currentLevelXp = user.xp % 1000;
    final xpProgress = currentLevelXp / nextLevelXp;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('PLAYER PROFILE', style: TextStyle(fontFamily: 'Outfit', fontWeight: FontWeight.bold)),
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => context.go('/home'),
        ),
      ),
      body: Column(
        children: [
          // Header Profile Card
          Padding(
            padding: const EdgeInsets.all(16),
            child: Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Row(
                      children: [
                        CircleAvatar(
                          radius: 40,
                          backgroundColor: AppColors.primary,
                          backgroundImage: NetworkImage(user.avatar),
                        ),
                        const SizedBox(width: 16),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: TextField(
                                      controller: _nameController,
                                      style: const TextStyle(
                                        fontSize: 20,
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                      ),
                                      decoration: const InputDecoration(
                                        border: InputBorder.none,
                                        suffixIcon: Icon(Icons.edit, size: 16, color: AppColors.textSecondary),
                                      ),
                                      onSubmitted: (_) => _updateName(),
                                    ),
                                  ),
                                ],
                              ),
                              Text(
                                user.email,
                                style: const TextStyle(color: AppColors.textSecondary),
                              ),
                              const SizedBox(height: 8),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                decoration: BoxDecoration(
                                  gradient: AppTheme.purplePinkGradient,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                                child: Text(
                                  'Rank: ${user.rank}',
                                  style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 20),
                    
                    // Level Progression Bar
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text('LEVEL ${user.level}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                        Text('$currentLevelXp / $nextLevelXp XP', style: const TextStyle(color: AppColors.textSecondary, fontSize: 13)),
                      ],
                    ),
                    const SizedBox(height: 6),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: LinearProgressIndicator(
                        value: xpProgress,
                        backgroundColor: const Color(0xFF334155),
                        valueColor: const AlwaysStoppedAnimation(AppColors.secondary),
                        minHeight: 8,
                      ),
                    ),
                    const SizedBox(height: 20),

                    // Win-Loss statistics row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat('Wins', '${user.totalWins}', AppColors.ludoGreen),
                        _buildStat('Losses', '${user.losses}', AppColors.ludoRed),
                        _buildStat('Matches', '${user.totalGames}', AppColors.ludoBlue),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildStat(
                          'Win %',
                          user.totalGames > 0
                              ? '${(user.totalWins / user.totalGames * 100).toStringAsFixed(1)}%'
                              : '0.0%',
                          AppColors.gold,
                        ),
                        _buildStat('Win Streak', '${user.currentWinStreak}', AppColors.secondary),
                        _buildStat('Max Streak', '${user.highestWinStreak}', AppColors.gold),
                      ],
                    ),
                    const SizedBox(height: 16),
                    const Divider(color: Color(0xFF334155)),
                    const SizedBox(height: 8),
                    // Action button to open match history
                    ElevatedButton.icon(
                      onPressed: () => context.go('/match-history'),
                      icon: const Icon(Icons.history, size: 18),
                      label: const Text('VIEW MATCH HISTORY'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.cardBg,
                        side: const BorderSide(color: AppColors.primary, width: 1.5),
                        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Bar
          TabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Achievements'),
              Tab(text: 'Friends List'),
            ],
            indicatorColor: AppColors.primary,
            labelColor: Colors.white,
            unselectedLabelColor: AppColors.textSecondary,
          ),

          // Tab views
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                // Achievements Tab
                ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: user.achievements.length + 1,
                  itemBuilder: (context, idx) {
                    if (idx == 0) {
                      return Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Text(
                          'Referral Code: ${user.referralCode}',
                          style: const TextStyle(fontWeight: FontWeight.bold, color: AppColors.ludoYellow, fontSize: 16),
                          textAlign: TextAlign.center,
                        ),
                      );
                    }
                    final achievement = user.achievements[idx - 1];
                    if (achievement.startsWith('DailyClaim_') || achievement.startsWith('SpinClaim_')) {
                      return const SizedBox.shrink(); // Hide reward keys
                    }
                    return Card(
                      color: AppColors.surface,
                      child: ListTile(
                        leading: const Icon(Icons.wine_bar, color: AppColors.gold),
                        title: Text(achievement),
                        subtitle: const Text('Unlocked milestone'),
                      ),
                    );
                  },
                ),

                // Friends tab
                Column(
                  children: [
                    // Search bar
                    Padding(
                      padding: const EdgeInsets.all(12),
                      child: TextField(
                        onChanged: _searchUsers,
                        decoration: InputDecoration(
                          hintText: 'Search friends...',
                          prefixIcon: const Icon(Icons.search),
                          filled: true,
                          fillColor: AppColors.cardBg,
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                      ),
                    ),

                    if (_isSearching)
                      const LinearProgressIndicator(valueColor: AlwaysStoppedAnimation(AppColors.primary))
                    else if (_searchResults.isNotEmpty) ...[
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 16),
                        child: Text('Search Results', style: TextStyle(fontWeight: FontWeight.bold, color: AppColors.textSecondary)),
                      ),
                      Expanded(
                        child: ListView.builder(
                          itemCount: _searchResults.length,
                          itemBuilder: (context, idx) {
                            final item = _searchResults[idx];
                            return ListTile(
                              leading: CircleAvatar(backgroundImage: NetworkImage(item['avatar'])),
                              title: Text(item['name']),
                              subtitle: Text('Lvl ${item['level']} - ${item['rank']}'),
                              trailing: IconButton(
                                icon: const Icon(Icons.person_add_alt_1, color: AppColors.primary),
                                onPressed: () => _sendFriendRequest(item['_id']),
                              ),
                            );
                          },
                        ),
                      ),
                    ] else ...[
                      // Normal Friends list
                      Expanded(
                        child: _isLoadingFriends
                            ? const Center(child: CircularProgressIndicator())
                            : _friends.isEmpty
                                ? const Center(child: Text('No friends added yet.'))
                                : ListView.builder(
                                    itemCount: _friends.length,
                                    itemBuilder: (context, idx) {
                                      final friend = _friends[idx];
                                      return ListTile(
                                        leading: CircleAvatar(backgroundImage: NetworkImage(friend['avatar'])),
                                        title: Text(friend['name']),
                                        subtitle: Text('Rank: ${friend['rank']}'),
                                        trailing: IconButton(
                                          icon: const Icon(Icons.person_remove_outlined, color: AppColors.ludoRed),
                                          onPressed: () => _removeFriend(friend['_id']),
                                        ),
                                      );
                                    },
                                  ),
                      ),
                    ]
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildStat(String title, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: color),
        ),
        const SizedBox(height: 4),
        Text(
          title,
          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
