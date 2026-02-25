import 'dart:io';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  runApp(
    MaterialApp(
      title: 'Grimório da Produtividade',
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark().copyWith(
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: const ColorScheme.dark(
          primary: Color(0xFFFFD700),
          secondary: Color(0xFF9C27B0),
        ),
      ),
      home: const TelaMissao(),
    ),
  );
}

class TelaMissao extends StatefulWidget {
  const TelaMissao({super.key});

  @override
  State<TelaMissao> createState() => _TelaMissaoState();
}

class _TelaMissaoState extends State<TelaMissao> {
  bool _emMissao = false;
  final TextEditingController _controller = TextEditingController();
  final TextEditingController _questListController = TextEditingController();
  File? _fotoConcluida;
  final ImagePicker _picker = ImagePicker();
  final AudioPlayer _audioPlayer = AudioPlayer();

  // RPG Stats
  int _nivel = 1;
  int _xpAtual = 0;
  int _xpNecessario = 100;

  // Quadro de Missões
  List<String> _questsPendentes = [];

  // Pomodoro
  Timer? _timer;
  static const int _tempoPadrao = 40 * 60; // 40 min
  int _tempoRestante = _tempoPadrao;

  // Dicas TDAH
  String _dicaDoDia = "";
  final List<String> _listaDicas = [
    "Quebre missões grandes em pequenas missões de 5 minutos.",
    "Se não consegue fazer perfeito, faça mal feito. O importante é fazer.",
    "Beba água, Mago. Seu cérebro precisa de mana para funcionar.",
    "A motivação segue a ação. Comece, e a vontade virá depois.",
    "Use fones de ouvido ou ruído branco para bloquear distrações.",
    "Se travou, levante-se e dê uma volta na taverna.",
    "Escreva TUDO. Sua memória de trabalho é um slot de inventário pequeno.",
    "Apenas uma missão de cada vez. Multitarefa é um debuff de intelecto.",
    "O 'Long Rest' é essencial. Sem sono, seus slots de magia não recarregam.",
    "Cuidado com o Espelho Negro (celular). Ele é um portal amaldiçoado que rouba tempo.",
    "Limpe seu altar antes do ritual. A bagunça visual drena sua energia mística.",
    "Não tente matar o dragão inteiro. Mire apenas na próxima escama.",
    "Se a missão leva menos de 2 minutos, conjure-a agora. Não guarde no Grimório.",
    "Seu foco é um recurso escasso. Não gaste mana em 'side quests' inúteis.",
    "Falhou na quest de hoje? Amanhã o servidor reinicia. Tenha compaixão consigo mesmo.",
    "Se não está no seu campo de visão, não existe. Deixe suas poções e itens à vista.",
    "Ajuste sua armadura. Roupas desconfortáveis causam dano contínuo na concentração.",
    "A parte mais difícil de qualquer feitiço é a primeira sílaba. Apenas comece mal feito.",
  ];

  String _classeSelecionada = 'Estudos';

  final Map<String, IconData> _classesRPG = {
    'Estudos': Icons.history_edu,
    'Casa': Icons.fort,
    'Relacionamentos': Icons.favorite,
    'Hobbies': Icons.handyman,
    'Exercício': Icons.fitness_center,
  };

  final Map<String, int> _xpPorClasse = {
    'Estudos': 20,
    'Casa': 25,
    'Relacionamentos': 30,
    'Hobbies': 15,
    'Exercício': 40,
  };

  @override
  void initState() {
    super.initState();
    _carregarProgresso();
    _sortearDica();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _sortearDica() {
    setState(() {
      _dicaDoDia = _listaDicas[Random().nextInt(_listaDicas.length)];
    });
  }

  Future<void> _invocarBardo() async {
    final Uri spotifyApp = Uri.parse("spotify:open");
    final Uri spotifyWeb = Uri.parse("https://open.spotify.com");
    try {
      if (await canLaunchUrl(spotifyApp)) {
        await launchUrl(spotifyApp);
      } else {
        await launchUrl(spotifyWeb, mode: LaunchMode.externalApplication);
      }
    } catch (e) {
      await launchUrl(spotifyWeb, mode: LaunchMode.externalApplication);
    }
  }

  // --- TIMER COM PUNIÇÃO DE TEMPO ---
  void _iniciarPomodoro() {
    _tempoRestante = _tempoPadrao;
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        if (_tempoRestante > 0) {
          _tempoRestante--;
        } else {
          // O TEMPO ACABOU!
          _timer?.cancel();
          _punirTempoEsgotado(); // Chama a punição de -25
        }
      });
    });
  }

  void _pararPomodoro() {
    _timer?.cancel();
  }

  String _formatarTempo(int segundos) {
    int min = segundos ~/ 60;
    int sec = segundos % 60;
    return '${min.toString().padLeft(2, '0')}:${sec.toString().padLeft(2, '0')}';
  }

  Future<void> _carregarProgresso() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _nivel = prefs.getInt('nivel') ?? 1;
      _xpAtual = prefs.getInt('xpAtual') ?? 0;
      _xpNecessario = prefs.getInt('xpNecessario') ?? 100;
      _questsPendentes = prefs.getStringList('questsPendentes') ?? [];
    });
  }

  Future<void> _salvarProgresso() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('nivel', _nivel);
    await prefs.setInt('xpAtual', _xpAtual);
    await prefs.setInt('xpNecessario', _xpNecessario);
    await prefs.setStringList('questsPendentes', _questsPendentes);
  }

  Future<void> _tocarSom(String arquivo) async {
    try {
      await _audioPlayer.play(AssetSource('sounds/$arquivo'));
    } catch (e) {
      print("Erro no bardo: $e");
    }
  }

  // --- SISTEMA DE XP E PUNIÇÕES ---

  void _ganharXP() {
    int xpGanho = _xpPorClasse[_classeSelecionada] ?? 20;
    _tocarSom('win.mp3');

    setState(() {
      _xpAtual += xpGanho;
      if (_xpAtual >= _xpNecessario) {
        _xpAtual -= _xpNecessario;
        _nivel++;
        _xpNecessario = (_xpNecessario * 1.2).toInt();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.purple,
            content: Text(
              "✨ LEVEL UP! BEM-VINDO AO NÍVEL $_nivel ✨",
              style: GoogleFonts.medievalSharp(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.green[800],
            content: Text(
              "Vitória! Você ganhou +$xpGanho XP!",
              style: GoogleFonts.medievalSharp(
                fontSize: 16,
                color: Colors.white,
              ),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });
    _salvarProgresso();
  }

  // PUNIÇÃO 1: DESISTÊNCIA (-50 XP)
  void _abandonarQuest() {
    _pararPomodoro();
    setState(() {
      _xpAtual -= 50;
      if (_xpAtual < 0) _xpAtual = 0; // Não deixa ficar negativo

      _emMissao = false;
      _controller.clear();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _salvarProgresso();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.red[900],
        content: Text(
          "Você fugiu! -50 XP (Vergonha!) 💀",
          style: GoogleFonts.medievalSharp(fontSize: 16, color: Colors.white),
        ),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  // PUNIÇÃO 2: TEMPO ESGOTADO (-25 XP)
  void _punirTempoEsgotado() {
    setState(() {
      _xpAtual -= 25;
      if (_xpAtual < 0) _xpAtual = 0; // Não deixa ficar negativo

      _emMissao = false;
      _controller.clear();
    });

    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _salvarProgresso();

    // Exibe alerta de falha
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: Text(
          "TEMPO ESGOTADO!",
          style: GoogleFonts.medievalSharp(
            color: Colors.redAccent,
            fontSize: 24,
          ),
        ),
        content: Text(
          "A ampulheta secou. Você perdeu 25 XP.",
          style: const TextStyle(color: Colors.white),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text(
              "Aceitar Destino",
              style: TextStyle(color: Colors.amber),
            ),
          ),
        ],
      ),
    );
  }
  // --------------------------------

  void _iniciarQuest() {
    if (_controller.text.isEmpty) return;
    _tocarSom('sword.mp3');
    _iniciarPomodoro();
    _sortearDica();
    setState(() {
      _fotoConcluida = null;
      _emMissao = true;
    });
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  }

  Future<void> _conjurarProva() async {
    try {
      final XFile? photo = await _picker.pickImage(source: ImageSource.camera);
      if (photo != null) {
        _pararPomodoro();
        _ganharXP();
        setState(() {
          _fotoConcluida = File(photo.path);
          _emMissao = false;
          _controller.clear();
        });
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
      }
    } catch (e) {
      print("Falha na magia: $e");
    }
  }

  void _abrirQuadroDeQuests() {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: const Color(0xFF1E1E1E),
      builder: (context) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return Padding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.of(context).viewInsets.bottom,
                left: 20,
                right: 20,
                top: 20,
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.assignment, color: Colors.amber),
                      const SizedBox(width: 10),
                      Text(
                        "Quadro de Missões",
                        style: GoogleFonts.medievalSharp(
                          fontSize: 22,
                          color: Colors.amber,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 15),
                  SizedBox(
                    height: 200,
                    child: _questsPendentes.isEmpty
                        ? Center(
                            child: Text(
                              "Nenhuma missão no quadro.",
                              style: GoogleFonts.cinzel(color: Colors.grey),
                            ),
                          )
                        : ListView.builder(
                            itemCount: _questsPendentes.length,
                            itemBuilder: (context, index) {
                              return Card(
                                color: Colors.black45,
                                child: ListTile(
                                  title: Text(
                                    _questsPendentes[index],
                                    style: const TextStyle(color: Colors.white),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete,
                                      color: Colors.redAccent,
                                      size: 20,
                                    ),
                                    onPressed: () {
                                      setModalState(() {
                                        _questsPendentes.removeAt(index);
                                      });
                                      _salvarProgresso();
                                      setState(() {});
                                    },
                                  ),
                                  onTap: () {
                                    setState(() {
                                      _controller.text =
                                          _questsPendentes[index];
                                    });
                                    Navigator.pop(context);
                                  },
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: _questListController,
                          style: const TextStyle(color: Colors.white),
                          decoration: const InputDecoration(
                            hintText: "Nova missão pendente...",
                            hintStyle: TextStyle(color: Colors.grey),
                          ),
                        ),
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add_circle,
                          color: Colors.greenAccent,
                        ),
                        onPressed: () {
                          if (_questListController.text.isNotEmpty) {
                            setModalState(() {
                              _questsPendentes.add(_questListController.text);
                              _questListController.clear();
                            });
                            _salvarProgresso();
                            setState(() {});
                          }
                        },
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                ],
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: !_emMissao,
      child: Scaffold(
        backgroundColor: _emMissao ? Colors.black : const Color(0xFF121212),
        floatingActionButton: !_emMissao
            ? FloatingActionButton(
                onPressed: _abrirQuadroDeQuests,
                backgroundColor: Colors.purple,
                child: const Icon(Icons.list_alt, color: Colors.white),
              )
            : null,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _emMissao ? _buildTelaCombate() : _buildTelaTaverna(),
          ),
        ),
      ),
    );
  }

  Widget _buildTelaTaverna() {
    double progresso = _xpAtual / _xpNecessario;

    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    "Nível $_nivel",
                    style: GoogleFonts.medievalSharp(
                      fontSize: 24,
                      color: Colors.amber,
                    ),
                  ),
                  Text(
                    "$_xpAtual / $_xpNecessario XP",
                    style: GoogleFonts.cinzel(fontSize: 12, color: Colors.grey),
                  ),
                ],
              ),
              ElevatedButton.icon(
                onPressed: _invocarBardo,
                icon: const Icon(Icons.music_note, color: Colors.greenAccent),
                label: Text(
                  "Bardo",
                  style: GoogleFonts.medievalSharp(color: Colors.white),
                ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.black38,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  side: const BorderSide(color: Colors.green, width: 0.5),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: progresso,
              backgroundColor: Colors.grey.shade800,
              color: Colors.purpleAccent,
              minHeight: 15,
            ),
          ),
          const SizedBox(height: 25),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: Colors.deepPurple.withOpacity(0.2),
              border: Border.all(
                color: Colors.deepPurpleAccent.withOpacity(0.5),
              ),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.auto_awesome,
                      color: Colors.amber,
                      size: 20,
                    ),
                    const SizedBox(width: 10),
                    Text(
                      "Sabedoria Arcana",
                      style: GoogleFonts.medievalSharp(
                        color: Colors.amber,
                        fontSize: 16,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Text(
                  "\"$_dicaDoDia\"",
                  style: const TextStyle(
                    color: Colors.white70,
                    fontStyle: FontStyle.italic,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 30),
          Text(
            "Mago Vini,",
            style: GoogleFonts.medievalSharp(fontSize: 32, color: Colors.white),
          ),
          Text(
            "Escolha sua batalha:",
            style: GoogleFonts.medievalSharp(fontSize: 18, color: Colors.grey),
          ),
          const SizedBox(height: 20),

          SizedBox(
            height: 110,
            child: ListView(
              scrollDirection: Axis.horizontal,
              children: _classesRPG.entries.map((entry) {
                final nome = entry.key;
                final icone = entry.value;
                final isSelected = _classeSelecionada == nome;
                final xpValor = _xpPorClasse[nome] ?? 0;

                return GestureDetector(
                  onTap: () => setState(() => _classeSelecionada = nome),
                  child: Container(
                    width: 90,
                    margin: const EdgeInsets.only(right: 12),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? Colors.amber.withOpacity(0.2)
                          : Colors.black38,
                      border: Border.all(
                        color: isSelected ? Colors.amber : Colors.grey.shade800,
                        width: 2,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          icone,
                          color: isSelected ? Colors.amber : Colors.grey,
                          size: 30,
                        ),
                        const SizedBox(height: 5),
                        Text(
                          nome,
                          style: GoogleFonts.cinzel(
                            fontSize: 10,
                            color: isSelected ? Colors.amber : Colors.grey,
                            fontWeight: FontWeight.bold,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          "+$xpValor XP",
                          style: const TextStyle(
                            color: Colors.greenAccent,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              }).toList(),
            ),
          ),

          const SizedBox(height: 30),
          TextField(
            controller: _controller,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              filled: true,
              fillColor: Colors.black26,
              labelText: 'Objetivo da Quest',
              labelStyle: GoogleFonts.medievalSharp(color: Colors.grey),
              hintText: "Digite ou escolha do quadro (+)",
              hintStyle: const TextStyle(color: Colors.white24),
              enabledBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.grey),
              ),
              focusedBorder: const OutlineInputBorder(
                borderSide: BorderSide(color: Colors.amber),
              ),
              prefixIcon: const Icon(Icons.history_edu, color: Colors.amber),
            ),
          ),
          const SizedBox(height: 30),
          SizedBox(
            width: double.infinity,
            height: 55,
            child: ElevatedButton(
              onPressed: _iniciarQuest,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF4A148C),
                foregroundColor: Colors.amber,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                side: const BorderSide(color: Colors.amber, width: 1),
              ),
              child: Text(
                "ACEITAR QUEST",
                style: GoogleFonts.medievalSharp(
                  fontSize: 20,
                  letterSpacing: 1,
                ),
              ),
            ),
          ),
          const SizedBox(height: 80),
        ],
      ),
    );
  }

  Widget _buildTelaCombate() {
    Color corTempo = _tempoRestante < 60 ? Colors.redAccent : Colors.amber;
    int xpPotencial = _xpPorClasse[_classeSelecionada] ?? 20;

    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _formatarTempo(_tempoRestante),
          style: GoogleFonts.medievalSharp(
            fontSize: 80,
            color: corTempo,
            fontWeight: FontWeight.bold,
            shadows: [
              BoxShadow(
                color: corTempo.withOpacity(0.5),
                blurRadius: 20,
                spreadRadius: 5,
              ),
            ],
          ),
        ),
        Text(
          "TEMPO DE CONJURAÇÃO",
          style: GoogleFonts.cinzel(
            color: Colors.white54,
            fontSize: 12,
            letterSpacing: 3,
          ),
        ),
        const SizedBox(height: 40),
        Icon(_classesRPG[_classeSelecionada], size: 60, color: Colors.grey),
        const SizedBox(height: 10),
        Text(
          "QUEST EM ANDAMENTO",
          style: GoogleFonts.medievalSharp(
            color: Colors.redAccent,
            fontSize: 20,
            letterSpacing: 2,
          ),
        ),
        const SizedBox(height: 10),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Text(
            _controller.text.toUpperCase(),
            textAlign: TextAlign.center,
            style: GoogleFonts.cinzel(
              fontSize: 24,
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
        const SizedBox(height: 5),
        Text(
          "Recompensa: +$xpPotencial XP",
          style: const TextStyle(color: Colors.greenAccent, fontSize: 14),
        ),
        const SizedBox(height: 20),
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 30),
          child: Text(
            "\"Apenas a prova visual libertará sua alma.\"",
            textAlign: TextAlign.center,
            style: TextStyle(
              color: Colors.white30,
              fontStyle: FontStyle.italic,
              fontSize: 16,
            ),
          ),
        ),
        const SizedBox(height: 60),
        SizedBox(
          width: double.infinity,
          height: 60,
          child: ElevatedButton.icon(
            onPressed: _conjurarProva,
            icon: const Icon(Icons.camera_alt),
            label: Text(
              "CONJURAR PROVA",
              style: GoogleFonts.medievalSharp(fontSize: 18),
            ),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.green.shade900,
              foregroundColor: Colors.white,
              side: const BorderSide(color: Colors.greenAccent),
            ),
          ),
        ),
        const SizedBox(height: 20),

        // BOTÃO DE DESISTÊNCIA
        TextButton.icon(
          onPressed: _abandonarQuest,
          icon: const Icon(Icons.exit_to_app, color: Colors.red),
          label: const Text(
            "ABANDONAR (-50 XP)",
            style: TextStyle(color: Colors.red),
          ),
        ),
      ],
    );
  }
}
