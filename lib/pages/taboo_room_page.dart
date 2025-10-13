Scaffold(
  backgroundColor: const Color(0xFF0E0E10),
  body: Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        ShaderMask(
          shaderCallback: (bounds) => const LinearGradient(
            colors: [Color(0xFFB993D6), Color(0xFF8CA6DB)],
          ).createShader(bounds),
          child: const Text(
            'ENTER TABOO\'S ROOM',
            style: TextStyle(
              fontSize: 38,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 4,
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          '—— 静寂の中で秘密が目覚める ——',
          style: TextStyle(color: Colors.grey, fontSize: 14),
        ),
        const SizedBox(height: 40),
        ElevatedButton.icon(
          onPressed: _openDiscordProfile,
          icon: const Icon(Icons.door_front_door_outlined),
          label: const Text('ENTER TABOO\'S ROOM'),
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.deepPurpleAccent.withOpacity(0.2),
            shadowColor: Colors.deepPurpleAccent,
            elevation: 10,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 16),
          ),
        ),
      ],
    ),
  ),
);