# Arena 3D Online 1v1 — Design

## Objetivo
Jogo 3D de arena para 2 jogadores (o usuário e um amigo remoto), com combate
corpo a corpo e à distância, jogado online entre dois PCs via VPN P2P
(Radmin VPN / Hamachi), sem necessidade de servidor externo ou port
forwarding. O jogo é distribuído como um executável `.exe` que é reenviado
ao amigo a cada atualização relevante.

## Escopo da primeira versão
- Arena única, fechada (chão + paredes que limitam a área).
- Câmera terceira pessoa atrás do personagem.
- Personagem: cápsula placeholder (sem modelos/animações customizados nesta fase).
- Movimento: andar (WASD) + pular (Space) + olhar com o mouse.
- Combate:
  - Ataque corpo a corpo: curto alcance, cooldown, dano fixo.
  - Ataque à distância: dispara um projétil simples (esfera), cooldown, dano fixo.
- Vida: 100 HP por jogador. Dano reduz HP. Ao chegar a 0, a rodada termina.
- Fim de rodada: mostra o vencedor na tela; um input (ex: tecla R) reinicia
  a rodada (reposiciona os dois jogadores, restaura HP).
- Multiplayer: um jogador hospeda (host), o outro entra como cliente
  informando o IP (IP da rede virtual criada pela VPN). Sem matchmaking,
  sem lobby list — apenas host/join direto.

## Fora de escopo (por enquanto)
- Modelos 3D customizados, animações, sons/música.
- Mais de 2 jogadores.
- Múltiplas armas/habilidades, progressão, itens.
- Qualquer servidor dedicado/relay externo.
- Anti-cheat ou validação server-authoritative rigorosa (aceitável para
  jogo casual entre amigos).

## Arquitetura técnica

**Engine:** Godot 4.x (GDScript), export target: Windows `.exe`.

**Rede:** `ENetMultiplayerPeer` (API de alto nível de multiplayer do Godot).
- Host: `create_server(porta)`.
- Cliente: `create_client(ip_do_host, porta)`.
- Conexão ocorre sobre a rede virtual criada pela VPN (Radmin VPN/Hamachi),
  então do ponto de vista do Godot é uma LAN normal — não precisa NAT
  traversal nem port forwarding.

**Cenas principais:**
- `MainMenu.tscn` — tela inicial: botão "Hospedar" e campo de IP + botão
  "Conectar".
- `Arena.tscn` — cena de jogo: chão, paredes, spawn points dos dois
  jogadores, HUD (barras de vida, mensagem de vencedor).
- `Player.tscn` — `CharacterBody3D` com câmera, colisão, script de
  movimento e combate. Instanciado dinamicamente para cada peer conectado.
- `Projectile.tscn` — `Area3D`/`RigidBody3D` simples que viaja em linha
  reta e aplica dano ao colidir com um jogador.

**Sincronização (RPC do Godot):**
- Posição/rotação do jogador: replicada via `MultiplayerSynchronizer` ou
  RPCs periódicos (abordagem simples primeiro, ajustar se houver
  jitter perceptível).
- Ações de combate (melee, disparo de projétil, dano recebido): RPCs
  explícitas chamadas pelo autor da ação, autoridade simples (cada
  cliente controla seu próprio personagem — sem validação server-side
  na v1, aceitável para 2 amigos confiando um no outro).
- Estado de rodada (HP, vencedor, reset): mantido no host, replicado aos
  clientes.

## Testes
- Fase de combate/movimento: testável localmente rodando duas instâncias
  do editor/export na mesma máquina (host + cliente em `127.0.0.1`).
- Fase de rede real: teste entre os dois PCs via Radmin VPN antes de cada
  entrega de `.exe`.
- Sem suíte automatizada de testes nesta fase (projeto de jogo pequeno,
  validação manual jogando é suficiente).

## Entrega
A cada marco de desenvolvimento, exportar um novo `.exe` (Godot export
preset "Windows Desktop") e enviar para o amigo junto com instruções
rápidas: instalar Radmin VPN/Hamachi (uma vez), entrar na mesma rede
virtual, um hospeda e passa o IP virtual, o outro conecta.
